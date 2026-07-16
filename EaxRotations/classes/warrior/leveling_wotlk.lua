-- leveling_wotlk.lua — Warrior leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for warrior leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple rage-based rotation using core leveling abilities.
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
local SPELLS = NS.WarriorSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BattleShout = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    Charge = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Rend = define("Rend", { 47465, 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    HeroicStrike = define("HeroicStrike", { 47497, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Overpower = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),
    Execute = define("Execute", { 47498, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    ThunderClap = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    VictoryRush = define("VictoryRush", 34428, "VictoryRush"),
    Pummel = define("Pummel", 6552, "Pummel"),
    BattleStance = define("BattleStance", 2457, "BattleStance"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
    Cleave = define("Cleave", { 47520, 25231, 20569, 11609, 11608, 7369, 845 }, "Cleave"),
}

local REND_DEBUFF = { 47465, 25208, 11574, 11573, 6548, 6547, 772 }
local BATTLE_SHOUT_BUFF = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local BATTLE_STANCE_BUFF = { 2457 }

local warrior_state = {
    hp = 100,
    target_hp = 100,
    rage = 0,
    enemy_count = 1,
    in_combat = false,
    rend_remains = 0,
    battle_shout_up = false,
    battle_stance_up = false,
    target_casting = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(warrior_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.rage = (me and me.get_rage and me:get_rage()) or 0
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    state.rend_remains = (target and NS.debuff_remains and NS.debuff_remains(target, REND_DEBUFF)) or 0
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false
    state.battle_stance_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_STANCE_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    return state
end

local function battle_stance_matches(context, state)
    -- Default leveling stance: enables Charge and the Battle-stance ability set.
    -- Only correct stance out of combat so we don't fight the combat rotation.
    return not state.in_combat and not state.battle_stance_up
end

local function pummel_matches(context, state)
    return state.in_combat and state.target_casting == true and state.rage >= 10
end

local function battle_shout_matches(context, state)
    return not state.in_combat and not state.battle_shout_up
end

local function charge_matches(context, state)
    return not state.in_combat
end

local function rend_matches(context, state)
    return state.in_combat and state.rend_remains < 3
end

local function overpower_matches(context, state)
    return state.in_combat
end

local function execute_matches(context, state)
    return state.in_combat and state.target_hp < 20 and state.rage >= 10
end

local function thunder_clap_matches(context, state)
    return state.in_combat and state.rage >= 20
        and NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
end

local function whirlwind_matches(context, state)
    return state.in_combat and state.rage >= 25
        and NS.aoe_self_meets and NS.aoe_self_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8, context, state)
end

local function cleave_matches(context, state)
    return state.in_combat and state.rage >= 20
        and NS.aoe_target_meets and NS.aoe_target_meets(2, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8, context and context.target, context, state)
end

local function victory_rush_matches(context, state)
    return state.in_combat
end

local function heroic_strike_matches(context, state)
    return state.in_combat and state.rage >= 30
end

local strategies = {
    { name = "Pummel", matches = pummel_matches, execute = function(ctx) return ACTION.Pummel and ACTION.Pummel:cast_safe(ctx.target) end },
    { name = "BattleStance", matches = battle_stance_matches, execute = function(ctx) return ACTION.BattleStance and ACTION.BattleStance:cast_safe() end },
    { name = "BattleShout", matches = battle_shout_matches, execute = function(ctx) return ACTION.BattleShout and ACTION.BattleShout:cast_safe() end },
    { name = "Charge", matches = charge_matches, execute = function(ctx) return ACTION.Charge and ACTION.Charge:cast_safe(ctx.target) end },
    { name = "VictoryRush", matches = victory_rush_matches, execute = function(ctx) return ACTION.VictoryRush and ACTION.VictoryRush:cast_safe(ctx.target) end },
    { name = "Execute", matches = execute_matches, execute = function(ctx) return ACTION.Execute and ACTION.Execute:cast_safe(ctx.target) end },
    { name = "Overpower", matches = overpower_matches, execute = function(ctx) return ACTION.Overpower and ACTION.Overpower:cast_safe(ctx.target) end },
    { name = "ThunderClap", matches = thunder_clap_matches, execute = function(ctx) return ACTION.ThunderClap and ACTION.ThunderClap:cast_safe(ctx.target) end },
    { name = "Whirlwind", matches = whirlwind_matches, execute = function(ctx) return ACTION.Whirlwind and ACTION.Whirlwind:cast_safe() end },
    { name = "Cleave", matches = cleave_matches, execute = function(ctx) return ACTION.Cleave and ACTION.Cleave:cast_safe(ctx.target) end },
    { name = "Rend", matches = rend_matches, execute = function(ctx) return ACTION.Rend and ACTION.Rend:cast_safe(ctx.target) end },
    { name = "HeroicStrike", matches = heroic_strike_matches, execute = function(ctx) return ACTION.HeroicStrike and ACTION.HeroicStrike:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
