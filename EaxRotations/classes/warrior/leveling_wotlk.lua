-- leveling_wotlk.lua — Warrior leveling rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for warrior leveling in WotLK: Battle Stance /
--        Battle Shout OOC setup, Charge gap-closer (8-25 yd), proc-gated
--        Victory Rush, Execute execute-range, dodge-proc-gated Overpower,
--        AoE ThunderClap/Whirlwind/Cleave, Rend maintenance, Heroic Strike dump.
-- WHEN:  combat with valid enemy target.
-- WHY:   simple rage-based rotation using core leveling abilities.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); declarative DSL strategies;
--         no on_update() allocs; no unconditional proc/execute lanes.

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
local CONSTANTS = NS.WarriorConstants or {}
local STANCE = CONSTANTS.STANCE or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Plain define_action (NOT define_action_for_class): the WotLK client loads the
-- TBC class_sylvanas.lua into NS.WarriorSpells, so the class-first resolver would
-- shadow these WotLK rank ladders with TBC-era rank lists.
local define = spec_kit.define_action

local ACTION = {
    BattleShout = define("BattleShout", { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }, "BattleShout"),
    Charge = define("Charge", { 11578, 6178, 100 }, "Charge"),
    Rend = define("Rend", { 47465, 25208, 11574, 11573, 6548, 6547, 772 }, "Rend"),
    HeroicStrike = define("HeroicStrike", { 47450, 30324, 29707, 25286, 11567, 11566, 11565, 11564, 1608, 285, 284, 78 }, "HeroicStrike"),
    Overpower = define("Overpower", { 11585, 11584, 7887, 7384 }, "Overpower"),
    Execute = define("Execute", { 47471, 25236, 25234, 20662, 20661, 20660, 20658, 5308 }, "Execute"),
    ThunderClap = define("ThunderClap", { 47502, 25264, 11581, 11580, 8205, 8204, 8198, 6343 }, "ThunderClap"),
    VictoryRush = define("VictoryRush", 34428, "VictoryRush"),
    Pummel = define("Pummel", { 6554, 6552 }, "Pummel"),
    BattleStance = define("BattleStance", 2457, "BattleStance"),
    Whirlwind = define("Whirlwind", 1680, "Whirlwind"),
    Cleave = define("Cleave", { 47520, 25231, 20569, 11609, 11608, 7369, 845 }, "Cleave"),
}

local REND_DEBUFF = { 47465, 25208, 11574, 11573, 6548, 6547, 772 }
local BATTLE_SHOUT_BUFF = { 47436, 25289, 2048, 11551, 11550, 11549, 6192, 5242, 6673 }
local BATTLE_STANCE_BUFF = { 2457 }
-- Victory Rush only becomes castable after a killing blow (the client applies
-- the Victory Rush aura — same id as the ability — on a killing blow; the
-- in-repo TBC fury/arms files gate on the same VICTORY_RUSH_BUFF = { 34428 }).
local VICTORY_RUSH_PROC_BUFF = { 34428 }

local EXECUTE_RAGE_MIN = 15 -- WotLK Execute costs 15 rage
local PUMMEL_RAGE_MIN  = 10 -- Pummel costs 10 rage
local REND_RAGE_MIN    = 10 -- Rend costs 10 rage
local OVERPOWER_RAGE_MIN = 5 -- WotLK Overpower costs 5 rage

local warrior_state = {
    target_hp = 100,
    rage = 0,
    enemy_count = 1,
    in_combat = false,
    rend_remains = 0,
    battle_shout_up = false,
    battle_stance_up = false,
    target_casting = false,
    victory_rush_proc = false,
    overpower_window = false,
}

-- WotLK Overpower is dodge-proc-gated: the real CLEU proc tracker is
-- authoritative, with a target-dodge-chance heuristic as the drivable fallback
-- (mirrors fury_vanilla.lua's overpower_window derivation).
local function overpower_window(target)
    if NS and NS.SwingDiagnostics and type(NS.SwingDiagnostics.is_overpower_proc_active) == "function" then
        local ok_proc, val = pcall(NS.SwingDiagnostics.is_overpower_proc_active)
        if ok_proc and val then return true end
    end
    if target and type(target.get_dodge_chance) == "function" then
        local ok_dodge, dodge = pcall(target.get_dodge_chance, target)
        if ok_dodge and type(dodge) == "number" and dodge > 0 then return true end
    end
    return false
end

local function build_state(context)
    local state = spec_kit.safe_state(warrior_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    -- Rage via the REAL chain: context.rage (main_sylvanas.lua:814,
    -- power_current(NS.POWER_RAGE)) first, then me:get_power(NS.POWER_RAGE) —
    -- me:get_rage() is mock-only and pinned state.rage at 0 live (W3.4 audit),
    -- collapsing every rage-gated lane into a production never-lane. Mirrors
    -- bear_wotlk.lua:57-59.
    state.rage = (context and context.rage)
        or (me and me.get_power and me:get_power(NS.POWER_RAGE))
        or 0
    state.enemy_count = (context and (context.enemies_count or context.enemy_count)) or 1
    state.in_combat = (context and context.in_combat) or false
    -- Explicit distance copy: safe_state's target_distance default is 0, which
    -- would otherwise shadow the context value and break the Charge range gate.
    state.target_distance = (context and context.target_distance) or 0
    state.rend_remains = (target and NS.debuff_remains and NS.debuff_remains(target, REND_DEBUFF)) or 0
    state.battle_shout_up = (me and NS.buff_up and NS.buff_up(me, BATTLE_SHOUT_BUFF)) or false
    -- Battle-stance read via me:get_stance() (arms convention), with the buff
    -- check retained as a fallback for clients that only expose the aura.
    state.battle_stance_up = (me and me.get_stance and me:get_stance() == STANCE.BATTLE)
        or (me and NS.buff_up and NS.buff_up(me, BATTLE_STANCE_BUFF)) or false
    state.target_casting = helpers.should_interrupt(target)
    state.victory_rush_proc = (me and NS.buff_up and NS.buff_up(me, VICTORY_RUSH_PROC_BUFF)) or false
    state.overpower_window = overpower_window(target)
    return state
end

local DSL_DEFS = {
    {
        name = "Pummel",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_casting", op = "==", value = true },
            { type = "state", field = "rage", op = ">=", value = PUMMEL_RAGE_MIN },
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
        -- Charge needs an 8-25 yd target; the un-gated lane attempted the cast
        -- at melee range every OOC frame.
        conditions = {
            { type = "state", field = "in_combat", op = "falsy" },
            { type = "distance", op = ">=", value = 8 },
            { type = "distance", op = "<=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Charge, target = "target" },
    },
    {
        name = "VictoryRush",
        -- Victory Rush requires the killing-blow proc (Victory Rush aura up);
        -- the old lane cast it unconditionally in combat.
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "victory_rush_proc", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.VictoryRush, target = "target" },
    },
    {
        name = "Execute",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_hp", op = "<", value = 20 },
            { type = "state", field = "rage", op = ">=", value = EXECUTE_RAGE_MIN },
        },
        action = { type = "cast", spell = ACTION.Execute, target = "target" },
    },
    {
        name = "Overpower",
        -- WotLK Overpower is dodge-proc-gated and costs 5 rage (Battle stance
        -- only); the old lane fired unconditionally every GCD.
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "battle_stance_up", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = OVERPOWER_RAGE_MIN },
            { type = "state", field = "overpower_window", op = "truthy" },
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
            { type = "state", field = "rage", op = ">=", value = REND_RAGE_MIN },
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
