-- Eax Priest Holy | spells.lua
-- Spell ID tables ordered highest-to-lowest for each Holy spell referenced by the rotation.

local spells = {}

spells.RENEW = { 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }
spells.GREATER_HEAL = { 25213, 25210, 25314, 10965, 10964, 10963, 2060 }
spells.PRAYER_OF_HEALING = { 25316, 25308, 10961, 10960, 996, 596 }
spells.FLASH_HEAL = { 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }
spells.PRAYER_OF_MENDING = { 33076 }
spells.CIRCLE_OF_HEALING = { 34866, 34865, 34864, 34863, 34862, 34861 }
spells.PRAYER_OF_FORTITUDE = { 21562, 21564, 25392 }

-- Flux: Power Word Shield for emergency healing (from Discipline)
spells.POWER_WORD_SHIELD = { 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }
spells.BUFF_POWER_WORD_SHIELD = spells.POWER_WORD_SHIELD
spells.BUFF_WEAKENED_SOUL = { 6788 }  -- Debuff applied after PW:S

spells.HOLY_NOVA = { 15237, 15239, 11687, 11686, 11685, 7285, 7284, 7283 }
spells.BINDING_HEAL = { 10797, 10796 }

-- TBC Holy talent: Lightwell (clickable heal object)
spells.LIGHTWELL = { 724, 27870, 27871, 28275 }

spells.HOLY_FIRE = { 25386, 25384, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }
spells.SMITE = { 25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585 }

spells.INNER_FIRE = { 25431, 25430, 10952, 10951, 1006, 602, 7128, 588 }
spells.INNER_FOCUS = { 14751 }

spells.DISPEL_MAGIC = { 988, 527 }
spells.CURE_DISEASE = { 528, 2870, 1922 }
spells.ABOLISH_DISEASE = { 552, 1924, 1923 }
spells.SHADOWFIEND = { 34433 }
spells.MASS_DISPEL = { 32375 }

spells.BUFF_RENEW = spells.RENEW
spells.BUFF_PRAYER_OF_MENDING = spells.PRAYER_OF_MENDING
spells.BUFF_INNER_FIRE = { 588, 7128, 602, 1006, 10951, 10952, 25430, 25431 }
spells.BUFF_SURGE_OF_LIGHT = { 33152, 33151, 33150 }  -- Surge of Light proc (free Smite)
spells.BUFF_CLEARCASTING = { 12536 }  -- Holy Concentration proc (free heal) - TBC only

spells.BERSERKING = { 26297 }
spells.SHADOWMELD = { 1784 }
spells.ARCANE_TORRENT = { 28730, 25046, 23160, 15533 }

spells.BUFF_BERSERKING = { 26297 }
spells.BUFF_SHADOWMELD = { 1784 }

spells.HASTE_POTION = { 28508, 22832 }
spells.SUPER_MANA_POTION = { 28499, 22828 }
spells.SCROLL_OF_INTELLECT = { 22732, 10291 }
spells.SCROLL_OF_STAMINA = { 22733, 10292 }


spells.RESURRECTION     = { 27185, 10881, 2006, 2010 }

spells.POWER_WORD_FORTITUDE   = { 25389, 10938, 10937, 10936, 2791, 1245, 1244, 1243, 1242, 1241, 1240 }
spells.DIVINE_SPIRIT           = { 27841, 14819, 14818, 14817, 14752 }
spells.BUFF_POWER_WORD_FORT    = { 25389, 10938, 10937, 10936, 2791, 1245, 1244, 1243, 1242, 1241, 1240 }
spells.BUFF_DIVINE_SPIRIT      = { 27841, 14819, 14818, 14817, 14752 }
spells.SHADOW_PROTECTION       = { 27683, 10958, 10957, 976 }
spells.BUFF_SHADOW_PROTECTION  = { 27683, 10958, 10957, 976 }

-- Pacify debuffs that prevent casting (e.g., Mechanar's Pacifying Dust)
spells.PACIFY_BUFFS = { 32904, 6465 }

return spells
