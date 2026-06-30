-- discipline_sylvanas.lua -- Priest Discipline healing for TBC Anniversary (2.5.5).
-- WHAT: support/hybrid healer (emergency PW:S, PoM, Greater Heal, Power Infusion).
-- WHEN: combat or pre-combat, with valid friendly targets.
-- WHY: TBC Disc = PI bot + emergency shields (NOT Wrath shield-healer).
-- SAFETY: PW:S gated to emergency HP threshold; all state fields nil-guarded.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}
local Healing = NS.PriestHealing or require("classes/priest/healing_sylvanas")
-- Preemptive heal module (Sonah-style predictive healing)
local PreemptiveHeal = require("shared/preemptive_heal_sylvanas")
local EMPTY_SETTINGS = {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }
local WEAKENED_SOUL_DEBUFF = { 6788 }

local DIVINE_SPIRIT_BUFF = { 25312, 27841, 14819, 14818, 14752 }
-- Mana conservation floors (Research.md Angle 4 Part B)
local CONSUME_MANA_FLOOR = 15 -- Below this: shield only, no heals
-- TBC Greater Heal: Rank 7=25213, Rank 6=25210, Rank 5=25314.
local GREATER_HEAL_MAX = 25213
local GREATER_HEAL_CONSERVE = 25210
local GREATER_HEAL_EFFICIENT = 25314

local function target_creature_type(unit)
 if not unit then return nil end
 if type(NS.unit_creature_type) == "function" then return NS.unit_creature_type(unit) end
 if unit.get_creature_type then
  local ok, value = pcall(function() return unit:get_creature_type() end)
  if ok then return value end
 end
 return nil
end

-- Pushback detection for Greater Heal
-- Tracks recent damage taken to gate long-cast heals during pushback
--- Checks if the player is taking damage or in pushback using available API.
--- Uses fallback detection when standard enemy scanner isn't exposed.
---@param context table The combat context.
---@return boolean has_pushback True if pushback is likely active.
local function _check_pushback(context)
 if not (context and context.me) then return false end
 local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(8) or {}
 for _, enemy in ipairs(enemies) do
  if enemy then
   -- Try: is this enemy attacking?
   local ok, is_casting = pcall(function() return enemy:is_casting() end)
   if ok and is_casting then return true end

   -- Fallback: can_attack check
   local ok2, can_attack = pcall(function()
    if context.me.can_attack then return enemy:can_attack(context.me) end
    return false
   end)
   if ok2 and can_attack then return true end
  end
 end
 return false
end
local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }
local FEAR_WARD_BUFF = { 6346 }
local POWER_WORD_FORTITUDE_BUFF = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
local PRAYER_OF_FORTITUDE_BUFF = { 25392, 21564, 21562 }
local RENEW_BUFF = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
local INNER_FOCUS_BUFF = { 14751 }
local PRAYER_OF_MENDING_BUFF = { 33076 } -- PoM buff on target (TBC rank 1)
-- Caster DPS class IDs for Power Infusion targeting (TBC)
local CASTER_CLASS_IDS = { [8] = true, [9] = true, [5] = true, [7] = true } -- Mage, Warlock, Priest, Shaman
-- parity feature constants
local FADE_BUFF = { 25429, 10942, 10941, 9592, 9579, 9578, 586 }
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

-- ============================================================================
-- Debuff check for self-dispel (Dispel Magic)
-- ============================================================================
local DISPEL_MAGIC_DEBUFF_IDS = {
 1010, 1014, 1022, -- Curses
 589, 594, 6074, -- Magic DoTs
 118, 12824, 12825, 12826, -- Magic CC
 27819,   -- Mana Detonation (KT)
}
local function has_magic_debuff(unit)
 if not unit then return false end
 for _, id in ipairs(DISPEL_MAGIC_DEBUFF_IDS) do
  if NS.has_debuff and NS.has_debuff(unit, id) then return true end
 end
 return false
end
-- ============================================================================
local disc_state = {
 lowest = nil,
 tank = nil,
 group_damaged_count = 0,
 has_inner_fire = false,
 has_fear_ward = false,
 has_power_word_fortitude = false,
 pws_ready = false,
 pom_ready = false,
 flash_heal_ready = false,
 greater_heal_ready = false,
 renew_ready = false,
 binding_heal_ready = false,
 circle_of_healing_ready = false,
 prayer_of_healing_ready = false,
 prayer_of_mending_ready = false,
 shadow_word_pain_ready = false,
 smite_ready = false,
 holy_fire_ready = false,
 psychic_scream_ready = false,
 dispel_magic_ready = false,
 shackle_undead_ready = false,
 mana_pct = 100,
 hp_pct = 100,
 in_combat = false,
 target_creature_type = nil,
 target_casting = false,
 enemy_count = 0,
 has_divine_spirit = false,
 has_prayer_of_fortitude = false,
 -- CD state
 pain_suppression_ready = false,
 power_infusion_ready = false,
 inner_focus_ready = false,
 has_inner_focus = false,
 pi_target = nil, -- Highest DPS caster for Power Infusion
 -- parity feature state
 healthstone_ready = false,
 healthstone_id = nil,
 has_fade_buff = false,
 fade_ready = false,
 inner_fire_ready = false,
 fear_ward_ready = false,
 power_word_fortitude_ready = false,
 friendly_target = nil,
 friendly_target_ready = false,
}

local function build_state(context)
 context.settings = context.settings or EMPTY_SETTINGS
 local me = context.me or NS.GetPlayer()
 if not me then return disc_state end
 disc_state.player_control_locked = context.player_control_locked == true
 -- Mounted bail: healer should not queue buffs/heals while mounted
 if me.is_mounted and me:is_mounted() then
  return disc_state
 end
 local target = context.target
 local entries, count = Healing.scan_healing_targets()

 -- Triage-ranked target selection: smarter than naive lowest-HP
 if NS.Triage and NS.Triage.rank and count and count > 0 then
  local ranked = NS.Triage.rank(entries, count, context.settings)
  disc_state.lowest = ranked[1] or NS.healing_get_lowest_hp(entries, count, 92)
 else
  disc_state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
 end
 disc_state.tank = NS.healing_get_tank(entries, count) or disc_state.lowest
 disc_state.group_damaged_count = NS.healing_count_below_hp(entries, count, context.settings.discipline_aoe_hp or 85)
 -- Subgroup count for Prayer of Healing: in raids, only count your own party
 disc_state.subgroup_damaged_count = (Healing.count_subgroup_below_hp and Healing.count_subgroup_below_hp(context.settings.discipline_aoe_hp or 85)) or disc_state.group_damaged_count
 -- Power Infusion target: find highest DPS caster in group
 disc_state.pi_target = nil
 if context.in_combat and entries and count and count > 0 then
  for i = 1, count do
   local entry = entries[i]
   if entry and entry.unit and NS.not_same_unit(entry.unit, me) then
    local ok, cls = pcall(function() return entry.unit:get_class() end)
    if ok and cls and CASTER_CLASS_IDS[cls] then
     disc_state.pi_target = entry.unit
     break
    end
   end
  end
 end
 -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
 local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(588, 3.0) or false
 if not skip_aura then
  disc_state.has_inner_fire = me and NS.buff_up(me, INNER_FIRE_BUFF) or false
  disc_state.has_fear_ward = me and NS.buff_up(me, FEAR_WARD_BUFF) or false
  disc_state.has_power_word_fortitude = me and NS.buff_up(me, POWER_WORD_FORTITUDE_BUFF) or false
  disc_state.has_divine_spirit = me and NS.buff_up(me, DIVINE_SPIRIT_BUFF) or false
  disc_state.has_prayer_of_fortitude = me and NS.buff_up(me, PRAYER_OF_FORTITUDE_BUFF) or false
  disc_state.has_inner_focus = me and NS.buff_up(me, INNER_FOCUS_BUFF) or false
 end
 disc_state.divine_spirit_ready = me and NS.spell_ready(SPELLS.DivineSpirit, me, { skip_range = true }) or false
 disc_state.prayer_of_fortitude_ready = me and NS.spell_ready(SPELLS.PrayerOfFortitude, me, { skip_range = true }) or false
 disc_state.enemy_count = (NS.GetEnemiesCount and NS.GetEnemiesCount(10)) or (context.enemies_count or 0)
 disc_state.inner_fire_ready = me and NS.spell_ready(SPELLS.InnerFire, me, { skip_range = true }) or false
 disc_state.fear_ward_ready = me and NS.spell_ready(SPELLS.FearWard, me, { skip_range = true }) or false
 disc_state.power_word_fortitude_ready = me and NS.spell_ready(SPELLS.PowerWordFortitude, me, { skip_range = true }) or false
 disc_state.symbol_of_hope_ready = me and NS.spell_ready(SPELLS.SymbolOfHope, me, { skip_range = true }) or false
 disc_state.pws_ready = me and NS.spell_ready(SPELLS.PowerWordShield, me, { skip_range = true }) or false
 disc_state.pom_ready = me and NS.spell_ready(SPELLS.PrayerofMending, me, { skip_range = true }) or false
 disc_state.flash_heal_ready = me and NS.spell_ready(SPELLS.FlashHeal, me, { skip_range = true }) or false
 disc_state.greater_heal_ready = me and NS.spell_ready(SPELLS.GreaterHeal, me, { skip_range = true }) or false
 disc_state.renew_ready = me and NS.spell_ready(SPELLS.Renew, me, { skip_range = true }) or false
 disc_state.binding_heal_ready = me and NS.spell_ready(SPELLS.BindingHeal, me, { skip_range = true }) or false
 disc_state.circle_of_healing_ready = me and NS.spell_ready(SPELLS.CircleofHealing, me, { skip_range = true }) or false
 disc_state.prayer_of_healing_ready = me and NS.spell_ready(SPELLS.PrayerOfHealing, me, { skip_range = true }) or false
 disc_state.prayer_of_mending_ready = me and NS.spell_ready(SPELLS.PrayerofMending, me, { skip_range = true }) or false
 disc_state.shadow_word_pain_ready = me and NS.spell_ready(SPELLS.ShadowWordPain, me, { expected_cooldown = 1.5 }) or false
 disc_state.smite_ready = me and NS.spell_ready(SPELLS.Smite, me, { expected_cooldown = 2.5 }) or false
 disc_state.holy_fire_ready = me and NS.spell_ready(SPELLS.HolyFire, me, { expected_cooldown = 10 }) or false
 disc_state.psychic_scream_ready = me and NS.spell_ready(SPELLS.PsychicScream, me, { expected_cooldown = 30 }) or false
 disc_state.dispel_magic_ready = me and NS.spell_ready(SPELLS.DispelMagic, me, { skip_range = true }) or false
 disc_state.shackle_undead_ready = me and NS.spell_ready(SPELLS.ShackleUndead, me, { expected_cooldown = 1.5 }) or false
 disc_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
 disc_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
 disc_state.in_combat = context.in_combat or false
 disc_state.target_creature_type = target_creature_type(target)
 disc_state.target_casting = target and target.is_casting and target:is_casting() or false

 -- Cooldown readiness
 disc_state.pain_suppression_ready = me and NS.spell_ready(SPELLS.PainSuppression, me, { skip_range = true }) or false
 disc_state.power_infusion_ready = me and NS.spell_ready(10060, me, { skip_range = true }) or false
 disc_state.inner_focus_ready = me and NS.spell_ready(SPELLS.InnerFocus or 14751, me, { skip_range = true }) or false

 -- parity: Healthstone scanning
 disc_state.healthstone_id = nil
 disc_state.healthstone_ready = false
 if NS.is_item_ready then
  for _, id in ipairs(HEALTHSTONE_IDS) do
   local ok, ready = pcall(NS.is_item_ready, id)
   if ok and ready then
    disc_state.healthstone_id = id
    disc_state.healthstone_ready = true
    break
   end
  end
 end

 -- parity: Fade state
 disc_state.has_fade_buff = me and NS.buff_up(me, FADE_BUFF) or false
 disc_state.fade_ready = me and NS.spell_ready(SPELLS.Fade, me, { skip_range = true }) or false
 local ft = NS.get_friendly_target_entry and NS.get_friendly_target_entry(context)
 disc_state.friendly_target = ft
 disc_state.friendly_target_ready = ft ~= nil

 -- parity: Smart Stop-Cast — cancel overhealing casts mid-flight
 if NS.StopCast and type(NS.StopCast.update) == "function" then
  NS.StopCast.update(me, context.settings)
 end

 return disc_state
end

local function discipline_idle_damage_enabled(context)
 local settings = context and context.settings or EMPTY_SETTINGS
 if settings.discipline_dps_when_idle == true then return true end
 return context and (context.is_solo == true or context.is_leveling == true)
end

local function group_stable_for_idle_damage(context, s)
 local settings = context and context.settings or EMPTY_SETTINGS
 if s.lowest and (s.lowest.effective_hp or 100) < (settings.discipline_idle_hp or 92) then return false end
 return true
end


-- ============================================================================
-- Match functions
-- ============================================================================
-- ============================================================================
-- PW:S on tank — always allowed, ignores tank-only setting.
-- This is the primary tank mitigation tool.
-- ============================================================================
local function pws_tank_matches(context, s)
 local settings = context.settings or EMPTY_SETTINGS
 if not s.tank then return false end
 if (s.tank.effective_hp or 100) > (settings.discipline_pws_hp or 35) then return false end
 if s.tank.has_weakened_soul then return false end
 if not s.pws_ready then return false end
 -- Respect existing absorb: don't overwrite a healthy PW:S shield.
 if Healing.pws_absorb_remaining then
  local absorb = Healing.pws_absorb_remaining(s.tank.unit)
  if absorb > 200 then return false end
 end
 return true
end

-- ============================================================================
-- PW:S on lowest non-tank — gated by disc_shield_tank_only setting.
-- When tank-only mode is active, this strategy never fires.
-- ============================================================================
local function pws_lowest_matches(context, s)
 local settings = context.settings or EMPTY_SETTINGS
 if settings.disc_shield_tank_only then return false end
 if not s.lowest then return false end
 -- Skip if the lowest target is already the tank (handled by pws_tank_matches)
 if s.tank and s.lowest == s.tank then return false end
 if (s.lowest.effective_hp or 100) > (settings.discipline_pws_hp or 35) then return false end
 if s.lowest.has_weakened_soul then return false end
 if not s.pws_ready then return false end
 if Healing.pws_absorb_remaining then
  local absorb = Healing.pws_absorb_remaining(s.lowest.unit)
  if absorb > 200 then return false end
 end
 return true
end

local function pom_tank_matches(context, s)
 local settings = context.settings or EMPTY_SETTINGS
 if not context.in_combat and settings.disc_prepull_pom == false then return false end
 local target = s.tank or s.lowest
 if not target then return false end
 if not s.pom_ready then return false end
 -- Skip if PoM already active on target (don't overwrite bounces in progress)
 if NS.has_buff and target.unit and NS.has_buff(target.unit, PRAYER_OF_MENDING_BUFF) then return false end
 return true
end

local function flash_heal_matches(context, s)
 if context.is_moving then return false end
 if not s.lowest then return false end
 if (s.lowest.effective_hp or 100) > (context.settings.discipline_flash_hp or 55) then return false end
 if (s.mana_pct or 100) < CONSUME_MANA_FLOOR then return false end
 if not s.flash_heal_ready then return false end
 -- Predictive overheal gate: don't cast FH if predicted deficit is smaller than the heal
 if NS.gate_overheal("FlashHeal", s.lowest.unit, 1.5, context.settings) then return false end
 return true
end

local function greater_heal_matches(context, s)
 if not context.in_combat then return false end
 if context.is_moving then return false end
 if not s.lowest then return false end
 -- Mana conserve: at <30%, skip GH in favor of Flash Heal (Research.md Angle 4 Part B)
 if (s.mana_pct or 100) < 30 then return false end
 -- Pushback gate: skip GH when taking damage (cast time gets pushed back, inefficient)
 -- Falls back to faster heals (Flash Heal) during pushback windows
 if _check_pushback(context) then return false end
 local hp = s.lowest.effective_hp or 100
 if hp > (context.settings.discipline_greater_heal_hp or 82) then return false end
 if hp <= (context.settings.discipline_flash_hp or 55) then return false end
 if not s.greater_heal_ready then return false end
 -- Predictive overheal gate: don't cast GH if predicted deficit is smaller than the heal
 if NS.gate_overheal("GreaterHeal", s.lowest.unit, 2.5, context.settings) then return false end
 return true
end

local function renew_tank_matches(context, s)
 if not s.tank then return false end
 if s.tank.has_renew then return false end
 if (s.tank.effective_hp or 100) > (context.settings.discipline_renew_hp or 90) then return false end
 if not s.renew_ready then return false end
 return true
end

local function renew_lowest_matches(context, s)
 if not s.lowest then return false end
 if s.lowest.has_renew then return false end
 if (s.lowest.effective_hp or 100) > (context.settings.discipline_renew_hp or 90) then return false end
 if not s.renew_ready then return false end
 return true
end

local function binding_heal_matches(context, s)
 if context.is_moving then return false end
 if not s.lowest then return false end
 if (s.lowest.effective_hp or 100) > 50 then return false end
 if (s.hp_pct or 100) > 70 then return false end
 if not s.binding_heal_ready then return false end
 -- Predictive overheal gate: don't cast BH if predicted deficit is smaller than the heal
 if NS.gate_overheal("BindingHeal", s.lowest.unit, 2.0, context.settings) then return false end
 return true
end

local function circle_of_healing_matches(context, s)
 if context.is_moving then return false end
 if s.group_damaged_count < 3 then return false end
 if not s.circle_of_healing_ready then return false end
 -- Predictive overheal gate: skip CoH if even the lowest target doesn't need it
 local coh_target = s.lowest and s.lowest.unit or NS.PLAYER_UNIT
 if NS.gate_overheal("CircleOfHealing", coh_target, 1.5, context.settings) then return false end
 return true
end

local function prayer_of_healing_matches(context, s)
 if context.is_moving then return false end
 -- Use subgroup count for PoH (only counts your party in raids)
 local poh_count = s.subgroup_damaged_count or s.group_damaged_count
 if poh_count < 4 then return false end
 if not s.prayer_of_healing_ready then return false end
 -- Predictive overheal gate: skip PoH if even the lowest target doesn't need a per-tick heal
 local poh_target = s.lowest and s.lowest.unit or NS.PLAYER_UNIT
 if NS.gate_overheal("PrayerOfHealing", poh_target, 3.0, context.settings) then return false end
 return true
end

local function _buff_on_cooldown(spell)
 if not NS.cooldown_remains then return false end
 return NS.cooldown_remains(spell, 10) > 0
end

local function _safe_buff_in_combat(context, s)
 local enemies = (s and s.enemy_count) or (context.enemies_count or 0)
 local has_target = context.has_valid_enemy_target or false
 if context.in_combat and enemies == 0 and not has_target then return false end
 return true
end

local function inner_fire_matches(context, s)
 if s.has_inner_fire then return false end
 if not s.inner_fire_ready then return false end
 if _buff_on_cooldown(SPELLS.InnerFire) then return false end
 return _safe_buff_in_combat(context, s)
end

local function fear_ward_matches(context, s)
 if s.has_fear_ward then return false end
 if not s.fear_ward_ready then return false end
 if _buff_on_cooldown(SPELLS.FearWard) then return false end
 return _safe_buff_in_combat(context, s)
end

local function pwf_matches(context, s)
 if s.has_power_word_fortitude then return false end
 if s.has_prayer_of_fortitude then return false end
 if not s.power_word_fortitude_ready then return false end
 if _buff_on_cooldown(SPELLS.PowerWordFortitude) then return false end
 return _safe_buff_in_combat(context, s)
end

local function symbol_of_hope_matches(context, s)
 if not s.symbol_of_hope_ready then return false end
 if not context.is_group then return false end
 if _buff_on_cooldown(SPELLS.SymbolOfHope) then return false end
 return _safe_buff_in_combat(context, s)
end

-- ============================================================================
-- Divine Spirit: maintain buff on self (and group when Prayer of Spirit talented)
-- ============================================================================


local function divine_spirit_matches(context, s)
 if s.has_divine_spirit then return false end
 if not s.divine_spirit_ready then return false end
 if _buff_on_cooldown(SPELLS.DivineSpirit) then return false end
 return _safe_buff_in_combat(context, s)
end

-- ============================================================================
-- Prayer of Fortitude: maintain raid buff
-- ============================================================================
local function pof_matches(context, s)
 if s.has_prayer_of_fortitude then return false end
 if s.has_power_word_fortitude then return false end
 if not s.prayer_of_fortitude_ready then return false end
 if _buff_on_cooldown(SPELLS.PrayerOfFortitude) then return false end
 return _safe_buff_in_combat(context, s)
end

local function idle_swp_matches(context, s)
 if not context.in_combat then return false end
 if not context.has_valid_enemy_target then return false end
 if not discipline_idle_damage_enabled(context) then return false end
 if (s.mana_pct or context.mana_pct or 100) < ((context.settings or EMPTY_SETTINGS).discipline_dps_mana_floor or 35) then return false end
 if not group_stable_for_idle_damage(context, s) then return false end
 if NS.debuff_remains(context.target, SHADOW_WORD_PAIN_DEBUFF) > 0 then return false end
 if not s.shadow_word_pain_ready then return false end
 return true
end

local function idle_smite_matches(context, s)
 if context.is_moving then return false end
 if not context.in_combat then return false end
 if not context.has_valid_enemy_target then return false end
 if not discipline_idle_damage_enabled(context) then return false end
 if (s.mana_pct or context.mana_pct or 100) < ((context.settings or EMPTY_SETTINGS).discipline_dps_mana_floor or 35) then return false end
 if not group_stable_for_idle_damage(context, s) then return false end
 if not s.smite_ready then return false end
 return true
end

local function holy_fire_matches(context, s)
 if context.is_moving then return false end
 if not context.in_combat then return false end
 if not context.has_valid_enemy_target then return false end
 if not discipline_idle_damage_enabled(context) then return false end
 if (s.mana_pct or context.mana_pct or 100) < ((context.settings or EMPTY_SETTINGS).discipline_dps_mana_floor or 45) then return false end
 if not group_stable_for_idle_damage(context, s) then return false end
 if not s.holy_fire_ready then return false end
 return true
end

local function psychic_scream_matches(context, s)
 if not context.in_combat then return false end
 local enemies = s.enemy_count or (context.enemies_count or 0)
 if enemies < 3 then return false end
 if not s.psychic_scream_ready then return false end
 return true
end

local function shackle_undead_matches(context, s)
 if not context.has_valid_enemy_target then return false end
 if s.target_creature_type ~= 6 then return false end
 if not s.shackle_undead_ready then return false end
 if context.target and NS.debuff_up and NS.debuff_up(context.target, {9484, 9485, 10955}) then return false end
 return true
end

local function dispel_magic_matches(context, s)
 if not s.dispel_magic_ready then return false end
 local me = context.me or NS.GetPlayer()
 if not has_magic_debuff(me) then return false end
 return true
end

-- ============================================================================
-- Pain Suppression: emergency external CD for tank lethal spikes
-- ============================================================================
local function pain_suppression_matches(context, s)
 if not context.in_combat then return false end
 if not s.tank then return false end
 local tank_hp = s.tank.effective_hp or 100
 if tank_hp > (context.settings.discipline_pain_suppression_hp or 30) then return false end
 if not s.pain_suppression_ready then return false end
 return true
end

-- ============================================================================
-- Power Infusion: grant +20% haste to highest DPS caster in group (or self)
-- ============================================================================
local function power_infusion_matches(context, s)
 if not context.in_combat then return false end
 if not s.power_infusion_ready then return false end
 local settings = context.settings or EMPTY_SETTINGS
 if settings.discipline_use_power_infusion == false then return false end
 -- Gate: only use when all DPS are healthy
 if s.lowest and (s.lowest.effective_hp or 100) < (settings.discipline_pi_safety_hp or 80) then return false end
 return true
end

-- ============================================================================
-- Inner Focus: free +25% crit on next spell — pair with Greater Heal or PoH
-- ============================================================================
local function inner_focus_matches(context, s)
 if not context.in_combat then return false end
 if s.has_inner_focus then return false end
 if not s.inner_focus_ready then return false end
 local settings = context.settings or EMPTY_SETTINGS
 if settings.discipline_use_inner_focus == false then return false end
 -- Use when tank needs a big heal or raid needs PoH
 local tank_hp = s.tank and (s.tank.effective_hp or 100) or 100
 if tank_hp > (settings.discipline_if_hp or 65) and s.group_damaged_count < 4 then return false end
 return true
end

-- ============================================================================
-- parity Feature: StopCast
-- Mid-cast cancellation: if a higher-priority target emerges during a long cast,
-- interrupt the current cast to switch to the higher-priority target.
-- ============================================================================
local function stop_cast_matches(context, s)
 if not context.in_combat then return false end
 if s.player_control_locked then return false end
 if not context.me then return false end
 local ok, is_casting = pcall(function() return context.me:is_casting() end)
 if not ok or not is_casting then return false end
 if not s.lowest then return false end
 if (s.lowest.effective_hp or 100) < 30 then return true end
 if s.tank and (s.tank.effective_hp or 100) < 50 then return true end
 return false
end

-- ============================================================================
-- parity Feature: PreHeal
-- Pre-cast Greater Heal when tank is about to take predictable damage.
-- ============================================================================
local function pre_heal_matches(context, s)
 if not context.in_combat then return false end
 if context.is_moving then return false end
 if not s.tank then return false end
 local tank_hp = s.tank.effective_hp or 100
 if tank_hp < 60 or tank_hp > 95 then return false end
 if not _check_pushback(context) then return false end
 if context.me then
  local ok, casting = pcall(function() return context.me:is_casting() end)
  if ok and casting then return false end
 end
 return s.greater_heal_ready
end

-- ============================================================================
-- parity Feature: Fade
-- Auto-use Fade when player has aggro.
-- ============================================================================
local function fade_matches(context, s)
 local auto_fade = (context.settings and context.settings.priest_auto_fade) ~= false
 if not auto_fade then return false end
 if not context.in_combat then return false end
 if s.has_fade_buff then return false end
 if not s.fade_ready then return false end
 local threshold = (context.settings and context.settings.priest_fade_threat_threshold) or 80
 if context.threat_pct and context.threat_pct >= threshold then return true end
 if context.threat_status and context.threat_status >= 2 then return true end
 local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(20) or {}
 for _, enemy in ipairs(enemies) do
  if enemy then
   local ok, is_valid = pcall(function() return enemy:is_valid() end)
   if ok and is_valid then
    local ok2, is_alive = pcall(function() return enemy:is_alive() end)
    if ok2 and is_alive then
     local ok3, etarget = pcall(function() return enemy:get_target() end)
     if ok3 and etarget and context.me and NS.same_unit then
      if NS.same_unit(etarget, context.me) then
       return true
      end
     end
    end
   end
  end
 end
 return false
end

-- ============================================================================
-- parity Feature: Healthstone
-- Auto-use healthstone below HP threshold, off-GCD.
-- ============================================================================
local function healthstone_matches(context, s)
 local auto_hs = (context.settings and context.settings.auto_healthstone) ~= false
 if not auto_hs then return false end
 if not s.healthstone_ready then return false end
 local hs_hp = (context.settings and context.settings.healthstone_hp_threshold) or 30
 if (s.hp_pct or 100) > hs_hp then return false end
 return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
local healing_strategies = {
 -- FriendlyTarget (Step 0): honor the player's manually-selected friendly target.
 -- TOP priority: works in and out of combat. Threshold-gated so full-health
 -- targets are ignored. State is populated in build_state().
 { name = "FriendlyTarget", matches = function(context, s)
  if not s.friendly_target_ready then return false end
  local ft = s.friendly_target
  if not ft then return false end
  if (ft.hp_pct or 100) >= (context.settings.disc_friendly_target_threshold or 90) then return false end
  if context.is_moving then return false end
  if context.player_control_locked then return false end
  if not s.greater_heal_ready then return false end
  if _check_pushback(context) then return false end
  if NS.gate_overheal and NS.gate_overheal("GreaterHeal", ft.unit, 2.5, context.settings) then return false end
  return true
 end, execute = function(context, s)
  local ft = s.friendly_target
  if not ft or not ft.unit then return false end
  local mana_pct = s.mana_pct or context.mana_pct or 100
  local spell_id
  if mana_pct > 30 then spell_id = GREATER_HEAL_MAX
  elseif mana_pct > 15 then spell_id = GREATER_HEAL_CONSERVE
  else spell_id = GREATER_HEAL_EFFICIENT end
  return NS.try_cast(spell_id, ft.unit, string.format("[DISCIPLINE] Greater Heal (friendly target) %.0f%%", ft.hp_pct or 0))
 end },
 { name = "PowerWordShieldTank", matches = pws_tank_matches, execute = function(context, s) return NS.try_cast(SPELLS.PowerWordShield, s.tank.unit, string.format("[DISCIPLINE] PW:S tank %.0f%%", s.tank.effective_hp or 0)) end },
 { name = "EmergencyPowerWordShield", matches = pws_lowest_matches, execute = function(context, s) return NS.try_cast(SPELLS.PowerWordShield, s.lowest.unit, string.format("[DISCIPLINE] PW:S %.0f%%", s.lowest.effective_hp or 0)) end },
 -- PowerWordShieldLowest removed: duplicate of EmergencyPowerWordShield (same matches + execute)
 { name = "PrayerOfMendingTank", matches = pom_tank_matches, execute = function(context, s) return NS.try_cast(SPELLS.PrayerofMending, (s.tank and s.tank.unit) or (s.lowest and s.lowest.unit), "[DISCIPLINE] Prayer of Mending") end },
 { name = "EmergencyFlashHeal", matches = flash_heal_matches, execute = function(context, s) return NS.try_cast(SPELLS.FlashHeal, s.lowest.unit, string.format("[DISCIPLINE] Flash Heal %.0f%%", s.lowest.effective_hp or 0)) end },
 { name = "PreemptiveGreaterHeal", matches = function(context, s)
  if not context.in_combat then return false end
  if context.is_moving then return false end
  local threshold = (context.settings and context.settings.discipline_preemptive_threshold) or PreemptiveHeal.DEFAULT_THRESHOLD
  if not PreemptiveHeal.match(context, s, threshold, 2.5) then return false end
  if not s.greater_heal_ready then return false end
  return true
 end, execute = function(context, s)
  local target_entry = s._preemptive_target
  if not target_entry or not target_entry.unit then return false end
  return PreemptiveHeal.execute(context, s, SPELLS.GreaterHeal, string.format("[DISCIPLINE] Preemptive GH %.0f%%", target_entry.effective_hp or 0), { cast_time = 2.5, heal_size = 3500 })
 end },
 { name = "GreaterHeal", matches = greater_heal_matches, execute = function(context, s)
  local mana_pct = s.mana_pct or context.mana_pct or 100
  local spell_id
  if mana_pct > 30 then
   spell_id = GREATER_HEAL_MAX
  elseif mana_pct > 15 then
   spell_id = GREATER_HEAL_CONSERVE
  else
   spell_id = GREATER_HEAL_EFFICIENT
  end
  return NS.try_cast(spell_id, s.lowest.unit, string.format("[DISCIPLINE] Greater Heal %.0f%% (rank %s)", s.lowest.effective_hp or 0, mana_pct > 30 and "7" or (mana_pct > 15 and "6" or "5")))
 end },
 { name = "BindingHeal", matches = binding_heal_matches, execute = function(context, s) return NS.try_cast(SPELLS.BindingHeal, s.lowest.unit, "[DISCIPLINE] Binding Heal") end },
 { name = "CircleOfHealing", matches = circle_of_healing_matches, execute = function() return NS.try_cast(SPELLS.CircleofHealing, NS.PLAYER_UNIT, "[DISCIPLINE] CircleOfHealing") end },
 { name = "PrayerOfHealing", matches = prayer_of_healing_matches, execute = function() return NS.try_cast(SPELLS.PrayerOfHealing, NS.PLAYER_UNIT, "[DISCIPLINE] PrayerOfHealing") end },
 { name = "RenewTank", matches = renew_tank_matches, execute = function(context, s) return NS.try_cast(SPELLS.Renew, s.tank.unit, string.format("[DISCIPLINE] Renew tank %.0f%%", s.tank.effective_hp or 0)) end },
 { name = "RenewLowest", matches = renew_lowest_matches, execute = function(context, s) return NS.try_cast(SPELLS.Renew, s.lowest.unit, string.format("[DISCIPLINE] Renew %.0f%%", s.lowest.effective_hp or 0)) end },
 { name = "InnerFire", matches = inner_fire_matches, execute = function() return NS.try_cast(SPELLS.InnerFire, NS.PLAYER_UNIT, "[DISCIPLINE] InnerFire") end },
 { name = "FearWard", matches = fear_ward_matches, execute = function() return NS.try_cast(SPELLS.FearWard, NS.PLAYER_UNIT, "[DISCIPLINE] FearWard") end },
 { name = "PowerWordFortitude", matches = pwf_matches, execute = function() return NS.try_cast(SPELLS.PowerWordFortitude, NS.PLAYER_UNIT, "[DISCIPLINE] PowerWordFortitude") end },
 { name = "SymbolOfHope", matches = symbol_of_hope_matches, execute = function() return NS.try_cast(SPELLS.SymbolOfHope, NS.PLAYER_UNIT, "[DISCIPLINE] SymbolOfHope") end },
 { name = "DivineSpirit", matches = divine_spirit_matches, execute = function() return NS.try_cast(SPELLS.DivineSpirit, NS.PLAYER_UNIT, "[DISCIPLINE] DivineSpirit") end },
 { name = "PrayerOfFortitude", matches = pof_matches, execute = function() return NS.try_cast(SPELLS.PrayerOfFortitude, NS.PLAYER_UNIT, "[DISCIPLINE] PrayerOfFortitude") end },
 { name = "PsychicScream", matches = psychic_scream_matches, execute = function(context) return NS.try_cast(SPELLS.PsychicScream, context.target, "[DISCIPLINE] PsychicScream", { expected_cooldown = 30 }) end },
 { name = "ShackleUndead", matches = shackle_undead_matches, execute = function(context) return NS.try_cast(SPELLS.ShackleUndead, context.target, "[DISCIPLINE] ShackleUndead", { expected_cooldown = 1.5 }) end },
 { name = "DispelMagic", matches = dispel_magic_matches, execute = function() return NS.try_cast(SPELLS.DispelMagic, NS.PLAYER_UNIT, "[DISCIPLINE] DispelMagic") end },
 -- Cooldown Features
 { name = "PainSuppression", matches = pain_suppression_matches, execute = function(_, s) return NS.try_cast(SPELLS.PainSuppression, s.tank.unit, string.format("[DISCIPLINE] Pain Suppression on tank %.0f%%", s.tank.effective_hp or 0)) end },
 { name = "PowerInfusion", matches = power_infusion_matches, execute = function(_, s)
  local pi_target = s.pi_target or NS.PLAYER_UNIT
  local label = s.pi_target and "[DISCIPLINE] Power Infusion on caster DPS" or "[DISCIPLINE] Power Infusion (self)"
  return NS.try_cast(10060, pi_target, label, { skip_range = true })
 end },
 { name = "InnerFocus", matches = inner_focus_matches, execute = function() return NS.try_cast(SPELLS.InnerFocus or 14751, NS.PLAYER_UNIT, "[DISCIPLINE] Inner Focus", { skip_range = true }) end },
 -- parity Features
 { name = "StopCast", matches = stop_cast_matches, execute = function() if NS.stop_casting then return NS.stop_casting() end; if NS.cancel_current_cast then return NS.cancel_current_cast() end; return false end },
 { name = "PreHeal", matches = pre_heal_matches, execute = function(context, s) return NS.try_cast(SPELLS.GreaterHeal, (s.tank and s.tank.unit) or (s.lowest and s.lowest.unit), string.format("[DISCIPLINE] PreHeal GH %.0f%%", (s.tank and s.tank.effective_hp) or (s.lowest and s.lowest.effective_hp) or 0)) end },
 { name = "Fade", matches = fade_matches, execute = function() return NS.try_cast(SPELLS.Fade, nil, "[DISCIPLINE] Fade (aggro drop)", { skip_range = true }) end },
 { name = "Healthstone", matches = healthstone_matches, execute = function(_, s) if s.healthstone_id and s.healthstone_ready and NS.use_item_by_id then return NS.use_item_by_id(s.healthstone_id) end; return false end },
}

local idle_dps_strategies = {
 { name = "IdleShadowWordPain", matches = idle_swp_matches, execute = function(context) return NS.try_cast(SPELLS.ShadowWordPain, context.target, "[DISCIPLINE] IdleShadowWordPain", { expected_cooldown = 1.5 }) end },
 { name = "IdleSmite", matches = idle_smite_matches, execute = function(context) return NS.try_cast(SPELLS.Smite, context.target, "[DISCIPLINE] IdleSmite", { expected_cooldown = 2.5 }) end },
 { name = "HolyFire", matches = holy_fire_matches, execute = function(context) return NS.try_cast(SPELLS.HolyFire, context.target, "[DISCIPLINE] HolyFire", { expected_cooldown = 10 }) end },
}

local strategies = {}
for i = 1, #healing_strategies do
 strategies[#strategies + 1] = healing_strategies[i]
end
for i = 1, #idle_dps_strategies do
 strategies[#strategies + 1] = idle_dps_strategies[i]
end

NS.rotation_registry:register("discipline", strategies, { get_state = build_state })
-- Priest discipline rotation registered
return strategies
