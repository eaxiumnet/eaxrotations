-- =============================================================================
-- WARRIOR MAIN ROTATION - SYLVANAS FRAMEWORK
-- Contains all rotation logic, spells, constants, menu, and playstyle strategies
-- All 3 playstyles: arms, fury, protection
-- Converted from Flux AIO - Consolidated into single main.lua
-- =============================================================================

local core = _G.core
local izi = require("common/izi_sdk")
local SettingsBridge = require("libraries.settings_bridge")
local FluxCompat = require("libraries.flux_compat")

-- =============================================================================
-- SPELL DEFINITIONS (Converted from Flux A.Create to izi.spell)
-- =============================================================================
local Spells = {
   -- Racials
   BloodFury = izi.spell(20572),
   Berserking = izi.spell(26297),
   Stoneform = izi.spell(20594),
   WillOfTheForsaken = izi.spell(7744),
   WarStomp = izi.spell(20549),
   EscapeArtist = izi.spell(20589),

   -- Core Damage (multi-rank)
   HeroicStrike = izi.spell(78),
   Cleave = izi.spell(845),
   MortalStrike = izi.spell(12294),
   Bloodthirst = izi.spell(23881),
   Execute = izi.spell(5308),
   Overpower = izi.spell(7384),
   Slam = izi.spell(1464),
   Revenge = izi.spell(6572),
   ShieldSlam = izi.spell(23922),
   Devastate = izi.spell(20243),
   Rend = izi.spell(772),
   Hamstring = izi.spell(1715),
   SunderArmor = izi.spell(7386),
   ThunderClap = izi.spell(6343),

   -- Single-rank spells
   Whirlwind = izi.spell(1680),
   VictoryRush = izi.spell(34428),
   Taunt = izi.spell(355),
   MockingBlow = izi.spell(694),
   ChallengingShout = izi.spell(1161),
   Charge = izi.spell(100),
   Intercept = izi.spell(20252),

   -- Shouts
   BattleShout = izi.spell(6673),
   CommandingShout = izi.spell(469),
   DemoralizingShout = izi.spell(1160),

   -- Cooldowns (self-cast)
   DeathWish = izi.spell(12292),
   Recklessness = izi.spell(1719),
   SweepingStrikes = izi.spell(12328),
   Bloodrage = izi.spell(2687),
   BerserkerRage = izi.spell(18499),
   Rampage = izi.spell(29801),

   -- Defensive (self-cast)
   ShieldBlock = izi.spell(2565),
   ShieldWall = izi.spell(871),
   LastStand = izi.spell(12975),
   SpellReflection = izi.spell(23920),

   -- Stances
   BattleStance = izi.spell(2457),
   DefensiveStance = izi.spell(71),
   BerserkerStance = izi.spell(2458),

   -- Defensive abilities
   Retaliation = izi.spell(20230),

   -- Interrupts
   Pummel = izi.spell(6552),
   ShieldBash = izi.spell(72),

   -- PvP CC / Utility
   Disarm = izi.spell(676),
   IntimidatingShout = izi.spell(5246),
   ConcussionBlow = izi.spell(12809),
   PiercingHowl = izi.spell(12323),
   Intervene = izi.spell(3411),
   Perception = izi.spell(20600),

   -- Items
   SuperHealingPotion = izi.item(22829),
   MajorHealingPotion = izi.item(13446),
   HealthstoneMaster = izi.item(22105),
   HealthstoneMajor = izi.item(22104),

   -- Bandages
   HeavyNetherweaveBandage = izi.item(21991),
   NetherweaveBandage = izi.item(21990),
   HeavyRuneclothBandage = izi.item(14530),
   RuneclothBandage = izi.item(14529),
   HeavyMageweaveBandage = izi.item(8545),
   MageweaveBandage = izi.item(8544),
   HeavySilkBandage = izi.item(6451),
   SilkBandage = izi.item(6450),
   HeavyWoolBandage = izi.item(3531),
   WoolBandage = izi.item(3530),
   HeavyLinenBandage = izi.item(2581),
   LinenBandage = izi.item(1251),
}

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local Constants = {
   STANCE = {
      BATTLE = 1,
      DEFENSIVE = 2,
      BERSERKER = 3,
   },

   PREFERRED_STANCE = {
      arms = 1,
      fury = 3,
      protection = 2,
   },

   BATTLE_SHOUT_IDS = { 6673, 5242, 6192, 11549, 11550, 11551, 2048 },
   COMMANDING_SHOUT_IDS = { 469 },

   BUFF_ID = {
      BATTLE_SHOUT = 2048,
      COMMANDING_SHOUT = 469,
      DEATH_WISH = 12292,
      RECKLESSNESS = 1719,
      SWEEPING_STRIKES = 12328,
      BERSERKER_RAGE = 18499,
      ENRAGE = 14202,
      FLURRY = 12974,
      RAMPAGE = 30033,
      SHIELD_BLOCK = 2565,
      LAST_STAND = 12975,
      SPELL_REFLECTION = 23920,
      RETALIATION = 20230,
      POWER_WORD_SHIELD = 17,
      BLESSING_OF_PROT = 1022,
   },

   DEBUFF_ID = {
      REND = 25208,
      SUNDER_ARMOR = 25225,
      THUNDER_CLAP = 25264,
      DEMO_SHOUT = 25203,
   },

   SUNDER_MAX_STACKS = 5,
   SUNDER_REFRESH_WINDOW = 3,
   TC_REFRESH_WINDOW = 2,
   RAMPAGE_MAX_STACKS = 5,

   PVP = {
      AttackTypes = { "TotalImun", "DamagePhysImun" },
      AuraForInterrupt = { "TotalImun", "DamagePhysImun", "KickImun" },
      AuraForFear = { "TotalImun", "DamagePhysImun", "FearImun" },
      AuraForStun = { "TotalImun", "DamagePhysImun", "CCTotalImun", "StunImun" },
      AuraForSlow = { "TotalImun", "DamagePhysImun", "CCTotalImun", "Freedom" },
      AuraForDisarm = { "TotalImun", "DamagePhysImun", "CCTotalImun" },
   },

   TAUNT = {
      CC_THRESHOLD = 2,
      MIN_TTD = 4,
      CSHOUT_RANGE = 10,
      CSHOUT_MIN_BOSSES = 1,
      CSHOUT_MIN_ELITES = 3,
      CSHOUT_MIN_TRASH = 5,
   },
}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================
local function get_tactical_mastery_cap()
   return 25
end

local function is_stance_swap_safe(current_rage, ability_cost)
   local tm_cap = get_tactical_mastery_cap()
   local rage_after_swap = current_rage <= tm_cap and current_rage or tm_cap
   return rage_after_swap >= ability_cost
end

-- =============================================================================
-- SETTINGS BRIDGE INITIALIZATION
-- =============================================================================
local aa_helper = require("common/utility/auto_attack_helper")
SettingsBridge:init("warrior_rotation_settings")
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
   return unit.debuff_up and unit:debuff_up(debuff_id) or false
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
-- SWING TIMER DETECTION
-- =============================================================================
local function get_playstyle()
   return s("playstyle") or "fury"
end

local function update_swing_timers(ctx)
   local me = ctx.me
   if not me then return end
    local equipped = (me.get_equipped_items and me:get_equipped_items()) or {}
   local oh_item = equipped[17]
   ctx.has_offhand = oh_item ~= nil
   
   if aa_helper and aa_helper.get_next_attack_game_time then
      local now = core.game_time()
      local mh_next = aa_helper:get_next_attack_game_time(me, 1)
      ctx.mh_next = mh_next
      ctx.mh_remain = math.max(0, mh_next - now)
      
      if ctx.has_offhand then
         local oh_next = aa_helper:get_next_attack_game_time(me, 2)
         ctx.oh_next = oh_next
         ctx.oh_remain = math.max(0, oh_next - now)
      else
         ctx.oh_next = 999
         ctx.oh_remain = 999
      end
      
      local attack_speed = me:get_attack_speed()
      ctx.mh_speed = attack_speed
      ctx.oh_speed = ctx.has_offhand and attack_speed or 0
   else
      ctx.has_offhand = false
      ctx.mh_remain = 999
      ctx.oh_remain = 999
      ctx.mh_speed = 0
      ctx.oh_speed = 0
   end
end

-- =============================================================================
-- HS QUEUE TRICK
-- =============================================================================
local hs_queued = false

local function check_hs_queued(ctx)
   local me = ctx.me
   if not me then return false end
   local has_hs_buff = me:buff_up(12163) or me:buff_up(25710)
   if has_hs_buff then
      hs_queued = true
   end
   return hs_queued
end

local function execute_hs_queue_trick(ctx)
   if not ctx.has_offhand then return false end
   if not ctx.in_combat or not ctx.has_valid_enemy_target then return false end
   if not s("hs_trick", true) then return false end
   
   update_swing_timers(ctx)
   local HS_COST = 15
   local currently_queued = check_hs_queued(ctx)
   
   if not currently_queued then
      if ctx.oh_remain > 0 and ctx.oh_remain <= 0.4 then
         if ctx.mh_remain > ctx.oh_remain + 0.3 then
            local rage_threshold = s("fury_hs_rage_threshold", 50)
            if ctx.playstyle == "fury" and s("hs_trick", true) then
               rage_threshold = 30
            end
            
            if ctx.rage >= HS_COST then
               local target_hp = ctx.target_hp or 100
               if target_hp <= 20 then
                  local exec_key = ctx.playstyle .. "_hs_during_execute"
                  if not s(exec_key, true) then
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

   -- Handle force commands
   if FluxCompat.is_force_active("gap") and ctx.has_valid_enemy_target then
      local target = ctx.target
      if target and target.distance and target:distance() > 5 then
         if Spells.Charge and Spells.Charge:is_usable() and try_cast_off_gcd(Spells.Charge, target, "[FORCE] Charge") then
            return
         end
      end
   end

   if FluxCompat.is_force_active("burst") then
      ctx.force_burst = true
   end

   if FluxCompat.is_force_active("defensive") then
      ctx.force_defensive = true
   end

   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   -- Execute middleware (defensives, interrupts, recovery)
   if FluxCompat.rotation_registry:execute_middleware(ctx) then
      return
   end

   if not ctx.in_combat then
      return
   end

   -- Execute rotation based on playstyle
   local playstyle = get_playstyle()

   if playstyle == "arms" then
      if execute_arms_rotation(ctx) then
         return
      end
   elseif playstyle == "fury" then
      if execute_fury_rotation(ctx) then
         return
      end
   elseif playstyle == "protection" then
      if execute_prot_rotation(ctx) then
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

   menu.tree_node("Warrior", function()
      menu.separator()

      -- Playstyle Selection
      menu.tree_node("Playstyle", function()
         menu.combobox("playstyle", "Active Spec", {
            { text = "Arms", value = "arms" },
            { text = "Fury", value = "fury" },
            { text = "Protection", value = "protection" },
         }, "Which spec rotation to use.")
      end)

      menu.separator()

      -- General Settings
      menu.tree_node("General", function()
         menu.tree_node("Shouts", function()
            menu.combobox("shout_type", "Shout Type", {
               { text = "Battle Shout", value = "battle" },
               { text = "Commanding Shout", value = "commanding" },
               { text = "None", value = "none" },
            }, "Which shout to maintain.")
            menu.checkbox("auto_shout", "Auto Shout", true, "Automatically maintain selected shout buff.")
         end)

         menu.tree_node("Debuff Maintenance", function()
            menu.combobox("sunder_armor_mode", "Sunder Armor", {
               { text = "None", value = "none" },
               { text = "Help Stack (to 5)", value = "help_stack" },
               { text = "Maintain (stack + refresh)", value = "maintain" },
            }, "Sunder Armor maintenance mode.")
            menu.checkbox("maintain_thunder_clap", "Maintain Thunder Clap", false, "Keep Thunder Clap debuff on target.")
            menu.checkbox("maintain_demo_shout", "Maintain Demo Shout", false, "Keep Demoralizing Shout debuff on target.")
         end)

         menu.tree_node("Utility", function()
            menu.checkbox("use_interrupt", "Auto Interrupt", true, "Interrupt enemy casts.")
            menu.checkbox("use_bloodrage", "Auto Bloodrage", true, "Use Bloodrage on cooldown.")
            menu.slider_int("bloodrage_min_hp", "Bloodrage Min HP (%)", 50, 20, 80, "Don't use Bloodrage when HP is below this.")
            menu.checkbox("use_berserker_rage", "Auto Berserker Rage", true, "Use Berserker Rage on cooldown.")
            menu.checkbox("use_auto_charge", "Auto Charge", true, "Automatically Charge to close gaps.")
         end)

         menu.tree_node("AoE", function()
            menu.slider_int("aoe_threshold", "Cleave Threshold", 2, 0, 8, "Use Cleave at this many enemies.")
         end)

         menu.tree_node("Heroic Strike", function()
            menu.checkbox("hs_trick", "HS Queue Trick (DW)", true, "Queue HS before off-hand swings.")
         end)
      end)

      -- Arms Settings
      menu.tree_node("Arms", function()
         menu.tree_node("Core Abilities", function()
            menu.checkbox("arms_maintain_rend", "Maintain Rend", true, "Keep Rend DoT on target.")
            menu.slider_int("arms_rend_refresh", "Rend Refresh (sec)", 4, 2, 8, "Refresh Rend when remaining duration is below this.")
            menu.checkbox("arms_use_overpower", "Use Overpower", true, "Use Overpower on dodge procs.")
            menu.checkbox("arms_use_whirlwind", "Use Whirlwind", true, "Use Whirlwind on cooldown.")
         end)

         menu.tree_node("Execute Phase", function()
            menu.checkbox("arms_execute_phase", "Execute Phase", true, "Switch to Execute priority at <20% target HP.")
            menu.checkbox("arms_use_ms_execute", "MS During Execute", true, "Use Mortal Strike during execute phase.")
            menu.checkbox("arms_use_ww_execute", "WW During Execute", true, "Use Whirlwind during execute phase.")
         end)

         menu.tree_node("Rage Dump", function()
            menu.slider_int("arms_hs_rage_threshold", "HS Rage Threshold", 50, 30, 80, "Queue Heroic Strike above this rage.")
         end)
      end)

      -- Fury Settings
      menu.tree_node("Fury", function()
         menu.tree_node("Core Abilities", function()
            menu.checkbox("fury_use_whirlwind", "Use Whirlwind", true, "Use Whirlwind on cooldown.")
            menu.slider_int("fury_ww_prio_count", "WW Prio Mob Count", 2, 0, 6, "Prioritize Whirlwind over Bloodthirst.")
         end)

         menu.tree_node("Execute Phase", function()
            menu.checkbox("fury_execute_phase", "Execute Phase", true, "Switch to Execute priority at <20% target HP.")
            menu.checkbox("fury_bt_during_execute", "BT During Execute", true, "Use Bloodthirst during execute phase.")
         end)
      end)

      -- Protection Settings
      menu.tree_node("Protection", function()
         menu.tree_node("Core Abilities", function()
            menu.checkbox("prot_use_shield_block", "Auto Shield Block", true, "Maintain Shield Block on cooldown.")
            menu.checkbox("prot_use_revenge", "Use Revenge", true, "Use Revenge when available.")
            menu.checkbox("prot_use_devastate", "Use Devastate", true, "Use Devastate.")
         end)

         menu.tree_node("Taunts", function()
            menu.checkbox("prot_no_taunt", "Disable Taunts (Off-Tank)", false, "Disables Taunt.")
            menu.checkbox("prot_use_taunt", "Auto Taunt", true, "Taunt when you lose aggro.")
         end)
      end)

      -- CDs & Survival
      menu.tree_node("CDs & Survival", function()
         menu.tree_node("Emergency Survival", function()
            menu.slider_int("last_stand_hp", "Last Stand HP (%)", 20, 0, 50, "Use Last Stand below this HP.")
            menu.slider_int("shield_wall_hp", "Shield Wall HP (%)", 15, 0, 50, "Use Shield Wall below this HP.")
         end)
      end)
   end)
end)

-- =============================================================================
-- LOG
-- =============================================================================
core.log("Warrior rotation loaded - v1.8.10")
               end
               hs_queued = true
               return true, "[HS TRICK] Queue for yellow OH"
            end
         end
      end
   end
   
   if currently_queued then
      if ctx.mh_remain > 0 and ctx.mh_remain <= 0.4 then
         if ctx.rage < HS_COST then
            hs_queued = false
            local me = ctx.me
            if me and me.cancel_buff then
               me:cancel_buff(12163)
            end
            return true, "[HS TRICK] Dequeue - low rage"
         end
         
         local target = ctx.target
         if target and target:is_casting() then
            local cast_remaining = target:get_cast_remaining_sec()
            if cast_remaining > 0 and cast_remaining < 2.0 then
               if ctx.rage < (HS_COST + 10) then
                  hs_queued = false
                  return true, "[HS TRICK] Dequeue - save for interrupt"
               end
            end
         end
      end
   end
   
   if currently_queued then
      local target_hp = ctx.target_hp or 100
      if target_hp <= 20 then
         local exec_key = ctx.playstyle .. "_execute_phase"
         local hs_exec_key = ctx.playstyle .. "_hs_during_execute"
         if s(exec_key, true) and not s(hs_exec_key, true) then
            hs_queued = false
            return true, "[HS TRICK] Dequeue - execute phase"
         end
      end
   end
   
   return false
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

   local stance = 1
   if buff_has(me, 2458) then
      stance = Constants.STANCE.BERSERKER
   elseif buff_has(me, 71) then
      stance = Constants.STANCE.DEFENSIVE
   else
      stance = Constants.STANCE.BATTLE
   end

   local ctx = {
      me = me,
      target = target,
      on_gcd = on_gcd,
      gcd_remains = gcd_remains,
      in_combat = me:time_in_combat() > 0,
      hp = me:get_health_percentage(),
      rage = me:rage_current() or 0,
      rage_pct = me:rage_pct() or 0,
      combat_time = me:time_in_combat(),
      is_mounted = me.is_mounted and me.is_mounted or false,
      is_moving = me.is_moving and me.is_moving or false,
      stance = stance,
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
   ctx.is_arena = false
   ctx.is_battleground = false
   ctx.target_is_player = target and target.is_player and target:is_player() or false
   ctx.has_battle_shout = buff_remains(me, Constants.BUFF_ID.BATTLE_SHOUT) > 0
   ctx.has_commanding_shout = buff_remains(me, Constants.BUFF_ID.COMMANDING_SHOUT) > 0
   ctx.death_wish_active = buff_remains(me, Constants.BUFF_ID.DEATH_WISH) > 0
   ctx.recklessness_active = buff_remains(me, Constants.BUFF_ID.RECKLESSNESS) > 0
   ctx.sweeping_strikes_active = buff_remains(me, Constants.BUFF_ID.SWEEPING_STRIKES) > 0
   ctx.berserker_rage_active = buff_remains(me, Constants.BUFF_ID.BERSERKER_RAGE) > 0
   ctx.rampage_active = buff_remains(me, Constants.BUFF_ID.RAMPAGE) > 0
   ctx.rampage_stacks = 0
   ctx.rampage_duration = buff_remains(me, Constants.BUFF_ID.RAMPAGE)
   ctx.shield_block_active = buff_remains(me, Constants.BUFF_ID.SHIELD_BLOCK) > 0
   ctx.enrage_active = buff_remains(me, Constants.BUFF_ID.ENRAGE) > 0
   ctx.flurry_active = buff_remains(me, Constants.BUFF_ID.FLURRY) > 0

   update_swing_timers(ctx)
   ctx.hs_queued = check_hs_queued(ctx)
   ctx._arms_valid = false
   ctx._fury_valid = false
   ctx._prot_valid = false

   return ctx
end

-- =============================================================================
-- STATE MANAGEMENT
-- =============================================================================
local arms_state = {
   rend_active = false,
   rend_duration = 0,
   target_below_20 = false,
   sunder_stacks = 0,
   sunder_duration = 0,
   thunder_clap_duration = 0,
   demo_shout_duration = 0,
   ms_cd = 0,
   ww_cd = 0,
}

local fury_state = {
   target_below_20 = false,
   sunder_stacks = 0,
   sunder_duration = 0,
   thunder_clap_duration = 0,
   demo_shout_duration = 0,
   bt_cd = 0,
   ww_cd = 0,
}

local prot_state = {
   revenge_available = false,
   sunder_stacks = 0,
   sunder_duration = 0,
   thunder_clap_debuff = 0,
   demo_shout_debuff = 0,
   target_below_20 = false,
}

local function update_arms_state(ctx)
   if ctx._arms_valid then return arms_state end
   ctx._arms_valid = true
   local target = ctx.target
   arms_state.rend_duration = debuff_remains(target, Constants.DEBUFF_ID.REND)
   arms_state.rend_active = arms_state.rend_duration > 0
   arms_state.target_below_20 = ctx.target_hp < 20
   arms_state.sunder_stacks = debuff_stacks(target, Constants.DEBUFF_ID.SUNDER_ARMOR)
   arms_state.sunder_duration = debuff_remains(target, Constants.DEBUFF_ID.SUNDER_ARMOR)
   arms_state.thunder_clap_duration = debuff_remains(target, Constants.DEBUFF_ID.THUNDER_CLAP)
   arms_state.demo_shout_duration = debuff_remains(target, Constants.DEBUFF_ID.DEMO_SHOUT)
   arms_state.ms_cd = Spells.MortalStrike.cooldown_remains and Spells.MortalStrike:cooldown_remains() or 0
   arms_state.ww_cd = Spells.Whirlwind.cooldown_remains and Spells.Whirlwind:cooldown_remains() or 0
   return arms_state
end

local function update_fury_state(ctx)
   if ctx._fury_valid then return fury_state end
   ctx._fury_valid = true
   local target = ctx.target
   fury_state.target_below_20 = ctx.target_hp < 20
   fury_state.sunder_stacks = debuff_stacks(target, Constants.DEBUFF_ID.SUNDER_ARMOR)
   fury_state.sunder_duration = debuff_remains(target, Constants.DEBUFF_ID.SUNDER_ARMOR)
   fury_state.thunder_clap_duration = debuff_remains(target, Constants.DEBUFF_ID.THUNDER_CLAP)
   fury_state.demo_shout_duration = debuff_remains(target, Constants.DEBUFF_ID.DEMO_SHOUT)
   fury_state.bt_cd = Spells.Bloodthirst.cooldown_remains and Spells.Bloodthirst:cooldown_remains() or 0
   fury_state.ww_cd = Spells.Whirlwind.cooldown_remains and Spells.Whirlwind:cooldown_remains() or 0
   return fury_state
end

local function update_prot_state(ctx)
   if ctx._prot_valid then return prot_state end
   ctx._prot_valid = true
   local target = ctx.target
   prot_state.revenge_available = Spells.Revenge:is_usable()
   prot_state.sunder_stacks = debuff_stacks(target, Constants.DEBUFF_ID.SUNDER_ARMOR)
   prot_state.sunder_duration = debuff_remains(target, Constants.DEBUFF_ID.SUNDER_ARMOR)
   prot_state.thunder_clap_debuff = debuff_remains(target, Constants.DEBUFF_ID.THUNDER_CLAP)
   prot_state.demo_shout_debuff = debuff_remains(target, Constants.DEBUFF_ID.DEMO_SHOUT)
   prot_state.target_below_20 = ctx.target_hp < 20
   return prot_state
end

-- =============================================================================
-- ROTATION FUNCTIONS
-- =============================================================================
local FILLER_HOLD_WINDOW = 2.0
local RAGE_COST_MS = 30
local RAGE_COST_WW = 25
local RAGE_COST_SLAM = 15

local function should_pool_for_core_arms(ctx, state)
   if state.ms_cd > 0 and state.ms_cd <= FILLER_HOLD_WINDOW then
      if (ctx.rage - RAGE_COST_SLAM) < RAGE_COST_MS then return true end
   end
   if s("arms_use_whirlwind") and state.ww_cd > 0 and state.ww_cd <= FILLER_HOLD_WINDOW then
      if (ctx.rage - RAGE_COST_SLAM) < RAGE_COST_WW then return true end
   end
   return false
end

local function should_pool_for_core_fury(ctx, state)
   if state.bt_cd > 0 and state.bt_cd <= FILLER_HOLD_WINDOW then
      if (ctx.rage - RAGE_COST_SLAM) < 30 then return true end
   end
   if s("fury_use_whirlwind") and state.ww_cd > 0 and state.ww_cd <= FILLER_HOLD_WINDOW then
      if (ctx.rage - RAGE_COST_SLAM) < RAGE_COST_WW then return true end
   end
   return false
end

local function execute_arms_rotation(ctx)
   local me = ctx.me
   local target = ctx.target
   local state = update_arms_state(ctx)

   -- Maintain Rend
   if s("arms_maintain_rend") then
      if not state.target_below_20 or not s("arms_execute_phase") then
         local refresh = s("arms_rend_refresh") or 4
         if (not state.rend_active or state.rend_duration < refresh) and Spells.Rend:is_usable() then
            if try_cast(Spells.Rend, target, "[ARMS] Rend") then return true end
         end
      end
   end

   -- Mortal Strike
   if s("arms_execute_phase") and not s("arms_use_ms_execute") and state.target_below_20 then
      -- Skip MS in execute if disabled
   else
      if Spells.MortalStrike:is_usable() and try_cast(Spells.MortalStrike, target, "[ARMS] Mortal Strike") then
         return true
      end
   end

   -- Sweeping Strikes
   if s("arms_use_sweeping_strikes") then
      if not ctx.sweeping_strikes_active and ctx.enemy_count >= 2 and ctx.rage >= 30 then
         if Spells.SweepingStrikes:is_usable() and try_cast(Spells.SweepingStrikes, me, "[ARMS] Sweeping Strikes") then
            return true
         end
      end
   end

   -- Whirlwind (Berserker Stance)
   if s("arms_use_whirlwind") then
      if not state.target_below_20 or s("arms_use_ww_execute") then
         if ctx.rage >= 25 then
            if ctx.stance ~= Constants.STANCE.BERSERKER then
               if is_stance_swap_safe(ctx.rage, 25) then
                  if Spells.BerserkerStance:is_usable() and try_cast_off_gcd(Spells.BerserkerStance, me, "[ARMS] Berserker Stance") then
                     return true
                  end
               end
            else
               if Spells.Whirlwind:is_usable() and try_cast(Spells.Whirlwind, target, "[ARMS] Whirlwind") then
                  return true
               end
            end
         end
      end
   end

   -- Overpower (Battle Stance)
   if s("arms_use_overpower") then
      if ctx.stance ~= Constants.STANCE.BATTLE then
         if Spells.BattleStance:is_usable() and try_cast_off_gcd(Spells.BattleStance, me, "[ARMS] Battle Stance") then
            return true
         end
      else
         if Spells.Overpower:is_usable() and try_cast(Spells.Overpower, target, "[ARMS] Overpower") then
            return true
         end
      end
   end

   -- Execute
   if s("arms_execute_phase") and state.target_below_20 then
      if ctx.rage >= 25 and Spells.Execute:is_usable() then
         if try_cast(Spells.Execute, target, "[ARMS] Execute") then
            return true
         end
      end
   end

   -- Victory Rush
   if s("arms_use_victory_rush") then
      if Spells.VictoryRush:is_usable() and try_cast(Spells.VictoryRush, target, "[ARMS] Victory Rush") then
         return true
      end
   end

   -- Sunder Armor maintenance
   local SunderMode = s("sunder_armor_mode") or "none"
   if SunderMode ~= "none" then
      if SunderMode == "help_stack" and state.sunder_stacks < 5 then
         if Spells.Devastate:is_usable() and try_cast(Spells.Devastate, target, "[ARMS] Devastate") then
            return true
         end
         if Spells.SunderArmor:is_usable() and try_cast(Spells.SunderArmor, target, "[ARMS] Sunder Armor") then
            return true
         end
      elseif SunderMode == "maintain" then
         if state.sunder_stacks < 5 or state.sunder_duration < Constants.SUNDER_REFRESH_WINDOW then
            if Spells.Devastate:is_usable() and try_cast(Spells.Devastate, target, "[ARMS] Devastate") then
               return true
            end
            if Spells.SunderArmor:is_usable() and try_cast(Spells.SunderArmor, target, "[ARMS] Sunder Armor") then
               return true
            end
         end
      end
   end

   -- Thunder Clap maintenance
   if s("maintain_thunder_clap") then
      if state.thunder_clap_duration <= 2 then
         if Spells.ThunderClap:is_usable() and try_cast(Spells.ThunderClap, me, "[ARMS] Thunder Clap") then
            return true
         end
      end
   end

   -- Demoralizing Shout maintenance
   if s("maintain_demo_shout") then
      if ctx.in_melee_range and state.demo_shout_duration <= 3 then
         if Spells.DemoralizingShout:is_usable() and try_cast(Spells.DemoralizingShout, me, "[ARMS] Demo Shout") then
            return true
         end
      end
   end

   -- Slam (filler)
   if s("arms_use_slam") then
      if not ctx.is_moving and not state.target_below_20 and not should_pool_for_core_arms(ctx, state) then
         if Spells.Slam:is_usable() and try_cast(Spells.Slam, target, "[ARMS] Slam") then
            return true
         end
      end
   end

   -- Heroic Strike / Cleave
   if not s("arms_hs_during_execute") and state.target_below_20 then
      -- Skip HS during execute if disabled
   else
      local threshold = s("arms_hs_rage_threshold") or 50
      if ctx.rage >= threshold then
         local cleave_at = s("aoe_threshold") or 2
         if cleave_at > 0 and ctx.enemy_count >= cleave_at then
            if Spells.Cleave:is_usable() and try_cast(Spells.Cleave, target, "[ARMS] Cleave") then
               return true
            end
         end
         if Spells.HeroicStrike:is_usable() and try_cast(Spells.HeroicStrike, target, "[ARMS] Heroic Strike") then
            return true
         end
      end
   end

   return false
end

local function execute_fury_rotation(ctx)
   local me = ctx.me
   local target = ctx.target
   local state = update_fury_state(ctx)

   -- Rampage
   if not ctx.rampage_active or ctx.rampage_stacks < Constants.RAMPAGE_MAX_STACKS then
      if Spells.Rampage:is_usable() and try_cast(Spells.Rampage, me, "[FURY] Rampage") then
         return true
      end
   end

   -- Bloodthirst
   if s("fury_execute_phase") and not s("fury_bt_during_execute") and state.target_below_20 then
      -- Skip BT in execute if disabled
   else
      local ww_prio = s("fury_ww_prio_count") or 2
      if ww_prio > 0 and ctx.enemy_count >= ww_prio and ctx.rage >= 25 and s("fury_use_whirlwind") then
         -- Yield to WW
      else
         if Spells.Bloodthirst:is_usable() and try_cast(Spells.Bloodthirst, target, "[FURY] Bloodthirst") then
            return true
         end
      end
   end

   -- Sweeping Strikes
   if s("fury_use_sweeping_strikes") then
      if not ctx.sweeping_strikes_active and ctx.enemy_count >= 2 and ctx.rage >= 30 then
         if Spells.SweepingStrikes:is_usable() and try_cast(Spells.SweepingStrikes, me, "[FURY] Sweeping Strikes") then
            return true
         end
      end
   end

   -- Whirlwind
   if s("fury_use_whirlwind") then
      if not state.target_below_20 or s("fury_ww_during_execute") then
         if ctx.rage >= 25 then
            if ctx.stance ~= Constants.STANCE.BERSERKER then
               if Spells.BerserkerStance:is_usable() and try_cast_off_gcd(Spells.BerserkerStance, me, "[FURY] Berserker Stance") then
                  return true
               end
            else
               if Spells.Whirlwind:is_usable() and try_cast(Spells.Whirlwind, target, "[FURY] Whirlwind") then
                  return true
               end
            end
         end
      end
   end

   -- Execute
   if s("fury_execute_phase") and state.target_below_20 then
      if ctx.rage >= 25 and Spells.Execute:is_usable() then
         if try_cast(Spells.Execute, target, "[FURY] Execute") then
            return true
         end
      end
   end

   -- Victory Rush
   if s("fury_use_victory_rush") then
      if Spells.VictoryRush:is_usable() and try_cast(Spells.VictoryRush, target, "[FURY] Victory Rush") then
         return true
      end
   end

   -- Sunder Armor maintenance
   local SunderMode = s("sunder_armor_mode") or "none"
   if SunderMode ~= "none" then
      if SunderMode == "help_stack" and state.sunder_stacks < 5 then
         if Spells.Devastate:is_usable() and try_cast(Spells.Devastate, target, "[FURY] Devastate") then
            return true
         end
         if Spells.SunderArmor:is_usable() and try_cast(Spells.SunderArmor, target, "[FURY] Sunder Armor") then
            return true
         end
      elseif SunderMode == "maintain" then
         if state.sunder_stacks < 5 or state.sunder_duration < Constants.SUNDER_REFRESH_WINDOW then
            if Spells.Devastate:is_usable() and try_cast(Spells.Devastate, target, "[FURY] Devastate") then
               return true
            end
            if Spells.SunderArmor:is_usable() and try_cast(Spells.SunderArmor, target, "[FURY] Sunder Armor") then
               return true
            end
         end
      end
   end

   -- Thunder Clap maintenance
   if s("maintain_thunder_clap") then
      if state.thunder_clap_duration <= 2 then
         if Spells.ThunderClap:is_usable() and try_cast(Spells.ThunderClap, me, "[FURY] Thunder Clap") then
            return true
         end
      end
   end

   -- Demoralizing Shout maintenance
   if s("maintain_demo_shout") then
      if ctx.in_melee_range and state.demo_shout_duration <= 3 then
         if Spells.DemoralizingShout:is_usable() and try_cast(Spells.DemoralizingShout, me, "[FURY] Demo Shout") then
            return true
         end
      end
   end

   -- Slam (filler)
   if s("fury_use_slam") then
      if not ctx.is_moving and not state.target_below_20 and not should_pool_for_core_fury(ctx, state) then
         if Spells.Slam:is_usable() and try_cast(Spells.Slam, target, "[FURY] Slam") then
            return true
         end
      end
   end

   -- Hamstring weave
   if s("fury_use_hamstring") then
      local min_rage = s("fury_hamstring_rage") or 50
      if ctx.rage >= min_rage and Spells.Hamstring:is_usable() then
         if try_cast(Spells.Hamstring, target, "[FURY] Hamstring") then
            return true
         end
      end
   end

   -- Heroic Strike / Cleave
   if s("fury_use_heroic_strike") then
      if not s("fury_hs_during_execute") and state.target_below_20 then
         -- Skip HS during execute if disabled
      else
         local threshold = s("fury_hs_rage_threshold") or 50
         if ctx.rage >= threshold then
            local cleave_at = s("aoe_threshold") or 2
            if cleave_at > 0 and ctx.enemy_count >= cleave_at then
               if Spells.Cleave:is_usable() and try_cast(Spells.Cleave, target, "[FURY] Cleave") then
                  return true
               end
            end
            if Spells.HeroicStrike:is_usable() and try_cast(Spells.HeroicStrike, target, "[FURY] Heroic Strike") then
               return true
            end
         end
      end
   end

   return false
end

local function execute_prot_rotation(ctx)
   local me = ctx.me
   local target = ctx.target
   local state = update_prot_state(ctx)

   -- Shield Block (off-GCD)
   if s("prot_use_shield_block") then
      if not ctx.shield_block_active then
         if Spells.ShieldBlock:is_usable() and try_cast_off_gcd(Spells.ShieldBlock, me, "[PROT] Shield Block") then
            return true
         end
      end
   end

   -- Shield Slam
   if Spells.ShieldSlam:is_usable() and try_cast(Spells.ShieldSlam, target, "[PROT] Shield Slam") then
      return true
   end

   -- Revenge
   if s("prot_use_revenge") then
      if state.revenge_available then
         if try_cast(Spells.Revenge, target, "[PROT] Revenge") then
            return true
         end
      end
   end

   -- Thunder Clap (requires Battle Stance)
   if s("prot_use_thunder_clap") then
      local tc_min = s("prot_tc_min_mobs") or 3
      if ctx.enemy_count >= tc_min or ctx.is_boss then
         if state.thunder_clap_debuff <= Constants.TC_REFRESH_WINDOW then
            if ctx.stance ~= Constants.STANCE.BATTLE then
               if Spells.BattleStance:is_usable() and try_cast_off_gcd(Spells.BattleStance, me, "[PROT] Battle Stance") then
                  return true
               end
            else
               if Spells.ThunderClap:is_usable() and try_cast(Spells.ThunderClap, me, "[PROT] Thunder Clap") then
                  return true
               end
            end
         end
      end
   end

   -- Demoralizing Shout
   if s("prot_use_demo_shout") then
      local demo_min = s("prot_demo_min_mobs") or 6
      if ctx.enemy_count >= demo_min or ctx.is_boss then
         if state.demo_shout_debuff <= 3 then
            if Spells.DemoralizingShout:is_usable() and try_cast(Spells.DemoralizingShout, me, "[PROT] Demo Shout") then
               return true
            end
         end
      end
   end

   -- Devastate
   if s("prot_use_devastate") then
      if Spells.Devastate:is_usable() and try_cast(Spells.Devastate, target, "[PROT] Devastate") then
         return true
      end
   end

   -- Sunder Armor (if Devastate not available)
   if not s("prot_use_devastate") then
      if state.sunder_stacks < 5 or state.sunder_duration < Constants.SUNDER_REFRESH_WINDOW then
         if Spells.SunderArmor:is_usable() and try_cast(Spells.SunderArmor, target, "[PROT] Sunder Armor") then
            return true
         end
      end
   end

   -- Execute
   if s("prot_use_execute") and state.target_below_20 then
      if Spells.Execute:is_usable() and try_cast(Spells.Execute, target, "[PROT] Execute") then
         return true
      end
   end

   -- Victory Rush
   if s("prot_use_victory_rush") then
      if Spells.VictoryRush:is_usable() and try_cast(Spells.VictoryRush, target, "[PROT] Victory Rush") then
         return true
      end
   end

   -- Taunt
   if s("prot_use_taunt") and not s("prot_no_taunt") then
      if not ctx.target_is_player then
         if Spells.Taunt:is_usable() and try_cast(Spells.Taunt, target, "[PROT] Taunt") then
            return true
         end
      end
   end

   -- Challenging Shout
   if s("prot_use_challenging_shout") and not s("prot_no_taunt") then
      if Spells.ChallengingShout:is_usable() and try_cast(Spells.ChallengingShout, me, "[PROT] Challenging Shout") then
         return true
      end
   end

   -- Heroic Strike / Cleave
   local threshold = s("prot_hs_rage_threshold") or 60
   if ctx.rage >= threshold then
      local cleave_at = s("aoe_threshold") or 2
      if cleave_at > 0 and ctx.enemy_count >= cleave_at then
         if Spells.Cleave:is_usable() and try_cast(Spells.Cleave, target, "[PROT] Cleave") then
            return true
         end
      end
      if Spells.HeroicStrike:is_usable() and try_cast(Spells.HeroicStrike, target, "[PROT] Heroic Strike") then
         return true
      end
   end

   return false
end
