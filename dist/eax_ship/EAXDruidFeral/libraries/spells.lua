-- spells.lua  |  Eax Druid Feral  |  TBC
local spells = {}

-- -- Cat Form spells ---------------------------------------------------------
spells.SHRED = { 27001, 27000, 22568, 22557, 5221 }
spells.RAKE = { 27003, 1823, 1822 }
spells.RIP = { 27008, 1079 }
spells.FEROCIOUS_BITE = { 31018, 22568, 22557, 24248 }
spells.MANGLE_CAT = { 33983, 33982, 33876 }
spells.TIGERS_FURY = { 9846, 9845, 6793, 5217 }
spells.PROWL = { 9913, 6783, 5215 }
spells.RAVAGE = { 27005, 6787, 6785, 6784 }
spells.CAT_FORM = { 768 }

-- -- PvP / Utility spells ------------------------------------------------------
spells.ENTANGLING_ROOTS = { 26989, 9853, 9852, 5196, 5195, 1062, 339 }
spells.HIBERNATE = { 18658, 18657, 2637 }
spells.CYCLONE = { 33786 }
spells.BASH = { 5211, 6798, 8983 }
spells.MAIM = { 22570 }

-- -- Buff/Debuff spells ------------------------------------------------------
spells.FAERIE_FIRE = { 26993, 9907, 770 }
spells.FAERIE_FIRE_FERAL = { 16857, 17390, 17391, 17392 }

-- -- Bear Form spells --------------------------------------------------------
spells.MAUL = { 26996, 6809, 6808, 6807 }
spells.SWIPE = { 26997, 9908, 779 }
spells.LACERATE = { 33745 }
spells.MANGLE_BEAR = { 33987, 33986, 33878 }
spells.DEMORALIZING_ROAR = { 26998, 9898, 9896, 99 }
spells.FRENZIED_REGENERATION = { 22842, 22895, 22896 }
spells.GROWL = { 2649, 6795, 6794, 6793 }
spells.CHALLENGING_ROAR = { 5209 }
spells.BEAR_FORM = { 5487 }
spells.DIRE_BEAR_FORM = { 9634 }

-- -- Forms -------------------------------------------------------------------
spells.CAT_FORM = { 768 }
spells.BEAR_FORM = { 5487 }
spells.DIRE_BEAR_FORM = { 9634 }

-- -- Buffs -------------------------------------------------------------------
spells.BUFF_CAT_FORM = { 768 }
spells.BUFF_BEAR_FORM = { 5487 }
spells.BUFF_DIRE_BEAR_FORM = { 9634 }
spells.BUFF_TIGERS_FURY = { 9846, 9845, 6793, 5217 }
spells.BUFF_PROWL = { 9913, 6783, 5215 }
spells.BUFF_OMEN_OF_CLARITY = { 16864 }
spells.BUFF_MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- MOTW buff IDs
spells.BUFF_THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Thorns buff IDs

-- -- Self-Buff Spells ----------------------------------------------------------
spells.MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- Ranked MOTW
spells.THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Ranked Thorns

-- -- Debuffs -----------------------------------------------------------------
spells.DEBUFF_RAKE = { 27003, 1823, 1822 }
spells.DEBUFF_RIP = { 27008, 1079 }
spells.DEBUFF_MANGLE = { 33983, 33982, 33876, 33987, 33986, 33878 }
spells.DEBUFF_FAERIE_FIRE = { 26993, 9907, 770 }

-- -- Items -------------------------------------------------------------------
spells.WOLFSHEAD_HELM_ID = 8345

return spells
