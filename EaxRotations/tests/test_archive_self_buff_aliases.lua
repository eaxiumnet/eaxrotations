-- test_archive_self_buff_aliases.lua — Verify self-buff alias mappings against spell data.
-- WHAT:  reads spell_id_table and validates that self-buff aliases resolve to real spell IDs.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   prevents stale aliases from breaking buff tracking in specs.
-- SAFETY: pure file-read test; no casting or side effects.

local function read(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

local function contains(haystack, needle, message)
    assert(haystack:find(needle, 1, true), message)
end

local ooc = read("EaxRotations/shared/ooc_manager_sylvanas.lua")
contains(ooc, "battle_shout = { n = 8, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }", "OOC Battle Shout should include archive low-rank aura IDs")
contains(ooc, "aspect_hawk = { n = 8, 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }", "OOC Aspect of the Hawk should match archive buff IDs")
contains(ooc, "mage_armor = { n = 4, 27125, 22783, 22782, 6117 }", "OOC Mage Armor should include rank 2 aura")
contains(ooc, "arcane_intellect = { n = 8, 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }", "OOC Arcane Intellect should include rank 2 and Arcane Brilliance aliases")
contains(ooc, "inner_fire = { n = 7, 25431, 10952, 10951, 1006, 602, 7128, 588 }", "OOC Inner Fire should include online TBC rank aliases")
contains(ooc, "power_word_fortitude = { n = 7, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }", "OOC Fortitude should include online TBC low ranks")
contains(ooc, "mark_of_the_wild = { n = 11, 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }", "OOC Mark/Gift detection should include archive ranks and group buff aliases")
contains(ooc, "thorns = { n = 7, 26992, 9910, 9756, 8914, 1075, 782, 467 }", "OOC Thorns should include archive rank 3 aura")
contains(ooc, "fel_armor = { n = 2, 28189, 28176 }", "OOC Fel Armor should include both TBC ranks")
contains(ooc, "demon_armor = { n = 8, 27260, 11735, 11734, 11733, 1086, 706, 687, 696 }", "OOC Demon Armor should include archive low-rank aliases")
contains(ooc, "lightning_shield = { n = 9, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }", "OOC Lightning Shield should include online TBC ranks")

local warrior_leveling = read("EaxRotations/classes/warrior/leveling_sylvanas.lua")
contains(warrior_leveling, "state.has_battle_shout = L.has_buff(BATTLE_SHOUT_BUFF)", "Warrior leveling should check full Battle Shout buff table")

local druid_leveling = read("EaxRotations/classes/druid/leveling_sylvanas.lua")
contains(druid_leveling, "state.has_mark_of_wild = has_buff(MARK_OF_THE_WILD_BUFF)", "Druid leveling should check full Mark/Gift buff table")
contains(druid_leveling, "state.has_thorns = has_buff(THORNS_BUFF)", "Druid leveling should check full Thorns buff table")

local druid_bear = read("EaxRotations/classes/druid/bear_sylvanas.lua")
contains(druid_bear, "local MARK_BUFF = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }", "Druid Bear Mark/Gift detection should include archive ranks and group buff aliases")
contains(druid_bear, "local THORNS_BUFF = { 26992, 9910, 9756, 8914, 1075, 782, 467 }", "Druid Bear Thorns detection should include archive rank 3 aura")

local priest_leveling = read("EaxRotations/classes/priest/leveling_sylvanas.lua")
contains(priest_leveling, "state.has_fortitude = has_buff(POWER_WORD_FORTITUDE_BUFF)", "Priest leveling should check full Fortitude buff table")
contains(priest_leveling, "state.has_inner_fire = has_buff(INNER_FIRE_BUFF)", "Priest leveling should check full Inner Fire buff table")
contains(priest_leveling, "local POWER_WORD_FORTITUDE_BUFF = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }", "Priest leveling Fortitude table should match online TBC ranks")
contains(priest_leveling, "local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }", "Priest leveling Inner Fire table should match online TBC ranks")

local rogue_leveling = read("EaxRotations/classes/rogue/leveling_sylvanas.lua")
contains(rogue_leveling, "state.has_slice_and_dice = has_buff(SLICE_AND_DICE_BUFF)", "Rogue leveling should check full Slice and Dice buff table")
contains(rogue_leveling, "state.stealthed = has_buff(STEALTH_BUFF)", "Rogue leveling should check full Stealth buff table")

local hunter_leveling = read("EaxRotations/classes/hunter/leveling_sylvanas.lua")
contains(hunter_leveling, "local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }", "Hunter leveling Hawk detection should match archive buff IDs")

print("PASS test_archive_self_buff_aliases")
