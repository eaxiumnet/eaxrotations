-- bear_wotlk.lua — Druid Bear rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Bear druid: Lacerate stack/refresh,
--        Mangle bleed-vulnerability refresh, Swipe AoE, FF upkeep, Maul rage
--        dump, Frenzied Regeneration panic heal.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions
--         replace imperative match functions; no on_update() allocs.
-- DECISION: rage comes from context.rage (main_sylvanas:814) or
--         me:get_power(NS.POWER_RAGE) — the mock-only me:get_rage() pinned rage
--         at 0 live (W3.1 audit) and collapsed Lacerate/Swipe/Mangle/Maul into
--         never-lanes. Rank ladders are file-local WotLK ids via plain
--         define_action (the TBC-capped class table shadows them otherwise).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Plain define_action: file-local WotLK rank lists must win over the
-- TBC-capped DruidSpells class table (precedent: mage/fire_wotlk.lua:20).
local define = spec_kit.define_action

local ACTION = {
    MangleBear = define("MangleBear", { 48564, 33987, 33986, 33878 }, "MangleBear"),
    Lacerate = define("Lacerate", { 48568, 33745 }, "Lacerate"),
    SwipeBear = define("SwipeBear", { 48562, 26997, 9908, 9754, 769, 780, 779 }, "SwipeBear"),
    Maul = define("Maul", { 48480, 26996, 9881, 9880, 9745, 8972, 6809, 6808, 6807 }, "Maul"),
    FeralFaerieFire = define("FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 }, "FeralFaerieFire"),
    -- Same 4 ranks in WotLK as TBC (no new rank) — era-stable ladder.
    FrenziedRegeneration = define("FrenziedRegeneration", { 26999, 22896, 22895, 22842 }, "FrenziedRegeneration"),
}

-- Max-rank-first debuff/aura tables: the WotLK Lacerate/Mangle DoT auras use
-- the WotLK spell ids (48568/48564), so the TBC-only tables read 0 at max rank
-- and the refresh gates re-cast every GCD (systemic injection #3).
local LACERATE_DEBUFF = { 48568, 33745 }
local MANGLE_DEBUFF = { 48564, 33987, 33986, 33878 }
local FAERIE_FIRE_FERAL_DEBUFF = { 27011, 17392, 17391, 17390, 16857 }

local bear_state = {
    hp = 100,
    rage = 0,
    enemy_count = 1,
    in_combat = false,
    lacerate_remains = 0,
    mangle_remains = 0,
    faerie_fire_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(bear_state)
    local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (context and context.hp) or (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.rage = (context and context.rage)
        or (me and me.get_power and me:get_power(NS.POWER_RAGE))
        or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.lacerate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, LACERATE_DEBUFF)) or 0
    state.mangle_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MANGLE_DEBUFF)) or 0
    state.faerie_fire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_FERAL_DEBUFF)) or 0
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Lacerate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "lacerate_remains", op = "<", value = 3 },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Lacerate, target = "target" },
    },
    {
        name = "SwipeBear",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "enemy_count", op = ">=", value = 2 },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.SwipeBear, target = "target" },
    },
    {
        name = "MangleBear",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            -- Mangle applies the 30% bleed-vulnerability debuff; refresh-gate
            -- like cat's interim gate (ids 48564/33987/33986/33878). Without
            -- the gate Mangle was an unconditional rage sink starving
            -- Lacerate (W3.1 audit must-fix).
            { type = "state", field = "mangle_remains", op = "<", value = 3 },
            { type = "state", field = "rage", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.MangleBear, target = "target" },
    },
    {
        name = "FeralFaerieFire",
        conditions = {
            { type = "state", field = "faerie_fire_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FeralFaerieFire, target = "target" },
    },
    {
        name = "Maul",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "rage", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.Maul, target = "target" },
    },
    {
        name = "FrenziedRegeneration",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<=", value = 40 },
            { type = "state", field = "rage", op = ">=", value = 10 },
            { type = "spell_ready", spell = ACTION.FrenziedRegeneration, target = "self" },
        },
        action = { type = "cast", spell = ACTION.FrenziedRegeneration, target = "self" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Lacerate" },
    { name = "SwipeBear" },
    { name = "MangleBear" },
    { name = "FeralFaerieFire" },
    { name = "Maul" },
    { name = "FrenziedRegeneration" },
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
    NS.rotation_registry:register("bear", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
