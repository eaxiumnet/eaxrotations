-- fury_wotlk.lua — Warrior Fury rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Fury warrior DPS: Battle Shout maintenance,
--        Death Wish CD, Execute execute-range, Bloodthirst filler, Whirlwind AoE,
--        Slam filler.
-- WHEN:  combat with a valid enemy target; Berserker Stance (default for Fury).
-- WHY:   mirrors SimulationCraft / wowsims WotLK Fury APL with 3.3.5-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocations.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Bloodthirst = define("Bloodthirst", { 30335, 25251, 23894, 23893, 23892, 23881 }, "Bloodthirst"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
    Slam = define("Slam", { 47475, 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    Execute = define("Execute", { 47498, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    DeathWish = define("DeathWish", { 12292, 12328 }, "DeathWish"),
    BattleShout = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
}

local BATTLE_SHOUT_BUFF = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }

local EXECUTE_RAGE_MIN = 10

-- -----------------------------------------------------------------------------
-- Cooldown helper: returns remaining seconds, or `fallback` when the action is a
-- raw spell ID (no method) or the method is unavailable. Never errors.
-- -----------------------------------------------------------------------------
local function cd_remaining(action, fallback)
    if action and type(action.cooldown_remaining) == "function" then
        local ok, val = pcall(action.cooldown_remaining, action)
        if ok and type(val) == "number" then return val end
    end
    return fallback or 99
end

-- -----------------------------------------------------------------------------
-- State table (raw; safe_state proxy applied in build_state)
-- -----------------------------------------------------------------------------
local fury_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    battle_shout_up = false,
    execute_ready = false,
    death_wish_ready = false,
}

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(fury_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    state.rage = (me and type(me.get_rage) == "function" and me:get_rage()) or 0
    state.hp = (me and type(me.get_health_percentage) == "function" and me:get_health_percentage()) or 100
    state.target_hp = (target and type(target.get_health_percentage) == "function" and target:get_health_percentage()) or 100
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false

    -- Cooldown / availability tracking
    state.execute_ready = (state.target_hp or 100) < 20
    state.death_wish_ready = cd_remaining(ACTION.DeathWish, 999) <= 0

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
        name = "BattleShout",
        conditions = {
            { type = "state", field = "battle_shout_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BattleShout, target = "self" },
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
        },
        action = { type = "cast", spell = ACTION.Bloodthirst, target = "target" },
    },
    {
        name = "Whirlwind",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Whirlwind, target = "target" },
    },
    {
        name = "Slam",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Slam, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "BattleShout" },
    { name = "DeathWish" },
    { name = "Execute" },
    { name = "Bloodthirst" },
    { name = "Whirlwind" },
    { name = "Slam" },
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
