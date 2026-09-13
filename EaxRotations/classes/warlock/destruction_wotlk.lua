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
    -- 59172 = WotLK max rank (level 80; 2.5s cast / 12s CD, Wowhead-verified).
    -- 50796 is the level-60 rank 1 the file shipped with — kept as the
    -- low-level fallback so the ladder resolves to the best known rank.
    ChaosBolt = define("ChaosBolt", { 59172, 50796 }, "ChaosBolt"),
    -- Guide-pass additions (wl_destro wowsims APL entries 3 and 8):
    -- Curse of Doom 47867 (1-min CD / 1-min duration, the long-fight boss
    -- curse) and Curse of Agony 47864 (the fallback curse when Doom is not
    -- up). Only one curse per warlock, so the two lanes are exclusive.
    CurseOfDoom = define("CurseOfDoom", 47867, "CurseOfDoom"),
    CurseOfAgony = define("CurseOfAgony", 47864, "CurseOfAgony"),
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

-- WotLK max-rank id FIRST (literal id matching — without 47811 the Immolate
-- remains read is always 0 and Conflagrate's "Immolate active" gate never
-- passes, a production never-lane).
local IMMOLATE_DEBUFF = { 47811, 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }

-- Immolate's refresh window is the wowsims fixture's expression verbatim
-- (wl_destro_wotlk.apl.json entry 4:
--   dotRemainingTime(47811) < spellCastTime(47811)).
-- The cast time comes from the engine spell book
-- (core.spell_book.get_spell_cast_time — fire_wotlk.lua:23 Scorch precedent),
-- so the window tracks the real talented/hasted cast time instead of a
-- constant. The WotLK base 2.0s is the fallback whenever the engine reports
-- nothing (mock harnesses / older clients), i.e. exactly the pre-existing
-- window. NOTE: the previous read of ACTION.Immolate._meta.cast_time could
-- never resolve at all — define_action builds array-style actions whose
-- _meta carries no cast_time — so the window was silently hardcoded.
local IMMOLATE_REFRESH_FALLBACK = 2.0
local _core = NS.core or _G.core or {}
local _get_spell_cast_time = _core.spell_book and _core.spell_book.get_spell_cast_time

-- Only sane engine cast times are accepted: a nil/zero/garbage read must not
-- close the window, or Immolate would never refresh again (fail-open).
local function resolve_immolate_refresh()
    if type(_get_spell_cast_time) == "function" then
        local ok, cast_time = pcall(_get_spell_cast_time, IMMOLATE_DEBUFF[1])
        if ok and type(cast_time) == "number" and cast_time > 0 and cast_time <= 6 then
            return cast_time
        end
    end
    return IMMOLATE_REFRESH_FALLBACK
end

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
-- Curse of Doom / Curse of Agony debuff ids (single WotLK ranks).
local DOOM_DEBUFF = { 47867 }
local AGONY_DEBUFF = { 47864 }

local DESTRUCTION_SCHEMA = {
    enemy_count = 1, in_combat = false,
    immolate_remains = 0,
    has_backdraft = false,
    elements_remains = 0,
    doom_remains = 0,
    agony_remains = 0,
    target_is_boss = false,
    target_hp = 100,
    shadowburn_cd = 99,
    conflagrate_cd = 0,
    chaos_bolt_cd = 0,
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
    -- Curse-slot reads (fails closed to 0 like the CoE read above).
    state.doom_remains = (target and NS.debuff_remains and NS.debuff_remains(target, DOOM_DEBUFF)) or 0
    state.agony_remains = (target and NS.debuff_remains and NS.debuff_remains(target, AGONY_DEBUFF)) or 0
    -- Dispatcher-produced boss flag (main_sylvanas target_is_boss).
    state.target_is_boss = (context and context.target_is_boss == true) or false
    -- Execute band HP (dispatcher-produced context field; HammerOfWrath idiom)
    -- and the Shadowburn cooldown read (fails closed via 99).
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or (context and context.target_hp) or 100
    state.shadowburn_cd = (ACTION.Shadowburn and NS.cooldown_remains and NS.cooldown_remains(ACTION.Shadowburn)) or 99
    -- Conflagrate carries a real 10s WotLK cooldown; the fixture's sim gates
    -- on it implicitly. Fail-open to 0 = ready when the engine read is
    -- unavailable, so the lane can never go permanently dark.
    state.conflagrate_cd = (ACTION.Conflagrate and NS.cooldown_remains and NS.cooldown_remains(ACTION.Conflagrate)) or 0
    -- Chaos Bolt carries a real 12s WotLK cooldown (Wowhead 3.3.5: 59172 /
    -- 50796, "Cooldown 12 seconds"); fail-open to 0 = ready when the engine
    -- read is unavailable, so the lane can never go permanently dark.
    state.chaos_bolt_cd = (ACTION.ChaosBolt and NS.cooldown_remains and NS.cooldown_remains(ACTION.ChaosBolt)) or 0
    return state
end

-- ============================================================================
-- Declarative Strategy DSL definitions (12 strategies, 100% declarative)
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
    -- APL entry 4: refresh only once the remainder is inside the cast-time
    -- window (dotRemainingTime(47811) < spellCastTime(47811)). The window is a
    -- live engine value, not a constant, so it is evaluated at match time
    -- against the same read the trace reports (watch list below).
    {
        name = "Immolate",
        conditions = {
            { type = "custom", watch = { "immolate_remains" },
              fn = function(context, state)
                  return (state.immolate_remains or 0) < resolve_immolate_refresh()
              end },
        },
        action = { type = "cast", spell = ACTION.Immolate, target = "target", label = "[DESTRUCTION WOTLK] Immolate" },
    },
    -- APL entry 2: the top of the race, but only while the spell is actually
    -- available — WotLK Conflagrate has a real 10s cooldown that the fixture's
    -- sim gates on implicitly. Without the cooldown read the lane claimed the
    -- GCD on every frame it was on cooldown and the curse lanes below it
    -- (entries 3 and 8) only got a turn when the central guard happened to
    -- reject the recast.
    {
        name = "Conflagrate",
        conditions = {
            { type = "state", field = "immolate_remains", op = ">", value = 0 },
            { type = "state", field = "conflagrate_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.Conflagrate, target = "target", label = "[DESTRUCTION WOTLK] Conflagrate" },
    },
    -- APL entry 3: the long-fight curse (1-min CD / 1-min duration) on a
    -- boss; the cooldown itself keeps it from re-casting while the DoT runs,
    -- and doom_remains == 0 covers the first application.
    {
        name = "CurseOfDoom",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_boss", op = "truthy" },
            { type = "state", field = "doom_remains", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.CurseOfDoom, target = "target", label = "[DESTRUCTION WOTLK] Curse of Doom" },
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
    -- Chaos Bolt: mana AND the real 12s cooldown ready. Without the cooldown
    -- read the lane matched on mana alone while its cooldown ran, claiming the
    -- race above the fallback curse and every filler below it.
    {
        name = "ChaosBolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
            { type = "state", field = "chaos_bolt_cd", op = "<=", value = 0 },
        },
        action = { type = "cast", spell = ACTION.ChaosBolt, target = "target", label = "[DESTRUCTION WOTLK] Chaos Bolt" },
    },
    -- APL entry 8: fallback curse when Doom is not applicable (non-boss
    -- fight) — refresh below the 3s window, exactly one curse per warlock.
    {
        name = "CurseOfAgony",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_boss", op = "falsy" },
            { type = "state", field = "agony_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.CurseOfAgony, target = "target", label = "[DESTRUCTION WOTLK] Curse of Agony" },
    },
    {
        name = "Incinerate",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
        },
        action = { type = "cast", spell = ACTION.Incinerate, target = "target", label = "[DESTRUCTION WOTLK] Incinerate" },
    },
    -- Soul Fire is a 6s-cast / no-cooldown nuke (Wowhead 3.3.5: 47825 has no
    -- cooldown field), so no cooldown gate belongs on this lane; its long cast
    -- is only competitive inside a haste window, so the proc lane consumes the
    -- Backdraft aura (mirrors the repo's proc-consumer convention, e.g.
    -- BacklashShadowBolt). The plain SoulFire lane stays for non-Backdraft
    -- builds.
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
    { name = "CurseOfDoom" },
    { name = "Shadowburn" },
    { name = "Immolate" },
    { name = "ChaosBolt" },
    { name = "SoulFireBackdraft" },
    { name = "CurseOfAgony" },
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
