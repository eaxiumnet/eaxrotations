-- Readability notes:
--   What: Druid Restoration group-healing playstyle.
--   When: dispatcher runs the resto playstyle.
--   Why: healing decisions use effective HP, incoming heals, absorbs, and HoT state from shared helpers.
--   Safety: every cast goes through NS.spell_ready/NS.try_cast and nil-safe target scans.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.DruidSpells or {}
local Healing = NS.DruidHealing or require("classes/druid/healing_sylvanas")

local NATURES_SWIFTNESS_BUFF = 17116

local resto_state = {
    lowest = nil,
    has_natures_swiftness = false,
}

local function build_state(context)
    local entries, count = Healing.scan_healing_targets()
    resto_state.lowest = NS.healing_get_lowest_hp(entries, count, 92)
    resto_state.has_natures_swiftness = NS.has_player_buff(NATURES_SWIFTNESS_BUFF)
    return resto_state
end

local strategies = {
    {
        name = "BarkskinSelf",
        matches = function(context)
            return context.hp <= 55 and NS.spell_ready(SPELLS.Barkskin, NS.PLAYER_UNIT, { skip_range = true })
        end,
        execute = function()
            return NS.try_cast(SPELLS.Barkskin, NS.PLAYER_UNIT, "[RESTO] Barkskin self")
        end,
    },
    {
        name = "SwiftmendEmergency",
        matches = function(context, state)
            if not state.lowest then return false end
            if (state.lowest.effective_hp or 100) > (context.settings.resto_swiftmend_hp or 50) then return false end
            if not (state.lowest.has_rejuvenation or state.lowest.has_regrowth) then return false end
            return NS.spell_ready(SPELLS.Swiftmend, state.lowest.unit, { expected_cooldown = 15 })
        end,
        execute = function(_, state)
            return NS.try_cast(SPELLS.Swiftmend, state.lowest.unit, string.format("[RESTO] Swiftmend %.0f%%", state.lowest.effective_hp or 0))
        end,
    },
    {
        name = "NaturesSwiftness",
        matches = function(context, state)
            if not state.lowest then return false end
            if state.has_natures_swiftness then return false end
            if (state.lowest.effective_hp or 100) > (context.settings.resto_ns_hp or 30) then return false end
            return NS.spell_ready(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, { skip_range = true, expected_cooldown = 180 })
        end,
        execute = function()
            return NS.try_cast(SPELLS.NaturesSwiftness, NS.PLAYER_UNIT, "[RESTO] Nature's Swiftness emergency")
        end,
    },
    {
        name = "SmartGroupHeal",
        matches = function(context)
            local rec = Healing and Healing.recommend and Healing.recommend(context) or nil
            context._druid_heal_recommendation = rec
            return rec and rec.spell and rec.target and NS.spell_ready(rec.spell, rec.target)
        end,
        execute = function(context)
            local rec = context._druid_heal_recommendation or (Healing and Healing.recommend and Healing.recommend(context))
            if not rec then return false end
            return NS.try_cast(rec.spell, rec.target, "[RESTO] " .. rec.reason)
        end,
    },
}

NS.rotation_registry:register("resto", strategies, { get_state = build_state })
NS.log("Druid resto rotation registered")
return strategies
