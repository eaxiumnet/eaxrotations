-- hunter/class_sylvanas.lua — Hunter class spells, constants, and shared helpers.
-- WHAT:  spell ID tables, stance/form mappings, and class-specific utilities.
-- WHEN:  loaded by all hunter specs; consumed via NS.HunterSpells.
-- WHY:   single source of truth for hunter spell IDs and class constants.
-- SAFETY: nil-guarded lookups; no runtime allocations.

-- Hunter spell table, playstyle config, and child module loader.


local NS = _G.EaxRotations
if not NS then return nil end
local cl = require("shared/class_loader_sylvanas")
local load_child = cl.create_loader("hunter", "Hunter")
local load_spec = cl.create_expansion_loader("hunter", "Hunter")
local enums = cl.get_enums()
local player = NS.GetPlayer and NS.GetPlayer()
local ok_cls, cls_id = pcall(function() return player and player:get_class() end)
if not ok_cls or cls_id ~= enums.class_id.HUNTER then return nil end

local SPELLS = {
    AimedShot = NS.spell_action({
        name = "AimedShot",
        ids = {27065, 20904, 20903, 20902, 20901, 20900, 19434},
        levels = {70, 60, 52, 44, 36, 28, 20},
        cast_time = 2.5,
        cooldown = 6,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    ArcaneShot = NS.spell_action({
        name = "ArcaneShot",
        ids = {27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044},
        levels = {69, 60, 52, 44, 36, 28, 20, 12, 6},
        cast_time = 0,
        cooldown = 6,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    AspectOfTheHawk = NS.spell_action({
        name = "AspectOfTheHawk",
        ids = {27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165},
        levels = {68, 60, 58, 48, 38, 28, 18, 10},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    AspectOfTheCheetah = NS.spell_action({
        name = "AspectOfTheCheetah",
        ids = {5118},
        levels = {20},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    AspectOfTheViper = NS.spell_action({
        name = "AspectOfTheViper",
        ids = {34074},
        levels = {64},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    BestialWrath = NS.spell_action({
        name = "BestialWrath",
        ids = {19574},
        levels = {40},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    Intimidation = NS.spell_action({
        name = "Intimidation",
        ids = {19577},
        levels = {30},
        cast_time = 0,
        cooldown = 60,
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
        levels = {61, 54, 44, 34},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "none",
        school = "fire",
    }),
    FeignDeath = NS.spell_action({
        name = "FeignDeath",
        ids = {5384},
        levels = {30},
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
        cooldown = 30,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    HuntersMark = NS.spell_action({
        name = "HuntersMark",
        ids = {14325, 14324, 14323, 1130},
        levels = {58, 40, 22, 6},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    KillCommand = NS.spell_action({
        name = "KillCommand",
        ids = {34026},
        levels = {66},
        cast_time = 0,
        cooldown = 5,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    MendPet = NS.spell_action({
        name = "MendPet",
        ids = {27046, 13544, 13543, 13542, 3662, 3661, 3111, 136},
        levels = {68, 60, 52, 44, 36, 28, 20, 12},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    MultiShot = NS.spell_action({
        name = "MultiShot",
        ids = {27021, 25294, 14290, 14289, 14288, 2643},
        levels = {67, 60, 54, 42, 30, 18},
        cast_time = 0.5,
        cooldown = 10,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    RapidFire = NS.spell_action({ 3045 }, "RapidFire"),
    Readiness = NS.spell_action({ 23989 }, "Readiness"),
    TrueshotAura = NS.spell_action({ 19506, 20905, 20906 }, "TrueshotAura"),
    RevivePet = NS.spell_action({
        name = "RevivePet",
        ids = {982},
        levels = {10},
        cast_time = 10.0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    ScareBeast = NS.spell_action({
        name = "ScareBeast",
        ids = {14327, 14326, 1513},
        levels = {46, 30, 14},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "nature",
        cc_type = "fear",
    }),
    SnakeTrap = NS.spell_action({
        name = "SnakeTrap",
        ids = {34600},
        levels = {68},
        cast_time = 0,
        cooldown = 30,
        power_cost = 305,
        power_type = "mana",
        school = "nature",
    }),
    SerpentSting = NS.spell_action({
        name = "SerpentSting",
        ids = {27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978},
        levels = {67, 60, 58, 50, 42, 34, 26, 18, 10, 4},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "nature",
    }),
    SteadyShot = NS.spell_action({
        name = "SteadyShot",
        ids = {34120},
        levels = {62},
        cast_time = 1.5,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    ViperSting = NS.spell_action({
        name = "ViperSting",
        ids = {27018, 14280, 14279, 3034},
        levels = {66, 56, 46, 36},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "nature",
    }),
    WyvernSting = NS.spell_action({
        name = "WyvernSting",
        ids = {27068, 24133, 24132, 19386},
        levels = {70, 60, 50, 40},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "nature",
    }),
    ConcussiveShot = NS.spell_action({
        name = "ConcussiveShot",
        ids = {5116},
        levels = {8},
        cast_time = 0,
        cooldown = 12,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    Misdirection = NS.spell_action({
        name = "Misdirection",
        ids = {34477},
        levels = {70},
        cast_time = 0,
        cooldown = 120,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    })
    ,
    SilencingShot = NS.spell_action({
        name = "SilencingShot",
        ids = {34490},
        levels = {30},
        cast_time = 0,
        cooldown = 20,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    Volley = NS.spell_action({
        name = "Volley",
        ids = {27022, 14295, 14294, 1510},
        levels = {67, 58, 50, 40},
        cast_time = 0.5,
        cooldown = 10,
        power_cost = 0,
        power_type = "mana",
        school = "arcane",
    }),
    ScatterShot = NS.spell_action({
        name = "ScatterShot",
        ids = {19503},
        levels = {20},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    ScorpidSting = NS.spell_action({
        name = "ScorpidSting",
        ids = {3043},
        levels = {22},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "nature",
    }),
    RaptorStrike = NS.spell_action({
        name = "RaptorStrike",
        ids = {27014, 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973},
        levels = {63, 56, 48, 40, 32, 24, 16, 8, 1},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    WingClip = NS.spell_action({
        name = "WingClip",
        ids = {14268, 14267, 2974},
        levels = {60, 38, 12},
        cast_time = 0,
        cooldown = 0,
        power_cost = 0,
        power_type = "mana",
        school = "physical",
    }),
    ImmolationTrap = NS.spell_action({
        name = "ImmolationTrap",
        ids = {29906, 27023, 14299, 14298, 13795},
        levels = {70, 60, 50, 40, 30},
        cast_time = 0,
        cooldown = 30,
        power_cost = 0,
        power_type = "mana",
        school = "fire",
    }),
    MongooseBite = NS.spell_action({
        name = "MongooseBite",
        -- DBC-verified ranks 1-4 (1495/14269/14270/14271 @ lvl 16/26/38/50).
        -- Was: {25285, 14271, ...} with a level-62 entry — 25285 is an item ID,
        -- not a spell, and Mongoose Bite has no rank 5. Audit caught it.
        ids = {14271, 14270, 14269, 1495},
        levels = {50, 38, 26, 16},
        cast_time = 0,
        cooldown = 5,
        power_cost = 0,
        power_type = "none",
        school = "physical",
    }),
    UnavailableClassicHunterShotA = nil,
    UnavailableClassicHunterShotB = nil,
    UnavailableClassicHunterAspect = nil,
    UnavailableClassicHunterInterrupt = nil,
    UnavailableClassicHunterThreat = nil,
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
            local player = NS.GetPlayer and NS.GetPlayer()
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
load_child("cliptracker_sylvanas", true)
load_spec("leveling", true)
-- Register the Auto Shot spell-cast callback so cliptracker timing stays accurate.
-- Must happen AFTER loading cliptracker_sylvanas (so NS.HunterClipTracker exists).
register_auto_shot_callback()
-- Also initialize hunter_core auto-shot tracking (used by Beast Mastery).
local hc_ok, hunter_core = pcall(require, "shared/hunter_core_sylvanas")
if hc_ok and type(hunter_core) == "table" and type(hunter_core.init) == "function" then
    pcall(hunter_core.init)
end
-- Load adaptive rotation engine (wowsims-derived DPS optimizer)
require("shared/hunter_adaptive_sylvanas")

--- Adaptive rotation integration: returns a match function that can be inserted
--- into any hunter spec's strategy table. When enabled, replaces threshold-based
--- shot selection with DPS-math-optimal choices from the wowsims engine.
--- Returns "(context) -> bool" suitable for a strategy table entry.
function NS.create_adaptive_rotation_strategy(target_func)
    return function(context)
        if not NS.HunterAdaptive then return false end
        if not spec_kit.setting_bool(context, "use_adaptive_rotation", false) then return false end
        if not context.in_combat then return false end
        if not context.target then return false end
        local target = (target_func and target_func(context)) or context.target
        if not target then return false end
        local s = context.settings or {}
        local choice = NS.HunterAdaptive.ChooseAction(target, {
            useMulti = s.multishot_mode and s.multishot_mode > 0,
            useArcane = true,
            manaSaveFloor = s.mana_save or 30,
            arcaneManaFloor = 15,
        })
        if choice == NS.HunterAdaptive.OPT_SHOOT then
            -- Auto Shot — handled by the engine, cast mechanism handles it
            return false  -- fall through; auto-shot is passive
        elseif choice == NS.HunterAdaptive.OPT_STEADY then
            return NS.try_cast(NS.HunterSpells.SteadyShot, target, "[ADAPTIVE] Steady Shot")
        elseif choice == NS.HunterAdaptive.OPT_MULTI then
            return NS.try_cast(NS.HunterSpells.MultiShot, target, "[ADAPTIVE] Multi-Shot")
        elseif choice == NS.HunterAdaptive.OPT_ARCANE then
            return NS.try_cast(NS.HunterSpells.ArcaneShot, target, "[ADAPTIVE] Arcane Shot")
        end
        return false  -- adaptive chose "none", fall through
    end
end
load_spec("beast_mastery")
load_spec("marksmanship")
load_spec("survival")
-- class module initialized
return config
