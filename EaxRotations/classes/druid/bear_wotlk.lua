-- bear_wotlk.lua — Druid Bear rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Bear druid.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    MangleBear = define("MangleBear", { 33987, 33986, 33878 }, "MangleBear"),
    Lacerate = define("Lacerate", 33745, "Lacerate"),
    SwipeBear = define("SwipeBear", { 26997, 9908, 9754, 769, 780, 779 }, "SwipeBear"),
    Maul = define("Maul", { 26996, 9881, 9880, 9745, 8972, 6809, 6808, 6807 }, "Maul"),
    FeralFaerieFire = define("FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 }, "FeralFaerieFire"),
}

local LACERATE_DEBUFF = { 33745 }
local FAERIE_FIRE_FERAL_DEBUFF = { 27011, 17392, 17391, 17390, 16857 }

local bear_state = {
    hp = 100,
    target_hp = 100,
    rage = 0,
    enemy_count = 1,
    in_combat = false,
    lacerate_remains = 0,
    faerie_fire_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(bear_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.rage = (me and me.get_rage and me:get_rage()) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.lacerate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LACERATE_DEBUFF)) or 0
    state.faerie_fire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_FERAL_DEBUFF)) or 0
    return state
end

local function feral_faerie_fire_matches(context, state)
    return state.faerie_fire_remains < 3
end

local function lacerate_matches(context, state)
    return state.lacerate_remains < 3 and state.rage >= 15
end

local function swipe_matches(context, state)
    return state.enemy_count >= 2 and state.rage >= 15
end

local function mangle_bear_matches(context, state)
    return state.rage >= 15
end

local function maul_matches(context, state)
    return state.rage >= 30
end

local strategies = {
    { name = "FeralFaerieFire", matches = feral_faerie_fire_matches, execute = function(ctx) return ACTION.FeralFaerieFire and ACTION.FeralFaerieFire:cast_safe(ctx.target) end },
    { name = "Lacerate", matches = lacerate_matches, execute = function(ctx) return ACTION.Lacerate and ACTION.Lacerate:cast_safe(ctx.target) end },
    { name = "SwipeBear", matches = swipe_matches, execute = function(ctx) return ACTION.SwipeBear and ACTION.SwipeBear:cast_safe(ctx.target) end },
    { name = "MangleBear", matches = mangle_bear_matches, execute = function(ctx) return ACTION.MangleBear and ACTION.MangleBear:cast_safe(ctx.target) end },
    { name = "Maul", matches = maul_matches, execute = function(ctx) return ACTION.Maul and ACTION.Maul:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("bear", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
