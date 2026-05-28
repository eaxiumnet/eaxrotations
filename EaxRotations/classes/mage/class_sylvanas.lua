-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/mage/class_sylvanas.lua"
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
-- Mage spell table, playstyle config, and child module loader.

-- ============================================================================
-- What: Mage spell table, playstyle config, and child module loader.
-- When: Load time.
-- Why: Centralize class registration and child module wiring.
-- Safety: Class check returns cleanly; NS.* helpers only; graceful degradation.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local cl = require("shared/class_loader_sylvanas")
local load_child = cl.create_loader("mage", "Mage")
local enums = cl.get_enums()
local player = NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return player and player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.MAGE then return nil end

local SPELLS = {
    ArcaneBlast = NS.spell_action({
        name = "ArcaneBlast",
        ids = {30451},
        levels = {64},
        cast_time = 2.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    ArcaneExplosion = NS.spell_action({
        name = "ArcaneExplosion",
        ids = {27082, 27080, 10202, 10201, 8439, 8438, 8437, 1449},
        levels = {70, 62, 54, 46, 38, 30, 22, 14},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    ArcaneIntellect = NS.spell_action({
        name = "ArcaneIntellect",
        ids = {27126, 10157, 10156, 1461, 1460, 1459},
        levels = {70, 56, 42, 28, 14, 1},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    ArcaneMissiles = NS.spell_action({
        name = "ArcaneMissiles",
        ids = {38704, 38699, 27075, 25345, 10212, 10211, 8417, 8416, 5145, 5144, 5143},
        levels = {70, 69, 63, 60, 56, 48, 40, 32, 24, 16, 8},
        cast_time = 5.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    ArcanePower = NS.spell_action({
        name = "ArcanePower",
        ids = {12042},
        levels = {40},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "arcane",
    }),
    BlastWave = NS.spell_action({
        name = "BlastWave",
        ids = {33933, 27133, 13021, 13020, 13019, 13018, 11113},
        levels = {70, 65, 60, 52, 44, 36, 30},
        cast_time = 0,
        cooldown = 45,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Counterspell = NS.spell_action({
        name = "Counterspell",
        ids = {2139},
        levels = {24},
        cast_time = 0,
        cooldown = 24,
        power_cost = 0,
        power_type = "none",
        school = "arcane",
    }),
    Blizzard = NS.spell_action({
        name = "Blizzard",
        ids = {27085, 10187, 10186, 10185, 8427, 6141, 10},
        levels = {68, 60, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    Combustion = NS.spell_action({
        name = "Combustion",
        ids = {11129},
        levels = {40},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "fire",
    }),
    ConjureManaEmerald = NS.spell_action({
        name = "ConjureManaEmerald",
        ids = {27101, 10054, 10053, 3552, 759},
        levels = {68, 58, 48, 38, 28},
        cast_time = 3.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    DragonsBreath = NS.spell_action({
        name = "DragonsBreath",
        ids = {33043, 33042, 33041, 31661},
        levels = {70, 64, 56, 50},
        cast_time = 0,
        cooldown = 15,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Evocation = NS.spell_action({
        name = "Evocation",
        ids = {12051},
        levels = {20},
        cast_time = 0,
        cooldown = 480,
        power_cost = 0,
        power_type = "none",
        school = "arcane",
    }),
    IceBarrier = NS.spell_action({
        name = "IceBarrier",
        ids = {33405, 27134, 13033, 13032, 13031, 11426},
        levels = {70, 64, 58, 52, 46, 40},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    FrostWard = NS.spell_action({
        name = "FrostWard",
        ids = {32796, 28609, 10177, 8462, 8461, 6143},
        levels = {70, 60, 52, 42, 32, 22},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    RemoveCurse = NS.spell_action({
        name = "RemoveCurse",
        ids = {475},
        levels = {18},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    FireBlast = NS.spell_action({
        name = "FireBlast",
        ids = {27079, 27078, 10199, 10197, 8413, 8412, 2138, 2137, 2136},
        levels = {70, 61, 54, 46, 38, 30, 22, 14, 6},
        cast_time = 0,
        cooldown = 8,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Fireball = NS.spell_action({
        name = "Fireball",
        ids = {38692, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133},
        levels = {70, 66, 60, 54, 48, 42, 36, 30, 24, 18, 12, 6, 3, 1},
        cast_time = 3.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Flamestrike = NS.spell_action({
        name = "Flamestrike",
        ids = {27086, 10216, 10215, 8423, 8422, 2121, 2120},
        levels = {64, 56, 48, 40, 32, 24, 16},
        cast_time = 3.0,
        cooldown = 15,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    FlamestrikeRank6 = NS.spell_action({
        name = "FlamestrikeRank6",
        ids = {10216},
        levels = {56},
        cast_time = 3.0,
        cooldown = 15,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Frostbolt = NS.spell_action({
        name = "Frostbolt",
        ids = {27072, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116},
        levels = {69, 60, 56, 50, 44, 38, 32, 26, 20, 14, 8, 4},
        cast_time = 3.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    IceBlock = NS.spell_action({
        name = "IceBlock",
        ids = {45438, 27619, 11958},
        levels = {30},
        cast_time = 0,
        cooldown = 300,
        power_cost = 0,
        power_type = "none",
        school = "frost",
    }),
    IceLance = NS.spell_action({
        name = "IceLance",
        ids = {30455},
        levels = {66},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    IcyVeins = NS.spell_action({
        name = "IcyVeins",
        ids = {12472},
        levels = {20},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "frost",
    }),
    MageArmor = NS.spell_action({
        name = "MageArmor",
        ids = {27125, 22783, 22782, 6117},
        levels = {69, 58, 46, 34},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    ManaShield = NS.spell_action({
        name = "ManaShield",
        ids = {27131, 10193, 10192, 10191, 8495, 8494, 1463},
        levels = {68, 60, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    MoltenArmor = NS.spell_action({
        name = "MoltenArmor",
        ids = {30482},
        levels = {62},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "fire",
    }),
    Polymorph = NS.spell_action({
        name = "Polymorph",
        ids = {12826, 12825, 12824, 118},
        levels = {60, 40, 20, 8},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    PresenceOfMind = NS.spell_action({
        name = "PresenceOfMind",
        ids = {12043},
        levels = {40},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "arcane",
    }),
    Pyroblast = NS.spell_action({
        name = "Pyroblast",
        ids = {33938, 27132, 18809, 12526, 12525, 12524, 12523, 12522, 12505, 11366},
        levels = {70, 66, 60, 54, 48, 42, 36, 30, 24, 20},
        cast_time = 6.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Scorch = NS.spell_action({
        name = "Scorch",
        ids = {27074, 27073, 10207, 10206, 10205, 8446, 8445, 8444, 2948},
        levels = {70, 65, 58, 52, 46, 40, 34, 28, 22},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    Slow = NS.spell_action({
        name = "Slow",
        ids = {31589},
        levels = {50},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    WaterElemental = NS.spell_action({
        name = "WaterElemental",
        ids = {31687},
        levels = {50},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    FrostNova = NS.spell_action({
        name = "FrostNova",
        ids = {27088, 10230, 6131, 865, 122},
        levels = {67, 54, 40, 26, 10},
        cast_time = 0,
        cooldown = 25,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    ConeOfCold = NS.spell_action({
        name = "ConeOfCold",
        ids = {27087, 10161, 10160, 10159, 8492, 120},
        levels = {65, 58, 50, 42, 34, 26},
        cast_time = 0,
        cooldown = 10,
        power_cost = 0,
        power_type = "mana",
        school = "frost",
    }),
    ColdSnap = NS.spell_action({
        name = "ColdSnap",
        ids = {11958},
        levels = {48},
        cast_time = 0,
        cooldown = 480,
        power_cost = 0,
        power_type = "none",
        school = "frost",
    }),
}
NS.MageSpells = SPELLS

local config = {
    class_key = "mage",
    class_name = "Mage",
    default_playstyle = "arcane",
    playstyles = {
        { name = "leveling", display_name = "Leveling" },
        { name = "arcane", display_name = "Arcane" },
        { name = "fire", display_name = "Fire" },
        { name = "frost", display_name = "Frost" },
    },
}
NS.rotation_registry:set_class_config(config)

load_child("middleware_sylvanas")
load_child("leveling_sylvanas", true)
load_child("arcane_sylvanas")
load_child("fire_sylvanas")
load_child("frost_sylvanas")
NS.log("Mage class module loaded")
return config
