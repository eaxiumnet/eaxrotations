-- Eax Rogue Combat  spells.lua
-- TBC spell IDs for Combat Rogue (swords, Blade Flurry)

local spells = {}

-- Combo Point Builders
spells.SINISTER_STRIKE = { 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 } -- Primary builder
spells.BACKSTAB = { 26863, 25300, 11281, 11280, 8721, 8620, 2591, 2590, 2589, 53 } -- Dagger builds
spells.SHIV = { 5938 } -- Offhand attack, applies poison
spells.GHOSTLY_STRIKE = { 14278, 14279, 14280, 14281, 14282, 14283, 14284, 14285 } -- Subtlety but used in combat

-- Finishers
spells.SLICE_AND_DICE = { 6774, 5171 } -- Primary buff, maintain at all times
spells.RUPTURE = { 26867, 26864, 11275, 11274, 11273, 8643, 8639, 1943 } -- DoT finisher
spells.EVISCERATE = { 26865, 26864, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 } -- Direct damage
spells.EXPOSE_ARMOR = { 26866, 11198, 11197, 8647, 7408, 7407, 6082, 2108, 1786 } -- Raid debuff
spells.KIDNEY_SHOT = { 8643, 408 } -- Stun finisher
spells.DEADLY_THROW = { 36677, 26679 } -- Ranged finisher

-- Poisons
spells.INSTANT_POISON = { 26890, 11341, 11340, 11339, 11338, 11337, 11336, 8681, 8679 }
spells.DEADLY_POISON = { 27282, 26967, 25347, 11357, 11356, 11355, 11354, 11353, 2818 }
spells.WOUND_POISON = { 22055, 22054, 13224, 13223, 13222, 13220, 13218 }
spells.CRIPPLING_POISON = { 3421, 3408 }
spells.MIND_NUMBING_POISON = { 5761, 8694, 8693, 8692, 8691, 8689, 8688, 8687, 8686, 8685, 8684, 5760 }

-- Combat-specific cooldowns
spells.BLADE_FLURRY = { 13877, 22435, 22436, 22437, 22438 } -- Cleave + attack speed
spells.ADRENALINE_RUSH = { 13750 } -- Energy regen boost
spells.RIPOSTE = { 14251 } -- Counter-attack after parry
spells.KILLING_SPREE = { 51690, 51689, 51688, 51687, 51686 } -- WotLK, not TBC

-- Buffs
spells.BUFF_SLICE_AND_DICE = { 6774, 5171 }
spells.BUFF_BLADE_FLURRY = { 13877, 22435, 22436, 22437, 22438 }
spells.BUFF_ADRENALINE_RUSH = { 13750 }
spells.BUFF_INSTANT_POISON = { 11336, 11337, 11338, 11339, 11340, 11341, 26890, 8681, 8679 }
spells.BUFF_DEADLY_POISON = { 2818, 11353, 11354, 11355, 11356, 11357, 25347, 26967, 27282 }
spells.BUFF_WOUND_POISON = { 13218, 13220, 13222, 13223, 13224, 22054, 22055 }

-- Debuffs
spells.DEBUFF_RUPTURE = { 1943, 8639, 8643, 11273, 11274, 11275, 26864, 26867 }
spells.DEBUFF_EXPOSE_ARMOR = { 8647, 7407, 7408, 11197, 11198, 26866 }
spells.DEBUFF_INSTANT_POISON = { 13218, 13220, 13222, 13223, 13224, 22054, 22055 }
spells.DEBUFF_DEADLY_POISON = { 2818, 11353, 11354, 11355, 11356, 11357, 25347, 26967, 27282 }
spells.DEBUFF_CHEAP_SHOT = { 1833 }
spells.DEBUFF_KIDNEY_SHOT = { 408, 8643 }
spells.DEBUFF_GOUGE = { 1776, 1777, 8629, 11285, 11286, 38764 }

-- Utility / CC
spells.CHEAP_SHOT = { 1833 }
spells.GOUGE = { 38764, 11286, 11285, 8629, 1777, 1776 }
spells.KICK = { 38768, 1769, 1768, 1767, 1766 }
spells.SPRINT = { 11305, 2983, 8696, 11304 }
spells.VANISH = { 26889, 1857, 1856 }
spells.EVASION = { 26669, 5277 }
spells.CLOAK_OF_SHADOWS = { 31224 }
spells.BLIND = { 2094, 21060 }
spells.SHADOWSTEP = { 36554 }
spells.PREPARATION = { 14185 }

-- Stealth
spells.STEALTH = { 1787, 1786, 1785, 1784 }
spells.BUFF_STEALTH = { 1787, 1786, 1785, 1784 }

-- Defensive
spells.FEINT = { 25302, 11303, 11302, 11301, 1966 }

-- Racial abilities
spells.BLOOD_FURY = { 20572 }
spells.BERSERKING = { 26297 }
spells.STONEFORM = { 20594 }
spells.ESCAPE_ARTIST = { 20589 }
spells.WILL_OF_THE_FORSAKEN = { 7744 }
spells.ARCANE_TORRENT = { 28730 }

return spells
