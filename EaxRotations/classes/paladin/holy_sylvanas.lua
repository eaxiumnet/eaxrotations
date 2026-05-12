-- Readability notes:
--   What: Paladin Holy group-healing playstyle.
--   When: dispatcher runs the holy playstyle.
--   Why: chooses Holy Shock, Flash of Light, or Holy Light from shared healing scans and rank helpers.
--   Safety: target scans, rank selection, and casts are nil-safe and Project Sylvanas API-only.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}
local Healing = NS.PaladinHealing or require("classes/paladin/healing_sylvanas")

local state = { lowest = nil, tank = nil, divine_favor_active = false }

local function build_state(context)
    local entries, count = Healing.scan_healing_targets()
    state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    state.tank = NS.healing_get_tank(entries, count)
    state.divine_favor_active = NS.has_player_buff(20216)
    return state
end

local strategies = {
    {
        name = "DivineFavor",
        matches = function(context, s)
            local target = s.lowest or s.tank
            return target and (target.effective_hp or 100) <= 45 and NS.spell_ready(SPELLS.DivineFavor, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.DivineFavor, NS.PLAYER_UNIT, "[HOLY] Divine Favor before emergency heal")
        end,
    },
    {
        name = "HolyShock",
        matches = function(context, s)
            if not s.lowest then return false end
            local hp = s.lowest.effective_hp or 100
            local emergency_hp = (context.settings and context.settings.holy_shock_hp) or 40
            if hp > emergency_hp and not context.is_moving then return false end
            return NS.spell_ready(SPELLS.HolyShock, s.lowest.unit)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.HolyShock, s.lowest.unit, string.format("[HOLY] Holy Shock %.0f%%", s.lowest.effective_hp or 0))
        end,
    },
    {
        name = "SmartHeal",
        matches = function(context, s)
            if not s.lowest then return false end
            local heal = Healing.select_heal(context, s, s.lowest)
            context._paladin_heal = heal
            return heal and heal.spell and NS.spell_ready(heal.spell, s.lowest.unit)
        end,
        execute = function(context, s)
            local heal = context._paladin_heal or Healing.select_heal(context, s, s.lowest)
            if not heal or not heal.spell then return false end
            return NS.try_cast(heal.spell, s.lowest.unit, string.format("[HOLY] %s %.0f%%", heal.label, s.lowest.effective_hp or 0))
        end,
    },
}

NS.rotation_registry:register("holy", strategies, { get_state = build_state })
NS.log("Paladin holy rotation registered")
return strategies
