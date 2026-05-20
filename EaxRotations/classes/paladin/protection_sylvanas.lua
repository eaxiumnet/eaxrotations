-- Paladin Protection priority list with holy threat, uncrushable logic, and seal/aura management.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}

-- ============================================================================
-- Buff & Debuff ID tables
-- ============================================================================
local RIGHTEOUS_FURY_BUFF = { 25780 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
local HOLY_SHIELD_BUFF = { 27179, 20928, 20927, 20925 }
local CONSECRATION_DEBUFF = { 27173, 20924, 20923, 20922, 20116, 26573 }
local BLESSING_OF_SANCTUARY_BUFF = { 27168, 20914, 20913, 20912, 20911 }
local DEVOTION_AURA_BUFF = { 27149, 10293, 10292, 1032, 643, 10291, 10290, 465 }
local DIVINE_SHIELD_BUFF = { 642 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }
local CC_DEBUFFS = { 118, 12824, 12825, 12826, 28271, 28272, 3355, 14308, 14309, 20066 }
local CONSECRATION_MIN_MANA = 35
local CONSECRATION_AOE_THRESHOLD = 3

-- ============================================================================
-- State builder
-- ============================================================================
local prot_state = {
    has_righteous_fury = false,
    has_holy_shield = false,
    has_seal = false,
    has_devotion_aura = false,
    has_divine_shield = false,
    consecration_remains = 0,
    has_blessing_sanctuary = false,
    holy_shield_ready = false,
    avenger_ready = false,
    exorcism_ready = false,
    judgement_ready = false,
    divine_shield_ready = false,
    lay_on_hands_ready = false,
    hammer_of_justice_ready = false,
    hammer_of_wrath_ready = false,
    avenging_wrath_ready = false,
    flash_of_light_ready = false,
    holy_light_ready = false,
    holy_shock_ready = false,
    cleanse_ready = false,
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

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    prot_state.has_righteous_fury = me and NS.buff_up(me, RIGHTEOUS_FURY_BUFF) or false
    prot_state.has_holy_shield = me and NS.buff_up(me, HOLY_SHIELD_BUFF) or false
    -- Track remaining Holy Shield charges via buff.points for proactive refresh
    prot_state.holy_shield_charges = 0
    if prot_state.has_holy_shield and type(NS.buff_points) == "function" then
        local pts = NS.buff_points(me, HOLY_SHIELD_BUFF)
        prot_state.holy_shield_charges = (pts and pts[1]) or 0
    end
    prot_state.has_seal = me and NS.buff_up(me, SEAL_RIGHTEOUSNESS_BUFF) or false
    prot_state.has_devotion_aura = me and NS.buff_up(me, DEVOTION_AURA_BUFF) or false
    prot_state.has_divine_shield = me and NS.buff_up(me, DIVINE_SHIELD_BUFF) or false
    prot_state.consecration_remains = target and NS.debuff_remains(target, CONSECRATION_DEBUFF) or 0
    prot_state.has_blessing_sanctuary = me and NS.buff_up(me, BLESSING_OF_SANCTUARY_BUFF) or false
    prot_state.holy_shield_ready = me and NS.spell_ready(SPELLS.HolyShield, me, { skip_range = true, expected_cooldown = 10 }) or false
    prot_state.avenger_ready = me and NS.spell_ready(SPELLS.AvengerShield, me, { expected_cooldown = 30 }) or false
    prot_state.exorcism_ready = me and NS.spell_ready(SPELLS.Exorcism, me, { expected_cooldown = 15 }) or false
    prot_state.judgement_ready = me and NS.spell_ready(SPELLS.Judgement, me, { expected_cooldown = 10 }) or false
    prot_state.divine_shield_ready = me and NS.spell_ready(SPELLS.DivineShield, me, { skip_range = true, expected_cooldown = 300 }) or false
    prot_state.lay_on_hands_ready = me and NS.spell_ready(SPELLS.LayOnHands, me, { skip_range = true, expected_cooldown = 1200 }) or false
    prot_state.hammer_of_justice_ready = me and NS.spell_ready(SPELLS.HammerOfJustice, me, { expected_cooldown = 60 }) or false
    prot_state.hammer_of_wrath_ready = me and NS.spell_ready(SPELLS.HammerOfWrath, me, { expected_cooldown = 6 }) or false
    prot_state.avenging_wrath_ready = me and NS.spell_ready(SPELLS.AvengingWrath, me, { skip_range = true, expected_cooldown = 180 }) or false
    prot_state.flash_of_light_ready = me and NS.spell_ready(SPELLS.FlashOfLight, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.holy_light_ready = me and NS.spell_ready(SPELLS.HolyLight, me, { skip_range = true, expected_cooldown = 2.5 }) or false
    prot_state.holy_shock_ready = me and NS.spell_ready(SPELLS.HolyShock, me, { expected_cooldown = 15 }) or false
    prot_state.cleanse_ready = me and NS.spell_ready(SPELLS.Cleanse, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.seal_of_wisdom_ready = me and NS.spell_ready(SPELLS.SealOfWisdom, me, { skip_range = true, expected_cooldown = 1.5 }) or false
    prot_state.righteous_defense_ready = me and NS.spell_ready(SPELLS.RighteousDefense, me, { skip_range = true, expected_cooldown = 10 }) or false
    prot_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    prot_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    prot_state.target_hp_pct = target and NS.unit_health_pct and NS.unit_health_pct(target) or 100
    prot_state.enemy_count = context.enemy_count or context.enemies_count or 1
    prot_state.target_creature_type = target and NS.unit_creature_type and NS.unit_creature_type(target) or nil
    prot_state.target_casting = target and target.is_casting and target:is_casting() or false

    -- Scan allies for threat and low HP (Righteous Defense / BoP peel)
    prot_state.ally_threatened = nil
    prot_state.low_hp_ally = nil
    local allies = context.party_members or context.group_members or context.allies
    if allies then
        for i = 1, #allies do
            local ally = allies[i]
            if ally and ally ~= me then
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
            if enemy and enemy ~= target then
                for j = 1, #CC_DEBUFFS do
                    if enemy.has_debuff and enemy:has_debuff(CC_DEBUFFS[j]) then
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
-- Action definitions (test assertion strings embedded)
-- ============================================================================
local RIGHTEOUS_FURY_ACTION = { name = "RighteousFury", spell = SPELLS.RighteousFury, target = "self", kind = "buff", buff = RIGHTEOUS_FURY_BUFF, requires_target = false }
local HOLY_SHIELD_ACTION = { name = "HolyShield", spell = SPELLS.HolyShield, target = "self", combat = true, cooldown = 10, requires_target = false }
local CONSECRATION_ACTION = { name = "Consecration", spell = SPELLS.Consecration, target = "self", combat = true, cooldown = 8, requires_target = false, min_mana = CONSECRATION_MIN_MANA }
local HOLY_WRATH_ACTION = { name = "HolyWrath", spell = SPELLS.HolyWrath, target = "self", not_moving = true, cooldown = 60, min_mana = 20, creature_types = DEMON_OR_UNDEAD, requires_target = false }
local AVENGER_SHIELD_ACTION = { name = "AvengerShield", spell = SPELLS.AvengerShield, not_moving = true, cooldown = 30 }
local EXORCISM_ACTION = { name = "Exorcism", spell = SPELLS.Exorcism, not_moving = true, cooldown = 15, min_mana = 20, creature_types = DEMON_OR_UNDEAD }
local SEAL_RIGHTEOUSNESS_ACTION = { name = "SealRighteousness", spell = SPELLS.SealRighteousness, target = "self", kind = "buff", buff = SEAL_RIGHTEOUSNESS_BUFF, requires_target = false }
local JUDGEMENT_ACTION = { name = "Judgement", spell = SPELLS.Judgement, cooldown = 10 }

local DIVINE_SHIELD_ACTION = { name = "DivineShield", spell = SPELLS.DivineShield, target = "self", kind = "buff", buff = DIVINE_SHIELD_BUFF, cooldown = 300, requires_target = false }
local LAY_ON_HANDS_ACTION = { name = "LayOnHands", spell = SPELLS.LayOnHands, target = "self", cooldown = 1200, requires_target = false }
local HAMMER_OF_JUSTICE_ACTION = { name = "HammerOfJustice", spell = SPELLS.HammerOfJustice, cooldown = 60 }
local HAMMER_OF_WRATH_ACTION = { name = "HammerOfWrath", spell = SPELLS.HammerOfWrath, cooldown = 6 }
local AVENGING_WRATH_ACTION = { name = "AvengingWrath", spell = SPELLS.AvengingWrath, target = "self", kind = "buff", cooldown = 180, requires_target = false }
local FLASH_OF_LIGHT_ACTION = { name = "FlashOfLight", spell = SPELLS.FlashOfLight, target = "self", cooldown = 1.5, requires_target = false }
local HOLY_LIGHT_ACTION = { name = "HolyLight", spell = SPELLS.HolyLight, target = "self", cooldown = 2.5, requires_target = false }
local HOLY_SHOCK_ACTION = { name = "HolyShock", spell = SPELLS.HolyShock, cooldown = 15 }
local CLEANSE_ACTION = { name = "Cleanse", spell = SPELLS.Cleanse, target = "self", cooldown = 1.5, requires_target = false }
local DEVOTION_AURA_ACTION = { name = "DevotionAura", spell = SPELLS.DevotionAura, target = "self", kind = "buff", buff = DEVOTION_AURA_BUFF, requires_target = false }
local BLESSING_OF_SANCTUARY_ACTION = { name = "BlessingOfSanctuary", spell = SPELLS.BlessingOfSanctuary, target = "self", kind = "buff", buff = BLESSING_OF_SANCTUARY_BUFF, requires_target = false }
local SEAL_OF_WISDOM_ACTION = { name = "SealOfWisdom", spell = SPELLS.SealOfWisdom, target = "self", kind = "buff", requires_target = false }

-- ============================================================================
-- Match functions
-- ============================================================================
local function righteous_fury_matches(context, state)
    if state.has_righteous_fury then return false end
    return NS.action_matches(context, RIGHTEOUS_FURY_ACTION)
end

local function devotion_aura_matches(context, state)
    if state.has_devotion_aura then return false end
    return NS.action_matches(context, DEVOTION_AURA_ACTION)
end

local function seal_righteousness_matches(context, state)
    if state.has_seal then return false end
    return NS.action_matches(context, SEAL_RIGHTEOUSNESS_ACTION)
end

local function holy_shield_matches(context, state)
    if not state.holy_shield_ready then return false end
    -- Track Holy Shield charges via buff.points for proactive refresh.
    -- Holy Shield has 8 charges (10 with Imp Holy Shield talent).
    -- buff.points[1] is typically the remaining charge count.
    -- Refresh when charges <= 2 to maintain uncrushable coverage.
    if state.has_holy_shield then
        local charges = state.holy_shield_charges or 0
        if charges > 2 then return false end
    end
    return NS.action_matches(context, HOLY_SHIELD_ACTION)
end

local function consecration_matches(context, state)
    -- Don't break CC with Consecration
    if state.cc_nearby then return false end
    -- Mana conservation: skip Consecration below mana floor
    if state.mana_pct < CONSECRATION_MIN_MANA then return false end
    if state.enemy_count < 2 and state.consecration_remains > 2 then return false end
    return NS.action_matches(context, CONSECRATION_ACTION)
end

local function avenger_shield_matches(context, state)
    if not state.avenger_ready then return false end
    -- Skip Avenger's Shield near CC'd mobs (bouncing breaks CC)
    if state.cc_nearby then return false end
    return NS.action_matches(context, AVENGER_SHIELD_ACTION)
end

local function exorcism_matches(context, state)
    if not state.exorcism_ready then return false end
    if not state.target_creature_type then return false end
    if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end
    return NS.action_matches(context, EXORCISM_ACTION)
end

local function divine_shield_matches(context, state)
    if state.hp_pct > 15 then return false end
    if state.has_divine_shield then return false end
    if not state.divine_shield_ready then return false end
    return NS.action_matches(context, DIVINE_SHIELD_ACTION)
end

local function lay_on_hands_matches(context, state)
    if state.hp_pct > 10 then return false end
    if not state.lay_on_hands_ready then return false end
    return NS.action_matches(context, LAY_ON_HANDS_ACTION)
end

local function hammer_of_justice_matches(context, state)
    if not state.hammer_of_justice_ready then return false end
    if not state.target_casting then return false end
    return NS.action_matches(context, HAMMER_OF_JUSTICE_ACTION)
end

local function hammer_of_wrath_matches(context, state)
    if not state.hammer_of_wrath_ready then return false end
    if state.target_hp_pct > 20 then return false end
    return NS.action_matches(context, HAMMER_OF_WRATH_ACTION)
end

local function avenging_wrath_matches(context, state)
    if not cooldowns_enabled(context) then return false end
    if not state.avenging_wrath_ready then return false end
    return NS.action_matches(context, AVENGING_WRATH_ACTION)
end

local function flash_of_light_matches(context, state)
    if state.hp_pct > 40 then return false end
    if not state.flash_of_light_ready then return false end
    return NS.action_matches(context, FLASH_OF_LIGHT_ACTION)
end

local function holy_light_matches(context, state)
    if state.hp_pct > 25 then return false end
    if not state.holy_light_ready then return false end
    return NS.action_matches(context, HOLY_LIGHT_ACTION)
end

local function holy_shock_matches(context, state)
    if not state.holy_shock_ready then return false end
    return NS.action_matches(context, HOLY_SHOCK_ACTION)
end

local function cleanse_matches(context, state)
    if not state.cleanse_ready then return false end
    return NS.action_matches(context, CLEANSE_ACTION)
end

local function seal_of_wisdom_matches(context, state)
    if state.mana_pct > 30 then return false end
    if state.has_seal then return false end
    if not state.seal_of_wisdom_ready then return false end
    return NS.action_matches(context, SEAL_OF_WISDOM_ACTION)
end


local function judgement_matches(context, state)
    if not state.judgement_ready then return false end
    if not state.has_seal then return false end
    return NS.action_matches(context, JUDGEMENT_ACTION)
end

local function holy_wrath_matches(context, state)
    -- Holy Wrath is AoE; only cast when 2+ demon/undead targets present
    if state.enemy_count < 2 then return false end
    if not state.target_creature_type then return false end
    if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end
    return NS.action_matches(context, HOLY_WRATH_ACTION)
end

local function blessing_of_sanctuary_matches(context, state)
    if state.has_blessing_sanctuary then return false end
    return NS.action_matches(context, BLESSING_OF_SANCTUARY_ACTION)
end

-- ============================================================================
-- Strategies
-- ============================================================================
local strategies = {
    { name = "RighteousFury", matches = righteous_fury_matches, execute = function(context) return NS.action_execute(context, RIGHTEOUS_FURY_ACTION, "[PROTECTION]") end },
    { name = "DevotionAura", matches = devotion_aura_matches, execute = function(context) return NS.action_execute(context, DEVOTION_AURA_ACTION, "[PROTECTION]") end },
    { name = "BlessingOfSanctuary", matches = blessing_of_sanctuary_matches, execute = function(context) return NS.action_execute(context, BLESSING_OF_SANCTUARY_ACTION, "[PROTECTION]") end },
    { name = "SealRighteousness", matches = seal_righteousness_matches, execute = function(context) return NS.action_execute(context, SEAL_RIGHTEOUSNESS_ACTION, "[PROTECTION]") end },
    { name = "HolyShield", matches = holy_shield_matches, execute = function(context) return NS.action_execute(context, HOLY_SHIELD_ACTION, "[PROTECTION]") end },
    { name = "Consecration", matches = consecration_matches, execute = function(context) return NS.action_execute(context, CONSECRATION_ACTION, "[PROTECTION]") end },
    { name = "AvengerShield", matches = avenger_shield_matches, execute = function(context) return NS.action_execute(context, AVENGER_SHIELD_ACTION, "[PROTECTION]") end },
    { name = "Exorcism", matches = exorcism_matches, execute = function(context) return NS.action_execute(context, EXORCISM_ACTION, "[PROTECTION]") end },
    { name = "HolyWrath", matches = holy_wrath_matches, execute = function(context) return NS.action_execute(context, HOLY_WRATH_ACTION, "[PROTECTION]") end },
    { name = "DivineShield", matches = divine_shield_matches, execute = function(context) return NS.action_execute(context, DIVINE_SHIELD_ACTION, "[PROTECTION]") end },
    { name = "LayOnHands", matches = lay_on_hands_matches, execute = function(context) return NS.action_execute(context, LAY_ON_HANDS_ACTION, "[PROTECTION]") end },
    { name = "HammerOfJustice", matches = hammer_of_justice_matches, execute = function(context) return NS.action_execute(context, HAMMER_OF_JUSTICE_ACTION, "[PROTECTION]") end },
    { name = "HammerOfWrath", matches = hammer_of_wrath_matches, execute = function(context) return NS.action_execute(context, HAMMER_OF_WRATH_ACTION, "[PROTECTION]") end },
    { name = "AvengingWrath", matches = avenging_wrath_matches, execute = function(context) return NS.action_execute(context, AVENGING_WRATH_ACTION, "[PROTECTION]") end },
    { name = "FlashOfLight", matches = flash_of_light_matches, execute = function(context) return NS.action_execute(context, FLASH_OF_LIGHT_ACTION, "[PROTECTION]") end },
    { name = "HolyLight", matches = holy_light_matches, execute = function(context) return NS.action_execute(context, HOLY_LIGHT_ACTION, "[PROTECTION]") end },
    { name = "HolyShock", matches = holy_shock_matches, execute = function(context) return NS.action_execute(context, HOLY_SHOCK_ACTION, "[PROTECTION]") end },
    { name = "Cleanse", matches = cleanse_matches, execute = function(context) return NS.action_execute(context, CLEANSE_ACTION, "[PROTECTION]") end },
    { name = "SealOfWisdom", matches = seal_of_wisdom_matches, execute = function(context) return NS.action_execute(context, SEAL_OF_WISDOM_ACTION, "[PROTECTION]") end },
    { name = "Judgement", matches = judgement_matches, execute = function(context) return NS.action_execute(context, JUDGEMENT_ACTION, "[PROTECTION]") end },
    { name = "RighteousDefense", matches = function(context, state) return state.ally_threatened ~= nil and state.righteous_defense_ready end, execute = function(context, state) return NS.try_cast(SPELLS.RighteousDefense, state.ally_threatened, "[PROTECTION] Righteous Defense peel") end },
    { name = "BlessingOfProtectionAlly", matches = function(context, state) return state.low_hp_ally ~= nil and NS.spell_ready and NS.spell_ready(SPELLS.BlessingOfProtection, state.low_hp_ally, {}) or false end, execute = function(context, state) return NS.try_cast(SPELLS.BlessingOfProtection, state.low_hp_ally, "[PROTECTION] BoP emergency peel") end },
}

NS.rotation_registry:register("protection", strategies, { get_state = build_state })
NS.log("Paladin protection rotation registered (Tier A)")
return strategies
