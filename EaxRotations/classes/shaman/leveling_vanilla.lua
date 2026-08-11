-- leveling_vanilla.lua — Shaman Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling (lightning bolt, shocks, healing, totems).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 content and mana conservation.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end

local shaman_leveling = {}
local is_leveling_context = leveling.create_context_guard()

local SPELLS = NS.ShamanSpells or NS.SPELLS or {}
local LIGHTNING_SHIELD_BUFF = { 10432, 10431, 8134, 945, 905, 325, 324 }

local MAIN_HAND_SLOT = 16
local TOTEM_SLOT = { fire = 1, earth = 2, water = 3, air = 4 }

local IMBUE_PRIORITY_AUTO = {
    SPELLS.WindfuryWeapon,
    SPELLS.RockbiterWeapon,
    SPELLS.FlametongueWeapon,
}

local IMBUE_BY_SETTING = {
    windfury = SPELLS.WindfuryWeapon,
    rockbiter = SPELLS.RockbiterWeapon,
    flametongue = SPELLS.FlametongueWeapon,
    frostbrand = SPELLS.FrostbrandWeapon,
}

local function now_ms()
    local game_time_ms = NS.game_time_ms
    if type(game_time_ms) == "function" then
        local ok, value = pcall(game_time_ms)
        if ok and type(value) == "number" then return value end
    end
    return ((NS.time_now and NS.time_now()) or 0) * 1000
end

local function get_player()
    return (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
end

local function spell_ready(spell_action, target, opts)
    if not spell_action then return false end
    if not NS.spell_ready then return false end
    local ok, result = pcall(NS.spell_ready, spell_action, target, opts)
    return ok and result == true
end

local function try_cast(spell_action, target, label, opts)
    if not spell_action then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "", opts)
    return ok and result == true
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = get_player()
    if not me then return false end
    if NS.buff_up then
        local ok, result = pcall(NS.buff_up, me, buff_ids)
        if ok and result then return true end
    end
    return false
end

local function totem_active(element)
    local info = NS.get_totem_info and NS.get_totem_info(TOTEM_SLOT[element]) or nil
    if not info then return false end
    return info.have_totem == true
end

local function can_drop_totem(state, element, last_ms)
    if (state.mana_pct or 100) < 20 then return false end
    if totem_active(element) then return false end
    return true
end

local function safe_debuff_remains(unit, debuff_ids)
    if not unit or not NS.debuff_remains then return 0 end
    local ok, remains = pcall(NS.debuff_remains, unit, debuff_ids)
    if not ok or not remains then return 0 end
    return remains
end

local function get_equipped_item(slot)
    local me = get_player()
    if not me or not me.get_item_at_inventory_slot then return nil end
    local ok, item_slot = pcall(function() return me:get_item_at_inventory_slot(slot) end)
    if not ok or type(item_slot) ~= "table" then return nil end
    return item_slot.object or item_slot.item or item_slot[1]
end

local function mainhand_has_imbue()
    local item = get_equipped_item(MAIN_HAND_SLOT)
    if not item then return false, false end
    if item.item_has_enchant then
        local ok, result = pcall(function() return item:item_has_enchant() end)
        if ok then return result == true, true end
    end
    return false, false
end

local function select_weapon_imbue(setting)
    local explicit = IMBUE_BY_SETTING[setting or ""]
    if explicit then return explicit end
    for i = 1, #IMBUE_PRIORITY_AUTO do
        local spell = IMBUE_PRIORITY_AUTO[i]
        if spell_ready(spell, get_player(), { skip_range = true }) then return spell end
    end
    return nil
end

-- Schema for safe_state: Pattern 14 nil-guard defaults.
local LEVELING_VANILLA_SCHEMA = {
    in_combat = false,  mana_pct = 100,  hp = 100,  enemies = 0,
    target = nil,  is_moving = false,  is_pvp = false,
    is_channeling = false,  in_melee_range = false,
    heal_hp = 50,  wand_threshold = 30,  use_shocks = true,
    default_shock = "flame",  use_weapon_imbue = true,
    weapon_imbue = nil,  use_totems = true,
    use_searing_totem = true,  use_strength_totem = true,
    use_water_totem = true,  now_ms = 0,
    has_lightning_shield = false,  has_mainhand_imbue = false,
    lightning_bolt_ready = false,  earth_shock_ready = false,
    flame_shock_ready = false,  frost_shock_ready = false,
    chain_lightning_ready = false,  lightning_shield_ready = false,
    healing_wave_ready = false,  lesser_healing_wave_ready = false,
    ghost_wolf_ready = false,  purge_ready = false,
    earthbind_totem_ready = false,  stoneclaw_totem_ready = false,
    strength_of_earth_ready = false,  grace_of_air_ready = false,
    mana_spring_ready = false,  healing_stream_ready = false,
    grounding_totem_ready = false,  windfury_totem_ready = false,
    tremor_totem_ready = false,  stormstrike_ready = false,
}

function shaman_leveling.build_state(context)
    if not context then return nil end
    local state = {}
    leveling.build_common_state(context, state)
    state.is_pvp = context.is_pvp == true or context.is_arena == true or context.is_battleground == true

    local me = get_player()
    state.lightning_bolt_ready = spell_ready(SPELLS.LightningBolt, state.target)
    state.earth_shock_ready = spell_ready(SPELLS.EarthShock, state.target)
    state.flame_shock_ready = spell_ready(SPELLS.FlameShock, state.target)
    state.frost_shock_ready = spell_ready(SPELLS.FrostShock, state.target)
    state.chain_lightning_ready = spell_ready(SPELLS.ChainLightning, state.target)
    state.lightning_shield_ready = spell_ready(SPELLS.LightningShield, me, { skip_range = true })
    state.healing_wave_ready = spell_ready(SPELLS.HealingWave, me, { skip_range = true })
    state.lesser_healing_wave_ready = spell_ready(SPELLS.LesserHealingWave, me, { skip_range = true })
    state.ghost_wolf_ready = spell_ready(SPELLS.GhostWolf, me, { skip_range = true })
    state.purge_ready = spell_ready(SPELLS.Purge, state.target)
    state.earthbind_totem_ready = spell_ready(SPELLS.EarthbindTotem, me, { skip_range = true })
    state.stoneclaw_totem_ready = SPELLS.StoneclawTotem and spell_ready(SPELLS.StoneclawTotem, me, { skip_range = true }) or false
    state.searing_totem_ready = SPELLS.SearingTotem and spell_ready(SPELLS.SearingTotem, me, { skip_range = true }) or false
    state.strength_of_earth_ready = spell_ready(SPELLS.StrengthOfEarthTotem, me, { skip_range = true })
    state.mana_spring_ready = spell_ready(SPELLS.ManaSpringTotem, me, { skip_range = true })
    state.healing_stream_ready = SPELLS.HealingStreamTotem and spell_ready(SPELLS.HealingStreamTotem, me, { skip_range = true }) or false
    state.grounding_totem_ready = spell_ready(SPELLS.GroundingTotem, me, { skip_range = true })
    state.tremor_totem_ready = spell_ready(SPELLS.TremorTotem, me, { skip_range = true })
    state.stormstrike_ready = spell_ready(SPELLS.Stormstrike, state.target)

    state.has_lightning_shield = has_buff(LIGHTNING_SHIELD_BUFF)
    local _dist = state.target and state.target.get_distance and state.target:get_distance(me)
    state.in_melee_range = _dist and _dist <= 5 or false
    state.has_mainhand_imbue = mainhand_has_imbue()

    state.heal_hp = spec_kit.setting_number(context, "leveling_heal_hp", 50)
    state.use_shocks = spec_kit.setting_bool(context, "leveling_use_shocks", true)
    state.default_shock = spec_kit.setting(context, "leveling_default_shock", "flame")
    state.use_weapon_imbue = spec_kit.setting_bool(context, "leveling_use_weapon_imbue", true)
    state.weapon_imbue = select_weapon_imbue(spec_kit.setting(context, "leveling_weapon_imbue", nil))
    state.use_totems = spec_kit.setting_bool(context, "leveling_use_totems", true)
    state.use_searing_totem = spec_kit.setting_bool(context, "leveling_use_searing_totem", true)
    state.use_strength_totem = spec_kit.setting_bool(context, "leveling_use_strength_totem", true)
    state.use_water_totem = spec_kit.setting_bool(context, "leveling_use_water_totem", true)

    return spec_kit.safe_state(state, LEVELING_VANILLA_SCHEMA)
end

local function has_enemy_target(context, state)
    if not context then return false end
    return state.in_combat == true or context.has_valid_enemy_target == true
end

local weapon_imbue_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.use_weapon_imbue then return false end
    if not state.weapon_imbue then return false end
    if state.has_mainhand_imbue then return false end
    local ready = spell_ready(state.weapon_imbue, get_player(), { skip_range = true })
    return ready
end

local lightning_shield_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_lightning_shield then return false end
    if not state.lightning_shield_ready then return false end
    if NS.buff_remains and NS.buff_remains(NS.PLAYER_UNIT, LIGHTNING_SHIELD_BUFF) > 2 then return false end
    return true
end

local healing_wave_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.healing_wave_ready then return false end
    if (state.hp or 100) > state.heal_hp then return false end
    return true
end

local earth_shock_interrupt_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.earth_shock_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

local searing_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_searing_totem then return false end
    if not state.searing_totem_ready then return false end
    if not state.target then return false end
    return can_drop_totem(state, "fire", 0)
end

local strength_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_strength_totem then return false end
    if not state.strength_of_earth_ready then return false end
    return can_drop_totem(state, "earth", 0)
end

local water_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_water_totem then return false end
    if state.mana_spring_ready and (state.mana_pct or 100) <= 85 then
        return can_drop_totem(state, "water", 0)
    end
    if state.healing_stream_ready and (state.hp or 100) <= 85 then
        return can_drop_totem(state, "water", 0)
    end
    return false
end

local flame_shock_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.flame_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    local remains = safe_debuff_remains(state.target, SPELLS.FlameShock)
    if remains > 4 then return false end
    if (state.default_shock or "flame") ~= "flame" then return false end
    return true
end

local earth_shock_dps_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.earth_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if (state.default_shock or "flame") ~= "earth" then return false end
    return true
end
local earth_shock_dps_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.earth_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if (state.default_shock or "flame") ~= "earth" then return false end
    return true
end

--- Stormstrike — enhancement melee attack (instant, boosts next nature spells)
local stormstrike_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.stormstrike_ready then return false end
    if not state.target then return false end
    if not state.in_melee_range then return false end
    return true
end


local frost_shock_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.frost_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if (state.default_shock or "flame") ~= "frost" then return false end
    return true
end

local chain_lightning_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.chain_lightning_ready then return false end
    if not state.target then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

local lightning_bolt_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.lightning_bolt_ready then return false end
    if not state.target then return false end
    if state.is_moving then return false end
    return true
end

local earthbind_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.earthbind_totem_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 50 then return false end
    return true
end

local lesser_healing_wave_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.lesser_healing_wave_ready then return false end
    if (state.hp or 100) > 40 then return false end
    return true
end

local stoneclaw_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.stoneclaw_totem_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 50 then return false end
    return true
end

local grounding_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.grounding_totem_ready then return false end
    if (state.enemies or 0) < 2 then return false end
    return can_drop_totem(state, "air", 0)
end

local tremor_totem_matches = function(context, state)
    if not state then return false end
    if not state.tremor_totem_ready then return false end
    if not state.in_combat then return false end
    return can_drop_totem(state, "earth", 0)
end

local purge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.purge_ready then return false end
    if not state.target then return false end
    if not state.is_pvp then return false end
    return true
end

local ghost_wolf_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.ghost_wolf_ready then return false end
    if not context.target then return false end
    local dist = NS.get_distance and NS.get_distance(context.target)
    if dist and dist < 20 then return false end
    return true
end

local strategies = {
    { name = "WeaponImbue", matches = weapon_imbue_matches,
      execute = function(context, state)
          if not state then return false end
          return try_cast(state.weapon_imbue, nil, "[LEVELING] Weapon Imbue", { skip_range = true })
      end },
    { name = "LightningShield", matches = lightning_shield_matches,
      execute = function(context, state)
          if not state then return false end
          return try_cast(SPELLS.LightningShield, nil, "[LEVELING] Lightning Shield", { skip_range = true })
      end },
    { name = "EarthShockInterrupt", matches = earth_shock_interrupt_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.EarthShock, context.target, "[LEVELING] Earth Shock") end },
    { name = "HealingWave", matches = healing_wave_matches,
      execute = function(context) return try_cast(SPELLS.HealingWave, nil, "[LEVELING] Healing Wave", { skip_range = true }) end },
    { name = "LesserHealingWave", matches = lesser_healing_wave_matches,
      execute = function(context) return try_cast(SPELLS.LesserHealingWave, nil, "[LEVELING] Lesser Healing Wave", { skip_range = true }) end },
    { name = "SearingTotem", matches = searing_totem_matches,
      execute = function(context, state)
          if not state then return false end
          return try_cast(SPELLS.SearingTotem, nil, "[LEVELING] Searing Totem", { skip_range = true })
      end },
    { name = "StrengthOfEarthTotem", matches = strength_totem_matches,
      execute = function(context, state)
          if not state then return false end
          return try_cast(SPELLS.StrengthOfEarthTotem, nil, "[LEVELING] Strength of Earth Totem", { skip_range = true })
      end },
    { name = "WaterTotem", matches = water_totem_matches,
      execute = function(context, state)
          if not state then return false end
          local spell = (state.mana_spring_ready and (state.mana_pct or 100) <= 85) and SPELLS.ManaSpringTotem or SPELLS.HealingStreamTotem
          return try_cast(spell, nil, "[LEVELING] Water Totem", { skip_range = true })
      end },
    { name = "Stormstrike", matches = stormstrike_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.Stormstrike, context.target, "[LEVELING] Stormstrike") end },
    { name = "GroundingTotem", matches = grounding_totem_matches,
      execute = function(context) return try_cast(SPELLS.GroundingTotem, nil, "[LEVELING] Grounding Totem", { skip_range = true }) end },
    { name = "TremorTotem", matches = tremor_totem_matches,
      execute = function(context) return try_cast(SPELLS.TremorTotem, nil, "[LEVELING] Tremor Totem", { skip_range = true }) end },
    { name = "ChainLightning", matches = chain_lightning_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.ChainLightning, context.target, "[LEVELING] Chain Lightning") end },
    { name = "FlameShock", matches = flame_shock_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.FlameShock, context.target, "[LEVELING] Flame Shock") end },
    { name = "EarthShock", matches = earth_shock_dps_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.EarthShock, context.target, "[LEVELING] Earth Shock") end },
    { name = "Purge", matches = purge_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.Purge, context.target, "[LEVELING] Purge") end },
    { name = "FrostShock", matches = frost_shock_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.FrostShock, context.target, "[LEVELING] Frost Shock") end },
    { name = "EarthbindTotem", matches = earthbind_totem_matches,
      execute = function(context) return try_cast(SPELLS.EarthbindTotem, nil, "[LEVELING] Earthbind Totem") end },
    { name = "StoneclawTotem", matches = stoneclaw_totem_matches,
      execute = function(context) return try_cast(SPELLS.StoneclawTotem, nil, "[LEVELING] Stoneclaw Totem", { skip_range = true }) end },
    { name = "LightningBolt", matches = lightning_bolt_matches,
      execute = function(context) if not context then return false end return try_cast(SPELLS.LightningBolt, context.target, "[LEVELING] Lightning Bolt") end },
    { name = "GhostWolf", matches = ghost_wolf_matches,
      execute = function(context, state) return try_cast(SPELLS.GhostWolf, nil, "[LEVELING] Ghost Wolf", { skip_range = true }) end },
    { name = "Wand",
      matches = leveling.create_wand_matches("leveling_wand_threshold", 30),
      execute = function(context) return leveling.execute_wand(context) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = shaman_leveling.build_state })
end

function shaman_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end
    local state = shaman_leveling.build_state(context)
    if not state then return false end
    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context, state)
            if ok2 and result then return true end
        end
    end
    return false
end

-- [Shaman] Leveling rotation loaded (Classic)
shaman_leveling.strategies = strategies

return shaman_leveling
