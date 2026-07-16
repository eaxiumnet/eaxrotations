-- test_archive_self_buff_aliases.lua — Verify self-buff alias mappings against spell data.
-- WHAT:  ranked_buff_families SoT + consumer wiring for class self-buffs.
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

-- SoT module owns multi-expansion ladders (Vanilla ∪ TBC ∪ WotLK).
local rbf = read("EaxRotations/shared/ranked_buff_families_sylvanas.lua")
contains(rbf, "48469", "SoT MotW must include WotLK max rank 48469")
contains(rbf, "48470", "SoT GotW must include WotLK max rank 48470")
contains(rbf, "26990", "SoT MotW must include TBC max rank 26990")
contains(rbf, "26991", "SoT GotW must include TBC max rank 26991")
contains(rbf, "43002", "SoT AB must include WotLK max rank 43002")
contains(rbf, "42995", "SoT AI must include WotLK max rank 42995")
contains(rbf, "48162", "SoT PoF must include WotLK max rank 48162")
contains(rbf, "48161", "SoT Fort must include WotLK max rank 48161")
contains(rbf, "53307", "SoT Thorns must include WotLK max rank 53307")
contains(rbf, "47436", "SoT Battle Shout must include WotLK max rank 47436")
contains(rbf, "47893", "SoT Fel Armor must include WotLK max rank 47893")
contains(rbf, "57960", "SoT Water Shield must include WotLK max rank 57960")
-- Best-first: group superiors listed before single-target in detect comments/order
contains(rbf, "MOTW_DETECT", "SoT must define MotW detect ladder")
contains(rbf, "AI_DETECT", "SoT must define AI detect ladder")
contains(rbf, "FORT_DETECT", "SoT must define Fort detect ladder")

local ooc = read("EaxRotations/shared/ooc_manager_sylvanas.lua")
contains(ooc, "ranked_buff_families_sylvanas", "OOC manager must require ranked_buff_families SoT")
contains(ooc, "rbf_detect", "OOC manager must use rbf_detect for buff tables")
contains(ooc, "rbf_cast", "OOC manager must use rbf_cast for spell ladders")

local warrior_leveling = read("EaxRotations/classes/warrior/leveling_sylvanas.lua")
contains(warrior_leveling, "state.has_battle_shout = L.has_buff(BATTLE_SHOUT_BUFF)", "Warrior leveling should check full Battle Shout buff table")

local druid_leveling = read("EaxRotations/classes/druid/leveling_sylvanas.lua")
contains(druid_leveling, "state.has_mark_of_wild = has_buff(MARK_OF_THE_WILD_BUFF)", "Druid leveling should check full Mark/Gift buff table")
contains(druid_leveling, "state.has_thorns = has_buff(THORNS_BUFF)", "Druid leveling should check full Thorns buff table")
contains(druid_leveling, "ranked_buff_families_sylvanas", "Druid leveling should pull MotW from SoT")

local druid_bear = read("EaxRotations/classes/druid/bear_sylvanas.lua")
contains(druid_bear, "ranked_buff_families_sylvanas", "Druid Bear Mark/Gift detection should use ranked_buff_families SoT")
contains(druid_bear, "THORNS_BUFF", "Druid Bear Thorns detection table present")

local priest_leveling = read("EaxRotations/classes/priest/leveling_sylvanas.lua")
contains(priest_leveling, "state.has_fortitude = has_buff(POWER_WORD_FORTITUDE_BUFF)", "Priest leveling should check full Fortitude buff table")
contains(priest_leveling, "state.has_inner_fire = has_buff(INNER_FIRE_BUFF)", "Priest leveling should check full Inner Fire buff table")
contains(priest_leveling, "ranked_buff_families_sylvanas", "Priest leveling Fortitude should use SoT")
contains(priest_leveling, "local INNER_FIRE_BUFF = { 25431, 10952, 10951, 1006, 602, 7128, 588 }", "Priest leveling Inner Fire table should match online TBC ranks")

local rogue_leveling = read("EaxRotations/classes/rogue/leveling_sylvanas.lua")
contains(rogue_leveling, "state.has_slice_and_dice = has_buff(SLICE_AND_DICE_BUFF)", "Rogue leveling should check full Slice and Dice buff table")
contains(rogue_leveling, "state.stealthed = has_buff(STEALTH_BUFF)", "Rogue leveling should check full Stealth buff table")

local hunter_leveling = read("EaxRotations/classes/hunter/leveling_sylvanas.lua")
contains(hunter_leveling, "local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }", "Hunter leveling Hawk detection should match archive buff IDs")

print("PASS test_archive_self_buff_aliases")
