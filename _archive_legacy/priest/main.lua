-- =============================================================================
-- PRIEST MAIN ROTATION - SYLVANAS FRAMEWORK
-- All 4 playstyles: shadow, smite, holy, discipline
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
   Starshards = izi.spell(19305),
   DevouringPlague = izi.spell(25467),

   -- Shadow
   Shadowform = izi.spell(15473),
   ShadowWordPain = izi.spell(25368),
   VampiricTouch = izi.spell(34917),
   VampiricEmbrace = izi.spell(15286),
   MindBlast = izi.spell(25375),
   MindFlay = izi.spell(25387),
   ShadowWordDeath = izi.spell(32996),
   Silence = izi.spell(15487),
   Fade = izi.spell(25429),
   DispelMagic = izi.spell(988),
   MassDispel = izi.spell(32375),
   Shadowfiend = izi.spell(34433),
   PsychicScream = izi.spell(10890),

   -- Holy/Smite
   Smite = izi.spell(25363),
   HolyFire = izi.spell(25384),
   GreaterHeal = izi.spell(25314),
   FlashHeal = izi.spell(25235),
   Renew = izi.spell(25222),
   PrayerOfHealing = izi.spell(25308),
   CircleOfHealing = izi.spell(34861),
   HolyNova = izi.spell(25331),
   BindingHeal = izi.spell(32546),
   DesperatePrayer = izi.spell(25437),
   Resurrection = izi.spell(25435),

   -- Discipline
   PowerWordShield = izi.spell(25218),
   PowerWordFortitude = izi.spell(25389),
   PrayerOfFortitude = izi.spell(25392),
   DivineSpirit = izi.spell(25312),
   PrayerOfSpirit = izi.spell(32999),
   ShadowProtection = izi.spell(25433),
   PrayerOfShadowProtection = izi.spell(39374),
   InnerFire = izi.spell(25431),
   FearWard = izi.spell(6346),
   InnerFocus = izi.spell(14751),
   PowerInfusion = izi.spell(10060),
   PainSuppression = izi.spell(33206),
   PrayerOfMending = izi.spell(33076),
   Lightwell = izi.spell(28275),

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
      SHADOWFORM = 15473,
      INNER_FIRE = 25431,
      POWER_WORD_SHIELD = 17,
      FEAR_WARD = 6346,
      INNER_FOCUS = 14751,
      POWER_INFUSION = 10060,
      PAIN_SUPPRESSION = 33206,
      SURGE_OF_LIGHT = 58802,
      HOLY_CONCENTRATION = 34754,
      VAMPIRIC_EMBRACE = 15286,
      CLEARCASTING = 12536,
      WEAKENED_SOUL = 6788,
   },

   DEBUFF_ID = {
      SHADOW_WORD_PAIN = 25368,
      VAMPIRIC_TOUCH = 34917,
      DEVOURING_PLAGUE = 25467,
      HOLY_FIRE_DOT = 14914,
      WEAKENED_SOUL = 6788,
   },

   INNER_FIRE_IDS = {25431, 10938, 10937, 10936, 10951, 10952, 10953, 10954, 10955, 10956},
   FORTITUDE_IDS = {25389, 25392, 1243, 1244, 1245, 2791, 10937, 10938, 13864, 21562, 21564},
   DIVINE_SPIRIT_IDS = {25312, 32999, 14752, 14818, 14819, 27841, 39234},
   SHADOW_PROT_IDS = {25433, 39374, 976, 10957, 10958, 27683},
}

-- =============================================================================
-- FLUXCOMPAT INITIALIZATION
-- =============================================================================
FluxCompat.register_trinket_middleware()

FluxCompat.register_defensive_middleware("PowerWordShield", function(ctx)
   if ctx.is_mounted then return nil end
   if is_in_combat() and ctx.has_valid_enemy_target then
      local me = izi.me()
      if me:buff_remains(Constants.BUFF_ID.POWER_WORD_SHIELD) > 0 then return nil end
      if me:debuff_remains(Constants.DEBUFF_ID.WEAKENED_SOUL) > 0 then return nil end
      if Spells.PowerWordShield:is_usable() and Spells.PowerWordShield:is_in_range(me) then
         return Spells.PowerWordShield:cast(me, "[DEF] Power Word: Shield")
      end
   end
   return nil
end)

FluxCompat.register_defensive_middleware("FearWard", function(ctx)
   if is_in_combat() then return nil end
   if ctx.is_mounted then return nil end
   if not settings("use_fear_ward") then return nil end

   local me = izi.me()
   if not Spells.FearWard:is_usable() then return nil end

   local self_has = me:buff_remains(Constants.BUFF_ID.FEAR_WARD) > 0
   if not self_has then
      return Spells.FearWard:cast(me, "[DEF] Fear Ward (self)")
   end

   local focus = core.input.get_focus()
   if focus and focus:is_valid() and not focus:is_dead() then
      local focus_has = focus:buff_remains(Constants.BUFF_ID.FEAR_WARD) > 0
      if not focus_has and Spells.FearWard:is_in_range(focus) then
         return Spells.FearWard:cast(focus, "[DEF] Fear Ward (focus)")
      end
   end
   return nil
end)

FluxCompat.register_defensive_middleware("DesperatePrayer", function(ctx)
   if not is_in_combat() then return nil end
   if not settings("use_desperate_prayer") then return nil end

   local threshold = settings("desperate_prayer_hp") or 30
   local hp = ctx.hp
   if hp > threshold then return nil end

   if Spells.DesperatePrayer:is_usable() and Spells.DesperatePrayer:cooldown_up() then
      return Spells.DesperatePrayer:cast(izi.me(), "[DEF] Desperate Prayer")
   end
   return nil
end)

FluxCompat.register_burst_middleware("Shadowfiend", function(ctx)
   if not settings("use_shadowfiend") then return nil end
   if not is_in_combat() then return nil end
   if not ctx.has_valid_enemy_target then return nil end

   local threshold = settings("shadowfiend_pct") or 50
   if ctx.mana_pct > threshold then return nil end

   local target = izi.target()
   if Spells.Shadowfiend:is_usable() and Spells.Shadowfiend:is_in_range(target) then
      return Spells.Shadowfiend:cast(target, "[BURST] Shadowfiend")
   end
   return nil
end)

FluxCompat.register_burst_middleware("InnerFocus", function(ctx)
   if not is_in_combat() then return nil end
   if not ctx.has_valid_enemy_target then return nil end

   local me = izi.me()
   if me:buff_remains(Constants.BUFF_ID.INNER_FOCUS) > 0 then return nil end
   if not Spells.InnerFocus:is_usable() then return nil end

   local target = izi.target()
   local hf_ready = Spells.HolyFire:is_usable() and Spells.HolyFire:cooldown_up() and Spells.HolyFire:is_in_range(target)
   local mb_ready = Spells.MindBlast:is_usable() and Spells.MindBlast:cooldown_up() and Spells.MindBlast:is_in_range(target)

   if hf_ready or mb_ready or ctx.should_burst then
      return Spells.InnerFocus:cast(me, "[BURST] Inner Focus")
   end
   return nil
end)

-- =============================================================================
-- LOCAL HELPERS
-- =============================================================================
local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

local function get_playstyle()
   local elem = MenuElements["playstyle"]
   if elem then
      return elem:get() or "shadow"
   end
   return "shadow"
end

local function settings(key)
   local elem = MenuElements[key]
   if not elem then return nil end
   local t = elem:get_type()
   if t == "checkbox" then
      return elem:get_state()
   elseif t == "slider_int" or t == "slider_float" then
      return elem:get()
   elseif t == "combobox" then
      return elem:get()
   end
   return nil
end

local function is_in_combat()
   local me = izi.me()
   return me and me:time_in_combat() > 0
end

local function count_mobs_targeting_me()
   local bosses, elites, trash = 0, 0, 0
   local enemies = izi.enemies(40)
   local me = izi.me()
   for _, unit in ipairs(enemies) do
      local target = unit:get_target()
      if target and target:is_valid() and target == me then
         local classification = unit:get_classification()
         if classification == 3 then
            bosses = bosses + 1
         elseif classification == 1 or classification == 2 then
            elites = elites + 1
         else
            trash = trash + 1
         end
      end
   end
   return bosses, elites, trash
end

-- =============================================================================
-- HEALING SYSTEM
-- =============================================================================
local Healing = {}
local healing_targets = {}
local healing_targets_count = 0

local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

function Healing.scan_healing_targets()
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
         local hp = unit_obj:get_health() / unit_obj:get_health_max() * 100
         if hp < 100 then
            healing_targets_count = healing_targets_count + 1
            healing_targets[healing_targets_count] = {
               unit = unit_obj,
               hp = hp,
               is_player = (unit == "player"),
               has_weakened_soul = unit_obj:debuff_up(Constants.DEBUFF_ID.WEAKENED_SOUL),
               has_renew = unit_obj:buff_up(Spells.Renew:id()),
               effective_hp = hp,
            }
         end
      end
   end

   if healing_targets_count > 1 then
      table.sort(healing_targets, function(a, b) return a.hp < b.hp end)
   end
end

function Healing.get_lowest_hp_target()
   if healing_targets_count > 0 then
      return healing_targets[1]
   end
   return nil
end

function Healing.get_tank_target()
   for i = 1, healing_targets_count do
      local entry = healing_targets[i]
      if entry and entry.unit:is_tank() then
         return entry
      end
   end
   if healing_targets_count > 0 then
      return healing_targets[1]
   end
   return nil
end

function Healing.count_below_hp(threshold)
   local count = 0
   for i = 1, healing_targets_count do
      if healing_targets[i].hp < threshold then
         count = count + 1
      end
   end
   return count
end

-- =============================================================================
-- SPELL CALLBACKS SYSTEM
-- =============================================================================
local spellCallbacks = {}

local function onspell(spell_name, callback)
   if not spellCallbacks[spell_name] then
      spellCallbacks[spell_name] = {}
   end
   table.insert(spellCallbacks[spell_name], callback)
end

local function execute_callbacks(spell_name, icon, context)
   local callbacks = spellCallbacks[spell_name]
   if not callbacks then return nil end

   for _, callback in ipairs(callbacks) do
      local result = callback(icon, context)
      if result then
         return result
      end
   end
   return nil
end

-- =============================================================================
-- MIDDLEWARE: Emergency, Recovery, Utility
-- =============================================================================
onspell("DesperatePrayer", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("use_desperate_prayer") then return nil end

   local threshold = settings("desperate_prayer_hp") or 30
   local hp = context.hp
   if hp > threshold then return nil end

   if Spells.DesperatePrayer:is_usable() and Spells.DesperatePrayer:cooldown_up() then
      return Spells.DesperatePrayer:cast(izi.me(), "[MW] Desperate Prayer")
   end
   return nil
end)

onspell("Fade", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("use_fade") then return nil end

   local in_group = false
   if core.party and core.party.get_members then
      local members = core.party.get_members()
      in_group = members and #members > 0
   elseif izi.party then
      local members = izi.party()
      in_group = members and #members > 0
   end
   if settings("fade_group_only") and not in_group then return nil end

   local bosses, elites, trash = count_mobs_targeting_me()
   local min_bosses = settings("fade_min_bosses") or 1
   local min_elites = settings("fade_min_elites") or 1
   local min_trash = settings("fade_min_trash") or 3

   if bosses >= min_bosses or elites >= min_elites or trash >= min_trash then
      if Spells.Fade:is_usable() and Spells.Fade:cooldown_up() then
         return Spells.Fade:cast(izi.me(), "[MW] Fade - threat reduction")
      end
   end
   return nil
end)

onspell("Silence", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("shadow_use_silence") then return nil end
   if not context.has_valid_enemy_target then return nil end

   local target = izi.target()
   if target and target:is_casting() then
      local cast_remaining = target:get_cast_remaining_sec()
      if cast_remaining > 0 then
         if Spells.Silence:is_usable() and Spells.Silence:is_in_range(target) then
            return Spells.Silence:cast(target, "[MW] Silence")
         end
      end
   end
   return nil
end)

onspell("DispelMagic", function(icon, context)
   if not settings("auto_dispel_magic") then return nil end
   if context.is_mounted then return nil end

   local me = izi.me()

   if me:has_aura("Magic") then
      if Spells.DispelMagic:is_usable() and Spells.DispelMagic:is_in_range(me) then
         return Spells.DispelMagic:cast(me, "[MW] Dispel Magic (self)")
      end
   end

   local in_group = false
   local members = izi.party and izi.party() or {}
   if #members == 0 and izi.raid then
      members = izi.raid() or {}
   end
   in_group = #members > 0

   if in_group then
      for _, unit_obj in ipairs(members) do
         if unit_obj and unit_obj:is_valid() and not unit_obj:is_dead() then
            if unit_obj:has_aura("Magic") then
               if Spells.DispelMagic:is_usable() and Spells.DispelMagic:is_in_range(unit_obj) then
                  return Spells.DispelMagic:cast(unit_obj, "[MW] Dispel Magic (party)")
               end
            end
         end
      end
   end
   return nil
end)

onspell("Healthstone", function(icon, context)
   if not is_in_combat() then return nil end

   local threshold = settings("healthstone_hp") or 0
   if threshold <= 0 then return nil end
   if context.hp > threshold then return nil end

   if Spells.HealthstoneMaster:is_usable() then
      return Spells.HealthstoneMaster:use_self("[MW] Healthstone")
   end
   if Spells.HealthstoneMajor:is_usable() then
      return Spells.HealthstoneMajor:use_self("[MW] Healthstone Major")
   end
   return nil
end)

onspell("HealingPotion", function(icon, context)
   if not settings("use_healing_potion") then return nil end
   if not is_in_combat() then return nil end
   if context.combat_time < 2 then return nil end

   local threshold = settings("healing_potion_hp") or 25
   if context.hp > threshold then return nil end

   if Spells.SuperHealingPotion:is_usable() then
      return Spells.SuperHealingPotion:use_self("[MW] Super Healing Potion")
   end
   if Spells.MajorHealingPotion:is_usable() then
      return Spells.MajorHealingPotion:use_self("[MW] Major Healing Potion")
   end
   return nil
end)

onspell("Shadowfiend", function(icon, context)
   if not settings("use_shadowfiend") then return nil end
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end

   local threshold = settings("shadowfiend_pct") or 50
   if context.mana_pct > threshold then return nil end

   local target = izi.target()
   if Spells.Shadowfiend:is_usable() and Spells.Shadowfiend:is_in_range(target) then
      return Spells.Shadowfiend:cast(target, "[MW] Shadowfiend")
   end
   return nil
end)

onspell("ManaPotion", function(icon, context)
   if not settings("use_mana_potion") then return nil end
   if not is_in_combat() then return nil end
   if context.combat_time < 2 then return nil end

   local threshold = settings("mana_potion_pct") or 50
   if context.mana_pct > threshold then return nil end

   if Spells.SuperManaPotion:is_usable() then
      return Spells.SuperManaPotion:use_self("[MW] Super Mana Potion")
   end
   return nil
end)

onspell("DarkRune", function(icon, context)
   if not settings("use_dark_rune") then return nil end
   if not is_in_combat() then return nil end
   if context.combat_time < 2 then return nil end

   local threshold = settings("dark_rune_pct") or 50
   if context.mana_pct > threshold then return nil end

   local min_hp = settings("dark_rune_min_hp") or 50
   if context.hp < min_hp then return nil end

   if Spells.DarkRune:is_usable() then
      return Spells.DarkRune:use_self("[MW] Dark Rune")
   end
   if Spells.DemonicRune:is_usable() then
      return Spells.DemonicRune:use_self("[MW] Demonic Rune")
   end
   return nil
end)

onspell("InnerFire", function(icon, context)
   if is_in_combat() then return nil end
   if context.is_mounted then return nil end
   if not settings("use_inner_fire") then return nil end

   local me = izi.me()
   local has_if = false
   for _, buff_id in ipairs(Constants.INNER_FIRE_IDS) do
      if me:buff_remains(buff_id) > 0 then
         has_if = true
         break
      end
   end
   if has_if then return nil end

   if Spells.InnerFire:is_usable() and Spells.InnerFire:is_in_range(me) then
      return Spells.InnerFire:cast(me, "[MW] Inner Fire")
   end
   return nil
end)

onspell("PowerWordFortitude", function(icon, context)
   if is_in_combat() then return nil end
   if context.is_mounted then return nil end
   if not settings("use_fortitude") then return nil end

   local me = izi.me()
   local has_fort = false
   for _, buff_id in ipairs(Constants.FORTITUDE_IDS) do
      if me:buff_remains(buff_id) > 0 then
         has_fort = true
         break
      end
   end
   if has_fort then return nil end

   local in_group = false
   local members = izi.party and izi.party() or {}
   in_group = #members > 0

   if in_group and Spells.PrayerOfFortitude:is_usable() then
      return Spells.PrayerOfFortitude:cast(me, "[MW] Prayer of Fortitude")
   end
   if Spells.PowerWordFortitude:is_usable() and Spells.PowerWordFortitude:is_in_range(me) then
      return Spells.PowerWordFortitude:cast(me, "[MW] Power Word: Fortitude")
   end
   return nil
end)

onspell("DivineSpirit", function(icon, context)
   if is_in_combat() then return nil end
   if context.is_mounted then return nil end
   if not settings("use_divine_spirit") then return nil end

   local me = izi.me()
   local has_ds = false
   for _, buff_id in ipairs(Constants.DIVINE_SPIRIT_IDS) do
      if me:buff_remains(buff_id) > 0 then
         has_ds = true
         break
      end
   end
   if has_ds then return nil end

   local in_group = false
   local members = izi.party and izi.party() or {}
   in_group = #members > 0

   if in_group and Spells.PrayerOfSpirit:is_usable() then
      return Spells.PrayerOfSpirit:cast(me, "[MW] Prayer of Spirit")
   end
   if Spells.DivineSpirit:is_usable() and Spells.DivineSpirit:is_in_range(me) then
      return Spells.DivineSpirit:cast(me, "[MW] Divine Spirit")
   end
   return nil
end)

onspell("ShadowProtection", function(icon, context)
   if is_in_combat() then return nil end
   if context.is_mounted then return nil end
   if not settings("use_shadow_protection") then return nil end

   local me = izi.me()
   local has_sp = false
   for _, buff_id in ipairs(Constants.SHADOW_PROT_IDS) do
      if me:buff_remains(buff_id) > 0 then
         has_sp = true
         break
      end
   end
   if has_sp then return nil end

   local in_group = false
   local members = izi.party and izi.party() or {}
   in_group = #members > 0

   if in_group and Spells.PrayerOfShadowProtection:is_usable() then
      return Spells.PrayerOfShadowProtection:cast(me, "[MW] Prayer of Shadow Protection")
   end
   if Spells.ShadowProtection:is_usable() and Spells.ShadowProtection:is_in_range(me) then
      return Spells.ShadowProtection:cast(me, "[MW] Shadow Protection")
   end
   return nil
end)

onspell("FearWard", function(icon, context)
   if is_in_combat() then return nil end
   if context.is_mounted then return nil end
   if not settings("use_fear_ward") then return nil end

   local me = izi.me()
   if not Spells.FearWard:is_usable() then return nil end

   local self_has = me:buff_remains(Constants.BUFF_ID.FEAR_WARD) > 0
   if not self_has then
      return Spells.FearWard:cast(me, "[MW] Fear Ward (self)")
   end

   local focus = core.input.get_focus()
   if focus and focus:is_valid() and not focus:is_dead() then
      local focus_has = focus:buff_remains(Constants.BUFF_ID.FEAR_WARD) > 0
      if not focus_has and Spells.FearWard:is_in_range(focus) then
         return Spells.FearWard:cast(focus, "[MW] Fear Ward (focus)")
      end
   end
   return nil
end)

-- =============================================================================
-- SHADOW ROTATION
-- =============================================================================
local shadow_state = {
   vt_remaining = 0,
   swp_active = false,
   ve_remaining = 0,
   mb_ready = false,
   swd_ready = false,
   swd_safe = false,
   inner_focus_ready = false,
}

local function update_shadow_state(context)
   local target = izi.target()
   if not target then return shadow_state end

   shadow_state.vt_remaining = target:debuff_remains(Constants.DEBUFF_ID.VAMPIRIC_TOUCH)
   shadow_state.swp_active = target:debuff_remains(Constants.DEBUFF_ID.SHADOW_WORD_PAIN) > 0
   shadow_state.ve_remaining = target:debuff_remains(Constants.DEBUFF_ID.VAMPIRIC_EMBRACE)
   shadow_state.mb_ready = Spells.MindBlast:is_usable() and Spells.MindBlast:cooldown_up() and Spells.MindBlast:is_in_range(target)
   shadow_state.swd_ready = Spells.ShadowWordDeath:is_usable() and Spells.ShadowWordDeath:cooldown_up() and Spells.ShadowWordDeath:is_in_range(target)
   shadow_state.swd_safe = context.hp > (settings("shadow_swd_hp") or 40)
   shadow_state.inner_focus_ready = Spells.InnerFocus:is_usable() and Spells.InnerFocus:cooldown_up()

   return shadow_state
end

onspell("Shadowform", function(icon, context)
   if context.in_shadowform then return nil end
   if context.is_mounted then return nil end

   if Spells.Shadowform:is_usable() and Spells.Shadowform:cooldown_up() then
      return Spells.Shadowform:cast(izi.me(), "[SHADOW] Shadowform")
   end
   return nil
end)

onspell("VampiricTouch", function(icon, context)
   if is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if context.is_moving then return nil end
   if not context.in_shadowform then return nil end

   local target = izi.target()
   if not target then return nil end
   if not Spells.VampiricTouch:is_in_range(target) then return nil end

   if shadow_state.vt_remaining > 0 then return nil end

   if Spells.VampiricTouch:is_usable() and Spells.VampiricTouch:cooldown_up() then
      return Spells.VampiricTouch:cast(target, "[SHADOW] Pull: Vampiric Touch")
   end
   if shadow_state.mb_ready then
      return Spells.MindBlast:cast(target, "[SHADOW] Pull: Mind Blast")
   end
   return nil
end)

onspell("VampiricEmbrace", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if not settings("shadow_ve_maintain") then return nil end

   local target = izi.target()
   if not target then return nil end

   local ttd = target:time_to_die()
   if ttd > 0 and ttd < 6 then return nil end
   if shadow_state.ve_remaining >= 3 then return nil end
   if not Spells.VampiricEmbrace:is_in_range(target) then return nil end

   if Spells.VampiricEmbrace:is_usable() and Spells.VampiricEmbrace:cooldown_up() then
      return Spells.VampiricEmbrace:cast(target, "[SHADOW] Vampiric Embrace")
   end
   return nil
end)

onspell("ShadowWordPain", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end

   local target = izi.target()
   if not target then return nil end

   if shadow_state.swp_active then return nil end
   if target:time_to_die() < 6 then return nil end
   if shadow_state.mb_ready then return nil end

   if Spells.ShadowWordPain:is_usable() and Spells.ShadowWordPain:is_in_range(target) then
      return Spells.ShadowWordPain:cast(target, "[SHADOW] SW:P")
   end
   return nil
end)

onspell("Starshards", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if not settings("shadow_use_starshards") then return nil end

   local target = izi.target()
   if Spells.Starshards:is_usable() and Spells.Starshards:is_in_range(target) then
      return Spells.Starshards:cast(target, "[SHADOW] Starshards")
   end
   return nil
end)

onspell("DevouringPlague", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if not settings("shadow_use_devouring_plague") then return nil end

   local target = izi.target()
   if not target then return nil end

   local ttd = target:time_to_die()
   if ttd > 0 and ttd < 8 then return nil end

   local dp_remains = target:debuff_remains(Constants.DEBUFF_ID.DEVOURING_PLAGUE)
   if dp_remains > 3 then return nil end

   if Spells.DevouringPlague:is_usable() and Spells.DevouringPlague:is_in_range(target) then
      return Spells.DevouringPlague:cast(target, "[SHADOW] Devouring Plague")
   end
   return nil
end)

onspell("InnerFocus_shadow", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("shadow_use_inner_focus") then return nil end
   if not shadow_state.inner_focus_ready then return nil end

   local me = izi.me()
   if me:buff_remains(Constants.BUFF_ID.INNER_FOCUS) > 0 then return nil end

   if shadow_state.mb_ready then
      return Spells.InnerFocus:cast(me, "[SHADOW] Inner Focus")
   end
   return nil
end)

onspell("MindBlast", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if context.is_moving then return nil end

   local target = izi.target()
   if shadow_state.mb_ready and target then
      return Spells.MindBlast:cast(target, "[SHADOW] Mind Blast")
   end
   return nil
end)

onspell("ShadowWordDeath", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if not settings("shadow_use_swd") then return nil end
   if not shadow_state.swd_safe then return nil end

   local target = izi.target()
   if shadow_state.swd_ready and target then
      return Spells.ShadowWordDeath:cast(target, "[SHADOW] SW:D")
   end
   return nil
end)

onspell("Berserking", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("use_racial") then return nil end

   if Spells.Berserking:is_usable() and Spells.Berserking:cooldown_up() then
      return Spells.Berserking:cast(izi.me(), "[SHADOW] Berserking")
   end
   return nil
end)

onspell("MindFlay", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if context.is_moving then return nil end

   local threshold = settings("shadow_low_mana_pct") or 50
   if context.mana_pct <= threshold and shadow_state.swp_active and shadow_state.vt_remaining >= 1.8 then
      return nil
   end

   local target = izi.target()
   if target and Spells.MindFlay:is_usable() and Spells.MindFlay:is_in_range(target) then
      return Spells.MindFlay:cast(target, "[SHADOW] Mind Flay")
   end
   return nil
end)

-- =============================================================================
-- SMITE ROTATION
-- =============================================================================
local smite_state = {
   swp_active = false,
   swp_remaining = 0,
   surge_of_light = false,
   hf_ready = false,
   mb_ready = false,
   swd_ready = false,
   swd_safe = false,
   in_weave_window = false,
}

local SMITE_CAST_BASE = 2.0
local HF_CAST_BASE = 3.0

local function update_smite_state(context)
   local target = izi.target()
   if not target then return smite_state end

   local swp_dur = target:debuff_remains(Constants.DEBUFF_ID.SHADOW_WORD_PAIN)
   smite_state.swp_active = swp_dur > 0
   smite_state.swp_remaining = swp_dur

   local me = izi.me()
   smite_state.surge_of_light = me:buff_remains(Constants.BUFF_ID.SURGE_OF_LIGHT) > 0
   smite_state.hf_ready = Spells.HolyFire:is_usable() and Spells.HolyFire:cooldown_up() and Spells.HolyFire:is_in_range(target)
   smite_state.mb_ready = Spells.MindBlast:is_usable() and Spells.MindBlast:cooldown_up() and Spells.MindBlast:is_in_range(target)
   smite_state.swd_ready = Spells.ShadowWordDeath:is_usable() and Spells.ShadowWordDeath:cooldown_up() and Spells.ShadowWordDeath:is_in_range(target)
   smite_state.swd_safe = context.hp > (settings("smite_swd_hp") or 40)

   smite_state.in_weave_window = smite_state.swp_active and swp_dur > SMITE_CAST_BASE and swp_dur < HF_CAST_BASE

   return smite_state
end

onspell("ShadowWordPain_smite", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end

   local target = izi.target()
   if not target then return nil end

   if smite_state.swp_active then return nil end
   if target:time_to_die() < 6 then return nil end

   if Spells.ShadowWordPain:is_usable() and Spells.ShadowWordPain:is_in_range(target) then
      return Spells.ShadowWordPain:cast(target, "[SMITE] SW:P")
   end
   return nil
end)

onspell("HolyFire", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if context.is_moving then return nil end

   local target = izi.target()
   if smite_state.hf_ready and target then
      return Spells.HolyFire:cast(target, "[SMITE] Holy Fire")
   end
   return nil
end)

onspell("SmiteFiller", function(icon, context)
   if not is_in_combat() then return nil end
   if not context.has_valid_enemy_target then return nil end
   if context.is_moving then return nil end

   local target = izi.target()
   if target and Spells.Smite:is_usable() and Spells.Smite:is_in_range(target) then
      return Spells.Smite:cast(target, "[SMITE] Smite")
   end
   return nil
end)

-- =============================================================================
-- HOLY ROTATION
-- =============================================================================
local holy_state = {
   lowest = nil,
   lowest_hp = 100,
   tank = nil,
   group_damaged_count = 0,
   surge_of_light = false,
   clearcasting = false,
   pom_ready = false,
   coh_ready = false,
}

local function update_holy_state(context)
   Healing.scan_healing_targets()

   holy_state.lowest = Healing.get_lowest_hp_target()
   holy_state.lowest_hp = holy_state.lowest and holy_state.lowest.effective_hp or 100
   holy_state.tank = Healing.get_tank_target()

   local aoe_hp = settings("holy_aoe_hp") or 80
   holy_state.group_damaged_count = Healing.count_below_hp(aoe_hp)

   local me = izi.me()
   holy_state.surge_of_light = me:buff_remains(Constants.BUFF_ID.SURGE_OF_LIGHT) > 0
   holy_state.clearcasting = me:buff_remains(Constants.BUFF_ID.HOLY_CONCENTRATION) > 0
   holy_state.pom_ready = Spells.PrayerOfMending:is_usable() and Spells.PrayerOfMending:cooldown_up()
   holy_state.coh_ready = Spells.CircleOfHealing:is_usable() and Spells.CircleOfHealing:cooldown_up()

   return holy_state
end

onspell("FlashHeal_holy_emergency", function(icon, context)
   if not is_in_combat() then return nil end
   if context.is_moving then return nil end

   local threshold = settings("holy_emergency_hp") or 30
   if holy_state.lowest_hp >= threshold then return nil end
   if not holy_state.lowest then return nil end

   local target = holy_state.lowest.unit
   if target and Spells.FlashHeal:is_usable() and Spells.FlashHeal:is_in_range(target) then
      return Spells.FlashHeal:cast(target, "[HOLY] EMERGENCY FH")
   end
   return nil
end)

onspell("PrayerOfMending_holy", function(icon, context)
   if not holy_state.pom_ready then return nil end

   if not is_in_combat() then
      if not settings("holy_prepull_pom") then return nil end
   end

   local target = holy_state.tank or holy_state.lowest
   if target then
      return Spells.PrayerOfMending:cast(target.unit, "[HOLY] Prayer of Mending")
   end
   return nil
end)

onspell("CircleOfHealing", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("holy_use_coh") then return nil end
   if not holy_state.coh_ready then return nil end

   local min_count = settings("holy_aoe_count") or 3
   if holy_state.group_damaged_count < min_count then return nil end

   local target = holy_state.lowest or holy_state.tank
   if target and Spells.CircleOfHealing:is_usable() and Spells.CircleOfHealing:is_in_range(target.unit) then
      return Spells.CircleOfHealing:cast(target.unit, "[HOLY] Circle of Healing")
   end
   return nil
end)

onspell("Renew_holy_tank", function(icon, context)
   if not holy_state.tank then return nil end

   if not is_in_combat() then
      if not settings("holy_prepull_renew") then return nil end
   end

   local target = holy_state.tank.unit
   if target and target:is_dead() then return nil end

   local threshold = settings("holy_renew_hp") or 90
   if holy_state.tank.effective_hp > threshold then
      if is_in_combat() then return nil end
   end
   if holy_state.tank.has_renew then return nil end

   if Spells.Renew:is_usable() and Spells.Renew:is_in_range(target) then
      return Spells.Renew:cast(target, "[HOLY] Renew (tank)")
   end
   return nil
end)

onspell("FlashHeal_holy", function(icon, context)
   if not is_in_combat() then return nil end
   if context.is_moving then return nil end
   if not holy_state.lowest then return nil end

   local flash_hp = settings("holy_flash_heal_hp") or 50
   if holy_state.lowest_hp >= flash_hp then return nil end

   local target = holy_state.lowest.unit
   if target and Spells.FlashHeal:is_usable() and Spells.FlashHeal:is_in_range(target) then
      return Spells.FlashHeal:cast(target, "[HOLY] Flash Heal")
   end
   return nil
end)

-- =============================================================================
-- DISCIPLINE ROTATION
-- =============================================================================
local disc_state = {
   lowest = nil,
   lowest_hp = 100,
   tank = nil,
   group_damaged_count = 0,
   inner_focus_ready = false,
   pain_suppression_ready = false,
   power_infusion_ready = false,
   pom_ready = false,
}

local function update_disc_state(context)
   Healing.scan_healing_targets()

   disc_state.inner_focus_ready = Spells.InnerFocus:is_usable() and Spells.InnerFocus:cooldown_up()
   disc_state.pain_suppression_ready = Spells.PainSuppression:is_usable() and Spells.PainSuppression:cooldown_remains() < 0.5
   disc_state.power_infusion_ready = Spells.PowerInfusion:is_usable() and Spells.PowerInfusion:cooldown_remains() < 0.5
   disc_state.pom_ready = Spells.PrayerOfMending:is_usable() and Spells.PrayerOfMending:cooldown_up()

   disc_state.lowest = Healing.get_lowest_hp_target()
   disc_state.lowest_hp = disc_state.lowest and disc_state.lowest.effective_hp or 100
   disc_state.tank = Healing.get_tank_target()

   local shield_hp = settings("disc_shield_hp") or 90
   disc_state.group_damaged_count = Healing.count_below_hp(shield_hp)

   return disc_state
end

onspell("PainSuppression", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("disc_use_pain_suppression") then return nil end
   if not disc_state.pain_suppression_ready then return nil end
   if not disc_state.tank then return nil end

   local threshold = settings("disc_pain_suppression_hp") or 20
   if disc_state.tank.effective_hp >= threshold then return nil end

   if Spells.PainSuppression:is_usable() and Spells.PainSuppression:is_in_range(disc_state.tank.unit) then
      return Spells.PainSuppression:cast(disc_state.tank.unit, "[DISC] Pain Suppression")
   end
   return nil
end)

onspell("FlashHeal_disc_emergency", function(icon, context)
   if not is_in_combat() then return nil end
   if context.is_moving then return nil end

   local threshold = settings("disc_emergency_hp") or 25
   if disc_state.lowest_hp >= threshold then return nil end
   if not disc_state.lowest then return nil end

   local target = disc_state.lowest.unit
   if target and Spells.FlashHeal:is_usable() and Spells.FlashHeal:is_in_range(target) then
      return Spells.FlashHeal:cast(target, "[DISC] EMERGENCY FH")
   end
   return nil
end)

onspell("PowerWordShield_disc_tank", function(icon, context)
   if not disc_state.tank then return nil end

   if not is_in_combat() then
      if not settings("disc_prepull_shield") then return nil end
   end

   if disc_state.tank.has_weakened_soul then return nil end

   local threshold = settings("disc_shield_hp") or 90
   if disc_state.tank.effective_hp > threshold then
      if is_in_combat() then return nil end
   end

   if Spells.PowerWordShield:is_usable() then
      return Spells.PowerWordShield:cast(disc_state.tank.unit, "[DISC] PW:S (tank)")
   end
   return nil
end)

onspell("PrayerOfMending_disc", function(icon, context)
   if not is_in_combat() then return nil end
   if not disc_state.pom_ready then return nil end

   local target = disc_state.tank or disc_state.lowest
   if target then
      return Spells.PrayerOfMending:cast(target.unit, "[DISC] Prayer of Mending")
   end
   return nil
end)

onspell("PowerInfusion", function(icon, context)
   if not is_in_combat() then return nil end
   if not settings("disc_use_power_infusion") then return nil end
   if not disc_state.power_infusion_ready then return nil end

   local me = izi.me()
   if me:buff_remains(Constants.BUFF_ID.POWER_INFUSION) > 0 then return nil end

   return Spells.PowerInfusion:cast(me, "[DISC] Power Infusion")
end)

onspell("FlashHeal_disc", function(icon, context)
   if not is_in_combat() then return nil end
   if context.is_moving then return nil end
   if not disc_state.lowest then return nil end

   local flash_hp = settings("disc_flash_heal_hp") or 50
   if disc_state.lowest_hp >= flash_hp then return nil end

   local target = disc_state.lowest.unit
   if target and Spells.FlashHeal:is_usable() and Spells.FlashHeal:is_in_range(target) then
      return Spells.FlashHeal:cast(target, "[DISC] Flash Heal")
   end
   return nil
end)

-- =============================================================================
-- PRIEST-SPECIFIC CONTEXT EXTENSIONS
-- =============================================================================
local function extend_priest_context(ctx)
   ctx.in_shadowform = ctx.me:buff_remains(Constants.BUFF_ID.SHADOWFORM) > 0
   ctx.has_inner_focus = ctx.me:buff_remains(Constants.BUFF_ID.INNER_FOCUS) > 0
   ctx.has_power_infusion = ctx.me:buff_remains(Constants.BUFF_ID.POWER_INFUSION) > 0
   ctx.has_surge_of_light = ctx.me:buff_remains(Constants.BUFF_ID.SURGE_OF_LIGHT) > 0

   Healing.scan_healing_targets()
   ctx.lowest_heal_target = Healing.get_lowest_hp_target()
   ctx.tank_target = Healing.get_tank_target()

   return ctx
end

-- =============================================================================
-- MAIN ROTATION DISPATCHER
-- =============================================================================
core.register_on_update_callback(function()
   local playstyle = get_playstyle()
   local me = izi.me()
   if not me then return end

   local target = izi.target()
   local ctx = FluxCompat.build_context()

   ctx.me = me
   ctx.target = target
   ctx.in_combat = is_in_combat()
   ctx.hp = me:get_health_percentage()
   ctx.mana_pct = me:mana_pct()
   ctx.mana = me:mana_current()
   ctx.combat_time = me:time_in_combat()
   ctx.is_mounted = me:is_mounted()
   ctx.is_moving = me:is_moving()
   ctx.target_exists = target and target:is_valid() or false
   ctx.target_enemy = target and target:is_valid_enemy() or false
   ctx.has_valid_enemy_target = target and target:is_valid() and target:is_valid_enemy() and not target:is_dead()
   ctx.enemy_count = #izi.enemies(40)

   ctx = extend_priest_context(ctx)

   ctx.force_burst = FluxCompat.is_force_active("burst")
   ctx.force_defensive = FluxCompat.is_force_active("defensive")
   ctx.should_burst = FluxCompat.should_auto_burst(ctx)

   if playstyle == "shadow" then
      update_shadow_state(ctx)
   elseif playstyle == "smite" then
      update_smite_state(ctx)
   elseif playstyle == "holy" then
      update_holy_state(ctx)
   elseif playstyle == "discipline" then
      update_disc_state(ctx)
   end

   local result = FluxCompat.rotation_registry:execute_middleware(ctx)
   if result then return result end

   result = execute_callbacks("InnerFire", nil, ctx)
   if result then return result end

   result = execute_callbacks("PowerWordFortitude", nil, ctx)
   if result then return result end

   result = execute_callbacks("DivineSpirit", nil, ctx)
   if result then return result end

   result = execute_callbacks("ShadowProtection", nil, ctx)
   if result then return result end

   result = execute_callbacks("FearWard", nil, ctx)
   if result then return result end

   result = execute_callbacks("DesperatePrayer", nil, ctx)
   if result then return result end

   result = execute_callbacks("Fade", nil, ctx)
   if result then return result end

   result = execute_callbacks("Healthstone", nil, ctx)
   if result then return result end

   result = execute_callbacks("HealingPotion", nil, ctx)
   if result then return result end

   result = execute_callbacks("ManaPotion", nil, ctx)
   if result then return result end

   result = execute_callbacks("DarkRune", nil, ctx)
   if result then return result end

   result = execute_callbacks("Shadowfiend", nil, ctx)
   if result then return result end

   result = execute_callbacks("DispelMagic", nil, ctx)
   if result then return result end

   result = execute_callbacks("Silence", nil, ctx)
   if result then return result end

   if playstyle == "shadow" then
      result = execute_callbacks("Shadowform", nil, ctx)
      if result then return result end

      result = execute_callbacks("VampiricTouch", nil, ctx)
      if result then return result end

      result = execute_callbacks("VampiricEmbrace", nil, ctx)
      if result then return result end

      result = execute_callbacks("ShadowWordPain", nil, ctx)
      if result then return result end

      result = execute_callbacks("Starshards", nil, ctx)
      if result then return result end

      result = execute_callbacks("DevouringPlague", nil, ctx)
      if result then return result end

      result = execute_callbacks("InnerFocus_shadow", nil, ctx)
      if result then return result end

      result = execute_callbacks("MindBlast", nil, ctx)
      if result then return result end

      result = execute_callbacks("ShadowWordDeath", nil, ctx)
      if result then return result end

      result = execute_callbacks("Berserking", nil, ctx)
      if result then return result end

      result = execute_callbacks("MindFlay", nil, ctx)
      if result then return result end

   elseif playstyle == "smite" then
      result = execute_callbacks("ShadowWordPain_smite", nil, ctx)
      if result then return result end

      result = execute_callbacks("HolyFire", nil, ctx)
      if result then return result end

      result = execute_callbacks("SmiteFiller", nil, ctx)
      if result then return result end

   elseif playstyle == "holy" then
      result = execute_callbacks("FlashHeal_holy_emergency", nil, ctx)
      if result then return result end

      result = execute_callbacks("PrayerOfMending_holy", nil, ctx)
      if result then return result end

      result = execute_callbacks("CircleOfHealing", nil, ctx)
      if result then return result end

      result = execute_callbacks("Renew_holy_tank", nil, ctx)
      if result then return result end

      result = execute_callbacks("FlashHeal_holy", nil, ctx)
      if result then return result end

   elseif playstyle == "discipline" then
      result = execute_callbacks("PainSuppression", nil, ctx)
      if result then return result end

      result = execute_callbacks("FlashHeal_disc_emergency", nil, ctx)
      if result then return result end

      result = execute_callbacks("PowerWordShield_disc_tank", nil, ctx)
      if result then return result end

      result = execute_callbacks("PrayerOfMending_disc", nil, ctx)
      if result then return result end

      result = execute_callbacks("PowerInfusion", nil, ctx)
      if result then return result end

      result = execute_callbacks("FlashHeal_disc", nil, ctx)
      if result then return result end
   end

   return nil
end)

core.log("Priest main rotation loaded - v1.8.5 (FluxCompat integrated)")
