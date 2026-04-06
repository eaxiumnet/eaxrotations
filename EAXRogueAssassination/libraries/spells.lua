-- Eax Rogue Assassination  spells.lua
-- TBC spell IDs for Assassination Rogue (poisons, Mutilate)

local spells = {}

-- Combo Point Builders
spells.MUTILATE = { 34411, 34410, 34409, 34408, 1329 } -- Main Assassination builder
spells.SINISTER_STRIKE = { 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 } -- Fallback
spells.BACKSTAB = { 26863, 25300, 11281, 11280, 8721, 8620, 2591, 2590, 2589, 53 } -- Position-dependent
spells.SHADOWSTRIKE = { 36554 } -- Shadowstep + strike

-- Finishers
spells.SLICE_AND_DICE = { 6774, 5171 } -- Primary buff, maintain at all times
spells.RUPTURE = { 26867, 26864, 11275, 11274, 11273, 8643, 8639, 1943 } -- DoT finisher
spells.EVISCERATE = { 26865, 26864, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 } -- Direct damage
spells.EXPOSE_ARMOR = { 26866, 11198, 11197, 8647, 7408, 7407, 6082, 2108, 1786 } -- Raid debuff
spells.KIDNEY_SHOT = { 8643, 408 } -- Stun finisher
spells.DEADLY_THROW = { 36677, 26679 } -- Ranged finisher

-- Poisons (Assassination core)
spells.INSTANT_POISON = { 26890, 11341, 11340, 11339, 11338, 11337, 11336, 8681, 8679 } -- Weapon buff
spells.DEADLY_POISON = { 27282, 26967, 25347, 11357, 11356, 11355, 11354, 11353, 2818 } -- DoT poison
spells.WOUND_POISON = { 22055, 22054, 13224, 13223, 13222, 13220, 13218 } -- Healing reduction
spells.CRIPPLING_POISON = { 3421, 3408 } -- Slow poison
spells.MIND_NUMBING_POISON = { 5761, 8694, 8693, 8692, 8691, 8689, 8688, 8687, 8686, 8685, 8684, 5760 } -- Cast slow
spells.ANESTHETIC_POISON = { 26786 } -- WotLK only, not TBC

-- Buffs
spells.BUFF_SLICE_AND_DICE = { 6774, 5171 }
spells.BUFF_INSTANT_POISON = { 11336, 11337, 11338, 11339, 11340, 11341, 26890, 8681, 8679 }
spells.BUFF_DEADLY_POISON = { 2818, 11353, 11354, 11355, 11356, 11357, 25347, 26967, 27282 }
spells.BUFF_WOUND_POISON = { 13218, 13220, 13222, 13223, 13224, 22054, 22055 }
spells.BUFF_HUNGER_FOR_BLOOD = { 51662 } -- WotLK talent, not TBC

-- Debuffs
spells.DEBUFF_RUPTURE = { 1943, 8639, 8643, 11273, 11274, 11275, 26864, 26867 }
spells.DEBUFF_EXPOSE_ARMOR = { 8647, 7407, 7408, 11197, 11198, 26866 }
spells.DEBUFF_INSTANT_POISON = { 13218, 13220, 13222, 13223, 13224, 22054, 22055 }
spells.DEBUFF_DEADLY_POISON = { 2818, 11353, 11354, 11355, 11356, 11357, 25347, 26967, 27282 }
spells.DEBUFF_CHEAP_SHOT = { 1833 }
spells.DEBUFF_KIDNEY_SHOT = { 408, 8643 }
spells.DEBUFF_GOUGE = { 1776, 1777, 8629, 11285, 11286, 38764 }

-- Utility / CC
spells.CHEAP_SHOT = { 1833 } -- Stealth opener stun
spells.GOUGE = { 38764, 11286, 11285, 8629, 1777, 1776 } -- Incapacitate
spells.KICK = { 38768, 1769, 1768, 1767, 1766 } -- Interrupt
spells.SPRINT = { 11305, 2983, 8696, 11304 } -- Speed boost
spells.VANISH = { 26889, 1857, 1856 } -- Stealth reset
spells.EVASION = { 26669, 5277 } -- Dodge buff
spells.CLOAK_OF_SHADOWS = { 31224 } -- Spell immunity (TBC)
spells.BLIND = { 2094, 21060 } -- CC
spells.SHADOWSTEP = { 36554 } -- Teleport behind target
spells.PREPARATION = { 14185 } -- Reset cooldowns
spells.COLD_BLOOD = { 14177 } -- Guaranteed crit

-- Stealth
spells.STEALTH = { 1787, 1786, 1785, 1784 } -- Stealth ability
spells.BUFF_STEALTH = { 1787, 1786, 1785, 1784 }

-- Defensive
spells.FEINT = { 25302, 11303, 11302, 11301, 1966 } -- AoE damage reduction

-- Racial abilities (may be available)
spells.BLOOD_FURY = { 20572 } -- Orc racial
spells.BERSERKING = { 26297 } -- Troll racial
spells.STONEFORM = { 20594 } -- Dwarf racial
spells.ESCAPE_ARTIST = { 20589 } -- Gnome racial
spells.WILL_OF_THE_FORSAKEN = { 7744 } -- Undead racial
spells.ARCANE_TORRENT = { 28730 } -- Blood Elf racial

return spells
