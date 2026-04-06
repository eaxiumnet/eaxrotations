-- Eax Druid Restoration | spells.lua
-- Rank tables and buff/debuff ID tables only.

local spells = {}

spells.MARK_OF_THE_WILD = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }
spells.GIFT_OF_THE_WILD = { 27003, 21850, 21849 }
spells.REBIRTH = { 26994, 20748, 20910, 20909, 20484 }
spells.REJUVENATION = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
spells.REGROWTH = { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
spells.SWIFTMEND = { 18562 }
spells.INNERVATE = { 29166 }
spells.TRANQUILITY = { 26983, 9863, 9862, 8918, 740 }
spells.NATURES_SWIFTNESS = { 17116 }
spells.TREE_OF_LIFE = { 33891 }

-- Lifebloom (TBC 2.4.3) - single learned rank that stacks to 3 applications
spells.LIFEBLOOM = { 33763 }
spells.BUFF_LIFEBLOOM = { 33763 }

spells.HEALING_TOUCH = { 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }
spells.BARKSKIN = { 22812 }

spells.MOONKIN_FORM = { 24858 }
spells.TRAVEL_FORM = { 783 }

spells.BUFF_MARK_OF_THE_WILD = { 1126, 21849, 26990 }
spells.BUFF_GIFT_OF_THE_WILD = { 27003, 21850, 21849 }
spells.BUFF_REJUVENATION = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
spells.BUFF_REGROWTH = { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
spells.BUFF_INNERVATE = { 29166 }
spells.BUFF_NATURES_SWIFTNESS = { 17116 }
spells.BUFF_BARKSKIN = { 22812 }
spells.BUFF_MOONKIN_FORM = { 24858 }
spells.BUFF_TREE_OF_LIFE = { 33891 }

spells.DEBUFF_MOONFIRE = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 26988 }

spells.BERSERKING = { 26297 }
spells.SHADOWMELD = { 1784 }
spells.WAR_STOMP = { 20549 }

spells.BUFF_BERSERKING = { 26297 }
spells.BUFF_SHADOWMELD = { 1784 }

spells.HASTE_POTION = { 28508, 22832 }
spells.SUPER_MANA_POTION = { 28499, 22828 }
spells.SCROLL_OF_INTELLECT = { 22732, 10291 }
spells.SCROLL_OF_STAMINA = { 22733, 10292 }


spells.REMOVE_CURSE = { 2782, 8690, 8691 }
spells.ABOLISH_POISON = { 2893 }
spells.BUFF_ABOLISH_POISON = { 2893 }

-- DPS fallback spells (used in solo when no healing needed)
spells.MOONFIRE      = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
spells.INSECT_SWARM  = { 27013, 24977, 24976, 24975, 24974, 5570 }
spells.WRATH         = { 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }
spells.STARFIRE      = { 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }
spells.FAERIE_FIRE   = { 26993, 9907, 9749, 778, 770 }

spells.DEBUFF_MOONFIRE      = spells.MOONFIRE
spells.DEBUFF_INSECT_SWARM  = { 24977, 24976, 24975, 24974, 5570 }
spells.DEBUFF_FAERIE_FIRE   = { 770, 778, 9749, 9907, 26993 }

-- Pacify debuffs that prevent casting (e.g., Mechanar's Pacifying Dust)
spells.PACIFY_BUFFS = { 32904, 6465 }

-- ============================================================================
-- HEAL DATA TABLES (Flux Adaptation)
-- Used for smart deficit-based rank selection in spell_downrank.lua
-- Format: [spell_id] = { avg_heal = X, mana_cost = Y, cast_time = Z }
-- Data sourced from TBC 2.4.3 spell database (wowsims verified)
-- ============================================================================

-- Healing Touch: 13 ranks (R1-R13)
-- Sorted high-to-low (best rank first for iteration)
spells.HEALING_TOUCH_DATA = {
    [26979] = { rank = 13, avg_heal = 2948, mana_cost = 935, cast_time = 3.5 },  -- Rank 13
    [26978] = { rank = 12, avg_heal = 2472, mana_cost = 800, cast_time = 3.5 },  -- Rank 12
    [25297] = { rank = 11, avg_heal = 2065, mana_cost = 680, cast_time = 3.5 },  -- Rank 11
    [9889]  = { rank = 10, avg_heal = 1656, mana_cost = 600, cast_time = 3.5 },  -- Rank 10
    [9888]  = { rank = 9,  avg_heal = 1313, mana_cost = 500, cast_time = 3.5 },  -- Rank 9
    [9758]  = { rank = 8,  avg_heal = 1151, mana_cost = 435, cast_time = 3.0 },  -- Rank 8
    [8903]  = { rank = 7,  avg_heal =  901, mana_cost = 340, cast_time = 3.0 },  -- Rank 7
    [6778]  = { rank = 6,  avg_heal =  633, mana_cost = 255, cast_time = 3.0 },  -- Rank 6
    [5189]  = { rank = 5,  avg_heal =  507, mana_cost = 210, cast_time = 3.0 },  -- Rank 5
    [5188]  = { rank = 4,  avg_heal =  360, mana_cost = 170, cast_time = 2.5 },  -- Rank 4
    [5187]  = { rank = 3,  avg_heal =  229, mana_cost = 110, cast_time = 2.5 },  -- Rank 3
    [5186]  = { rank = 2,  avg_heal =  109, mana_cost =  55, cast_time = 2.0 },  -- Rank 2
    [5185]  = { rank = 1,  avg_heal =   44, mana_cost =  25, cast_time = 1.5 },  -- Rank 1
}

-- Regrowth: 10 ranks (R1-R10)
-- Note: Regrowth has both direct heal + HoT component
spells.REGROWTH_DATA = {
    [26980] = { rank = 10, direct_avg = 1538, hot_total = 1060, mana_cost = 675, cast_time = 2.0 },  -- Rank 10
    [9858]  = { rank = 9,  direct_avg = 1285, hot_total =  888, mana_cost = 580, cast_time = 2.0 },  -- Rank 9
    [9857]  = { rank = 8,  direct_avg = 1061, hot_total =  756, mana_cost = 485, cast_time = 2.0 },  -- Rank 8
    [9856]  = { rank = 7,  direct_avg =  907, hot_total =  644, mana_cost = 420, cast_time = 2.0 },  -- Rank 7
    [9750]  = { rank = 6,  direct_avg =  732, hot_total =  548, mana_cost = 350, cast_time = 2.0 },  -- Rank 6
    [8941]  = { rank = 5,  direct_avg =  566, hot_total =  400, mana_cost = 280, cast_time = 2.0 },  -- Rank 5
    [8940]  = { rank = 4,  direct_avg =  460, hot_total =  316, mana_cost = 235, cast_time = 2.0 },  -- Rank 4
    [8939]  = { rank = 3,  direct_avg =  347, hot_total =  244, mana_cost = 185, cast_time = 2.0 },  -- Rank 3
    [8938]  = { rank = 2,  direct_avg =  256, hot_total =  200, mana_cost = 145, cast_time = 2.0 },  -- Rank 2
    [8936]  = { rank = 1,  direct_avg =  100, hot_total =  116, mana_cost =  65, cast_time = 2.0 },  -- Rank 1
}

-- Helper function: Get total effective heal (direct + portion of HoT)
-- For Regrowth, we count HoT at 50% value since it ticks over time
function spells.get_regrowth_effective_heal(spell_id)
    local data = spells.REGROWTH_DATA[spell_id]
    if not data then return 0 end
    return data.direct_avg + (data.hot_total * 0.5)
end

-- Helper function: Calculate heal efficiency (heal per mana)
function spells.get_heal_efficiency(spell_id, spell_type)
    if spell_type == "healing_touch" then
        local data = spells.HEALING_TOUCH_DATA[spell_id]
        if not data or data.mana_cost == 0 then return 0 end
        return data.avg_heal / data.mana_cost
    elseif spell_type == "regrowth" then
        local data = spells.REGROWTH_DATA[spell_id]
        if not data or data.mana_cost == 0 then return 0 end
        return spells.get_regrowth_effective_heal(spell_id) / data.mana_cost
    end
    return 0
end

return spells
