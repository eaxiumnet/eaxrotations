-- frost_wotlk.lua — Mage Frost rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Frost mage: ColdSnap panic heal, DeepFreeze
--        on frozen targets, FrostfireBolt debuff refresh, IceLance on frozen,
--        Frostbolt filler.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Frostbolt = define("Frostbolt", { 27072, 27071, 25304, 10181, 10180, 10179, 10177, 10176, 10175, 116, 205 }, "Frostbolt"),
    FrostfireBolt = define("FrostfireBolt", 44614, "FrostfireBolt"),
    IceLance = define("IceLance", 30455, "IceLance"),
    DeepFreeze = define("DeepFreeze", 44572, "DeepFreeze"),
    ColdSnap = define("ColdSnap", 12472, "ColdSnap"),
}

local FROSTBOLT_DEBUFF = { 27072, 27071, 25304, 10181, 10180, 10179, 10177, 10176, 10175, 116, 205 }
local FROSTFIRE_BOLT_DEBUFF = { 44614 }
local FROST_NOVA_DEBUFF = { 122, 865, 6131, 10230 }

local frost_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    frostbolt_remains = 0,
    frostfire_remains = 0,
    target_frozen = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(frost_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.frostbolt_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROSTBOLT_DEBUFF)) or 0
    state.frostfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROSTFIRE_BOLT_DEBUFF)) or 0
    state.target_frozen = (target and NS.debuff_up and NS.debuff_up(target, FROST_NOVA_DEBUFF)) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "ColdSnap",
        conditions = {
            { type = "state", field = "hp", op = "<", value = 50 },
        },
        action = { type = "cast", spell = ACTION.ColdSnap, target = "self" },
    },
    {
        name = "DeepFreeze",
        conditions = {
            { type = "state", field = "target_frozen", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.DeepFreeze, target = "target" },
    },
    {
        name = "FrostfireBolt",
        conditions = {
            { type = "state", field = "frostfire_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.FrostfireBolt, target = "target" },
    },
    {
        name = "IceLance",
        conditions = {
            { type = "state", field = "target_frozen", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.IceLance, target = "target" },
    },
    {
        name = "Frostbolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Frostbolt, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "ColdSnap" },
    { name = "DeepFreeze" },
    { name = "FrostfireBolt" },
    { name = "IceLance" },
    { name = "Frostbolt" },
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
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage Frost WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
