-- protection_wotlk.lua — Paladin Protection rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Protection paladin tanking.
-- WHEN:  combat with a valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims WotLK Protection APL with 3.3.5-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocations.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    -- 48999 removed (2026-08-08): wowhead WotLK Classic spell=48999 is Warrior
    -- Counterattack, NOT Avenger's Shield — a rank-list typo (see
    -- tests/run_wotlk_audit_tests.lua WOTLK_REJECTED_IDS).
    AvengersShield = define("AvengersShield", { 48827, 48826, 32700, 32699, 31935 }, "AvengersShield"),
    HammerOfTheRighteous = define("HammerOfTheRighteous", 53595, "HammerOfTheRighteous"),
    ShieldOfRighteousness = define("ShieldOfRighteousness", { 53600, 61411 }, "ShieldOfRighteousness"),
    Consecration = define("Consecration", { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    Judgement = define("Judgement", { 20271, 53407, 53408 }, "Judgement"),
}

local CONSECRATION_DEBUFF = { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }

-- -----------------------------------------------------------------------------
-- State table (raw; safe_state proxy applied in build_state)
-- -----------------------------------------------------------------------------
local protection_state = {
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    consecration_remains = 0,
}

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(protection_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    state.mana_pct = (me and type(me.get_mana_percentage) == "function" and me:get_mana_percentage()) or 100
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.consecration_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CONSECRATION_DEBUFF)) or 0

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "AvengersShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.AvengersShield, target = "target" },
    },
    {
        name = "ShieldOfRighteousness",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ShieldOfRighteousness, target = "target" },
    },
    {
        name = "HammerOfTheRighteous",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.HammerOfTheRighteous, target = "target" },
    },
    {
        name = "Consecration",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "consecration_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Consecration, target = "target" },
    },
    {
        name = "Judgement",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Judgement, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "AvengersShield" },
    { name = "ShieldOfRighteousness" },
    { name = "HammerOfTheRighteous" },
    { name = "Consecration" },
    { name = "Judgement" },
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
if NS.log then NS.log("Paladin Protection WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
