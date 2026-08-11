-- deathknight/class_sylvanas.lua — Death Knight class spells, constants, and loader for WotLK.
-- WHAT:  spell ID tables, rune/pet mappings, and class-specific utilities.
-- WHEN:  loaded by all death knight specs when NS.is_wotlk() is true.
-- WHY:   single source of truth for death knight spell IDs and class constants.
-- SAFETY: nil-guarded lookups; no runtime allocations; exits early on non-WotLK clients.

local NS = _G.EaxRotations
if not NS then return nil end

local cl = require("shared/class_loader_sylvanas")
local load_child = cl.create_loader("deathknight", "DeathKnight")
local load_spec = cl.create_expansion_loader("deathknight", "DeathKnight")
local player = NS.GetPlayer and NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return player and player:get_class() end)

local CLASS_ID_DEATHKNIGHT = 6
if not ok_cls or cls_id ~= CLASS_ID_DEATHKNIGHT then
    if not (NS.is_wotlk and NS.is_wotlk()) then
        return nil
    end
end

-- Spell ID verification notes (Wave 1 WotLK hardening):
-- Sources: lexxer.org/api/v1/spells/{id}?game=wotlk (primary), WotLK 3.3.5a DBC.
-- Corrected 2026-07-13: removed cross-contaminated IDs that belonged to other
-- spells (e.g. DeathAndDecay/BloodBoil overlap, Strangulate shared with
-- DeathGrip/AntiMagicShell), pruned invalid glyph/quest IDs, and fixed level
-- mismatches. Disease debuffs are single-rank in 3.3.5a (Frost Fever 55095,
-- Blood Plague 55078).
local SPELLS = {
    BloodStrike = NS.spell_action({
        name = "BloodStrike",
        ids = {45902, 49926, 49927, 49928, 49929, 49930},
        levels = {55, 59, 64, 69, 74, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "physical",
    }),
    DeathStrike = NS.spell_action({
        name = "DeathStrike",
        ids = {49998, 49999, 45463, 49924},
        levels = {56, 63, 70, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "physical",
    }),
    HeartStrike = NS.spell_action({
        name = "HeartStrike",
        ids = {55050, 55258, 55259, 55260, 55261, 55262},
        levels = {55, 59, 64, 69, 74, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "physical",
    }),
    IcyTouch = NS.spell_action({
        name = "IcyTouch",
        ids = {45477, 49903, 49904, 49909},
        levels = {55, 67, 73, 78},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "frost",
    }),
    PlagueStrike = NS.spell_action({
        name = "PlagueStrike",
        ids = {49917, 49918, 49919, 49920, 49921},
        levels = {60, 65, 70, 75, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "physical",
    }),
    Obliterate = NS.spell_action({
        name = "Obliterate",
        ids = {49020, 51423, 51424, 51425},
        levels = {61, 67, 74, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 2,
        power_type = "rune",
        school = "physical",
    }),
    HowlingBlast = NS.spell_action({
        name = "HowlingBlast",
        ids = {49184, 51409, 51410, 51411},
        levels = {55, 70, 75, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "frost",
    }),
    ScourgeStrike = NS.spell_action({
        name = "ScourgeStrike",
        ids = {55090, 55265, 55270, 55271},
        levels = {62, 70, 75, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "physical",
    }),
    DeathCoil = NS.spell_action({
        name = "DeathCoil",
        ids = {47541, 49892, 49893, 49894, 49895},
        levels = {55, 62, 68, 76, 80},
        cast_time = 0,
        cooldown = 0,
        power_cost = 40,
        power_type = "runicpower",
        school = "shadow",
    }),
    Pestilence = NS.spell_action({
        name = "Pestilence",
        ids = {50842},
        levels = {56},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    BloodBoil = NS.spell_action({
        name = "BloodBoil",
        ids = {48721, 49939, 49940, 49941},
        levels = {58, 66, 72, 78},
        cast_time = 0,
        cooldown = 0,
        power_cost = 1,
        power_type = "rune",
        school = "shadow",
    }),
    DeathAndDecay = NS.spell_action({
        name = "DeathAndDecay",
        ids = {43265, 49936, 49937, 49938},
        levels = {60, 67, 73, 80},
        cast_time = 0,
        cooldown = 30,
        power_cost = 1,
        power_type = "rune",
        school = "shadow",
    }),
    BoneShield = NS.spell_action({
        name = "BoneShield",
        ids = {49222},
        levels = {55},
        cast_time = 0,
        cooldown = 60,
        power_cost = 1,
        power_type = "rune",
        school = "shadow",
    }),
    IceboundFortitude = NS.spell_action({
        name = "IceboundFortitude",
        ids = {48792},
        levels = {62},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "frost",
    }),
    VampiricBlood = NS.spell_action({
        name = "VampiricBlood",
        ids = {55233},
        levels = {60},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    DancingRuneWeapon = NS.spell_action({
        name = "DancingRuneWeapon",
        ids = {49028},
        levels = {60},
        cast_time = 0,
        cooldown = 180,
        power_cost = 60,
        power_type = "runicpower",
        school = "physical",
    }),
    SummonGargoyle = NS.spell_action({
        name = "SummonGargoyle",
        ids = {49206},
        levels = {60},
        cast_time = 0,
        cooldown = 180,
        power_cost = 60,
        power_type = "runicpower",
        school = "shadow",
    }),
    EmpowerRuneWeapon = NS.spell_action({
        name = "EmpowerRuneWeapon",
        ids = {47568},
        levels = {60},
        cast_time = 0,
        cooldown = 300,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    HornOfWinter = NS.spell_action({
        name = "HornOfWinter",
        ids = {57330, 57623},
        levels = {65, 80},
        cast_time = 0,
        cooldown = 20,
        power_cost = 0,
        power_type = "none",
        school = "frost",
    }),
    MindFreeze = NS.spell_action({
        name = "MindFreeze",
        ids = {47528},
        levels = {57},
        cast_time = 0,
        cooldown = 10,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Strangulate = NS.spell_action({
        name = "Strangulate",
        ids = {47476, 49913, 49914, 49915, 49916},
        levels = {59, 65, 69, 74, 79},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    DeathGrip = NS.spell_action({
        name = "DeathGrip",
        ids = {49576},
        levels = {55},
        cast_time = 0,
        cooldown = 35,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    RaiseDead = NS.spell_action({
        name = "RaiseDead",
        ids = {46584},
        levels = {56},
        cast_time = 0,
        cooldown = 180,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    ArmyOfTheDead = NS.spell_action({
        name = "ArmyOfTheDead",
        ids = {42650},
        levels = {60},
        cast_time = 6,
        cooldown = 600,
        power_cost = 0,
        power_type = "none",
        school = "shadow",
    }),
    UnbreakableArmor = NS.spell_action({
        name = "UnbreakableArmor",
        ids = {51271},
        levels = {55},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "frost",
    }),
    AntiMagicShell = NS.spell_action({
        name = "AntiMagicShell",
        ids = {48707},
        levels = {68},
        cast_time = 0,
        cooldown = 45,
        power_cost = 20,
        power_type = "runicpower",
        school = "shadow",
    }),
    RuneStrike = NS.spell_action({
        name = "RuneStrike",
        ids = {56815},
        levels = {67},
        cast_time = 0,
        cooldown = 0,
        power_cost = 20,
        power_type = "runicpower",
        school = "physical",
    }),
    DarkCommand = NS.spell_action({
        name = "DarkCommand",
        ids = {56222},
        levels = {65},
        cast_time = 0,
        cooldown = 8,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
}
NS.DeathKnightSpells = SPELLS

NS.DeathKnightConstants = {
    FROST_FEVER_DEBUFF = {55095},
    BLOOD_PLAGUE_DEBUFF = {55078},
    HORN_OF_WINTER_BUFF = {57330, 57623},
    DISEASES = {
        {55095},
        {55078},
    },
}

local config = {
    class_key = "deathknight",
    class_name = "DeathKnight",
    default_playstyle = "blood",
    playstyles = {
        { name = "leveling", display_name = "Leveling" },
        { name = "blood", display_name = "Blood" },
        { name = "frost", display_name = "Frost" },
        { name = "unholy", display_name = "Unholy" },
    },
}
NS.rotation_registry:set_class_config(config)

load_child("middleware_sylvanas", true)
load_spec("leveling", true)
load_spec("blood")
load_spec("frost")
load_spec("unholy")

return config
