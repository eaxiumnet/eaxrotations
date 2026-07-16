-- demonology_wotlk.lua — Warlock Demonology rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Demonology warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarlockSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Metamorphosis = define("Metamorphosis", 47241, "Metamorphosis"),
    Immolate = define("Immolate", { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Corruption = define("Corruption", { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    ShadowBolt = define("ShadowBolt", { 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    SoulFire = define("SoulFire", { 30545, 27211, 17924, 6353 }, "SoulFire"),
}

local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local METAMORPHOSIS_BUFF = { 47241 }

local demonology_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    immolate_remains = 0,
    corruption_remains = 0,
    metamorphosis_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(demonology_state)
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

local function metamorphosis_matches(context, state)
    if not state.in_combat then return false end
    if state.metamorphosis_up then return false end
    if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
    return true
end

local function immolate_matches(context, state)
    return state.immolate_remains < 3
end

local function corruption_matches(context, state)
    return state.corruption_remains < 3
end

local function soul_fire_matches(context, state)
    return state.mana_pct >= 30
end

local function shadow_bolt_matches(context, state)
    return state.mana_pct >= 20
end

local strategies = {
    { name = "Metamorphosis", matches = metamorphosis_matches, execute = function(ctx) return ACTION.Metamorphosis and ACTION.Metamorphosis:cast_safe() end },
    { name = "Immolate", matches = immolate_matches, execute = function(ctx) return ACTION.Immolate and ACTION.Immolate:cast_safe(ctx.target) end },
    { name = "Corruption", matches = corruption_matches, execute = function(ctx) return ACTION.Corruption and ACTION.Corruption:cast_safe(ctx.target) end },
    { name = "SoulFire", matches = soul_fire_matches, execute = function(ctx) return ACTION.SoulFire and ACTION.SoulFire:cast_safe(ctx.target) end },
    { name = "ShadowBolt", matches = shadow_bolt_matches, execute = function(ctx) return ACTION.ShadowBolt and ACTION.ShadowBolt:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
