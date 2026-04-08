-- spells.lua  |  EAX Druid Resto  |  TBC
local spells = {}

-- -- Healing spells ----------------------------------------------------------
spells.REJUVENATION = { 26981, 26980, 25299, 22850, 22849, 22848, 1430 }
spells.REGROWTH = { 26980, 25299, 22850, 22849, 22848, 8936 }
spells.LIFEBLOOM = { 33763 }
spells.SWIFTMEND = { 18562 }
spells.HEALING_TOUCH = { 26979, 25297, 22848, 22847, 22846, 5185 }
spells.TRANQUILITY = { 26983, 9863, 9862, 740 }

-- -- Utility spells ------------------------------------------------------------
spells.NATURES_SWIFTNESS = { 17116 }
spells.INNERVATE = { 29166 }
spells.REBIRTH = { 26994, 20748, 20747, 20742, 20484 }
spells.REMOVE_CURSE = { 2782 }
spells.ABOLISH_POISON = { 2893 }
spells.BARKSKIN = { 22812 }
spells.THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Ranked Thorns
spells.MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- Ranked MOTW

-- -- Forms -------------------------------------------------------------------
spells.TREE_OF_LIFE_FORM = { 33891 }
spells.CASTER_FORM = { 0 }

-- -- Buffs -------------------------------------------------------------------
spells.BUFF_TREE_OF_LIFE_FORM = { 33891 }
spells.BUFF_REJUVENATION = { 26981, 26980, 25299, 1430 }
spells.BUFF_REGROWTH = { 26980, 25299, 8936 }
spells.BUFF_LIFEBLOOM = { 33763 }
spells.BUFF_NATURES_SWIFTNESS = { 17116 }
spells.BUFF_ABOLISH_POISON = { 2893 }
spells.BUFF_THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Thorns buff IDs
spells.BUFF_MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- MOTW buff IDs

-- -- Debuffs -----------------------------------------------------------------
spells.DEBUFF_CYCLONE = { 33786 }
spells.DEBUFF_ENTANGLING_ROOTS = { 26989, 22812, 22811, 22810, 5196, 339 }

return spells
