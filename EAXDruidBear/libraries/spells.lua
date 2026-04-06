-- spells.lua  |  EAX Port)  |  TBC
local spells = {}

-- -- Bear Form spells --------------------------------------------------------
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
spells.FAERIE_FIRE_FERAL = { 27011, 17392, 17391, 16857 }

-- -- Forms -------------------------------------------------------------------
spells.BEAR_FORM = { 5487 }
spells.DIRE_BEAR_FORM = { 9634 }

-- -- Cooldowns -----------------------------------------------------------------
spells.BARKSKIN = { 22812 }
spells.SURVIVAL_INSTINCTS = { 50322 }

-- -- Buffs -------------------------------------------------------------------
spells.BUFF_BEAR_FORM = { 5487, 9634 }
spells.BUFF_FRENZIED_REGENERATION = { 22842, 22895, 22896 }
spells.BUFF_ENRAGE = { 5229 }

-- -- Debuffs -----------------------------------------------------------------
spells.DEBUFF_LACERATE = { 33745 }
spells.DEBUFF_MANGLE = { 33987, 33986, 33878 }
spells.DEBUFF_DEMORALIZING_ROAR = { 26998, 9898, 99 }
spells.DEBUFF_FAERIE_FIRE = { 27011, 17392, 16857 }

return spells
