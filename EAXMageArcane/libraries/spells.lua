-- Eax Mage Arcane  spells.lua
-- TBC Arcane Mage spell definitions

local spells = {}

-- Core Arcane Spells
spells.ARCANE_BLAST = { 33938, 30451 }  -- Rank 1-2 for TBC
spells.ARCANE_MISSILES = { 27075, 25345, 10212, 10211, 8417, 8416, 5145, 5144, 5143 }
spells.ARCANE_POWER = { 12042 }
spells.ARCANE_EXPLOSION = { 27080, 10263, 10262, 10261, 10260, 10259, 8439, 8438, 8437, 1449 }
spells.ARCANE_INTELLECT = { 27126, 10157, 10156, 1461, 1460, 1459 }
spells.ARCANE_BRILLIANCE = { 27127, 23028 }

-- Filler Spells
spells.FROSTBOLT = { 27071, 27070, 25304, 10181, 10180, 10179, 7322, 837, 205, 116 }
spells.FIREBALL = { 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 145, 143, 133 }
spells.SCORCH = { 27074, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }

-- Utility Spells
spells.FIRE_BLAST = { 27079, 10199, 10198, 10197, 8413, 8412, 2138, 2137, 2136 }
spells.ICE_LANCE = { 30455 }  -- TBC only
spells.CONE_OF_COLD = { 27087, 10161, 10160, 10159, 8492, 120 }
spells.COUNTERSPELL = { 2139 }
spells.REMOVE_CURSE = { 30449, 475 }
spells.EVOCATION = { 12051 }
spells.POLYMORPH = { 12826, 12825, 12824, 118 }

-- Defensive Spells
spells.ICE_BLOCK = { 45438 }
spells.ICE_BARRIER = { 33405, 13033, 13032, 13031, 11426 }
spells.MANA_SHIELD = { 10193, 10192, 10191, 8495, 8494, 1463 }
spells.BLINK = { 1953 }
spells.FROST_NOVA = { 27088, 10230, 6131, 865, 122 }

-- Cooldowns
spells.PRESENCE_OF_MIND = { 12043 }
spells.ICY_VEINS = { 12472 }
spells.COLD_SNAP = { 11958 }

-- Armor Spells
spells.MAGE_ARMOR = { 27125, 22783, 22782, 6117 }
spells.ICE_ARMOR = { 27124, 10220, 10219, 7320, 7302, 7300, 168 }
spells.MOLTEN_ARMOR = { 30482 }  -- TBC only

-- Buff IDs
spells.BUFF_ARCANE_BLAST = { 36032 }  -- Self-debuff, stacks to 3
spells.BUFF_ARCANE_POWER = { 12042 }
spells.BUFF_CLEARCASTING = { 12536 }
spells.BUFF_PRESENCE_OF_MIND = { 12043 }
spells.BUFF_ICY_VEINS = { 12472 }
spells.BUFF_ICE_BLOCK = { 45438 }
spells.BUFF_ARCANE_INTELLECT = { 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }
spells.BUFF_ICE_BARRIER = { 33405, 13033, 13032, 13031, 11426 }
spells.BUFF_MAGE_ARMOR = { 27125, 22783, 22782, 6117 }

-- Debuff IDs
spells.DEBUFF_ARCANE_BLAST = { 36032 }  -- Self-debuff from AB casts

-- Racials
spells.BERSERKING = { 26297 }
spells.ARCANE_TORRENT = { 28730, 25046 }
spells.BUFF_BERSERKING = { 26297 }

-- Consumables
spells.MANA_GEM_ITEMS = { 22044, 8008, 8007, 5514, 5513 }  -- Emerald, Ruby, Citrine, Jade, Agate
spells.HASTE_POTION = { 28508 }
spells.SUPER_MANA_POTION = { 28499, 22832 }
spells.DARK_RUNE = { 20520 }
spells.DEMONIC_RUNE = { 12662 }

-- Pacify debuffs (prevent casting)
spells.PACIFY_BUFFS = { 32904, 6465 }

return spells
