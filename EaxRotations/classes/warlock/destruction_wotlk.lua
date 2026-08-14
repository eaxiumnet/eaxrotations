-- destruction_wotlk.lua — Warlock Destruction rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Destruction warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- WotLK file-local rank ladders are authoritative: plain define_action (not
-- define_action_for_class) so the TBC-era NS.WarlockSpells table can never
-- shadow the WotLK max-rank ids (Immolate 47811 etc.).
local define = spec_kit.define_action

local ACTION = {
    Immolate = define("Immolate", { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    ChaosBolt = define("ChaosBolt", 50796, "ChaosBolt"),
    Incinerate = define("Incinerate", { 47838, 32231, 29722 }, "Incinerate"),
    Conflagrate = define("Conflagrate", { 30912, 27266, 18932, 18931, 18930, 17962 }, "Conflagrate"),
    SoulFire = define("SoulFire", { 47825, 30545, 27211, 17924, 6353 }, "SoulFire"),
    LifeTap = define("LifeTap", { 57946, 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
}

local IMMOLATE_CAST_TIME = type(ACTION.Immolate) == "table"
    and ACTION.Immolate._meta and ACTION.Immolate._meta.cast_time
local IMMOLATE_REFRESH_SECONDS = type(IMMOLATE_CAST_TIME) == "number"
    and IMMOLATE_CAST_TIME or 2.0

-- WotLK max-rank id FIRST (literal id matching — without 47811 the Immolate
-- remains read is always 0 and Conflagrate's "Immolate active" gate never
-- passes, a production never-lane).
local IMMOLATE_DEBUFF = { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }

local DESTRUCTION_SCHEMA = {
    enemy_count = 1, in_combat = false,
    immolate_remains = 0,
    hp = 100, mana_pct = 100,
}

local destruction_state = {}

local function build_state(context)
    local state = spec_kit.safe_state(destruction_state, DESTRUCTION_SCHEMA)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- Engine-populated context fields first (production API); unit-method
    -- reads kept only as fallback for harnesses without a context.
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.hp = (context and context.hp) or (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.immolate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF)) or 0
    return state
end

-- ============================================================================
-- Declarative Strategy DSL definitions (5 strategies, 100% declarative)
-- ============================================================================
local DSL_DEFS = {
    {
        name = "Immolate",
        conditions = {
            { type = "state", field = "immolate_remains", op = "<", value = IMMOLATE_REFRESH_SECONDS },
        },
        action = { type = "cast", spell = ACTION.Immolate, target = "target", label = "[DESTRUCTION WOTLK] Immolate" },
    },
    {
        name = "Conflagrate",
        conditions = {
            { type = "state", field = "immolate_remains", op = ">", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Conflagrate, target = "target", label = "[DESTRUCTION WOTLK] Conflagrate" },
    },
    {
        name = "ChaosBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ChaosBolt, target = "target", label = "[DESTRUCTION WOTLK] Chaos Bolt" },
    },
    {
        name = "Incinerate",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Incinerate, target = "target", label = "[DESTRUCTION WOTLK] Incinerate" },
    },
    {
        name = "SoulFire",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target", label = "[DESTRUCTION WOTLK] Soul Fire" },
    },
    -- Mana sustain (rubric): mirror the TBC destruction LifeTap gates
    -- (mana <= 20-30, min_hp 50). Appended after SoulFire so the pinned APL
    -- order (Conflagrate < Immolate < Incinerate) is untouched.
    {
        name = "LifeTap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 30 },
            { type = "state", field = "hp", op = ">", value = 50 },
        },
        action = { type = "cast", spell = ACTION.LifeTap, target = "self", label = "[DESTRUCTION WOTLK] Life Tap" },
    },
}

-- ============================================================================
-- Strategies (name-only placeholders; DSL-compiled equivalents replace them)
-- ============================================================================
local strategies = {
    { name = "Conflagrate" },
    { name = "Immolate" },
    { name = "ChaosBolt" },
    { name = "Incinerate" },
    { name = "SoulFire" },
    { name = "LifeTap" },
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
    NS.rotation_registry:register("destruction", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock destruction WotLK rotation registered") end
return { strategies = strategies, build_state = build_state }
