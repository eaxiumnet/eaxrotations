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
local core = NS.core or _G.core or {}
local _get_spell_cast_time = core.spell_book and core.spell_book.get_spell_cast_time

local SCORCH_ID = 42859

local define = spec_kit.define_action

local ACTION = {
    Pyroblast = define("Pyroblast", { 42891 }, "Pyroblast"),
    LivingBomb = define("LivingBomb", { 55360 }, "LivingBomb"),
    FireBlast = define("FireBlast", { 42873 }, "FireBlast"),
    Scorch = define("Scorch", { 42859 }, "Scorch"),
    Fireball = define("Fireball", { 42833, 38692, 27070, 25306, 10151, 10150, 10149, 10148, 8402, 8401, 8400, 3140, 145, 143, 133 }, "Fireball"),
    Combustion = define("Combustion", 11129, "Combustion"),
    Counterspell = define("Counterspell", { 2139 }, "Counterspell"),
}

local LIVING_BOMB_DEBUFF = { 55360 }
-- 22959 Fire Vulnerability is the Improved Scorch target debuff (rank-
-- independent, applied by any Scorch rank with the talent). 12873 is the
-- "Improved Scorch" talent itself — its aura never lands on the target, so
-- reading it left scorch_remains perpetually 0. DBC-verified: SpellName
-- 22959 = "Fire Vulnerability", 12873 = "Improved Scorch" (wowsims.db);
-- matches fire_sylvanas.lua:47 (TBC) precedent.
local SCORCH_DEBUFF = { 22959 }
local HOT_STREAK_BUFF = { 44448 }

local fire_state = {
    enemy_count = 1,
    in_combat = false,
    living_bomb_remains = 0,
    scorch_remains = 0,
    hot_streak_proc = false,
    ttd = 999,
    scorch_cast_time = nil,
    target_is_casting = false,
}

local function resolve_scorch_cast_time(context)
    local context_cast_time = context and context.scorch_cast_time
    if type(context_cast_time) == "number" and context_cast_time > 0 then
        return context_cast_time
    end
    if type(_get_spell_cast_time) == "function" then
        local ok, cast_time = pcall(_get_spell_cast_time, SCORCH_ID)
        if ok and type(cast_time) == "number" and cast_time > 0 then
            return cast_time
        end
    end
    return nil
end

local function build_state(context)
    local state = spec_kit.safe_state(fire_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    local ttd = context and context.ttd
    state.ttd = type(ttd) == "number" and ttd > 0 and ttd or 999
    state.scorch_cast_time = resolve_scorch_cast_time(context)
    state.living_bomb_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LIVING_BOMB_DEBUFF)) or 0
    state.scorch_remains = (target and NS.debuff_remains and NS.debuff_remains(target, SCORCH_DEBUFF)) or 0
    state.hot_streak_proc = (me and NS.buff_up and NS.buff_up(me, HOT_STREAK_BUFF)) or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Counterspell",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Counterspell, target = "target" },
    },
    {
        name = "Combustion",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
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
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "state", field = "hot_streak_proc", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Pyroblast, target = "target" },
    },
    {
        name = "LivingBomb",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "state", field = "living_bomb_remains", op = "<=", value = 0 },
            { type = "state", field = "ttd", op = ">", value = 12 },
        },
        action = { type = "cast", spell = ACTION.LivingBomb, target = "target" },
    },
    {
        name = "FireBlast",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "custom", fn = function(context, state)
                local cast_time = state.scorch_cast_time
                return type(cast_time) == "number" and cast_time > 0 and state.ttd <= cast_time
            end },
        },
        action = { type = "cast", spell = ACTION.FireBlast, target = "target" },
    },
    {
        name = "Scorch",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "state", field = "scorch_remains", op = "<=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.Scorch, target = "target" },
    },
    {
        name = "ScorchFinal",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
            { type = "state", field = "ttd", op = "<=", value = 4 },
        },
        action = { type = "cast", spell = ACTION.Scorch, target = "target" },
    },
    {
        name = "Fireball",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "context", field = "target", op = "!=", value = nil },
        },
        action = { type = "cast", spell = ACTION.Fireball, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Counterspell" },
    { name = "Combustion" },
    { name = "Scorch" },
    { name = "Pyroblast" },
    { name = "LivingBomb" },
    { name = "FireBlast" },
    { name = "ScorchFinal" },
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
