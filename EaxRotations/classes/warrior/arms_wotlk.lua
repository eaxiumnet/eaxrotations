-- arms_wotlk.lua — Warrior Arms rotation for Wrath of the Lich King (3.3.5a).
-- WHAT:  priority-list strategies for Arms warrior DPS: Rend maintenance, Mortal Strike,
--        Overpower (Taste for Blood), Execute, Bladestorm, Sweeping Strikes, Slam filler,
--        Hamstring PvP root, stance management, Shield Wall/Retaliation defensives.
-- WHEN:  combat with a valid enemy target; Battle Stance default, Berserker for Intercept/Pummel.
-- WHY:   mirrors SimulationCraft / wowsims WotLK Arms APL with 3.3.5a-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace imperative
--         match functions; no on_update() allocations; cooldown reads guarded for raw-ID fallbacks.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Centralized spell resolver via spec_kit (replaces per-spec spell() helper).
local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BattleStance      = define("BattleStance", 2457, "BattleStance"),
    BerserkerStance   = define("BerserkerStance", 2458, "BerserkerStance"),
    BattleShout       = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    CommandingShout   = define("CommandingShout", { 47439, 469 }, "CommandingShout"),
    Charge            = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Intercept         = define("Intercept", { 25275, 20617, 20616, 20252 }, "Intercept"),
    Rend              = define("Rend", { 47465, 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    MortalStrike      = define("MortalStrike", { 47486, 30330, 25248, 21553, 21552, 21551, 12294 }, "MortalStrike"),
    Overpower         = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),
    Execute           = define("Execute", { 47471, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    Bladestorm        = define("Bladestorm", 46924, "Bladestorm"),
    SweepingStrikes   = define("SweepingStrikes", 12328, "SweepingStrikes"),
    Slam              = define("Slam", { 47475, 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    HeroicStrike      = define("HeroicStrike", { 47450, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    ThunderClap       = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    DemoralizingShout = define("DemoralizingShout", { 47437, 25203, 25202, 11556, 11555, 11554, 6190, 1160 }, "DemoralizingShout"),
    Hamstring         = define("Hamstring", { 25212, 7373, 7372, 1715 }, "Hamstring"),
    Pummel            = define("Pummel", { 6554, 6552 }, "Pummel"),
    ShieldWall        = define("ShieldWall", { 871 }, "ShieldWall"),
    Retaliation       = define("Retaliation", 20230, "Retaliation"),
}

-- Debuff / buff ID tables (WotLK rank chains)
local REND_DEBUFF         = { 47465, 25208, 11574, 11573, 6548, 6547, 772 }
local BATTLE_SHOUT_BUFF   = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local DEMO_SHOUT_DEBUFF   = { 47437, 25203, 25202, 11556, 11555, 11554, 6190, 1160 }
local THUNDER_CLAP_DEBUFF = { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }
local HAMSTRING_DEBUFF    = { 25212, 7373, 7372, 1715 }
-- Taste for Blood proc aura (enables Overpower without a dodge). 60503 = rank 1 proc.
local TASTE_FOR_BLOOD_BUFF = { 60503, 56636 }

local REND_REFRESH_SECONDS = 5     -- refresh Rend when remaining < 5s
local EXECUTE_RAGE_MIN     = 10    -- Execute minimum rage cost
local SLAM_RAGE_MIN        = 15    -- Slam minimum rage
local HEROIC_RAGE_MIN      = 60    -- Heroic Strike rage dump threshold

-- -----------------------------------------------------------------------------
-- State table (raw; safe_state proxy applied in build_state)
-- -----------------------------------------------------------------------------
local arms_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    stance = STANCE.BATTLE,
    enemy_count = 1,
    in_combat = false,
    is_moving = false,
    is_pvp = false,
    is_boss = false,
    target_distance = 0,
    target_casting = false,
    rend_remains = 0,
    ms_cd = 99,
    overpower_ready = false,
    overpower_cd = 99,
    execute_ready = false,
    bladestorm_ready = false,
    sweeping_ready = false,
    intercept_ready = false,
    pummel_ready = false,
    charge_ready = false,
    shieldwall_ready = false,
    retaliation_ready = false,
    battle_shout_up = false,
    demo_remains = 0,
    tclap_remains = 0,
    hamstring_remains = 0,
}

-- -----------------------------------------------------------------------------
-- Helpers (nil-guarded against missing NS APIs / raw-ID action fallbacks)
-- -----------------------------------------------------------------------------

-- Cooldown helper: returns remaining seconds, or `fallback` when the action is a
-- raw spell ID (no method) or the method is unavailable. Never errors.
local function cd_remaining(action, fallback)
    if action and type(action.cooldown_remaining) == "function" then
        local ok, val = pcall(action.cooldown_remaining, action)
        if ok and type(val) == "number" then return val end
    end
    return fallback or 99
end

local function is_boss(context)
    if NS and type(NS.gate_cooldown_boss_only) == "function" then
        return NS.gate_cooldown_boss_only() == true
    end
    return false
end

local function target_is_casting(target)
    if not target then return false end
    if type(target.is_casting) == "function" then
        local ok, val = pcall(target.is_casting, target)
        if ok and val then return true end
    end
    return false
end

local function target_is_interruptible(target)
    if NS and type(NS.is_interruptible) == "function" then
        return NS.is_interruptible(target) == true
    end
    return false
end

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(arms_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    -- Player resources
    state.rage = (me and type(me.get_rage) == "function" and me:get_rage()) or 0
    state.hp = (me and type(me.get_health_percentage) == "function" and me:get_health_percentage()) or 100
    state.stance = (me and type(me.get_stance) == "function" and me:get_stance()) or STANCE.BATTLE
    state.is_moving = (context.is_moving == true)

    -- Target state
    state.target_hp = (target and type(target.get_health_percentage) == "function" and target:get_health_percentage()) or 100
    state.target_distance = (context.target_distance or 0)
    state.target_casting = target_is_casting(target)

    -- Encounter context
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.is_pvp = (context.is_pvp == true) or spec_kit.setting_bool(context, "pvp_mode", false)
    state.is_boss = is_boss(context)

    -- Debuff tracking on target
    state.rend_remains = (target and NS.debuff_remains and NS.debuff_remains(target, REND_DEBUFF)) or 0
    state.demo_remains = (target and NS.debuff_remains and NS.debuff_remains(target, DEMO_SHOUT_DEBUFF)) or 0
    state.tclap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF)) or 0
    state.hamstring_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HAMSTRING_DEBUFF)) or 0

    -- Buff tracking on player
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false
    state.overpower_ready = (me and NS.buff_up and NS.buff_up(me, TASTE_FOR_BLOOD_BUFF)) or false

    -- Cooldown / availability tracking (guarded for raw-ID fallbacks)
    state.ms_cd = cd_remaining(ACTION.MortalStrike, 99)
    state.overpower_cd = cd_remaining(ACTION.Overpower, 99)
    state.execute_ready = ((state.target_hp or 100) < 20)
    state.bladestorm_ready = (cd_remaining(ACTION.Bladestorm, 99) <= 0)
    state.sweeping_ready = (cd_remaining(ACTION.SweepingStrikes, 99) <= 0)
    state.intercept_ready = (cd_remaining(ACTION.Intercept, 99) <= 0)
    state.pummel_ready = (cd_remaining(ACTION.Pummel, 99) <= 0)
    state.charge_ready = (cd_remaining(ACTION.Charge, 99) <= 0)
    state.shieldwall_ready = (cd_remaining(ACTION.ShieldWall, 99) <= 0)
    state.retaliation_ready = (cd_remaining(ACTION.Retaliation, 99) <= 0)

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "ShieldWall",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "shieldwall_ready", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.ShieldWall, target = "self" },
    },
    {
        name = "Retaliation",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "retaliation_ready", op = "truthy" },
            { type = "state", field = "is_boss", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Retaliation, target = "self" },
    },
    {
        name = "BattleShout",
        conditions = {
            { type = "state", field = "battle_shout_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BattleShout, target = "self" },
    },
    {
        name = "Charge",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "charge_ready", op = "truthy" },
            { type = "distance", op = ">=", value = 8 },
            { type = "distance", op = "<=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Charge, target = "target" },
    },
    {
        name = "BerserkerStance",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if (state.stance or STANCE.BATTLE) == STANCE.BERSERKER then return false end
                local dist = (state.target_distance or 0)
                local need_intercept = dist >= 8 and dist <= 25 and state.intercept_ready
                local need_pummel = state.target_casting and target_is_interruptible(context.target) and state.pummel_ready
                return need_intercept or need_pummel
            end },
        },
        action = { type = "cast", spell = ACTION.BerserkerStance, target = "self" },
    },
    {
        name = "BattleStance",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if (state.stance or STANCE.BATTLE) == STANCE.BATTLE then return false end
                if (state.rend_remains or 0) < REND_REFRESH_SECONDS then return true end
                if state.overpower_ready then return true end
                return false
            end },
        },
        action = { type = "cast", spell = ACTION.BattleStance, target = "self" },
    },
    {
        name = "Intercept",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "intercept_ready", op = "truthy" },
            { type = "distance", op = ">=", value = 8 },
            { type = "distance", op = "<=", value = 25 },
            { type = "state", field = "rage", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Intercept, target = "target" },
    },
    {
        name = "Pummel",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return target_is_interruptible(context.target)
            end },
            { type = "state", field = "pummel_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Pummel, target = "target" },
    },
    {
        name = "Rend",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 10 },
            { type = "state", field = "rend_remains", op = "<", value = REND_REFRESH_SECONDS },
        },
        action = { type = "cast", spell = ACTION.Rend, target = "target" },
    },
    {
        name = "Overpower",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 5 },
            { type = "custom", fn = function(context, state)
                if state.overpower_ready then return true end
                if (state.overpower_cd or 99) <= 0 then return true end
                return false
            end },
        },
        action = { type = "cast", spell = ACTION.Overpower, target = "target" },
    },
    {
        name = "MortalStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "ms_cd", op = "<=", value = 0 },
            { type = "state", field = "rage", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.MortalStrike, target = "target" },
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
        name = "SweepingStrikes",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "sweeping_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not (NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context and context.target, context, state)) then
                    return false
                end
                return (state.rage or 0) >= 30
            end },
        },
        action = { type = "cast", spell = ACTION.SweepingStrikes, target = "self" },
    },
    {
        name = "Bladestorm",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "bladestorm_ready", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                local aoe = NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
                if not (state.is_boss or aoe) then return false end
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 90) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Bladestorm, target = "target" },
    },
    {
        name = "ThunderClap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not (NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) then
                    return false
                end
                if (state.tclap_remains or 0) >= 3 then return false end
                return (state.rage or 0) >= 20
            end },
        },
        action = { type = "cast", spell = ACTION.ThunderClap, target = "target" },
    },
    {
        name = "DemoralizingShout",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "demo_remains", op = "<", value = 3 },
            { type = "state", field = "rage", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.DemoralizingShout, target = "target" },
    },
    {
        name = "Hamstring",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "is_pvp", op = "truthy" },
            { type = "state", field = "hamstring_remains", op = "<", value = 3 },
            { type = "state", field = "rage", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Hamstring, target = "target" },
    },
    {
        name = "Slam",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "is_moving", op = "falsy" },
            { type = "state", field = "rage", op = ">=", value = SLAM_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.Slam, target = "target" },
    },
    {
        name = "HeroicStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = HEROIC_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.HeroicStrike, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "ShieldWall" },
    { name = "Retaliation" },
    { name = "BattleShout" },
    { name = "Charge" },
    { name = "BerserkerStance" },
    { name = "BattleStance" },
    { name = "Intercept" },
    { name = "Pummel" },
    { name = "Rend" },
    { name = "Overpower" },
    { name = "MortalStrike" },
    { name = "Execute" },
    { name = "SweepingStrikes" },
    { name = "Bladestorm" },
    { name = "ThunderClap" },
    { name = "DemoralizingShout" },
    { name = "Hamstring" },
    { name = "Slam" },
    { name = "HeroicStrike" },
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
    NS.rotation_registry:register("arms", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Arms WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
