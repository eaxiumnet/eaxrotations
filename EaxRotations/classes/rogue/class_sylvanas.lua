-- Readability notes:
--   What: Rogue spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.ROGUE then return nil end

local SPELLS = {
    AdrenalineRush = NS.spell_action({ 13750 }, "AdrenalineRush"),
    Ambush = NS.spell_action({ 27441, 11269, 11268, 11267, 8725, 8724, 8676 }, "Ambush"),
    Backstab = NS.spell_action({ 26863, 25300, 11281, 11280, 11279, 8721, 2591, 2590, 2589, 53 }, "Backstab"),
    BladeFlurry = NS.spell_action({ 13877 }, "BladeFlurry"),
    Eviscerate = NS.spell_action({ 26865, 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, "Eviscerate"),
    Feint = NS.spell_action({ 27448, 25302, 11303, 8637, 6768, 1966 }, "Feint"),
    Garrote = NS.spell_action({ 26884, 26839, 11290, 11289, 8633, 8632, 8631, 703 }, "Garrote"),
    Hemorrhage = NS.spell_action({ 26864, 17348, 17347, 16511 }, "Hemorrhage"),
    Kick = NS.spell_action({ 1769, 1768, 1767, 1766 }, "Kick"),
    Mutilate = NS.spell_action({ 34413, 34412, 34411, 1329 }, "Mutilate"),
    Rupture = NS.spell_action({ 26867, 11275, 11274, 11273, 8640, 8639, 1943 }, "Rupture"),
    SinisterStrike = NS.spell_action({ 26862, 26861, 11294, 11293, 8621, 1760, 1759, 1758, 1757, 1752 }, "SinisterStrike"),
    SliceAndDice = NS.spell_action({ 6774, 5171 }, "SliceAndDice"),
    Stealth = NS.spell_action({ 1787, 1786, 1785, 1784 }, "Stealth"),
    Vanish = NS.spell_action({ 26889, 1857, 1856 }, "Vanish"),
}
NS.RogueSpells = SPELLS

local config = {
    class_key = "rogue",
    class_name = "Rogue",
    default_playstyle = "combat",
    playstyles = {
        { name = "assassination", display_name = "Assassination" },
        { name = "combat", display_name = "Combat" },
        { name = "subtlety", display_name = "Subtlety" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/rogue/" .. name)
    if not ok then NS.log_warning("Rogue module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("assassination_sylvanas")
load_child("combat_sylvanas")
load_child("subtlety_sylvanas")
NS.log("Rogue class module loaded")
return config
