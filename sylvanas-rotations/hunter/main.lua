-- =============================================================================
-- HUNTER MAIN ROTATION - SYLVANAS FRAMEWORK
-- Converted from Flux AIO Hunter
-- Ranged rotation with pet management, aspect handling, and shot weaving
-- Self-contained version with local Spells
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local SettingsBridge = require("libraries.settings_bridge")
local FluxCompat = require("libraries.flux_compat")

-- =============================================================================
-- AUTO ATTACK HELPER
-- =============================================================================
local aa_helper = require("common/utility/auto_attack_helper")

-- =============================================================================
-- SPELL DEFINITIONS
-- =============================================================================
local Spells = {
   -- Racials
   Berserking = izi.spell(26297),
   ArcaneTorrent = izi.spell(28730),
   BloodFury = izi.spell(20572),
   GiftOfTheNaaru = izi.spell(28880),

   -- Beast Mastery
   BestialWrath = izi.spell(19574),
   Intimidation = izi.spell(19577),
   KillCommand = izi.spell(34026),

   -- Marksmanship
   AimedShot = izi.spell(19434),
   ArcaneShot = izi.spell(3044),
   SteadyShot = izi.spell(56641),
   MultiShot = izi.spell(2643),
   ChimeraShot = izi.spell(53209),
   SilencingShot = izi.spell(34490),
   ScatterShot = izi.spell(19503),
   Readiness = izi.spell(23989),
   RapidFire = izi.spell(3045),
   TrueshotAura = izi.spell(19506),
   HuntersMark = izi.spell(1130),

   -- Survival
   ExplosiveShot = izi.spell(53301),
   BlackArrow = izi.spell(3674),
   SerpentSting = izi.spell(1978),
   WyvernSting = izi.spell(19386),
   Counterattack = izi.spell(19306),
   Deterrence = izi.spell(19263),
   Disengage = izi.spell(781),
   FeignDeath = izi.spell(5384),
   Misdirection = izi.spell(34477),

   -- Melee
   RaptorStrike = izi.spell(2973),
   MongooseBite = izi.spell(1495),
   WingClip = izi.spell(2974),

   -- Aspects
   AspectoftheHawk = izi.spell(13165),
   AspectoftheMonkey = izi.spell(13163),
   AspectoftheCheetah = izi.spell(5118),
   AspectofthePack = izi.spell(13159),
   AspectoftheViper = izi.spell(34074),
   AspectoftheBeast = izi.spell(13161),
   AspectoftheWild = izi.spell(20043),

   -- Pet
   CallPet = izi.spell(883),
   RevivePet = izi.spell(982),
   MendPet = izi.spell(136),
   FeedPet = izi.spell(6991),
   DismissPet = izi.spell(2641),

   -- Tracking and Utility
   AutoShot = izi.spell(75),
   TrackBeasts = izi.spell(1494),
   TrackHumanoids = izi.spell(19883),
   TrackUndead = izi.spell(19884),
   TrackHidden = izi.spell(19885),
   TrackElementals = izi.spell(19880),
   TrackDemons = izi.spell(19878),
   TrackGiants = izi.spell(19882),
   TrackDragonkin = izi.spell(19879),

   -- Items
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   SuperManaPotion = izi.item(22832),
   MajorManaPotion = izi.item(13443),
   HastePotion = izi.item(22838),
}

-- =============================================================================
-- SETTINGS BRIDGE INITIALIZATION
-- =============================================================================
SettingsBridge:init("hunter_rotation_settings")

local function s(key, default)
   return SettingsBridge:get(key, default)
end

-- =============================================================================
-- DEFAULT SETTINGS
-- =============================================================================
local defaults = {
   playstyle = "beast_mastery",
   aspect_hawk = true,
   aspect_viper = true,
   mana_viper_start = 10,
   mana_viper_end = 30,
   use_pet = true,
   pet_heal_hp = 50,
   use_hunters_mark = true,
   use_serpent_sting = true,
   use_arcane_shot = true,
   use_steady_shot = true,
   use_multi_shot = true,
   use_aimed_shot = true,
   use_kill_command = true,
   use_raptor_strike = true,
   use_wing_clip = true,
   use_concussive = true,
   use_bestial_wrath = true,
   use_rapid_fire = true,
   use_readiness = true,
   cd_min_ttd = 15,
   use_interrupt = true,
   use_feign_death = true,
   use_deterrence = true,
   defensive_hp = 20,
   use_healthstone = true,
   healthstone_hp = 30,
   use_healing_potion = true,
   healing_potion_hp = 25,
   shot_weave_enabled = true,
   clip_protection = true,
   clip_window = 0.3,
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================
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

-- =============================================================================
-- CONTEXT BUILDER
-- =============================================================================
local function build_context()
   local me = izi.me()
   local target = izi.target()

   if not me or not me.is_valid or not me:is_valid() then
      return nil
   end

   local ctx = {
      me = me,
      target = target,
      in_combat = me:time_in_combat() > 0,
      hp = me:get_health_percentage(),
      mana = me:mana_current(),
      mana_pct = me:mana_pct(),
      focus = me:power_current(),
      target_exists = target and target.is_valid and target:is_valid() or false,
      target_enemy = target and target.is_valid_enemy and target:is_valid_enemy() or false,
      has_valid_enemy_target = target and target.is_valid and target:is_valid() and target.is_valid_enemy and target:is_valid_enemy(),
      target_hp = target and target.get_health_percentage and target:get_health_percentage() or 0,
      target_range = target and target.distance and target:distance() or 999,
      in_melee_range = target and target.distance and target:distance() <= 5,
      settings = defaults,
      next_auto_shot = 999,
      auto_shot_remaining = 999,
      is_auto_attacking = false,
   }

   if aa_helper and aa_helper.get_next_attack_game_time then
      local now = core.game_time()
      ctx.next_auto_shot = aa_helper:get_next_attack_game_time(me, 1) or 999
      ctx.auto_shot_remaining = math.max(0, ctx.next_auto_shot - now)
      ctx.is_auto_attacking = aa_helper:is_auto_attacking(me) or false
   end

   return ctx
end

-- =============================================================================
-- ROTATION FUNCTIONS
-- =============================================================================
local function check_interrupt(ctx)
   if not ctx.settings.use_interrupt then return nil end
   if not ctx.has_valid_enemy_target then return nil end
   if not ctx.target.is_casting then return nil end

   local cast_remains = ctx.target.get_cast_remaining_sec and ctx.target:get_cast_remaining_sec() or 0
   if cast_remains <= 0 then return nil end

   if Spells.SilencingShot and Spells.SilencingShot:is_learned() and Spells.SilencingShot:is_usable() then
      if try_cast(Spells.SilencingShot, ctx.target, "[P1] Silencing Shot - Interrupt") then
         return true
      end
   end

   if Spells.ScatterShot and Spells.ScatterShot:is_learned() and Spells.ScatterShot:is_usable() then
      if try_cast(Spells.ScatterShot, ctx.target, "[P1] Scatter Shot - Interrupt") then
         return true
      end
   end

   return nil
end

local function check_defensive(ctx)
   if not ctx.in_combat then return nil end

   if s.use_feign_death and ctx.hp <= s.defensive_hp then
      if Spells.FeignDeath and Spells.FeignDeath:is_learned() and Spells.FeignDeath:is_usable() then
         if try_cast(Spells.FeignDeath, nil, "[P2] Feign Death - Emergency") then
            return true
         end
      end
   end

   if s.use_deterrence and ctx.hp <= s.defensive_hp then
      if Spells.Deterrence and Spells.Deterrence:is_learned() and Spells.Deterrence:is_usable() then
         if try_cast(Spells.Deterrence, nil, "[P2] Deterrence - Emergency") then
            return true
         end
      end
   end

   if s.use_healthstone and ctx.hp <= s.healthstone_hp then
      if Spells.HealthstoneMaster and Spells.HealthstoneMaster:is_usable() then
         if try_cast(Spells.HealthstoneMaster, nil, "[P2] Healthstone") then
            return true
         end
      end
   end

   return nil
end

local function check_pet(ctx)
   if not s("use_pet") then return nil end

   local pet = izi.pet()
   if not pet or not pet.is_valid or not pet:is_valid() then
      if Spells.RevivePet and Spells.RevivePet:is_learned() and Spells.RevivePet:is_usable() then
         if try_cast(Spells.RevivePet, nil, "[P3] Revive Pet") then
            return true
         end
      end

      if Spells.CallPet and Spells.CallPet:is_learned() and Spells.CallPet:is_usable() then
         if try_cast(Spells.CallPet, nil, "[P3] Call Pet") then
            return true
         end
      end
   else
      if Spells.MendPet and Spells.MendPet:is_learned() then
         local pet_hp = pet:get_health_percentage() or 100
         if pet_hp <= s.pet_heal_hp and Spells.MendPet:is_usable() then
            if try_cast(Spells.MendPet, nil, "[P3] Mend Pet") then
               return true
            end
         end
      end

      if s.use_kill_command and Spells.KillCommand and Spells.KillCommand:is_learned() then
         if ctx.has_valid_enemy_target and Spells.KillCommand:is_usable() then
            if try_cast(Spells.KillCommand, ctx.target, "[P3] Kill Command") then
               return true
            end
         end
      end
   end

   return nil
end

local function check_burst(ctx)
   if not ctx.in_combat then return nil end
   if not ctx.has_valid_enemy_target then return nil end

   local ttd = ctx.target.time_to_die and ctx.target:time_to_die() or 0
   if ttd < s("cd_min_ttd") then return nil end

   if s.use_bestial_wrath and Spells.BestialWrath and Spells.BestialWrath:is_learned() then
      if Spells.BestialWrath:is_usable() then
         if try_cast(Spells.BestialWrath, nil, "[P4] Bestial Wrath - Burst") then
            return true
         end
      end
   end

   if s.use_rapid_fire and Spells.RapidFire and Spells.RapidFire:is_learned() then
      if Spells.RapidFire:is_usable() then
         if try_cast(Spells.RapidFire, nil, "[P4] Rapid Fire - Burst") then
            return true
         end
      end
   end

   return nil
end

local function check_aspects(ctx)
   local me = ctx.me

   if s("aspect_viper") and ctx.mana_pct <= s("mana_viper_start") then
      if not me:buff_up(Spells.AspectoftheViper:id()) then
         if Spells.AspectoftheViper and Spells.AspectoftheViper:is_usable() then
            if try_cast(Spells.AspectoftheViper, nil, "[P5] Aspect of the Viper - Mana") then
               return true
            end
         end
      end
   end

   if s("aspect_hawk") and ctx.mana_pct > s("mana_viper_end") then
      if not me:buff_up(Spells.AspectoftheHawk:id()) then
         if Spells.AspectoftheHawk and Spells.AspectoftheHawk:is_usable() then
            if try_cast(Spells.AspectoftheHawk, nil, "[P5] Aspect of the Hawk") then
               return true
            end
         end
      end
   end

   return nil
end

local function check_trueshot(ctx)
   if not Spells.TrueshotAura then return nil end
   if not Spells.TrueshotAura:is_learned() then return nil end

   local me = ctx.me
   if not me:buff_up(Spells.TrueshotAura:id()) then
      if Spells.TrueshotAura:is_usable() then
         if try_cast(Spells.TrueshotAura, nil, "[P6] Trueshot Aura") then
            return true
         end
      end
   end

   return nil
end

local function check_hunters_mark(ctx)
   if not s("use_hunters_mark") then return nil end
   if not ctx.has_valid_enemy_target then return nil end

   if not Spells.HuntersMark then return nil end
   if not Spells.HuntersMark:is_learned() then return nil end

   if ctx.target:debuff_up(Spells.HuntersMark:id()) then return nil end

   if Spells.HuntersMark:is_usable() and Spells.HuntersMark:is_in_range(ctx.target) then
      if try_cast(Spells.HuntersMark, ctx.target, "[P7] Hunter's Mark") then
         return true
      end
   end

   return nil
end

local function check_damage(ctx)
   if not ctx.has_valid_enemy_target then return nil end
   if ctx.target_range > 35 then return nil end

   local target = ctx.target
   local me = ctx.me

   if ctx.in_melee_range then
      if s("use_raptor_strike") and Spells.RaptorStrike and Spells.RaptorStrike:is_learned() then
         if Spells.RaptorStrike:is_usable() and Spells.RaptorStrike:is_castable_to_unit(target) then
            if try_cast(Spells.RaptorStrike, target, "[P8] Raptor Strike") then
               return true
            end
         end
      end

      if Spells.MongooseBite and Spells.MongooseBite:is_learned() then
         if Spells.MongooseBite:is_usable() and Spells.MongooseBite:is_castable_to_unit(target) then
            if try_cast(Spells.MongooseBite, target, "[P8] Mongoose Bite") then
               return true
            end
         end
      end

      if s("use_wing_clip") and Spells.WingClip and Spells.WingClip:is_learned() then
         if not target:debuff_up(Spells.WingClip:id()) then
            if Spells.WingClip:is_usable() and Spells.WingClip:is_castable_to_unit(target) then
               if try_cast(Spells.WingClip, target, "[P8] Wing Clip") then
                  return true
               end
            end
         end
      end

      return nil
   end

   if s("use_serpent_sting") and Spells.SerpentSting and Spells.SerpentSting:is_learned() then
      if not target:debuff_up(Spells.SerpentSting:id()) then
         if Spells.SerpentSting:is_usable() and Spells.SerpentSting:is_in_range(target) then
            if try_cast(Spells.SerpentSting, target, "[P8] Serpent Sting") then
               return true
            end
         end
      end
   end

   if s("use_aimed_shot") and Spells.AimedShot and Spells.AimedShot:is_learned() then
      if Spells.AimedShot:is_usable() and Spells.AimedShot:is_in_range(target) then
         if not (me.is_moving and me.is_moving) then
            if try_cast(Spells.AimedShot, target, "[P8] Aimed Shot") then
               return true
            end
         end
      end
   end

   if s("use_arcane_shot") and Spells.ArcaneShot and Spells.ArcaneShot:is_learned() then
      if Spells.ArcaneShot:is_usable() and Spells.ArcaneShot:is_in_range(target) then
         if try_cast(Spells.ArcaneShot, target, "[P8] Arcane Shot") then
            return true
         end
      end
   end

   if s("use_multi_shot") and Spells.MultiShot and Spells.MultiShot:is_learned() then
      if Spells.MultiShot:is_usable() and Spells.MultiShot:is_in_range(target) then
         if try_cast(Spells.MultiShot, target, "[P8] Multi-Shot") then
            return true
         end
      end
   end

   if s("use_steady_shot") and Spells.SteadyShot and Spells.SteadyShot:is_learned() then
      if Spells.SteadyShot:is_usable() and Spells.SteadyShot:is_in_range(target) then
         if not (me.is_moving and me.is_moving) then
            local can_weave = true
            if s("shot_weave_enabled") and ctx.is_auto_attacking then
               local steady_cast_time = 1.5
               if Spells.SteadyShot.cast_time then
                  steady_cast_time = Spells.SteadyShot:cast_time() / 1000
               end

               local clip_window = s("clip_window") or 0.3
               if ctx.auto_shot_remaining < steady_cast_time + clip_window and ctx.auto_shot_remaining > 0 then
                  can_weave = false
               end
            end

            if can_weave then
               if try_cast(Spells.SteadyShot, target, "[P8] Steady Shot") then
                  return true
               end
            end
         end
      end
   end

   if Spells.AutoShot and Spells.AutoShot:is_learned() then
      if Spells.AutoShot:is_usable() and Spells.AutoShot:is_in_range(target) then
         if try_cast(Spells.AutoShot, target, "[P8] Auto Shot") then
            return true
         end
      end
   end

   return nil
end

-- =============================================================================
-- FLUXCOMPAT MIDDLEWARE REGISTRATION
-- =============================================================================
FluxCompat.register_trinket_middleware()

FluxCompat.rotation_registry:register_middleware("check_interrupt", check_interrupt, 250, { is_gcd_gated = true })
FluxCompat.rotation_registry:register_middleware("check_defensive", check_defensive, 400, { is_defensive = true, is_gcd_gated = false })
FluxCompat.rotation_registry:register_middleware("check_pet", check_pet, 100)
FluxCompat.rotation_registry:register_middleware("check_burst", check_burst, 80, { is_burst = true, is_gcd_gated = false })
FluxCompat.rotation_registry:register_middleware("check_aspects", check_aspects, 140)
FluxCompat.rotation_registry:register_middleware("check_trueshot", check_trueshot, 145)
FluxCompat.rotation_registry:register_middleware("check_hunters_mark", check_hunters_mark, 130)
FluxCompat.rotation_registry:register_middleware("check_damage", check_damage, 1)

-- =============================================================================
-- MAIN ROTATION EXECUTION
-- =============================================================================
local function on_update_callback()
   local ctx = build_context()
   if not ctx then return nil end

   ctx.force_burst = FluxCompat.is_force_active("burst")
   ctx.force_defensive = FluxCompat.is_force_active("defensive")
   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   FluxCompat.rotation_registry:execute_middleware(ctx)

   return nil
end

-- =============================================================================
-- REGISTER CALLBACK
-- =============================================================================
core.register_on_update_callback(on_update_callback)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Hunter main rotation loaded - v1.8.0 (FluxCompat integrated)")
