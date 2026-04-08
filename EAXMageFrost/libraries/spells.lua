-- Eax Mage Frost  spells.lua
-- TBC Frost Mage spell definitions

local spells = {}

-- Core Frost Spells
spells.FROSTBOLT = { 27071, 27070, 25304, 10181, 10180, 10179, 7322, 837, 205, 116 }
spells.ICE_LANCE = { 30455 }
spells.CONE_OF_COLD = { 27087, 10161, 10160, 10159, 8492, 120 }
spells.BLIZZARD = { 27085, 10199, 10198, 10197, 10196, 10195, 10194, 10193, 10192, 10191, 10 }

-- Frost AoE
spells.ARCANE_EXPLOSION = { 27080, 10263, 10262, 10261, 10260, 10259, 8439, 8438, 8437, 1449 }
spells.FROST_NOVA = { 27088, 10230, 6131, 865, 122 }

-- Utility Spells
spells.FIRE_BLAST = { 27079, 10199, 10198, 10197, 8413, 8412, 2138, 2137, 2136 }
spells.COUNTERSPELL = { 2139 }
spells.REMOVE_CURSE = { 30449, 475 }
spells.EVOCATION = { 12051 }
spells.POLYMORPH = { 12826, 12825, 12824, 118 }

-- Defensive Spells
spells.ICE_BLOCK = { 45438 }
spells.ICE_BARRIER = { 33405, 13033, 13032, 13031, 11426 }
spells.MANA_SHIELD = { 10193, 10192, 10191, 8495, 8494, 1463 }
spells.BLINK = { 1953 }

-- Cooldowns
spells.ICY_VEINS = { 12472 }
spells.COLD_SNAP = { 11958 }
spells.SUMMON_WATER_ELEMENTAL = { 31687 }

-- Armor Spells
spells.MAGE_ARMOR = { 27125, 22783, 22782, 6117 }
spells.ICE_ARMOR = { 27124, 10220, 10219, 7320, 7302, 7300, 168 }
spells.MOLTEN_ARMOR = { 30482 }

-- Buff IDs
spells.BUFF_ICY_VEINS = { 12472 }
spells.BUFF_ICE_BLOCK = { 45438 }
spells.BUFF_CLEARCASTING = { 12536 }
spells.BUFF_ICE_BARRIER = { 33405, 13033, 13032, 13031, 11426 }
spells.BUFF_ICE_ARMOR = { 27124, 10220, 10219, 7320, 7302, 7300, 168 }
spells.BUFF_ARCANE_INTELLECT = { 27126, 10157, 10156, 10154, 1461, 1460, 1459 }

-- Debuff IDs
spells.DEBUFF_WINTERS_CHILL = { 12579 }  -- Winter's Chill, stacks to 5

-- Racials
spells.BERSERKING = { 26297 }
spells.ARCANE_TORRENT = { 28730, 25046 }
spells.BUFF_BERSERKING = { 26297 }

-- Consumables
spells.MANA_GEM_ITEMS = { 22044, 8008, 8007, 5514, 5513 }
spells.HASTE_POTION = { 28508 }
spells.SUPER_MANA_POTION = { 28499, 22832 }
spells.DARK_RUNE = { 20520 }
spells.DEMONIC_RUNE = { 12662 }

-- Pacify debuffs
spells.PACIFY_BUFFS = { 32904, 6465 }

return spells
