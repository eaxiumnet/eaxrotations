-- protection_vanilla.lua — Paladin Protection tank for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  AoE tank (Consecration, Holy Shield, Seal of Righteousness).
-- WHEN:  combat, when NS.is_vanilla() is true.
-- WHY:   Vanilla Prot Paladin has no taunt; relies on threat generation.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local __eax_file = "classes/paladin/protection_vanilla.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-28"
local __eax_change = "Classic Vanilla Protection Paladin rotation"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Paladin Protection priority list with holy threat, uncrushable logic, and seal/aura management.

-- ============================================================================
-- What: Paladin Protection priority with holy threat and seal/aura management.
-- When: Evaluated every tick.
-- Why: Priority-list early exit keeps tanking decisions fast and predictable.
-- Safety: Nil-guarded state; conservative thresholds; NS.* helpers only.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local potion_helper = require("shared/potion_helper_sylvanas")
local SPELLS = NS.PaladinSpells or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local RIGHTEOUS_FURY_BUFF = { 25780 }
local HOLY_SHIELD_BUFF = { 20928, 20927, 20925 }
local SEAL_RIGHTEOUSNESS_BUFF = { 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
local CONSECRATION_DEBUFF = { 20924, 20923, 20922, 20116, 26573 }
local BLESSING_OF_SANCTUARY_BUFF = { 20914, 20913, 20912, 20911 }
local DEVOTION_AURA_BUFF = { 10293, 10292, 1032, 643, 10291, 10290, 465 }
local DIVINE_SHIELD_BUFF = { 642 }
local FORBEARANCE_DEBUFF = { 25771 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }
local CC_DEBUFFS = { 118, 12824, 12825, 12826, 28271, 28272, 3355, 14308, 14309, 20066 }
local CONSECRATION_MIN_MANA = 35
local CONSECRATION_AOE_THRESHOLD = 3

-- ============================================================================
-- Settings helper
-- ============================================================================
local get_setting = spec_kit.setting

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
    has_devotion_aura = false,
    has_divine_shield = false,
    has_forbearance = false,
    consecration_remains = 0,
    has_blessing_sanctuary = false,
    now_ms = 0,
    holy_shield_ready = false,
    exorcism_ready = false,
    judgement_ready = false,
    divine_shield_ready = false,
    lay_on_hands_ready = false,
    hammer_of_justice_ready = false,
    hammer_of_wrath_ready = false,
    flash_of_light_ready = false,
    holy_light_ready = false,
    holy_shock_ready = false,
    holy_wrath_ready = false,
    cleanse_ready = false,
    needs_cleanse = false,
    seal_of_wisdom_ready = false,
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
        prot_state.has_devotion_aura = me and NS.buff_up(me, DEVOTION_AURA_BUFF) or false
        prot_state.has_divine_shield = me and NS.buff_up(me, DIVINE_SHIELD_BUFF) or false
        prot_state.has_forbearance = me and NS.debuff_up(me, FORBEARANCE_DEBUFF) or false
        prot_state.consecration_remains = target and NS.debuff_remains(target, CONSECRATION_DEBUFF) or 0
        prot_state.has_blessing_sanctuary = me and NS.buff_up(me, BLESSING_OF_SANCTUARY_BUFF) or false
    end
    prot_state.consecration_ready = me and NS.spell_ready(SPELLS.Consecration, me, { skip_range = true, expected_cooldown = 8 }) or false
    prot_state.holy_shield_ready = me and NS.spell_ready(SPELLS.HolyShield, me, { skip_range = true, expected_cooldown = 10 }) or false
    prot_state.exorcism_ready = target and NS.spell_ready(SPELLS.Exorcism, target, { expected_cooldown = 15 }) or false
    prot_state.judgement_ready = target and NS.spell_ready(SPELLS.Judgement, target, { expected_cooldown = 10 }) or false
    prot_state.divine_shield_ready = me and NS.spell_ready(SPELLS.DivineShield, me, { skip_range = true, expected_cooldown = 300 }) or false
    prot_state.lay_on_hands_ready = me and NS.spell_ready(SPELLS.LayOnHands, me, { skip_range = true, expected_cooldown = 3600 }) or false
    prot_state.hammer_of_justice_ready = target and NS.spell_ready(SPELLS.HammerOfJustice, target, { expected_cooldown = 60 }) or false
    prot_state.hammer_of_wrath_ready = target and NS.spell_ready(SPELLS.HammerOfWrath, target, { expected_cooldown = 6 }) or false
    prot_state.flash_of_light_ready = me and NS.spell_ready(SPELLS.FlashOfLight, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.holy_light_ready = me and NS.spell_ready(SPELLS.HolyLight, me, { skip_range = true, expected_cooldown = 2.5 }) or false
    prot_state.holy_shock_ready = target and NS.spell_ready(SPELLS.HolyShock, target, { expected_cooldown = 15 }) or false
    prot_state.holy_wrath_ready = me and NS.spell_ready(SPELLS.HolyWrath, me, { skip_range = true, expected_cooldown = 60 }) or false
    prot_state.cleanse_ready = me and NS.spell_ready(SPELLS.Cleanse, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.needs_cleanse = self_needs_cleanse(me)
    prot_state.seal_of_wisdom_ready = me and NS.spell_ready(SPELLS.SealOfWisdom, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.mana_pct = context.mana_pct or (me and NS.mana_pct and NS.mana_pct(me)) or 100
    prot_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    prot_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100
    prot_state.enemy_count = context.enemy_count or context.enemies_count or 1
    prot_state.target_creature_type = creature_type(target)
    prot_state.target_casting = target and target.is_casting and target:is_casting() or false

    -- Scan allies for threat and low HP (Righteous Defense / BoP peel)
    prot_state.ally_threatened = nil
    prot_state.low_hp_ally = nil
    local allies = context.party_members or context.group_members or context.allies
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

    -- CC proximity check (skip AoE near controlled mobs)
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
    return not context.settings or context.settings.use_cooldowns ~= false
end

-- ============================================================================
-- Match functions
-- ============================================================================
local function righteous_fury_matches(context, state)
    if state.has_righteous_fury then return false end
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

local function judgement_matches(context, state)
    if not get_setting(context, "prot_judgement", true) then return false end
    if not has_combat_target(context) then return false end
    if not state.judgement_ready then return false end
    if not state.has_seal then return false end
    return true
end

local function seal_righteousness_matches(context, state)
    if not get_setting(context, "prot_seal_of_righteousness", true) then return false end
    if state.has_seal then return false end
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
    return true
end

local function hammer_of_justice_matches(context, state)
    if NS.DRTracker and NS.DRTracker.is_dr_immune and context.target and NS.DRTracker.is_dr_immune(context.target, "stun") then return false end
    if not get_setting(context, "prot_hammer_of_justice", true) then return false end
    if not state.target_casting then return false end
    if not state.hammer_of_justice_ready then return false end
    return true
end

local function holy_shock_matches(context, state)
    if not has_combat_target(context) then return false end
    if not state.holy_shock_ready then return false end
    -- Don't burn Holy Shock offensively when the tank needs self-healing;
    -- let Flash of Light / Holy Light (positioned below) get priority instead.
    local fol_threshold = get_setting(context, "prot_flash_of_light_hp", 40)
    if (state.hp_pct or 100) <= fol_threshold then return false end
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

local function devotion_aura_matches(context, state)
    if not get_setting(context, "prot_devotion_aura", true) then return false end
    -- Don't block combat rotation with aura maintenance when in combat
    if has_combat_target(context) then return false end
    if state.has_devotion_aura then return false end
    if NS.buff_remains and context.me then
        local remains = NS.buff_remains(context.me, DEVOTION_AURA_BUFF) or 0
        if remains > 0 then return false end
    end
    return true
end

local function blessing_of_sanctuary_matches(context, state)
    if not get_setting(context, "prot_blessing_sanctuary", true) then return false end
    -- Don't block combat rotation with blessing maintenance when in combat
    if has_combat_target(context) then return false end
    if state.has_blessing_sanctuary then return false end
    if NS.buff_remains and context.me then
        local remains = NS.buff_remains(context.me, BLESSING_OF_SANCTUARY_BUFF) or 0
        if remains > 0 then return false end
    end
    return true
end

-- ============================================================================
-- Strategies
-- ============================================================================
-- Priority order: combat spells first, then buff maintenance, then emergency.
-- DevotionAura and BlessingOfSanctuary are placed low so they don't block
-- the actual combat rotation (HolyShield, Consecration, Judgement, etc.).
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
    { name = "HolyShield", matches = holy_shield_matches, execute = function(context) return NS.try_cast(SPELLS.HolyShield, context.me, "[PROTECTION] HolyShield") end },
    { name = "Consecration", matches = consecration_matches, execute = function(context) return NS.try_cast(SPELLS.Consecration, context.me, "[PROTECTION] Consecration") end },
    { name = "Judgement", matches = judgement_matches, execute = function(context) return NS.try_cast(SPELLS.Judgement, context.target, "[PROTECTION] Judgement") end },
    { name = "SealRighteousness", matches = seal_righteousness_matches, execute = function(context) return NS.try_cast(SPELLS.SealRighteousness, context.me, "[PROTECTION] SealRighteousness") end },
    { name = "HammerOfWrath", matches = hammer_of_wrath_matches, execute = function(context) return NS.try_cast(SPELLS.HammerOfWrath, context.target, "[PROTECTION] HammerOfWrath") end },
    { name = "Exorcism", matches = exorcism_matches, execute = function(context) return NS.try_cast(SPELLS.Exorcism, context.target, "[PROTECTION] Exorcism") end },
    { name = "HolyWrath", matches = holy_wrath_matches, execute = function(context) return NS.try_cast(SPELLS.HolyWrath, context.me, "[PROTECTION] HolyWrath") end },
    { name = "SealOfWisdom", matches = seal_of_wisdom_matches, execute = function(context) return NS.try_cast(SPELLS.SealOfWisdom, context.me, "[PROTECTION] SealOfWisdom") end },
    { name = "DevotionAura", matches = devotion_aura_matches, execute = function(context) return NS.try_cast(SPELLS.DevotionAura, context.me, "[PROTECTION] DevotionAura") end },
    { name = "BlessingOfSanctuary", matches = blessing_of_sanctuary_matches, execute = function(context) return NS.try_cast(SPELLS.BlessingOfSanctuary, context.me, "[PROTECTION] BlessingOfSanctuary") end },
    { name = "HolyShock", matches = holy_shock_matches, execute = function(context) return NS.try_cast(SPELLS.HolyShock, context.target, "[PROTECTION] HolyShock") end },
    { name = "FlashOfLight", matches = flash_of_light_matches, execute = function(context) return NS.try_cast(SPELLS.FlashOfLight, context.me, "[PROTECTION] FlashOfLight") end },
    { name = "HolyLight", matches = holy_light_matches, execute = function(context) return NS.try_cast(SPELLS.HolyLight, context.me, "[PROTECTION] HolyLight") end },
    { name = "Cleanse", matches = cleanse_matches, execute = function(context) return NS.try_cast(SPELLS.Cleanse, context.me, "[PROTECTION] Cleanse") end },
    { name = "DivineShield", matches = divine_shield_matches, execute = function(context) return NS.try_cast(SPELLS.DivineShield, context.me, "[PROTECTION] DivineShield") end },
    { name = "LayOnHands", matches = lay_on_hands_matches, execute = function(context) return NS.try_cast(SPELLS.LayOnHands, context.me, "[PROTECTION] LayOnHands") end },
    { name = "HammerOfJustice", matches = hammer_of_justice_matches, execute = function(context) return NS.try_cast(SPELLS.HammerOfJustice, context.target, "[PROTECTION] HammerOfJustice") end },

    -- Peel
    { name = "BlessingOfProtectionAlly", matches = function(context, state) return get_setting(context, "prot_blessing_of_protection", true) and state.low_hp_ally ~= nil and NS.spell_ready(SPELLS.BlessingOfProtection, state.low_hp_ally, {}) or false end, execute = function(context, state) return NS.try_cast(SPELLS.BlessingOfProtection, state.low_hp_ally, "[PROTECTION] BoP emergency peel") end },
}

NS.rotation_registry:register("protection", strategies, { get_state = build_state })
-- Paladin protection rotation registered
return strategies

