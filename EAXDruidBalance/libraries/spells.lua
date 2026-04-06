-- spells.lua  |  EAX Port)  |  TBC
local spells = {}

-- -- Balance DPS spells --------------------------------------------------------
spells.STARFIRE = { 26986, 25298, 22897, 22896, 22895, 2912 }
spells.WRATH = { 26985, 25298, 22897, 22896, 22895, 5176 }
spells.MOONFIRE = { 26988, 26987, 25299, 22827, 22826, 22825, 8921 }
spells.INSECT_SWARM = { 26980, 24977, 24976, 24975, 5570 }
spells.HURRICANE = { 27012, 17401, 17400, 17399, 16914 }
spells.FAERIE_FIRE = { 26993, 9907, 9749, 778, 770 }

-- -- Cooldowns -----------------------------------------------------------------
spells.FORCE_OF_NATURE = { 33831 }
spells.INNERVATE = { 29166 }
spells.BARKSKIN = { 22812 }

-- -- Forms -------------------------------------------------------------------
spells.MOONKIN_FORM = { 24880 }
spells.CASTER_FORM = { 0 }

-- -- Buffs -------------------------------------------------------------------
spells.BUFF_MOONKIN_FORM = { 24880 }
spells.BUFF_CLEARCASTING = { 16870 }
spells.BUFF_NATURES_GRACE = { 16886 }

-- -- Debuffs -----------------------------------------------------------------
spells.DEBUFF_MOONFIRE = { 26988, 26987, 25299, 22827, 8921 }
spells.DEBUFF_INSECT_SWARM = { 26980, 24977, 5570 }
spells.DEBUFF_FAERIE_FIRE = { 26993, 9907, 770 }

return spells
