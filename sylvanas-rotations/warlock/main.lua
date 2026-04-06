-- =============================================================================
-- WARLOCK MAIN ROTATION - SYLVANAS FRAMEWORK
-- Converted from Flux rotation/source/aio/warlock/
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
   BloodFury = izi.spell(20572),
   ArcaneTorrent = izi.spell(28730),
   Berserking = izi.spell(26297),

   -- Affliction
   Corruption = izi.spell(27216),
   UnstableAffliction = izi.spell(30404),
   SiphonLife = izi.spell(30911),
   CurseOfAgony = izi.spell(27218),
   CurseOfDoom = izi.spell(30910),
   CurseOfElements = izi.spell(27228),
   CurseOfWeakness = izi.spell(30909),
   CurseOfTongues = izi.spell(11719),
   AmplifyCurse = izi.spell(18288),
   DrainSoul = izi.spell(27217),
   DrainLife = izi.spell(27219),
   Fear = izi.spell(6215),
   HowlOfTerror = izi.spell(17928),
   DeathCoil = izi.spell(27223),
   SeedOfCorruption = izi.spell(27243),

   -- Demonology
   SummonImp = izi.spell(688),
   SummonVoidwalker = izi.spell(697),
   SummonSuccubus = izi.spell(712),
   SummonFelhunter = izi.spell(691),
   SummonFelguard = izi.spell(30146),
   FelDomination = izi.spell(18708),
   SoulLink = izi.spell(19028),
   DemonicSacrifice = izi.spell(18788),
   HealthFunnel = izi.spell(27259),
   DarkPact = izi.spell(27265),
   FelArmor = izi.spell(28189),
   FelArmorR1 = izi.spell(28176),
   DemonArmor = izi.spell(27260),
   ShadowWard = izi.spell(28610),

   -- Destruction
   ShadowBolt = izi.spell(27209),
   Incinerate = izi.spell(32231),
   Immolate = izi.spell(27215),
   Conflagrate = izi.spell(30912),
   Shadowburn = izi.spell(30546),
   Shadowfury = izi.spell(30414),
   Soulshatter = izi.spell(29858),
   LifeTap = izi.spell(27222),

   -- Items
   HealthstoneFel = izi.item(36892),
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   SuperManaPotion = izi.item(22832),
   DarkRune = izi.item(20520),
   DemonicRune = izi.item(12662),
}

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local Constants = {
   BUFF_ID = {
      SHADOW_TRANCE = 17941,
      BACKLASH = 34936,
      DEMONIC_EMPOWERMENT = 47193,
      METAMORPHOSIS = 47241,
      SOUL_LINK = 25228,
      FEL_ARMOR_R1 = 28176,
      FEL_ARMOR_R2 = 28189,
      DS_TOUCH_SHADOW = 18791,
      DS_BURNING_WISH = 18790,
      DS_FEL_STAMINA = 18792,
      DS_FEL_ENERGY = 18793,
   },

   DEBUFF_ID = {
      CORRUPTION = 27216,
      UNSTABLE_AFF = 30404,
      SIPHON_LIFE = 30911,
      IMMOLATE = 27215,
      ISB = 17800,
      CURSE_OF_AGONY = 27218,
      CURSE_OF_DOOM = 30910,
      CURSE_OF_ELEMENTS = 27228,
      CURSE_OF_WEAKNESS = 30909,
      CURSE_OF_TONGUES = 11719,
   },

   SPELL_ID = {
      SHADOW_WARD = 28610,
      SOULSHATTER = 29858,
      DEATH_COIL = 27223,
      DEMONIC_EMPOWERMENT = 47193,
      METAMORPHOSIS = 47241,
   },

   ARMOR_BUFF_IDS = {28176, 28189, 27260, 706},

   CURSE = {
      DEFAULT_TYPE = "elements",
      AGONY_THRESHOLD_PCT = 0.1,
   },
}

-- Curse debuff ID mapping
local CURSE_DEBUFF_IDS = {
   agony = Constants.DEBUFF_ID.CURSE_OF_AGONY,
   doom = Constants.DEBUFF_ID.CURSE_OF_DOOM,
   elements = Constants.DEBUFF_ID.CURSE_OF_ELEMENTS,
   weakness = Constants.DEBUFF_ID.CURSE_OF_WEAKNESS,
   tongues = Constants.DEBUFF_ID.CURSE_OF_TONGUES,
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================
local function get_curse_duration(ctx)
   local curse_type = ctx.settings.curse_type or Constants.CURSE.DEFAULT_TYPE
   local debuff_id = CURSE_DEBUFF_IDS[curse_type]
   if not debuff_id then return 0 end
   if not ctx.target then return 0 end
   return ctx.target:debuff_remains(debuff_id) or 0
end

local function get_curse_spell(ctx)
   local curse_type = ctx.settings.curse_type or Constants.CURSE.DEFAULT_TYPE
   if curse_type == "agony" then return Spells.CurseOfAgony end
   if curse_type == "doom" then return Spells.CurseOfDoom end
   if curse_type == "elements" then return Spells.CurseOfElements end
   if curse_type == "weakness" then return Spells.CurseOfWeakness end
   if curse_type == "tongues" then return Spells.CurseOfTongues end
   return nil
end

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- =============================================================================
-- FLUXCOMPAT INITIALIZATION
-- =============================================================================
FluxCompat.register_trinket_middleware()

FluxCompat.register_defensive_middleware({
   spell_id = Constants.SPELL_ID.SHADOW_WARD,
   name = "Shadow Ward",
   type = "absorb",
   settings_key = nil,
})

FluxCompat.register_defensive_middleware({
   spell_id = Constants.SPELL_ID.SOULSHATTER,
   name = "Soulshatter",
   type = "threat",
   settings_key = "use_soulshatter",
})

FluxCompat.register_defensive_middleware({
   spell_id = Constants.SPELL_ID.DEATH_COIL,
   name = "Death Coil",
   type = "emergency",
   settings_key = "death_coil_hp",
   hp_threshold = true,
})

if Constants.SPELL_ID.DEMONIC_EMPOWERMENT then
   FluxCompat.register_burst_middleware({
      spell_id = Constants.SPELL_ID.DEMONIC_EMPOWERMENT,
      name = "Demonic Empowerment",
      settings_key = nil,
   })
end

if Constants.SPELL_ID.METAMORPHOSIS then
   FluxCompat.register_burst_middleware({
      spell_id = Constants.SPELL_ID.METAMORPHOSIS,
      name = "Metamorphosis",
      settings_key = nil,
   })
end

FluxCompat.register_rotation("warlock", {
   playstyles = {"affliction", "demonology", "destruction"},
   has_pet = true,
   has_curse = true,
   has_dot = true,
   has_soul_shards = true,
})

-- =============================================================================
-- SETTINGS DEFAULTS
-- =============================================================================
local defaults = {
   playstyle = "affliction",
   curse_type = "elements",
   use_fel_armor = true,
   aoe_threshold = 0,
   cd_min_ttd = 0,
   use_soulshatter = true,
   healthstone_hp = 35,
   use_healing_potion = true,
   healing_potion_hp = 25,
   death_coil_hp = 20,
   aff_use_corruption = true,
   aff_use_ua = true,
   aff_use_siphon_life = true,
   aff_use_immolate = false,
   aff_use_shadow_trance = true,
   aff_use_drain_soul = true,
   aff_drain_soul_hp = 25,
   aff_use_dark_pact = true,
   aff_use_amplify_curse = true,
   demo_use_corruption = true,
   demo_use_immolate = false,
   demo_pet_heal_hp = 40,
   demo_use_fel_domination = true,
   demo_use_soul_link = true,
   demo_use_sacrifice = false,
   demo_sacrifice_pet = "succubus",
   destro_primary_spell = "shadow_bolt",
   destro_use_immolate = true,
   destro_use_conflagrate = true,
   destro_use_shadowburn = true,
   destro_shadowburn_hp = 10,
   destro_use_shadowfury = true,
   destro_use_backlash = true,
   life_tap_mana_pct = 30,
   life_tap_min_hp = 40,
   use_mana_potion = true,
   mana_potion_pct = 30,
   use_dark_rune = true,
   dark_rune_pct = 30,
   dark_rune_min_hp = 50,
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================
local function get_setting(settings, key)
   if settings and settings[key] ~= nil then
      return settings[key]
   end
   return defaults[key]
end

local function try_cast(spell, target, label)
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
   return spell:cast(target, label or "")
end

local function is_spell_available(spell)
   if not spell then return false end
   return spell:is_learned() and spell:is_available()
end

-- =============================================================================
-- CONTEXT EXTENSION
-- =============================================================================
local function extend_context(ctx, me, target)
   ctx.is_moving = not me:is_standing_still()
   ctx.is_mounted = me.is_mounted and me.is_mounted or false

   local pet = izi.target()
   ctx.pet_exists = pet and pet:is_valid() and not pet:is_dead_or_ghost()
   ctx.pet_hp = ctx.pet_exists and pet:get_health_percentage() or 0
   ctx.pet_active = ctx.pet_exists and not pet:is_dead_or_ghost()

   ctx.has_shadow_trance = me:buff_remains(Constants.BUFF_ID.SHADOW_TRANCE) > 0
   ctx.has_backlash = me:buff_remains(Constants.BUFF_ID.BACKLASH) > 0

   ctx.has_ds_shadow = me:buff_remains(Constants.BUFF_ID.DS_TOUCH_SHADOW) > 0
   ctx.has_ds_fire = me:buff_remains(Constants.BUFF_ID.DS_BURNING_WISH) > 0
   ctx.has_ds_any = ctx.has_ds_shadow or ctx.has_ds_fire
      or me:buff_remains(Constants.BUFF_ID.DS_FEL_STAMINA) > 0
      or me:buff_remains(Constants.BUFF_ID.DS_FEL_ENERGY) > 0

   ctx.has_fel_armor = me:buff_remains(Constants.BUFF_ID.FEL_ARMOR_R2) > 0
      or me:buff_remains(Constants.BUFF_ID.FEL_ARMOR_R1) > 0

   ctx.has_soul_link = me:buff_remains(Constants.BUFF_ID.SOUL_LINK) > 0

   ctx.soul_shards = me.soul_shards_current or 0

   ctx.demon_type = ctx.pet_exists and ctx:get_demon_type() or nil
   ctx.has_demonic_empowerment = me:buff_remains(Constants.BUFF_ID.DEMONIC_EMPOWERMENT) > 0
   ctx.has_metamorphosis = me:buff_remains(Constants.BUFF_ID.METAMORPHOSIS) > 0

   ctx.enemy_count = #izi.enemies(30)

   ctx.force_burst = FluxCompat.is_force_active("burst")
   ctx.force_defensive = FluxCompat.is_force_active("defensive")
   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   ctx._affliction_valid = false
   ctx._demo_valid = false
   ctx._destro_valid = false
end

-- =============================================================================
-- MIDDLEWARE FUNCTIONS
-- =============================================================================
local function mw_DeathCoil(ctx, icon)
   if not ctx.in_combat then return nil end
   local threshold = ctx.settings.death_coil_hp or 0
   if threshold <= 0 then return nil end
   if ctx.hp > threshold then return nil end

   if Spells.DeathCoil:is_usable() and Spells.DeathCoil:is_castable_to_unit(ctx.target) then
      return Spells.DeathCoil:cast(ctx.target, "Death Coil - HP: " .. string.format("%.0f%%", ctx.hp))
   end
   return nil
end

local function mw_Healthstone(ctx, icon)
   if not ctx.in_combat then return nil end
   local threshold = ctx.settings.healthstone_hp or 0
   if threshold <= 0 then return nil end
   if ctx.hp > threshold then return nil end

   if Spells.HealthstoneFel:is_usable() then
      return Spells.HealthstoneFel:use_self("Healthstone - HP: " .. string.format("%.0f%%", ctx.hp))
   end
   if Spells.HealthstoneMaster:is_usable() then
      return Spells.HealthstoneMaster:use_self("Healthstone - HP: " .. string.format("%.0f%%", ctx.hp))
   end
   if Spells.HealthstoneMajor:is_usable() then
      return Spells.HealthstoneMajor:use_self("Healthstone - HP: " .. string.format("%.0f%%", ctx.hp))
   end
   return nil
end

local function mw_HealingPotion(ctx, icon)
   if not ctx.settings.use_healing_potion then return nil end
   if not ctx.in_combat then return nil end
   if ctx.combat_time < 2 then return nil end
   local threshold = ctx.settings.healing_potion_hp or 25
   if ctx.hp > threshold then return nil end

   if Spells.SuperHealingPotion:is_usable() then
      return Spells.SuperHealingPotion:use_self("Super Healing Potion - HP: " .. string.format("%.0f%%", ctx.hp))
   end
   if Spells.MajorHealingPotion:is_usable() then
      return Spells.MajorHealingPotion:use_self("Major Healing Potion - HP: " .. string.format("%.0f%%", ctx.hp))
   end
   return nil
end

local function mw_Soulshatter(ctx, icon)
   if not ctx.settings.use_soulshatter then return nil end
   if not ctx.in_combat then return nil end
   if ctx.soul_shards < 1 then return nil end

   if ctx.target and ctx.target:is_tank() then
      if Spells.Soulshatter:is_usable() then
         return Spells.Soulshatter:cast(ctx.me, "Soulshatter (threat)")
      end
   end
   return nil
end

local function mw_DarkPact(ctx, icon)
   if not ctx.settings.aff_use_dark_pact then return nil end
   if not ctx.in_combat then return nil end
   local threshold = ctx.settings.life_tap_mana_pct or 30
   if ctx.mana_pct > threshold then return nil end
   if not ctx.pet_active then return nil end

   if Spells.DarkPact:is_usable() and Spells.DarkPact:is_castable_to_unit(ctx.me) then
      return Spells.DarkPact:cast(ctx.me, "Dark Pact - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
   end
   return nil
end

local function mw_LifeTap(ctx, icon)
   if not ctx.in_combat then return nil end
   local mana_threshold = ctx.settings.life_tap_mana_pct or 30
   if ctx.mana_pct > mana_threshold then return nil end
   local min_hp = ctx.settings.life_tap_min_hp or 40
   if ctx.hp < min_hp then return nil end

   if Spells.LifeTap:is_usable() and Spells.LifeTap:is_castable_to_unit(ctx.me) then
      return Spells.LifeTap:cast(ctx.me, string.format("Life Tap - Mana: %.0f%% HP: %.0f%%", ctx.mana_pct, ctx.hp))
   end
   return nil
end

local function mw_ManaPotion(ctx, icon)
   if not ctx.settings.use_mana_potion then return nil end
   if not ctx.in_combat then return nil end
   if ctx.combat_time < 2 then return nil end
   local threshold = ctx.settings.mana_potion_pct or 30
   if ctx.mana_pct > threshold then return nil end

   if Spells.SuperManaPotion:is_usable() then
      return Spells.SuperManaPotion:use_self("Super Mana Potion - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
   end
   return nil
end

local function mw_DarkRune(ctx, icon)
   if not ctx.settings.use_dark_rune then return nil end
   if not ctx.in_combat then return nil end
   if ctx.combat_time < 2 then return nil end
   local threshold = ctx.settings.dark_rune_pct or 30
   if ctx.mana_pct > threshold then return nil end
   local min_hp = ctx.settings.dark_rune_min_hp or 50
   if ctx.hp < min_hp then return nil end

   if Spells.DarkRune:is_usable() then
      return Spells.DarkRune:use_self("Dark Rune - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
   end
   if Spells.DemonicRune:is_usable() then
      return Spells.DemonicRune:use_self("Demonic Rune - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
   end
   return nil
end

local function mw_FelArmor(ctx, icon)
   if ctx.in_combat then return nil end
   if ctx.is_mounted then return nil end
   if not ctx.settings.use_fel_armor then return nil end
   local me = ctx.me
   local has_armor = false
   for _, buff_id in ipairs(Constants.ARMOR_BUFF_IDS) do
      if me:buff_remains(buff_id) > 0 then
         has_armor = true
         break
      end
   end
   if has_armor then return nil end

   if Spells.FelArmor:is_usable() and Spells.FelArmor:is_castable_to_unit(me) then
      return Spells.FelArmor:cast(me, "Fel Armor")
   end
   if Spells.FelArmorR1:is_usable() and Spells.FelArmorR1:is_castable_to_unit(me) then
      return Spells.FelArmorR1:cast(me, "Fel Armor (R1)")
   end
   if Spells.DemonArmor:is_usable() and Spells.DemonArmor:is_castable_to_unit(me) then
      return Spells.DemonArmor:cast(me, "Demon Armor (fallback)")
   end
   return nil
end

local function execute_middleware(ctx, icon)
   local result = mw_FelArmor(ctx, icon)
   if result then return result end

   result = mw_DeathCoil(ctx, icon)
   if result then return result end

   result = mw_Healthstone(ctx, icon)
   if result then return result end

   result = mw_HealingPotion(ctx, icon)
   if result then return result end

   result = mw_Soulshatter(ctx, icon)
   if result then return result end

   result = mw_DarkPact(ctx, icon)
   if result then return result end

   result = mw_LifeTap(ctx, icon)
   if result then return result end

   result = mw_ManaPotion(ctx, icon)
   if result then return result end

   result = mw_DarkRune(ctx, icon)
   if result then return result end

   return nil
end

-- =============================================================================
-- AFFLICTION STATE
-- =============================================================================
local affliction_state = {
   corruption_duration = 0,
   ua_duration = 0,
   siphon_duration = 0,
   immolate_duration = 0,
   curse_duration = 0,
   isb_active = false,
}

local function get_affliction_state(ctx)
   if ctx._affliction_valid then return affliction_state end
   ctx._affliction_valid = true

   local target = ctx.target
   if target then
      affliction_state.corruption_duration = target:debuff_remains(Constants.DEBUFF_ID.CORRUPTION) or 0
      affliction_state.ua_duration = target:debuff_remains(Constants.DEBUFF_ID.UNSTABLE_AFF) or 0
      affliction_state.siphon_duration = target:debuff_remains(Constants.DEBUFF_ID.SIPHON_LIFE) or 0
      affliction_state.immolate_duration = target:debuff_remains(Constants.DEBUFF_ID.IMMOLATE) or 0
      affliction_state.isb_active = (target:debuff_remains(Constants.DEBUFF_ID.ISB) or 0) > 0
   else
      affliction_state.corruption_duration = 0
      affliction_state.ua_duration = 0
      affliction_state.siphon_duration = 0
      affliction_state.immolate_duration = 0
      affliction_state.isb_active = false
   end
   affliction_state.curse_duration = get_curse_duration(ctx)

   return affliction_state
end

-- =============================================================================
-- AFFLICTION STRATEGIES
-- =============================================================================
local Aff_Strategies = {}

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "aff_use_shadow_trance",
      matches = function(ctx, state)
         return ctx.has_shadow_trance
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.ShadowBolt, ctx.target, "[AFF] Shadow Bolt (Nightfall)")
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         if ctx.settings.curse_type == "none" then return false end
         local threshold = 1.5
         if ctx.settings.curse_type == "agony" then
            threshold = 0.1
         end
         return state.curse_duration < threshold
      end,
      execute = function(ctx, icon)
         local curse_type = ctx.settings.curse_type
         if ctx.settings.aff_use_amplify_curse
            and (curse_type == "doom" or curse_type == "agony")
            and is_spell_available(Spells.AmplifyCurse) then
            local result = try_cast(Spells.AmplifyCurse, ctx.me, "[AFF] Amplify Curse")
            if result then return result end
         end

         local curse_spell = get_curse_spell(ctx)
         if curse_spell then
            return try_cast(curse_spell, ctx.target, "[AFF] " .. curse_type)
         end
         return nil
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "aff_use_ua",
      matches = function(ctx, state)
         if ctx.is_moving then return false end
         return state.ua_duration < 3
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.UnstableAffliction, ctx.target,
            "[AFF] Unstable Affliction - Dur: " .. string.format("%.1fs", state.ua_duration))
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "aff_use_corruption",
      matches = function(ctx, state)
         return state.corruption_duration < 1.5
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Corruption, ctx.target,
            "[AFF] Corruption - Dur: " .. string.format("%.1fs", state.corruption_duration))
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "aff_use_siphon_life",
      matches = function(ctx, state)
         if state.siphon_duration > 1.5 then return false end
         return state.isb_active
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.SiphonLife, ctx.target,
            "[AFF] Siphon Life - Dur: " .. string.format("%.1fs ISB: yes", state.siphon_duration))
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "aff_use_immolate",
      matches = function(ctx, state)
         if ctx.is_moving then return false end
         return state.immolate_duration < 3
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Immolate, ctx.target,
            "[AFF] Immolate - Dur: " .. string.format("%.1fs", state.immolate_duration))
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "aff_use_drain_soul",
      matches = function(ctx, state)
         if ctx.is_moving then return false end
         local threshold = ctx.settings.aff_drain_soul_hp or 25
         return ctx.target_hp < threshold
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.DrainSoul, ctx.target,
            "[AFF] Drain Soul - Target: " .. string.format("%.0f%%", ctx.target_hp))
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         local threshold = ctx.settings.aoe_threshold or 0
         if threshold == 0 then return false end
         if ctx.enemy_count < threshold then return false end
         if ctx.is_moving then return false end
         return true
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.SeedOfCorruption, ctx.target,
            "[AFF] Seed of Corruption (AoE) - Enemies: " .. ctx.enemy_count)
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      is_gcd_gated = false,
      is_burst = true,
      setting_key = "use_racial",
      matches = function(ctx, state)
         local min_ttd = ctx.settings.cd_min_ttd or 0
         if min_ttd > 0 and ctx.ttd and ctx.ttd > 0 and ctx.ttd < min_ttd then return false end
         return Spells.BloodFury:is_usable() or Spells.ArcaneTorrent:is_usable()
      end,
      execute = function(ctx, icon)
         if Spells.BloodFury:is_usable() then
            return Spells.BloodFury:cast(ctx.me, "[AFF] Blood Fury")
         end
         if Spells.ArcaneTorrent:is_usable() then
            return Spells.ArcaneTorrent:cast(ctx.me, "[AFF] Arcane Torrent")
         end
         return nil
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         return not ctx.is_moving
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.ShadowBolt, ctx.target, "[AFF] Shadow Bolt")
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      matches = function(ctx, state)
         local min_hp = ctx.settings.life_tap_min_hp or 40
         if ctx.hp < min_hp then return false end
         local threshold = ctx.settings.life_tap_mana_pct or 30
         return ctx.mana_pct < threshold
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.LifeTap, ctx.me,
            "[AFF] Life Tap (fallback) - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
      end,
   }
   table.insert(Aff_Strategies, strategy)
end

-- =============================================================================
-- DEMONOLOGY STATE
-- =============================================================================
local demo_state = {
   pet_exists = false,
   pet_hp = 0,
   has_sacrifice = false,
   corruption_duration = 0,
   immolate_duration = 0,
   curse_duration = 0,
}

local function get_demo_state(ctx)
   if ctx._demo_valid then return demo_state end
   ctx._demo_valid = true

   demo_state.pet_exists = ctx.pet_active
   demo_state.pet_hp = ctx.pet_hp
   demo_state.has_sacrifice = ctx.has_ds_any

   local target = ctx.target
   if target then
      demo_state.corruption_duration = target:debuff_remains(Constants.DEBUFF_ID.CORRUPTION) or 0
      demo_state.immolate_duration = target:debuff_remains(Constants.DEBUFF_ID.IMMOLATE) or 0
   else
      demo_state.corruption_duration = 0
      demo_state.immolate_duration = 0
   end
   demo_state.curse_duration = get_curse_duration(ctx)

   return demo_state
end

-- =============================================================================
-- DEMONOLOGY STRATEGIES
-- =============================================================================
local Demo_Strategies = {}

do
   local strategy = {
      requires_combat = true,
      setting_key = "demo_use_fel_domination",
      matches = function(ctx, state)
         if ctx.settings.demo_use_sacrifice then return false end
         if ctx.pet_active then return false end
         return true
      end,
      execute = function(ctx, icon)
         if is_spell_available(Spells.FelDomination) and Spells.FelDomination:is_usable() then
            local result = try_cast(Spells.FelDomination, ctx.me, "[DEMO] Fel Domination")
            if result then return result end
         end
         if is_spell_available(Spells.SummonFelguard) and Spells.SummonFelguard:is_usable() then
            return try_cast(Spells.SummonFelguard, ctx.me, "[DEMO] Summon Felguard (resummon)")
         end
         return nil
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      setting_key = "demo_use_soul_link",
      matches = function(ctx, state)
         if ctx.settings.demo_use_sacrifice then return false end
         if not ctx.pet_active then return false end
         if ctx.has_soul_link then return false end
         return true
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.SoulLink, ctx.me, "[DEMO] Soul Link")
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      matches = function(ctx, state)
         if ctx.settings.demo_use_sacrifice then return false end
         if not state.pet_exists then return false end
         if ctx.is_moving then return false end
         local threshold = ctx.settings.demo_pet_heal_hp or 40
         return state.pet_hp < threshold and state.pet_hp > 0
      end,
      execute = function(ctx, icon)
         local pet = ctx.me:get_pet()
         if pet and try_cast(Spells.HealthFunnel, pet,
            "[DEMO] Health Funnel - Pet HP: " .. string.format("%.0f%%", state.pet_hp)) then
            return true
         end
         return nil
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      setting_key = "demo_use_sacrifice",
      matches = function(ctx, state)
         if state.has_sacrifice then return false end
         if not state.pet_exists then return false end
         return true
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.DemonicSacrifice, ctx.me, "[DEMO] Demonic Sacrifice")
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         if ctx.settings.curse_type == "none" then return false end
         return state.curse_duration < 1.5
      end,
      execute = function(ctx, icon)
         local curse_spell = get_curse_spell(ctx)
         if curse_spell then
            return try_cast(curse_spell, ctx.target, "[DEMO] " .. ctx.settings.curse_type)
         end
         return nil
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "demo_use_corruption",
      matches = function(ctx, state)
         return state.corruption_duration < 1.5
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Corruption, ctx.target,
            "[DEMO] Corruption - Dur: " .. string.format("%.1fs", state.corruption_duration))
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "demo_use_immolate",
      matches = function(ctx, state)
         if ctx.is_moving then return false end
         return state.immolate_duration < 3
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Immolate, ctx.target,
            "[DEMO] Immolate - Dur: " .. string.format("%.1fs", state.immolate_duration))
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         local threshold = ctx.settings.aoe_threshold or 0
         if threshold == 0 then return false end
         if ctx.enemy_count < threshold then return false end
         if ctx.is_moving then return false end
         return true
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.SeedOfCorruption, ctx.target,
            "[DEMO] Seed of Corruption (AoE) - Enemies: " .. ctx.enemy_count)
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      is_gcd_gated = false,
      is_burst = true,
      setting_key = "use_racial",
      matches = function(ctx, state)
         local min_ttd = ctx.settings.cd_min_ttd or 0
         if min_ttd > 0 and ctx.ttd and ctx.ttd > 0 and ctx.ttd < min_ttd then return false end
         return Spells.BloodFury:is_usable() or Spells.ArcaneTorrent:is_usable()
      end,
      execute = function(ctx, icon)
         if Spells.BloodFury:is_usable() then
            return Spells.BloodFury:cast(ctx.me, "[DEMO] Blood Fury")
         end
         if Spells.ArcaneTorrent:is_usable() then
            return Spells.ArcaneTorrent:cast(ctx.me, "[DEMO] Arcane Torrent")
         end
         return nil
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         return not ctx.is_moving
      end,
      execute = function(ctx, icon)
         if ctx.has_ds_fire and is_spell_available(Spells.Incinerate) then
            local result = try_cast(Spells.Incinerate, ctx.target, "[DEMO] Incinerate (DS/Ruin)")
            if result then return result end
         end
         return try_cast(Spells.ShadowBolt, ctx.target, "[DEMO] Shadow Bolt")
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      matches = function(ctx, state)
         local min_hp = ctx.settings.life_tap_min_hp or 40
         if ctx.hp < min_hp then return false end
         local threshold = ctx.settings.life_tap_mana_pct or 30
         return ctx.mana_pct < threshold
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.LifeTap, ctx.me,
            "[DEMO] Life Tap (fallback) - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
      end,
   }
   table.insert(Demo_Strategies, strategy)
end

-- =============================================================================
-- DESTRUCTION STATE
-- =============================================================================
local destro_state = {
   immolate_duration = 0,
   curse_duration = 0,
   backlash_active = false,
   isb_active = false,
   target_below_execute = false,
   is_fire_build = false,
}

local function get_destro_state(ctx)
   if ctx._destro_valid then return destro_state end
   ctx._destro_valid = true

   local target = ctx.target
   if target then
      destro_state.immolate_duration = target:debuff_remains(Constants.DEBUFF_ID.IMMOLATE) or 0
      destro_state.isb_active = (target:debuff_remains(Constants.DEBUFF_ID.ISB) or 0) > 0
   else
      destro_state.immolate_duration = 0
      destro_state.isb_active = false
   end
   destro_state.curse_duration = get_curse_duration(ctx)
   destro_state.backlash_active = ctx.has_backlash

   local sb_hp = ctx.settings.destro_shadowburn_hp or 10
   destro_state.target_below_execute = ctx.target_hp < sb_hp
   destro_state.is_fire_build = ctx.settings.destro_primary_spell == "incinerate"

   return destro_state
end

-- =============================================================================
-- DESTRUCTION STRATEGIES
-- =============================================================================
local Destro_Strategies = {}

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "destro_use_backlash",
      matches = function(ctx, state)
         return state.backlash_active
      end,
      execute = function(ctx, icon)
         if state.is_fire_build and is_spell_available(Spells.Incinerate) then
            local result = try_cast(Spells.Incinerate, ctx.target, "[DESTRO] Incinerate (Backlash)")
            if result then return result end
         end
         return try_cast(Spells.ShadowBolt, ctx.target, "[DESTRO] Shadow Bolt (Backlash)")
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "destro_use_immolate",
      matches = function(ctx, state)
         if not state.is_fire_build then return false end
         if ctx.is_moving then return false end
         return state.immolate_duration < 3
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Immolate, ctx.target,
            "[DESTRO] Immolate - Dur: " .. string.format("%.1fs", state.immolate_duration))
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "destro_use_conflagrate",
      matches = function(ctx, state)
         if not state.is_fire_build then return false end
         return state.immolate_duration > 0
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Conflagrate, ctx.target,
            "[DESTRO] Conflagrate - Immo: " .. string.format("%.1fs", state.immolate_duration))
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         if ctx.settings.curse_type == "none" then return false end
         return state.curse_duration < 1.5
      end,
      execute = function(ctx, icon)
         local curse_spell = get_curse_spell(ctx)
         if curse_spell then
            return try_cast(curse_spell, ctx.target, "[DESTRO] " .. ctx.settings.curse_type)
         end
         return nil
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "destro_use_shadowfury",
      matches = function(ctx, state)
         if state.is_fire_build then return true end
         local threshold = ctx.settings.aoe_threshold or 0
         if threshold == 0 then return false end
         if ctx.enemy_count < threshold then return false end
         return true
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Shadowfury, ctx.target, "[DESTRO] Shadowfury")
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      setting_key = "destro_use_shadowburn",
      matches = function(ctx, state)
         if ctx.soul_shards < 1 then return false end
         return state.target_below_execute
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.Shadowburn, ctx.target,
            "[DESTRO] Shadowburn - Target: " .. string.format("%.0f%% Shards: %d", ctx.target_hp, ctx.soul_shards))
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         local threshold = ctx.settings.aoe_threshold or 0
         if threshold == 0 then return false end
         if ctx.enemy_count < threshold then return false end
         if ctx.is_moving then return false end
         return true
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.SeedOfCorruption, ctx.target,
            "[DESTRO] Seed of Corruption (AoE) - Enemies: " .. ctx.enemy_count)
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      is_gcd_gated = false,
      is_burst = true,
      setting_key = "use_racial",
      matches = function(ctx, state)
         local min_ttd = ctx.settings.cd_min_ttd or 0
         if min_ttd > 0 and ctx.ttd and ctx.ttd > 0 and ctx.ttd < min_ttd then return false end
         return Spells.BloodFury:is_usable() or Spells.ArcaneTorrent:is_usable()
      end,
      execute = function(ctx, icon)
         if Spells.BloodFury:is_usable() then
            return Spells.BloodFury:cast(ctx.me, "[DESTRO] Blood Fury")
         end
         if Spells.ArcaneTorrent:is_usable() then
            return Spells.ArcaneTorrent:cast(ctx.me, "[DESTRO] Arcane Torrent")
         end
         return nil
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      requires_enemy = true,
      matches = function(ctx, state)
         return not ctx.is_moving
      end,
      execute = function(ctx, icon)
         if state.is_fire_build and is_spell_available(Spells.Incinerate) then
            local result = try_cast(Spells.Incinerate, ctx.target, "[DESTRO] Incinerate")
            if result then return result end
         end
         return try_cast(Spells.ShadowBolt, ctx.target, "[DESTRO] Shadow Bolt")
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

do
   local strategy = {
      requires_combat = true,
      matches = function(ctx, state)
         local min_hp = ctx.settings.life_tap_min_hp or 40
         if ctx.hp < min_hp then return false end
         local threshold = ctx.settings.life_tap_mana_pct or 30
         return ctx.mana_pct < threshold
      end,
      execute = function(ctx, icon)
         return try_cast(Spells.LifeTap, ctx.me,
            "[DESTRO] Life Tap (fallback) - Mana: " .. string.format("%.0f%%", ctx.mana_pct))
      end,
   }
   table.insert(Destro_Strategies, strategy)
end

-- =============================================================================
-- STRATEGY EXECUTOR
-- =============================================================================
local function check_prerequisites(strategy, ctx)
   if strategy.requires_combat and not ctx.in_combat then return false end
   if strategy.requires_enemy and not ctx.has_valid_enemy_target then return false end
   if strategy.setting_key then
      local setting = get_setting(ctx.settings, strategy.setting_key)
      if setting == false then return false end
   end
   if strategy.matches then
      return strategy.matches(ctx)
   end
   return true
end

local function execute_strategies(strategies, ctx, icon, state_fn)
   for _, strategy in ipairs(strategies) do
      if not ctx.on_gcd or strategy.is_gcd_gated == false then
         if check_prerequisites(strategy, ctx) then
            local result = strategy.execute(ctx, icon, state_fn and state_fn(ctx))
            if result then
               return result
            end
         end
      end
   end
   return nil
end

-- =============================================================================
-- MAIN ROTATION CALLBACK
-- =============================================================================
core.register_on_update_callback(function()
   local me = izi.me()
   if not me then return end

   local ctx = FluxCompat.build_context(extend_context)
   if not ctx then return end

   local settings = {}
   for k, v in pairs(defaults) do
      settings[k] = v
   end
   ctx.settings = settings

   local icon = nil
   local result = FluxCompat.rotation_registry:execute_middleware(ctx, icon)
   if result then
      return
   end

   local playstyle = get_setting(settings, "playstyle") or "affliction"

   if playstyle == "affliction" then
      execute_strategies(Aff_Strategies, ctx, icon, get_affliction_state)
   elseif playstyle == "demonology" then
      execute_strategies(Demo_Strategies, ctx, icon, get_demo_state)
   elseif playstyle == "destruction" then
      execute_strategies(Destro_Strategies, ctx, icon, get_destro_state)
   end
end)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Warlock main rotation loaded - Affliction/Demonology/Destruction")
