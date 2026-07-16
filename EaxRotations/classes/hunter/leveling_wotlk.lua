-- leveling_wotlk.lua — Hunter leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for hunter leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple shot rotation with pet cooldowns.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local pet_manager = require("shared/pet_manager_sylvanas")
local SPELLS = NS.HunterSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    HuntersMark = define("HuntersMark", { 14325, 14324, 14323, 1130 }, "HuntersMark"),
    SerpentSting = define("SerpentSting", { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }, "SerpentSting"),
    SteadyShot = define("SteadyShot", 34120, "SteadyShot"),
    ArcaneShot = define("ArcaneShot", { 27019, 14287, 14286, 14285, 14284, 14283, 14282, 14281, 3044 }, "ArcaneShot"),
    KillCommand = define("KillCommand", 34026, "KillCommand"),
    BestialWrath = define("BestialWrath", 19574, "BestialWrath"),
    SilencingShot = define("SilencingShot", 34490, "SilencingShot"),
    AspectOfTheDragonhawk = define("AspectOfTheDragonhawk", 61847, "AspectOfTheDragonhawk"),
    AspectOfTheHawk = define("AspectOfTheHawk", { 27044, 25296, 14322, 14321, 14320, 13165 }, "AspectOfTheHawk"),
    AspectOfTheViper = define("AspectOfTheViper", 34074, "AspectOfTheViper"),
    CallPet = define("CallPet", 883, "CallPet"),
    RevivePet = define("RevivePet", 982, "RevivePet"),
    -- Mend Pet ranks (lexxer); removed invalid 13539-43/1515 (1515 is Tame Beast).
    MendPet = define("MendPet", { 48990, 48989, 27046, 13544, 13543, 13542, 3662, 3661, 3111 }, "MendPet"),
    MultiShot = define("MultiShot", { 49048, 49047, 27021, 25294, 14290, 14289, 14288, 2643 }, "MultiShot"),
    Volley = define("Volley", { 58434, 58433, 42243, 27022, 1543 }, "Volley"),
}

local DRAGONHAWK_BUFF = { 61847 }
local HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 13165 }
local VIPER_BUFF = { 34074 }

local SERPENT_STING_DEBUFF = { 49001, 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_DEBUFF = { 14325, 14324, 14323, 1130 }

local hunter_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    serpent_remains = 0,
    mark_remains = 0,
    bestial_wrath_ready = false,
    target_casting = false,
    dps_aspect_up = false,
    viper_up = false,
    pet_alive = false,
    has_pet = false,
    pet_hp = 100,
}

local function build_state(context)
    local state = spec_kit.safe_state(hunter_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.serpent_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SERPENT_STING_DEBUFF)) or 0
    state.mark_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HUNTERS_MARK_DEBUFF)) or 0
    state.bestial_wrath_ready = (ACTION.BestialWrath and ACTION.BestialWrath.cooldown_remaining and ACTION.BestialWrath:cooldown_remaining() <= 0) or false
    state.target_casting = helpers.should_interrupt(target)
    state.dps_aspect_up = (me and NS.buff_up and (NS.buff_up(me, DRAGONHAWK_BUFF) or NS.buff_up(me, HAWK_BUFF))) or false
    state.viper_up = (me and NS.buff_up and NS.buff_up(me, VIPER_BUFF)) or false
    local pet = pet_manager.get_pet(me)
    state.has_pet = pet ~= nil
    state.pet_alive = pet_manager.pet_alive(pet)
    state.pet_hp = (state.pet_alive and pet_manager.pet_hp_pct(pet)) or 100
    return state
end

local function silencing_shot_matches(context, state)
    -- Silencing Shot is an interrupt: only fire when the target is actually casting.
    return state.in_combat and state.target_casting == true and state.mana_pct >= 6
end

local function aspect_of_the_viper_matches(context, state)
    -- Mana recovery stance: swap to Viper when low, hysteresis vs dps-aspect switch-back.
    return not state.viper_up and state.mana_pct < 20
end

local function dps_aspect_matches(context, state)
    -- Establish/return to Hawk/Dragonhawk once mana recovers past the hysteresis gap.
    return not state.dps_aspect_up and state.mana_pct >= 40
end

local function call_pet_matches(context, state)
    return not state.in_combat and not state.has_pet
end

local function revive_pet_matches(context, state)
    return not state.in_combat and state.has_pet and not state.pet_alive
end

local function mend_pet_matches(context, state)
    return state.pet_alive and state.pet_hp < 80 and state.mana_pct >= 10
end

local function hunters_mark_matches(context, state)
    return state.in_combat and state.mark_remains < 3 and state.mana_pct >= 10
end

local function bestial_wrath_matches(context, state)
    return state.in_combat and state.bestial_wrath_ready
end

local function kill_command_matches(context, state)
    return state.in_combat and state.mana_pct >= 15
end

local function serpent_sting_matches(context, state)
    return state.in_combat and state.serpent_remains < 3 and state.mana_pct >= 15
end

local function multi_shot_matches(context, state)
    return state.in_combat and state.mana_pct >= 9
        and NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context and context.target, context)
end

local function volley_matches(context, state)
    return state.in_combat and state.mana_pct >= 17
        and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.GROUND_8) or 8, context and context.target, context, state)
end

local function arcane_shot_matches(context, state)
    return state.in_combat and state.mana_pct >= 20
end

local function steady_shot_matches(context, state)
    return state.in_combat and state.mana_pct >= 10
end

local strategies = {
    { name = "SilencingShot", matches = silencing_shot_matches, execute = function(ctx) return ACTION.SilencingShot and ACTION.SilencingShot:cast_safe(ctx.target) end },
    { name = "AspectOfTheViper", matches = aspect_of_the_viper_matches, execute = function(ctx) return ACTION.AspectOfTheViper and ACTION.AspectOfTheViper:cast_safe() end },
    { name = "DpsAspect", matches = dps_aspect_matches, execute = function(ctx) return (ACTION.AspectOfTheDragonhawk and ACTION.AspectOfTheDragonhawk:cast_safe()) or (ACTION.AspectOfTheHawk and ACTION.AspectOfTheHawk:cast_safe()) end },
    { name = "CallPet", matches = call_pet_matches, execute = function(ctx) return ACTION.CallPet and ACTION.CallPet:cast_safe() end },
    { name = "RevivePet", matches = revive_pet_matches, execute = function(ctx) return ACTION.RevivePet and ACTION.RevivePet:cast_safe() end },
    { name = "MendPet", matches = mend_pet_matches, execute = function(ctx) return ACTION.MendPet and ACTION.MendPet:cast_safe() end },
    { name = "HuntersMark", matches = hunters_mark_matches, execute = function(ctx) return ACTION.HuntersMark and ACTION.HuntersMark:cast_safe(ctx.target) end },
    { name = "Volley", matches = volley_matches, execute = function(ctx) return ACTION.Volley and ACTION.Volley:cast_safe(ctx.target) end },
    { name = "MultiShot", matches = multi_shot_matches, execute = function(ctx) return ACTION.MultiShot and ACTION.MultiShot:cast_safe(ctx.target) end },
    { name = "BestialWrath", matches = bestial_wrath_matches, execute = function(ctx) return ACTION.BestialWrath and ACTION.BestialWrath:cast_safe() end },
    { name = "KillCommand", matches = kill_command_matches, execute = function(ctx) return ACTION.KillCommand and ACTION.KillCommand:cast_safe(ctx.target) end },
    { name = "SerpentSting", matches = serpent_sting_matches, execute = function(ctx) return ACTION.SerpentSting and ACTION.SerpentSting:cast_safe(ctx.target) end },
    { name = "ArcaneShot", matches = arcane_shot_matches, execute = function(ctx) return ACTION.ArcaneShot and ACTION.ArcaneShot:cast_safe(ctx.target) end },
    { name = "SteadyShot", matches = steady_shot_matches, execute = function(ctx) return ACTION.SteadyShot and ACTION.SteadyShot:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
