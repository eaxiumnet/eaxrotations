-- affliction_wotlk.lua — Warlock Affliction rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Affliction warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")
local SPELLS = NS.WarlockSpells or {}

local define = spec_kit.define_action_for_class(SPELLS)

local ACTION = {
    UnstableAffliction = define("UnstableAffliction", { 47843, 30405, 30404, 30108 }, "UnstableAffliction"),
    Haunt = define("Haunt", { 59164, 48181 }, "Haunt"),
    Corruption = define("Corruption", { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    CurseOfAgony = define("CurseOfAgony", { 47864, 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    DrainSoul = define("DrainSoul", { 47855, 27217, 11675, 8289, 8288, 1120 }, "DrainSoul"),
    ShadowBolt = define("ShadowBolt", { 47809, 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
}

local UNSTABLE_AFFLICTION_DEBUFF = { 30405, 30404, 30108 }
local CORRUPTION_DEBUFF = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local HAUNT_DEBUFF = { 48181, 59164 }

local affliction_state = {
    hp = 100,
    target_hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    unstable_remains = 0,
    haunt_remains = 0,
    corruption_remains = 0,
    agony_remains = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(affliction_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.hp = (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.mana_pct = (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.unstable_remains = (target and NS.debuff_remains and NS.debuff_remains(target, UNSTABLE_AFFLICTION_DEBUFF)) or 0
    state.haunt_remains = (target and NS.debuff_remains and NS.debuff_remains(target, HAUNT_DEBUFF)) or 0
    state.corruption_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF)) or 0
    state.agony_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF)) or 0
    return state
end

local DSL_DEFS = {
    {
        name = "Haunt",
        conditions = {
            { type = "state", field = "haunt_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Haunt, target = "target" },
    },
    {
        name = "Corruption",
        conditions = {
            { type = "state", field = "corruption_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Corruption, target = "target" },
    },
    {
        name = "UnstableAffliction",
        conditions = {
            { type = "state", field = "unstable_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.UnstableAffliction, target = "target" },
    },
    {
        name = "CurseOfAgony",
        conditions = {
            { type = "state", field = "agony_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.CurseOfAgony, target = "target" },
    },
    {
        name = "DrainSoul",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 25 },
        },
        action = { type = "cast", spell = ACTION.DrainSoul, target = "target" },
    },
    {
        name = "ShadowBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target" },
    },
}

local strategies = {
    { name = "Haunt" },
    { name = "Corruption" },
    { name = "UnstableAffliction" },
    { name = "CurseOfAgony" },
    { name = "DrainSoul" },
    { name = "ShadowBolt" },
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
    NS.rotation_registry:register("affliction", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock affliction rotation registered") end

return { strategies = strategies, build_state = build_state }
