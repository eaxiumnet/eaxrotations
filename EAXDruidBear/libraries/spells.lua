-- spells.lua  |  EAX Druid Bear (Tank)  |  TBC
local spells = {}

-- -- Bear Form spells (Tank) --------------------------------------------------
spells.MAUL = { 26996, 6809, 6808, 6807 }
spells.SWIPE = { 26997, 9908, 779 }
spells.LACERATE = { 33745 }
spells.MANGLE_BEAR = { 33987, 33986, 33878 }
spells.DEMORALIZING_ROAR = { 26998, 9898, 9896, 99 }
spells.FRENZIED_REGENERATION = { 22842, 22895, 22896 }
spells.GROWL = { 2649, 6795, 6794, 6793 }
spells.CHALLENGING_ROAR = { 5209 }
spells.BASH = { 5211, 6798, 8983 }
spells.FERAL_CHARGE = { 16979 }
spells.ENRAGE = { 5229 }

-- -- Forms -------------------------------------------------------------------
spells.BEAR_FORM = { 9634, 5487 }
spells.DIRE_BEAR_FORM = { 9634 }
spells.CASTER_FORM = { 0 }

-- -- Buffs -------------------------------------------------------------------
spells.BUFF_BEAR_FORM = { 5487 }
spells.BUFF_DIRE_BEAR_FORM = { 9634 }
spells.BUFF_FRENZIED_REGENERATION = { 22842 }
spells.BUFF_ENRAGE = { 5229 }
spells.BUFF_THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Thorns buff IDs
spells.BUFF_MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- MOTW buff IDs

-- -- Debuffs -----------------------------------------------------------------
spells.DEBUFF_LACERATE = { 33745 }
spells.DEBUFF_DEMORALIZING_ROAR = { 26998, 9898, 9896, 99 }
spells.DEBUFF_MANGLE = { 33987, 33986, 33878 }
spells.DEBUFF_FAERIE_FIRE = { 26993, 9907, 770 }

-- -- Utility spells ------------------------------------------------------------
spells.FAERIE_FIRE = { 26993, 9907, 770 }
spells.FAERIE_FIRE_FERAL = { 16857, 17390, 17391, 17392 }
spells.BARKSKIN = { 22812 }
spells.INNERVATE = { 29166 }
spells.THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Ranked Thorns
spells.MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- Ranked MOTW

-- -- PvP/CC spells -------------------------------------------------------------
spells.ENTANGLING_ROOTS = { 26989, 9853, 9852, 5196, 5195, 1062, 339 }
spells.HIBERNATE = { 18658, 18657, 2637 }
spells.CYCLONE = { 33786 }

return spells
