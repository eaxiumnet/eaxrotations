-- Readability notes:
--   What: Paladin Protection priority list with holy threat, uncrushable logic, and seal/aura management.
--   When: dispatcher runs this playstyle when selected.
--   Why: Protection Paladin in TBC relies on Righteous Fury, Holy Shield, Consecration, and reactive abilities (Avenger Shield, Revenge proc via Reckoning).
--   Safety: each strategy uses shared spell/resource/range checks before casting.

-- Decision notes:
--   TBC Prot Paladin theorycraft: Righteous Fury must always be active (threat multiplier).
--   Holy Shield is kept on cooldown for block charges and threat.
--   Consecration is the primary AoE threat tool; use when 2+ enemies or on cooldown.
--   Avenger Shield is a ranged pull/interrupt (30s CD).
--   Seal of Righteousness is the sustained threat seal; Judgement for burst.
--   Exorcism for demons/undead (15s CD). Lay on Hands for emergency.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}

local RIGHTEOUS_FURY_BUFF = { 25780 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }
local HOLY_SHIELD_BUFF = { 27179, 20928, 20927, 20925 }
local CONSECRATION_DEBUFF = { 27173, 20924, 20923, 20922, 20116, 26573 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local prot_state = {
    has_righteous_fury = false,
    has_holy_shield = false,
    has_seal = false,
    consecration_remains = 0,
    holy_shield_ready = false,
    avenger_ready = false,
    exorcism_ready = false,
    judgement_ready = false,
    mana_pct = 100,
    hp_pct = 100,
    enemy_count = 1,
    target_creature_type = nil,
}

local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local target = context.target

    prot_state.has_righteous_fury = me and NS.buff_up(me, RIGHTEOUS_FURY_BUFF) or false
    prot_state.has_holy_shield = me and NS.buff_up(me, HOLY_SHIELD_BUFF) or false
    prot_state.has_seal = me and NS.buff_up(me, SEAL_RIGHTEOUSNESS_BUFF) or false
    prot_state.consecration_remains = target and NS.debuff_remains(target, CONSECRATION_DEBUFF) or 0
    prot_state.holy_shield_ready = me and NS.spell_ready(SPELLS.HolyShield, me, { skip_range = true, expected_cooldown = 10 }) or false
    prot_state.avenger_ready = me and NS.spell_ready(SPELLS.AvengerShield, me, { expected_cooldown = 30 }) or false
    prot_state.exorcism_ready = me and NS.spell_ready(SPELLS.Exorcism, me, { expected_cooldown = 15 }) or false
    prot_state.judgement_ready = me and NS.spell_ready(SPELLS.Judgement, me, { expected_cooldown = 10 }) or false
    prot_state.mana_pct = context.mana_pct or (me and NS.unit_mana_pct(me)) or 100
    prot_state.hp_pct = context.hp or (me and NS.unit_health_pct(me)) or 100
    prot_state.enemy_count = context.enemy_count or context.enemies_count or 1
    prot_state.target_creature_type = target and NS.unit_creature_type and NS.unit_creature_type(target) or nil

    return prot_state
end

local function cooldowns_enabled(context)
    return not context.settings or context.settings.use_cooldowns ~= false
end

local RIGHTEOUS_FURY_ACTION = { name = "RighteousFury", spell = SPELLS.RighteousFury, target = "self", kind = "buff", buff = RIGHTEOUS_FURY_BUFF, requires_target = false }
local HOLY_SHIELD_ACTION = { name = "HolyShield", spell = SPELLS.HolyShield, target = "self", combat = true, cooldown = 10, requires_target = false }
local CONSECRATION_ACTION = { name = "Consecration", spell = SPELLS.Consecration, target = "self", combat = true, cooldown = 8, requires_target = false }
local AVENGER_SHIELD_ACTION = { name = "AvengerShield", spell = SPELLS.AvengerShield, not_moving = true, cooldown = 30 }
local EXORCISM_ACTION = { name = "Exorcism", spell = SPELLS.Exorcism, not_moving = true, cooldown = 15, min_mana = 20, creature_types = DEMON_OR_UNDEAD }
local SEAL_RIGHTEOUSNESS_ACTION = { name = "SealRighteousness", spell = SPELLS.SealRighteousness, target = "self", kind = "buff", buff = SEAL_RIGHTEOUSNESS_BUFF, requires_target = false }
local JUDGEMENT_ACTION = { name = "Judgement", spell = SPELLS.Judgement, cooldown = 10 }

local strategies = {
    {
        name = "RighteousFury",
        matches = function(context, state)
            if state.has_righteous_fury then return false end
            return NS.action_matches(context, RIGHTEOUS_FURY_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, RIGHTEOUS_FURY_ACTION, "[PROTECTION]") end,
    },
    {
        name = "SealRighteousness",
        matches = function(context, state)
            if state.has_seal then return false end
            return NS.action_matches(context, SEAL_RIGHTEOUSNESS_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, SEAL_RIGHTEOUSNESS_ACTION, "[PROTECTION]") end,
    },
    {
        name = "HolyShield",
        matches = function(context, state)
            if not state.holy_shield_ready then return false end
            return NS.action_matches(context, HOLY_SHIELD_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, HOLY_SHIELD_ACTION, "[PROTECTION]") end,
    },
    {
        name = "Consecration",
        matches = function(context, state)
            if state.enemy_count < 2 and state.consecration_remains > 2 then return false end
            return NS.action_matches(context, CONSECRATION_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, CONSECRATION_ACTION, "[PROTECTION]") end,
    },
    {
        name = "AvengerShield",
        matches = function(context, state)
            if not state.avenger_ready then return false end
            return NS.action_matches(context, AVENGER_SHIELD_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, AVENGER_SHIELD_ACTION, "[PROTECTION]") end,
    },
    {
        name = "Exorcism",
        matches = function(context, state)
            if not state.exorcism_ready then return false end
            if not state.target_creature_type then return false end
            if not DEMON_OR_UNDEAD[state.target_creature_type] then return false end
            return NS.action_matches(context, EXORCISM_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, EXORCISM_ACTION, "[PROTECTION]") end,
    },
    {
        name = "Judgement",
        matches = function(context, state)
            if not state.judgement_ready then return false end
            if not state.has_seal then return false end
            return NS.action_matches(context, JUDGEMENT_ACTION)
        end,
        execute = function(context) return NS.action_execute(context, JUDGEMENT_ACTION, "[PROTECTION]") end,
    },
}

NS.rotation_registry:register("protection", strategies, { get_state = build_state })
NS.log("Paladin protection rotation registered (Tier A)")
return strategies
