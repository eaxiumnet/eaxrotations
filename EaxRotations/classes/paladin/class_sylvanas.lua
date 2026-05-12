-- Readability notes:
--   What: Paladin spell table, playstyle config, and child module loader.
--   When: main.lua loads the active player's class module.
--   Why: every spec shares one audited spell map and one safe require path.
--   Safety: child module failures are logged instead of crashing startup.

-- Decision notes:
--   Class module is the single spell map and playstyle registry for this class.
--   Spell IDs are ranked newest-to-oldest so runtime resolution can pick the best learned TBC rank.
--   Child modules load with pcall so one broken playstyle logs cleanly instead of preventing the whole class from loading.
local NS = _G.EaxRotations
if not NS then return nil end
local enums = require("common/enums")
if type(enums) ~= "table" or type(enums.class_id) ~= "table" then enums = { class_id = NS.CLASS_ID } end
local player = NS.GetPlayer()
if not player or player:get_class() ~= enums.class_id.PALADIN then return nil end

local SPELLS = {
    AvengerShield = NS.spell_action({ 31935, 32700 }, "AvengerShield"),
    AvengingWrath = NS.spell_action({ 31884 }, "AvengingWrath"),
    BlessingOfKings = NS.spell_action({ 19897, 19898, 19899, 19900 }, "BlessingOfKings"),
    BlessingOfMight = NS.spell_action({ 25782, 19740, 20378 }, "BlessingOfMight"),
    BlessingOfWisdom = NS.spell_action({ 20355, 20356, 20357 }, "BlessingOfWisdom"),
    Cleanse = NS.spell_action({ 4987 }, "Cleanse"),
    ConcentrationAura = NS.spell_action({ 19746, 19747 }, "ConcentrationAura"),
    Consecration = NS.spell_action({ 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    CrusaderStrike = NS.spell_action({ 35395 }, "CrusaderStrike"),
    DevotionAura = NS.spell_action({ 465, 10291, 10292 }, "DevotionAura"),
    DivineFavor = NS.spell_action({ 20216 }, "DivineFavor"),
    DivineShield = NS.spell_action({ 642 }, "DivineShield"),
    Exorcism = NS.spell_action({ 27138, 10314, 10313, 10312, 5615, 5614, 879 }, "Exorcism"),
    FlashOfLight = NS.spell_action({ 27137, 19943, 19942, 19941, 19940, 19939, 19750 }, "FlashOfLight"),
    HammerOfJustice = NS.spell_action({ 10308, 5589, 5588, 853 }, "HammerOfJustice"),
    HammerOfWrath = NS.spell_action({ 27180, 24275 }, "HammerOfWrath"),
    HolyLight = NS.spell_action({ 27136, 27135, 25292, 10329, 10328, 3472, 1042, 1026, 647, 639, 635 }, "HolyLight"),
    HolyShield = NS.spell_action({ 27179, 20928, 20927, 20925 }, "HolyShield"),
    HolyShock = NS.spell_action({ 20930, 20929, 20473 }, "HolyShock"),
    Judgement = NS.spell_action({ 20271 }, "Judgement"),
    LayOnHands = NS.spell_action({ 27154, 10310, 2800, 633 }, "LayOnHands"),
    Repentance = NS.spell_action({ 20066, 5164 }, "Repentance"),
    RighteousFury = NS.spell_action({ 25780 }, "RighteousFury"),
    SanctityAura = NS.spell_action({ 20218, 32223 }, "SanctityAura"),
    SealBlood = NS.spell_action({ 31892 }, "SealBlood"),
    SealCommand = NS.spell_action({ 27170, 20920, 20919, 20918, 20915, 20375 }, "SealCommand"),
    SealCommandRank1 = NS.spell_action({ 20375 }, "SealCommandRank1"),
    SealOfWisdom = NS.spell_action({ 27168, 20266, 15981 }, "SealOfWisdom"),
    SealRighteousness = NS.spell_action({ 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084 }, "SealRighteousness"),
}
NS.PaladinSpells = SPELLS

NS.HOLY_LIGHT_RANKS = { { spell = SPELLS.HolyLight, label = "R11", base_min = 2196, base_max = 2446 } }
NS.FLASH_OF_LIGHT_RANKS = { { spell = SPELLS.FlashOfLight, label = "R7", base_min = 448, base_max = 502 } }
NS.HL_COEFFICIENT, NS.FOL_COEFFICIENT, NS.HEALING_LIGHT_MULT = 0.714, 0.429, 1.12

local config = {
    class_key = "paladin",
    class_name = "Paladin",
    default_playstyle = "holy",
    playstyles = {
        { name = "holy", display_name = "Holy" },
        { name = "protection", display_name = "Protection" },
        { name = "retribution", display_name = "Retribution" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/paladin/" .. name)
    if not ok then NS.log_warning("Paladin module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("healing_sylvanas")
load_child("holy_sylvanas")
load_child("protection_sylvanas")
load_child("retribution_sylvanas")
NS.log("Paladin class module loaded")
return config
