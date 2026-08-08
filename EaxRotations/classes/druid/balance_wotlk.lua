-- balance_wotlk.lua — Druid Balance rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Balance druid.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.DruidSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    MoonkinForm = define("MoonkinForm", 24858, "MoonkinForm"),
    InsectSwarm = define("InsectSwarm", { 48468, 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    Moonfire = define("Moonfire", { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Starfall = define("Starfall", 48505, "Starfall"),
    Wrath = define("Wrath", { 48461, 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    Starfire = define("Starfire", { 48465, 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
}

local MOONKIN_FORM_BUFF = { 24858 }
local INSECT_SWARM_DEBUFF = { 27013, 24977, 24976, 24975, 24974, 5570 }
local MOONFIRE_DEBUFF = { 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }

local balance_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    moonkin_up = false,
    insect_swarm_remains = 0,
    moonfire_remains = 0,
    eclipse_proc = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(balance_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.moonkin_up = (me and NS.buff_up and NS.buff_up(me, MOONKIN_FORM_BUFF)) or false
    state.insect_swarm_remains = (target and NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF)) or 0
    state.moonfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF)) or 0
    state.eclipse_proc = (me and NS.buff_up and (NS.buff_up(me, { 48517 }) or NS.buff_up(me, { 48518 }))) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "MoonkinForm",
        conditions = {
            { type = "state", field = "moonkin_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.MoonkinForm, target = "self" },
    },
    {
        name = "Starfall",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 60) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Starfall, target = "target" },
    },
    {
        name = "InsectSwarm",
        conditions = {
            { type = "state", field = "insect_swarm_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.InsectSwarm, target = "target" },
    },
    {
        name = "Moonfire",
        conditions = {
            { type = "state", field = "moonfire_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Moonfire, target = "target" },
    },
    {
        name = "Wrath",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Wrath, target = "target" },
    },
    {
        name = "Starfire",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Starfire, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "MoonkinForm" },
    { name = "Starfall" },
    { name = "InsectSwarm" },
    { name = "Moonfire" },
    { name = "Wrath" },
    { name = "Starfire" },
}

-- Name-based substitution preserves the existing priority order.
for i = 1, #strategies do
    for j = 1, #DSL_DEFS do
        if strategies[i].name == DSL_DEFS[j].name then
            strategies[i] = dsl.compile_strategy(DSL_DEFS[j], { get_state = build_state })
            break
        end
    end
end

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("balance", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
