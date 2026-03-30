-- Eax Druid Feral | spells.lua
-- Rank tables and buff/debuff ID tables only.

local spells = {}

spells.CAT_FORM = { 768 }
spells.BEAR_FORM = { 9634, 5487 }
spells.DIRE_BEAR_FORM = { 9635, 9634, 5487 }
spells.MOONKIN_FORM = { 24858 }
spells.AQUATIC_FORM = { 1066 }
spells.FAERIE_FIRE_FERAL = { 27011, 17392, 17391, 17390, 16857 }

spells.MANGLE_CAT = { 33982, 33983, 33876 }
spells.RAKE = { 27003, 1822 }
spells.SHRED = { 5221, 8992, 8993, 27001, 27002 }
spells.RIP = { 27008, 1079 }
spells.FEROCIOUS_BITE = { 24248, 22829, 22828, 22568 }
spells.TIGERS_FURY = { 9846, 9845, 6793, 5217 }

spells.MANGLE_BEAR = { 33987, 33986, 33878 }
spells.MAUL = { 26996, 9881, 9880, 6807 }
spells.SWIPE = { 26997, 9908, 779 }
spells.GROWL = { 6795 }
spells.FRENZIED_REGENERATION = { 22842 }

spells.DEMORALIZING_ROAR = { 99, 1738, 9490, 9491, 9745, 9746, 10756, 25275 }
spells.FAERIE_FIRE = { 26993, 9907, 9749, 778, 770 }

spells.HEALING_TOUCH = { 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }
spells.REJUVENATION = { 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
spells.REGROWTH = { 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
spells.MARK_OF_THE_WILD = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }

spells.BUFF_CAT_FORM = { 768 }
spells.BUFF_BEAR_FORM = { 5487, 9634, 9635 }
spells.BUFF_DIRE_BEAR_FORM = { 9635, 9634, 5487 }
spells.BUFF_MOONKIN_FORM = { 24858 }
spells.BUFF_TIGERS_FURY = { 5217, 6793, 9845, 9846 }
spells.BUFF_FRENZIED_REGENERATION = { 22842 }

spells.DEBUFF_FAERIE_FIRE = { 770, 778, 16857, 17390, 17391, 17392, 26993, 27011 }
spells.DEBUFF_RAKE = { 1822, 27003 }
spells.DEBUFF_RIP = { 1079, 27008 }
spells.DEBUFF_MANGLE = { 33876, 33983, 33878, 33986, 33987 }
-- Trauma (Arms warrior) provides the same bleed-amplification effect as Mangle.
-- If Trauma is already on the target, our Mangle is redundant.
spells.DEBUFF_DEMORALIZING_ROAR = { 99, 1738, 9490, 9491, 9745, 9746, 10756, 25275 }

spells.BERSERKING = { 26297 }
spells.SHADOWMELD = { 1784 }
spells.WAR_STOMP = { 20549 }

spells.BUFF_BERSERKING = { 26297 }
spells.BUFF_SHADOWMELD = { 1784 }

spells.HASTE_POTION = { 28508, 22832 }
spells.SUPER_MANA_POTION = { 28499, 22828 }
spells.SCROLL_OF_AGILITY = { 22730, 10290 }
spells.SCROLL_OF_STAMINA = { 22733, 10292 }


spells.MAIM              = { 22570 }
spells.DEBUFF_MAIM       = { 22570 }

spells.LACERATE          = { 33745 }
spells.DEBUFF_LACERATE   = { 33745 }

spells.REBIRTH           = { 26994, 20748, 20910, 20909, 20484 }

spells.REMOVE_CURSE = { 2782, 8690, 8691 }


-- Missing spells added in v2.1.0
spells.PROWL               = { 9913, 5215 }
spells.POUNCE              = { 27006, 9005, 9004, 8998 }
spells.BASH                = { 8983, 6798, 5211 }
spells.DASH                = { 9821, 1850 }
spells.FERAL_CHARGE_BEAR   = { 16979, 19675 }
spells.RAVAGE              = { 9867, 9866, 6785, 3242 }
spells.ABOLISH_POISON      = { 2893 }
spells.NATURES_GRASP       = { 17329, 16813, 16812, 16811, 16810, 16689 }

-- Defensive / utility
spells.BARKSKIN            = { 22812 }
spells.ENRAGE              = { 5229 }
spells.CHALLENGING_ROAR    = { 5209 }
spells.BUFF_ENRAGE         = { 5229 }
spells.INNERVATE           = { 29166, 29166 }
spells.CLAW                = { 27000, 9850, 9849, 1082 }
spells.COWER               = { 27004, 9892, 8998, 8997 }

spells.BUFF_BARKSKIN       = { 22812 }
spells.BUFF_PROWL          = { 9913, 5215 }
spells.BUFF_DASH           = { 9821, 1850 }
spells.BUFF_TRAVEL_FORM    = { 783 }
spells.DEBUFF_POUNCE       = { 27006, 9005, 9004, 8998 }
spells.DEBUFF_BASH         = { 8983, 5211 }

-- Buffs
spells.BUFF_MARK_OF_THE_WILD   = { 1126, 5232, 5234, 6756, 8907, 9884, 9885, 26990 }
spells.BUFF_LEADER_OF_THE_PACK = { 17007 }
-- Omen of Clarity - Clearcasting proc, next builder/finisher costs 0 energy
spells.BUFF_CLEARCASTING = { 16864 }

-- CC
spells.CYCLONE          = { 33786 }
spells.ENTANGLING_ROOTS = { 26989, 19970, 19971, 19972, 19973, 19974, 1062, 339 }
spells.HIBERNATE        = { 18658, 18657, 2637 }

-- Debuffs
spells.DEBUFF_CYCLONE          = { 33786 }
spells.DEBUFF_ENTANGLING_ROOTS = { 26989, 19970, 19971, 19972, 19973, 19974, 1062, 339 }

return spells
