-- elemental_wotlk.lua — Shaman Elemental rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Elemental shaman.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    FlameShock = define("FlameShock", { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    LavaBurst = define("LavaBurst", 51505, "LavaBurst"),
    LightningBolt = define("LightningBolt", { 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    ChainLightning = define("ChainLightning", { 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    Thunderstorm = define("Thunderstorm", 51490, "Thunderstorm"),
}

local FLAME_SHOCK_DEBUFF = { 25457, 29228, 10448, 10447, 8053, 8052, 8050 }

local elemental_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    flame_shock_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(elemental_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    return state
end

local function flame_shock_matches(context, state)
    return state.flame_shock_remains < 3
end

local function lava_burst_matches(context, state)
    return state.mana_pct >= 20
end

local function chain_lightning_matches(context, state)
    return state.enemy_count >= 2 and state.mana_pct >= 25
end

local function thunderstorm_matches(context, state)
    return state.mana_pct < 50
end

local function lightning_bolt_matches(context, state)
    return state.mana_pct >= 15
end

local strategies = {
    { name = "FlameShock", matches = flame_shock_matches, execute = function(ctx) return ACTION.FlameShock and ACTION.FlameShock:cast_safe(ctx.target) end },
    { name = "LavaBurst", matches = lava_burst_matches, execute = function(ctx) return ACTION.LavaBurst and ACTION.LavaBurst:cast_safe(ctx.target) end },
    { name = "ChainLightning", matches = chain_lightning_matches, execute = function(ctx) return ACTION.ChainLightning and ACTION.ChainLightning:cast_safe(ctx.target) end },
    { name = "Thunderstorm", matches = thunderstorm_matches, execute = function(ctx) return ACTION.Thunderstorm and ACTION.Thunderstorm:cast_safe() end },
    { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(ctx) return ACTION.LightningBolt and ACTION.LightningBolt:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("elemental", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
