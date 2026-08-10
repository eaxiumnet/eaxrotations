-- demonology_wotlk.lua — Warlock Demonology rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Demonology warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.WarlockSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Metamorphosis = define("Metamorphosis", 47241, "Metamorphosis"),
    Immolate = define("Immolate", { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Corruption = define("Corruption", { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    ShadowBolt = define("ShadowBolt", { 47809, 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    SoulFire = define("SoulFire", { 47825, 30545, 27211, 17924, 6353 }, "SoulFire"),
}

local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local METAMORPHOSIS_BUFF = { 47241 }

local DEMO_SCHEMA = {
    hp = 100, target_hp = 100, mana_pct = 100,
    enemy_count = 1, in_combat = false,
    immolate_remains = 0, corruption_remains = 0,
    metamorphosis_up = false,
}

local demonology_state = {}

local function build_state(context)
    local state = spec_kit.safe_state(demonology_state, DEMO_SCHEMA)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.immolate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF)) or 0
    state.corruption_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF)) or 0
    state.metamorphosis_up = (me and NS.buff_up and NS.buff_up(me, METAMORPHOSIS_BUFF)) or false
    return state
end

-- ============================================================================
-- Declarative Strategy DSL definitions (5 strategies, 100% declarative)
-- ============================================================================
local DSL_DEFS = {
    {
        name = "Metamorphosis",
        conditions = {
            { type = "context", field = "in_combat", op = "==", value = true },
            { type = "state", field = "metamorphosis_up", op = "==", value = false },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Metamorphosis, target = "self", label = "[DEMONOLOGY WOTLK] Metamorphosis" },
    },
    {
        name = "Corruption",
        conditions = {
            { type = "state", field = "corruption_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Corruption, target = "target", label = "[DEMONOLOGY WOTLK] Corruption" },
    },
    {
        name = "Immolate",
        conditions = {
            { type = "state", field = "immolate_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Immolate, target = "target", label = "[DEMONOLOGY WOTLK] Immolate" },
    },
    {
        name = "SoulFire",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target", label = "[DEMONOLOGY WOTLK] Soul Fire" },
    },
    {
        name = "ShadowBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target", label = "[DEMONOLOGY WOTLK] Shadow Bolt" },
    },
}

-- ============================================================================
-- Strategies (name-only placeholders; DSL-compiled equivalents replace them)
-- ============================================================================
local strategies = {
    { name = "Metamorphosis" },
    { name = "Corruption" },
    { name = "Immolate" },
    { name = "SoulFire" },
    { name = "ShadowBolt" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock demonology WotLK rotation registered") end
return { strategies = strategies, build_state = build_state }
