-- protection_wotlk.lua — Warrior Protection rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Protection warrior tanking: Last Stand
--        emergency, Berserker dance for Pummel (Berserker-only in WotLK),
--        swing-QUEUED Heroic Strike rage dump, Shield Block (rage-gated +
--        need-gated, so it can't starve Shield Slam/Devastate), Shield Slam,
--        Revenge, Thunder Clap AoE debuff refresh, Devastate filler.
-- WHEN:  combat with a valid enemy target; Defensive Stance.
-- WHY:   mirrors SimulationCraft / wowsims WotLK Protection APL with 3.3.5-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocations; cooldown reads via
--         NS.cooldown_remains (never a 99 fallback — action:cooldown_remaining() is
--         mock-only and silently never-fired the ShieldBlock lane in production).

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
    ShieldSlam = define("ShieldSlam", { 47488, 30356, 25258, 23925, 23924, 23923, 23922 }, "ShieldSlam"),
    -- 57823 = WotLK Revenge max rank (the APL casts 57823; 30357 is TBC-era rank 8).
    Revenge = define("Revenge", { 57823, 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 }, "Revenge"),
    Devastate = define("Devastate", { 30022, 30016, 20243 }, "Devastate"),
    HeroicStrike = define("HeroicStrike", { 47450, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    ThunderClap = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    ShieldBlock = define("ShieldBlock", 2565, "ShieldBlock"),
    -- Baseline warrior interrupt (3.3.5): not in the wowsims protection APL, so
    -- it sits outside the pinned order (first, like the rogue Kick template).
    Pummel = define("Pummel", { 6554, 6552 }, "Pummel"),
    LastStand = define("LastStand", 12975, "LastStand"),
    -- 2026-09-09 guide pass: Shockwave 46968 (protection talent, 20s CD,
    -- frontal-cone stun + AP-scaled damage; Wowhead-verified).
    Shockwave = define("Shockwave", 46968, "Shockwave"),
    -- 2026-09-12 guide pass: the two shout upkeep lanes the wowsims prot APL
    -- carries but this file lacked — Commanding Shout 47440 (2-min raid
    -- health buff, 10 rage; APL 'auraShouldRefresh maxOverlap 3s' on self)
    -- and Demoralizing Shout 47437 (WotLK max rank, bridge level 79).
    CommandingShout = define("CommandingShout", 47440, "CommandingShout"),
    DemoralizingShout = define("DemoralizingShout", 47437, "DemoralizingShout"),
    BerserkerStance = define("BerserkerStance", 2458, "BerserkerStance"),
}

local THUNDER_CLAP_DEBUFF = { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
-- Shout upkeep ids (single WotLK max ranks).
local COMMANDING_SHOUT_BUFF = { 47440 }
local DEMORALIZING_SHOUT_DEBUFF = { 47437 }

local SHIELD_BLOCK_RAGE_MIN = 60 -- WotLK Shield Block costs 60 rage
local SHIELD_BLOCK_HP_NEED  = 70 -- ...or use it when the tank is under pressure
local LAST_STAND_HP         = 30 -- emergency HP band (rubric protection item)
local HEROIC_RAGE_MIN       = 30 -- queued Heroic Strike threshold (wowsims prot APL)
local HEROIC_SWING_WINDOW   = 1.0 -- queue HS when the next auto swing lands within 1s
local PUMMEL_RAGE_MIN       = 10 -- Pummel costs 10 rage
local SHOUT_RAGE_MIN        = 10 -- Commanding/Demoralizing Shout cost 10 rage
local SHOUT_REFRESH_SECONDS = 60 -- Commanding Shout 2-min buff: refresh under 1 min
local DEMORALIZING_REFRESH  = 3 -- debuff refresh window (Tclap idiom)

-- -----------------------------------------------------------------------------
-- Cooldown reads go through NS.cooldown_remains / NS.get_spell_cooldown (both
-- 0 when unknown). The old action:cooldown_remaining() call returned nil in
-- production (spell_action exposes no such method), making every caller fall
-- back to 99/999 and silently never-firing the ShieldBlock lane.
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
-- closed so queued Heroic Strike never fires without a real swing clock).
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
local protection_state = {
    rage = 0,
    hp = 100,
    stance = STANCE.DEFENSIVE,
    enemy_count = 1,
    in_combat = false,
    target_is_casting = false,
    tclap_remains = 0,
    shout_remains = 0,
    demoralizing_remains = 0,
    shield_block_ready = false,
    shockwave_ready = false,
    last_stand_ready = false,
    shield_slam_cd = 99,
    revenge_cd = 99,
    pummel_ready = false,
    heroic_swing_imminent = false,
}

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(protection_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    -- Rage via the REAL chain: context.rage (main_sylvanas.lua:814,
    -- power_current(NS.POWER_RAGE)) first, then me:get_power(NS.POWER_RAGE) —
    -- me:get_rage() is mock-only and pinned state.rage at 0 live (W3.4 audit),
    -- collapsing every rage-gated lane (HeroicStrike/ShieldBlock/ShieldSlam/
    -- Revenge/ThunderClap/Devastate) into a production never-lane. Mirrors
    -- bear_wotlk.lua:57-59.
    state.rage = (context and context.rage)
        or (me and me.get_power and me:get_power(NS.POWER_RAGE))
        or 0
    state.hp = (me and type(me.get_health_percentage) == "function" and me:get_health_percentage()) or 100
    state.stance = (me and type(me.get_stance) == "function" and me:get_stance()) or STANCE.DEFENSIVE
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.tclap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF)) or 0
    -- Shout upkeep reads (real buff/debuff APIs; 0 = down → the refresh
    -- windows fire, and once cast the 2-min buff holds the lane off).
    state.shout_remains = (me and NS.buff_remains and NS.buff_remains(me, COMMANDING_SHOUT_BUFF)) or 0
    state.demoralizing_remains = (target and NS.debuff_remains and NS.debuff_remains(target, DEMORALIZING_SHOUT_DEBUFF)) or 0

    -- Cooldown / availability tracking (real API: NS.cooldown_remains, 0 = ready)
    state.shield_block_ready = cd_remaining(ACTION.ShieldBlock) <= 0
    state.last_stand_ready = cd_remaining(ACTION.LastStand) <= 0
    state.shield_slam_cd = cd_remaining(ACTION.ShieldSlam)
    state.revenge_cd = cd_remaining(ACTION.Revenge)
    state.shockwave_ready = cd_remaining(ACTION.Shockwave) <= 0
    state.pummel_ready = cd_remaining(ACTION.Pummel) <= 0
    state.heroic_swing_imminent = swing_time_until(me) <= HEROIC_SWING_WINDOW

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    -- Last Stand is the APL's FIRST priority (schedule 29s/209s) — an emergency
    -- tanking cooldown the rotation previously lacked entirely.
    {
        name = "LastStand",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "last_stand_ready", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = LAST_STAND_HP },
        },
        action = { type = "cast", spell = ACTION.LastStand, target = "self" },
    },
    -- WotLK Pummel is Berserker-stance-only; the tank lives in Defensive, so
    -- this dance makes the interrupt lane actually reachable.
    {
        name = "BerserkerStance",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if (state.stance or 0) == STANCE.BERSERKER then return false end
                return target_is_interruptible(context.target) and state.pummel_ready
            end },
        },
        action = { type = "cast", spell = ACTION.BerserkerStance, target = "self" },
    },
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
    -- WotLK Heroic Strike queues on the next auto swing (APL: rage >= 30, tag 1)
    -- and is checked SECOND, right after Last Stand — not a last-priority
    -- unqueued rage >= 60 dump (which was inverted vs the pinned reference).
    {
        name = "HeroicStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = HEROIC_RAGE_MIN },
            { type = "state", field = "heroic_swing_imminent", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.HeroicStrike, target = "target" },
    },
    -- Shield Block: 60 rage cost + a need condition (tank under pressure or
    -- multi-target) so the WotLK charge economy can't starve Shield Slam /
    -- Devastate by spamming on cooldown.
    {
        name = "ShieldBlock",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "shield_block_ready", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = SHIELD_BLOCK_RAGE_MIN },
            { type = "custom", fn = function(context, state)
                return (state.hp or 100) < SHIELD_BLOCK_HP_NEED or (state.enemy_count or 1) >= 2
            end },
        },
        action = { type = "cast", spell = ACTION.ShieldBlock, target = "self" },
    },
    {
        name = "ShieldSlam",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 20 },
            { type = "state", field = "shield_slam_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.ShieldSlam, target = "target" },
    },
    {
        name = "Revenge",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 5 },
            { type = "state", field = "revenge_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Revenge, target = "target" },
    },
    -- APL upkeep: Commanding Shout (47440) refresh window on self.
    {
        name = "CommandingShout",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "shout_remains", op = "<", value = SHOUT_REFRESH_SECONDS },
            { type = "state", field = "rage", op = ">=", value = SHOUT_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.CommandingShout, target = "self" },
    },
    {
        name = "ThunderClap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "tclap_remains", op = "<", value = 3 },
            { type = "state", field = "rage", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ThunderClap, target = "target" },
    },
    -- APL upkeep: Demoralizing Shout (47437) attack-power debuff refresh —
    -- same maxOverlap-2s shape the sim uses for Tclap/Shout refreshes.
    {
        name = "DemoralizingShout",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "demoralizing_remains", op = "<", value = DEMORALIZING_REFRESH },
            { type = "state", field = "rage", op = ">=", value = SHOUT_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.DemoralizingShout, target = "target" },
    },
    {
        name = "Shockwave",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "shockwave_ready", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Shockwave, target = "target" },
    },
    {
        name = "Devastate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Devastate, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "LastStand" },
    { name = "BerserkerStance" },
    { name = "Pummel" },
    { name = "HeroicStrike" },
    { name = "ShieldBlock" },
    { name = "ShieldSlam" },
    { name = "Revenge" },
    { name = "CommandingShout" },
    { name = "ThunderClap" },
    { name = "DemoralizingShout" },
    { name = "Shockwave" },
    { name = "Devastate" },
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
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Protection WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
