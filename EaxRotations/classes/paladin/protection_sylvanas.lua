-- protection_sylvanas.lua — Paladin Protection tank rotation for TBC Anniversary (2.5.5).

-- WHAT:  tank spec — Holy Shield (100% uptime) → Consecration → Judgement → Avenger's

--         Shield, with seal twisting (SoR/SoW/SoC), downranked Consecration, and layered

--         defensives (Divine Protection/Shield, Lay on Hands, Flash of Light/Holy Light).
--         6 strategies use the declarative strategy DSL (fifth DSL adopter, first tank).

-- WHEN:  in combat, with valid enemy target. OOC aura/blessing maintenance gated by combat.

-- WHY:   mirrors wowsims protection paladin APL + TBC 2.5.5 community consensus.

-- SAFETY: Holy Shield charge tracking via buff_points (Pattern 11); Pattern 14 nil-guards

--          on all numeric state reads; anti-loop 3s throttles on OOC self-buffs; JoW

--          emergency mode with 5% hysteresis; CC-proximity gating on Avenger's Shield.

local NS = _G.EaxRotations

if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local potion_helper = require("shared/potion_helper_sylvanas")

local SPELLS = NS.PaladinSpells or {}


local spec_kit = require("shared/spec_kit_sylvanas")

-- Fallback merge_state for test environments that mock an older spec_kit
-- without the shared helper. Production uses spec_kit.merge_state.
local merge_state = spec_kit.merge_state or function(build_state, context, state_override)
    local s = build_state(context)
    if not state_override or next(state_override) == nil then return s end
    local merged = {}
    for k, v in pairs(s) do merged[k] = v end
    for k, v in pairs(state_override) do merged[k] = v end
    local mt = getmetatable(s)
    if mt then
        local mt_copy = {}
        for k, v in pairs(mt) do mt_copy[k] = v end
        mt_copy.__newindex = nil
        setmetatable(merged, mt_copy)
    end
    return merged
end
local dsl = require("shared/strategy_dsl_sylvanas")
local _hp_ok, HealthPred = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hp_ok or type(HealthPred) ~= "table" then HealthPred = nil end

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {

    AvengerShield       = define("AvengerShield",       {32700, 32699, 31935}, "AvengerShield"),

    AvengingWrath        = define("AvengingWrath",        {31884}, "AvengingWrath"),

    BlessingOfKings       = define("BlessingOfKings",       {20217}, "BlessingOfKings"),

    BlessingOfProtection  = define("BlessingOfProtection",  {10278, 5599, 1022}, "BlessingOfProtection"),

    BlessingOfSanctuary   = define("BlessingOfSanctuary",   {27168, 20914, 20913, 20912, 20911}, "BlessingOfSanctuary"),

    Cleanse              = define("Cleanse",              {4987}, "Cleanse"),

    Consecration         = define("Consecration",         {27173, 20924, 20923, 20922, 20116, 26573}, "Consecration"),

    DevotionAura         = define("DevotionAura",         {27149, 10293, 10292, 1032, 643, 10291, 10290, 465}, "DevotionAura"),

    DivineProtection     = define("DivineProtection",     {5573, 498}, "DivineProtection"),

    DivineShield         = define("DivineShield",         {1020, 642}, "DivineShield"),

    Exorcism             = define("Exorcism",             {27138, 10314, 10313, 10312, 5615, 5614, 879}, "Exorcism"),

    FlashOfLight         = define("FlashOfLight",         {27137, 19943, 19942, 19941, 19940, 19939, 19750}, "FlashOfLight"),

    HammerOfJustice      = define("HammerOfJustice",      {10308, 5589, 5588, 853}, "HammerOfJustice"),

    HammerOfWrath        = define("HammerOfWrath",        {27180, 24239, 24274, 24275}, "HammerOfWrath"),

    HolyLight            = define("HolyLight",            {27136, 27135, 25292, 10329, 10328, 3472, 1042, 1026, 647, 639, 635}, "HolyLight"),

    HolyShield           = define("HolyShield",           {27179, 20928, 20927, 20925}, "HolyShield"),

    HolyShock            = define("HolyShock",            {33072, 27174, 20930, 20929, 20473}, "HolyShock"),

    HolyWrath            = define("HolyWrath",            {27139, 10318, 2812}, "HolyWrath"),

    Judgement            = define("Judgement",            {20271}, "Judgement"),

    LayOnHands           = define("LayOnHands",           {27154, 10310, 2800, 633}, "LayOnHands"),

    RighteousDefense     = define("RighteousDefense",     {31789}, "RighteousDefense"),

    RighteousFury        = define("RighteousFury",        {25780}, "RighteousFury"),

    SealCommand          = define("SealCommand",          {27170, 20920, 20919, 20918, 20915, 20375}, "SealCommand"),

    SealOfWisdom         = define("SealOfWisdom",         {27166, 20357, 20356, 20166}, "SealOfWisdom"),

    SealRighteousness    = define("SealRighteousness",    {27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154}, "SealRighteousness"),

    TurnEvil             = define("TurnEvil",             {10326}, "TurnEvil"),

}


-- ============================================================================

-- Buff & Debuff ID tables

-- ============================================================================

local RIGHTEOUS_FURY_BUFF = { 25780 }

local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }

local SEAL_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }

local SEAL_WISDOM_BUFF = { 27166, 20357, 20356, 20166 }

local JUDGEMENT_WISDOM_DEBUFF = { 27164, 20355, 20354, 20186 }

local HOLY_SHIELD_BUFF = { 27179, 20928, 20927, 20925 }

local CONSECRATION_DEBUFF = { 27173, 20924, 20923, 20922, 20116, 26573 }

local BLESSING_OF_SANCTUARY_BUFF = { 27168, 20914, 20913, 20912, 20911 }

local BLESSING_KINGS_BUFF = { 25898, 20217 }

local DEVOTION_AURA_BUFF = { 27149, 10293, 10292, 1032, 643, 10291, 10290, 465 }

local DIVINE_SHIELD_BUFF = { 642 }

local FORBEARANCE_DEBUFF = { 25771 }

local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local CC_DEBUFFS = { 118, 12824, 12825, 12826, 28271, 28272, 3355, 14308, 14309, 20066 }

local MELEE_RANGE = 8

local CONSECRATION_MIN_MANA = 35

local CONSECRATION_AOE_THRESHOLD = 3

local HEALTHSTONE_IDS = { 22105, 22104, 22103, 19013, 19012, 19011, 5512 }

local function first_ready_item(item_ids)

    if not NS.is_item_ready then return 0 end

    for i = 1, #item_ids do

        local item_id = item_ids[i]

        if NS.is_item_ready(item_id) then return item_id end

    end

    return 0

end


-- ============================================================================

-- Consecration downrank table: { min_mana_pct, spell_id }

-- Ordered from highest rank to lowest. Pick first entry where mana >= threshold.

-- ============================================================================

local CONSECRATION_DOWNRANK = {

 { 60, 27173 }, -- R6 (lvl 70)

 { 50, 20924 }, -- R5 (lvl 60)

 { 40, 20923 }, -- R4 (lvl 50)

 { 35, 20922 }, -- R3 (lvl 40)

}


local function get_consecration_id_for_mana(mana_pct)

 mana_pct = mana_pct or 100

 for i = 1, #CONSECRATION_DOWNRANK do

  if mana_pct >= CONSECRATION_DOWNRANK[i][1] then

   return CONSECRATION_DOWNRANK[i][2]

  end

 end

 return nil -- Below minimum floor, don't cast

end


-- ============================================================================

-- Settings helper

-- ============================================================================


-- ============================================================================

-- Time-based gates (buff detection via Sylvanas API returns nil)

-- ============================================================================


-- ============================================================================

-- Schema (Pattern 14 nil-guard defaults via spec_kit.safe_state)

-- ============================================================================

local PROT_SCHEMA = {

    -- Booleans: assume buffed/debuffed → don't reapply unnecessarily

    has_righteous_fury = true,  has_holy_shield = true,  has_seal = true,

    has_seal_command = false,   has_devotion_aura = true, has_divine_shield = false,

    has_forbearance = false,    has_blessing_sanctuary = true,

    has_seal_wisdom = false,    target_has_wisdom = false,

    judgement_wisdom_mode = false,  last_judgement_mode = "damage",

    needs_cleanse = false,      target_casting = false,     cc_nearby = false,

    is_group = false,

    -- Base-match guards (Pattern 14)

    in_combat = false,  has_valid_enemy_target = false,  in_melee = false,

    -- Spell readiness: assume ready (Pattern 14: nil → fallback reads true)

    consecration_ready = true,  holy_shield_ready = true,  avenger_ready = true,

    exorcism_ready = true,      judgement_ready = true,

    divine_shield_ready = true, divine_protection_ready = true,

    lay_on_hands_ready = true,  hammer_of_justice_ready = true,

    hammer_of_wrath_ready = true, avenging_wrath_ready = true,

    flash_of_light_ready = true, holy_light_ready = true,  holy_shock_ready = true,

    holy_wrath_ready = true,    cleanse_ready = true,      seal_of_wisdom_ready = true,

    righteous_defense_ready = true,

    -- Resources: assume full → skip defensives (Pattern 14)

    hp_pct = 100,  mana_pct = 100,  target_hp_pct = 100,

    -- Counts: assume zero → skip AoE/spender (Pattern 14)

    enemy_count = 0,  consecration_remains = 0,  holy_shield_charges = 0,

    healthstone_ready = 0,

    -- Misc

    now_ms = 0,  target_creature_type = nil,

    ally_threatened = nil,  low_hp_ally = nil,  utility_target = nil,

    swing_remains = 99,

}


-- ============================================================================

-- State builder

-- ============================================================================

local prot_state = {

 has_righteous_fury = false,

 has_holy_shield = false,

 has_seal = false,

 has_seal_command = false,

 has_devotion_aura = false,

 has_divine_shield = false,

 has_forbearance = false,

 consecration_remains = 0,

 has_blessing_sanctuary = false,

 now_ms = 0,

 holy_shield_ready = false,

 avenger_ready = false,

 exorcism_ready = false,

 judgement_ready = false,

 divine_shield_ready = false,

 divine_protection_ready = false,

 lay_on_hands_ready = false,

 hammer_of_justice_ready = false,

 hammer_of_wrath_ready = false,

 avenging_wrath_ready = false,

 flash_of_light_ready = false,

 holy_light_ready = false,

 holy_shock_ready = false,

 holy_wrath_ready = false,

 cleanse_ready = false,

 needs_cleanse = false,

 seal_of_wisdom_ready = false,

 righteous_defense_ready = false,

 turn_evil_ready = false,

 mana_pct = 100,

 hp_pct = 100,

 target_hp_pct = 100,

 enemy_count = 1,

 target_creature_type = nil,

 target_casting = false,

 ally_threatened = nil,

 low_hp_ally = nil,

 cc_nearby = false,

 has_seal_wisdom = false,

 target_has_wisdom = false,

 judgement_wisdom_mode = false,

 last_judgement_mode = nil,


    healthstone_ready = 0,}


local function self_needs_cleanse(unit)

 if not unit then return false end

 if type(NS.has_dispel_type_debuff) == "function" then

  return NS.has_dispel_type_debuff(unit, "Poison")

   or NS.has_dispel_type_debuff(unit, "Disease")

   or NS.has_dispel_type_debuff(unit, "Magic")

 end

 return false

end


local function creature_type(unit)

 if not unit or not unit.get_creature_type then return nil end

 local ok, value = pcall(unit.get_creature_type, unit)

 return ok and value or nil

end


local function build_state(context)

 local me = context.me or NS.GetPlayer()

 local target = context.target


 prot_state.now_ms = NS.game_time_ms and NS.game_time_ms() or 0



 prot_state.has_righteous_fury = me and NS.buff_up(me, RIGHTEOUS_FURY_BUFF) or false

 prot_state.has_holy_shield = me and NS.buff_up(me, HOLY_SHIELD_BUFF) or false

 -- Track remaining Holy Shield charges via buff.points for proactive refresh

 prot_state.holy_shield_charges = 0

 if prot_state.has_holy_shield and type(NS.buff_points) == "function" then

  local pts = NS.buff_points and NS.buff_points(me, HOLY_SHIELD_BUFF) or nil

  prot_state.holy_shield_charges = (pts and pts[1]) or 0

 end

 prot_state.has_seal = me and NS.buff_up(me, SEAL_RIGHTEOUSNESS_BUFF) or false

 prot_state.has_seal_command = me and NS.buff_up(me, SEAL_COMMAND_BUFF) or false

 prot_state.has_devotion_aura = me and NS.buff_up(me, DEVOTION_AURA_BUFF) or false

 prot_state.has_divine_shield = me and NS.buff_up(me, DIVINE_SHIELD_BUFF) or false

 prot_state.has_forbearance = me and NS.debuff_up(me, FORBEARANCE_DEBUFF) or false

 prot_state.consecration_remains = target and NS.debuff_remains(target, CONSECRATION_DEBUFF) or 0

 prot_state.has_blessing_sanctuary = me and NS.buff_up(me, BLESSING_OF_SANCTUARY_BUFF) or false

 prot_state.has_seal_wisdom = me and NS.buff_up(me, SEAL_WISDOM_BUFF) or false

 prot_state.target_has_wisdom = target and NS.debuff_up(target, JUDGEMENT_WISDOM_DEBUFF) or false


 prot_state.consecration_ready = me and NS.spell_ready(ACTION.Consecration, me, { skip_range = true, expected_cooldown = 8 }) or false

 prot_state.holy_shield_ready = me and NS.spell_ready(ACTION.HolyShield, me, { skip_range = true, expected_cooldown = 10 }) or false

 prot_state.avenger_ready = target and NS.spell_ready(ACTION.AvengerShield, target, { expected_cooldown = 30 }) or false

 prot_state.exorcism_ready = target and NS.spell_ready(ACTION.Exorcism, target, { expected_cooldown = 15 }) or false

 prot_state.judgement_ready = target and NS.spell_ready(ACTION.Judgement, target, { expected_cooldown = 10 }) or false

 prot_state.divine_shield_ready = me and NS.spell_ready(ACTION.DivineShield, me, { skip_range = true, expected_cooldown = 300 }) or false

 prot_state.divine_protection_ready = me and NS.spell_ready(ACTION.DivineProtection, me, { skip_range = true, expected_cooldown = 300 }) or false

 prot_state.lay_on_hands_ready = me and NS.spell_ready(ACTION.LayOnHands, me, { skip_range = true, expected_cooldown = 3600 }) or false

 prot_state.hammer_of_justice_ready = target and NS.spell_ready(ACTION.HammerOfJustice, target, { expected_cooldown = 60 }) or false

 prot_state.hammer_of_wrath_ready = target and NS.spell_ready(ACTION.HammerOfWrath, target, { expected_cooldown = 6 }) or false

 prot_state.avenging_wrath_ready = me and NS.spell_ready(ACTION.AvengingWrath, me, { skip_range = true, expected_cooldown = 180 }) or false

 prot_state.flash_of_light_ready = me and NS.spell_ready(ACTION.FlashOfLight, me, { skip_range = true, expected_cooldown = 1.5 }) or false

 prot_state.holy_light_ready = me and NS.spell_ready(ACTION.HolyLight, me, { skip_range = true, expected_cooldown = 2.5 }) or false

 prot_state.holy_shock_ready = target and NS.spell_ready(ACTION.HolyShock, target, { expected_cooldown = 15 }) or false

 prot_state.holy_wrath_ready = me and NS.spell_ready(ACTION.HolyWrath, me, { skip_range = true, expected_cooldown = 60 }) or false

 prot_state.cleanse_ready = me and NS.spell_ready(ACTION.Cleanse, me, { skip_range = true, expected_cooldown = 1.5 }) or false

 prot_state.needs_cleanse = self_needs_cleanse(me)

 prot_state.seal_of_wisdom_ready = me and NS.spell_ready(ACTION.SealOfWisdom, me, { skip_range = true, expected_cooldown = 1.5 }) or false

 prot_state.righteous_defense_ready = me and NS.spell_ready(ACTION.RighteousDefense, me, { skip_range = true, expected_cooldown = 15 }) or false

 prot_state.turn_evil_ready = me and NS.spell_ready(ACTION.TurnEvil, me, { expected_cooldown = 1.5 }) or false

 prot_state.is_group = context.is_group or false

 prot_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me)) or 100

 -- JoW emergency mode with hysteresis: enter below threshold, exit only above threshold + 5%

 local jow_enabled = spec_kit.setting_bool(context, "prot_jow_enabled", true)

 local jow_threshold = spec_kit.setting_number(context, "prot_jow_mana_threshold", 20)

 if jow_enabled then

  if (prot_state.mana_pct or 100) < jow_threshold then

   prot_state.judgement_wisdom_mode = true

   prot_state.last_judgement_mode = "wisdom"

  elseif (prot_state.mana_pct or 100) > (jow_threshold + 5) then

   prot_state.judgement_wisdom_mode = false

   prot_state.last_judgement_mode = "damage"

  else

   -- In hysteresis band: retain last mode (prevents flip-flopping)

   prot_state.judgement_wisdom_mode = (prot_state.last_judgement_mode == "wisdom")

  end

 else

  prot_state.judgement_wisdom_mode = false

  prot_state.last_judgement_mode = "damage"

 end

 prot_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100

 prot_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100

 prot_state.enemy_count = context.enemy_count or context.enemies_count or 1

 prot_state.target_creature_type = creature_type(target)

 prot_state.target_casting = target and target.is_casting and target:is_casting() or false


 -- Scan allies for threat and low HP (Righteous Defense / BoP peel)

 prot_state.ally_threatened = nil

 prot_state.low_hp_ally = nil

 local allies = context.party_members or context.group_members

 if type(allies) == "table" and #allies > 0 then

  for i = 1, #allies do

   local ally = allies[i]

   if ally and NS.not_same_unit(ally, me) then

    local ally_hp = ally.get_health_percentage and ally:get_health_percentage() or 100

    if ally_hp <= 35 and not prot_state.low_hp_ally then

     prot_state.low_hp_ally = ally

    end

    if not prot_state.ally_threatened and (ally.threat_status and ally.threat_status >= 2 or ally.has_aggro) then

     prot_state.ally_threatened = ally

    end

   end

  end

 end


 -- CC proximity check (skip Avenger's Shield near controlled mobs)

 prot_state.cc_nearby = false

 local enemies = context.enemies or context.enemy_list

 if enemies and target then

  for i = 1, #enemies do

   local enemy = enemies[i]

   if enemy and NS.not_same_unit(enemy, target) then

    for j = 1, #CC_DEBUFFS do

     if NS.debuff_up(enemy, {CC_DEBUFFS[j]}) then

      local dx = (enemy.x or 0) - (target.x or 0)

      local dy = (enemy.y or 0) - (target.y or 0)

      if dx*dx + dy*dy < 225 then -- 15 yards

       prot_state.cc_nearby = true

       break

      end

     end

    end

    if prot_state.cc_nearby then break end

   end

  end

 end


 -- parity: Snap Threat — immediate high-threat opener on combat start

 if NS.SnapThreat and type(NS.SnapThreat.check) == "function" then

  local snap_spell = NS.SnapThreat.check(me, target, context.settings, {

   spell_id = ACTION.Judgement,

   fallback_id = ACTION.AvengerShield,

  })

  if snap_spell and NS.try_cast then

   pcall(NS.try_cast, snap_spell, target, "[PROT] Snap Threat opener")

  end

 end


     prot_state.healthstone_ready = first_ready_item(HEALTHSTONE_IDS)

     -- Centralized guard fields used by base_matches guards
     prot_state.in_combat = context.in_combat == true
     local t = context.target
     if context.has_valid_enemy_target ~= nil then
         prot_state.has_valid_enemy_target = context.has_valid_enemy_target == true
     elseif t ~= nil then
         local is_valid = false
         if NS.is_valid_target then
             is_valid = NS.is_valid_target(t)
         elseif t.is_valid then
             is_valid = t:is_valid()
         end
         prot_state.has_valid_enemy_target = is_valid and not (t.is_dead and t:is_dead())
     else
         prot_state.has_valid_enemy_target = false
     end
     -- Compute in_melee from explicit context flag or fallback to distance check
     if context.in_melee ~= nil then
         prot_state.in_melee = context.in_melee == true
     elseif me and target and me.get_distance then
         local ok, dist = pcall(me.get_distance, me, target)
         prot_state.in_melee = ok and dist and dist <= MELEE_RANGE or false
     else
         prot_state.in_melee = false
     end

     local swing_remains = 99
     if NS.swing_time_until then
         local ok, sr = pcall(NS.swing_time_until, me)
         if ok and type(sr) == "number" then swing_remains = sr end
     end
     prot_state.swing_remains = swing_remains

    return spec_kit.safe_state(prot_state, PROT_SCHEMA)

end


local function find_ally(context, predicate)

 local members = context.party_members or context.group_members

 if type(members) == "table" and #members > 0 then

  for i = 1, #members do

   local member = members[i]

   if member and predicate(member) then return member end

  end

 end

 local me = context.me or NS.GetPlayer and NS.GetPlayer()

 if me and predicate(me) then return me end

 return nil

end


local function unit_has_buff(unit, ids)

 return NS.buff_up(unit, ids)

end

local function cooldowns_enabled(context)
 return spec_kit.setting_bool(context, "use_cooldowns", false)
end


-- ============================================================================
-- Centralized base_matches guards
-- ============================================================================
-- Merge a caller-provided state override into the state built from context.
-- This keeps tests ergonomic (callers can pass partial states) without
-- mutating the static cached state table (Pattern 4).

local function base_guard_passes(action_def, s)
    if not action_def then return true end
    if action_def.requires_in_combat and not s.in_combat then return false end
    if action_def.requires_not_in_combat and s.in_combat then return false end
    if action_def.requires_target and not s.has_valid_enemy_target then return false end
    if action_def.requires_melee and not s.in_melee then return false end
    return true
end

local function apply_base_matches(strategies, actions)
    for i = 1, #strategies do
        local action = actions[strategies[i].name]
        local original_matches = strategies[i].matches
        strategies[i].matches = function(context, state)
            local s = merge_state(build_state, context, state)
            if not base_guard_passes(action, s) then return false end
            return original_matches(context, s)
        end
    end
end


-- ============================================================================

-- Match functions


-- ============================================================================

-- Anti-loop throttle: when matches() accepts, we immediately claim a 3s slot.

-- This defeats the same anti-flicker / buff-cache-stale pattern that ate DevotionAura

-- and SelfBuffKings. Buff lasts ~30 min so re-cast is invisible at runtime.

local _last_righteous_fury_match_time = 0

local function righteous_fury_matches(context, state)

 if state.has_righteous_fury then return false end

 local now = NS.time_now and NS.time_now() or 0

 if (now - _last_righteous_fury_match_time) < 3.0 then return false end

 _last_righteous_fury_match_time = now

 return true

end


local function holy_shield_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_holy_shield", true) then return false end

 if not state.holy_shield_ready then return false end

 -- Holy Shield has 8 charges (10 with Imp Holy Shield talent).

 -- buff.points[1] is the remaining charge count.

 -- Refresh when charges drop below configurable threshold.

 if state.has_holy_shield then

  local charges = state.holy_shield_charges or 0

  local refresh_at = spec_kit.setting_number(context, "prot_holy_shield_charges", 2)

  if charges > refresh_at then

   local me = context.me or NS.GetPlayer()

   local incoming = (HealthPred and HealthPred.incoming_damage) and HealthPred.incoming_damage(me, 2.0) or 0

   local incoming_threshold = spec_kit.setting_number(context, "prot_holy_shield_incoming", 1200)

   if incoming < incoming_threshold then return false end

  end

 end

 return true

end


local function consecration_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_consecration", true) then return false end

 if not state.consecration_ready then return false end

 -- Don't break CC with Consecration

 if state.cc_nearby then return false end

 -- Mana conservation: skip Consecration below configurable floor

 local min_mana = spec_kit.setting_number(context, "prot_consecration_min_mana", CONSECRATION_MIN_MANA)

 if (state.mana_pct or 100) < min_mana then return false end

 -- AoE threshold: only use single-target if Consecration is already ticking

 local min_targets = spec_kit.setting_number(context, "prot_consecration_targets", CONSECRATION_AOE_THRESHOLD)

 if not (NS.aoe_self_meets and NS.aoe_self_meets(min_targets, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)) and (state.consecration_remains or 0) > 2 then return false end

 return true

end


local function avenger_shield_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_avenger_shield", false) then return false end

 if not state.avenger_ready then return false end

 -- Skip Avenger's Shield near CC'd mobs (bouncing breaks CC)

 if state.cc_nearby then return false end

 -- Opener mode: pre-pull when target exists but not yet in combat

 local is_opener = spec_kit.setting_bool(context, "prot_avenger_opener", false)

  and context.has_valid_enemy_target

  and not context.in_combat

 -- Normal mode: in combat with valid target

 local in_combat = context.has_valid_enemy_target and context.in_combat

 if not (is_opener or in_combat) then return false end

 return true

end


local function judgement_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_judgement", false) then return false end

 if not state.judgement_ready then return false end

 -- Mana Emergency (JoW): only judge Seal of Wisdom. Do NOT also require SoR
 -- (has_seal) — SoR and SoW cannot both be active; requiring both was a silent
 -- gate that blocked all Judgement once mana dropped into JoW mode.
 if state.judgement_wisdom_mode then

  if not state.has_seal_wisdom then return false end

  if state.target_has_wisdom then return false end

  return true

 end

 -- Damage Judgement: SoR or SoC (any damage seal)
 if not (state.has_seal or state.has_seal_command) then return false end

 return true

end


-- Anti-loop throttle: belt-and-suspenders to RighteousFury + BlessingOfSanctuary.

-- state.has_seal is derived from NS.buff_up which can lag up to ~50ms after a successful

-- cast (especially if the buff-state API is stalled or broken on private servers).

-- During that stale window, matches() returns true every tick while anti-flicker

-- keeps rejecting try_cast — emitting "matched=true, executed=false" spam in

-- [EaxRotations:TRACE]. 3s guard at matches-end eliminates the cycle.

local _last_seal_righteousness_match_time = 0

local function seal_righteousness_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_seal_of_righteousness", true) then return false end

 if state.has_seal then return false end

 if state.has_seal_command then return false end

 -- JoW emergency: do not re-apply SoR over the SoW path
 if state.judgement_wisdom_mode then return false end

 -- Keep SoW while mana is still low; allow overwrite once mana recovers
 if state.has_seal_wisdom then

  local mana_threshold = spec_kit.setting_number(context, "prot_seal_of_wisdom_mana", 30)

  if (state.mana_pct or 100) <= mana_threshold then return false end

 end

 local now = NS.time_now and NS.time_now() or 0

 if (now - _last_seal_righteousness_match_time) < 3.0 then return false end

 _last_seal_righteousness_match_time = now

 return true

end


local _last_seal_command_aoe_match_time = 0

local _last_divine_protection_prot_match_time = 0

local _last_lay_on_hands_prot_match_time = 0

local function seal_command_aoe_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_seal_of_command", false) then return false end

 if (state.enemy_count or 0) < 3 then return false end

 if state.has_seal or state.has_seal_command then return false end

 if not NS.spell_ready(ACTION.SealCommand, context.me, { skip_range = true }) then return false end

 local now = NS.time_now and NS.time_now() or 0

 if (now - _last_seal_command_aoe_match_time) < 3.0 then return false end

 _last_seal_command_aoe_match_time = now

 return true

end


local function turn_evil_matches(context, state)
    if not spec_kit.setting_bool(context, "prot_auto_turn_evil", true) then return false end
    if not state.turn_evil_ready then return false end
    if not context.has_valid_enemy_target then return false end
    local ct = state.target_creature_type
    if not ct or not DEMON_OR_UNDEAD[ct] then return false end
    if context.target and NS.debuff_up and NS.debuff_up(context.target, {10326}) then return false end
    return true
end


local function exorcism_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_exorcism", true) then return false end

 if not state.exorcism_ready then return false end

 if not state.target_creature_type then return false end

 if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end

 return true

end


local function divine_shield_matches(context, state)

 local threshold = spec_kit.setting_number(context, "prot_divine_shield_hp", 15)

 if (state.hp_pct or 100) > threshold then return false end

 if state.has_forbearance then return false end

 if state.has_divine_shield then return false end

 if not state.divine_shield_ready then return false end

 return true

end


local function lay_on_hands_matches(context, state)

 local threshold = spec_kit.setting_number(context, "prot_lay_on_hands_hp", 10)

 if (state.hp_pct or 100) > threshold then return false end

 if not state.lay_on_hands_ready then return false end

 local now = NS.time_now and NS.time_now() or 0

 if (now - _last_lay_on_hands_prot_match_time) < 3.0 then return false end

 _last_lay_on_hands_prot_match_time = now

 return true

end



local function flash_of_light_matches(context, state)

 local threshold = spec_kit.setting_number(context, "prot_flash_of_light_hp", 40)

 if (state.hp_pct or 100) > threshold then return false end

 if not state.flash_of_light_ready then return false end

 return true

end


local function holy_light_matches(context, state)

 local threshold = spec_kit.setting_number(context, "prot_holy_light_hp", 25)

 if (state.hp_pct or 100) > threshold then return false end

 if not state.holy_light_ready then return false end

 return true

end


local function seal_of_wisdom_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_seal_of_wisdom", true) then return false end

 if state.has_seal_wisdom then return false end

 if not state.seal_of_wisdom_ready then return false end

 -- Enter SoW when JoW mode is active OR mana is below the SoW threshold.
 -- Must be allowed to replace SoR/SoC (old gate `if state.has_seal` deadlocked
 -- JoW: SoR stayed up → SoW never applied → Judgement required SoW forever).
 if state.judgement_wisdom_mode then return true end

 local mana_threshold = spec_kit.setting_number(context, "prot_seal_of_wisdom_mana", 30)

 if (state.mana_pct or 100) > mana_threshold then return false end

 return true

end


local _last_devotion_aura_prot_match_time = 0

local function devotion_aura_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_devotion_aura", true) then return false end

 if state.has_devotion_aura then return false end

 if NS.buff_remains and context.me then

  local remains = NS.buff_remains(context.me, DEVOTION_AURA_BUFF) or 0

  if remains > 0 then return false end

 end

 local now = NS.time_now and NS.time_now() or 0

 if (now - _last_devotion_aura_prot_match_time) < 3.0 then return false end

 _last_devotion_aura_prot_match_time = now

 return true

end


-- Anti-loop throttle for OOC blessing (prevents matched=true / executed=false cycle

-- when buff state lags behind matches calls). 3s is invisible vs 30min blessing duration.

local _last_blessing_sanctuary_match_time = 0

local function blessing_of_sanctuary_matches(context, state)

 if not spec_kit.setting_bool(context, "prot_blessing_sanctuary", true) then return false end

 if state.has_blessing_sanctuary then return false end

 if NS.buff_remains and context.me then

  local remains = NS.buff_remains(context.me, BLESSING_OF_SANCTUARY_BUFF) or 0

  if remains > 0 then return false end

 end

 local now = NS.time_now and NS.time_now() or 0

 if (now - _last_blessing_sanctuary_match_time) < 3.0 then return false end

 _last_blessing_sanctuary_match_time = now

 return true

end


-- ============================================================================

-- Strategies

-- ============================================================================-- Priority order: Consecration > HolyShield > AvengerShield for AoE threat.
-- Consecration generates more AoE threat per GCD; HolyShield provides mitigation.
-- DevotionAura and BlessingOfSanctuary are placed low so they don't block
-- the actual combat rotation.

-- Strategy metadata for centralized guards. Keys correspond to strategy.name.
local ACTIONS = {
    Healthstone = { requires_in_combat = true },
    ManaPotion = { requires_in_combat = true },
    RighteousFury = {},
    HolyShield = { requires_in_combat = true, requires_target = true },
    Judgement = { requires_in_combat = true, requires_target = true },
    SealOfCommandAoE = { requires_in_combat = true, requires_target = true },
    SealRighteousness = {},
    SealOfWisdom = {},
    Consecration = { requires_in_combat = true, requires_target = true },
    TurnEvil = { requires_target = true },
    Exorcism = { requires_in_combat = true, requires_target = true },
    HolyWrath = { requires_in_combat = true, requires_target = true },
    HammerOfWrath = { requires_in_combat = true, requires_target = true },
    AvengingWrath = { requires_in_combat = true },
    AvengerShield = { requires_target = true },
    DevotionAura = { requires_not_in_combat = true },
    BlessingOfSanctuary = { requires_not_in_combat = true },
    HolyShock = { requires_in_combat = true, requires_target = true },
    FlashOfLight = {},
    HolyLight = {},
    Cleanse = {},
    DivineProtection = { requires_in_combat = true },
    DivineShield = {},
    LayOnHands = {},
    RighteousDefense = { requires_in_combat = true },
    BlessingOfProtectionAlly = { requires_in_combat = true },
    BlessingOfKingsParty = { requires_not_in_combat = true },
}

local function RighteousDefense_matches(context, state)  return spec_kit.setting_bool(context, "auto_taunt", true) and spec_kit.setting_bool(context, "prot_righteous_defense", true) and state.ally_threatened ~= nil and state.righteous_defense_ready and (context.target_classification or 0) >= 1 end


local function RighteousDefense_execute(context, state) return NS.try_cast(ACTION.RighteousDefense, state.ally_threatened, "[PROTECTION] Righteous Defense peel") end


local function BlessingOfProtectionAlly_matches(context, state)  return spec_kit.setting_bool(context, "prot_blessing_of_protection", true) and state.low_hp_ally ~= nil and NS.spell_ready(ACTION.BlessingOfProtection, state.low_hp_ally, {}) or false end

local function BlessingOfProtectionAlly_execute(context, state) return NS.try_cast(ACTION.BlessingOfProtection, state.low_hp_ally, "[PROTECTION] BoP emergency peel") end


local strategies = {

    { name = "Healthstone",

      matches = function(context, state)

          if (context.hp or 100) > 28 then return false end

          return (state.healthstone_ready or 0) > 0

      end,

      execute = function(context)

          local item_id = first_ready_item(HEALTHSTONE_IDS)

          if item_id > 0 and NS.use_item_by_id then

              return NS.use_item_by_id(item_id, context.me) and true or false

          end

          return false

      end,

    },


 { name = "ManaPotion",

  matches = function(context)

   if not spec_kit.setting_bool(context, "use_auto_potions", true) then return false end

   if not context.has_mana_potion then return false end

   if (context.mana_pct or 100) > 20 then return false end

   return true

  end,

  execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },

 -- Buff maintenance (no target needed, check once)

{ name = "RighteousFury", matches = righteous_fury_matches, execute = function(context) return NS.try_cast(ACTION.RighteousFury, context.me, "[PROTECTION] RighteousFury") end },

 -- TBC guide (Wowhead 2.5.5): Holy Shield is #1 priority on crush-cap bosses

 -- (100% uptime for the 102.4% CTC; survival > threat). Keep it above Consecration

 -- so a charge-low Holy Shield never waits a GCD behind a Consecration refresh.

 { name = "HolyShield", matches = holy_shield_matches, execute = function(context) return NS.try_cast(ACTION.HolyShield, context.me, "[PROTECTION] HolyShield") end },

 -- Wowsims APL order (sim/paladin/protection/rotation.go):
 -- HolyShield -> Consecration -> Judgement/Seal cycle -> Exorcism -> Hammer of Wrath -> Avenger's Shield

 { name = "Consecration", matches = consecration_matches, execute = function(context)

  local mana_pct = context.mana_pct or (context.me and NS.unit_mana_pct and NS.unit_mana_pct(context.me)) or 100

  local downrank_id = get_consecration_id_for_mana(mana_pct)

  if downrank_id then

   return NS.try_cast(downrank_id, context.me, "[PROTECTION] Consecration (downranked)")

  end

  return NS.try_cast(ACTION.Consecration, context.me, "[PROTECTION] Consecration")

 end },

 { name = "Judgement", matches = judgement_matches, execute = function(context) return NS.try_cast(ACTION.Judgement, context.target, "[PROTECTION] Judgement") end },

 { name = "SealOfCommandAoE", matches = seal_command_aoe_matches, execute = function(context) return NS.try_cast(ACTION.SealCommand, context.me, "[PROTECTION] Seal of Command AoE") end },

 { name = "SealRighteousness", matches = seal_righteousness_matches, execute = function(context) return NS.try_cast(ACTION.SealRighteousness, context.me, "[PROTECTION] SealRighteousness") end },

 { name = "SealOfWisdom", matches = seal_of_wisdom_matches, execute = function(context) return NS.try_cast(ACTION.SealOfWisdom, context.me, "[PROTECTION] SealOfWisdom") end },

 { name = "TurnEvil", matches = turn_evil_matches, execute = function(context) return NS.try_cast(ACTION.TurnEvil, context.target, "[PROTECTION] TurnEvil") end },

 { name = "Exorcism", matches = exorcism_matches, execute = function(context) return NS.try_cast(ACTION.Exorcism, context.target, "[PROTECTION] Exorcism") end },

 { name = "HolyWrath" },  -- DSL-substituted at runtime

 { name = "HammerOfWrath" },  -- DSL-substituted at runtime

 { name = "AvengingWrath" },  -- DSL-substituted at runtime

 { name = "AvengerShield", matches = avenger_shield_matches, execute = function(context) return NS.try_cast(ACTION.AvengerShield, context.target, "[PROTECTION] AvengerShield") end },

 { name = "DevotionAura", matches = devotion_aura_matches, execute = function(context) return NS.try_cast(ACTION.DevotionAura, context.me, "[PROTECTION] DevotionAura") end },

 { name = "BlessingOfSanctuary", matches = blessing_of_sanctuary_matches, execute = function(context) return NS.try_cast(ACTION.BlessingOfSanctuary, context.me, "[PROTECTION] BlessingOfSanctuary") end },

 { name = "HolyShock" },  -- DSL-substituted at runtime

 { name = "FlashOfLight", matches = flash_of_light_matches, execute = function(context) return NS.try_cast(ACTION.FlashOfLight, context.me, "[PROTECTION] FlashOfLight") end },

 { name = "HolyLight", matches = holy_light_matches, execute = function(context) return NS.try_cast(ACTION.HolyLight, context.me, "[PROTECTION] HolyLight") end },

 { name = "Cleanse" },  -- DSL-substituted at runtime

 { name = "DivineProtection" },  -- DSL-substituted at runtime

 { name = "DivineShield", matches = divine_shield_matches, execute = function(context) return NS.try_cast(ACTION.DivineShield, context.me, "[PROTECTION] DivineShield") end },

 { name = "LayOnHands", matches = lay_on_hands_matches, execute = function(context) return NS.try_cast(ACTION.LayOnHands, context.me, "[PROTECTION] LayOnHands") end },

 -- Peel

  { name = "RighteousDefense", matches = RighteousDefense_matches, execute = RighteousDefense_execute },

  { name = "BlessingOfProtectionAlly", matches = BlessingOfProtectionAlly_matches, execute = BlessingOfProtectionAlly_execute },

 -- OOC party buff maintenance

 { name = "BlessingOfKingsParty", matches = function(context, state)

  if not spec_kit.setting_bool(context, "prot_bok_party", true) then return false end

  if not state.is_group then return false end

  if not NS.spell_ready(ACTION.BlessingOfKings, NS.PLAYER_UNIT, { skip_range = true }) then return false end

  state.utility_target = find_ally(context, function(unit) return not unit_has_buff(unit, BLESSING_KINGS_BUFF) end)

  return state.utility_target ~= nil

 end, execute = function(_, state) return NS.try_cast(ACTION.BlessingOfKings, state.utility_target, "[PROT] Blessing of Kings party") end },

}


-- ============================================================================
-- Declarative Strategy DSL definitions (fifth DSL adopter, first tank)
-- ============================================================================
-- These strategies are compiled from declarative definitions and replace the
-- imperative match functions in the strategies table above for the same names.
-- This proves the DSL generalizes beyond DPS specs to tank mechanics: defensive
-- cooldown throttles, creature-type gating, settings-driven HP thresholds, and
-- mana-based resource management.
local DSL_DEFS = {
    {
        name = "HammerOfWrath",
        conditions = {
            { type = "setting", key = "prot_hammer_of_wrath", op = "truthy", default = false },
            { type = "state", field = "hammer_of_wrath_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                local execute_hp = spec_kit.setting_number(context, "prot_hammer_of_wrath_hp", 20)
                if (state.target_hp_pct or 100) > execute_hp then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.HammerOfWrath, context.target, "[PROTECTION] HammerOfWrath")
        end },
    },
    {
        name = "AvengingWrath",
        conditions = {
            { type = "setting", key = "prot_avenging_wrath", op = "truthy", default = true },
            { type = "custom", fn = function(context, state)
                if not cooldowns_enabled(context) then return false end
                return true
            end },
            { type = "state", field = "has_forbearance", op = "falsy" },
            { type = "state", field = "avenging_wrath_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.AvengingWrath, context.me, "[PROTECTION] AvengingWrath")
        end },
    },
    {
        name = "HolyShock",
        conditions = {
            { type = "state", field = "holy_shock_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                local fol_threshold = spec_kit.setting_number(context, "prot_flash_of_light_hp", 40)
                if (state.hp_pct or 100) <= fol_threshold then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.HolyShock, context.target, "[PROTECTION] HolyShock")
        end },
    },
    {
        name = "Cleanse",
        conditions = {
            { type = "setting", key = "prot_cleanse", op = "truthy", default = true },
            { type = "state", field = "needs_cleanse", op = "truthy" },
            { type = "state", field = "cleanse_ready", op = "truthy" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Cleanse, context.me, "[PROTECTION] Cleanse")
        end },
    },
    {
        name = "HolyWrath",
        conditions = {
            { type = "setting", key = "prot_holy_wrath", op = "truthy", default = true },
            { type = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "holy_wrath_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if not state.target_creature_type then return false end
                if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.HolyWrath, context.me, "[PROTECTION] HolyWrath")
        end },
    },
    {
        name = "DivineProtection",
        -- Single custom condition: the 3s anti-loop throttle has a side effect
        -- (_last_divine_protection_prot_match_time = now) that can't be expressed
        -- via declarative DSL condition types, so the full logic stays in one fn.
        conditions = {
            { type = "custom", fn = function(context, state)
                local threshold = spec_kit.setting_number(context, "prot_divine_protection_hp", 25)
                if (state.hp_pct or 100) > threshold then return false end
                if state.has_forbearance then return false end
                if state.has_divine_shield then return false end
                if not state.divine_protection_ready then return false end
                local now = NS.time_now and NS.time_now() or 0
                if (now - _last_divine_protection_prot_match_time) < 3.0 then return false end
                _last_divine_protection_prot_match_time = now
                return true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.DivineProtection, context.me, "[PROTECTION] DivineProtection", { skip_range = true })
        end },
    },
}

-- Compile declarative strategies, injecting build_state so unit tests that call
-- strategy.matches(context) without state get a freshly-built state.
local DSL_STRATEGIES = dsl.compile_strategies(DSL_DEFS, { get_state = build_state })

-- ============================================================================
-- DSL in-place substitution (preserves priority order)
-- ============================================================================
local DSL_BY_NAME = {}
for i = 1, #DSL_STRATEGIES do
    DSL_BY_NAME[DSL_STRATEGIES[i].name] = DSL_STRATEGIES[i]
end

for i = 1, #strategies do
    local dsl_strategy = DSL_BY_NAME[strategies[i].name]
    if dsl_strategy then
        strategies[i] = dsl_strategy
    end
end

-- Apply centralized base_matches guards after DSL substitution so both
-- imperative and DSL-compiled strategies share the same guard layer.
apply_base_matches(strategies, ACTIONS)

if NS.rotation_registry and NS.rotation_registry.register then

    NS.rotation_registry:register("protection", strategies, { get_state = build_state })

end

if NS.log then NS.log("Paladin protection rotation registered") end

-- Paladin protection rotation registered — AoE threat priority, SoC option, HS charge tracking

return { strategies = strategies, build_state = build_state }
