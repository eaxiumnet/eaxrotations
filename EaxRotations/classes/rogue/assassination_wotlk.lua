-- assassination_wotlk.lua — Rogue Assassination rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Assassination rogue.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.RogueSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    HungerForBlood = define("HungerForBlood", 51662, "HungerForBlood"),
    Mutilate = define("Mutilate", { 48666, 34413, 34412, 34411, 1329 }, "Mutilate"),
    Envenom = define("Envenom", { 57993, 32645, 32684 }, "Envenom"),
    Rupture = define("Rupture", { 48672, 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    TricksOfTheTrade = define("TricksOfTheTrade", 57934, "TricksOfTheTrade"),
    SliceAndDice = define("SliceAndDice", { 6774, 5171 }, "SliceAndDice"),
}

local RUPTURE_DEBUFF = { 26867, 11275, 11274, 11273, 8640, 8639, 1943 }
local SLICE_AND_DICE_BUFF = { 6774, 5171 }

local assassination_state = {
    hp = 100,
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    rupture_remains = 0,
    snd_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(assassination_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.energy = (me and me.get_energy and me:get_energy()) or 0
    state.combo_points = (me and me.get_combo_points and me:get_combo_points()) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.rupture_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RUPTURE_DEBUFF)) or 0
    state.snd_remains = (me and NS.buff_remains and NS.buff_remains(me, SLICE_AND_DICE_BUFF)) or 0
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "TricksOfTheTrade",
        conditions = {},
        action = { type = "cast", spell = ACTION.TricksOfTheTrade, target = "self" },
    },
    {
        name = "HungerForBlood",
        conditions = {},
        action = { type = "cast", spell = ACTION.HungerForBlood, target = "target" },
    },
    {
        name = "SliceAndDice",
        conditions = {
            { type = "state", field = "snd_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.SliceAndDice, target = "self" },
    },
    {
        name = "Rupture",
        conditions = {
            { type = "state", field = "rupture_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 1 },
        },
        action = { type = "cast", spell = ACTION.Rupture, target = "target" },
    },
    {
        name = "Envenom",
        conditions = {
            { type = "state", field = "combo_points", op = ">=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.Envenom, target = "target" },
    },
    {
        name = "Mutilate",
        conditions = {
            { type = "state", field = "energy", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Mutilate, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL). Priority preserved.
-- -----------------------------------------------------------------------------
-- Priority order mirrors wowsims mutilate APL (ui/rogue/apls/mutilate.apl.json):
-- SnD > HfB > Tricks > Envenom > Mutilate (Rupture unconstrained by fixture,
-- kept after SnD maintenance).
local strategies = {
    { name = "SliceAndDice" },
    { name = "Rupture" },
    { name = "HungerForBlood" },
    { name = "TricksOfTheTrade" },
    { name = "Envenom" },
    { name = "Mutilate" },
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

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("assassination", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
