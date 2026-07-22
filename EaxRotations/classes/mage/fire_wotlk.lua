-- fire_wotlk.lua — Mage Fire rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Fire mage: Combustion CD, Pyroblast on
--        Hot Streak proc, Living Bomb debuff refresh, Scorch debuff maintenance,
--        Fireball filler.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.MageSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    Pyroblast = define("Pyroblast", { 33938, 12526, 12525, 12524, 12523, 12522, 12521, 11366 }, "Pyroblast"),
    LivingBomb = define("LivingBomb", 44457, "LivingBomb"),
    Scorch = define("Scorch", { 30455, 2948, 8444, 8445, 8446, 8447, 10211, 10210, 27073, 27074 }, "Scorch"),
    Fireball = define("Fireball", { 42833, 38692, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Combustion = define("Combustion", 11129, "Combustion"),
}

local LIVING_BOMB_DEBUFF = { 44457, 44459, 44460, 44461 }
local SCORCH_DEBUFF = { 30455, 2948, 8444, 8445, 8446, 8447, 10211, 10210, 27073, 27074 }
local HOT_STREAK_BUFF = { 48108 }

local fire_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    living_bomb_remains = 0,
    scorch_remains = 0,
    hot_streak_proc = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(fire_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.living_bomb_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LIVING_BOMB_DEBUFF)) or 0
    state.scorch_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SCORCH_DEBUFF)) or 0
    state.hot_streak_proc = (me and NS.buff_up and NS.buff_up(me, HOT_STREAK_BUFF)) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Combustion",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Combustion, target = "self" },
    },
    {
        name = "Pyroblast",
        conditions = {
            { type = "state", field = "hot_streak_proc", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Pyroblast, target = "target" },
    },
    {
        name = "LivingBomb",
        conditions = {
            { type = "state", field = "living_bomb_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.LivingBomb, target = "target" },
    },
    {
        name = "Scorch",
        conditions = {
            { type = "state", field = "scorch_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Scorch, target = "target" },
    },
    {
        name = "Fireball",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Fireball, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Combustion" },
    { name = "Pyroblast" },
    { name = "LivingBomb" },
    { name = "Scorch" },
    { name = "Fireball" },
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

-- Register (guarded — nil-safe in unit tests)
if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("fire", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage Fire WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
