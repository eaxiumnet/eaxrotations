-- Readability notes:
--   What: Hunter spell table, playstyle config, and child module loader.
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
if not player or player:get_class() ~= enums.class_id.HUNTER then return nil end

local SPELLS = {
    AimedShot = NS.spell_action({ 27065, 20904, 20903, 20902, 20901, 20900, 19434 }, "AimedShot"),
    ArcaneShot = NS.spell_action({ 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    AspectOfTheHawk = NS.spell_action({ 38121, 27045, 25296, 14320, 14319, 14318, 13165 }, "AspectOfTheHawk"),
    AspectOfTheViper = NS.spell_action({ 34074 }, "AspectOfTheViper"),
    BestialWrath = NS.spell_action({ 19574 }, "BestialWrath"),
    CallPet = NS.spell_action({ 883 }, "CallPet"),
    ExplosiveTrap = NS.spell_action({ 27025, 14317, 14316, 13813 }, "ExplosiveTrap"),
    FeignDeath = NS.spell_action({ 5384 }, "FeignDeath"),
    FreezingTrap = NS.spell_action({ 10926, 10925, 10924, 1499 }, "FreezingTrap"),
    HuntersMark = NS.spell_action({ 14325, 14324, 14323, 1130 }, "HuntersMark"),
    KillCommand = NS.spell_action({ 34026 }, "KillCommand"),
    MendPet = NS.spell_action({ 27046, 13544, 13543, 13542, 3662, 3661, 3111, 136 }, "MendPet"),
    MultiShot = NS.spell_action({ 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
    RapidFire = NS.spell_action({ 3045 }, "RapidFire"),
    RevivePet = NS.spell_action({ 982 }, "RevivePet"),
    SerpentSting = NS.spell_action({ 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    SteadyShot = NS.spell_action({ 34120 }, "SteadyShot"),
    ViperSting = NS.spell_action({ 25810, 14279, 14278, 14277, 14276, 3034 }, "ViperSting"),
}
NS.HunterSpells = SPELLS

local config = {
    class_key = "hunter",
    class_name = "Hunter",
    default_playstyle = "beast_mastery",
    playstyles = {
        { name = "beast_mastery", display_name = "Beast Mastery" },
        { name = "marksmanship", display_name = "Marksmanship" },
        { name = "survival", display_name = "Survival" },
    },
}
NS.rotation_registry:set_class_config(config)

local function load_child(name)
    local ok, result = pcall(require, "classes/hunter/" .. name)
    if not ok then NS.log_warning("Hunter module skipped: " .. tostring(name) .. " -> " .. tostring(result)) end
    return ok and result or nil
end

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
load_child("beast_mastery_sylvanas")
load_child("marksmanship_sylvanas")
load_child("survival_sylvanas")
NS.log("Hunter class module loaded")
return config
