-- Paladin Protection priority list with holy threat, uncrushable logic, and seal/aura management.
-- WHAT:  tank spec (Righteous Defense / Avenger's Shield threat, Holy Shield
--         for block value, Consecration AoE, Seal of Righteousness / Vigil aura
--         management, Redoubt + Holy Shield for uncrushable calc).
-- WHEN:  in combat with valid target, holding aggro.
-- WHY:   TBC prot consensus: SoR / Vigil + Consecration for threat, Holy Shield
--         for block stacks to maintain 102.4% avoidance against bosses.
-- SAFETY: pattern 14 nil-guards for shield charges / spell blocks.


local NS = _G.EaxRotations
if not NS then return nil end
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.PaladinSpells or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local RIGHTEOUS_FURY_BUFF = { 25780 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
local SEAL_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local HOLY_SHIELD_BUFF = { 27179, 20928, 20927, 20925 }
local CONSECRATION_DEBUFF = { 27173, 20924, 20923, 20922, 20116, 26573 }
local BLESSING_OF_SANCTUARY_BUFF = { 27168, 20914, 20913, 20912, 20911 }
local DEVOTION_AURA_BUFF = { 27149, 10293, 10292, 1032, 643, 10291, 10290, 465 }
local DIVINE_SHIELD_BUFF = { 642 }
local FORBEARANCE_DEBUFF = { 25771 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }
local CC_DEBUFFS = { 118, 12824, 12825, 12826, 28271, 28272, 3355, 14308, 14309, 20066 }
local CONSECRATION_MIN_MANA = 35
local CONSECRATION_AOE_THRESHOLD = 3

-- ============================================================================
-- Consecration downrank table: { min_mana_pct, spell_id }
-- Ordered from highest rank to lowest. Pick first entry where mana >= threshold.
-- ============================================================================
local CONSECRATION_DOWNRANK = {
    { 60, 27173 },  -- R6 (lvl 70)
    { 50, 20924 },  -- R5 (lvl 60)
    { 40, 20923 },  -- R4 (lvl 50)
    { 35, 20922 },  -- R3 (lvl 40)
}

local function get_consecration_id_for_mana(mana_pct)
    mana_pct = mana_pct or 100
    for i = 1, #CONSECRATION_DOWNRANK do
        if mana_pct >= CONSECRATION_DOWNRANK[i][1] then
            return CONSECRATION_DOWNRANK[i][2]
        end
    end
    return nil  -- Below minimum floor, don't cast
end

-- ============================================================================
-- Settings helper
-- ============================================================================
local get_setting = NS.setting

-- ============================================================================
-- Time-based gates (buff detection via Sylvanas API returns nil)
-- ============================================================================

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
    mana_pct = 100,
    hp_pct = 100,
    target_hp_pct = 100,
    enemy_count = 1,
    target_creature_type = nil,
    target_casting = false,
    ally_threatened = nil,
    low_hp_ally = nil,
    cc_nearby = false,
}

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
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(25780, 3.0) or false
    if not skip_aura then
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
    end
    prot_state.consecration_ready = me and NS.spell_ready(SPELLS.Consecration, me, { skip_range = true, expected_cooldown = 8 }) or false
    prot_state.holy_shield_ready = me and NS.spell_ready(SPELLS.HolyShield, me, { skip_range = true, expected_cooldown = 10 }) or false
    prot_state.avenger_ready = target and NS.spell_ready(SPELLS.AvengerShield, target, { expected_cooldown = 30 }) or false
    prot_state.exorcism_ready = target and NS.spell_ready(SPELLS.Exorcism, target, { expected_cooldown = 15 }) or false
    prot_state.judgement_ready = target and NS.spell_ready(SPELLS.Judgement, target, { expected_cooldown = 10 }) or false
    prot_state.divine_shield_ready = me and NS.spell_ready(SPELLS.DivineShield, me, { skip_range = true, expected_cooldown = 300 }) or false
    prot_state.divine_protection_ready = me and NS.spell_ready(SPELLS.DivineProtection, me, { skip_range = true, expected_cooldown = 300 }) or false
    prot_state.lay_on_hands_ready = me and NS.spell_ready(SPELLS.LayOnHands, me, { skip_range = true, expected_cooldown = 3600 }) or false
    prot_state.hammer_of_justice_ready = target and NS.spell_ready(SPELLS.HammerOfJustice, target, { expected_cooldown = 60 }) or false
    prot_state.hammer_of_wrath_ready = target and NS.spell_ready(SPELLS.HammerOfWrath, target, { expected_cooldown = 6 }) or false
    prot_state.avenging_wrath_ready = me and NS.spell_ready(SPELLS.AvengingWrath, me, { skip_range = true, expected_cooldown = 180 }) or false
    prot_state.flash_of_light_ready = me and NS.spell_ready(SPELLS.FlashOfLight, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.holy_light_ready = me and NS.spell_ready(SPELLS.HolyLight, me, { skip_range = true, expected_cooldown = 2.5 }) or false
    prot_state.holy_shock_ready = target and NS.spell_ready(SPELLS.HolyShock, target, { expected_cooldown = 15 }) or false
    prot_state.holy_wrath_ready = me and NS.spell_ready(SPELLS.HolyWrath, me, { skip_range = true, expected_cooldown = 60 }) or false
    prot_state.cleanse_ready = me and NS.spell_ready(SPELLS.Cleanse, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.needs_cleanse = self_needs_cleanse(me)
    prot_state.seal_of_wisdom_ready = me and NS.spell_ready(SPELLS.SealOfWisdom, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.righteous_defense_ready = me and NS.spell_ready(SPELLS.RighteousDefense, me, { skip_range = true, expected_cooldown = 15 }) or false
    prot_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me)) or 100
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

    return prot_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns == true
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

local function has_combat_target(context)
    return context.has_valid_enemy_target and context.in_combat
end

local function holy_shield_matches(context, state)
    if not get_setting(context, "prot_holy_shield", true) then return false end
    if not has_combat_target(context) then return false end
    if not state.holy_shield_ready then return false end
    -- Holy Shield has 8 charges (10 with Imp Holy Shield talent).
    -- buff.points[1] is the remaining charge count.
    -- Refresh when charges drop below configurable threshold.
    if state.has_holy_shield then
        local charges = state.holy_shield_charges or 0
        local refresh_at = get_setting(context, "prot_holy_shield_charges", 2)
        if charges > refresh_at then return false end
    end
    return true
end

local function consecration_matches(context, state)
    if not get_setting(context, "prot_consecration", true) then return false end
    if not has_combat_target(context) then return false end
    if not state.consecration_ready then return false end
    -- Don't break CC with Consecration
    if state.cc_nearby then return false end
    -- Mana conservation: skip Consecration below configurable floor
    local min_mana = get_setting(context, "prot_consecration_min_mana", CONSECRATION_MIN_MANA)
    if (state.mana_pct or 100) < min_mana then return false end
    -- AoE threshold: only use single-target if Consecration is already ticking
    local min_targets = get_setting(context, "prot_consecration_targets", CONSECRATION_AOE_THRESHOLD)
    if (state.enemy_count or 0) < min_targets and (state.consecration_remains or 0) > 2 then return false end
    return true
end

local function avenger_shield_matches(context, state)
    if not get_setting(context, "prot_avenger_shield", true) then return false end
    if not state.avenger_ready then return false end
    -- Skip Avenger's Shield near CC'd mobs (bouncing breaks CC)
    if state.cc_nearby then return false end
    -- Opener mode: pre-pull when target exists but not yet in combat
    local is_opener = get_setting(context, "prot_avenger_opener", true)
        and context.has_valid_enemy_target
        and not context.in_combat
    -- Normal mode: in combat with valid target
    local in_combat = context.has_valid_enemy_target and context.in_combat
    if not (is_opener or in_combat) then return false end
    return true
end

local function judgement_matches(context, state)
    if not get_setting(context, "prot_judgement", true) then return false end
    if not has_combat_target(context) then return false end
    if not state.judgement_ready then return false end
    if not state.has_seal then return false end
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
    if not get_setting(context, "prot_seal_of_righteousness", true) then return false end
    if state.has_seal then return false end
    if state.has_seal_command then return false end
    local now = NS.time_now and NS.time_now() or 0
    if (now - _last_seal_righteousness_match_time) < 3.0 then return false end
    _last_seal_righteousness_match_time = now
    return true
end

local _last_seal_command_aoe_match_time = 0
local _last_divine_protection_prot_match_time = 0
local _last_lay_on_hands_prot_match_time = 0
local function seal_command_aoe_matches(context, state)
    if not get_setting(context, "prot_seal_of_command", false) then return false end
    if not has_combat_target(context) then return false end
    if (state.enemy_count or 0) < 3 then return false end
    if state.has_seal or state.has_seal_command then return false end
    if not NS.spell_ready(SPELLS.SealCommand, context.me, { skip_range = true }) then return false end
    local now = NS.time_now and NS.time_now() or 0
    if (now - _last_seal_command_aoe_match_time) < 3.0 then return false end
    _last_seal_command_aoe_match_time = now
    return true
end

local function hammer_of_wrath_matches(context, state)
    if not get_setting(context, "prot_hammer_of_wrath", true) then return false end
    if not has_combat_target(context) then return false end
    if not state.hammer_of_wrath_ready then return false end
    local execute_hp = get_setting(context, "prot_hammer_of_wrath_hp", 20)
    if (state.target_hp_pct or 100) > execute_hp then return false end
    return true
end

local function avenging_wrath_matches(context, state)
    if not get_setting(context, "prot_avenging_wrath", true) then return false end
    if not cooldowns_enabled(context) then return false end
    if state.has_forbearance then return false end
    if not state.avenging_wrath_ready then return false end
    -- TTD gate: don't waste 3min CD on a dying target
    if context.ttd_known and context.ttd > 0 and context.ttd < 15 then return false end
    return true
end

local function exorcism_matches(context, state)
    if not get_setting(context, "prot_exorcism", true) then return false end
    if not has_combat_target(context) then return false end
    if not state.exorcism_ready then return false end
    if not state.target_creature_type then return false end
    if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end
    return true
end

local function holy_wrath_matches(context, state)
    if not get_setting(context, "prot_holy_wrath", true) then return false end
    if not has_combat_target(context) then return false end
    -- Holy Wrath is AoE; only cast when 2+ demon/undead targets present
    if (state.enemy_count or 0) < 2 then return false end
    if not state.holy_wrath_ready then return false end
    if not state.target_creature_type then return false end
    if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end
    return true
end

local function divine_protection_matches(context, state)
    local threshold = get_setting(context, "prot_divine_protection_hp", 25)
    if (state.hp_pct or 100) > threshold then return false end
    if state.has_forbearance then return false end
    if state.has_divine_shield then return false end
    if not state.divine_protection_ready then return false end
    local now = NS.time_now and NS.time_now() or 0
    if (now - _last_divine_protection_prot_match_time) < 3.0 then return false end
    _last_divine_protection_prot_match_time = now
    return true
end

local function divine_shield_matches(context, state)
    local threshold = get_setting(context, "prot_divine_shield_hp", 15)
    if (state.hp_pct or 100) > threshold then return false end
    if state.has_forbearance then return false end
    if state.has_divine_shield then return false end
    if not state.divine_shield_ready then return false end
    return true
end

local function lay_on_hands_matches(context, state)
    local threshold = get_setting(context, "prot_lay_on_hands_hp", 10)
    if (state.hp_pct or 100) > threshold then return false end
    if not state.lay_on_hands_ready then return false end
    local now = NS.time_now and NS.time_now() or 0
    if (now - _last_lay_on_hands_prot_match_time) < 3.0 then return false end
    _last_lay_on_hands_prot_match_time = now
    return true
end

local function hammer_of_justice_matches(context, state)
    if not get_setting(context, "prot_hammer_of_justice", true) then return false end
    if not state.target_casting then return false end
    if not state.hammer_of_justice_ready then return false end
    return true
end

local function holy_shock_matches(context, state)
    if not has_combat_target(context) then return false end
    if not state.holy_shock_ready then return false end
    return true
end

local function flash_of_light_matches(context, state)
    local threshold = get_setting(context, "prot_flash_of_light_hp", 40)
    if (state.hp_pct or 100) > threshold then return false end
    if not state.flash_of_light_ready then return false end
    return true
end

local function holy_light_matches(context, state)
    local threshold = get_setting(context, "prot_holy_light_hp", 25)
    if (state.hp_pct or 100) > threshold then return false end
    if not state.holy_light_ready then return false end
    return true
end

local function cleanse_matches(context, state)
    if not get_setting(context, "prot_cleanse", true) then return false end
    if not state.needs_cleanse then return false end
    if not state.cleanse_ready then return false end
    return true
end

local function seal_of_wisdom_matches(context, state)
    if not get_setting(context, "prot_seal_of_wisdom", true) then return false end
    local mana_threshold = get_setting(context, "prot_seal_of_wisdom_mana", 30)
    if (state.mana_pct or 100) > mana_threshold then return false end
    if state.has_seal then return false end
    if not state.seal_of_wisdom_ready then return false end
    return true
end

local _last_devotion_aura_prot_match_time = 0
local function devotion_aura_matches(context, state)
    if not get_setting(context, "prot_devotion_aura", true) then return false end
    -- Don't block combat rotation with aura maintenance when in combat
    if has_combat_target(context) then return false end
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
    if not get_setting(context, "prot_blessing_sanctuary", true) then return false end
    -- Don't block combat rotation with blessing maintenance when in combat
    if has_combat_target(context) then return false end
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
-- ============================================================================
-- Priority order: Consecration > HolyShield > AvengerShield for AoE threat.
-- Consecration generates more AoE threat per GCD; HolyShield provides mitigation.
-- DevotionAura and BlessingOfSanctuary are placed low so they don't block
-- the actual combat rotation.
local strategies = {
    { name = "ManaPotion",
      matches = function(context)
          if not context.in_combat then return false end
          if context.settings and context.settings.use_auto_potions == false then return false end
          if not context.has_mana_potion then return false end
          if (context.mana_pct or 100) > 20 then return false end
          return true
      end,
      execute = function(context) return potion_helper.try_use_potion(context, potion_helper.MANA_POTION_IDS) end },
    -- Buff maintenance (no target needed, check once)
{ name = "RighteousFury", matches = righteous_fury_matches, execute = function(context) return NS.try_cast(SPELLS.RighteousFury, context.me, "[PROTECTION] RighteousFury") end },
    -- TBC guide (Wowhead 2.5.5): Holy Shield is #1 priority on crush-cap bosses
    -- (100% uptime for the 102.4% CTC; survival > threat). Keep it above Consecration
    -- so a charge-low Holy Shield never waits a GCD behind a Consecration refresh.
    { name = "HolyShield", matches = holy_shield_matches, execute = function(context) return NS.try_cast(SPELLS.HolyShield, context.me, "[PROTECTION] HolyShield") end },
    { name = "Consecration", matches = consecration_matches, execute = function(context)
        local mana_pct = context.mana_pct or (context.me and NS.unit_mana_pct and NS.unit_mana_pct(context.me)) or 100
        local downrank_id = get_consecration_id_for_mana(mana_pct)
        if downrank_id then
            return NS.try_cast(downrank_id, context.me, "[PROTECTION] Consecration (downranked)")
        end
        return NS.try_cast(SPELLS.Consecration, context.me, "[PROTECTION] Consecration")
    end },
    { name = "AvengerShield", matches = avenger_shield_matches, execute = function(context) return NS.try_cast(SPELLS.AvengerShield, context.target, "[PROTECTION] AvengerShield") end },
    { name = "Judgement", matches = judgement_matches, execute = function(context) return NS.try_cast(SPELLS.Judgement, context.target, "[PROTECTION] Judgement") end },
    { name = "SealOfCommandAoE", matches = seal_command_aoe_matches, execute = function(context) return NS.try_cast(SPELLS.SealCommand, context.me, "[PROTECTION] Seal of Command AoE") end },
    { name = "SealRighteousness", matches = seal_righteousness_matches, execute = function(context) return NS.try_cast(SPELLS.SealRighteousness, context.me, "[PROTECTION] SealRighteousness") end },
    { name = "HammerOfWrath", matches = hammer_of_wrath_matches, execute = function(context) return NS.try_cast(SPELLS.HammerOfWrath, context.target, "[PROTECTION] HammerOfWrath") end },
    { name = "AvengingWrath", matches = avenging_wrath_matches, execute = function(context) return NS.try_cast(SPELLS.AvengingWrath, context.me, "[PROTECTION] AvengingWrath") end },
    { name = "Exorcism", matches = exorcism_matches, execute = function(context) return NS.try_cast(SPELLS.Exorcism, context.target, "[PROTECTION] Exorcism") end },
    { name = "HolyWrath", matches = holy_wrath_matches, execute = function(context) return NS.try_cast(SPELLS.HolyWrath, context.me, "[PROTECTION] HolyWrath") end },
    { name = "SealOfWisdom", matches = seal_of_wisdom_matches, execute = function(context) return NS.try_cast(SPELLS.SealOfWisdom, context.me, "[PROTECTION] SealOfWisdom") end },
    { name = "DevotionAura", matches = devotion_aura_matches, execute = function(context) return NS.try_cast(SPELLS.DevotionAura, context.me, "[PROTECTION] DevotionAura") end },
    { name = "BlessingOfSanctuary", matches = blessing_of_sanctuary_matches, execute = function(context) return NS.try_cast(SPELLS.BlessingOfSanctuary, context.me, "[PROTECTION] BlessingOfSanctuary") end },
    { name = "HolyShock", matches = holy_shock_matches, execute = function(context) return NS.try_cast(SPELLS.HolyShock, context.target, "[PROTECTION] HolyShock") end },
    { name = "FlashOfLight", matches = flash_of_light_matches, execute = function(context) return NS.try_cast(SPELLS.FlashOfLight, context.me, "[PROTECTION] FlashOfLight") end },
    { name = "HolyLight", matches = holy_light_matches, execute = function(context) return NS.try_cast(SPELLS.HolyLight, context.me, "[PROTECTION] HolyLight") end },
    { name = "Cleanse", matches = cleanse_matches, execute = function(context) return NS.try_cast(SPELLS.Cleanse, context.me, "[PROTECTION] Cleanse") end },
    { name = "DivineProtection", matches = divine_protection_matches, execute = function(context) return NS.try_cast(SPELLS.DivineProtection, context.me, "[PROTECTION] DivineProtection", { skip_range = true }) end },
    { name = "DivineShield", matches = divine_shield_matches, execute = function(context) return NS.try_cast(SPELLS.DivineShield, context.me, "[PROTECTION] DivineShield") end },
    { name = "LayOnHands", matches = lay_on_hands_matches, execute = function(context) return NS.try_cast(SPELLS.LayOnHands, context.me, "[PROTECTION] LayOnHands") end },
    -- Peel
    { name = "RighteousDefense", matches = function(context, state) return get_setting(context, "prot_righteous_defense", true) and state.ally_threatened ~= nil and state.righteous_defense_ready and (context.target_classification or 0) >= 1 end, execute = function(context, state) return NS.try_cast(SPELLS.RighteousDefense, state.ally_threatened, "[PROTECTION] Righteous Defense peel") end },
    { name = "BlessingOfProtectionAlly", matches = function(context, state) return get_setting(context, "prot_blessing_of_protection", true) and state.low_hp_ally ~= nil and NS.spell_ready(SPELLS.BlessingOfProtection, state.low_hp_ally, {}) or false end, execute = function(context, state) return NS.try_cast(SPELLS.BlessingOfProtection, state.low_hp_ally, "[PROTECTION] BoP emergency peel") end },
}

NS.rotation_registry:register("protection", strategies, { get_state = build_state })
NS.log("Paladin protection rotation registered — AoE threat priority, SoC option, HS charge tracking")
return strategies
