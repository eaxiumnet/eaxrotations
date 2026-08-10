-- shadow_wotlk.lua — Priest Shadow rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Shadow priest: DoT maintenance
--        (VampiricTouch, ShadowWordPain, DevouringPlague), Mind Blast filler,
--        Mind Flay channel filler.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.PriestSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    VampiricTouch = define("VampiricTouch", { 48160, 34917, 34916, 34914 }, "VampiricTouch"),
    ShadowWordPain = define("ShadowWordPain", { 48125, 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
    DevouringPlague = define("DevouringPlague", { 48300, 25467, 19280, 19279, 19278, 19277, 19276, 2944 }, "DevouringPlague"),
    MindBlast = define("MindBlast", { 48127, 25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }, "MindBlast"),
    MindFlay = define("MindFlay", { 48156, 25387, 18807, 17314, 17313, 17312, 17311, 15407 }, "MindFlay"),
}

local VAMPIRIC_TOUCH_DEBUFF = { 34917, 34916, 34914 }
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local DEVOURING_PLAGUE_DEBUFF = { 25467, 19280, 19279, 19278, 19277, 19276, 2944 }

local shadow_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    vampiric_touch_remains = 0,
    shadow_word_pain_remains = 0,
    devouring_plague_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(shadow_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.vampiric_touch_remains = (target and NS.debuff_remains and NS.debuff_remains(target, VAMPIRIC_TOUCH_DEBUFF)) or 0
    state.shadow_word_pain_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SHADOW_WORD_PAIN_DEBUFF)) or 0
    state.devouring_plague_remains = (target and NS.debuff_remains and NS.debuff_remains(target, DEVOURING_PLAGUE_DEBUFF)) or 0
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "VampiricTouch",
        conditions = {
            { type = "state", field = "vampiric_touch_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.VampiricTouch, target = "target" },
    },
    {
        name = "ShadowWordPain",
        conditions = {
            { type = "state", field = "shadow_word_pain_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.ShadowWordPain, target = "target" },
    },
    {
        name = "DevouringPlague",
        conditions = {
            { type = "state", field = "devouring_plague_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.DevouringPlague, target = "target" },
    },
    {
        name = "MindBlast",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MindBlast, target = "target" },
    },
    {
        name = "MindFlay",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.MindFlay, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "DevouringPlague" },
    { name = "ShadowWordPain" },
    { name = "VampiricTouch" },
    { name = "MindBlast" },
    { name = "MindFlay" },
}

-- Priority order mirrors wowsims shadow APL (ui/shadow_priest/apls/default.apl.json):
-- DP > SWP > VT > MindBlast > MindFlay.
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
    NS.rotation_registry:register("shadow", strategies, { get_state = build_state })
end
if NS.log then NS.log("Priest Shadow WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
