-- Readability notes:
--   What: Mage spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.MAGE then return nil end

local SPELLS = {
    ArcaneBlast = NS.spell_action({ 30451 }, "ArcaneBlast"),
    ArcaneIntellect = NS.spell_action({ 27126, 10157, 10156, 1461, 1460, 1459 }, "ArcaneIntellect"),
    ArcaneMissiles = NS.spell_action({ 27075, 25345, 10212, 10211, 8417, 8416, 5145, 5144, 5143 }, "ArcaneMissiles"),
    ArcanePower = NS.spell_action({ 12042 }, "ArcanePower"),
    Blizzard = NS.spell_action({ 27085, 10187, 10186, 10185, 8427, 6141, 10 }, "Blizzard"),
    Combustion = NS.spell_action({ 11129 }, "Combustion"),
    Evocation = NS.spell_action({ 12051 }, "Evocation"),
    IceBarrier = NS.spell_action({ 13032, 13031, 13033 }, "IceBarrier"),
    RemoveCurse = NS.spell_action({ 475 }, "RemoveCurse"),
    FireBlast = NS.spell_action({ 27079, 10199, 10197, 8413, 8412, 2138, 2137, 2136 }, "FireBlast"),
    Fireball = NS.spell_action({ 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Flamestrike = NS.spell_action({ 27086, 10216, 10215, 8423, 8422, 2120 }, "Flamestrike"),
    FlamestrikeRank6 = NS.spell_action({ 10216 }, "FlamestrikeRank6"),
    Frostbolt = NS.spell_action({ 27072, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116 }, "Frostbolt"),
    IceBlock = NS.spell_action({ 45438, 27619 }, "IceBlock"),
    IceLance = NS.spell_action({ 30455 }, "IceLance"),
    IcyVeins = NS.spell_action({ 12472 }, "IcyVeins"),
    ManaShield = NS.spell_action({ 27131, 10193, 10192, 10191, 8495, 8494, 1463 }, "ManaShield"),
    RemoveCurse = NS.spell_action({ 475 }, "RemoveCurse"),
    MoltenArmor = NS.spell_action({ 30482 }, "MoltenArmor"),
    PresenceOfMind = NS.spell_action({ 12043 }, "PresenceOfMind"),
    Scorch = NS.spell_action({ 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948 }, "Scorch"),
    WaterElemental = NS.spell_action({ 31687 }, "WaterElemental"),
}
NS.MageSpells = SPELLS

local config = {
    class_key = "mage",
    class_name = "Mage",
    default_playstyle = "arcane",
    playstyles = {
        { name = "arcane", display_name = "Arcane" },
        { name = "fire", display_name = "Fire" },
        { name = "frost", display_name = "Frost" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/mage/" .. name)
    if not ok then NS.log_warning("Mage module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("arcane_sylvanas")
load_child("fire_sylvanas")
load_child("frost_sylvanas")
NS.log("Mage class module loaded")
return config
