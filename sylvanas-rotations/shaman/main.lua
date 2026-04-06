-- =============================================================================
-- SHAMAN MAIN ROTATION - SYLVANAS FRAMEWORK
-- Contains all rotation logic for elemental, enhancement, and restoration
-- Self-contained version with local Spells and Constants
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local FluxCompat = require("libraries.flux_compat")

-- =============================================================================
-- SPELL DEFINITIONS
-- =============================================================================
local Spells = {
   -- Racials
   BloodFurySP = izi.spell(33697),
   BloodFuryAP = izi.spell(20572),
   Berserking = izi.spell(26297),
   ArcaneTorrent = izi.spell(28730),

   -- Elemental Combat
   LightningBolt = izi.spell(403),
   ChainLightning = izi.spell(421),
   EarthShock = izi.spell(8042),
   EarthShockR1 = izi.spell(8042),
   FlameShock = izi.spell(8050),
   FrostShock = izi.spell(8056),
   ElementalMastery = izi.spell(16166),
   Thunderstorm = izi.spell(51490),
   LavaBurst = izi.spell(51505),

   -- Enhancement
   Stormstrike = izi.spell(17364),
   ShamanisticRage = izi.spell(30823),
   Bloodlust = izi.spell(2825),
   Heroism = izi.spell(32182),
   FeralSpirit = izi.spell(51533),
   WindfuryWeapon = izi.spell(8232),
   FlametongueWeapon = izi.spell(8024),
   FrostbrandWeapon = izi.spell(8033),
   RockbiterWeapon = izi.spell(8017),
   EarthlivingWeapon = izi.spell(51730),
   LightningShield = izi.spell(324),
   WaterShield = izi.spell(52127),
   MaelstromWeapon = izi.spell(53817),

   -- Restoration
   HealingWave = izi.spell(331),
   LesserHealingWave = izi.spell(8004),
   ChainHeal = izi.spell(1064),
   Riptide = izi.spell(61295),
   EarthShield = izi.spell(974),
   NaturesSwiftness = izi.spell(16188),
   ManaTideTotem = izi.spell(16190),
   CurePoison = izi.spell(526),
   CureDisease = izi.spell(2870),
   Purge = izi.spell(370),

   -- Totems - Fire
   SearingTotem = izi.spell(3599),
   MagmaTotem = izi.spell(8190),
   FireNovaTotem = izi.spell(1535),
   FlametongueTotem = izi.spell(8227),
   TotemOfWrath = izi.spell(30706),
   FireElementalTotem = izi.spell(2894),

   -- Totems - Earth
   EarthbindTotem = izi.spell(2484),
   StoneclawTotem = izi.spell(5730),
   StoneskinTotem = izi.spell(8071),
   StrengthOfEarthTotem = izi.spell(8075),
   TremorTotem = izi.spell(8143),
   EarthElementalTotem = izi.spell(2062),

   -- Totems - Water
   HealingStreamTotem = izi.spell(5394),
   ManaSpringTotem = izi.spell(5675),
   CleansingTotem = izi.spell(8170),
   FireResistanceTotem = izi.spell(8181),
   FrostResistanceTotem = izi.spell(8184),

   -- Totems - Air
   WindfuryTotem = izi.spell(8512),
   WrathOfAirTotem = izi.spell(3738),
   GroundingTotem = izi.spell(8177),
   SentryTotem = izi.spell(6495),
   NatureResistanceTotem = izi.spell(10595),
   GraceOfAirTotem = izi.spell(8835),
   TranquilAirTotem = izi.spell(25908),

   -- Items
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   SuperManaPotion = izi.item(22832),
   MajorManaPotion = izi.item(13443),
   DarkRune = izi.item(20520),
   DemonicRune = izi.item(12662),
}

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local Constants = {
   BUFF_ID = {
      WATER_SHIELD = 52127,
      LIGHTNING_SHIELD = 324,
      ELEMENTAL_FOCUS = 16164,
      ELEMENTAL_MASTERY = 16166,
      NATURES_SWIFTNESS = 16188,
      SHAMANISTIC_RAGE = 30823,
      SHAMANISTIC_FOCUS = 43338,
      FLURRY = 16277,
      MAELSTROM_WEAPON = 53817,
      BLOODLUST = 2825,
      HEROISM = 32182,
   },

   DEBUFF_ID = {
      FLAME_SHOCK = 8050,
      STORMSTRIKE = 17364,
      EARTH_SHOCK = 8042,
      FROST_SHOCK = 8056,
   },

   TOTEM_REFRESH_THRESHOLD = 5,

   TWIST = {
      CYCLE_TIME = 10,
      OOM_THRESHOLD = 0.15,
   },
}

-- =============================================================================
-- TOTEM SYSTEM
-- =============================================================================
local totem_state = {
   fire_active = false,
   fire_remaining = 0,
   earth_active = false,
   earth_remaining = 0,
   water_active = false,
   water_remaining = 0,
   air_active = false,
   air_remaining = 0,
}

local FIRE_TOTEM_SPELLS = {
   searing = Spells.SearingTotem,
   magma = Spells.MagmaTotem,
   fire_nova = Spells.FireNovaTotem,
   flametongue = Spells.FlametongueTotem,
   totem_of_wrath = Spells.TotemOfWrath,
}

local EARTH_TOTEM_SPELLS = {
   strength_of_earth = Spells.StrengthOfEarthTotem,
   stoneskin = Spells.StoneskinTotem,
   tremor = Spells.TremorTotem,
   earthbind = Spells.EarthbindTotem,
   stoneclaw = Spells.StoneclawTotem,
}

local WATER_TOTEM_SPELLS = {
   mana_spring = Spells.ManaSpringTotem,
   healing_stream = Spells.HealingStreamTotem,
   cleansing = Spells.CleansingTotem,
   fire_resistance = Spells.FireResistanceTotem,
   frost_resistance = Spells.FrostResistanceTotem,
}

local AIR_TOTEM_SPELLS = {
   windfury = Spells.WindfuryTotem,
   wrath_of_air = Spells.WrathOfAirTotem,
   grounding = Spells.GroundingTotem,
   nature_resistance = Spells.NatureResistanceTotem,
   grace_of_air = Spells.GraceOfAirTotem,
   tranquil_air = Spells.TranquilAirTotem,
}

local function get_totem_info_native(slot)
   local me = izi.me()
   if not me then return false, "", 0, 0 end
   return me:get_totem_info(slot)
end

local function refresh_totem_state()
   local have_fire, name_fire, start_fire, dur_fire = get_totem_info_native(1)
   totem_state.fire_active = have_fire
   totem_state.fire_remaining = have_fire and math.max(0, (start_fire + dur_fire) - core.time()) or 0

   local have_earth, name_earth, start_earth, dur_earth = get_totem_info_native(2)
   totem_state.earth_active = have_earth
   totem_state.earth_remaining = have_earth and math.max(0, (start_earth + dur_earth) - core.time()) or 0

   local have_water, name_water, start_water, dur_water = get_totem_info_native(3)
   totem_state.water_active = have_water
   totem_state.water_remaining = have_water and math.max(0, (start_water + dur_water) - core.time()) or 0

   local have_air, name_air, start_air, dur_air = get_totem_info_native(4)
   totem_state.air_active = have_air
   totem_state.air_remaining = have_air and math.max(0, (start_air + dur_air) - core.time()) or 0
end

local function resolve_totem_spell(key, spell_table)
   return spell_table[key] or spell_table.searing
end

local function totem_allowed(condition, in_group)
   if condition == "never" then return false end
   if condition == "solo" and in_group then return false end
   if condition == "group" and not in_group then return false end
   return true
end

local function track_totem_cast(spell_id)
   -- Placeholder for totem tracking
end

-- =============================================================================
-- HEALING SYSTEM
-- =============================================================================
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local healing_targets = {}
local healing_targets_count = 0

local function scan_healing_targets()
   healing_targets_count = 0
   local in_raid = false
   local members = izi.party and izi.party() or {}
   if #members == 0 and izi.raid then
      members = izi.raid() or {}
   end
   in_raid = #members > 5

   local units_to_scan = in_raid and RAID_UNITS or PARTY_UNITS
   local max_units = in_raid and 40 or 5

   for i = 1, max_units do
      local unit = units_to_scan[i]
      local unit_obj = izi.unit and izi.unit(unit) or nil
      if unit_obj and unit_obj:is_valid() and not unit_obj:is_dead() and unit_obj:is_connected() then
         local in_range = false
         local me = izi.me()
         local is_me = unit == "player" or (me and unit_obj:get_guid() == me:get_guid())
         if is_me then
            in_range = true
         else
            in_range = unit_obj:is_in_range(40)
         end

         if in_range then
            healing_targets_count = healing_targets_count + 1
            local idx = healing_targets_count
            healing_targets[idx] = {
               unit = unit_obj,
               hp = unit_obj:get_health() / unit_obj:get_health_max() * 100,
               is_player = is_me,
            }
         end
      end
   end

   if healing_targets_count > 1 then
      for i = 2, healing_targets_count do
         local val = healing_targets[i]
         local val_hp = val.hp
         local j = i - 1
         while j >= 1 and healing_targets[j].hp > val_hp do
            healing_targets[j + 1] = healing_targets[j]
            j = j - 1
         end
         healing_targets[j + 1] = val
      end
   end
end

local function get_lowest_target(threshold)
   scan_healing_targets()
   if healing_targets_count > 0 then
      local entry = healing_targets[1]
      if entry and entry.hp < threshold then
         return entry.unit, entry.hp
      end
   end
   return nil, 100
end

-- =============================================================================
-- SETTINGS
-- =============================================================================
local function get_settings()
   return {}
end

local function get_setting(key, default)
   local elem = MenuElements[key]
   if not elem then return default end
   local t = elem:get_type()
   if t == "checkbox" then
      return elem:get_state()
   elseif t == "slider_int" or t == "slider_float" then
      return elem:get()
   elseif t == "combobox" then
      return elem:get()
   end
   return default
end

-- =============================================================================
-- FLUXCOMPAT MIDDLEWARE REGISTRATION
-- =============================================================================
FluxCompat.register_trinket_middleware()

FluxCompat.rotation_registry:register_middleware({
   name = "Shaman_Defensive_SR",
   priority = 285,
   is_defensive = true,
   is_gcd_gated = false,
   matches = function(context)
      if not context.in_combat then return false end
      if context.mana_pct > (context.settings.enh_shamanistic_rage_pct or 30) then return false end
      return Spells.ShamanisticRage:is_usable()
   end,
   execute = function(icon, context)
      local ok = Spells.ShamanisticRage:cast(context.me, string.format("[MW] Shamanistic Rage - Mana: %.0f%%", context.mana_pct))
      if ok then return icon end
      return nil
   end,
})

FluxCompat.rotation_registry:register_middleware({
   name = "Shaman_Defensive_Stoneclaw",
   priority = 283,
   is_defensive = true,
   is_gcd_gated = false,
   matches = function(context)
      if not context.in_combat then return false end
      if context.hp > (context.settings.stoneclaw_totem_hp or 40) then return false end
      return Spells.StoneclawTotem:is_usable()
   end,
   execute = function(icon, context)
      local ok = Spells.StoneclawTotem:cast(context.me, string.format("[MW] Stoneclaw Totem - HP: %.0f%%", context.hp))
      if ok then return icon end
      return nil
   end,
})

FluxCompat.rotation_registry:register_middleware({
   name = "Shaman_Burst_Bloodlust",
   priority = 95,
   is_burst = true,
   is_gcd_gated = false,
   matches = function(context)
      if not context.in_combat then return false end
      if not context.has_valid_enemy_target then return false end
      if context.settings.ele_use_bloodlust == false then return false end
      local min_ttd = context.settings.cd_min_ttd or 0
      if min_ttd > 0 and context.ttd > 0 and context.ttd < min_ttd then return false end
      return Spells.Bloodlust:is_usable() or Spells.Heroism:is_usable()
   end,
   execute = function(icon, context)
      if Spells.Bloodlust:is_usable() then
         local ok = Spells.Bloodlust:cast(context.me, "[MW] Bloodlust (Burst)")
         if ok then return icon end
      elseif Spells.Heroism:is_usable() then
         local ok = Spells.Heroism:cast(context.me, "[MW] Heroism (Burst)")
         if ok then return icon end
      end
      return nil
   end,
})

FluxCompat.rotation_registry:register_middleware({
   name = "Shaman_Burst_ElementalMastery",
   priority = 96,
   is_burst = true,
   is_gcd_gated = false,
   matches = function(context)
      if not context.in_combat then return false end
      if not context.has_valid_enemy_target then return false end
      if context.settings.ele_use_elemental_mastery == false then return false end
      local min_ttd = context.settings.cd_min_ttd or 0
      if min_ttd > 0 and context.ttd > 0 and context.ttd < min_ttd then return false end
      return Spells.ElementalMastery:is_usable()
   end,
   execute = function(icon, context)
      local ok = Spells.ElementalMastery:cast(context.me, "[MW] Elemental Mastery (Burst)")
      if ok then return icon end
      return nil
   end,
})

-- =============================================================================
-- STATE FUNCTIONS
-- =============================================================================
local ele_state = {
   clearcasting_charges = 0,
   elemental_mastery_active = false,
   flame_shock_duration = 0,
   chain_lightning_cd = 0,
}

local function get_ele_state(context)
   if context._ele_valid then return ele_state end
   context._ele_valid = true

   local me = context.me
   ele_state.clearcasting_charges = me:buff_remains(Constants.BUFF_ID.ELEMENTAL_FOCUS) > 0 and 2 or (me:buff_stacks(Constants.BUFF_ID.ELEMENTAL_FOCUS) or 0)
   ele_state.elemental_mastery_active = me:buff_remains(Constants.BUFF_ID.ELEMENTAL_MASTERY) > 0
   ele_state.flame_shock_duration = context.flame_shock_duration
   ele_state.chain_lightning_cd = Spells.ChainLightning.cooldown_remains

   return ele_state
end

local enh_state = {
   stormstrike_debuff_duration = 0,
   flame_shock_duration = 0,
   shamanistic_rage_active = false,
   shamanistic_focus_active = false,
   flurry_charges = 0,
}

local function get_enh_state(context)
   if context._enh_valid then return enh_state end
   context._enh_valid = true

   local me = context.me
   enh_state.stormstrike_debuff_duration = context.stormstrike_debuff
   enh_state.flame_shock_duration = context.flame_shock_duration
   enh_state.shamanistic_rage_active = me:buff_remains(Constants.BUFF_ID.SHAMANISTIC_RAGE) > 0
   enh_state.shamanistic_focus_active = me:buff_remains(Constants.BUFF_ID.SHAMANISTIC_FOCUS) > 0
   enh_state.flurry_charges = me:buff_stacks(Constants.BUFF_ID.FLURRY) or 0

   return enh_state
end

local resto_state = {
   earth_shield_charges = 0,
   earth_shield_duration = 0,
   natures_swiftness_active = false,
   mana_tide_cd = 0,
}

local function get_resto_state(context)
   if context._resto_valid then return resto_state end
   context._resto_valid = true

   local focus = core.input.get_focus()
   if focus and focus:is_valid() and not focus:is_dead() then
      resto_state.earth_shield_charges = focus:buff_stacks(Constants.BUFF_ID.EARTH_SHIELD) or 0
      resto_state.earth_shield_duration = focus:buff_remains(Constants.BUFF_ID.EARTH_SHIELD) or 0
   else
      resto_state.earth_shield_charges = 0
      resto_state.earth_shield_duration = 0
   end

   local me = context.me
   resto_state.natures_swiftness_active = me:buff_remains(Constants.BUFF_ID.NATURES_SWIFTNESS) > 0
   resto_state.mana_tide_cd = Spells.ManaTideTotem.cooldown_remains

   return resto_state
end

-- =============================================================================
-- ROTATION FUNCTIONS
-- =============================================================================
local function rotation_elemental(icon, context, state)
   local s = context.settings
   local me = context.me
   local target = context.target

   if s.ele_use_elemental_mastery then
      local min_ttd = s.cd_min_ttd or 0
      if min_ttd <= 0 or context.ttd <= 0 or context.ttd >= min_ttd then
         if Spells.ElementalMastery:is_usable() then
            local ok = Spells.ElementalMastery:cast(me, "[ELE] Elemental Mastery")
            if ok then return icon end
         end
      end
   end

   if Spells.BloodFurySP:is_usable() then
      local ok = Spells.BloodFurySP:cast(me, "[ELE] Blood Fury (SP)")
      if ok then return icon end
   end
   if Spells.Berserking:is_usable() then
      local ok = Spells.Berserking:cast(me, "[ELE] Berserking")
      if ok then return icon end
   end

   if not context.is_moving then
      local threshold = Constants.TOTEM_REFRESH_THRESHOLD

      if not context.fire_elemental_active and (s.ele_fire_totem or "totem_of_wrath") ~= "none" and totem_allowed(s.totem_fire_condition, context.in_group) then
         if not context.totem_fire_active or context.totem_fire_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_fire_totem or "totem_of_wrath", FIRE_TOTEM_SPELLS)
            if spell and spell:is_usable() then
               local ok = spell:cast(me, "[ELE] Fire Totem")
               if ok then return icon end
            end
         end
      end

      local earth_setting = s.ele_earth_totem or "strength_of_earth"
      if earth_setting ~= "none" and totem_allowed(s.totem_earth_condition, context.in_group) then
         if not context.totem_earth_active or context.totem_earth_remaining < threshold then
            local spell = resolve_totem_spell(earth_setting, EARTH_TOTEM_SPELLS)
            if spell and spell:is_usable() then
               local ok = spell:cast(me, "[ELE] Earth Totem")
               if ok then return icon end
            end
         end
      end

      if (s.ele_water_totem or "mana_spring") ~= "none" and totem_allowed(s.totem_water_condition, context.in_group) then
         if not context.totem_water_active or context.totem_water_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_water_totem or "mana_spring", WATER_TOTEM_SPELLS)
            if spell and spell:is_usable() then
               local ok = spell:cast(me, "[ELE] Water Totem")
               if ok then return icon end
            end
         end
      end

      if (s.ele_air_totem or "wrath_of_air") ~= "none" and totem_allowed(s.totem_air_condition, context.in_group) then
         if not context.totem_air_active or context.totem_air_remaining < threshold then
            local spell = resolve_totem_spell(s.ele_air_totem or "wrath_of_air", AIR_TOTEM_SPELLS)
            if spell and spell:is_usable() then
               local ok = spell:cast(me, "[ELE] Air Totem")
               if ok then return icon end
            end
         end
      end
   end

   if s.ele_use_flame_shock then
      if state.flame_shock_duration <= 2 then
         if Spells.FlameShock:is_usable() and target:is_in_range(30) then
            local ok = Spells.FlameShock:cast(target, string.format("[ELE] Flame Shock - DoT: %.1fs", state.flame_shock_duration))
            if ok then return icon end
         end
      end
   end

   if not context.is_moving and state.chain_lightning_cd <= 0 then
      if Spells.ChainLightning:is_usable() and target:is_in_range(30) then
         local ok = Spells.ChainLightning:cast(target, "[ELE] Chain Lightning")
         if ok then return icon end
      end
   end

   if not context.is_moving then
      if Spells.LightningBolt:is_usable() and target:is_in_range(30) then
         local ok = Spells.LightningBolt:cast(target, "[ELE] Lightning Bolt")
         if ok then return icon end
      end
   end

   return nil
end

local function rotation_enhancement(icon, context, state)
   local s = context.settings
   local me = context.me
   local target = context.target

   if Spells.BloodFuryAP:is_usable() then
      local ok = Spells.BloodFuryAP:cast(me, "[ENH] Blood Fury (AP)")
      if ok then return icon end
   end
   if Spells.Berserking:is_usable() then
      local ok = Spells.Berserking:cast(me, "[ENH] Berserking")
      if ok then return icon end
   end

   if s.enh_use_stormstrike then
      if Spells.Stormstrike:is_usable() and target:is_in_melee_range(5) then
         local ok = Spells.Stormstrike:cast(target, "[ENH] Stormstrike")
         if ok then return icon end
      end
   end

   if s.enh_weave_flame_shock and state.flame_shock_duration <= 2 then
      if Spells.FlameShock:is_usable() and target:is_in_range(20) then
         local ok = Spells.FlameShock:cast(target, string.format("[ENH] Flame Shock - DoT: %.1fs", state.flame_shock_duration))
         if ok then return icon end
      end
   end

   if state.shamanistic_focus_active then
      if Spells.EarthShock:is_usable() and target:is_in_range(20) then
         local ok = Spells.EarthShock:cast(target, "[ENH] Earth Shock (Sham. Focus)")
         if ok then return icon end
      end
   end

   if state.stormstrike_debuff_duration > 0 then
      if Spells.EarthShock:is_usable() and target:is_in_range(20) then
         local ok = Spells.EarthShock:cast(target, "[ENH] Earth Shock (SS synergy)")
         if ok then return icon end
      end
   end

   return nil
end

local function rotation_restoration(icon, context, state)
   local s = context.settings
   local me = context.me

   if s.resto_use_natures_swiftness then
      local threshold = s.resto_ns_hp_threshold or 30
      local unit, hp = get_lowest_target(threshold)
      if unit then
         if Spells.NaturesSwiftness:is_usable() then
            local ok = Spells.NaturesSwiftness:cast(me, "[RESTO] Nature's Swiftness (emergency)")
            if ok then return icon end
         end
      end
   end

   if state.natures_swiftness_active then
      local threshold = s.resto_ns_hp_threshold or 30
      local unit, hp = get_lowest_target(threshold)
      if unit then
         if Spells.HealingWave:is_usable() then
            local ok = Spells.HealingWave:cast(unit, string.format("[RESTO] NS + Healing Wave - HP: %.0f%%", hp))
            if ok then return icon end
         end
      end
   end

   if s.resto_maintain_earth_shield then
      local focus = core.input.get_focus()
      if focus and focus:is_valid() and not focus:is_dead() then
         local refresh_at = s.resto_earth_shield_refresh or 2
         if state.earth_shield_charges <= refresh_at then
            if Spells.EarthShield:is_usable() then
               local ok = Spells.EarthShield:cast(focus, string.format("[RESTO] Earth Shield - Charges: %d", state.earth_shield_charges))
               if ok then return icon end
            end
         end
      end
   end

   if s.resto_use_mana_tide then
      if state.mana_tide_cd <= 0 then
         local threshold = s.resto_mana_tide_pct or 65
         if context.mana_pct <= threshold then
            if Spells.ManaTideTotem:is_usable() then
               local ok = Spells.ManaTideTotem:cast(me, string.format("[RESTO] Mana Tide Totem - Mana: %.0f%%", context.mana_pct))
               if ok then return icon end
            end
         end
      end
   end

   local unit, hp = get_lowest_target(90)
   if unit then
      if Spells.ChainHeal:is_usable() then
         local ok = Spells.ChainHeal:cast(unit, string.format("[RESTO] Chain Heal - HP: %.0f%%", hp))
         if ok then return icon end
      end
   end

   return nil
end

-- =============================================================================
-- CONTEXT EXTENSION
-- =============================================================================
local function shaman_context_extend(ctx, me, target)
   ctx.is_moving = not me:is_standing_still()
   ctx.is_mounted = me:is_mounted()

   local members = izi.party and izi.party() or {}
   if #members == 0 and izi.raid then
      members = izi.raid() or {}
   end
   ctx.in_group = #members > 0

   local enemies = izi.enemies(30)
   ctx.enemy_count = #enemies

   refresh_totem_state()
   ctx.totem_fire_active = totem_state.fire_active
   ctx.totem_fire_remaining = totem_state.fire_remaining
   ctx.totem_earth_active = totem_state.earth_active
   ctx.totem_earth_remaining = totem_state.earth_remaining
   ctx.totem_water_active = totem_state.water_active
   ctx.totem_water_remaining = totem_state.water_remaining
   ctx.totem_air_active = totem_state.air_active
   ctx.totem_air_remaining = totem_state.air_remaining

   if ctx.totem_fire_active then
      local _, fire_name = get_totem_info_native(1)
      ctx.fire_elemental_active = fire_name and fire_name:find("Fire Elemental") ~= nil
   else
      ctx.fire_elemental_active = false
   end

   ctx.has_water_shield = me:buff_remains(Constants.BUFF_ID.WATER_SHIELD) > 0
   ctx.water_shield_charges = me:buff_stacks(Constants.BUFF_ID.WATER_SHIELD) or 0
   ctx.has_lightning_shield = me:buff_remains(Constants.BUFF_ID.LIGHTNING_SHIELD) > 0

   ctx.has_clearcasting = me:buff_remains(Constants.BUFF_ID.ELEMENTAL_FOCUS) > 0
   ctx.clearcasting_charges = me:buff_stacks(Constants.BUFF_ID.ELEMENTAL_FOCUS) or 0
   ctx.has_elemental_mastery = me:buff_remains(Constants.BUFF_ID.ELEMENTAL_MASTERY) > 0
   ctx.has_natures_swiftness = me:buff_remains(Constants.BUFF_ID.NATURES_SWIFTNESS) > 0
   ctx.shamanistic_rage_active = me:buff_remains(Constants.BUFF_ID.SHAMANISTIC_RAGE) > 0

   if target and target:is_valid() then
      ctx.flame_shock_duration = target:debuff_remains(Constants.DEBUFF_ID.FLAME_SHOCK)
      ctx.stormstrike_debuff = target:debuff_remains(Constants.DEBUFF_ID.STORMSTRIKE)
      ctx.stormstrike_charges = target:debuff_stacks(Constants.DEBUFF_ID.STORMSTRIKE) or 0
   else
      ctx.flame_shock_duration = 0
      ctx.stormstrike_debuff = 0
      ctx.stormstrike_charges = 0
   end

   ctx._ele_valid = false
   ctx._enh_valid = false
   ctx._resto_valid = false
end

-- =============================================================================
-- MAIN ON_UPDATE CALLBACK
-- =============================================================================
core.register_on_update_callback(function()
   local me = izi.me()
   if not me or not me:is_valid() then
      return
   end

   local s = get_settings()
   local playstyle = s.playstyle or "elemental"

   local ctx = FluxCompat.build_context(shaman_context_extend)
   if not ctx then return end

   ctx.settings = s

   ctx.force_burst = FluxCompat.is_force_active("burst")
   ctx.force_defensive = FluxCompat.is_force_active("defensive")
   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   local result = FluxCompat.rotation_registry:execute_middleware(nil, ctx)
   if result then return end

   if playstyle == "elemental" then
      local ele = get_ele_state(ctx)
      rotation_elemental(nil, ctx, ele)
   elseif playstyle == "enhancement" then
      local enh = get_enh_state(ctx)
      rotation_enhancement(nil, ctx, enh)
   elseif playstyle == "restoration" then
      local resto = get_resto_state(ctx)
      rotation_restoration(nil, ctx, resto)
   end
end)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Shaman main rotation loaded - v1.8.0 (FluxCompat integrated)")
