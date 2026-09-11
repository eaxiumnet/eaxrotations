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
    -- Guide-priority additions (wl_destro wowsims APL + Icy-Veins/Chardev
    -- destruction guides): Curse of the Elements 47865 (amp opener, APL entry
    -- 2 — the fixture's 47867 is NOT the live WotLK max rank; 47865 is, so the
    -- read table is max-id-only, mirroring the Dragon's Breath era-ladder
    -- rule), Shadowburn 47827 r3 (execute-band finisher, feeds Empowered Imp
    -- shards), Hellfire 47823 r9 (channeled AoE — Hurricane channel idiom).
    CurseOfElements = define("CurseOfElements", 47865, "CurseOfElements"),
    Shadowburn = define("Shadowburn", 47827, "Shadowburn"),
    Hellfire = define("Hellfire", 47823, "Hellfire"),
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

-- Backdraft: the haste aura Conflagrate grants the caster (reduces the cast
-- time and GCD of the next three Destruction spells). Per-talent-rank auras
-- are 54274 (-10%) / 54276 (-20%) / 54277 (-30%), verified on wotlkdb.com
-- (3.3.5a). The index bridge carries the same ids; 55379/55380 are Skyflare
-- Swiftness (meta-gem proc), NOT Backdraft — see the index manual entry.
local BACKDRAFT_BUFF = { 54274, 54276, 54277 }

-- Curse of the Elements debuff (max-id-only: single WotLK-rank trainable;
-- a TBC ladder here would read 0 at max rank and re-cast every GCD —
-- systemic injection #3 pattern).
local ELEMENTS_DEBUFF = { 47865 }

local DESTRUCTION_SCHEMA = {
    enemy_count = 1, in_combat = false,
    immolate_remains = 0,
    has_backdraft = false,
    elements_remains = 0,
    target_hp = 100,
    shadowburn_cd = 99,
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
    state.has_backdraft = (me and NS.buff_up and NS.buff_up(me, BACKDRAFT_BUFF)) or false
    -- CoE amp read (fails closed like immolate_remains above: no target/API
    -- → 0 → the upkeep lane re-casts).
    state.elements_remains = (target and NS.debuff_remains and NS.debuff_remains(target, ELEMENTS_DEBUFF)) or 0
    -- Execute band HP (dispatcher-produced context field; HammerOfWrath idiom)
    -- and the Shadowburn cooldown read (fails closed via 99).
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or (context and context.target_hp) or 100
    state.shadowburn_cd = (ACTION.Shadowburn and NS.cooldown_remains and NS.cooldown_remains(ACTION.Shadowburn)) or 99
    return state
end

-- ============================================================================
-- Declarative Strategy DSL definitions (7 strategies, 100% declarative)
-- ============================================================================
local DSL_DEFS = {
    -- APL entry 2: the 13% magic-damage amp goes up before the damage cycle
    -- (5-min curse; the guide's first stop even over Immolate).
    {
        name = "CurseOfElements",
        conditions = {
            { type = "state", field = "elements_remains", op = "<", value = 30 },
        },
        action = { type = "cast", spell = ACTION.CurseOfElements, target = "target", label = "[DESTRUCTION WOTLK] Curse of the Elements" },
    },
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
    -- Execute band: Shadowburn ≤ 35% target HP (shard generation for
    -- Empowered Imp makes it the guide's execute finisher).
    {
        name = "Shadowburn",
        conditions = {
            { type = "state", field = "target_hp", op = "<", value = 35 },
            { type = "state", field = "shadowburn_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Shadowburn, target = "target", label = "[DESTRUCTION WOTLK] Shadowburn (execute)" },
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
    -- Soul Fire is a 15s-CD / 4s-cast nuke; its long cast is only competitive
    -- inside a haste window, so the proc lane consumes the Backdraft aura
    -- (mirrors the repo's proc-consumer convention, e.g. BacklashShadowBolt).
    -- The plain SoulFire lane below Incinerate stays for non-Backdraft builds.
    {
        name = "SoulFireBackdraft",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "has_backdraft", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target", label = "[DESTRUCTION WOTLK] Soul Fire (Backdraft window)" },
    },
    {
        name = "SoulFire",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 30 },
        },
        action = { type = "cast", spell = ACTION.SoulFire, target = "target", label = "[DESTRUCTION WOTLK] Soul Fire" },
    },
    -- Channeled AoE wave (3+ targets in 10y self radius; the DSL has no
    -- channel action type — a plain cast would re-queue every GCD, so this
    -- mirrors the balance_wotlk Hurricane idiom exactly).
    {
        name = "HellfireAoE",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                return (state.enemy_count or 1) >= 3
                    and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context and context.target, context)
            end },
            -- Channel readiness (real engine cooldown read).
            { type = "spell_ready", spell = ACTION.Hellfire, target = "target" },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Hellfire, context and context.target, "[DESTRUCTION WOTLK] Hellfire") == true
        end },
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
    { name = "CurseOfElements" },
    { name = "Conflagrate" },
    { name = "Shadowburn" },
    { name = "Immolate" },
    { name = "ChaosBolt" },
    { name = "SoulFireBackdraft" },
    { name = "Incinerate" },
    { name = "SoulFire" },
    { name = "HellfireAoE" },
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
