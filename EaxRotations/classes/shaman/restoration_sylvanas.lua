-- Readability notes:
--   What: Shaman Restoration group-healing playstyle.
--   When: dispatcher runs the restoration playstyle.
--   Why: keeps shield buffs up and chooses Chain Heal/LHW/HW from group effective HP.
--   Safety: every target comes from the shared healing scanner and every cast is gated.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.ShamanSpells or {}
local Healing = NS.ShamanHealing or require("classes/shaman/healing_sylvanas")

local state = { lowest = nil, tank = nil, natures_swiftness_active = false }

local function build_state(context)
    local entries, count = Healing.scan_healing_targets()
    state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    state.tank = NS.healing_get_tank(entries, count) or state.lowest
    state.natures_swiftness_active = NS.has_player_buff(16188)
    return state
end

local strategies = {
    {
        name = "WaterShield",
        matches = function()
            return not NS.has_player_buff({ 33736, 24398, 23575 }) and NS.spell_ready(SPELLS.WaterShield, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.WaterShield, NS.PLAYER_UNIT, "[RESTO] Water Shield")
        end,
    },
    {
        name = "EarthShieldTank",
        matches = function(context, s)
            local target = s.tank and s.tank.unit or NS.PLAYER_UNIT
            return target and not NS.buff_up(target, SPELLS.EarthShield) and NS.spell_ready(SPELLS.EarthShield, target)
        end,
        execute = function(_, s)
            local target = s.tank and s.tank.unit or NS.PLAYER_UNIT
            return NS.try_cast(SPELLS.EarthShield, target, "[RESTO] Earth Shield tank")
        end,
    },
    {
        name = "NaturesSwiftness",
        matches = function(context, s)
            return s.lowest and (s.lowest.effective_hp or 100) <= 30 and not s.natures_swiftness_active and NS.spell_ready(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, "[RESTO] Nature's Swiftness emergency")
        end,
    },
    {
        name = "ManaTideTotem",
        matches = function(context)
            if context.settings.use_cooldowns == false then return false end
            if not context.in_combat then return false end
            if (context.mana_pct or 100) > (context.settings.restoration_mana_tide_pct or 60) then return false end
            if Healing.all_members_above_hp and not Healing.all_members_above_hp(80) then return false end
            return NS.spell_ready(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 300 })
        end,
        execute = function()
            return NS.try_cast(SPELLS.ManaTideTotem, NS.PLAYER_UNIT, "[RESTO] Mana Tide Totem")
        end,
    },
    {
        name = "Bloodlust",
        matches = function(context)
            if context.settings.use_cooldowns == false then return false end
            if not context.in_combat then return false end
            if Healing.all_members_above_hp and not Healing.all_members_above_hp(85) then return false end
            return NS.spell_ready(SPELLS.Bloodlust, NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 600 })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Bloodlust, NS.PLAYER_UNIT, "[RESTO] Bloodlust stable group")
        end,
    },
    {
        name = "SmartHeal",
        matches = function(context, s)
            if not s.lowest then return false end
            local heal = Healing.select_heal(context, s, s.lowest)
            context._shaman_heal = heal
            return heal and heal.spell and NS.spell_ready(heal.spell, s.lowest.unit)
        end,
        execute = function(context, s)
            local heal = context._shaman_heal or Healing.select_heal(context, s, s.lowest)
            if not heal or not heal.spell then return false end
            return NS.try_cast(heal.spell, s.lowest.unit, string.format("[RESTO] %s %.0f%%", heal.label, s.lowest.effective_hp or 0))
        end,
    },
}

NS.rotation_registry:register("restoration", strategies, { get_state = build_state })
NS.log("Shaman restoration rotation registered")
return strategies
