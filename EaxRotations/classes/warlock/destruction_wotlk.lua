-- destruction_wotlk.lua — Warlock Destruction rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Destruction warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarlockSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Immolate = define("Immolate", { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    ChaosBolt = define("ChaosBolt", 50796, "ChaosBolt"),
    Incinerate = define("Incinerate", { 32231, 29722 }, "Incinerate"),
    Conflagrate = define("Conflagrate", { 30912, 27266, 18932, 18931, 18930, 17962 }, "Conflagrate"),
    SoulFire = define("SoulFire", { 30545, 27211, 17924, 6353 }, "SoulFire"),
}

local IMMOLATE_DEBUFF = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }

local destruction_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    immolate_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(destruction_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.immolate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF)) or 0
    return state
end

local function immolate_matches(context, state)
    return state.immolate_remains < 3
end

local function conflagrate_matches(context, state)
    return state.immolate_remains > 3
end

local function chaos_bolt_matches(context, state)
    return state.mana_pct >= 20
end

local function incinerate_matches(context, state)
    return state.mana_pct >= 20
end

local function soul_fire_matches(context, state)
    return state.mana_pct >= 30
end

local strategies = {
    { name = "Immolate", matches = immolate_matches, execute = function(ctx) return ACTION.Immolate and ACTION.Immolate:cast_safe(ctx.target) end },
    { name = "Conflagrate", matches = conflagrate_matches, execute = function(ctx) return ACTION.Conflagrate and ACTION.Conflagrate:cast_safe(ctx.target) end },
    { name = "ChaosBolt", matches = chaos_bolt_matches, execute = function(ctx) return ACTION.ChaosBolt and ACTION.ChaosBolt:cast_safe(ctx.target) end },
    { name = "Incinerate", matches = incinerate_matches, execute = function(ctx) return ACTION.Incinerate and ACTION.Incinerate:cast_safe(ctx.target) end },
    { name = "SoulFire", matches = soul_fire_matches, execute = function(ctx) return ACTION.SoulFire and ACTION.SoulFire:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("destruction", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
