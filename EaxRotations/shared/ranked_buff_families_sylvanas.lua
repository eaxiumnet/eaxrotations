-- ranked_buff_families_sylvanas.lua — Single source of truth for ranked class self-buffs.
-- WHAT:  cast + detect ladders for MotW/AI/Fort/Thorns/shouts/armor/shields across Vanilla, TBC, WotLK.
-- WHEN:  required by ooc_manager, buff_upgrade, class middleware, leveling buff tables.
-- WHY:  prevent divergent ID lists and superior→inferior recast loops (GotW/MotW, AB/AI, PoF/Fort).
-- SAFETY: pure data + accessors; no on_update; nil-safe require.
-- DECISION: super-set ladders (Vanilla∪TBC∪WotLK). Unknown ranks fail is_spell_learned.
-- SOURCES (verified Jul 2026): lexxer.org ?game=tbc|wotlk|classic; wowhead /tbc|/wotlk|/classic;
--   local DBC 2.5.5 spell index for TBC cast ranks.
--
-- Convention:
--   cast   = high→low player-castable ranks for the single-target (or preferred) spell.
--   detect = best-first family: superior group buffs FIRST, then cast ranks, then proven aliases.
--   buff_would_downgrade(unit, detect, cast_spell) blocks inferior overwrites.

local M = {}

local function copy_array(src)
    local t = {}
    if type(src) ~= "table" then return t end
    for i = 1, #src do t[i] = src[i] end
    return t
end

-- n-table form for NS.buff_remains consumers that expect .n
local function as_n_table(ids)
    local t = { n = #ids }
    for i = 1, #ids do t[i] = ids[i] end
    return t
end

---------------------------------------------------------------------------
-- Families (super-set ladders)
---------------------------------------------------------------------------

-- MotW cast high→low. WotLK 48469 (lexxer wotlk), TBC 26990 (lexxer tbc).
local MOTW_CAST = {
    48469, -- WotLK r9 lvl 80
    26990, -- TBC r8 lvl 70
    9885, 9884, 8907, 5234, 6756, 5232, 1126,
}
-- GotW first (superior), then MotW. Detect aliases only if seen as player auras.
local MOTW_DETECT = {
    48470, -- WotLK GotW (lexxer wotlk)
    26991, 21850, 21849, -- GotW TBC/Vanilla
    48469, 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126,
    24752, 39233, 16878, -- client/talent MotW aura aliases (detect-only)
}

local THORNS_CAST = {
    53307, -- WotLK (lexxer wotlk lvl 74)
    26992, 9910, 9756, 8914, 1075, 782, 467,
}
local THORNS_DETECT = copy_array(THORNS_CAST)

-- AI cast. WotLK 42995 (lexxer wotlk).
local AI_CAST = {
    42995, -- WotLK
    27126, 10157, 10156, 1461, 1460, 1459,
}
-- AB superior. WotLK 43002 (lexxer wotlk).
local AI_DETECT = {
    43002, 27127, 23028, -- Arcane Brilliance
    42995, 27126, 10157, 10156, 1461, 1460, 1459,
}

local FORT_CAST = {
    48161, -- WotLK (lexxer wotlk)
    25389, 10938, 10937, 2791, 1245, 1244, 1243,
}
local FORT_DETECT = {
    48162, 25392, 21564, 21562, 39231, -- Prayer of Fortitude (+ alias)
    48161, 25389, 10938, 10937, 2791, 1245, 1244, 1243,
}

local INNER_FIRE_CAST = {
    48168, -- WotLK (lexxer wotlk)
    25431, 10952, 10951, 1006, 602, 7128, 588,
}
local INNER_FIRE_DETECT = copy_array(INNER_FIRE_CAST)

-- Battle Shout: levels high→low (WotLK 47436, TBC 2048@69, 25289@60, …)
local BATTLE_SHOUT_CAST = {
    47436, -- WotLK (lexxer wotlk)
    2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673,
}
local BATTLE_SHOUT_DETECT = copy_array(BATTLE_SHOUT_CAST)

local COMMANDING_SHOUT_CAST = {
    47440, -- WotLK (lexxer wotlk)
    469,   -- TBC
}
local COMMANDING_SHOUT_DETECT = copy_array(COMMANDING_SHOUT_CAST)

local HAWK_CAST = {
    27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165,
}
local HAWK_DETECT = copy_array(HAWK_CAST)

-- Mage armor cast preference: Mage Armor ranks then Frost/Ice (Molten separate opt).
local MAGE_ARMOR_CAST = {
    43024, -- WotLK Mage Armor (lexxer wotlk)
    27125, 22783, 22782, 6117,
    27124, 10220, 10219, 7320, 7302, 7301, 7300, 168,
}
local MAGE_ARMOR_DETECT = {
    43024, 27125, 22783, 22782, 6117,
    27124, 10220, 10219, 7320, 7302, 7301, 7300, 168,
    43046, 30482, -- Molten Armor WotLK + TBC
}

local FEL_ARMOR_CAST = {
    47893, -- WotLK (lexxer wotlk)
    28189, 28176,
}
local DEMON_ARMOR_CAST = {
    47889, -- WotLK (lexxer wotlk)
    27260, 11735, 11734, 11733, 1086, 706, 687, 696,
}
-- Fel first (preferred), then Demon.
local WARLOCK_ARMOR_DETECT = {
    47893, 28189, 28176,
    47889, 27260, 11735, 11734, 11733, 1086, 706, 687, 696,
}

local WATER_SHIELD_CAST = {
    57960, -- WotLK (lexxer wotlk)
    33736, 24398, 23575,
}
local LIGHTNING_SHIELD_CAST = {
    49280, -- WotLK (lexxer wotlk)
    25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324,
}
-- Water preferred before Lightning for exclusive shield family.
local SHAMAN_SHIELD_DETECT = {
    57960, 33736, 24398, 23575,
    49280, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324,
}

local RIGHTEOUS_FURY = { 25780 }

-- Paladin Kings: Greater first
local BLESSING_KINGS_DETECT = {
    25898, -- Greater Blessing of Kings
    20217, -- Blessing of Kings
}

M.FAMILIES = {
    mark_of_the_wild = {
        key = "mark_of_the_wild",
        label = "Mark of the Wild",
        cast = MOTW_CAST,
        detect = MOTW_DETECT,
    },
    thorns = {
        key = "thorns",
        label = "Thorns",
        cast = THORNS_CAST,
        detect = THORNS_DETECT,
    },
    arcane_intellect = {
        key = "arcane_intellect",
        label = "Arcane Intellect",
        cast = AI_CAST,
        detect = AI_DETECT,
    },
    power_word_fortitude = {
        key = "power_word_fortitude",
        label = "Power Word: Fortitude",
        cast = FORT_CAST,
        detect = FORT_DETECT,
    },
    inner_fire = {
        key = "inner_fire",
        label = "Inner Fire",
        cast = INNER_FIRE_CAST,
        detect = INNER_FIRE_DETECT,
    },
    battle_shout = {
        key = "battle_shout",
        label = "Battle Shout",
        cast = BATTLE_SHOUT_CAST,
        detect = BATTLE_SHOUT_DETECT,
    },
    commanding_shout = {
        key = "commanding_shout",
        label = "Commanding Shout",
        cast = COMMANDING_SHOUT_CAST,
        detect = COMMANDING_SHOUT_DETECT,
    },
    aspect_hawk = {
        key = "aspect_hawk",
        label = "Aspect of the Hawk",
        cast = HAWK_CAST,
        detect = HAWK_DETECT,
    },
    mage_armor = {
        key = "mage_armor",
        label = "Mage Armor",
        cast = MAGE_ARMOR_CAST,
        detect = MAGE_ARMOR_DETECT,
    },
    fel_armor = {
        key = "fel_armor",
        label = "Fel Armor",
        cast = FEL_ARMOR_CAST,
        detect = WARLOCK_ARMOR_DETECT,
    },
    demon_armor = {
        key = "demon_armor",
        label = "Demon Armor",
        cast = DEMON_ARMOR_CAST,
        detect = WARLOCK_ARMOR_DETECT,
    },
    water_shield = {
        key = "water_shield",
        label = "Water Shield",
        cast = WATER_SHIELD_CAST,
        detect = SHAMAN_SHIELD_DETECT,
    },
    lightning_shield = {
        key = "lightning_shield",
        label = "Lightning Shield",
        cast = LIGHTNING_SHIELD_CAST,
        detect = SHAMAN_SHIELD_DETECT,
    },
    righteous_fury = {
        key = "righteous_fury",
        label = "Righteous Fury",
        cast = RIGHTEOUS_FURY,
        detect = RIGHTEOUS_FURY,
    },
    blessing_kings = {
        key = "blessing_kings",
        label = "Blessing of Kings",
        cast = { 20217 },
        detect = BLESSING_KINGS_DETECT,
    },
}

function M.cast(key)
    local f = M.FAMILIES[key]
    return f and copy_array(f.cast) or {}
end

function M.detect(key)
    local f = M.FAMILIES[key]
    return f and copy_array(f.detect) or {}
end

function M.detect_n(key)
    return as_n_table(M.detect(key))
end

function M.cast_n(key)
    return as_n_table(M.cast(key))
end

function M.label(key)
    local f = M.FAMILIES[key]
    return f and f.label or key
end

--- Returns raw family table (cast/detect arrays — do not mutate).
function M.get(key)
    return M.FAMILIES[key]
end

-- Install on NS for convenience when EaxRotations is loaded.
local NS = _G.EaxRotations
if NS then
    NS.RankedBuffFamilies = M
end

return M
