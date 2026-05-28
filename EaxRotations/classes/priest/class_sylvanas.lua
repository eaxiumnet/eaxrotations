-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/priest/class_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Priest spell table, playstyle config, and child module loader.
-- ============================================================================
-- What: Priest spell table and playstyle loader
-- When: Load time
-- Why: Registers priest spells and loads child modules by class
-- Safety: Class check on load, shared loader pattern, no runtime combat logic
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local cl = require("shared/class_loader_sylvanas")
local load_child = cl.create_loader("priest", "Priest")
local enums = cl.get_enums()
local player = NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return player and player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.PRIEST then return nil end

local SPELLS = {
    BindingHeal = NS.spell_action({
        name = "BindingHeal",
        ids = {32546},
        levels = {64},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    CircleofHealing = NS.spell_action({
        name = "CircleofHealing",
        ids = {34866, 34865, 34864, 34863, 34861},
        levels = {70, 65, 60, 56, 50},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    Fade = NS.spell_action({
        name = "Fade",
        ids = {25429, 10942, 10941, 9592, 9579, 9578, 586},
        levels = {66, 60, 50, 40, 30, 20, 8},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    FlashHeal = NS.spell_action({
        name = "FlashHeal",
        ids = {25235, 25233, 10917, 10916, 10915, 9474, 9473, 9472, 2061},
        levels = {67, 61, 56, 50, 44, 38, 32, 26, 20},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    GreaterHeal = NS.spell_action({
        name = "GreaterHeal",
        ids = {25213, 25210, 25314, 10965, 10964, 10963, 2060},
        levels = {68, 63, 60, 58, 52, 46, 40},
        cast_time = 3.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    HolyFire = NS.spell_action({
        name = "HolyFire",
        ids = {25384, 15261, 15267, 15266, 15265, 15264, 15263, 15262, 14914},
        levels = {66, 60, 54, 48, 42, 36, 30, 24, 20},
        cast_time = 1.5,
        cooldown = 10,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    InnerFire = NS.spell_action({
        name = "InnerFire",
        ids = {25431, 10952, 10951, 1006, 602, 7128, 588},
        levels = {69, 60, 50, 40, 30, 20, 12},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    InnerFocus = NS.spell_action({
        name = "InnerFocus",
        ids = {14751},
        levels = {40},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "holy",
    }),
    PowerInfusion = NS.spell_action({
        name = "PowerInfusion",
        ids = {10060},
        levels = {40},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    DispelMagic = NS.spell_action({
        name = "DispelMagic",
        ids = {988, 527},
        levels = {54, 30},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    DivineSpirit = NS.spell_action({
        name = "DivineSpirit",
        ids = {25312, 27841, 14819, 14818, 14752},
        levels = {70, 60, 50, 40, 30},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    FearWard = NS.spell_action({
        name = "FearWard",
        ids = {6346},
        levels = {20},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    MindBlast = NS.spell_action({
        name = "MindBlast",
        ids = {25375, 25372, 10947, 10946, 10945, 8106, 8105, 8104, 8103, 8102, 8092},
        levels = {69, 63, 58, 52, 46, 40, 34, 28, 22, 16, 10},
        cast_time = 1.5,
        cooldown = 8,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    MindFlay = NS.spell_action({
        name = "MindFlay",
        ids = {25387, 18807, 17314, 17313, 17312, 17311, 15407},
        levels = {68, 60, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    PowerWordShield = NS.spell_action({
        name = "PowerWordShield",
        ids = {25218, 25217, 10901, 10900, 10899, 10898, 6066, 6065, 3747, 600, 592, 17},
        levels = {70, 62, 54, 46, 38, 30, 24, 18, 12, 8, 6, 1},
        cast_time = 0,
        cooldown = 15,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    PowerWordFortitude = NS.spell_action({
        name = "PowerWordFortitude",
        ids = {25389, 10938, 10937, 2791, 1245, 1244, 1243},
        levels = {70, 60, 48, 36, 24, 12, 1},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    PrayerOfFortitude = NS.spell_action({
        name = "PrayerOfFortitude",
        ids = {25392, 21564, 21562},
        levels = {70, 60, 48},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    PrayerOfHealing = NS.spell_action({
        name = "PrayerOfHealing",
        ids = {25308, 25316, 10961, 10960, 996, 596},
        levels = {68, 60, 60, 50, 40, 30},
        cast_time = 3.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    PrayerofMending = NS.spell_action({
        name = "PrayerofMending",
        ids = {33076},
        levels = {68},
        cast_time = 0,
        cooldown = 10,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    Renew = NS.spell_action({
        name = "Renew",
        ids = {25222, 25221, 25315, 10929, 10928, 10927, 6078, 6077, 6076, 6075, 6074, 139},
        levels = {70, 65, 60, 56, 50, 44, 38, 32, 26, 20, 14, 8},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    Shadowfiend = NS.spell_action({
        name = "Shadowfiend",
        ids = {34433},
        levels = {66},
        cast_time = 0,
        cooldown = 300,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    ShadowWordDeath = NS.spell_action({
        name = "ShadowWordDeath",
        ids = {32996, 32379},
        levels = {70, 62},
        cast_time = 0,
        cooldown = 12,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    ShadowWordPain = NS.spell_action({
        name = "ShadowWordPain",
        ids = {25368, 25367, 10894, 10893, 10892, 2767, 992, 970, 594, 589},
        levels = {70, 65, 58, 50, 42, 34, 26, 18, 10, 4},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    ShackleUndead = NS.spell_action({
        name = "ShackleUndead",
        ids = {10955, 9485, 9484},
        levels = {60, 40, 20},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    Shadowform = NS.spell_action({
        name = "Shadowform",
        ids = {15473},
        levels = {40},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    Smite = NS.spell_action({
        name = "Smite",
        ids = {25364, 25363, 10934, 10933, 6060, 1004, 984, 598, 591, 585},
        levels = {69, 61, 54, 46, 38, 30, 22, 14, 6, 1},
        cast_time = 2.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    PsychicScream = NS.spell_action({
        name = "PsychicScream",
        ids = {10890, 10888, 8124, 8122},
        levels = {56, 42, 28, 14},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    VampiricEmbrace = NS.spell_action({
        name = "VampiricEmbrace",
        ids = {15286},
        levels = {30},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    VampiricTouch = NS.spell_action({
        name = "VampiricTouch",
        ids = {34917, 34916, 34914},
        levels = {70, 60, 50},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    Starshards = NS.spell_action({
        name = "Starshards",
        ids = {25446, 19305, 19304, 19303, 19302, 19299, 19296, 10797},
        levels = {66, 58, 50, 42, 34, 26, 18, 10},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    DevouringPlague = NS.spell_action({
        name = "DevouringPlague",
        ids = {25467, 19280, 19279, 19278, 19277, 19276, 2944},
        levels = {68, 60, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    DesperatePrayer = NS.spell_action({
        name = "DesperatePrayer",
        ids = {25437, 19243, 19242, 19241, 19240, 19238, 19236, 13908},
        levels = {66, 58, 50, 42, 34, 26, 18, 10},
        cast_time = 0,
        cooldown = 600,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    Lightwell = NS.spell_action({
        name = "Lightwell",
        ids = {28275, 27871, 27870, 724},
        levels = {70, 60, 50, 40},
        cast_time = 1.5,
        cooldown = 360,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    AbolishDisease = NS.spell_action({
        name = "AbolishDisease",
        ids = {552},
        levels = {32},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    CureDisease = NS.spell_action({
        name = "CureDisease",
        ids = {528},
        levels = {14},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    HolyNova = NS.spell_action({
        name = "HolyNova",
        ids = {25331, 25329, 27805, 27804, 27803, 27801, 27800, 27799, 15431, 15430, 15237},
        levels = {68, 68, 60, 52, 44, 60, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 6,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    ManaBurn = NS.spell_action({
        name = "ManaBurn",
        ids = {25380, 25379, 10876, 10875, 10874, 8131, 8129},
        levels = {70, 63, 56, 48, 40, 32, 24},
        cast_time = 3.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    MassDispel = NS.spell_action({
        name = "MassDispel",
        ids = {32375},
        levels = {70},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "holy",
    }),
    Silence = NS.spell_action({
        name = "Silence",
        ids = {15487},
        levels = {30},
        cast_time = 0,
        cooldown = 45,
        power_cost = 0,
        power_type = "mana",
        school = "shadow",
    }),
    Berserking = NS.spell_action({
        name = "Berserking",
        ids = {26297, 20554},
        levels = {1},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    BloodFury = NS.spell_action({
        name = "BloodFury",
        ids = {33697, 20572},
        levels = {1},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    ArcaneTorrent = NS.spell_action({
        name = "ArcaneTorrent",
        ids = {25046},
        levels = {1},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "arcane",
    }),
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
        { name = "leveling", display_name = "Leveling" },
        { name = "discipline", display_name = "Discipline" },
        { name = "holy", display_name = "Holy" },
        { name = "shadow", display_name = "Shadow" },
        { name = "smite", display_name = "Smite" },
    },
}
NS.rotation_registry:set_class_config(config)

load_child("middleware_sylvanas")
load_child("healing_sylvanas")
load_child("leveling_sylvanas", true)
load_child("discipline_sylvanas")
load_child("holy_sylvanas")
load_child("shadow_sylvanas")
load_child("smite_sylvanas")
NS.log("Priest class module loaded")
return config
