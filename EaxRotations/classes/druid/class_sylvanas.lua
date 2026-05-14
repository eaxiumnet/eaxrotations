-- Readability notes:
--   What: Druid spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.DRUID then return nil end

local SPELLS = {
    Barkskin = NS.spell_action({ 22812 }, "Barkskin"),
    BearForm = NS.spell_action({ 9634, 5487 }, "BearForm"),
    CatForm = NS.spell_action({ 768 }, "CatForm"),
    ChallengingRoar = NS.spell_action({ 5209 }, "ChallengingRoar"),
    Claw = NS.spell_action({ 27000, 9850, 9849, 1082 }, "Claw"),
    Cower = NS.spell_action({ 27004, 9892, 8998 }, "Cower"),
    Dash = NS.spell_action({ 33357, 9821, 1850 }, "Dash"),
    DemoralizingRoar = NS.spell_action({ 26998, 9898, 9747, 9490, 1735, 99 }, "DemoralizingRoar"),
    FaerieFire = NS.spell_action({ 26993, 9907, 9749, 778, 770 }, "FaerieFire"),
    FaerieFireFeral = NS.spell_action({ 27011, 17392, 17391, 17390, 16857 }, "FaerieFireFeral"),
    FerociousBite = NS.spell_action({ 24248, 22829, 22828, 22568 }, "FerociousBite"),
    ForceOfNature = NS.spell_action({ 33831 }, "ForceOfNature"),
    FrenziedRegeneration = NS.spell_action({ 22842 }, "FrenziedRegeneration"),
    Growl = NS.spell_action({ 6795 }, "Growl"),
    HealingTouch = NS.spell_action({ 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    Hurricane = NS.spell_action({ 27012, 17402, 17401, 16914 }, "Hurricane"),
    InsectSwarm = NS.spell_action({ 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    Lacerate = NS.spell_action({ 33745 }, "Lacerate"),
    Lifebloom = NS.spell_action({ 33763 }, "Lifebloom"),
    MangleBear = NS.spell_action({ 33987, 33986, 33878 }, "MangleBear"),
    MangleCat = NS.spell_action({ 33983, 33982, 33876 }, "MangleCat"),
    Maul = NS.spell_action({ 26996, 9881, 9880, 6807 }, "Maul"),
    Moonfire = NS.spell_action({ 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    MoonkinForm = NS.spell_action({ 24858 }, "MoonkinForm"),
    NaturesSwiftness = NS.spell_action({ 17116 }, "NaturesSwiftness"),
    Prowl = NS.spell_action({ 9913, 6783, 5215 }, "Prowl"),
    Rake = NS.spell_action({ 1822 }, "Rake"),
    Ravage = NS.spell_action({ 9867, 9866, 6785, 3242 }, "Ravage"),
    Regrowth = NS.spell_action({ 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Rejuvenation = NS.spell_action({ 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    Rip = NS.spell_action({ 27008, 1079 }, "Rip"),
    Shred = NS.spell_action({ 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
    Starfire = NS.spell_action({ 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
    Swiftmend = NS.spell_action({ 18562 }, "Swiftmend"),
    SwipeBear = NS.spell_action({ 26997, 9908, 779 }, "SwipeBear"),
    TigersFury = NS.spell_action({ 9846, 9845, 6793, 5217 }, "TigersFury"),
Wrath = NS.spell_action({ 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    RemoveCurse = NS.spell_action({ 2782, 20739 }, "RemoveCurse"),
    AbolishPoison = NS.spell_action({ 2893, 8955, 8954, 8953, 8952, 5237 }, "AbolishPoison"),
}
NS.DruidSpells = SPELLS

local config = {
    class_key = "druid",
    class_name = "Druid",
    default_playstyle = "balance",
    playstyles = {
        { name = "balance", display_name = "Balance" },
        { name = "bear", display_name = "Bear" },
        { name = "cat", display_name = "Cat" },
        { name = "caster", display_name = "Caster" },
        { name = "resto", display_name = "Resto" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/druid/" .. name)
    if not ok then NS.log_warning("Druid module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("balance_sylvanas")
load_child("bear_sylvanas")
load_child("cat_sylvanas")
load_child("caster_sylvanas")
load_child("healing_sylvanas")
load_child("resto_sylvanas")
NS.log("Druid class module loaded")
return config
