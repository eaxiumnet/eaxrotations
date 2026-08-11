-- protection_wotlk.lua — Warrior Protection rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Protection warrior tanking: Shield Block CD,
--        Shield Slam, Revenge, Thunder Clap AoE debuff refresh, Devastate filler,
--        Heroic Strike rage dump.
-- WHEN:  combat with a valid enemy target; Defensive Stance.
-- WHY:   mirrors SimulationCraft / wowsims WotLK Protection APL with 3.3.5-era mechanics.
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
    ShieldSlam = define("ShieldSlam", { 47488, 30356, 25258, 23925, 23924, 23923, 23922 }, "ShieldSlam"),
    Revenge = define("Revenge", { 30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572 }, "Revenge"),
    Devastate = define("Devastate", { 30022, 30016, 20243 }, "Devastate"),
    HeroicStrike = define("HeroicStrike", { 47450, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    ThunderClap = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    ShieldBlock = define("ShieldBlock", 2565, "ShieldBlock"),
    -- Baseline warrior interrupt (3.3.5): not in the wowsims protection APL, so
    -- it sits outside the pinned order (first, like the rogue Kick template).
    Pummel = define("Pummel", { 6554, 6552 }, "Pummel"),
}

local THUNDER_CLAP_DEBUFF = { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }

-- -----------------------------------------------------------------------------
-- Cooldown helper: returns remaining seconds, or `fallback` when unavailable.
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
local protection_state = {
    rage = 0,
    enemy_count = 1,
    in_combat = false,
    target_is_casting = false,
    tclap_remains = 0,
    shield_block_ready = false,
}

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(protection_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    state.rage = (me and type(me.get_rage) == "function" and me:get_rage()) or 0
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    state.tclap_remains = (target and NS.debuff_remains and NS.debuff_remains(target, THUNDER_CLAP_DEBUFF)) or 0
    state.shield_block_ready = cd_remaining(ACTION.ShieldBlock, 999) <= 0

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Pummel",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Pummel, target = "target" },
    },
    {
        name = "ShieldBlock",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "shield_block_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ShieldBlock, target = "self" },
    },
    {
        name = "ShieldSlam",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ShieldSlam, target = "target" },
    },
    {
        name = "Revenge",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Revenge, target = "target" },
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
    {
        name = "Devastate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Devastate, target = "target" },
    },
    {
        name = "HeroicStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.HeroicStrike, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Pummel" },
    { name = "ShieldBlock" },
    { name = "ShieldSlam" },
    { name = "Revenge" },
    { name = "ThunderClap" },
    { name = "Devastate" },
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
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warrior Protection WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
