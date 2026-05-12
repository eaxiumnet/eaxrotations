-- Readability notes:
--   What: Warlock spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.WARLOCK then return nil end

local SPELLS = {
Conflagrate = NS.spell_action({ 17962 }, "Conflagrate"),
    Corruption = NS.spell_action({ 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony = NS.spell_action({ 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfDoom"),
    CurseOfDoom = NS.spell_action({ 30910, 603 }, "CurseOfDoom"),
    DeathCoil = NS.spell_action({ 6789, 17928, 17924, 17923 }, "DeathCoil"),
    DeathCoil = NS.spell_action({ 6789, 17927, 27223 }, "DeathCoil"),
    FelArmor = NS.spell_action({ 28189, 28176 }, "FelArmor"),
    Immolate = NS.spell_action({ 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Incinerate = NS.spell_action({ 32231, 29722 }, "Incinerate"),
    LifeTap = NS.spell_action({ 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    HowlofTerror = NS.spell_action({ 17928, 5484 }, "HowlofTerror"),
    SeedOfCorruption = NS.spell_action({ 27243 }, "SeedOfCorruption"),
    ShadowBolt = NS.spell_action({ 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    Shadowburn = NS.spell_action({ 30546, 27263, 18871, 18870, 18869, 18868, 18867, 17877 }, "Shadowburn"),
    SiphonLife = NS.spell_action({ 30911, 27264, 18881, 18880, 18879, 18265 }, "SiphonLife"),
    Soulshatter = NS.spell_action(29858, "Soulshatter"),
    UnstableAffliction = NS.spell_action({ 30405, 30404, 30108 }, "UnstableAffliction"),
}
NS.WarlockSpells = SPELLS

local config = {
    class_key = "warlock",
    class_name = "Warlock",
    default_playstyle = "affliction",
    playstyles = {
        { name = "affliction", display_name = "Affliction" },
        { name = "demonology", display_name = "Demonology" },
        { name = "destruction", display_name = "Destruction" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/warlock/" .. name)
    if not ok then NS.log_warning("Warlock module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("affliction_sylvanas")
load_child("demonology_sylvanas")
load_child("destruction_sylvanas")
NS.log("Warlock class module loaded")
return config
