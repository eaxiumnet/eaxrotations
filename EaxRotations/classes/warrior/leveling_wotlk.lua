-- leveling_wotlk.lua — Warrior leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for warrior leveling in WotLK.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple rage-based rotation using core leveling abilities.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

-- Hit-volume AoE gates (install if core not loaded, e.g. unit tests)
do
    local _ok_aoe, AoeHV = pcall(require, "shared/aoe_hit_volume_sylvanas")
    if _ok_aoe and AoeHV and AoeHV.install then AoeHV.install(NS) end
end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local helpers = require("shared/leveling_helpers_sylvanas")
local SPELLS = NS.WarriorSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    BattleShout = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    Charge = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Rend = define("Rend", { 47465, 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    HeroicStrike = define("HeroicStrike", { 47450, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Overpower = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),
    Execute = define("Execute", { 47471, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
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

local DSL_DEFS = {
    {
        name = "Pummel",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "==", value = true },
            { type = "state", field = "rage", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Pummel, target = "target" },
    },
    {
        name = "BattleStance",
        -- Default leveling stance: enables Charge and the Battle-stance ability set.
        -- Only correct stance out of combat so we don't fight the combat rotation.
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "battle_stance_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BattleStance, target = "self" },
    },
    {
        name = "BattleShout",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "state", field = "battle_shout_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.BattleShout, target = "self" },
    },
    {
        name = "Charge",
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Charge, target = "target" },
    },
    {
        name = "VictoryRush",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.VictoryRush, target = "target" },
    },
    {
        name = "Execute",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 20 },
            { type = "state", field = "rage", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.Execute, target = "target" },
    },
    {
        name = "Overpower",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Overpower, target = "target" },
    },
    {
        name = "ThunderClap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 20 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8
                return NS.aoe_self_meets(2, r, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.ThunderClap, target = "target" },
    },
    {
        name = "Whirlwind",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_self_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_8) or 8
                return NS.aoe_self_meets(2, r, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Whirlwind, target = "self" },
    },
    {
        name = "Cleave",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 20 },
            { type = "custom", fn = function(context, state)
                if not NS.aoe_target_meets then return false end
                local r = (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_8) or 8
                return NS.aoe_target_meets(2, r, context and context.target, context, state) and true or false
            end },
        },
        action = { type = "cast", spell = ACTION.Cleave, target = "target" },
    },
    {
        name = "Rend",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rend_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Rend, target = "target" },
    },
    {
        name = "HeroicStrike",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.HeroicStrike, target = "target" },
    },
}

-- Priority order (compiled in place from DSL_DEFS below).
local strategies = {
    { name = "Pummel" },
    { name = "BattleStance" },
    { name = "BattleShout" },
    { name = "Charge" },
    { name = "VictoryRush" },
    { name = "Execute" },
    { name = "Overpower" },
    { name = "ThunderClap" },
    { name = "Whirlwind" },
    { name = "Cleave" },
    { name = "Rend" },
    { name = "HeroicStrike" },
}

for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end

if NS.log then NS.log("Warrior leveling rotation registered") end

return { strategies = strategies, build_state = build_state }
