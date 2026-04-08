-- spells.lua  |  EAX Druid Balance  |  TBC
local spells = {}

-- -- Balance DPS spells --------------------------------------------------------
spells.STARFIRE = { 26986, 25298, 22897, 22896, 22895, 2912 }
spells.WRATH = { 26985, 25298, 22897, 22896, 22895, 5176 }
spells.MOONFIRE = { 26988, 26987, 25299, 22827, 22826, 22825, 8921 }
spells.INSECT_SWARM = { 26980, 24977, 24976, 24975, 5570 }
spells.HURRICANE = { 27012, 17401, 17400, 17399, 16914 }
spells.FAERIE_FIRE = { 26993, 9907, 9749, 778, 770 }

-- -- PvP Spells ------------------------------------------------------------------
spells.ENTANGLING_ROOTS = { 26989, 26988, 19972, 19971, 19970, 19969, 19968, 339 }
spells.HIBERNATE = { 18658, 18657, 2637 }
spells.CYCLONE = { 33786 }

-- -- Cooldowns -----------------------------------------------------------------
spells.FORCE_OF_NATURE = { 33831 }
spells.INNERVATE = { 29166 }
spells.BARKSKIN = { 22812 }

-- -- Self-Buff Spells ----------------------------------------------------------
spells.THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Ranked Thorns
spells.MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- Ranked MOTW

-- -- Forms -------------------------------------------------------------------
spells.MOONKIN_FORM = { 24880 }
spells.CASTER_FORM = { 0 }

-- -- Buffs -------------------------------------------------------------------
spells.BUFF_MOONKIN_FORM = { 24880 }
spells.BUFF_CLEARCASTING = { 16870 }
spells.BUFF_NATURES_GRACE = { 16886 }
spells.BUFF_THORNS = { 26992, 9910, 9756, 8914, 1075, 782, 467 }  -- Thorns buff IDs
spells.BUFF_MARK_OF_THE_WILD = { 26990, 21849, 21850, 1126, 5232, 5234, 8907, 10937, 10938, 25460, 26991 }  -- MOTW buff IDs

-- -- Debuffs -----------------------------------------------------------------
spells.DEBUFF_MOONFIRE = { 26988, 26987, 25299, 22827, 8921 }
spells.DEBUFF_INSECT_SWARM = { 26980, 24977, 5570 }
spells.DEBUFF_FAERIE_FIRE = { 26993, 9907, 770 }

return spells
