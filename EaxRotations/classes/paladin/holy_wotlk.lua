-- holy_wotlk.lua — Paladin Holy rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Holy paladin.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BeaconOfLight = define("BeaconOfLight", 53563, "BeaconOfLight"),
    HolyShock = define("HolyShock", { 33074, 33073, 33072, 33071, 33070, 20473 }, "HolyShock"),
    FlashOfLight = define("FlashOfLight", { 27137, 27136, 27135, 27134, 27133, 19993, 19941, 19942, 19943, 19750 }, "FlashOfLight"),
    HolyLight = define("HolyLight", { 27136, 27135, 27134, 27133, 19943, 19941, 19942, 19750, 1026, 1025, 1024, 1023, 1022, 635 }, "HolyLight"),
    SacredShield = define("SacredShield", 53601, "SacredShield"),
}

local BEACON_OF_LIGHT_BUFF = { 53563 }
local SACRED_SHIELD_BUFF = { 53601, 53602, 53603, 53604 }

local holy_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    beacon_up = false,
    sacred_shield_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(holy_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.beacon_up = (target and NS.buff_up and NS.buff_up(target, BEACON_OF_LIGHT_BUFF)) or false
    state.sacred_shield_up = (target and NS.buff_up and NS.buff_up(target, SACRED_SHIELD_BUFF)) or false
    return state
end

local function beacon_of_light_matches(context, state)
    return not state.beacon_up
end

local function sacred_shield_matches(context, state)
    return not state.sacred_shield_up
end

local function holy_shock_matches(context, state)
    return state.target_hp < 80
end

local function flash_of_light_matches(context, state)
    return state.target_hp < 70 and state.mana_pct >= 20
end

local function holy_light_matches(context, state)
    return state.target_hp < 50 and state.mana_pct >= 30
end

local strategies = {
    { name = "BeaconOfLight", matches = beacon_of_light_matches, execute = function(ctx) return ACTION.BeaconOfLight and ACTION.BeaconOfLight:cast_safe(ctx.target) end },
    { name = "SacredShield", matches = sacred_shield_matches, execute = function(ctx) return ACTION.SacredShield and ACTION.SacredShield:cast_safe(ctx.target) end },
    { name = "HolyShock", matches = holy_shock_matches, execute = function(ctx) return ACTION.HolyShock and ACTION.HolyShock:cast_safe(ctx.target) end },
    { name = "HolyLight", matches = holy_light_matches, execute = function(ctx) return ACTION.HolyLight and ACTION.HolyLight:cast_safe(ctx.target) end },
    { name = "FlashOfLight", matches = flash_of_light_matches, execute = function(ctx) return ACTION.FlashOfLight and ACTION.FlashOfLight:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("holy", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
