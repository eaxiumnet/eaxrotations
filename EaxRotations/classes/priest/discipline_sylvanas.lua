-- Readability notes:
--   What: Priest Discipline group-healing priority list.
--   When: dispatcher runs this playstyle when selected.
--   Why: Discipline in TBC is still a direct healer; shields are emergency tools, not the whole rotation.
--   Safety: healing targets come from shared nil-safe scans and every cast goes through shared spell gates.

-- Decision notes:
--   This mirrors Holy's triage style but stays lean: emergency shield, Prayer of Mending, direct heals, Renew, idle DPS.
--   Power Word: Shield is guarded by Weakened Soul because repeated shield attempts waste GCDs and mana.
--   Offensive spells only run when the group is stable so the playstyle remains a healer first.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PriestSpells or {}
local Healing = NS.PriestHealing or require("classes/priest/healing_sylvanas")

local SHADOW_WORD_PAIN_DEBUFF = { 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }

local state = {
    lowest = nil,
    tank = nil,
    group_damaged_count = 0,
}

local function build_state(context)
    local entries, count = Healing.scan_healing_targets()
    state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    state.tank = NS.healing_get_tank(entries, count) or state.lowest
    state.group_damaged_count = NS.healing_count_below_hp(entries, count, context.settings.discipline_aoe_hp or 85)
    return state
end

local strategies = {
    {
        name = "EmergencyPowerWordShield",
        matches = function(context, s)
            if not s.lowest then return false end
            if (s.lowest.effective_hp or 100) > (context.settings.discipline_pws_hp or 35) then return false end
            if s.lowest.has_weakened_soul then return false end
            return NS.spell_ready(SPELLS.PowerWordShield, s.lowest.unit)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.PowerWordShield, s.lowest.unit, string.format("[DISCIPLINE] PW:S %.0f%%", s.lowest.effective_hp or 0))
        end,
    },
    {
        name = "PrayerOfMendingTank",
        matches = function(context, s)
            if not context.in_combat then return false end
            local target = s.tank or s.lowest
            if not target then return false end
            return NS.spell_ready(SPELLS.PrayerofMending, target.unit, { expected_cooldown = 10 })
        end,
        execute = function(_, s)
            local target = (s.tank and s.tank.unit) or (s.lowest and s.lowest.unit)
            return NS.try_cast(SPELLS.PrayerofMending, target, "[DISCIPLINE] Prayer of Mending")
        end,
    },
    {
        name = "EmergencyFlashHeal",
        matches = function(context, s)
            if context.is_moving then return false end
            if not s.lowest then return false end
            return (s.lowest.effective_hp or 100) <= (context.settings.discipline_flash_hp or 55)
                and NS.spell_ready(SPELLS.FlashHeal, s.lowest.unit)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.FlashHeal, s.lowest.unit, string.format("[DISCIPLINE] Flash Heal %.0f%%", s.lowest.effective_hp or 0))
        end,
    },
    {
        name = "GreaterHeal",
        matches = function(context, s)
            if context.is_moving then return false end
            if not s.lowest then return false end
            local hp = s.lowest.effective_hp or 100
            return hp <= (context.settings.discipline_greater_heal_hp or 82)
                and hp > (context.settings.discipline_flash_hp or 55)
                and NS.spell_ready(SPELLS.GreaterHeal, s.lowest.unit)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.GreaterHeal, s.lowest.unit, string.format("[DISCIPLINE] Greater Heal %.0f%%", s.lowest.effective_hp or 0))
        end,
    },
    {
        name = "RenewTank",
        matches = function(context, s)
            if not s.tank then return false end
            if s.tank.has_renew then return false end
            return (s.tank.effective_hp or 100) <= (context.settings.discipline_renew_hp or 90)
                and NS.spell_ready(SPELLS.Renew, s.tank.unit)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.Renew, s.tank.unit, string.format("[DISCIPLINE] Renew tank %.0f%%", s.tank.effective_hp or 0))
        end,
    },
    {
        name = "RenewLowest",
        matches = function(context, s)
            if not s.lowest then return false end
            if s.lowest.has_renew then return false end
            return (s.lowest.effective_hp or 100) <= (context.settings.discipline_renew_hp or 90)
                and NS.spell_ready(SPELLS.Renew, s.lowest.unit)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.Renew, s.lowest.unit, string.format("[DISCIPLINE] Renew %.0f%%", s.lowest.effective_hp or 0))
        end,
    },
    {
        name = "IdleShadowWordPain",
        matches = function(context, s)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if s.lowest and (s.lowest.effective_hp or 100) < (context.settings.discipline_idle_hp or 92) then return false end
            if NS.debuff_remains(context.target, SHADOW_WORD_PAIN_DEBUFF) > 0 then return false end
            return NS.spell_ready(SPELLS.ShadowWordPain, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.ShadowWordPain, context.target, "[DISCIPLINE] Idle SW:P")
        end,
    },
    {
        name = "IdleSmite",
        matches = function(context, s)
            if context.is_moving then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if s.lowest and (s.lowest.effective_hp or 100) < (context.settings.discipline_idle_hp or 92) then return false end
            return NS.spell_ready(SPELLS.Smite, context.target)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Smite, context.target, "[DISCIPLINE] Idle Smite")
        end,
    },
}

NS.rotation_registry:register("discipline", strategies, { get_state = build_state })
NS.log("Priest discipline rotation registered")
return strategies
