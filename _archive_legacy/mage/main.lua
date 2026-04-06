-- =============================================================================
-- MAGE MAIN ROTATION - SYLVANAS FRAMEWORK
-- Contains all rotation logic for Fire, Frost, and Arcane playstyles
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
   Berserking = izi.spell(26297),
   ArcaneTorrent = izi.spell(28730),
   BloodFury = izi.spell(20572),

   -- Fire
   Fireball = izi.spell(38692),
   Scorch = izi.spell(27074),
   FireBlast = izi.spell(27079),
   Pyroblast = izi.spell(33938),
   Combustion = izi.spell(11129),
   BlastWave = izi.spell(33043),
   DragonsBreath = izi.spell(33042),
   Flamestrike = izi.spell(27086),
   MoltenArmor = izi.spell(30482),

   -- Frost
   Frostbolt = izi.spell(38697),
   IceLance = izi.spell(30455),
   ConeOfCold = izi.spell(27087),
   Blizzard = izi.spell(27085),
   FrostNova = izi.spell(27088),
   IceBarrier = izi.spell(33405),
   IceBlock = izi.spell(45438),
   IcyVeins = izi.spell(12472),
   ColdSnap = izi.spell(11958),
   SummonWaterElemental = izi.spell(31687),
   IceArmor = izi.spell(27124),

   -- Arcane
   ArcaneMissiles = izi.spell(38699),
   ArcaneExplosion = izi.spell(27080),
   ArcaneBlast = izi.spell(30451),
   ArcanePower = izi.spell(12042),
   PresenceOfMind = izi.spell(12043),
   Evocation = izi.spell(12051),
   MageArmor = izi.spell(27125),
   Slow = izi.spell(31589),

   -- Utility
   Counterspell = izi.spell(2139),
   RemoveLesserCurse = izi.spell(475),
   Blink = izi.spell(1953),
   Invisibility = izi.spell(66),
   ConjureWater = izi.spell(27089),
   ConjureFood = izi.spell(33717),

   -- Buffs
   SelfArcaneIntellect = izi.spell(27126),
   SelfArcaneBrilliance = izi.spell(27127),
   ManaShield = izi.spell(27131),

   -- Items
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   SuperManaPotion = izi.item(22832),
   MajorManaPotion = izi.item(13443),
   ManaEmerald = izi.item(22044),
   ManaRuby = izi.item(22043),
   ManaCitrine = izi.item(22042),
   DarkRune = izi.item(20520),
   DemonicRune = izi.item(12662),
}

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local Constants = {
   BUFF_ID = {
      COMBUSTION = 11129,
      ICY_VEINS = 12472,
      ARCANE_POWER = 12042,
      PRESENCE_OF_MIND = 12043,
      CLEARCASTING = 12536,
      ICE_BARRIER = 33405,
      ICE_BLOCK = 45438,
      MANA_SHIELD = 27131,
      MOLTEN_ARMOR = 30482,
      MAGE_ARMOR = 27125,
      ICE_ARMOR = 27124,
      ARCANE_INTELLECT = 27126,
      ARCANE_BRILLIANCE = 27127,
      SURGE_OF_LIGHT = 58802,
      HOT_STREAK = 48108,
   },

   DEBUFF_ID = {
      IMPROVED_SCORCH = 22959,
      WINTERS_CHILL = 12579,
      FROSTBITE = 12494,
      SLOW = 31589,
      ARCANE_BLAST = 36032,
      HOLY_FIRE_DOT = 14914,
      HYPOTHERMIA = 41425,
   },

   SCORCH = {
      MAX_STACKS = 5,
      DEFAULT_REFRESH = 3,
   },

   ARCANE = {
      DEFAULT_START_CONSERVE = 20,
      DEFAULT_STOP_CONSERVE = 80,
      DEFAULT_BLASTS_BEFORE_FILLER = 3,
   },

   BLOODLUST_IDS = {2825, 32182, 80353},
   ARMOR_BUFF_IDS = {30482, 27125, 27124, 7302},
   INTELLECT_BUFF_IDS = {27126, 27127, 1459, 23028},
}

-- =============================================================================
-- LOAD MIDDLEWARE
-- =============================================================================
require("mage/middleware")

-- =============================================================================
-- DEFAULTS
-- =============================================================================
local defaults = {
   playstyle = "fire",
   aoe_threshold = 3,
   cd_min_ttd = 15,
   use_racial = true,
   use_trinkets = true,
   fire_maintain_scorch = true,
   fire_scorch_refresh = 3,
   fire_primary_spell = "fireball",
   fire_weave_fire_blast = true,
   fire_use_blast_wave = true,
   fire_use_dragons_breath = true,
   fire_use_combustion = true,
   fire_combustion_below_hp = 30,
   fire_use_icy_veins = true,
   frost_use_icy_veins = true,
   frost_use_cold_snap = true,
   frost_use_water_elemental = true,
   arcane_use_arcane_power = true,
   arcane_use_pom = true,
   arcane_use_icy_veins = true,
   arcane_use_cold_snap = true,
   arcane_filler = "arcane_missiles",
   arcane_blasts_between_fillers = 3,
   arcane_start_conserve_pct = 20,
   arcane_stop_conserve_pct = 80,
   use_ice_block = true,
   ice_block_hp = 15,
   use_mana_shield = true,
   mana_shield_hp = 30,
   use_ice_barrier = true,
   use_counterspell = true,
   healthstone_hp = 35,
   use_healing_potion = true,
   healing_potion_hp = 25,
   use_mana_gem = true,
   mana_gem_pct = 70,
   use_mana_potion = true,
   mana_potion_pct = 50,
   use_dark_rune = true,
   dark_rune_pct = 50,
   dark_rune_min_hp = 50,
   use_evocation = true,
   evocation_pct = 15,
}

-- =============================================================================
-- PHASE TRACKING
-- =============================================================================
local arcane_phase = "burn"

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================
local function get_setting(key)
   return defaults[key]
end

local function try_cast(spell, target, msg)
   if not spell or not spell:is_learned() then
      return false
   end
   if not spell:is_usable() then
      return false
   end
   if target then
      if not spell:is_castable_to_unit(target) then
         return false
      end
   end
   return spell:cast(target, msg or "")
end

local function try_cast_gcd(spell, target, msg)
   if not spell or not spell:is_learned() then
      return false
   end
   local me = izi.me()
   if me:gcd_remains() > 0.1 then
      return false
   end
   if target then
      if not spell:is_castable_to_unit(target) then
         return false
      end
   end
   return spell:cast(target, msg or "")
end

local function get_me()
   return izi.me()
end

local function get_target()
   return izi.target()
end

local function is_moving()
   local me = get_me()
   if not me then return false end
   return not me:is_standing_still()
end

local function in_melee_range(target)
   if not target then return false end
   return target:distance() <= 5
end

local function get_enemies_in_melee()
   local me = get_me()
   if not me then return 0 end
   local enemies = izi.enemies(10)
   return #enemies
end

local function get_enemies_in_ranged()
   local me = get_me()
   if not me then return 0 end
   local enemies = izi.enemies(40)
   return #enemies
end

local function racial_ready()
   if Spells.Berserking:is_usable() then return true end
   if Spells.ArcaneTorrent:is_usable() then return true end
   return false
end

local function cast_racial(msg)
   if Spells.Berserking:is_usable() then
      return Spells.Berserking:cast(get_me(), msg)
   end
   if Spells.ArcaneTorrent:is_usable() then
      return Spells.ArcaneTorrent:cast(get_me(), msg)
   end
   return false
end

local function is_spell_available(spell)
   return spell and spell:is_learned()
end

-- =============================================================================
-- CONTEXT BUILDER
-- =============================================================================
local function build_context()
   local me = get_me()
   local target = get_target()

   if not me or not me:is_valid() then
      return nil
   end

   local gcd_remains = me:gcd_remains()
   local on_gcd = gcd_remains > 0.1

   local ctx = FluxCompat.build_context(me, target, {
      in_combat = me:time_in_combat() > 0,
      hp = me:get_health_percentage(),
      mana_pct = me:mana_pct(),
      mana = me:mana_current(),
      is_moving = is_moving(),
      target_exists = target and target:is_valid() or false,
      target_enemy = target and target:is_valid_enemy() or false,
      has_valid_enemy_target = target and target:is_valid() and target:is_valid_enemy() and not target:is_dead(),
      target_hp = target and target:get_health_percentage() or 0,
      target_range = target and target:distance() or 999,
      in_melee_range = target and in_melee_range(target),
      ttd = target and target:time_to_die() or 999,
      combat_time = me:time_in_combat(),
      on_gcd = on_gcd,
      gcd_remains = gcd_remains,
   })

   ctx.hypothermia = me:debuff_up(Constants.DEBUFF_ID.HYPOTHERMIA)
   ctx.settings = defaults

   ctx.force_burst = FluxCompat.is_force_active("burst")
   ctx.force_defensive = FluxCompat.is_force_active("defensive")
   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   ctx._fire_valid = false
   ctx._frost_valid = false
   ctx._arcane_valid = false

   return ctx
end

-- =============================================================================
-- FIRE STATE
-- =============================================================================
local fire_state = {
   scorch_stacks = 0,
   scorch_duration = 0,
}

local function get_fire_state(ctx)
   if ctx._fire_valid then return fire_state end
   ctx._fire_valid = true

   local target = ctx.target
   if target and target:is_valid() then
      fire_state.scorch_stacks = target:debuff_stacks(Constants.DEBUFF_ID.IMPROVED_SCORCH) or 0
      fire_state.scorch_duration = target:debuff_remains(Constants.DEBUFF_ID.IMPROVED_SCORCH) or 0
   else
      fire_state.scorch_stacks = 0
      fire_state.scorch_duration = 0
   end

   return fire_state
end

-- =============================================================================
-- FROST STATE
-- =============================================================================
local frost_state = {}

local function get_frost_state(ctx)
   if ctx._frost_valid then return frost_state end
   ctx._frost_valid = true
   return frost_state
end

-- =============================================================================
-- ARCANE STATE
-- =============================================================================
local arcane_state = {
   is_burning = true,
   is_conserving = false,
   ab_will_drop = false,
}

local function get_arcane_state(ctx)
   if ctx._arcane_valid then return arcane_state end
   ctx._arcane_valid = true

   local me = get_me()

   local start_conserve = get_setting("arcane_start_conserve_pct") or Constants.ARCANE.DEFAULT_START_CONSERVE
   local stop_conserve = get_setting("arcane_stop_conserve_pct") or Constants.ARCANE.DEFAULT_STOP_CONSERVE

   local has_bloodlust = false
   for _, id in ipairs(Constants.BLOODLUST_IDS) do
      if me:buff_up(id) then
         has_bloodlust = true
         break
      end
   end
   if has_bloodlust and start_conserve > 10 then
      start_conserve = 10
   end

   if arcane_phase == "burn" and ctx.mana_pct <= start_conserve then
      arcane_phase = "conserve"
   elseif arcane_phase == "conserve" and ctx.mana_pct >= stop_conserve then
      local ab_stacks = 0
      local target = ctx.target
      if target and target:is_valid() then
         ab_stacks = target:debuff_stacks(Constants.DEBUFF_ID.ARCANE_BLAST) or 0
      end
      if ab_stacks <= 1 then
         arcane_phase = "burn"
      end
   end

   if not ctx.in_combat then
      arcane_phase = "burn"
   end

   arcane_state.is_burning = (arcane_phase == "burn")
   arcane_state.is_conserving = (arcane_phase == "conserve")

   local ab_cast_time = 2.5
   local ab_duration = 0
   local target = ctx.target
   if target and target:is_valid() then
      ab_duration = target:debuff_remains(Constants.DEBUFF_ID.ARCANE_BLAST) or 0
   end
   arcane_state.ab_will_drop = ab_duration > 0 and ab_duration < ab_cast_time

   return arcane_state
end

-- =============================================================================
-- MIDDLEWARE FUNCTIONS
-- =============================================================================
local function mw_ice_block(ctx)
   if not ctx.in_combat then return false end
   if ctx.hypothermia then return false end

   local threshold = get_setting("ice_block_hp") or 0
   if threshold <= 0 then return false end
   if ctx.hp > threshold then return false end

   return try_cast_gcd(Spells.IceBlock, get_me(), "[MW] Ice Block")
end

local function mw_mana_shield(ctx)
   if not ctx.in_combat then return false end

   local threshold = get_setting("mana_shield_hp") or 0
   if threshold <= 0 then return false end
   if ctx.hp > threshold then return false end
   if ctx.mana_pct < 20 then return false end

   return try_cast_gcd(Spells.ManaShield, get_me(), "[MW] Mana Shield")
end

local function mw_ice_barrier(ctx)
   if not ctx.in_combat then return false end
   if not get_setting("use_ice_barrier") then return false end

   local me = get_me()
   if me:buff_up(Constants.BUFF_ID.ICE_BARRIER) then return false end

   return try_cast_gcd(Spells.IceBarrier, get_me(), "[MW] Ice Barrier")
end

local function mw_counterspell(ctx)
   if not ctx.in_combat then return false end
   if not get_setting("use_counterspell") then return false end
   if not ctx.has_valid_enemy_target then return false end

   local target = ctx.target
   if not target then return false end

   local cast_remaining = target:get_cast_remaining_sec()
   if not cast_remaining or cast_remaining <= 0 then return false end

   local cast_id = target:get_active_cast_or_channel_id()
   if cast_id == 0 then return false end

   return try_cast_gcd(Spells.Counterspell, target, "[MW] Counterspell")
end

local function mw_healthstone(ctx)
   if not ctx.in_combat then return false end

   local threshold = get_setting("healthstone_hp") or 0
   if threshold <= 0 then return false end
   if ctx.hp > threshold then return false end

   if Spells.HealthstoneMaster:is_usable() then
      return Spells.HealthstoneMaster:use_self("[MW] Healthstone")
   end
   if Spells.HealthstoneMajor:is_usable() then
      return Spells.HealthstoneMajor:use_self("[MW] Healthstone")
   end

   return false
end

local function mw_healing_potion(ctx)
   if not get_setting("use_healing_potion") then return false end
   if not ctx.in_combat then return false end
   if ctx.combat_time < 2 then return false end

   local threshold = get_setting("healing_potion_hp") or 25
   if ctx.hp > threshold then return false end

   if Spells.SuperHealingPotion:is_usable() then
      return Spells.SuperHealingPotion:use_self("[MW] Super Healing Potion")
   end
   if Spells.MajorHealingPotion:is_usable() then
      return Spells.MajorHealingPotion:use_self("[MW] Major Healing Potion")
   end

   return false
end

local function mw_mana_gem(ctx)
   if not get_setting("use_mana_gem") then return false end
   if not ctx.in_combat then return false end

   local threshold = get_setting("mana_gem_pct") or 70
   if ctx.mana_pct > threshold then return false end

   if Spells.ManaEmerald:is_usable() then
      return Spells.ManaEmerald:use_self("[MW] Mana Emerald")
   end
   if Spells.ManaRuby:is_usable() then
      return Spells.ManaRuby:use_self("[MW] Mana Ruby")
   end
   if Spells.ManaCitrine:is_usable() then
      return Spells.ManaCitrine:use_self("[MW] Mana Citrine")
   end

   return false
end

local function mw_mana_potion(ctx)
   if not get_setting("use_mana_potion") then return false end
   if not ctx.in_combat then return false end
   if ctx.combat_time < 2 then return false end

   local threshold = get_setting("mana_potion_pct") or 50
   if ctx.mana_pct > threshold then return false end

   if Spells.SuperManaPotion:is_usable() then
      return Spells.SuperManaPotion:use_self("[MW] Super Mana Potion")
   end

   return false
end

local function mw_dark_rune(ctx)
   if not get_setting("use_dark_rune") then return false end
   if not ctx.in_combat then return false end
   if ctx.combat_time < 2 then return false end

   local threshold = get_setting("dark_rune_pct") or 50
   if ctx.mana_pct > threshold then return false end

   local min_hp = get_setting("dark_rune_min_hp") or 50
   if ctx.hp < min_hp then return false end

   if Spells.DarkRune:is_usable() then
      return Spells.DarkRune:use_self("[MW] Dark Rune")
   end
   if Spells.DemonicRune:is_usable() then
      return Spells.DemonicRune:use_self("[MW] Demonic Rune")
   end

   return false
end

local function mw_evocation(ctx)
   if not get_setting("use_evocation") then return false end
   if not ctx.in_combat then return false end

   local threshold = get_setting("evocation_pct") or 20
   if ctx.mana_pct > threshold then return false end
   if ctx.is_moving then return false end

   return try_cast_gcd(Spells.Evocation, get_me(), "[MW] Evocation")
end

local function mw_armor(ctx)
   local me = get_me()

   for _, id in ipairs(Constants.ARMOR_BUFF_IDS) do
      if me:buff_up(id) then return false end
   end

   local armor = get_setting("armor_type") or "auto"

   if armor == "auto" or armor == "molten" then
      if Spells.MoltenArmor:is_usable() then
         return Spells.MoltenArmor:cast(get_me(), "[MW] Molten Armor")
      end
   end

   if armor == "mage" then
      if Spells.MageArmor:is_usable() then
         return Spells.MageArmor:cast(get_me(), "[MW] Mage Armor")
      end
   end

   if armor == "ice" then
      if Spells.IceArmor:is_usable() then
         return Spells.IceArmor:cast(get_me(), "[MW] Ice Armor")
      end
   end

   if armor == "auto" then
      if Spells.MageArmor:is_usable() then
         return Spells.MageArmor:cast(get_me(), "[MW] Mage Armor (fallback)")
      end
      if Spells.IceArmor:is_usable() then
         return Spells.IceArmor:cast(get_me(), "[MW] Ice Armor (fallback)")
      end
   end

   return false
end

local function mw_intellect(ctx)
   if ctx.in_combat then return false end

   if not get_setting("use_arcane_intellect") then return false end

   local me = get_me()
   for _, id in ipairs(Constants.INTELLECT_BUFF_IDS) do
      if me:buff_up(id) then return false end
   end

   if Spells.SelfArcaneBrilliance:is_usable() then
      return Spells.SelfArcaneBrilliance:cast(get_me(), "[MW] Arcane Brilliance")
   end
   if Spells.SelfArcaneIntellect:is_usable() then
      return Spells.SelfArcaneIntellect:cast(get_me(), "[MW] Arcane Intellect")
   end

   return false
end

-- =============================================================================
-- FIRE ROTATION
-- =============================================================================
local function fire_rotation(ctx)
   local me = get_me()
   local target = ctx.target
   if not target or not target:is_valid() or not target:is_valid_enemy() then
      return false
   end

   local s = ctx.settings
   local state = get_fire_state(ctx)

   local cd_min_ttd = get_setting("cd_min_ttd") or 0
   local aoe_threshold = get_setting("aoe_threshold") or 0

   local function try_burst_cds()
      if get_setting("fire_use_combustion") then
         local hp_threshold = get_setting("fire_combustion_below_hp") or 0
         if not (hp_threshold > 0 and ctx.target_hp > hp_threshold) then
            if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
               if try_cast_gcd(Spells.Combustion, me, "[FIRE] Combustion") then
                  return true
               end
            end
         end
      end

      if get_setting("fire_use_icy_veins") then
         if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
            if try_cast_gcd(Spells.IcyVeins, me, "[FIRE] Icy Veins") then
               return true
            end
         end
      end

      if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
         if cast_racial("[FIRE] Racial") then
            return true
         end
      end

      return false
   end

   if not ctx.on_gcd then
      if try_burst_cds() then return true end
   end

   if aoe_threshold > 0 then
      local melee_count = get_enemies_in_melee()
      local ranged_count = get_enemies_in_ranged()

      if melee_count >= aoe_threshold then
         if Spells.ArcaneExplosion:is_castable_to_unit(me) then
            return try_cast(Spells.ArcaneExplosion, me, "[FIRE] Arcane Explosion (AoE)")
         end
      elseif not ctx.is_moving and ranged_count >= aoe_threshold then
         if Spells.Flamestrike:is_castable_to_unit(target) then
            return try_cast(Spells.Flamestrike, target, "[FIRE] Flamestrike (AoE)")
         end
      end
   end

   if get_setting("fire_use_blast_wave") then
      local min_enemies = get_setting("fire_melee_aoe_min_enemies") or 2
      if get_enemies_in_melee() >= min_enemies then
         if try_cast(Spells.BlastWave, target, "[FIRE] Blast Wave") then
            return true
         end
      end
   end

   if get_setting("fire_use_dragons_breath") then
      local min_enemies = get_setting("fire_melee_aoe_min_enemies") or 2
      if get_enemies_in_melee() >= min_enemies then
         if try_cast(Spells.DragonsBreath, target, "[FIRE] Dragon's Breath") then
            return true
         end
      end
   end

   if ctx.is_moving then
      if get_setting("fire_move_fire_blast") then
         if try_cast(Spells.FireBlast, target, "[FIRE] Fire Blast (moving)") then
            return true
         end
      end
      if get_setting("fire_move_ice_lance") then
         if try_cast(Spells.IceLance, target, "[FIRE] Ice Lance (moving)") then
            return true
         end
      end
      if get_setting("fire_move_cone_of_cold") then
         if try_cast(Spells.ConeOfCold, target, "[FIRE] Cone of Cold (moving)") then
            return true
         end
      end
      if get_setting("fire_move_arcane_explosion") and ctx.in_melee_range then
         if try_cast(Spells.ArcaneExplosion, me, "[FIRE] Arcane Explosion (moving)") then
            return true
         end
      end
      return false
   end

   if get_setting("fire_maintain_scorch") then
      local refresh = get_setting("fire_scorch_refresh") or Constants.SCORCH.DEFAULT_REFRESH
      if state.scorch_stacks < Constants.SCORCH.MAX_STACKS or state.scorch_duration < refresh then
         if try_cast(Spells.Scorch, target, string.format("[FIRE] Scorch - Stacks: %d, Duration: %.1fs", state.scorch_stacks, state.scorch_duration)) then
            return true
         end
      end
   end

   if get_setting("fire_weave_fire_blast") then
      if try_cast(Spells.FireBlast, target, "[FIRE] Fire Blast") then
         return true
      end
   end

   local primary = get_setting("fire_primary_spell") or "fireball"
   if primary == "scorch" then
      if try_cast(Spells.Scorch, target, "[FIRE] Scorch (primary)") then
         return true
      end
   end
   if try_cast(Spells.Fireball, target, "[FIRE] Fireball") then
      return true
   end

   return false
end

-- =============================================================================
-- FROST ROTATION
-- =============================================================================
local function frost_rotation(ctx)
   local me = get_me()
   local target = ctx.target
   if not target or not target:is_valid() or not target:is_valid_enemy() then
      return false
   end

   local cd_min_ttd = get_setting("cd_min_ttd") or 0
   local aoe_threshold = get_setting("aoe_threshold") or 0

   local function try_burst_cds()
      if get_setting("frost_use_icy_veins") then
         if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
            if try_cast_gcd(Spells.IcyVeins, me, "[FROST] Icy Veins") then
               return true
            end
         end
      end

      if get_setting("frost_use_water_elemental") then
         if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
            if try_cast_gcd(Spells.SummonWaterElemental, me, "[FROST] Summon Water Elemental") then
               return true
            end
         end
      end

      if get_setting("frost_use_cold_snap") then
         if not me:buff_up(Constants.BUFF_ID.ICY_VEINS) then
            local iv_cd = Spells.IcyVeins:cooldown_remains()
            if iv_cd >= 20 then
               if is_spell_available(Spells.SummonWaterElemental) then
                  local we_cd = Spells.SummonWaterElemental:cooldown_remains()
                  if we_cd >= 20 then
                     if try_cast_gcd(Spells.ColdSnap, me, "[FROST] Cold Snap") then
                        return true
                     end
                  end
               else
                  if iv_cd >= 20 then
                     if try_cast_gcd(Spells.ColdSnap, me, "[FROST] Cold Snap") then
                        return true
                     end
                  end
               end
            end
         end
      end

      if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
         if cast_racial("[FROST] Racial") then
            return true
         end
      end

      return false
   end

   if not ctx.on_gcd then
      if try_burst_cds() then return true end
   end

   if aoe_threshold > 0 then
      local melee_count = get_enemies_in_melee()
      local ranged_count = get_enemies_in_ranged()

      if melee_count >= aoe_threshold then
         if Spells.ConeOfCold:is_castable_to_unit(target) then
            if try_cast(Spells.ConeOfCold, target, "[FROST] Cone of Cold (AoE)") then
               return true
            end
         end
         if Spells.ArcaneExplosion:is_castable_to_unit(me) then
            return try_cast(Spells.ArcaneExplosion, me, "[FROST] Arcane Explosion (AoE)")
         end
      elseif not ctx.is_moving and ranged_count >= aoe_threshold then
         if try_cast(Spells.Blizzard, target, "[FROST] Blizzard (AoE)") then
            return true
         end
      end
   end

   if ctx.is_moving then
      if get_setting("frost_move_fire_blast") then
         if try_cast(Spells.FireBlast, target, "[FROST] Fire Blast (moving)") then
            return true
         end
      end
      if get_setting("frost_move_ice_lance") then
         if try_cast(Spells.IceLance, target, "[FROST] Ice Lance (moving)") then
            return true
         end
      end
      if get_setting("frost_move_cone_of_cold") then
         if try_cast(Spells.ConeOfCold, target, "[FROST] Cone of Cold (moving)") then
            return true
         end
      end
      if get_setting("frost_move_arcane_explosion") and ctx.in_melee_range then
         if try_cast(Spells.ArcaneExplosion, me, "[FROST] Arcane Explosion (moving)") then
            return true
         end
      end
      return false
   end

   if try_cast(Spells.Frostbolt, target, "[FROST] Frostbolt") then
      return true
   end

   return false
end

-- =============================================================================
-- ARCANE ROTATION
-- =============================================================================
local function arcane_rotation(ctx)
   local me = get_me()
   local target = ctx.target
   if not target or not target:is_valid() or not target:is_valid_enemy() then
      return false
   end

   local state = get_arcane_state(ctx)
   local cd_min_ttd = get_setting("cd_min_ttd") or 0
   local aoe_threshold = get_setting("aoe_threshold") or 0

   local function try_burst_cds()
      if get_setting("arcane_use_icy_veins") then
         if state.is_burning then
            if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
               if try_cast_gcd(Spells.IcyVeins, me, "[ARCANE] Icy Veins") then
                  return true
               end
            end
         end
      end

      if get_setting("arcane_use_cold_snap") then
         if state.is_burning then
            if not me:buff_up(Constants.BUFF_ID.ICY_VEINS) then
               local iv_cd = Spells.IcyVeins:cooldown_remains()
               if iv_cd >= 20 then
                  if try_cast_gcd(Spells.ColdSnap, me, "[ARCANE] Cold Snap") then
                     return true
                  end
               end
            end
         end
      end

      if get_setting("arcane_use_arcane_power") then
         if state.is_burning then
            if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
               if try_cast_gcd(Spells.ArcanePower, me, "[ARCANE] Arcane Power") then
                  return true
               end
            end
         end
      end

      if get_setting("arcane_use_pom") then
         if state.is_burning then
            if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
               if try_cast_gcd(Spells.PresenceOfMind, me, "[ARCANE] Presence of Mind") then
                  return true
               end
            end
         end
      end

      if get_setting("use_racial") and state.is_burning then
         if not (cd_min_ttd > 0 and ctx.ttd > 0 and ctx.ttd < cd_min_ttd) then
            if cast_racial("[ARCANE] Racial") then
               return true
            end
         end
      end

      return false
   end

   if not ctx.on_gcd then
      if try_burst_cds() then return true end
   end

   if aoe_threshold > 0 then
      local melee_count = get_enemies_in_melee()
      local ranged_count = get_enemies_in_ranged()

      if melee_count >= aoe_threshold then
         if Spells.ArcaneExplosion:is_castable_to_unit(me) then
            return try_cast(Spells.ArcaneExplosion, me, "[ARCANE] Arcane Explosion (AoE)")
         end
      elseif not ctx.is_moving and ranged_count >= aoe_threshold then
         if Spells.Flamestrike:is_castable_to_unit(target) then
            return try_cast(Spells.Flamestrike, target, "[ARCANE] Flamestrike (AoE)")
         end
      end
   end

   if ctx.is_moving then
      if get_setting("arcane_move_fire_blast") then
         if try_cast(Spells.FireBlast, target, "[ARCANE] Fire Blast (moving)") then
            return true
         end
      end
      if get_setting("arcane_move_ice_lance") then
         if try_cast(Spells.IceLance, target, "[ARCANE] Ice Lance (moving)") then
            return true
         end
      end
      if get_setting("arcane_move_cone_of_cold") then
         if try_cast(Spells.ConeOfCold, target, "[ARCANE] Cone of Cold (moving)") then
            return true
         end
      end
      if get_setting("arcane_move_arcane_explosion") and ctx.in_melee_range then
         if try_cast(Spells.ArcaneExplosion, me, "[ARCANE] Arcane Explosion (moving)") then
            return true
         end
      end
      return false
   end

   if state.is_burning then
      if try_cast(Spells.ArcaneBlast, target, string.format("[ARCANE] Arcane Blast (BURN) - Stacks: %d", ctx.ab_stacks or 0)) then
         return true
      end
   end

   if state.is_conserving then
      local max_casts = get_setting("arcane_blasts_between_fillers") or Constants.ARCANE.DEFAULT_BLASTS_BEFORE_FILLER
      local ab_stacks = 0
      if target and target:is_valid() then
         ab_stacks = target:debuff_stacks(Constants.DEBUFF_ID.ARCANE_BLAST) or 0
      end

      local has_cc = me:buff_up(Constants.BUFF_ID.CLEARCASTING)

      if ab_stacks < max_casts or (has_cc and ab_stacks >= max_casts) then
         if try_cast(Spells.ArcaneBlast, target, string.format("[ARCANE] Arcane Blast (CONSERVE %d/%d)%s", ab_stacks + 1, max_casts, has_cc and " [CC]" or "")) then
            return true
         end
      end

      if ab_stacks >= max_casts or state.ab_will_drop then
         local filler = get_setting("arcane_filler") or "frostbolt"
         if filler == "frostbolt" then
            if try_cast(Spells.Frostbolt, target, "[ARCANE] Frostbolt (filler)") then
               return true
            end
         elseif filler == "fireball" then
            if try_cast(Spells.Fireball, target, "[ARCANE] Fireball (filler)") then
               return true
            end
         elseif filler == "arcane_missiles" then
            if try_cast(Spells.ArcaneMissiles, target, "[ARCANE] Arcane Missiles (filler)") then
               return true
            end
         elseif filler == "scorch" then
            if try_cast(Spells.Scorch, target, "[ARCANE] Scorch (filler)") then
               return true
            end
         end
         if try_cast(Spells.Frostbolt, target, "[ARCANE] Frostbolt (filler)") then
            return true
         end
      end
   end

   return false
end

-- =============================================================================
-- MAIN UPDATE CALLBACK
-- =============================================================================
core.register_on_update_callback(function()
   local ctx = build_context()
   if not ctx then
      return
   end

   if FluxCompat.rotation_registry:execute_middleware(ctx) then
      return
   end

   if not ctx.in_combat then
      if mw_armor(ctx) then return end
      if mw_intellect(ctx) then return end
   end

   if not ctx.has_valid_enemy_target then
      return
   end

   local playstyle = get_setting("playstyle") or "fire"

   if playstyle == "fire" then
      fire_rotation(ctx)
   elseif playstyle == "frost" then
      frost_rotation(ctx)
   elseif playstyle == "arcane" then
      arcane_rotation(ctx)
   end
end)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Mage main rotation loaded")
