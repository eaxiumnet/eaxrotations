-- Readability notes:
--   What: Shaman spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.SHAMAN then return nil end

local SPELLS = {
    Bloodlust = NS.spell_action({ 2825 }, "Bloodlust"),
    ChainHeal = NS.spell_action({ 25423, 25422, 10623, 10622, 1064 }, "ChainHeal"),
    ChainLightning = NS.spell_action({ 25442, 25439, 10605, 2860, 930, 421 }, "ChainLightning"),
    EarthShield = NS.spell_action({ 32594, 32593, 974 }, "EarthShield"),
    EarthShock = NS.spell_action({ 25454, 10414, 10413, 10412, 8046, 8045, 8044, 8042 }, "EarthShock"),
    FlameShock = NS.spell_action({ 25457, 29228, 10448, 10447, 8053, 8052, 8050 }, "FlameShock"),
    GraceOfAirTotem = NS.spell_action({ 25359, 10627, 8835 }, "GraceOfAirTotem"),
    HealingWave = NS.spell_action({ 25396, 25391, 25357, 10396, 10395, 959, 939, 913, 547, 332, 331 }, "HealingWave"),
    LesserHealingWave = NS.spell_action({ 25420, 10468, 10467, 10466, 8010, 8008, 8004 }, "LesserHealingWave"),
    LightningBolt = NS.spell_action({ 25449, 25448, 15208, 15207 }, "LightningBolt"),
    LightningShield = NS.spell_action({ 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, "LightningShield"),
    ManaSpringTotem = NS.spell_action({ 25570, 10497, 10496, 10495, 5675 }, "ManaSpringTotem"),
    ManaTideTotem = NS.spell_action({ 16190 }, "ManaTideTotem"),
    NaturesSwiftness = NS.spell_action({ 16188 }, "NaturesSwiftness"),
    ShamanisticRage = NS.spell_action({ 30823 }, "ShamanisticRage"),
    Stormstrike = NS.spell_action({ 17364 }, "Stormstrike"),
    StrengthOfEarthTotem = NS.spell_action({ 25528, 10442, 8161, 8160, 8075 }, "StrengthOfEarthTotem"),
    WaterShield = NS.spell_action({ 33736, 24398 }, "WaterShield"),
    WindfuryTotem = NS.spell_action({ 25587, 10614, 10613, 8512 }, "WindfuryTotem"),
}
NS.ShamanSpells = SPELLS

local config = {
    class_key = "shaman",
    class_name = "Shaman",
    default_playstyle = "elemental",
    playstyles = {
        { name = "elemental", display_name = "Elemental" },
        { name = "enhancement", display_name = "Enhancement" },
        { name = "restoration", display_name = "Restoration" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/shaman/" .. name)
    if not ok then NS.log_warning("Shaman module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

load_child("middleware_sylvanas")
load_child("healing_sylvanas")
load_child("elemental_sylvanas")
load_child("enhancement_sylvanas")
load_child("restoration_sylvanas")
NS.log("Shaman class module loaded")
return config
