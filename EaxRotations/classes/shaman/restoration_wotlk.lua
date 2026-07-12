-- restoration_wotlk.lua — Shaman Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration shaman.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Riptide = define("Riptide", 61295, "Riptide"),
    ChainHeal = define("ChainHeal", { 25423, 25422, 10623, 10622, 1064 }, "ChainHeal"),
    HealingWave = define("HealingWave", { 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
    EarthShield = define("EarthShield", { 32594, 32593, 974 }, "EarthShield"),
}

local RIPTIDE_BUFF = { 61295, 61299, 61300, 61301 }
local EARTH_SHIELD_BUFF = { 32594, 32593, 974 }

local restoration_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    riptide_remains = 0,
    earth_shield_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(restoration_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.riptide_remains = (target and NS.buff_remains and NS.buff_remains(target, RIPTIDE_BUFF)) or 0
    state.earth_shield_up = (target and NS.buff_up and NS.buff_up(target, EARTH_SHIELD_BUFF)) or false
    return state
end

local function earth_shield_matches(context, state)
    return not state.earth_shield_up
end

local function riptide_matches(context, state)
    return state.riptide_remains < 3
end

local function chain_heal_matches(context, state)
    return state.enemy_count >= 2 and state.mana_pct >= 25
end

local function healing_wave_matches(context, state)
    return state.target_hp < 70 and state.mana_pct >= 20
end

local strategies = {
    { name = "EarthShield", matches = earth_shield_matches, execute = function(ctx) return ACTION.EarthShield and ACTION.EarthShield:cast_safe(ctx.target) end },
    { name = "Riptide", matches = riptide_matches, execute = function(ctx) return ACTION.Riptide and ACTION.Riptide:cast_safe(ctx.target) end },
    { name = "ChainHeal", matches = chain_heal_matches, execute = function(ctx) return ACTION.ChainHeal and ACTION.ChainHeal:cast_safe(ctx.target) end },
    { name = "HealingWave", matches = healing_wave_matches, execute = function(ctx) return ACTION.HealingWave and ACTION.HealingWave:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
