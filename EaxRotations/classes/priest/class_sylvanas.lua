-- Readability notes:
--   What: Priest spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.PRIEST then return nil end

local SPELLS = {
    BindingHeal = NS.spell_action({ 32546 }, "BindingHeal"),
    CircleofHealing = NS.spell_action({ 34866, 34865, 34864, 34863, 34861 }, "CircleofHealing"),
    Fade = NS.spell_action({ 25429, 10942, 10941, 9592, 9579, 9578, 586 }, "Fade"),
    FlashHeal = NS.spell_action({ 25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061 }, "FlashHeal"),
    GreaterHeal = NS.spell_action({ 25213, 25210, 25314, 10965, 10964, 10963, 2060 }, "GreaterHeal"),
    HolyFire = NS.spell_action({ 25384, 15267, 15266, 15265, 15264, 15263, 15262, 14914 }, "HolyFire"),
    InnerFocus = NS.spell_action({ 14751 }, "InnerFocus"),
    MindBlast = NS.spell_action({ 25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092 }, "MindBlast"),
    MindFlay = NS.spell_action({ 25387, 18807, 17314, 17313, 17312, 17311, 15407 }, "MindFlay"),
    PowerWordShield = NS.spell_action({ 25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17 }, "PowerWordShield"),
    PrayerOfHealing = NS.spell_action({ 25308, 25316, 10961, 10960, 996, 596 }, "PrayerOfHealing"),
    PrayerofMending = NS.spell_action({ 33076 }, "PrayerofMending"),
    Renew = NS.spell_action({ 25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139 }, "Renew"),
    Shadowfiend = NS.spell_action({ 34433 }, "Shadowfiend"),
    ShadowWordDeath = NS.spell_action({ 32996, 32379 }, "ShadowWordDeath"),
    ShadowWordPain = NS.spell_action({ 25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589 }, "ShadowWordPain"),
    Shadowform = NS.spell_action({ 15473 }, "Shadowform"),
    Smite = NS.spell_action({ 25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585 }, "Smite"),
    PsychicScream = NS.spell_action({ 10890, 10888, 8124, 8122 }, "PsychicScream"),
    VampiricEmbrace = NS.spell_action({ 15286 }, "VampiricEmbrace"),
    VampiricTouch = NS.spell_action({ 34917, 34916, 34914 }, "VampiricTouch"),
    Starshards = NS.spell_action({ 19399, 19398, 19397, 19396, 19395, 19394, 19393 }, "Starshards"),
    DevouringPlague = NS.spell_action({ 25467, 19280, 19279, 19278, 19277, 19276, 2944 }, "DevouringPlague"),
}
NS.PriestSpells = SPELLS

NS.PriestFLASH_HEAL_RANKS = { { spell = SPELLS.FlashHeal, label = "R9" } }
NS.PriestGREATER_HEAL_RANKS = { { spell = SPELLS.GreaterHeal, label = "R7" } }
NS.PriestPRAYER_OF_HEALING_RANKS = { { spell = SPELLS.PrayerOfHealing, label = "R6" } }
NS.PriestBINDING_HEAL_RANKS = { { spell = SPELLS.BindingHeal, label = "R1" } }

local config = {
    class_key = "priest",
    class_name = "Priest",
    default_playstyle = "discipline",
    playstyles = {
        { name = "discipline", display_name = "Discipline" },
        { name = "holy", display_name = "Holy" },
        { name = "shadow", display_name = "Shadow" },
        { name = "smite", display_name = "Smite" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/priest/" .. name)
    if not ok then NS.log_warning("Priest module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("healing_sylvanas")
load_child("discipline_sylvanas")
load_child("holy_sylvanas")
load_child("shadow_sylvanas")
load_child("smite_sylvanas")
NS.log("Priest class module loaded")
return config
