-- fury_wotlk.lua — Warrior Fury rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Fury warrior DPS: Battle Shout maintenance,
--        Death Wish CD, Execute execute-range, Bloodthirst filler, Whirlwind AoE,
--        Bloodsurge-proc-gated Slam, Berserker Stance enforcement (the APL's
--        final lane — Whirlwind/Pummel are Berserker-only in WotLK).
-- WHEN:  combat with a valid enemy target; Berserker Stance (default for Fury).
-- WHY:   mirrors SimulationCraft / wowsims WotLK Fury APL with 3.3.5-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocations; cooldown reads via
--         NS.cooldown_remains (never a 99 fallback — action:cooldown_remaining() is
--         mock-only and silently never-fired the DeathWish lane in production).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
-- Cast/channel end-time gate (2026-09-12): an interrupt that lands after the
-- target's cast completes wastes its cooldown. Fail-open when the engine
-- reports no end time (shared/cast_timing_sylvanas.lua).
local _ct_ok, cast_timing = pcall(require, "shared/cast_timing_sylvanas")
if not _ct_ok or type(cast_timing) ~= "table" then
    cast_timing = { context_interrupt_open = function() return true end }
end
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Plain define_action (NOT define_action_for_class): the WotLK client loads the
-- TBC class_sylvanas.lua into NS.WarriorSpells, so the class-first resolver would
-- shadow these WotLK rank ladders with TBC-era rank lists.
local define = spec_kit.define_action

local ACTION = {
    Bloodthirst = define("Bloodthirst", { 30335, 25251, 23894, 23893, 23892, 23881 }, "Bloodthirst"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
    Slam = define("Slam", { 47475, 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    Execute = define("Execute", { 47471, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    -- 12328 is Sweeping Strikes, NOT a Death Wish rank (rank-list contamination);
    -- WotLK Death Wish is the single rank 12292.
    DeathWish = define("DeathWish", { 12292 }, "DeathWish"),
    BattleShout = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    -- Baseline warrior interrupt (3.3.5): not in the wowsims fury APL, so it
    -- sits outside the pinned order (first, like arms' class-sibling template).
    Pummel = define("Pummel", { 6554, 6552 }, "Pummel"),
    BerserkerStance = define("BerserkerStance", 2458, "BerserkerStance"),
    -- 2026-09-12 guide pass (Wowhead WotLK-verified): the wowsims fury APL
    -- casts Cleave 47520 (rage>=12, targets>1) and Heroic Strike 47450
    -- (rage>=12, single target) as queued rage dumps, and the prepull/
    -- autocastOtherCooldowns block carries Recklessness (1719, Berserker
    -- only, 5-min, +100% crit on the next 3 specials). Heroic Throw 57755
    -- is the ranged gap-closer the APL fires when auto + both CDs are away.
    Cleave = define("Cleave", { 47520, 25231, 20569, 11609, 11608, 7369, 845 }, "Cleave"),
    HeroicStrike = define("HeroicStrike", { 47450, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Recklessness = define("Recklessness", 1719, "Recklessness"),
    HeroicThrow = define("HeroicThrow", 57755, "HeroicThrow"),
}

local BATTLE_SHOUT_BUFF = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
-- Bloodsurge (Fury talent): makes Slam instant + free. 46916 = rank 1, 70847 = rank 2.
local BLOODSURGE_BUFF = { 46916, 70847 }

local EXECUTE_RAGE_MIN = 15 -- WotLK Execute costs 15 rage
local PUMMEL_RAGE_MIN  = 10 -- Pummel costs 10 rage
local HEROIC_RAGE_MIN   = 30  -- queued Heroic Strike / Cleave threshold (prot precedent)
local HEROIC_SWING_WINDOW = 1.0 -- queue the strike when the next auto lands within 1s
local RECKLESSNESS_CD   = 300 -- 5-min burst CD (Berserker stance only)

-- -----------------------------------------------------------------------------
-- Cooldown reads go through NS.cooldown_remains / NS.get_spell_cooldown (both
-- 0 when unknown). The old action:cooldown_remaining() call returned nil in
-- production (spell_action exposes no such method), making every caller fall
-- back to 99/999 and silently never-firing the DeathWish lane.
-- -----------------------------------------------------------------------------
local function cd_remaining(action)
    if NS.cooldown_remains then
        local v = NS.cooldown_remains(action)
        if type(v) == "number" then return v end
    end
    if NS.get_spell_cooldown then
        local v = NS.get_spell_cooldown(action)
        if type(v) == "number" then return v end
    end
    return 0
end

-- Seconds until the main-hand auto swing lands (999 when unknown: gate fails
-- closed so a queued strike never fires without a real swing clock).
local function swing_time_until(me)
    if me and NS and type(NS.swing_time_until) == "function" then
        local ok, v = pcall(NS.swing_time_until, me)
        if ok and type(v) == "number" then return v end
    end
    return 999
end

local function target_is_interruptible(target)
    if NS and type(NS.is_interruptible) == "function" then
        return NS.is_interruptible(target) == true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- State table (raw; safe_state proxy applied in build_state)
-- -----------------------------------------------------------------------------
local fury_state = {
    rage = 0,
    stance = STANCE.BERSERKER,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    target_is_casting = false,
    battle_shout_up = false,
    bloodsurge_proc = false,
    execute_ready = false,
    death_wish_ready = false,
    bloodthirst_cd = 99,
    whirlwind_cd = 99,
    pummel_ready = false,
    recklessness_ready = false,
    heroic_throw_ready = false,
    heroic_swing_imminent = false,
    in_melee_range = true,
}

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(fury_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    -- Rage via the REAL chain: context.rage (main_sylvanas.lua:814,
    -- power_current(NS.POWER_RAGE)) first, then me:get_power(NS.POWER_RAGE) —
    -- me:get_rage() is mock-only and pinned state.rage at 0 live (W3.4 audit),
    -- collapsing every rage-gated lane into a production never-lane. Mirrors
    -- bear_wotlk.lua:57-59.
    state.rage = (context and context.rage)
        or (me and me.get_power and me:get_power(NS.POWER_RAGE))
        or 0
    state.stance = (me and type(me.get_stance) == "function" and me:get_stance()) or STANCE.BERSERKER
    state.target_hp = (target and type(target.get_health_percentage) == "function" and target:get_health_percentage()) or 100
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false
    state.bloodsurge_proc = (me and NS.buff_up and NS.buff_up(me, BLOODSURGE_BUFF)) or false

    -- Cooldown / availability tracking (real API: NS.cooldown_remains, 0 = ready)
    state.execute_ready = (state.target_hp or 100) < 20
    state.death_wish_ready = cd_remaining(ACTION.DeathWish) <= 0
    state.bloodthirst_cd = cd_remaining(ACTION.Bloodthirst)
    state.whirlwind_cd = cd_remaining(ACTION.Whirlwind)
    state.pummel_ready = cd_remaining(ACTION.Pummel) <= 0
    state.recklessness_ready = cd_remaining(ACTION.Recklessness) <= 0
    state.heroic_throw_ready = cd_remaining(ACTION.HeroicThrow) <= 0
    state.heroic_swing_imminent = swing_time_until(me) <= HEROIC_SWING_WINDOW
    -- context.in_melee_range is published by main_sylvanas (me:is_in_melee_range);
    -- a harness without it keeps the melee default so nothing changes there.
    state.in_melee_range = (context and context.in_melee_range ~= false)

    return state
end

-- -----------------------------------------------------------------------------
-- Helper: should_use_long_cd wrapper (nil-safe for unit tests)
-- -----------------------------------------------------------------------------
local function should_use_long_cd(context, cooldown)
    if NS and type(NS.should_use_long_cd) == "function" then
        return NS.should_use_long_cd(context, cooldown) == true
    end
    return true
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Pummel",
        conditions = {
            { type = "custom", fn = function(context, state)
                return cast_timing.context_interrupt_open(context, context and context.settings)
            end },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return target_is_interruptible(context.target)
            end },
            { type = "state", field = "pummel_ready", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = PUMMEL_RAGE_MIN },
            { type = "state", field = "stance", op = "==", value = STANCE.BERSERKER },
        },
        action = { type = "cast", spell = ACTION.Pummel, target = "target" },
    },
    {
        name = "BattleShout",
        conditions = {
            { type = "state", field = "battle_shout_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BattleShout, target = "self" },
    },
    -- Recklessness: the fury burst CD (Berserker-stance only, 5 min, +100% crit
    -- on the next 3 special attacks). Sits with Death Wish above the fillers.
    {
        name = "Recklessness",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "recklessness_ready", op = "truthy" },
            { type = "state", field = "stance", op = "==", value = STANCE.BERSERKER },
            { type = "custom", fn = function(context, state)
                return should_use_long_cd(context, RECKLESSNESS_CD)
            end },
        },
        action = { type = "cast", spell = ACTION.Recklessness, target = "self" },
    },
    {
        name = "DeathWish",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "death_wish_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return should_use_long_cd(context, 180)
            end },
        },
        action = { type = "cast", spell = ACTION.DeathWish, target = "self" },
    },
    {
        name = "Execute",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "execute_ready", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = EXECUTE_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.Execute, target = "target" },
    },
    {
        name = "Bloodthirst",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 30 },
            { type = "state", field = "bloodthirst_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Bloodthirst, target = "target" },
    },
    -- Cleave: the AoE queued rage dump (wowsims fury APL: targets > 1). The
    -- rage floor mirrors the prot Heroic-Strike dump so it cannot starve
    -- Bloodthirst/Whirlwind.
    {
        name = "Cleave",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "rage", op = ">=", value = HEROIC_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.Cleave, target = "target" },
    },
    {
        name = "Whirlwind",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 25 },
            { type = "state", field = "whirlwind_cd", op = "<=", value = 0 },
            { type = "state", field = "stance", op = "==", value = STANCE.BERSERKER },
        },
        action = { type = "cast", spell = ACTION.Whirlwind, target = "target" },
    },
    -- Heroic Strike: the single-target queued rage dump, gated on the real
    -- swing clock (prot precedent) so it only queues when the auto is imminent.
    {
        name = "HeroicStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = "<=", value = 1 },
            { type = "state", field = "rage", op = ">=", value = HEROIC_RAGE_MIN },
            { type = "state", field = "heroic_swing_imminent", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.HeroicStrike, target = "target" },
    },
    -- Heroic Throw: the ranged filler the APL falls back to when out of melee
    -- (auto swing + both main CDs unavailable). Gate fails closed in melee.
    {
        name = "HeroicThrow",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "in_melee_range", op = "falsy" },
            { type = "state", field = "heroic_throw_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.HeroicThrow, target = "target" },
    },
    {
        name = "Slam",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 15 },
            -- WotLK Slam is only cast on a Bloodsurge proc (wowsims fury APL:
            -- gcdIsReady + auraIsActive(46916/70847)); the old every-GCD filler
            -- spammed the 1.5s cast and delayed auto attacks.
            { type = "state", field = "bloodsurge_proc", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Slam, target = "target" },
    },
    -- WotLK Fury plays in Berserker Stance (the APL's final lane: cast 2458
    -- when not in Berserker). Whirlwind/Pummel are Berserker-only, so this
    -- dance keeps them reachable (e.g. after a Charge opener in Battle stance).
    {
        name = "BerserkerStance",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return (state.stance or 0) ~= STANCE.BERSERKER
            end },
        },
        action = { type = "cast", spell = ACTION.BerserkerStance, target = "self" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Pummel" },
    { name = "BattleShout" },
    { name = "Recklessness" },
    { name = "DeathWish" },
    { name = "Execute" },
    { name = "Bloodthirst" },
    { name = "Cleave" },
    { name = "Whirlwind" },
    { name = "HeroicStrike" },
    { name = "Slam" },
    { name = "HeroicThrow" },
    { name = "BerserkerStance" },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

-- Register (guarded — nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("fury", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Fury WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
