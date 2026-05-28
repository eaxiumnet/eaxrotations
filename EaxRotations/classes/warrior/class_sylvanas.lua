-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/warrior/class_sylvanas.lua"
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
-- Warrior spell table, playstyle config, and child module loader.
-- ============================================================================
-- What: TBC Warrior spell table and class bootstrap for all warrior playstyles
-- When: Load time
-- Why: Centralizes spell objects and child registration before playstyle modules load
-- Safety: Class check gates loading; shared loader handles children; nil-guarded player lookup
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local cl = require("shared/class_loader_sylvanas")
local load_child = cl.create_loader("warrior", "Warrior")
local enums = cl.get_enums()
local player = NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return player and player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.WARRIOR then return nil end

local SPELLS = {
    BattleShout = NS.spell_action({
        name = "BattleShout",
        ids = {2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673},
        levels = {69, 60, 52, 42, 32, 22, 12, 1},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    BattleStance = NS.spell_action({
        name = "BattleStance",
        ids = {2457},
        levels = {1},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    BerserkerRage = NS.spell_action({
        name = "BerserkerRage",
        ids = {18499},
        levels = {32},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    BerserkerStance = NS.spell_action({
        name = "BerserkerStance",
        ids = {2458},
        levels = {30},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Bloodrage = NS.spell_action({
        name = "Bloodrage",
        ids = {2687},
        levels = {10},
        cast_time = 0,
        cooldown = 60,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Bloodthirst = NS.spell_action({
        name = "Bloodthirst",
        ids = {30335, 25251, 23894, 23893, 23892, 23881},
        levels = {70, 66, 60, 54, 48, 40},
        cast_time = 0,
        cooldown = 6,
        power_cost = 30,
        power_type = "rage",
        school = "physical",
    }),
    ChallengingShout = NS.spell_action({
        name = "ChallengingShout",
        ids = {1161},
        levels = {58},
        cast_time = 0,
        cooldown = 600,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Charge = NS.spell_action({
        name = "Charge",
        ids = {11578, 6178, 100},
        levels = {46, 26, 4},
        cast_time = 0,
        cooldown = 15,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Cleave = NS.spell_action({
        name = "Cleave",
        ids = {25231, 20569, 11609, 11608, 7369, 845},
        levels = {68, 60, 50, 40, 30, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 20,
        power_type = "rage",
        school = "physical",
    }),
    CommandingShout = NS.spell_action({
        name = "CommandingShout",
        ids = {469},
        levels = {68},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    ConcussionBlow = NS.spell_action({
        name = "ConcussionBlow",
        ids = {12809},
        levels = {44},
        cast_time = 0,
        cooldown = 30,
        power_cost = 15,
        power_type = "rage",
        school = "physical",
    }),
    DeathWish = NS.spell_action({
        name = "DeathWish",
        ids = {12292},
        levels = {50},
        cast_time = 0,
        cooldown = 180,
        power_cost = 10,
        power_type = "rage",
        school = "physical",
    }),
    DefensiveStance = NS.spell_action({
        name = "DefensiveStance",
        ids = {71},
        levels = {10},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    DemoralizingShout = NS.spell_action({
        name = "DemoralizingShout",
        ids = {25203, 25202, 11556, 11555, 11554, 6190, 1160},
        levels = {70, 62, 54, 44, 34, 24, 14},
        cast_time = 0,
        cooldown = 0,
        power_cost = 10,
        power_type = "rage",
        school = "physical",
    }),
    Devastate = NS.spell_action({
        name = "Devastate",
        ids = {30022, 30016, 20243},
        levels = {70, 62, 50},
        cast_time = 0,
        cooldown = 0,
        power_cost = 15,
        power_type = "rage",
        school = "physical",
    }),
    Disarm = NS.spell_action({
        name = "Disarm",
        ids = {676},
        levels = {18},
        cast_time = 0,
        cooldown = 60,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Execute = NS.spell_action({
        name = "Execute",
        ids = {25236, 25234, 20662, 20661, 20660, 20658, 5308},
        levels = {70, 65, 56, 48, 40, 32, 24},
        cast_time = 0,
        cooldown = 0,
        power_cost = 15,
        power_type = "rage",
        school = "physical",
    }),
    VictoryRush = NS.spell_action({
        name = "VictoryRush",
        ids = {34428},
        levels = {62},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    IntimidatingShout = NS.spell_action({
        name = "IntimidatingShout",
        ids = {5246},
        levels = {22},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    HeroicStrike = NS.spell_action({
        name = "HeroicStrike",
        ids = {30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78},
        levels = {70, 66, 60, 56, 48, 40, 32, 24, 16, 8, 1},
        cast_time = 0,
        cooldown = 0,
        power_cost = 15,
        power_type = "rage",
        school = "physical",
    }),
    Hamstring = NS.spell_action({
        name = "Hamstring",
        ids = {25212, 7373, 7372, 1715},
        levels = {67, 54, 32, 8},
        cast_time = 0,
        cooldown = 0,
        power_cost = 10,
        power_type = "rage",
        school = "physical",
    }),
    Intercept = NS.spell_action({
        name = "Intercept",
        ids = {25275, 20617, 20616, 20252},
        levels = {69, 52, 42, 30},
        cast_time = 0,
        cooldown = 30,
        power_cost = 10,
        power_type = "rage",
        school = "physical",
    }),
    Pummel = NS.spell_action({
        name = "Pummel",
        ids = {6552},
        levels = {38},
        cast_time = 0,
        cooldown = 10,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    LastStand = NS.spell_action({
        name = "LastStand",
        ids = {12975},
        levels = {50},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    MockingBlow = NS.spell_action({
        name = "MockingBlow",
        ids = {20560, 20559, 7400, 694},
        levels = {56, 46, 26, 16},
        cast_time = 0,
        cooldown = 120,
        power_cost = 10,
        power_type = "rage",
        school = "physical",
    }),
    MortalStrike = NS.spell_action({
        name = "MortalStrike",
        ids = {30330, 25248, 21553, 21552, 21551, 12294},
        levels = {70, 66, 60, 54, 48, 40},
        cast_time = 0,
        cooldown = 6,
        power_cost = 30,
        power_type = "rage",
        school = "physical",
    }),
    Overpower = NS.spell_action({
        name = "Overpower",
        ids = {11585, 7887, 7384},
        levels = {60, 28, 12},
        cast_time = 0,
        cooldown = 5,
        power_cost = 5,
        power_type = "rage",
        school = "physical",
    }),
    Rampage = NS.spell_action({
        name = "Rampage",
        ids = {30033, 30030, 29801},
        levels = {70, 60, 50},
        cast_time = 0,
        cooldown = 0,
        power_cost = 30,
        power_type = "rage",
        school = "physical",
    }),
    Rend = NS.spell_action({
        name = "Rend",
        ids = {25208, 11574, 11573, 6548, 6547, 772},
        levels = {68, 60, 50, 30, 20, 4},
        cast_time = 0,
        cooldown = 0,
        power_cost = 10,
        power_type = "rage",
        school = "physical",
    }),
    Revenge = NS.spell_action({
        name = "Revenge",
        ids = {30357, 25269, 25288, 11601, 11600, 7379, 6574, 6572},
        levels = {70, 63, 60, 54, 44, 34, 24, 14},
        cast_time = 0,
        cooldown = 5,
        power_cost = 5,
        power_type = "rage",
        school = "physical",
    }),
    ShieldBlock = NS.spell_action({
        name = "ShieldBlock",
        ids = {2565},
        levels = {16},
        cast_time = 0,
        cooldown = 5,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    ShieldBash = NS.spell_action({
        name = "ShieldBash",
        ids = {1672, 1671, 72},
        levels = {52, 32, 12},
        cast_time = 0,
        cooldown = 12,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    ShieldSlam = NS.spell_action({
        name = "ShieldSlam",
        ids = {30356, 25258, 23925, 23924, 23923, 23922},
        levels = {70, 66, 60, 54, 48, 40},
        cast_time = 0,
        cooldown = 6,
        power_cost = 20,
        power_type = "rage",
        school = "physical",
    }),
    ShieldWall = NS.spell_action({
        name = "ShieldWall",
        ids = {871},
        levels = {28},
        cast_time = 0,
        cooldown = 600,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Slam = NS.spell_action({
        name = "Slam",
        ids = {25242, 25241, 11605, 11604, 8820, 1464},
        levels = {69, 61, 54, 46, 38, 30},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 15,
        power_type = "rage",
        school = "physical",
    }),
    SpellReflection = NS.spell_action({
        name = "SpellReflection",
        ids = {23920},
        levels = {64},
        cast_time = 0,
        cooldown = 10,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    SunderArmor = NS.spell_action({
        name = "SunderArmor",
        ids = {25225, 11597, 11596, 8380, 7405, 7386},
        levels = {67, 58, 46, 34, 22, 10},
        cast_time = 0,
        cooldown = 0,
        power_cost = 15,
        power_type = "rage",
        school = "physical",
    }),
    SweepingStrikes = NS.spell_action({
        name = "SweepingStrikes",
        ids = {12328},
        levels = {40},
        cast_time = 0,
        cooldown = 30,
        power_cost = 30,
        power_type = "rage",
        school = "physical",
    }),
    Taunt = NS.spell_action({
        name = "Taunt",
        ids = {355},
        levels = {10},
        cast_time = 0,
        cooldown = 8,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    ThunderClap = NS.spell_action({
        name = "ThunderClap",
        ids = {25264, 11581, 11580, 8205, 8204, 8198, 6343},
        levels = {67, 58, 48, 38, 28, 18, 6},
        cast_time = 0,
        cooldown = 4,
        power_cost = 20,
        power_type = "rage",
        school = "physical",
    }),

    Whirlwind = NS.spell_action({
        name = "Whirlwind",
        ids = {1680},
        levels = {36},
        cast_time = 0,
        cooldown = 10,
        power_cost = 25,
        power_type = "rage",
        school = "physical",
    }),
}
NS.WarriorSpells = SPELLS

NS.WarriorConstants = {
    STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    BUFF_ID = { SWEEPING_STRIKES = 12328 },
    SUNDER_DEBUFF = { 25225, 11597, 11596, 8380, 7405, 7386 },
    THUNDER_CLAP_DEBUFF = { 25264, 11581, 11580, 8205, 8204, 8198, 6343 },
    DEMO_SHOUT_DEBUFF = { 25203, 25202, 11556, 11555, 11554, 6190, 1160 },
    BATTLE_SHOUT_IDS = { 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 },
    COMMANDING_SHOUT_BUFF = { 469 },
}

local config = {
    class_key = "warrior",
    class_name = "Warrior",
    default_playstyle = "arms",
    playstyles = {
        { name = "leveling", display_name = "Leveling" },
        { name = "arms", display_name = "Arms" },
        { name = "fury", display_name = "Fury" },
        { name = "kebab", display_name = "Kebab" },
        { name = "protection", display_name = "Protection" },
    },
}
NS.rotation_registry:set_class_config(config)

load_child("middleware_sylvanas")
load_child("leveling_sylvanas", true)
load_child("arms_sylvanas")
load_child("fury_sylvanas")
load_child("kebab_sylvanas", true)
load_child("protection_sylvanas")
NS.log("Warrior class module loaded")
return config
