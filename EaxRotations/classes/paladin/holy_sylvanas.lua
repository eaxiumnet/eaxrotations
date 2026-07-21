-- holy_sylvanas.lua — Paladin Holy healing rotation for TBC Anniversary (2.5.5).
-- WHAT:  single-target healer — Flash of Light spam, downranked Holy Light (R4/R7/R9/R11),
--         Divine Favor + Holy Shock guaranteed-crit burst combo, Light's Grace chain,
--         Triage-scored target selection, auto-blessing/aura/cleanse maintenance.
-- WHEN:  combat or pre-combat, with valid friendly targets.
-- WHY:   TBC holy pally consensus = FoL sustain + ranked HL for triage, DF+HS burst,
--         JoW/JoL seal-twist for mana/health support.
-- SAFETY: Pattern 14 nil-guards via spec_kit.safe_state; no on_update() allocs; broken-API
--          guard (3s throttle) on aura/buff checks; DF/DI/DS/LoH readiness gated.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)

-- Safe spell-ID extraction: handles production spell_action objects (with :id())
-- and test stubs that return raw numbers or plain tables.
local function _spell_id(spell_obj)
    if type(spell_obj) == "number" then return spell_obj end
    if type(spell_obj) == "table" and type(spell_obj.id) == "function" then return spell_obj:id() end
    return nil
end

local _ns_gate_overheal = NS.gate_overheal
local function gate_overheal(spell_key, unit, cast_time, settings, spell_id)
    if NS.HealerDeficit and NS.HealerDeficit.gate_spell_overheal then
        return NS.HealerDeficit.gate_spell_overheal(spell_key, unit, cast_time, settings, spell_id)
    end
    return _ns_gate_overheal and _ns_gate_overheal(spell_key, unit, cast_time, settings, spell_id) or false
end

local ACTION = {
    AvengingWrath          = define("AvengingWrath",          {31884}, "AvengingWrath"),
    BlessingOfFreedom      = define("BlessingOfFreedom",      {1044}, "BlessingOfFreedom"),
    BlessingOfKings        = define("BlessingOfKings",        {20217}, "BlessingOfKings"),
    BlessingOfLight        = define("BlessingOfLight",        {27144, 19979, 19978, 19977}, "BlessingOfLight"),
    BlessingOfProtection   = define("BlessingOfProtection",   {10278, 5599, 1022}, "BlessingOfProtection"),
    BlessingOfSacrifice    = define("BlessingOfSacrifice",    {27148, 27147, 20729, 6940}, "BlessingOfSacrifice"),
    BlessingOfWisdom       = define("BlessingOfWisdom",       {27142, 25290, 19854, 19853, 19852, 19850, 19742}, "BlessingOfWisdom"),
    Cleanse                = define("Cleanse",                {4987}, "Cleanse"),
    ConcentrationAura      = define("ConcentrationAura",      {19746}, "ConcentrationAura"),
    Consecration           = define("Consecration",           {27173, 20924, 20923, 20922, 20116, 26573}, "Consecration"),
    DevotionAura           = define("DevotionAura",           {27149, 10293, 10292, 1032, 10291, 643, 10290, 465}, "DevotionAura"),
    DivineFavor            = define("DivineFavor",            {20216}, "DivineFavor"),
    DivineIllumination     = define("DivineIllumination",     {31842}, "DivineIllumination"),
    DivineShield           = define("DivineShield",           {1020, 642}, "DivineShield"),
    FireResistanceAura     = define("FireResistanceAura",     {27153, 19900, 19899, 19891}, "FireResistanceAura"),
    FlashOfLight           = define("FlashOfLight",           {27137, 19943, 19942, 19941, 19940, 19939, 19750}, "FlashOfLight"),
    FrostResistanceAura    = define("FrostResistanceAura",    {27152, 19898, 19897, 19888}, "FrostResistanceAura"),
    GreaterBlessingOfKings  = define("GreaterBlessingOfKings",  {25898}, "GreaterBlessingOfKings"),
    GreaterBlessingOfLight  = define("GreaterBlessingOfLight",  {27145, 25890}, "GreaterBlessingOfLight"),
    GreaterBlessingOfWisdom = define("GreaterBlessingOfWisdom", {27143, 25918, 25894}, "GreaterBlessingOfWisdom"),
    HammerOfJustice        = define("HammerOfJustice",        {10308, 5589, 5588, 853}, "HammerOfJustice"),
    HammerOfWrath          = define("HammerOfWrath",          {27180, 24239, 24274, 24275}, "HammerOfWrath"),
    HolyShock              = define("HolyShock",              {33072, 27174, 20930, 20929, 20473}, "HolyShock"),
    Judgement              = define("Judgement",              {20271}, "Judgement"),
    LayOnHands             = define("LayOnHands",             {27154, 10310, 2800, 633}, "LayOnHands"),
    Purify                 = define("Purify",                 {1152}, "Purify"),
    SealOfLight            = define("SealOfLight",            {27160, 20349, 20348, 20347, 20165}, "SealOfLight"),
    SealOfWisdom           = define("SealOfWisdom",           {27166, 20357, 20356, 20166}, "SealOfWisdom"),
    SealRighteousness      = define("SealRighteousness",      {27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154}, "SealRighteousness"),
    ShadowResistanceAura   = define("ShadowResistanceAura",   {27151, 19896, 19895, 19876}, "ShadowResistanceAura"),
}
local potion_helper = require("shared/potion_helper_sylvanas")
local FsrManager = require("shared/fsr_manager_sylvanas")
local Healing = NS.PaladinHealing or require("classes/paladin/healing_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = { potions = {} } } end
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}
local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }
local function first_ready_item(item_ids)
    if not NS.is_item_ready then return 0 end
    for i = 1, #item_ids do
        local item_id = item_ids[i]
        if NS.is_item_ready(item_id) then return item_id end
    end
    return 0
end
local Triage = NS.Triage
local _hp_ok, HealthPred = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hp_ok or type(HealthPred) ~= "table" then HealthPred = nil end

local format = string.format
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }
local EXPECTED_10S = { expected_cooldown = 10 }
local EXPECTED_300S = { expected_cooldown = 300, skip_range = true }
local EXPECTED_LOH = { expected_cooldown = 3600, skip_range = true }
local EXPECTED_CONSECRATION_SELF = { skip_range = true, expected_cooldown = 8 }

local _last_aura_cast = -100
local AURA_SWITCH_COOLDOWN = 3.0

local function spell_action(ids, label)
 if NS.spell_action then return NS.spell_action(ids, label) end
 return type(ids) == "table" and ids[1] or ids
end

-- Pattern 14: centralized spec_kit.setting_*() (nil-guarded against missing NS)

-- TBC Holy spells not exposed by the base Paladin class map.
local BlessingOfLight = ACTION.BlessingOfLight or spell_action({ 27144, 19979, 19978, 19977 }, "BlessingOfLight")
local GreaterBlessingOfLight = ACTION.GreaterBlessingOfLight or spell_action({ 27145, 25890 }, "GreaterBlessingOfLight")
local BlessingOfFreedom = ACTION.BlessingOfFreedom or spell_action({ 1044 }, "BlessingOfFreedom")
local BlessingOfProtection = ACTION.BlessingOfProtection or spell_action({ 10278, 5599, 1022 }, "BlessingOfProtection")
local BlessingOfSacrifice = ACTION.BlessingOfSacrifice or spell_action({ 27148, 27147, 20729, 6940 }, "BlessingOfSacrifice")
local FireResistanceAura = ACTION.FireResistanceAura or spell_action({ 27153, 19900, 19899, 19891 }, "FireResistanceAura")
local FrostResistanceAura = ACTION.FrostResistanceAura or spell_action({ 27152, 19898, 19897, 19888 }, "FrostResistanceAura")
local ShadowResistanceAura = ACTION.ShadowResistanceAura or spell_action({ 27151, 19896, 19895, 19876 }, "ShadowResistanceAura")
local SealOfLight = ACTION.SealOfLight or spell_action({ 27160, 20349, 20348, 20347, 20165 }, "SealOfLight")
local Purify = ACTION.Purify or spell_action({ 1152 }, "Purify") -- DB2: learned at level 8

local HolyLightRank11 = spell_action({ 27136 }, "HolyLightRank11")
local HolyLightRank9 = spell_action({ 25292 }, "HolyLightRank9")
local HolyLightRank7 = spell_action({ 10328 }, "HolyLightRank7")
local HolyLightRank4 = spell_action({ 1042 }, "HolyLightRank4")
local FlashOfLightRank6 = spell_action({ 19943 }, "FlashOfLightRank6")

local BUFF_DIVINE_FAVOR = { 20216 }
local BUFF_DIVINE_ILLUMINATION = { 31842 }
local BUFF_FORBEARANCE = { 25771 }
local BUFF_SEAL_WISDOM = { 27166, 20357, 20356, 20166 }
local BUFF_SEAL_LIGHT = { 27160, 20349, 20348, 20347, 20165 }
local BUFF_SEAL_RIGHTEOUSNESS = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
local BUFF_BLESSING_LIGHT = { 27145, 27144, 19979, 19978, 19977, 25890 }
local BUFF_BLESSING_WISDOM = { 27143, 27142, 25918, 25894, 25290, 19854, 19853, 19852, 19850, 19742 }
local BUFF_BLESSING_KINGS = { 25898, 20217 }
local BUFF_BLESSING_FREEDOM = { 1044 }
local BUFF_BLESSING_PROTECTION = { 10278, 5599, 1022 }
local BUFF_BLESSING_SACRIFICE = { 27148, 27147, 20729, 6940 }
local BUFF_DIVINE_SHIELD = { 642, 1020 }
local BUFF_LIGHTS_GRACE = { 31834 }
local BUFF_CONCENTRATION_AURA = { 19746 }
local BUFF_DEVOTION_AURA = { 27149, 10293, 10292, 1032, 643, 10291, 10290, 465 }
local BUFF_FIRE_RESIST_AURA = { 27153, 19900, 19899, 19891 }
local BUFF_FROST_RESIST_AURA = { 27152, 19898, 19897, 19888 }
local BUFF_SHADOW_RESIST_AURA = { 27151, 19896, 19895, 19876 }
local DEBUFF_JUDGEMENT_LIGHT = { 27163, 20343, 20342, 20341, 20185 }
local DEBUFF_JUDGEMENT_WISDOM = { 27164, 20355, 20354, 20186 }

local MAGIC_DAMAGE_DEBUFFS = { 29928, 36805, 33051, 28410, 27243, 25368 }
local FIRE_DAMAGE_DEBUFFS = { 22959, 10161, 16536, 29953, 31340 }
local FROST_DAMAGE_DEBUFFS = { 12494, 116, 7321, 33395, 27087 }
local SHADOW_DAMAGE_DEBUFFS = { 27216, 27243, 30910, 30414, 33676 }
local ROOT_SNARE_DEBUFFS = { 122, 339, 512, 865, 1022, 116, 1715, 2974, 3409, 3600, 12494, 27088, 33395 }
local PHYSICAL_FOCUS_DEBUFFS = { 26017, 12809, 25274, 25273, 30108 }
local DARK_RUNE_IDS = { 20520, 12662 }

local DEFAULT_SCAN_HP = 96
local EMERGENCY_HP = 25
local LOW_MANA_PCT = 35
local POTION_MANA_PCT = 22
local HEAVY_DAMAGE_COUNT = 3
local HEAVY_TANK_HP = 55
local BLESSING_REFRESH_SEC = 120
local BLESSING_MIN_MANA = 30
local BOSS_HP_FLOOR = 20
local TANK_HEAL_TARGET_HP = 92
local LIGHT_HEAL_DEFICIT = 900
local MEDIUM_HEAL_DEFICIT = 1900
local LARGE_HEAL_DEFICIT = 3200

-- ============================================================================
-- Schema (Pattern 14 nil-guard defaults via spec_kit.safe_state)
-- ============================================================================
local HOLY_SCHEMA = {
    -- Null-object fields (targets, spells, labels — default nil is correct)
    entries = nil,  count = 0,  lowest = nil,  tank = nil,
    cleanse_target = nil,  purify_target = nil,  mana_target = nil,
    freedom_target = nil,  protection_target = nil,  sacrifice_target = nil,
    pvp_stun_target = nil,  aura_spell = nil,  aura_label = nil,
    blessing_target = nil,  blessing_spell = nil,  blessing_label = nil,
    heal_target = nil,  heal_spell = nil,  heal_label = nil,  heal_priority = 0,
    holy_light_spell = nil,  holy_light_label = nil,
    friendly_target = nil,  friendly_target_ready = false,
    -- Resources (Pattern 14: assume full → skip defensives)
    mana_pct = 100,  hp_pct = 100,  target_hp_pct = 100,
    emergency_count = 0,  heavy_healing = false,  use_group_blessings = false,
    in_pvp = false,  moving = false,  is_group = false,  healthstone_ready = 0,
    -- Buff/debuff state
    has_divine_favor = false,  has_divine_illumination = false,  has_forbearance = false,
    has_seal_wisdom = false,  has_seal_righteousness = false,  has_seal_light = false,
    has_concentration_aura = false,  has_devotion_aura = false,
    has_fire_aura = false,  has_frost_aura = false,  has_shadow_aura = false,
    has_lights_grace = false,  lights_grace_remains = 0,
    target_has_jol = false,  target_has_jow = false,
    -- Swing timer for post-swing Judgement gating
    swing_remains = 99,
    -- FSR state (Five-Second Rule)
    fsr_inside = false,  fsr_seconds = 0,  fsr_regen_delta = 0,
}

local state = {
 entries = nil,
 count = 0,
 lowest = nil,
 tank = nil,
 cleanse_target = nil,
 purify_target = nil,
 mana_target = nil,
 freedom_target = nil,
 protection_target = nil,
 sacrifice_target = nil,
 pvp_stun_target = nil,
 aura_spell = nil,
 aura_label = nil,
 blessing_target = nil,
 blessing_spell = nil,
 blessing_label = nil,
 heal_target = nil,
 heal_spell = nil,
 heal_label = nil,
 heal_priority = 0,
 holy_light_spell = nil,
 holy_light_label = nil,
 emergency_count = 0,
 heavy_healing = false,
 use_group_blessings = false,
 in_pvp = false,
 mana_pct = 100,
 hp_pct = 100,
 target_hp_pct = 100,
 moving = false,
 has_divine_favor = false,
 has_divine_illumination = false,
 has_forbearance = false,
 has_seal_wisdom = false,
 has_seal_righteousness = false,
 has_concentration_aura = false,
 has_devotion_aura = false,
 has_fire_aura = false,
 has_frost_aura = false,
 has_shadow_aura = false,
 has_lights_grace = false,
 swing_remains = 99,
 lights_grace_remains = 0,
 target_has_jol = false,
 target_has_jow = false,
 friendly_target = nil,
 friendly_target_ready = false,
}

local function hp_of(entry, fallback)
 if entry and type(entry.effective_hp) == "number" then return entry.effective_hp end
 if entry and type(entry.hp) == "number" then return entry.hp end
 return fallback or 100
end

local function predicted_hp_of(entry, deadline)
    if not entry then return 100 end
    local unit = entry.unit
    if not unit then return entry.effective_hp or entry.hp or 100 end
    local has_health_api = type(unit.get_health_percentage) == "function" or
                          (type(unit.get_health) == "function" and type(unit.get_max_health) == "function")
    if has_health_api and HealthPred and HealthPred.predicted_hp_pct then
        local ok, pct = pcall(HealthPred.predicted_hp_pct, unit, deadline or 2.5)
        if ok and type(pct) == "number" then return pct end
    end
    return entry.effective_hp or entry.hp or 100
end

local function deficit_of(entry)
 if not entry then return 0 end
 if type(entry.deficit) == "number" then return entry.deficit end
 if type(entry.max_hp) == "number" and type(entry.current_hp) == "number" then
  return entry.max_hp - entry.current_hp
 end
 return 0
end

local function unit_has_buff(unit, ids)
 return unit and NS.buff_up and NS.buff_up(unit, ids) or false
end

local function unit_debuff_remains(unit, ids)
 if not unit or not NS.debuff_remains then return 0 end
 return NS.debuff_remains(unit, ids) or 0
end

local function has_debuff(unit, ids)
 return unit and unit_debuff_remains(unit, ids) > 0 or false
end

local function has_any_debuff(unit, lists)
 if not unit then return false end
 for i = 1, #lists do
  if has_debuff(unit, lists[i]) then return true end
 end
 return false
end

local function can_help(entry)
 if not entry or not entry.unit then return false end
 if entry.is_dead == true or entry.dead == true then return false end
 return true
end

local function can_cast_on(spell, entry)
 return can_help(entry) and NS.spell_ready(spell, entry.unit, EMPTY_OPTS)
end

local function cast_on(spell, entry, reason, opts)
 if not can_help(entry) then return false end
 return NS.try_cast(spell, entry.unit, reason, opts)
end

local function is_self(entry)
 if not entry or not entry.unit then return false end
 return NS.same_unit and NS.same_unit(entry.unit, NS.PLAYER_UNIT) or entry.unit == NS.PLAYER_UNIT
end

local function entry_needs_freedom(entry)
 if not can_help(entry) then return false end
 if unit_has_buff(entry.unit, BUFF_BLESSING_FREEDOM) then return false end
 if has_any_debuff(entry.unit, ROOT_SNARE_DEBUFFS) then return true end
 return entry.is_rooted == true or entry.is_snared == true
end

local function entry_needs_protection(entry, context)
 if not can_help(entry) then return false end
 if unit_has_buff(entry.unit, BUFF_BLESSING_PROTECTION) then return false end
 if hp_of(entry) > 38 then return false end
 if context and context.in_combat == false then return false end
 if has_any_debuff(entry.unit, PHYSICAL_FOCUS_DEBUFFS) then return true end
 return entry.threat_status and entry.threat_status >= 2 or false
end

local function entry_needs_cleanse(entry)
 if not can_help(entry) then return false end
 return entry.needs_cleanse or entry.has_poison or entry.has_disease or entry.has_magic
end

local function entry_is_mana_user(entry)
 if not can_help(entry) then return false end
 if entry.power_type == NS.POWER_MANA then return true end
 if type(entry.mana_pct) == "number" then return true end
 return entry.is_caster == true or entry.role == "healer" or entry.role == "caster"
end

local function should_use_greater_blessing(s)
 return (s.count or 0) >= 5 or s.use_group_blessings
end

local function blessing_remains(entry, ids)
 if not can_help(entry) then return 0 end
 if NS.buff_remains then return NS.buff_remains(entry.unit, ids) or 0 end
 return unit_has_buff(entry.unit, ids) and BLESSING_REFRESH_SEC or 0
end

local function blessing_missing_or_expiring(entry, ids, threshold)
 local remains = blessing_remains(entry, ids)
 return remains <= (threshold or BLESSING_REFRESH_SEC)
end

local function choose_holy_light_rank(context, entry)
 local mode = spec_kit.setting(context, "holy_light_rank", "max")
 local hp = predicted_hp_of(entry, 2.5)
 local deficit = deficit_of(entry)
 if mode == "rank4" then return HolyLightRank4, "Holy Light R4" end
 if mode == "rank7" then return HolyLightRank7, "Holy Light R7" end
 if mode == "rank9" then return HolyLightRank9, "Holy Light R9" end
 if hp <= EMERGENCY_HP or deficit >= LARGE_HEAL_DEFICIT then return HolyLightRank11, "Holy Light R11" end
 if hp <= 45 or deficit >= MEDIUM_HEAL_DEFICIT then return HolyLightRank9, "Holy Light R9" end
 if hp <= 65 or deficit >= LIGHT_HEAL_DEFICIT then return HolyLightRank7, "Holy Light R7" end
 return HolyLightRank4, "Holy Light R4"
end

local function choose_smart_heal(context, s, entry)
 if not can_help(entry) then return nil end
 local hp = predicted_hp_of(entry, 2.5)
 local deficit = deficit_of(entry)
 local flash_hp = spec_kit.setting_number(context, "holy_flash_light_hp", 85)
 local shock_hp = spec_kit.setting_number(context, "holy_shock_hp", 40)
 if (context and context.is_moving or s.moving) and hp <= flash_hp and NS.spell_ready(ACTION.HolyShock, entry.unit, EMPTY_OPTS) then
  s.heal_spell = ACTION.HolyShock
  s.heal_label = "Holy Shock moving"
  return ACTION.HolyShock
 end
 if hp <= shock_hp and NS.spell_ready(ACTION.HolyShock, entry.unit, EMPTY_OPTS) then
  s.heal_spell = ACTION.HolyShock
  s.heal_label = "Holy Shock emergency"
  return ACTION.HolyShock
 end
 -- Light's Grace reduces Holy Light cast time to 2.0s, making it more efficient
 local hl_base_threshold = spec_kit.setting_number(context, "holy_light_hp", 70)
 local hl_hp_threshold = s.has_lights_grace and (hl_base_threshold + 10) or hl_base_threshold
 if (hp <= hl_hp_threshold or deficit >= LIGHT_HEAL_DEFICIT) and (s.mana_pct or 100) >= LOW_MANA_PCT then
  -- Predictive overheal gate for Holy Light
  local hl_spell, _ = choose_holy_light_rank(context, entry)
  if gate_overheal("HolyLight", entry.unit, 2.5, context.settings, _spell_id(hl_spell)) then
   -- Fall through to Flash of Light instead
   if hp <= flash_hp and NS.spell_ready(ACTION.FlashOfLight, entry.unit, EMPTY_OPTS) then
    if (s.mana_pct or 100) < 15 and NS.spell_ready(FlashOfLightRank6, entry.unit, EMPTY_OPTS) then
     s.heal_spell = FlashOfLightRank6
     s.heal_label = "Flash of Light R6 conserve"
    else
     s.heal_spell = ACTION.FlashOfLight
     s.heal_label = "Flash of Light"
    end
    return s.heal_spell
   end
   return nil -- Skip both HL and FoL if HL would overheat
  end
  s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, entry)
  s.heal_spell = s.holy_light_spell
  s.heal_label = s.holy_light_label
  return s.heal_spell
 end
 if hp <= flash_hp then
  -- Flash of Light downranking: use rank 6 [25297] for mana conservation < 15%
  if (s.mana_pct or 100) < 15 and NS.spell_ready(FlashOfLightRank6, entry.unit, EMPTY_OPTS) then
   s.heal_spell = FlashOfLightRank6
   s.heal_label = "Flash of Light R6 conserve"
  else
   s.heal_spell = ACTION.FlashOfLight
   s.heal_label = "Flash of Light"
  end
  return s.heal_spell
 end
 return nil
end

local function choose_blessing(context, s)
 s.blessing_target = nil
 s.blessing_spell = nil
 s.blessing_label = nil
 if spec_kit.setting_bool(context, "holy_refresh_enabled", true) == false then return end
 if (s.mana_pct or 100) < spec_kit.setting_number(context, "holy_refresh_mana", BLESSING_MIN_MANA) then return end
 local threshold = spec_kit.setting_number(context, "holy_refresh_threshold", BLESSING_REFRESH_SEC)
 local use_greater = should_use_greater_blessing(s)

 if spec_kit.setting_bool(context, "holy_blessing_light", true) ~= false and can_help(s.tank) and blessing_missing_or_expiring(s.tank, BUFF_BLESSING_LIGHT, threshold) then
  s.blessing_target = s.tank
  s.blessing_spell = use_greater and GreaterBlessingOfLight or BlessingOfLight
  s.blessing_label = use_greater and "Greater Blessing of Light" or "Blessing of Light"
  return
 end
 if spec_kit.setting_bool(context, "holy_blessing_wisdom", true) ~= false then
  for i = 1, s.count do
   local entry = s.entries[i]
   if entry_is_mana_user(entry) and blessing_missing_or_expiring(entry, BUFF_BLESSING_WISDOM, threshold) then
    s.blessing_target = entry
    s.blessing_spell = use_greater and ACTION.GreaterBlessingOfWisdom or ACTION.BlessingOfWisdom
    s.blessing_label = use_greater and "Greater Blessing of Wisdom" or "Blessing of Wisdom"
    return
   end
  end
 end
 for i = 1, s.count do
  local entry = s.entries[i]
  if can_help(entry) and blessing_missing_or_expiring(entry, BUFF_BLESSING_KINGS, threshold) then
   s.blessing_target = entry
   s.blessing_spell = use_greater and ACTION.GreaterBlessingOfKings or ACTION.BlessingOfKings
   s.blessing_label = use_greater and "Greater Blessing of Kings" or "Blessing of Kings"
   return
  end
 end
end

local function choose_aura(context, s)
 s.aura_spell = nil
 s.aura_label = nil
 if has_any_debuff(NS.PLAYER_UNIT, SHADOW_DAMAGE_DEBUFFS) and not s.has_shadow_aura then
  s.aura_spell = ShadowResistanceAura
  s.aura_label = "Shadow Resistance Aura"
  return
 end
 if has_any_debuff(NS.PLAYER_UNIT, FIRE_DAMAGE_DEBUFFS) and not s.has_fire_aura then
  s.aura_spell = FireResistanceAura
  s.aura_label = "Fire Resistance Aura"
  return
 end
 if has_any_debuff(NS.PLAYER_UNIT, FROST_DAMAGE_DEBUFFS) and not s.has_frost_aura then
  s.aura_spell = FrostResistanceAura
  s.aura_label = "Frost Resistance Aura"
  return
 end
 if s.heavy_healing and not s.has_concentration_aura then
  s.aura_spell = ACTION.ConcentrationAura
  s.aura_label = "Concentration Aura"
  return
 end
 if not s.has_devotion_aura and not s.has_concentration_aura then
  s.aura_spell = ACTION.DevotionAura
  s.aura_label = "Devotion Aura"
 end
end

local function item_ready(item_id)
 if NS.is_item_ready then return NS.is_item_ready(item_id) end
 return true
end

local function try_use_item(item_ids, reason)
 if not NS.use_item_by_id then return false end
 for i = 1, #item_ids do
  local item_id = item_ids[i]
  if item_ready(item_id) and NS.use_item_by_id(item_id) then
   return true
  end
 end
 return false
end

local function build_state(context)
 -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
 local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(20216, 3.0) or false
 local entries, count = Healing.scan_healing_targets()
 state.entries = entries
 state.is_group = context.is_group or false
 state.count = count or 0
 state.lowest = NS.healing_get_lowest_hp(entries, count, DEFAULT_SCAN_HP)
 state.tank = NS.healing_get_tank(entries, count)
 state.cleanse_target = nil
 state.purify_target = nil
 state.mana_target = nil
 state.freedom_target = nil
 state.protection_target = nil
 state.sacrifice_target = nil
 state.pvp_stun_target = nil
 state.healthstone_ready = 0
 state.heal_target = nil
 state.heal_spell = nil
 state.heal_label = nil
 state.heal_priority = 0
 state.holy_light_spell = nil
 state.holy_light_label = nil
 state.emergency_count = 0
 state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)
 state.mana_pct = context and context.mana_pct or NS.mana_pct and NS.mana_pct(NS.GetPlayer()) or 100
 state.hp_pct = context and context.hp or NS.unit_health_pct and NS.unit_health_pct(NS.GetPlayer()) or 100
 state.target_hp_pct = context and context.target_hp or NS.unit_health_pct and NS.unit_health_pct(context and context.target) or 100
 state.moving = context and context.is_moving or false
 state.in_pvp = NS.is_pvp_zone and NS.is_pvp_zone() or context and context.is_pvp or false
 state.use_group_blessings = state.count >= 5
 if not skip_aura then
  state.has_divine_favor = NS.has_player_buff(BUFF_DIVINE_FAVOR)
  state.has_divine_illumination = NS.has_player_buff(BUFF_DIVINE_ILLUMINATION)
  state.has_forbearance = NS.has_player_debuff and NS.has_player_debuff(BUFF_FORBEARANCE) or NS.has_player_buff(BUFF_FORBEARANCE)
  state.has_seal_wisdom = NS.has_player_buff(BUFF_SEAL_WISDOM)
  state.has_seal_light = NS.has_player_buff(BUFF_SEAL_LIGHT)
  state.has_seal_righteousness = NS.has_player_buff(BUFF_SEAL_RIGHTEOUSNESS)
  state.has_concentration_aura = NS.has_player_buff(BUFF_CONCENTRATION_AURA)
  state.has_devotion_aura = NS.has_player_buff(BUFF_DEVOTION_AURA)
  state.has_fire_aura = NS.has_player_buff(BUFF_FIRE_RESIST_AURA)
  state.has_frost_aura = NS.has_player_buff(BUFF_FROST_RESIST_AURA)
  state.has_shadow_aura = NS.has_player_buff(BUFF_SHADOW_RESIST_AURA)
  state.has_lights_grace = NS.has_player_buff(BUFF_LIGHTS_GRACE)
  state.lights_grace_remains = NS.buff_remains and NS.buff_remains(NS.PLAYER_UNIT, BUFF_LIGHTS_GRACE) or 0
  state.target_has_jol = context and context.target and has_debuff(context.target, DEBUFF_JUDGEMENT_LIGHT) or false
  state.target_has_jow = context and context.target and has_debuff(context.target, DEBUFF_JUDGEMENT_WISDOM) or false
 end

 for i = 1, state.count do
  local entry = entries[i]
  if can_help(entry) then
   local hp = hp_of(entry)
   if hp < 40 then state.emergency_count = state.emergency_count + 1 end
   if not state.cleanse_target and entry_needs_cleanse(entry) then state.cleanse_target = entry end
   if not state.purify_target and is_self(entry) and (entry.has_poison or entry.has_disease) then state.purify_target = entry end
   if not state.freedom_target and entry_needs_freedom(entry) then state.freedom_target = entry end
   if not state.protection_target and entry_needs_protection(entry, context) then state.protection_target = entry end
   if not state.mana_target and entry_is_mana_user(entry) then state.mana_target = entry end
  end
 end

 if can_help(state.tank) and hp_of(state.tank) <= HEAVY_TANK_HP then state.sacrifice_target = state.tank end
 state.heavy_healing = state.emergency_count >= HEAVY_DAMAGE_COUNT or hp_of(state.tank) <= HEAVY_TANK_HP
 choose_blessing(context, state)
 choose_aura(context, state)
 -- Use Triage scoring when available for smarter target selection
 if Triage and Triage.rank and (state.count or 0) > 1 then
  local ranked = Triage.rank(entries, state.count, context.settings)
  if ranked and ranked[1] then
   state.heal_target = ranked[1]
  else
   state.heal_target = state.lowest or state.tank
  end
 else
  state.heal_target = state.lowest or state.tank
 end
 if can_help(state.heal_target) then choose_smart_heal(context, state, state.heal_target) end
 local ft = NS.get_friendly_target_entry and NS.get_friendly_target_entry(context)
 state.friendly_target = ft
 state.friendly_target_ready = ft ~= nil

  -- parity: Smart Stop-Cast — cancel overhealing casts mid-flight
  local me = context.me or NS.GetPlayer and NS.GetPlayer() or nil
  if me and NS.StopCast and type(NS.StopCast.update) == "function" then
   NS.StopCast.update(me, context.settings)
  end
  
  -- FSR (Five-Second Rule) tracking for mana efficiency
  if FsrManager then
   state.fsr_inside = FsrManager.is_inside_fsr()
   state.fsr_seconds = FsrManager.seconds_until_fsr()
   state.fsr_regen_delta = FsrManager.get_regen_delta()
  else
   state.fsr_inside = false
   state.fsr_seconds = 0
   state.fsr_regen_delta = 0
  end
  
  return spec_kit.safe_state(state, HOLY_SCHEMA)
end

local function has_valid_enemy(context)
 return context and context.has_valid_enemy_target and context.target
end

local function solo_damage_enabled(context, s)
 if not has_valid_enemy(context) then return false end
 local settings = context and context.settings or {}
 if not (context.is_solo == true or context.is_leveling == true or settings.holy_dps_when_idle == true) then return false end
 local safe_hp = settings.holy_idle_hp or 88
 if s and can_help(s.lowest) and hp_of(s.lowest) < safe_hp then return false end
 if s and (s.mana_pct or 100) < (settings.holy_dps_mana_floor or 35) then return false end	return true
end

local function cast_judgement(context, label)
	return NS.try_cast(ACTION.Judgement, context.target, label, EXPECTED_10S)
end

-- ============================================================================
-- Declarative strategy DSL definitions
-- Replaces 6 imperative strategies with compiled DSL equivalents while preserving
-- the existing priority order via name-based substitution.
-- ============================================================================
local DSL_DEFS = {
    {
        name = "DivineShieldSelfPreservation",
        conditions = {
            { type = "state", field = "hp_pct", op = "<=", value = 18 },
            { type = "state", field = "has_forbearance", op = "falsy" },
            { type = "spell_ready", spell = ACTION.DivineShield, target = "self", opts = EXPECTED_300S },
        },
        action = { type = "custom", fn = function()
            return NS.try_cast(ACTION.DivineShield, NS.PLAYER_UNIT, "[HOLY] Divine Shield self-preservation", EXPECTED_300S)
        end },
    },
    {
        name = "DivineIlluminationHeavyHealing",
        conditions = {
            { type = "state", field = "has_divine_illumination", op = "falsy" },
            { type = "OR", conditions = {
                { type = "state", field = "heavy_healing", op = "truthy" },
                { type = "state", field = "mana_pct", op = "<=", value = LOW_MANA_PCT },
            } },
            { type = "spell_ready", spell = ACTION.DivineIllumination, target = "self", opts = SELF_OPTS },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.DivineIllumination, NS.PLAYER_UNIT, format("[HOLY] Divine Illumination mana %.0f%%", state.mana_pct), SELF_OPTS)
        end },
    },
    {
        name = "ManaPotion",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = POTION_MANA_PCT },
        },
        action = { type = "custom", fn = function(context)
            return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS)
        end },
    },
    {
        name = "DarkRune",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = 18 },
            { type = "state", field = "hp_pct", op = ">", value = 45 },
        },
        action = { type = "custom", fn = function()
            return try_use_item(DARK_RUNE_IDS, "[HOLY] Dark Rune")
        end },
    },
    {
        name = "SealOfWisdomLowMana",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = LOW_MANA_PCT },
            { type = "state", field = "has_seal_wisdom", op = "falsy" },
            { type = "spell_ready", spell = ACTION.SealOfWisdom, target = "self", opts = SELF_OPTS },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.SealOfWisdom, NS.PLAYER_UNIT, format("[HOLY] Seal of Wisdom mana %.0f%%", state.mana_pct), SELF_OPTS)
        end },
    },
    {
        name = "Healthstone",
        conditions = {
            { type = "in_combat" },
            { type = "hp_threshold", op = "<=", value = 28 },
            { type = "state", field = "healthstone_ready", op = ">", value = 0 },
        },
        action = { type = "custom", fn = function(context, state)
            if state.healthstone_ready > 0 and NS.use_item_by_id then
                return NS.use_item_by_id(state.healthstone_ready, context.me) and true or false
            end
            return false
        end },
    },
}

local strategies = {
 -- FriendlyTarget (Step 0): honor the player's manually-selected friendly target.
 -- TOP priority: works in and out of combat. Threshold-gated so full-health
 -- targets are ignored. State is populated in build_state().
 {
  name = "FriendlyTarget",
  matches = function(context, s)
   if not s.friendly_target_ready then return false end
   local ft = s.friendly_target
   if not ft or not ft.unit then return false end
   if (ft.hp_pct or 100) >= spec_kit.setting_number(context, "holy_friendly_target_threshold", 90) then return false end
   if context.is_moving then return false end
   if context.player_control_locked then return false end
   s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, ft)
   if not (NS.spell_ready and NS.spell_ready(s.holy_light_spell, ft.unit, EMPTY_OPTS)) then return false end
   if gate_overheal("HolyLight", ft.unit, 2.5, context.settings, _spell_id(s.holy_light_spell)) then return false end
   return true
  end,
  execute = function(context, s)
   local ft = s.friendly_target
   if not ft or not ft.unit then return false end
   local spell = s.holy_light_spell or HolyLightRank7
   local label = s.holy_light_label or "Holy Light"
   return cast_on(spell, ft, format("[HOLY] %s (friendly target) %.0f%%", label, hp_of(ft)))
  end,
 },
 {
  name = "LayOnHandsLastResort",
  matches = function(context, s)
   if not can_help(s.lowest) then return false end
   if hp_of(s.lowest) > 12 then return false end
   return NS.spell_ready(ACTION.LayOnHands, s.lowest.unit, EXPECTED_LOH)
  end,
  execute = function(_, s)
   return cast_on(ACTION.LayOnHands, s.lowest, format("[HOLY] Lay on Hands last resort %.0f%%", hp_of(s.lowest)), EXPECTED_LOH)
  end,
 },
 { name = "DivineShieldSelfPreservation" },
 {
  name = "BlessingOfProtectionFocusedAlly",
  matches = function(_, s)
   return can_cast_on(BlessingOfProtection, s.protection_target)
  end,
  execute = function(_, s)
   return cast_on(BlessingOfProtection, s.protection_target, "[HOLY] Blessing of Protection focused ally")
  end,
 },
 {
  name = "CleanseTankPriority",
  matches = function(context, s)
   if spec_kit.setting_bool(context, "holy_auto_cleanse", true) == false then return false end
   if not entry_needs_cleanse(s.tank) then return false end
   return can_cast_on(ACTION.Cleanse, s.tank)
  end,
  execute = function(_, s)
   return cast_on(ACTION.Cleanse, s.tank, "[HOLY] Cleanse tank")
  end,
 },
 {
  name = "PurifySelf",
  matches = function(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Purify, 3.0) then return false end
   if spec_kit.setting_bool(context, "holy_auto_cleanse", true) == false then return false end
   return can_cast_on(Purify, s.purify_target)
  end,
  execute = function(_, s)
   return cast_on(Purify, s.purify_target, "[HOLY] Purify self")
  end,
 },
 {
  name = "CleanseParty",
  matches = function(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(ACTION.Cleanse, 3.0) then return false end
   if spec_kit.setting_bool(context, "holy_auto_cleanse", true) == false then return false end
   if context and (context.control_risk or context.is_group) and s.cleanse_target then return true end
   return can_cast_on(ACTION.Cleanse, s.cleanse_target)
  end,
  execute = function(_, s)
   return cast_on(ACTION.Cleanse, s.cleanse_target, "[HOLY] Cleanse ally")
  end,
 },
 {
  name = "BlessingOfFreedomSnare",
  matches = function(_, s)
   return can_cast_on(BlessingOfFreedom, s.freedom_target)
  end,
  execute = function(_, s)
   return cast_on(BlessingOfFreedom, s.freedom_target, "[HOLY] Blessing of Freedom snare/root")
  end,
 },
 {
  name = "DivineFavor",
  matches = function(context, s)
   local target = s.lowest or s.tank
   if not can_help(target) or s.has_divine_favor then return false end
   if hp_of(target) > spec_kit.setting_number(context, "holy_divine_favor_hp", 45) then return false end
   return NS.spell_ready(ACTION.DivineFavor, NS.PLAYER_UNIT, SELF_OPTS)
  end,
  execute = function()
   return NS.try_cast(ACTION.DivineFavor, NS.PLAYER_UNIT, "[HOLY] Divine Favor before critical Holy Light", SELF_OPTS)
  end,
 },
 {
  name = "DivineFavorHolyShockCombo",
  matches = function(context, s)
   if not s.has_divine_favor then return false end
   local target = s.lowest or s.tank
   if not can_help(target) then return false end
   if hp_of(target) > spec_kit.setting_number(context, "holy_shock_hp", 40) then return false end
   return NS.spell_ready(ACTION.HolyShock, target.unit, EMPTY_OPTS)
  end,
  execute = function(_, s)
   local target = s.lowest or s.tank
   return cast_on(ACTION.HolyShock, target, format("[HOLY] Holy Shock guaranteed crit %.0f%%", hp_of(target)))
  end,
 },
 { name = "DivineIlluminationHeavyHealing" },
 -- Avenging Wrath: +20% healing (and damage) for 20s on a 3-min CD. Valid TBC
 -- baseline (spell 31884; already used by Ret + Prot). Fire during a heavy-
 -- healing window for max HPS value; gate on a setting + TTD so it isn't wasted.
 {
  name = "AvengingWrathHeavyHealing",
  matches = function(context, s)
   if not spec_kit.setting_bool(context, "holy_avenging_wrath", true) then return false end
   if not (context and context.in_combat) then return false end
   -- Fire during heavy healing OR PvP burst-heal window
   if not s.heavy_healing then
    if NS.PvPBurstWindow and context.is_pvp then
     local ok, should = pcall(NS.PvPBurstWindow.should_burst, NS.PvPBurstWindow, context)
     if not (ok and should) then return false end
    else
     return false
    end
   end
   -- Don't waste a 3-min burst CD on a target about to die.
   if context.ttd_known and context.ttd and context.ttd > 0 and context.ttd < 15 then return false end
   return NS.spell_ready(ACTION.AvengingWrath, NS.PLAYER_UNIT, SELF_OPTS)
  end,
  execute = function()
   return NS.try_cast(ACTION.AvengingWrath, NS.PLAYER_UNIT, "[HOLY] Avenging Wrath +20% healing (heavy window)", SELF_OPTS)
  end,
 },
 {
  name = "HolyShock",
  matches = function(context, s)
   if not can_help(s.lowest) then return false end
   local moving = s.moving or context and context.is_moving
   if hp_of(s.lowest) > spec_kit.setting_number(context, "holy_shock_hp", 40) and not moving then return false end
   if not (NS.spell_ready and NS.spell_ready(ACTION.HolyShock, s.lowest.unit, EMPTY_OPTS)) then return false end
   -- Predictive overheal gate: Holy Shock is instant but still gated at higher HP
   if gate_overheal("HolyShock", s.lowest.unit, 1.5, context.settings, _spell_id(ACTION.HolyShock)) then return false end
   return true
  end,
  execute = function(_, s)
   return cast_on(ACTION.HolyShock, s.lowest, format("[HOLY] Holy Shock %.0f%%", hp_of(s.lowest)))
  end,
 },
 {
  name = "HolyLightEmergency",
  matches = function(context, s)
   if not can_help(s.lowest) or hp_of(s.lowest) > 55 then return false end
   s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, s.lowest)
   if not (NS.spell_ready and NS.spell_ready(s.holy_light_spell, s.lowest.unit, EMPTY_OPTS)) then return false end
   -- Predictive overheal gate
   if gate_overheal("HolyLight", s.lowest.unit, 2.5, context.settings, _spell_id(s.holy_light_spell)) then return false end
   return true
  end,
  execute = function(_, s)
   return cast_on(s.holy_light_spell, s.lowest, format("[HOLY] %s emergency %.0f%%", s.holy_light_label, hp_of(s.lowest)))
  end,
 },
 {
  name = "DivineFavorHolyLightFollowup",
  matches = function(context, s)
   if not s.has_divine_favor or not can_help(s.lowest) then return false end
   s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, s.lowest)
   if not (NS.spell_ready and NS.spell_ready(s.holy_light_spell, s.lowest.unit, EMPTY_OPTS)) then return false end
   -- Predictive overheal gate: even with Divine Favor, avoid wasteful overheal
   if gate_overheal("HolyLight", s.lowest.unit, 2.5, context.settings, _spell_id(s.holy_light_spell)) then return false end
   return true
  end,
  execute = function(_, s)
   return cast_on(s.holy_light_spell, s.lowest, format("[HOLY] %s guaranteed crit %.0f%%", s.holy_light_label, hp_of(s.lowest)))
  end,
 },
 -- Light's Grace Chain: when LG is active but about to expire (< 2.5s),
 -- cast another Holy Light to keep the haste rolling. Positioned after
 -- DivineFavorHolyLightFollowup so DF+HS still wins emergencies.
 {
  name = "LightGraceChain",
  matches = function(context, s)
   if not spec_kit.setting_bool(context, "holy_lg_chain_enabled", true) then return false end
   if not (context and context.in_combat) then return false end
   if (s.lights_grace_remains or 0) <= 0 then return false end
   if (s.lights_grace_remains or 0) >= 2.5 then return false end
   if not s.tank then return false end
   if not can_help(s.tank) then return false end
   if deficit_of(s.tank) <= 0 then return false end
   s.holy_light_spell, s.holy_light_label = choose_holy_light_rank(context, s.tank)
   return NS.spell_ready(s.holy_light_spell, s.tank.unit, EMPTY_OPTS)
  end,
  execute = function(_, s)
   return cast_on(s.holy_light_spell, s.tank, format("[HOLY] %s (Light's Grace chain %.1fs)", s.holy_light_label, s.lights_grace_remains or 0))
  end,
 },
 -- Light's Grace Build (proactive downrank): per TBC guides, cast lower-rank Holy Light when LG is not active or expiring to proc/refresh Light's Grace cheaply on the tank.
 -- This enables faster subsequent max-rank HL. Uses downrank ranks when LG down.
 {
  name = "LightGraceBuild",
  matches = function(context, s)
   if not spec_kit.setting_bool(context, "holy_lg_build_enabled", true) then return false end
   if not (context and context.in_combat) then return false end
   if not s.tank or not can_help(s.tank) then return false end
   if deficit_of(s.tank) <= 0 then return false end
   if (s.lights_grace_remains or 0) > 5 then return false end  -- only when weak or absent
   -- Prefer downrank for cheap proc when building
   local build_rank = (s.mana_pct or 100) < 40 and HolyLightRank4 or HolyLightRank7
   s.holy_light_spell = build_rank
   s.holy_light_label = (build_rank == HolyLightRank4) and "Holy Light R4 (LG build)" or "Holy Light R7 (LG build)"
   return NS.spell_ready(s.holy_light_spell, s.tank.unit, EMPTY_OPTS)
  end,
  execute = function(_, s)
   return cast_on(s.holy_light_spell, s.tank, format("[HOLY] %s (build Light's Grace)", s.holy_light_label))
  end,
 },
 -- FriendlyTarget (B6): honor the player's manually-selected friendly target.
 -- Placed after the emergency direct-heal tier (HolyShock / HolyLightEmergency /
 -- DivineFavorHolyLightFollowup) so life-critical saves win, but before the
 -- buff/utility/routine tier so a manual friendly target wins over auto-
 {
  name = "BlessingOfSacrificeTank",
  matches = function(_, s)
   if not can_help(s.sacrifice_target) then return false end
   if unit_has_buff(s.sacrifice_target.unit, BUFF_BLESSING_SACRIFICE) then return false end
   return NS.spell_ready(BlessingOfSacrifice, s.sacrifice_target.unit, EMPTY_OPTS)
  end,
  execute = function(_, s)
   return cast_on(BlessingOfSacrifice, s.sacrifice_target, "[HOLY] Blessing of Sacrifice on tank")
  end,
 },
 { name = "ManaPotion" },
 { name = "DarkRune" },
 {
  name = "AuraManagement",
  matches = function(_, s)
   local now = NS.time_now and NS.time_now() or 0
   if now - _last_aura_cast < AURA_SWITCH_COOLDOWN then return false end
   return s.aura_spell and NS.spell_ready(s.aura_spell, NS.PLAYER_UNIT, SELF_OPTS)
  end,
  execute = function(_, s)
   local ok = NS.try_cast(s.aura_spell, NS.PLAYER_UNIT, "[HOLY] " .. s.aura_label, SELF_OPTS)
   if ok then _last_aura_cast = NS.time_now and NS.time_now() or 0 end
   return ok
  end,
 },
 {
  name = "BlessingRefresh",
  matches = function(_, s)
   return s.blessing_spell and can_cast_on(s.blessing_spell, s.blessing_target)
  end,
  execute = function(_, s)
   return cast_on(s.blessing_spell, s.blessing_target, "[HOLY] " .. s.blessing_label)
  end,
 },
 {
  name = "BlessingOfLightTank",
  matches = function(context, s)
   if spec_kit.setting_bool(context, "holy_blessing_light", true) == false then return false end
   if not can_help(s.tank) or not blessing_missing_or_expiring(s.tank, BUFF_BLESSING_LIGHT, BLESSING_REFRESH_SEC) then return false end
   return NS.spell_ready(BlessingOfLight, s.tank.unit, EMPTY_OPTS)
  end,
  execute = function(_, s)
   return cast_on(BlessingOfLight, s.tank, "[HOLY] Blessing of Light tank")
  end,
 },
 {
  name = "TankPreHeal",
  matches = function(context, s)
   if not can_help(s.tank) or hp_of(s.tank) > TANK_HEAL_TARGET_HP then return false end
   s.heal_target = s.tank
   if not choose_smart_heal(context, s, s.tank) or not NS.spell_ready(s.heal_spell, s.tank.unit, EMPTY_OPTS) then return false end
   -- Predictive overheal gate for tank pre-heal
   if s.heal_spell then
    local spell_key = (s.heal_spell == ACTION.HolyLight) and "HolyLight" or "FlashOfLight"
    local cast_time = (s.heal_spell == ACTION.HolyLight) and 2.5 or 1.5
    if gate_overheal(spell_key, s.tank.unit, cast_time, context.settings, _spell_id(s.heal_spell)) then return false end
   end
   return true
  end,
  execute = function(_, s)
   return cast_on(s.heal_spell, s.tank, format("[HOLY] %s tank %.0f%%", s.heal_label, hp_of(s.tank)))
  end,
 },
  {
   name = "SmartHeal",
   matches = function(context, s)
    local target = s.heal_target or s.lowest or s.tank
    if not can_help(target) then return false end
    s.heal_target = target
    return choose_smart_heal(context, s, target) and NS.spell_ready(s.heal_spell, target.unit, EMPTY_OPTS)
   end,
   execute = function(_, s)
    return cast_on(s.heal_spell, s.heal_target, format("[HOLY] %s %.0f%%", s.heal_label, hp_of(s.heal_target)))
   end,
  },
  {
   name = "FSRPause",
   matches = function(context, s)
    if not FsrManager then return false end
    if not context.in_combat then return false end
    if (s.mana_pct or 100) > 35 then return false end
    if not s.fsr_inside then return false end
    if (s.fsr_regen_delta or 0) <= 0 then return false end
    local pause_ok, reason = FsrManager.should_pause_for_fsr(s, context)
    return pause_ok
   end,
    execute = function(_, s)
     return true
    end,
  },
  {
   name = "FlashOfLightEfficientTopoff",
  matches = function(context, s)
   if not can_help(s.lowest) then return false end
   if hp_of(s.lowest) > spec_kit.setting_number(context, "holy_flash_light_hp", 85) then return false end
   if not (NS.spell_ready and NS.spell_ready(ACTION.FlashOfLight, s.lowest.unit, EMPTY_OPTS)) then return false end
   -- Predictive overheal gate: skip FoL if predicted deficit is small
   if gate_overheal("FlashOfLight", s.lowest.unit, 1.5, context.settings, _spell_id(ACTION.FlashOfLight)) then return false end
   return true
  end,
  execute = function(_, s)
   return cast_on(ACTION.FlashOfLight, s.lowest, format("[HOLY] Flash of Light efficient %.0f%%", hp_of(s.lowest)))
  end,
 },
 { name = "SealOfWisdomLowMana" },
 {
  name = "JudgementOfWisdomBoss",
  matches = function(context, s)
   if not has_valid_enemy(context) or s.target_has_jow then return false end
   if (s.mana_pct or 100) > LOW_MANA_PCT and (s.target_hp_pct or 100) < BOSS_HP_FLOOR then return false end
   return s.has_seal_wisdom and NS.spell_ready(ACTION.Judgement, context.target, EXPECTED_10S)
  end,
  execute = function(context)
   return cast_judgement(context, "[HOLY] Judgement of Wisdom")
  end,
 },
 {
  name = "SealOfLightBoss",
  matches = function(context, s)
   if not has_valid_enemy(context) or s.target_has_jol or s.has_seal_light then return false end
   if (s.mana_pct or 100) < LOW_MANA_PCT then return false end
   if (s.target_hp_pct or 100) < BOSS_HP_FLOOR then return false end
   return NS.spell_ready(SealOfLight, NS.PLAYER_UNIT, SELF_OPTS)
  end,
  execute = function()
   return NS.try_cast(SealOfLight, NS.PLAYER_UNIT, "[HOLY] Seal of Light support", SELF_OPTS)
  end,
 },
 {
  name = "JudgementOfLightBoss",
  matches = function(context, s)
   if not has_valid_enemy(context) or s.target_has_jol or (s.mana_pct or 100) < LOW_MANA_PCT then return false end
   if (s.target_hp_pct or 100) < BOSS_HP_FLOOR then return false end
   return s.has_seal_light and NS.spell_ready(ACTION.Judgement, context.target, EXPECTED_10S)
  end,
  execute = function(context)
   return cast_judgement(context, "[HOLY] Judgement of Light support")
  end,
 },
 {
  name = "HammerOfJusticeDiver",
  matches = function(context, s)
   if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
   if not s.in_pvp and (s.hp_pct or 100) > 55 then return false end
   if not has_valid_enemy(context) then return false end
   if NS.unit_distance and NS.unit_distance(context.target, context.me) > 10 then return false end
   return NS.spell_ready(ACTION.HammerOfJustice, context.target, EMPTY_OPTS)
  end,
  execute = function(context)
   return NS.try_cast(ACTION.HammerOfJustice, context.target, "[HOLY] Hammer of Justice on diver")
  end,
 },
 {
  name = "SealOfRighteousnessSolo",
  matches = function(context, s)
   if not solo_damage_enabled(context, s) or s.has_seal_righteousness then return false end
   return NS.spell_ready(ACTION.SealRighteousness, NS.PLAYER_UNIT, SELF_OPTS)
  end,
  execute = function()
   return NS.try_cast(ACTION.SealRighteousness, NS.PLAYER_UNIT, "[HOLY] Solo Seal of Righteousness", SELF_OPTS)
  end,
 },
 {
  name = "HammerOfWrathSolo",
  matches = function(context, s)
   if not solo_damage_enabled(context, s) or (s.target_hp_pct or 100) > 20 then return false end
   return NS.spell_ready(ACTION.HammerOfWrath, context.target, EMPTY_OPTS)
  end,
  execute = function(context)
   return NS.try_cast(ACTION.HammerOfWrath, context.target, "[HOLY] Solo Hammer of Wrath")
  end,
 },
 {
  name = "HolyShockSoloDamage",
  matches = function(context, s)
   if not solo_damage_enabled(context, s) then return false end
   if (s.mana_pct or 100) < 45 and context.is_leveling then return false end
   return NS.spell_ready(ACTION.HolyShock, context.target, EMPTY_OPTS)
  end,
  execute = function(context)
   return NS.try_cast(ACTION.HolyShock, context.target, "[HOLY] Solo Holy Shock")
  end,
 },
 {
  name = "JudgementSoloRighteousness",
  matches = function(context, s)
   if not solo_damage_enabled(context, s) or not s.has_seal_righteousness then return false end
   return NS.spell_ready(ACTION.Judgement, context.target, EXPECTED_10S)
  end,
  execute = function(context)
   return cast_judgement(context, "[HOLY] Solo Judgement")
  end,
 },
 {
  name = "ConsecrationSoloAoE",
  matches = function(context, s)
   if context.is_moving then return false end
   if not solo_damage_enabled(context, s) then return false end
   if (context.enemy_count or context.enemies_count or 1) < 2 then return false end
   return NS.spell_ready(ACTION.Consecration, NS.PLAYER_UNIT, EXPECTED_CONSECRATION_SELF)
  end,
  execute = function()
   return NS.try_cast(ACTION.Consecration, NS.PLAYER_UNIT, "[HOLY] Solo Consecration", EXPECTED_CONSECRATION_SELF)
  end,
 },
 {
  name = "SealOfRighteousnessIdle",
  matches = function(context, s)
   if not has_valid_enemy(context) or s.has_seal_righteousness or (s.mana_pct or 100) < 45 then return false end
   return NS.spell_ready(ACTION.SealRighteousness, NS.PLAYER_UNIT, SELF_OPTS)
  end,
  execute = function()
   return NS.try_cast(ACTION.SealRighteousness, NS.PLAYER_UNIT, "[HOLY] Seal of Righteousness idle", SELF_OPTS)
  end,
 },
 { name = "Healthstone" },
}

-- Replace the 6 imperative strategies with compiled DSL equivalents by name.
-- Name-based substitution keeps the priority order intact even when strategies
-- are inserted or reordered in the future.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("holy", strategies, { get_state = build_state })
end
if NS.log then NS.log("Paladin holy rotation registered") end
-- Paladin holy rotation registered — Triage targeting, DF+HS burst combo
return { strategies = strategies, build_state = build_state }
