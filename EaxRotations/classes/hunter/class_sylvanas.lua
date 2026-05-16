-- Hunter spell table, playstyle config, and child module loader.

local NS = _G.EaxRotations
if not NS then return nil end
local cl = require("shared/class_loader_sylvanas")
local load_child = cl.create_loader("hunter", "Hunter")
local enums = cl.get_enums()
local player = NS.GetPlayer()
if not player or player:get_class() ~= enums.class_id.HUNTER then return nil end

local SPELLS = {
    AimedShot = NS.spell_action({
        name = "AimedShot",
        ids = {27065, 20904, 20903, 20902, 20901, 20900, 19434},
        levels = {70, 62, 54, 46, 40, 34, 28},
        cast_time = 3.0,
        cooldown = 6,
        power_cost = 0,
        power_type = "focus",
        school = "physical",
    }),
    ArcaneShot = NS.spell_action({
        name = "ArcaneShot",
        ids = {27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044},
        levels = {70, 60, 50, 42, 34, 28, 22, 16, 6},
        cast_time = 0,
        cooldown = 6,
        power_cost = 0,
        power_type = "focus",
        school = "arcane",
    }),
    AspectOfTheHawk = NS.spell_action({
        name = "AspectOfTheHawk",
        ids = {27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165},
        levels = {70, 64, 58, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    AspectOfTheViper = NS.spell_action({
        name = "AspectOfTheViper",
        ids = {34074},
        levels = {62},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    BestialWrath = NS.spell_action({
        name = "BestialWrath",
        ids = {19574},
        levels = {50},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    CallPet = NS.spell_action({
        name = "CallPet",
        ids = {883},
        levels = {10},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    ExplosiveTrap = NS.spell_action({
        name = "ExplosiveTrap",
        ids = {27025, 14317, 14316, 13813},
        levels = {70, 60, 50, 40},
        cast_time = 0,
        cooldown = 15,
        power_cost = 0,
        power_type = "none",
        school = "fire",
    }),
    FeignDeath = NS.spell_action({
        name = "FeignDeath",
        ids = {5384},
        levels = {32},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    FreezingTrap = NS.spell_action({
        name = "FreezingTrap",
        ids = {14311, 14310, 1499},
        levels = {60, 40, 20},
        cast_time = 0,
        cooldown = 15,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    HuntersMark = NS.spell_action({
        name = "HuntersMark",
        ids = {14325, 14324, 14323, 1130},
        levels = {62, 54, 44, 4},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    KillCommand = NS.spell_action({
        name = "KillCommand",
        ids = {34026},
        levels = {62},
        cast_time = 0,
        cooldown = 5,
        power_cost = 0,
        power_type = "focus",
        school = "physical",
    }),
    MendPet = NS.spell_action({
        name = "MendPet",
        ids = {27046, 13544, 13543, 13542, 3662, 3661, 3111, 136},
        levels = {70, 64, 58, 52, 44, 36, 28, 20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "focus",
        school = "physical",
    }),
    MultiShot = NS.spell_action({ 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),	    RapidFire = NS.spell_action({ 3045 }, "RapidFire"),
	    Readiness = NS.spell_action({ 23989 }, "Readiness"),
    RevivePet = NS.spell_action({
        name = "RevivePet",
        ids = {982},
        levels = {10},
        cast_time = 2.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    SerpentSting = NS.spell_action({
        name = "SerpentSting",
        ids = {27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978},
        levels = {70, 64, 56, 48, 40, 32, 24, 16, 8, 4},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "focus",
        school = "nature",
    }),
    SteadyShot = NS.spell_action({
        name = "SteadyShot",
        ids = {34120},
        levels = {62},
        cast_time = 2.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "focus",
        school = "physical",
    }),
    ViperSting = NS.spell_action({
        name = "ViperSting",
        ids = {27018, 14280, 14279, 3034},
        levels = {68, 60, 40, 36},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "focus",
        school = "nature",
    }),
}
NS.HunterSpells = SPELLS

local config = {
    class_key = "hunter",
    class_name = "Hunter",
    default_playstyle = "beast_mastery",
    playstyles = {
        { name = "leveling", display_name = "Leveling" },
        { name = "beast_mastery", display_name = "Beast Mastery" },
        { name = "marksmanship", display_name = "Marksmanship" },
        { name = "survival", display_name = "Survival" },
    },
}
NS.rotation_registry:set_class_config(config)

local function register_auto_shot_callback()
    if NS._hunter_auto_shot_callback_registered then return end
    if type(NS.register_on_spell_cast) ~= "function" then return end

    local ok = NS.register_on_spell_cast(function(spell_id, _, data)
        if spell_id ~= 75 then return end

        local caster = type(data) == "table" and data.caster or nil
        if caster then
            local player = NS.GetPlayer and NS.GetPlayer() or nil
            if player then
                if caster ~= player then
                    local caster_name, player_name
                    pcall(function() caster_name = caster.get_name and caster:get_name() end)
                    pcall(function() player_name = player.get_name and player:get_name() end)
                    if not (caster_name and player_name and caster_name == player_name) then
                        return
                    end
                end
            end
        end

        local tracker = NS.HunterClipTracker
        local record = tracker and tracker.record_auto_shot or nil
        if type(record) == "function" then
            local recorded, err = pcall(record)
            if not recorded and NS.log_warning then
                NS.log_warning("Hunter Auto Shot tracker failed: " .. tostring(err))
            end
        end
    end)

    if ok then NS._hunter_auto_shot_callback_registered = true end
end

load_child("middleware_sylvanas")
load_child("cliptracker_sylvanas")
register_auto_shot_callback()
load_child("leveling_sylvanas")
load_child("beast_mastery_sylvanas")
load_child("marksmanship_sylvanas")
load_child("survival_sylvanas")
NS.log("Hunter class module loaded")
return config
