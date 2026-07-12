-- cat_wotlk.lua — Druid Feral Cat rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Feral Cat druid.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    MangleCat = define("MangleCat", { 33983, 33982, 33876 }, "MangleCat"),
    Rake = define("Rake", { 27003, 9904, 1824, 1823, 1822 }, "Rake"),
    Rip = define("Rip", { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
    SavageRoar = define("SavageRoar", 52610, "SavageRoar"),
    FerociousBite = define("FerociousBite", { 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
    Shred = define("Shred", { 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
}

local RAKE_DEBUFF = { 27003, 9904, 1824, 1823, 1822 }
local RIP_DEBUFF = { 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
local SAVAGE_ROAR_BUFF = { 52610 }

local cat_state = {
    hp = 100,
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    rake_remains = 0,
    rip_remains = 0,
    savage_roar_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(cat_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.energy = (me and me.get_energy and me:get_energy()) or 0
    state.combo_points = (me and me.get_combo_points and me:get_combo_points()) or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.rake_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF)) or 0
    state.rip_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF)) or 0
    state.savage_roar_remains = (me and NS.buff_remains and NS.buff_remains(me, SAVAGE_ROAR_BUFF)) or 0
    return state
end

local function savage_roar_matches(context, state)
    return state.savage_roar_remains < 3 and state.combo_points >= 1
end

local function rake_matches(context, state)
    return state.rake_remains < 3 and state.energy >= 40
end

local function rip_matches(context, state)
    return state.rip_remains < 3 and state.combo_points >= 4
end

local function ferocious_bite_matches(context, state)
    return state.combo_points >= 4 and state.target_hp < 25
end

local function mangle_matches(context, state)
    return state.energy >= 45
end

local function shred_matches(context, state)
    return state.energy >= 50
end

local strategies = {
    { name = "SavageRoar", matches = savage_roar_matches, execute = function(ctx) return ACTION.SavageRoar and ACTION.SavageRoar:cast_safe() end },
    { name = "Rip", matches = rip_matches, execute = function(ctx) return ACTION.Rip and ACTION.Rip:cast_safe(ctx.target) end },
    { name = "Rake", matches = rake_matches, execute = function(ctx) return ACTION.Rake and ACTION.Rake:cast_safe(ctx.target) end },
    { name = "FerociousBite", matches = ferocious_bite_matches, execute = function(ctx) return ACTION.FerociousBite and ACTION.FerociousBite:cast_safe(ctx.target) end },
    { name = "MangleCat", matches = mangle_matches, execute = function(ctx) return ACTION.MangleCat and ACTION.MangleCat:cast_safe(ctx.target) end },
    { name = "Shred", matches = shred_matches, execute = function(ctx) return ACTION.Shred and ACTION.Shred:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("cat", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
