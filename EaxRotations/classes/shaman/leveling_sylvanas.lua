-- Shaman leveling rotation.
-- Auto-activates in solo/leveling context or when playstyle = "leveling".
-- Uses shared leveling module for context guard, wand, and common helpers.

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { shaman = {} } } end
local TBC_SHAMAN = (TBC.SPELLS and TBC.SPELLS.shaman) or {}

-- ============================================================================
-- API caching
-- ============================================================================
local _core_time = core.time

-- ============================================================================
-- Module table
-- ============================================================================
local shaman_leveling = {}

-- ============================================================================
-- Context guard
-- ============================================================================
local is_leveling_context = leveling.create_context_guard()

-- ============================================================================
-- Constants
-- ============================================================================
local SPELLS = NS.ShamanSpells or NS.SPELLS or {}
local LIGHTNING_SHIELD_BUFF = TBC_SHAMAN.lightning_shield or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
local WATER_SHIELD_BUFF = TBC_SHAMAN.water_shield or { 33736, 24398, 23575 }
local TOTEM_REFRESH_MS = 110000
local IMBUE_REFRESH_UNKNOWN_MS = 1500000
local SHIELD_REFRESH_UNKNOWN_MS = 300000
local MAIN_HAND_SLOT = 16
local TOTEM_SLOT = {
    fire = 1,
    earth = 2,
    water = 3,
    air = 4,
}

local runtime = {
    last_imbue_ms = -IMBUE_REFRESH_UNKNOWN_MS,
    last_lightning_shield_ms = -SHIELD_REFRESH_UNKNOWN_MS,
    last_fire_totem_ms = -TOTEM_REFRESH_MS,
    last_earth_totem_ms = -TOTEM_REFRESH_MS,
    last_water_totem_ms = -TOTEM_REFRESH_MS,
}

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

-- ============================================================================
-- Strategy helpers
-- ============================================================================

local function now_ms()
    local game_time_ms = NS.game_time_ms
    if type(game_time_ms) == "function" then
        local ok, value = pcall(game_time_ms)
        if ok and type(value) == "number" then return value end
    end
    return _core_time() * 1000
end

local function get_player()
    return (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
end

local function spell_ready(spell_action, target, opts)
    if not spell_action then return false end
    return NS.spell_ready and NS.spell_ready(spell_action, target, opts) or false
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
    if type(buff_ids) ~= "table" then buff_ids = { buff_ids } end
    for i = 1, #buff_ids do
        local ok, result = pcall(function() return me:has_buff(buff_ids[i]) end)
        if ok and result then return true end
    end
    return false
end

local function has_totem(totem_id)
    -- Check if a totem is active by checking for the totem buff
    return has_buff(totem_id)
end

local function get_totem_info(slot)
    local me = get_player()
    if me and me.get_totem_info then
        local ok, have, name, start_time, duration, spell_id = pcall(function()
            return me:get_totem_info(slot)
        end)
        if ok then
            return { have_totem = have == true, totem_name = name, start_time = start_time, duration = duration, spell_id = spell_id }
        end
    end
    local fn = core and core.spell_book and core.spell_book.get_totem_info
    if type(fn) == "function" then
        local ok, info = pcall(fn, slot)
        if ok and type(info) == "table" then return info end
    end
    return nil
end

local function totem_active(element)
    local info = get_totem_info(TOTEM_SLOT[element])
    if not info then return false end
    return info.have_totem == true
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

local function can_retry_unknown_imbue(state)
    return state.now_ms - runtime.last_imbue_ms >= IMBUE_REFRESH_UNKNOWN_MS
end

local function can_drop_totem(state, element, last_ms)
    if (state.mana_pct or 100) < 20 then return false end
    if totem_active(element) then return false end
    return state.now_ms - last_ms >= TOTEM_REFRESH_MS
end

-- ============================================================================
-- State builder
-- ============================================================================

function shaman_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)
    state.now_ms = now_ms()

    -- Shaman-specific spell readiness
    local me = get_player()
    state.lightning_bolt_ready = spell_ready(SPELLS.LightningBolt, state.target)
    state.earth_shock_ready = spell_ready(SPELLS.EarthShock, state.target)
    state.flame_shock_ready = spell_ready(SPELLS.FlameShock, state.target)
    state.frost_shock_ready = spell_ready(SPELLS.FrostShock, state.target)
    state.chain_lightning_ready = spell_ready(SPELLS.ChainLightning, state.target)
    state.lightning_shield_ready = spell_ready(SPELLS.LightningShield, me, { skip_range = true })
    state.water_shield_ready = spell_ready(SPELLS.WaterShield, me, { skip_range = true })
    state.healing_wave_ready = spell_ready(SPELLS.HealingWave, me, { skip_range = true })
    state.lesser_healing_wave_ready = spell_ready(SPELLS.LesserHealingWave, me, { skip_range = true })
    state.ghost_wolf_ready = spell_ready(SPELLS.GhostWolf, me, { skip_range = true })
    state.purge_ready = spell_ready(SPELLS.Purge, state.target)
    state.earthbind_totem_ready = spell_ready(SPELLS.EarthbindTotem, me, { skip_range = true })
    state.stoneclaw_totem_ready = SPELLS.StoneclawTotem and spell_ready(SPELLS.StoneclawTotem, me, { skip_range = true }) or false
    state.fire_nova_totem_ready = spell_ready(SPELLS.FireNovaTotem, me, { skip_range = true })
    state.searing_totem_ready = SPELLS.SearingTotem and spell_ready(SPELLS.SearingTotem, me, { skip_range = true }) or false
    state.strength_of_earth_ready = spell_ready(SPELLS.StrengthOfEarthTotem, me, { skip_range = true })
    state.grace_of_air_ready = spell_ready(SPELLS.GraceOfAirTotem, me, { skip_range = true })
    state.mana_spring_ready = spell_ready(SPELLS.ManaSpringTotem, me, { skip_range = true })
    state.healing_stream_ready = SPELLS.HealingStreamTotem and spell_ready(SPELLS.HealingStreamTotem, me, { skip_range = true }) or false
    state.grounding_totem_ready = spell_ready(SPELLS.GroundingTotem, me, { skip_range = true })
    state.windfury_totem_ready = spell_ready(SPELLS.WindfuryTotem, me, { skip_range = true })
    state.tremor_totem_ready = spell_ready(SPELLS.TremorTotem, me, { skip_range = true })
    state.shield_slot = nil  -- Will be set from game query

    -- Buff checks
    state.has_lightning_shield = has_buff(LIGHTNING_SHIELD_BUFF)
    state.has_water_shield = has_buff(WATER_SHIELD_BUFF)
    state.has_mainhand_imbue, state.weapon_imbue_api_known = mainhand_has_imbue()

    -- Settings
    local settings = context.settings or {}
    state.wand_threshold = settings.leveling_wand_threshold or 30
    state.heal_hp = settings.leveling_heal_hp or 50
    state.use_shocks = settings.leveling_use_shocks ~= false
    state.default_shock = settings.leveling_default_shock or "flame"  -- "flame", "earth", "frost"
    state.use_weapon_imbue = settings.leveling_use_weapon_imbue ~= false
    state.weapon_imbue = select_weapon_imbue(settings.leveling_weapon_imbue)
    state.use_totems = settings.leveling_use_totems ~= false
    state.use_searing_totem = settings.leveling_use_searing_totem ~= false
    state.use_strength_totem = settings.leveling_use_strength_totem ~= false
    state.use_water_totem = settings.leveling_use_water_totem ~= false

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function has_enemy_target(context, state)
    if not context then return false end
    return state.in_combat == true or context.has_valid_enemy_target == true
end

--- Main-hand weapon imbue - maintain OOC
local weapon_imbue_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.use_weapon_imbue then return false end
    if not state.weapon_imbue then return false end
    if state.has_mainhand_imbue then return false end
    if not state.weapon_imbue_api_known and not can_retry_unknown_imbue(state) then return false end
    return spell_ready(state.weapon_imbue, get_player(), { skip_range = true })
end

--- Lightning Shield - maintain OOC
local lightning_shield_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_lightning_shield then return false end
    if not state.lightning_shield_ready then return false end
    if state.now_ms - runtime.last_lightning_shield_ms < SHIELD_REFRESH_UNKNOWN_MS then return false end
    return true
end

--- Healing Wave - emergency heal
local healing_wave_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.healing_wave_ready then return false end
    if state.hp > state.heal_hp then return false end
    return true
end

--- Earth Shock - interrupt
local earth_shock_interrupt_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.earth_shock_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Searing Totem - single target damage assist
local searing_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_searing_totem then return false end
    if not state.searing_totem_ready then return false end
    if not state.target then return false end
    return can_drop_totem(state, "fire", runtime.last_fire_totem_ms)
end

--- Strength of Earth Totem - melee leveling support
local strength_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_strength_totem then return false end
    if not state.strength_of_earth_ready then return false end
    return can_drop_totem(state, "earth", runtime.last_earth_totem_ms)
end

--- Mana/Healing Stream - water totem sustain
local water_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_totems or not state.use_water_totem then return false end
    if state.mana_spring_ready and (state.mana_pct or 100) <= 85 then
        return can_drop_totem(state, "water", runtime.last_water_totem_ms)
    end
    if state.healing_stream_ready and (state.hp or 100) <= 85 then
        return can_drop_totem(state, "water", runtime.last_water_totem_ms)
    end
    return false
end

--- Flame Shock - DoT
local flame_shock_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.flame_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    -- Check if DoT is already up
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.FlameShock) or 0 end)
    if ok and remains and remains > 4 then return false end
    if state.default_shock ~= "flame" then return false end
    return true
end

--- Earth Shock - DPS
local earth_shock_dps_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.earth_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if state.default_shock ~= "earth" then return false end
    return true
end

--- Frost Shock - slow
local frost_shock_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.frost_shock_ready then return false end
    if not state.use_shocks then return false end
    if not state.target then return false end
    if state.default_shock ~= "frost" then return false end
    return true
end

--- Chain Lightning - AoE (3+ enemies)
local chain_lightning_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.chain_lightning_ready then return false end
    if not state.target then return false end
    if state.enemies < 2 then return false end  -- CL on 2+ (splash)
    return true
end

--- Lightning Bolt - primary filler
local lightning_bolt_matches = function(context, state)
    if not state then return false end
    if not has_enemy_target(context, state) then return false end
    if not state.lightning_bolt_ready then return false end
    if not state.target then return false end
    if state.is_moving then return false end
    return true
end

--- Earthbind Totem - kite when overwhelmed
local earthbind_totem_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.earthbind_totem_ready then return false end
    if state.enemies < 3 then return false end
    if state.hp > 50 then return false end
    return true
end

--- Ghost Wolf - OOC travel
local ghost_wolf_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.ghost_wolf_ready then return false end
    if not context.target then return false end
    -- Only shift to wolf if target is far
    local dist = NS.get_distance and NS.get_distance(context.target)
    if dist and dist < 20 then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Weapon imbue
    { name = "WeaponImbue",
      matches = weapon_imbue_matches,
      execute = function(context, state)
          if try_cast(state.weapon_imbue, nil, "[LEVELING] Weapon Imbue", { skip_range = true }) then
              runtime.last_imbue_ms = state.now_ms
              return true
          end
          return false
      end },

    -- OOC: Lightning Shield
    { name = "LightningShield",
      matches = lightning_shield_matches,
      execute = function(context, state)
          if try_cast(SPELLS.LightningShield, nil, "[LEVELING] Lightning Shield", { skip_range = true }) then
              runtime.last_lightning_shield_ms = state.now_ms
              return true
          end
          return false
      end },

    -- Interrupt: Earth Shock
    { name = "EarthShockInterrupt",
      matches = earth_shock_interrupt_matches,
      execute = function(context) return try_cast(SPELLS.EarthShock, context.target, "[LEVELING] Earth Shock") end },

    -- Survival: Healing Wave
    { name = "HealingWave",
      matches = healing_wave_matches,
      execute = function(context) return try_cast(SPELLS.HealingWave, nil, "[LEVELING] Healing Wave", { skip_range = true }) end },

    -- Totems: combat support
    { name = "SearingTotem",
      matches = searing_totem_matches,
      execute = function(context, state)
          if try_cast(SPELLS.SearingTotem, nil, "[LEVELING] Searing Totem", { skip_range = true }) then
              runtime.last_fire_totem_ms = state.now_ms
              return true
          end
          return false
      end },

    { name = "StrengthOfEarthTotem",
      matches = strength_totem_matches,
      execute = function(context, state)
          if try_cast(SPELLS.StrengthOfEarthTotem, nil, "[LEVELING] Strength of Earth Totem", { skip_range = true }) then
              runtime.last_earth_totem_ms = state.now_ms
              return true
          end
          return false
      end },

    { name = "WaterTotem",
      matches = water_totem_matches,
      execute = function(context, state)
          local spell = (state.mana_spring_ready and (state.mana_pct or 100) <= 85) and SPELLS.ManaSpringTotem or SPELLS.HealingStreamTotem
          if try_cast(spell, nil, "[LEVELING] Water Totem", { skip_range = true }) then
              runtime.last_water_totem_ms = state.now_ms
              return true
          end
          return false
      end },

    -- AoE: Chain Lightning
    { name = "ChainLightning",
      matches = chain_lightning_matches,
      execute = function(context) return try_cast(SPELLS.ChainLightning, context.target, "[LEVELING] Chain Lightning") end },

    -- DoT: Flame Shock
    { name = "FlameShock",
      matches = flame_shock_matches,
      execute = function(context) return try_cast(SPELLS.FlameShock, context.target, "[LEVELING] Flame Shock") end },

    -- DPS: Earth Shock
    { name = "EarthShock",
      matches = earth_shock_dps_matches,
      execute = function(context) return try_cast(SPELLS.EarthShock, context.target, "[LEVELING] Earth Shock") end },

    -- Slow: Frost Shock
    { name = "FrostShock",
      matches = frost_shock_matches,
      execute = function(context) return try_cast(SPELLS.FrostShock, context.target, "[LEVELING] Frost Shock") end },

    -- Kite: Earthbind Totem
    { name = "EarthbindTotem",
      matches = earthbind_totem_matches,
      execute = function(context) return try_cast(SPELLS.EarthbindTotem, nil, "[LEVELING] Earthbind Totem") end },

    -- Filler: Lightning Bolt
    { name = "LightningBolt",
      matches = lightning_bolt_matches,
      execute = function(context) return try_cast(SPELLS.LightningBolt, context.target, "[LEVELING] Lightning Bolt") end },

    -- OOC Travel: Ghost Wolf
    { name = "GhostWolf",
      matches = ghost_wolf_matches,
      execute = function(context, state)
          return try_cast(SPELLS.GhostWolf, nil, "[LEVELING] Ghost Wolf", { skip_range = true })
      end },

    -- Wand fallback (when low mana)
    { name = "Wand",
      matches = leveling.create_wand_matches("leveling_wand_threshold", 30),
      execute = function(context) return leveling.execute_wand(context) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = shaman_leveling.build_state })
end

-- ============================================================================
-- Rotation entry point
-- ============================================================================

function shaman_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end

    local state = shaman_leveling.build_state(context)
    if not state then return false end

    -- Evaluate strategies in priority order
    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context, state)
            if ok2 and result then
                return true
            end
        end
    end

    return false
end

NS.log("[Shaman] Leveling rotation loaded")
return shaman_leveling
