-- =============================================================================
-- ROGUE MAIN ROTATION - SYLVANAS FRAMEWORK
-- Contains all rotation logic, spells, constants, menu, and playstyle strategies
-- All 3 playstyles: assassination, combat, subtlety
-- Converted from Flux AIO - Consolidated into single main.lua
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local SettingsBridge = require("libraries.settings_bridge")
local FluxCompat = require("libraries.flux_compat")

-- =============================================================================
-- SPELL DEFINITIONS
-- =============================================================================
local Spells = {
   -- Racials
   BloodFury = izi.spell(20572),
   Berserking = izi.spell(26297),
   ArcaneTorrent = izi.spell(25046),
   WilloftheForsaken = izi.spell(7744),
   EscapeArtist = izi.spell(20589),
   Stoneform = izi.spell(20594),

   -- Builders
   SinisterStrike = izi.spell(1752),
   Backstab = izi.spell(53),
   Mutilate = izi.spell(34413),
   Hemorrhage = izi.spell(16511),
   GhostlyStrike = izi.spell(14278),
   Shiv = izi.spell(5938),

   -- Finishers
   SliceAndDice = izi.spell(5171),
   Eviscerate = izi.spell(2098),
   Rupture = izi.spell(1943),
   Envenom = izi.spell(32645),
   ExposeArmor = izi.spell(8647),
   KidneyShot = izi.spell(408),

   -- Stealth Openers
   Ambush = izi.spell(8676),
   Garrote = izi.spell(703),
   CheapShot = izi.spell(1833),
   Premeditation = izi.spell(14183),

   -- Defensive / Utility
   Evasion = izi.spell(5277),
   Sprint = izi.spell(2983),
   CloakOfShadows = izi.spell(31224),
   Vanish = izi.spell(1856),
   Kick = izi.spell(1766),
   Feint = izi.spell(1966),
   Gouge = izi.spell(1776),
   Blind = izi.spell(2094),

   -- Cooldowns
   BladeFlurry = izi.spell(13877),
   AdrenalineRush = izi.spell(13750),
   ColdBlood = izi.spell(14177),
   Preparation = izi.spell(14185),
   Shadowstep = izi.spell(36554),

   -- Items
   HastePotion = izi.item(22838),
   ThistleTea = izi.item(7676),
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),
}

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local Constants = {
   BUFF_ID = {
      SLICE_AND_DICE = 6774,
      BLADE_FLURRY = 13877,
      ADRENALINE_RUSH = 13750,
      COLD_BLOOD = 14177,
      EVASION = 26669,
      SPRINT = 26023,
      CLOAK_OF_SHADOWS = 31224,
      STEALTH = 1787,
      SHADOWSTEP_BUFF = 36563,
      REMORSELESS_ATTACKS = 14143,
      MASTER_OF_SUBTLETY = 31665,
   },

   DEBUFF_ID = {
      RUPTURE = 26867,
      EXPOSE_ARMOR = 26866,
      GARROTE = 26884,
      HEMORRHAGE = 26864,
      DEADLY_POISON = 27187,
      WOUND_POISON = 27189,
      FIND_WEAKNESS = 31234,
   },

   ENERGY = {
      SINISTER_STRIKE = 45,
      BACKSTAB = 60,
      MUTILATE = 60,
      HEMORRHAGE = 35,
      GHOSTLY_STRIKE = 40,
      SHIV = 20,
      SLICE_AND_DICE = 25,
      EVISCERATE = 35,
      RUPTURE = 25,
      ENVENOM = 35,
      EXPOSE_ARMOR = 25,
      KICK = 25,
      FEINT = 20,
      AMBUSH = 60,
      GARROTE = 50,
      CHEAP_SHOT = 60,
   },

   ROGUE = {
      SND_MIN_DURATION = 2,
      DP_REFRESH_THRESHOLD = 2,
   },
}

-- =============================================================================
-- SETTINGS BRIDGE INITIALIZATION
-- =============================================================================
SettingsBridge:init("rogue_rotation_settings")
FluxCompat.register_trinket_middleware()

local function s(key, default)
   return SettingsBridge:get(key, default)
end

-- =============================================================================
-- BUFF/DEBUFF HELPERS
-- =============================================================================
local function buff_has(unit, buff_id)
   if not unit then return false end
   return unit.buff_up and unit:buff_up(buff_id) or false
end

local function buff_remains(unit, buff_id)
   if not unit then return 0 end
   return unit.buff_remains and unit:buff_remains(buff_id) or 0
end

local function debuff_has(unit, debuff_id)
   if not unit then return false end
   return unit.debuff_up and unit:buff_up(debuff_id) or false
end

local function debuff_remains(unit, debuff_id)
   if not unit then return 0 end
   return unit.debuff_remains and unit:debuff_remains(debuff_id) or 0
end

local function debuff_stacks(unit, debuff_id)
   if not unit then return 0 end
   return unit.get_debuff_stacks and unit:get_debuff_stacks(debuff_id) or 0
end

-- =============================================================================
-- SPELL CAST HELPERS
-- =============================================================================
local function try_cast(spell, target, message)
   if not spell or not spell.is_learned then
      return false
   end
   if not spell:is_usable() then
      return false
   end
   if target and not spell:is_castable_to_unit(target) then
      return false
   end
   return spell:cast(target, message or "")
end

local function try_cast_off_gcd(spell, target, message)
   if not spell or not spell.is_learned then
      return false
   end
   local me = izi.me()
   if me:gcd_remains() > 0.1 then
      return false
   end
   if not spell:is_usable() then
      return false
   end
   if target and not spell:is_castable_to_unit(target) then
      return false
   end
   return spell:cast(target, message or "")
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

   local gcd_remains = me:gcd_remains()
   local on_gcd = gcd_remains > 0.1

   local ctx = {
      me = me,
      target = target,
      on_gcd = on_gcd,
      gcd_remains = gcd_remains,
      in_combat = me:time_in_combat() > 0,
      hp = me:get_health_percentage(),
      energy = me:energy_current() or 0,
      combo_points = me:combo_points() or 0,
      combat_time = me:time_in_combat(),
      is_mounted = me.is_mounted and me.is_mounted or false,
      is_moving = me.is_moving and me.is_moving or false,
      target_exists = target and target.is_valid and target:is_valid() or false,
      target_dead = target and target.is_dead and target:is_dead() or false,
      target_enemy = target and target.is_valid_enemy and target:is_valid_enemy() or false,
      has_valid_enemy_target = target and target.is_valid and target:is_valid() and target.is_valid_enemy and target:is_valid_enemy() and not (target.is_dead and target:is_dead()),
      target_hp = target and target.get_health_percentage and target:get_health_percentage() or 0,
      target_range = target and target.distance and target:distance() or 999,
      in_melee_range = target and target.distance and target:distance() <= 5,
      ttd = target and target.time_to_die and target:time_to_die() or 999,
      is_boss = target and target.is_dummy and target:is_dummy() or false,
   }

   local enemies = izi.enemies(8)
   ctx.enemy_count = enemies and #enemies or 0
   ctx.is_pvp = false
   ctx.target_is_player = target and target.is_player and target:is_player() or false

   ctx.has_slice_and_dice = buff_remains(me, Constants.BUFF_ID.SLICE_AND_DICE) > 0
   ctx.snd_duration = buff_remains(me, Constants.BUFF_ID.SLICE_AND_DICE)
   ctx.blade_flurry_active = buff_remains(me, Constants.BUFF_ID.BLADE_FLURRY) > 0
   ctx.adrenaline_rush_active = buff_remains(me, Constants.BUFF_ID.ADRENALINE_RUSH) > 0

   ctx._assassination_valid = false
   ctx._combat_valid = false
   ctx._subtlety_valid = false

   return ctx
end

-- =============================================================================
-- STATE MANAGEMENT
-- =============================================================================
local combat_state = {
   rupture_active = false,
   rupture_duration = 0,
   expose_armor_active = false,
   snd_need_refresh = false,
}

local assassination_state = {
   deadly_poison_stacks = 0,
   envenom_ready = false,
}

local subtlety_state = {
   shadowstep_ready = false,
   find_weakness_active = false,
}

local function update_combat_state(ctx)
   if ctx._combat_valid then return combat_state end
   ctx._combat_valid = true
   local target = ctx.target
   combat_state.rupture_duration = debuff_remains(target, Constants.DEBUFF_ID.RUPTURE)
   combat_state.rupture_active = combat_state.rupture_duration > 0
   combat_state.expose_armor_active = debuff_remains(target, Constants.DEBUFF_ID.EXPOSE_ARMOR) > 0
   combat_state.snd_need_refresh = ctx.snd_duration <= Constants.ROGUE.SND_MIN_DURATION
   return combat_state
end

local function update_assassination_state(ctx)
   if ctx._assassination_valid then return assassination_state end
   ctx._assassination_valid = true
   local target = ctx.target
   assassination_state.deadly_poison_stacks = debuff_stacks(target, Constants.DEBUFF_ID.DEADLY_POISON)
   assassination_state.envenom_ready = assassination_state.deadly_poison_stacks >= s("assassination_envenom_min_stacks", 2)
   return assassination_state
end

local function update_subtlety_state(ctx)
   if ctx._subtlety_valid then return subtlety_state end
   ctx._subtlety_valid = true
   subtlety_state.shadowstep_ready = Spells.Shadowstep:is_usable()
   subtlety_state.find_weakness_active = debuff_remains(ctx.target, Constants.DEBUFF_ID.FIND_WEAKNESS) > 0
   return subtlety_state
end

-- =============================================================================
-- PLAYSTYLE GETTER
-- =============================================================================
local function get_playstyle()
   return s("playstyle") or "combat"
end

-- =============================================================================
-- ROTATION FUNCTIONS
-- =============================================================================
local function execute_combat_rotation(ctx)
   local me = ctx.me
   local target = ctx.target
   local state = update_combat_state(ctx)

   -- Blade Flurry
   if s("combat_use_blade_flurry") then
      if not ctx.blade_flurry_active and ctx.enemy_count >= 2 then
         if Spells.BladeFlurry:is_usable() and try_cast(Spells.BladeFlurry, me, "[COMBAT] Blade Flurry") then
            return true
         end
      end
   end

   -- Slice and Dice maintenance
   if state.snd_need_refresh then
      if ctx.combo_points >= 1 then
         if Spells.SliceAndDice:is_usable() and try_cast(Spells.SliceAndDice, me, "[COMBAT] Slice and Dice") then
            return true
         end
      end
   end

   -- Rupture maintenance
   if s("combat_use_rupture") then
      if not state.rupture_active or state.rupture_duration < s("combat_rupture_refresh", 2) then
         if ctx.combo_points >= s("combat_min_cp_finisher", 5) and ctx.ttd > s("combat_rupture_min_ttd", 12) then
            if Spells.Rupture:is_usable() and try_cast(Spells.Rupture, target, "[COMBAT] Rupture") then
               return true
            end
         end
      end
   end

   -- Eviscerate (finisher)
   if ctx.combo_points >= s("combat_min_cp_finisher", 5) then
      if Spells.Eviscerate:is_usable() and try_cast(Spells.Eviscerate, target, "[COMBAT] Eviscerate") then
         return true
      end
   end

   -- Builders
   if Spells.SinisterStrike:is_usable() then
      if try_cast(Spells.SinisterStrike, target, "[COMBAT] Sinister Strike") then
         return true
      end
   end

   return false
end

local function execute_assassination_rotation(ctx)
   local me = ctx.me
   local target = ctx.target
   local state = update_combat_state(ctx)
   local ass_state = update_assassination_state(ctx)

   -- Slice and Dice maintenance
   if state.snd_need_refresh then
      if ctx.combo_points >= 1 then
         if Spells.SliceAndDice:is_usable() and try_cast(Spells.SliceAndDice, me, "[ASSASSINATION] Slice and Dice") then
            return true
         end
      end
   end

   -- Rupture maintenance
   if s("assassination_use_rupture") then
      if not state.rupture_active or state.rupture_duration < s("assassination_rupture_refresh", 2) then
         if ctx.combo_points >= s("assassination_min_cp_finisher", 4) and ctx.ttd > s("assassination_rupture_min_ttd", 12) then
            if Spells.Rupture:is_usable() and try_cast(Spells.Rupture, target, "[ASSASSINATION] Rupture") then
               return true
            end
         end
      end
   end

   -- Envenom
   if s("assassination_use_envenom") then
      if ass_state.envenom_ready and ctx.combo_points >= s("assassination_min_cp_finisher", 4) then
         if Spells.Envenom:is_usable() and try_cast(Spells.Envenom, target, "[ASSASSINATION] Envenom") then
            return true
         end
      end
   end

   -- Eviscerate (fallback finisher)
   if ctx.combo_points >= s("assassination_min_cp_finisher", 4) then
      if Spells.Eviscerate:is_usable() and try_cast(Spells.Eviscerate, target, "[ASSASSINATION] Eviscerate") then
         return true
      end
   end

   -- Mutilate (builder)
   if Spells.Mutilate:is_usable() then
      if try_cast(Spells.Mutilate, target, "[ASSASSINATION] Mutilate") then
         return true
      end
   end

   return false
end

local function execute_subtlety_rotation(ctx)
   local me = ctx.me
   local target = ctx.target
   local state = update_combat_state(ctx)
   local sub_state = update_subtlety_state(ctx)

   -- Shadowstep
   if s("subtlety_use_shadowstep") then
      if sub_state.shadowstep_ready then
         if Spells.Shadowstep:is_usable() and try_cast(Spells.Shadowstep, target, "[SUBTLETY] Shadowstep") then
            return true
         end
      end
   end

   -- Ghostly Strike
   if s("subtlety_use_ghostly_strike") then
      if Spells.GhostlyStrike:is_usable() then
         if try_cast(Spells.GhostlyStrike, target, "[SUBTLETY] Ghostly Strike") then
            return true
         end
      end
   end

   -- Slice and Dice maintenance
   if state.snd_need_refresh then
      if ctx.combo_points >= 1 then
         if Spells.SliceAndDice:is_usable() and try_cast(Spells.SliceAndDice, me, "[SUBTLETY] Slice and Dice") then
            return true
         end
      end
   end

   -- Rupture maintenance
   if s("subtlety_use_rupture") then
      if not state.rupture_active or state.rupture_duration < s("subtlety_rupture_refresh", 2) then
         if ctx.combo_points >= s("subtlety_min_cp_finisher", 5) and ctx.ttd > s("subtlety_rupture_min_ttd", 12) then
            if Spells.Rupture:is_usable() and try_cast(Spells.Rupture, target, "[SUBTLETY] Rupture") then
               return true
            end
         end
      end
   end

   -- Eviscerate
   if ctx.combo_points >= s("subtlety_min_cp_finisher", 5) then
      if Spells.Eviscerate:is_usable() and try_cast(Spells.Eviscerate, target, "[SUBTLETY] Eviscerate") then
         return true
      end
   end

   -- Backstab (builder)
   if Spells.Backstab:is_usable() then
      if try_cast(Spells.Backstab, target, "[SUBTLETY] Backstab") then
         return true
      end
   end

   return false
end

-- =============================================================================
-- MAIN CALLBACK
-- =============================================================================
local function on_update_callback()
   local ctx = build_context()
   if not ctx then
      return
   end

   ctx.settings = SettingsBridge:get_all()

   if FluxCompat.is_force_active("burst") then
      ctx.force_burst = true
   end

   if FluxCompat.rotation_registry:execute_middleware(ctx) then
      return
   end

   if not ctx.in_combat then
      return
   end

   local playstyle = get_playstyle()

   if playstyle == "combat" then
      if execute_combat_rotation(ctx) then
         return
      end
   elseif playstyle == "assassination" then
      if execute_assassination_rotation(ctx) then
         return
      end
   elseif playstyle == "subtlety" then
      if execute_subtlety_rotation(ctx) then
         return
      end
   end
end

-- =============================================================================
-- REGISTER CALLBACK
-- =============================================================================
core.register_on_update_callback(on_update_callback)

-- =============================================================================
-- MENU REGISTRATION
-- =============================================================================
core.register_on_render_menu_callback(function()
   local menu = core.menu

   menu.tree_node("Rogue", function()
      menu.separator()

      menu.tree_node("Playstyle", function()
         menu.combobox("playstyle", "Active Spec", {
            { text = "Combat", value = "combat" },
            { text = "Assassination", value = "assassination" },
            { text = "Subtlety", value = "subtlety" },
         }, "Which spec rotation to use.")
      end)

      menu.separator()

      menu.tree_node("General", function()
         menu.checkbox("use_kick", "Auto Kick", true, "Interrupt enemy casts.")
         menu.checkbox("use_feint", "Auto Feint", false, "Use Feint for threat reduction.")
         menu.checkbox("use_expose_armor", "Expose Armor", false, "Use Expose Armor at 5 CP.")
         menu.checkbox("use_shiv", "Use Shiv", true, "Use Shiv to refresh Deadly Poison.")
      end)

      menu.tree_node("Combat", function()
         menu.checkbox("combat_use_blade_flurry", "Use Blade Flurry", true)
         menu.checkbox("combat_use_adrenaline_rush", "Use Adrenaline Rush", true)
         menu.checkbox("combat_use_rupture", "Use Rupture", true)
         menu.slider_int("combat_min_cp_finisher", "Min CP for Finisher", 5, 3, 5)
      end)

      menu.tree_node("Assassination", function()
         menu.checkbox("assassination_use_envenom", "Use Envenom", true)
         menu.slider_int("assassination_envenom_min_stacks", "Envenom Min DP Stacks", 2, 1, 5)
         menu.slider_int("assassination_min_cp_finisher", "Min CP for Finisher", 4, 3, 5)
      end)

      menu.tree_node("Subtlety", function()
         menu.checkbox("subtlety_use_shadowstep", "Use Shadowstep", true)
         menu.checkbox("subtlety_use_ghostly_strike", "Use Ghostly Strike", true)
         menu.slider_int("subtlety_min_cp_finisher", "Min CP for Finisher", 5, 3, 5)
      end)

      menu.tree_node("CDs & Defense", function()
         menu.checkbox("use_racial", "Use Racial", true)
         menu.checkbox("use_evasion", "Auto Evasion", false)
         menu.slider_int("evasion_hp", "Evasion HP (%)", 40, 0, 75)
      end)
   end)
end)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Rogue rotation loaded - v1.8.10")
