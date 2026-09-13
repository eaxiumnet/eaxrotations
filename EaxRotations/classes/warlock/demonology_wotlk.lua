-- demonology_wotlk.lua — Warlock Demonology rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Demonology warlock.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- WotLK file-local rank ladders are authoritative: plain define_action (not
-- define_action_for_class) so the TBC-era NS.WarlockSpells table can never
-- shadow the WotLK max-rank ids (Immolate 47811 / Corruption 47813).
local define = spec_kit.define_action

local ACTION = {
    Metamorphosis = define("Metamorphosis", 47241, "Metamorphosis"),
    Immolate = define("Immolate", { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }, "Immolate"),
    Corruption = define("Corruption", { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }, "Corruption"),
    ShadowBolt = define("ShadowBolt", { 47809, 27209, 25307, 11661, 11660, 11659, 7641, 1106, 1088, 705, 695, 686 }, "ShadowBolt"),
    SoulFire = define("SoulFire", { 47825, 30545, 27211, 17924, 6353 }, "SoulFire"),
    -- Demo signature proc payload (Molten Core buff 47245/47246/71165):
    -- Incinerate 47838 = WotLK max rank (ladder mirrors destruction_wotlk,
    -- audit-pinned).
    Incinerate = define("Incinerate", { 47838, 32231, 29722 }, "Incinerate"),
    LifeTap = define("LifeTap", { 57946, 27222, 11689, 11688, 11687, 1456, 1455, 1454 }, "LifeTap"),
    -- 2026-09-12 guide pass (Wowhead WotLK-verified): the demo/affliction
    -- fixtures’ long-fight curse Curse of Doom 47867, the default curse
    -- Curse of Agony 47864, the AoE Seed of Corruption 47836 (already in the
    -- local bridge) and Immolation Aura 50589 (Metamorphosis-form 30s CD).
    CurseOfDoom = define("CurseOfDoom", 47867, "CurseOfDoom"),
    CurseOfAgony = define("CurseOfAgony", { 47864, 27218, 11713, 11712, 11711, 6217, 1014, 980 }, "CurseOfAgony"),
    SeedOfCorruption = define("SeedOfCorruption", { 47836, 27243 }, "SeedOfCorruption"),
    ImmolationAura = define("ImmolationAura", 50589, "ImmolationAura"),
}

-- WotLK max-rank ids FIRST (literal id matching — without 47811/47813 the
-- DoT-remains reads are always 0 and every DoT is re-cast every GCD).
local IMMOLATE_DEBUFF = { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CORRUPTION_DEBUFF = { 47813, 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local METAMORPHOSIS_BUFF = { 47241 }
-- Wowhead-verified proc-buff ids: Molten Core ranks 47245/47246/71165;
-- Decimation is the single-rank 63165 (10s, sub-35% target).
local MOLTEN_CORE_BUFF = { 71165, 47246, 47245 }
local DECIMATION_BUFF = { 63165 }
local CURSE_OF_DOOM_DEBUFF = { 47867 }
local CURSE_OF_AGONY_DEBUFF = { 47864, 27218, 11713, 11712, 11711, 6217, 1014, 980 }

local DEMO_SCHEMA = {
    enemy_count = 1, in_combat = false,
    immolate_remains = 0, corruption_remains = 0,
    metamorphosis_up = false,
    metamorphosis_cd = 0,
    immolation_aura_cd = 0,
    molten_core_up = false,
    decimation_up = false,
    hp = 100, mana_pct = 100,
    cod_remains = 0, agony_remains = 0, target_is_boss = false,
}

local demonology_state = {}

local function build_state(context)
    local state = spec_kit.safe_state(demonology_state, DEMO_SCHEMA)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- Engine-populated context fields first (production API); unit-method
    -- reads kept only as fallback for harnesses without a context.
    state.mana_pct = (context and context.mana_pct) or (me and me.get_mana_percentage and me:get_mana_percentage()) or 100
    state.hp = (context and context.hp) or (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.immolate_remains = (target and NS.debuff_remains and NS.debuff_remains(target, IMMOLATE_DEBUFF)) or 0
    state.corruption_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CORRUPTION_DEBUFF)) or 0
    state.metamorphosis_up = (me and NS.buff_up and NS.buff_up(me, METAMORPHOSIS_BUFF)) or false
    state.molten_core_up = (me and NS.buff_up and NS.buff_up(me, MOLTEN_CORE_BUFF)) or false
    state.decimation_up = (me and NS.buff_up and NS.buff_up(me, DECIMATION_BUFF)) or false
    state.cod_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_DOOM_DEBUFF)) or 0
    state.agony_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CURSE_OF_AGONY_DEBUFF)) or 0
    state.target_is_boss = (context and context.target_is_boss) == true
    -- Real cooldowns for the two demon-form abilities: Metamorphosis is 3 min
    -- (Wowhead 3.3.5: 47241, 30s duration) and Immolation Aura is 30s (50589,
    -- 15s duration). Both lanes gated on their aura/buff only, so for the
    -- ~150s after the 30s Metamorphosis dropped the entry-1 lane matched every
    -- tick, and Immolation Aura matched for the whole form window. Fail-open
    -- to 0 = ready when the engine read is unavailable.
    state.metamorphosis_cd = (ACTION.Metamorphosis and NS.cooldown_remains and NS.cooldown_remains(ACTION.Metamorphosis)) or 0
    state.immolation_aura_cd = (ACTION.ImmolationAura and NS.cooldown_remains and NS.cooldown_remains(ACTION.ImmolationAura)) or 0
    -- Demo signature procs (Wowhead-verified buff ids): Molten Core
    -- (Corruption-tick proc empowering the next 3 Incinerate/Soul Fire casts)
    -- and Decimation (Shadow Bolt/Incinerate/Soul Fire on a sub-35% target
    -- procs a fast, shard-free Soul Fire for 10s).
    return state
end

-- ============================================================================
-- Declarative Strategy DSL definitions (8 strategies, 100% declarative)
-- ============================================================================
local DSL_DEFS = {
    {
        name = "Metamorphosis",
        conditions = {
            { type = "context", field = "in_combat", op = "==", value = true },
            { type = "state", field = "metamorphosis_up", op = "==", value = false },
            -- The buff falling off is NOT availability: the real 3-min cooldown
            -- outlives the 30s form by ~150s, during which this entry-1 lane
            -- would otherwise claim every GCD from the curse/DoT/filler lanes.
            { type = "state", field = "metamorphosis_cd", op = "<=", value = 0 },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.Metamorphosis, target = "self", label = "[DEMONOLOGY WOTLK] Metamorphosis" },
    },
    -- Curses lead the real demo rotation (the fixtures cast Curse of Doom on a
    -- long/boss fight and Curse of Agony otherwise). Both sit ABOVE Corruption
    -- so the curse is up before the DoT cycle; the pinned sim chain
    -- Corruption < Immolate < SoulFire < ShadowBolt is untouched.
    {
        name = "CurseOfDoom",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_boss", op = "truthy" },
            { type = "state", field = "cod_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.CurseOfDoom, target = "target", label = "[DEMONOLOGY WOTLK] Curse of Doom" },
    },
    {
        name = "CurseOfAgony",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "agony_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.CurseOfAgony, target = "target", label = "[DEMONOLOGY WOTLK] Curse of Agony" },
    },
    {
        name = "Corruption",
        conditions = {
            { type = "state", field = "corruption_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Corruption, target = "target", label = "[DEMONOLOGY WOTLK] Corruption" },
    },
    {
        name = "Immolate",
        conditions = {
            { type = "state", field = "immolate_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.Immolate, target = "target", label = "[DEMONOLOGY WOTLK] Immolate" },
    },
    {
        name = "IncinerateProc",
        conditions = {
            -- Molten Core window: the Corruption-tick proc empowers the next
            -- 3 Incinerates (+18% dmg, -30% cast). Spend it before resuming
            -- Shadow Bolt; ShadowBolt is skipped while the buff is up.
            { type = "state", field = "molten_core_up", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.Incinerate, target = "target", label = "[DEMONOLOGY WOTLK] Incinerate (Molten Core)" },
    },
    {
        name = "SoulFireDecimation",
        conditions = {
            -- Decimation window (sub-35% target procs 63165): instant,
            -- shard-free Soul Fire beats every filler in the execute band.
            { type = "state", field = "decimation_up", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target", label = "[DEMONOLOGY WOTLK] Soul Fire (Decimation)" },
    },
    {
        name = "SoulFire",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target", label = "[DEMONOLOGY WOTLK] Soul Fire" },
    },
    -- Metamorphosis-form ability (50589): a 30s-CD instant the demo spec spends
    -- while transformed. Gated on the real Metamorphosis aura, so it is silent
    -- outside the window.
    {
        name = "ImmolationAura",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "metamorphosis_up", op = "truthy" },
            -- The form aura is a 30s window and the ability's own cooldown is
            -- also 30s, so the form gate alone let the lane claim every GCD of
            -- the window after its one real cast.
            { type = "state", field = "immolation_aura_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.ImmolationAura, target = "target", label = "[DEMONOLOGY WOTLK] Immolation Aura" },
    },
    -- AoE DoT: Seed of Corruption into a pack (mirrors the affliction volume
    -- gate — below 4 targets Shadow Bolt is the better filler).
    {
        name = "SeedOfCorruptionAoE",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return (state.enemy_count or 1) >= 4
                    and NS.aoe_target_meets and NS.aoe_target_meets(4, (NS.AOE_RADIUS and NS.AOE_RADIUS.TARGET_10) or 10, context and context.target, context)
            end },
        },
        action = { type = "cast", spell = ACTION.SeedOfCorruption, target = "target", label = "[DEMONOLOGY WOTLK] Seed of Corruption" },
    },
    {
        name = "ShadowBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.ShadowBolt, target = "target", label = "[DEMONOLOGY WOTLK] Shadow Bolt" },
    },
    -- Mana sustain (rubric): mirror the TBC demonology LifeTap gates
    -- (mana < 65, hp > 55). Appended after ShadowBolt so the pinned APL order
    -- (Corruption < Immolate < SoulFire < ShadowBolt) is untouched.
    {
        name = "LifeTap",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 65 },
            { type = "state", field = "hp", op = ">", value = 55 },
        },
        action = { type = "cast", spell = ACTION.LifeTap, target = "self", label = "[DEMONOLOGY WOTLK] Life Tap" },
    },
}

-- ============================================================================
-- Strategies (name-only placeholders; DSL-compiled equivalents replace them)
-- ============================================================================
local strategies = {
    { name = "Metamorphosis" },
    { name = "IncinerateProc" },
    { name = "SoulFireDecimation" },
    { name = "CurseOfDoom" },
    { name = "CurseOfAgony" },
    { name = "Corruption" },
    { name = "Immolate" },
    { name = "ImmolationAura" },
    { name = "SoulFire" },
    { name = "SeedOfCorruptionAoE" },
    { name = "ShadowBolt" },
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
    NS.rotation_registry:register("demonology", strategies, { get_state = build_state })
end
if NS.log then NS.log("Warlock demonology WotLK rotation registered") end
return { strategies = strategies, build_state = build_state }
