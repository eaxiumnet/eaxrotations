-- leveling_wotlk.lua — Shaman leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for shaman leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple shock/bolt rotation with emergency heal.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local SPELLS = NS.ShamanSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    LightningBolt = define("LightningBolt", { 49238, 25449, 25448, 15208, 15207, 10392, 10391, 6041, 943, 915, 548, 529, 403 }, "LightningBolt"),
    EarthShock = define("EarthShock", { 49231, 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
    FlameShock = define("FlameShock", { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    LavaBurst = define("LavaBurst", 51505, "LavaBurst"),
    Stormstrike = define("Stormstrike", 17364, "Stormstrike"),
    HealingWave = define("HealingWave", { 49273, 25396, 25391, 25357, 10396, 10395, 8005, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
    WindShear = define("WindShear", 57994, "WindShear"),
    LightningShield = define("LightningShield", { 49281, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
    FlametongueWeapon = define("FlametongueWeapon", { 58790, 58789, 25489, 16342, 16341, 16339, 8030, 8027, 8024 }, "FlametongueWeapon"),
    -- Searing Totem / Chain Lightning ranks (lexxer); removed invalid 6367/25028/15115-17.
    SearingTotem = define("SearingTotem", { 58704, 58703, 25533, 10438, 10437, 6365, 6364, 6363, 3599 }, "SearingTotem"),
    ChainLightning = define("ChainLightning", { 49271, 49270, 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    MagmaTotem = define("MagmaTotem", { 58734, 58733, 25552, 10587, 10586, 10585, 8190 }, "MagmaTotem"),
}

local LIGHTNING_SHIELD_BUFF = { 49281, 49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local _core_time = _G.core and _G.core.time
local function time_now() return (_core_time and _core_time()) or 0 end
local _last_flametongue = -1e9
local _last_searing = -1e9
local _last_magma = -1e9

local FLAME_SHOCK_DEBUFF = { 49233, 25457, 29228, 10448, 10447, 8053, 8052, 8050 }

local shaman_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    flame_shock_remains = 0,
    target_casting = false,
    lightning_shield_up = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(shaman_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.flame_shock_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FLAME_SHOCK_DEBUFF)) or 0
    state.target_casting = helpers.should_interrupt(target)
    state.lightning_shield_up = (me and NS.buff_up and NS.buff_up(me, LIGHTNING_SHIELD_BUFF)) or false
    return state
end

local function healing_wave_matches(context, state)
    return state.in_combat and state.hp < 50 and state.mana_pct >= 25
end

local function flame_shock_matches(context, state)
    return state.in_combat and state.flame_shock_remains < 3 and state.mana_pct >= 15
end

local function lava_burst_matches(context, state)
    -- Lava Burst is only worth casting while Flame Shock is on the target (guaranteed crit).
    return state.in_combat and state.flame_shock_remains > 0 and state.mana_pct >= 20
end

local function stormstrike_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local function earth_shock_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function lightning_bolt_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function chain_lightning_matches(context, state)
    return state.in_combat and state.enemy_count >= 2 and state.mana_pct >= 20
end

local function magma_totem_matches(context, state)
    -- Fire AoE totem for tight packs; throttle recast to avoid GCD spam.
    return state.in_combat and state.enemy_count >= 3 and (time_now() - _last_magma) >= 18 and state.mana_pct >= 20
end

local function wind_shear_matches(context, state)
    return state.in_combat and state.target_casting == true
end

local function lightning_shield_matches(context, state)
    return not state.lightning_shield_up and state.mana_pct >= 5
end

local function flametongue_weapon_matches(context, state)
    -- Weapon imbues have no player aura; re-apply out of combat on a long throttle.
    return not state.in_combat and (time_now() - _last_flametongue) >= 1500 and state.mana_pct >= 5
end

local function searing_totem_matches(context, state)
    -- Fire totem lasts ~60s; recast in combat on a throttle to avoid GCD spam.
    return state.in_combat and state.enemy_count >= 1 and (time_now() - _last_searing) >= 55 and state.mana_pct >= 10
end

local strategies = {
    { name = "WindShear", matches = wind_shear_matches, execute = function(ctx) return ACTION.WindShear and ACTION.WindShear:cast_safe(ctx.target) end },
    { name = "HealingWave", matches = healing_wave_matches, execute = function(ctx) return ACTION.HealingWave and ACTION.HealingWave:cast_safe() end },
    { name = "LightningShield", matches = lightning_shield_matches, execute = function(ctx) return ACTION.LightningShield and ACTION.LightningShield:cast_safe() end },
    { name = "FlametongueWeapon", matches = flametongue_weapon_matches, execute = function(ctx) if ACTION.FlametongueWeapon and ACTION.FlametongueWeapon:cast_safe() then _last_flametongue = time_now(); return true end return false end },
    { name = "SearingTotem", matches = searing_totem_matches, execute = function(ctx) if ACTION.SearingTotem and ACTION.SearingTotem:cast_safe() then _last_searing = time_now(); return true end return false end },
    { name = "MagmaTotem", matches = magma_totem_matches, execute = function(ctx) if ACTION.MagmaTotem and ACTION.MagmaTotem:cast_safe() then _last_magma = time_now(); return true end return false end },
    { name = "ChainLightning", matches = chain_lightning_matches, execute = function(ctx) return ACTION.ChainLightning and ACTION.ChainLightning:cast_safe(ctx.target) end },
    { name = "FlameShock", matches = flame_shock_matches, execute = function(ctx) return ACTION.FlameShock and ACTION.FlameShock:cast_safe(ctx.target) end },
    { name = "LavaBurst", matches = lava_burst_matches, execute = function(ctx) return ACTION.LavaBurst and ACTION.LavaBurst:cast_safe(ctx.target) end },
    { name = "Stormstrike", matches = stormstrike_matches, execute = function(ctx) return ACTION.Stormstrike and ACTION.Stormstrike:cast_safe(ctx.target) end },
    { name = "EarthShock", matches = earth_shock_matches, execute = function(ctx) return ACTION.EarthShock and ACTION.EarthShock:cast_safe(ctx.target) end },
    { name = "LightningBolt", matches = lightning_bolt_matches, execute = function(ctx) return ACTION.LightningBolt and ACTION.LightningBolt:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
