-- fury_wotlk.lua — Warrior Fury rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Fury warrior.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.WarriorSpells or {}
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Bloodthirst = define("Bloodthirst", { 30335, 25251, 23894, 23893, 23892, 23881 }, "Bloodthirst"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
    Slam = define("Slam", { 47475, 25242, 25241, 11605, 11604, 8820, 1464 }, "Slam"),
    Execute = define("Execute", { 47498, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    DeathWish = define("DeathWish", { 12292, 12328 }, "DeathWish"),
    BattleShout = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
}

local BATTLE_SHOUT_BUFF = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }

local fury_state = {
    rage = 0,
    hp = 100,
    target_hp = 100,
    enemy_count = 1,
    in_combat = false,
    battle_shout_up = false,
    execute_ready = false,
    death_wish_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(fury_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.rage = (me and me.get_rage and me:get_rage()) or 0
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false
    state.execute_ready = (target and target.get_health_percentage and target:get_health_percentage() < 20) or false
    state.death_wish_ready = (ACTION.DeathWish and ACTION.DeathWish.cooldown_remaining and ACTION.DeathWish:cooldown_remaining() <= 0) or false
    return state
end

local function battle_shout_matches(context, state)
    return not state.battle_shout_up
end

local function death_wish_matches(context, state)
    return state.death_wish_ready
end

local function execute_matches(context, state)
    return state.execute_ready and state.rage >= 10
end

local function bloodthirst_matches(context, state)
    return state.rage >= 30
end

local function whirlwind_matches(context, state)
    return state.rage >= 25
end

local function slam_matches(context, state)
    return state.rage >= 15
end

local strategies = {
    { name = "BattleShout", matches = battle_shout_matches, execute = function(ctx) return ACTION.BattleShout and ACTION.BattleShout:cast_safe() end },
    { name = "DeathWish", matches = death_wish_matches, execute = function(ctx) return ACTION.DeathWish and ACTION.DeathWish:cast_safe() end },
    { name = "Execute", matches = execute_matches, execute = function(ctx) return ACTION.Execute and ACTION.Execute:cast_safe(ctx.target) end },
    { name = "Bloodthirst", matches = bloodthirst_matches, execute = function(ctx) return ACTION.Bloodthirst and ACTION.Bloodthirst:cast_safe(ctx.target) end },
    { name = "Whirlwind", matches = whirlwind_matches, execute = function(ctx) return ACTION.Whirlwind and ACTION.Whirlwind:cast_safe(ctx.target) end },
    { name = "Slam", matches = slam_matches, execute = function(ctx) return ACTION.Slam and ACTION.Slam:cast_safe(ctx.target) end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("fury", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
