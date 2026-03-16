-- EAX Druid Feral | spells.lua
-- Rank tables and buff/debuff ID tables only.

local spells = {}

spells.CAT_FORM = { 768 }
spells.BEAR_FORM = { 9634, 5487 }
spells.FAERIE_FIRE_FERAL = { 27011, 17392, 17391, 17390, 16857 }

spells.MANGLE_CAT = { 33983, 33876 }
spells.RAKE = { 27003, 1822 }
spells.SHRED = { 5221 }
spells.RIP = { 27008, 1079 }
spells.FEROCIOUS_BITE = { 24248, 22829, 22828, 22568 }
spells.TIGERS_FURY = { 9846, 9845, 6793, 5217 }

spells.MANGLE_BEAR = { 33987, 33986, 33878 }
spells.MAUL = { 26996, 9881, 9880, 6807 }
spells.SWIPE = { 26997, 9908, 779 }
spells.GROWL = { 6795 }
spells.FRENZIED_REGENERATION = { 22842 }
spells.BERSERK = { 50334 }

spells.BUFF_CAT_FORM = { 768 }
spells.BUFF_BEAR_FORM = { 5487, 9634, 9635 }
spells.BUFF_TIGERS_FURY = { 5217, 6793, 9845, 9846, 50213 }
spells.BUFF_FRENZIED_REGENERATION = { 22842 }
spells.BUFF_BERSERK = { 50334 }

spells.DEBUFF_FAERIE_FIRE = { 770, 778, 16857, 17390, 17391, 17392, 26993, 27011 }
spells.DEBUFF_RAKE = { 1822, 27003 }
spells.DEBUFF_RIP = { 1079, 27008 }
spells.DEBUFF_MANGLE = { 33876, 33983, 33878, 33986, 33987 }

return spells
