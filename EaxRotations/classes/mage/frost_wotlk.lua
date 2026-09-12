-- frost_wotlk.lua — Mage Frost rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Frost mage: ColdSnap panic heal, DeepFreeze
--        on frozen targets OR Fingers of Frost, FrostfireBolt debuff (44549)
--        refresh, IceLance on frozen/FoF, Frostbolt filler.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors wowsims APL (ui/mage/apls/frost.apl.json — pinned fixture):
--        DeepFreeze on aura 44545 (FoF), FFB on debuff 44549, Frostbolt filler.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions replace
--         imperative match functions; no on_update() allocs.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
-- Cast/channel end-time gate (2026-09-12): an interrupt that lands after the
-- target's cast completes wastes its cooldown. Fail-open when the engine
-- reports no end time (shared/cast_timing_sylvanas.lua).
local _ct_ok, cast_timing = pcall(require, "shared/cast_timing_sylvanas")
if not _ct_ok or type(cast_timing) ~= "table" then
    cast_timing = { context_interrupt_open = function() return true end }
end
-- Engine school-lockout gate: after an interrupt the frost school can be locked,
-- and every frost cast is refused by the engine. The gate reads the native
-- lockout mask (main_sylvanas → context.school_lockout) so the rotation falls
-- back to its off-school instant (Fire Blast) instead of spam-queueing Frostbolt.
local school_gate = require("shared/spell_school_gate_sylvanas")

-- Plain define_action (NOT define_action_for_class): NS.MageSpells is TBC-era,
-- so the class-bound resolver would shadow these WotLK rank ladders with TBC
-- ranks (systemic W3.3 fix — fire_wotlk.lua is the clean precedent).
local define = spec_kit.define_action

local ACTION = {
    -- Frostbolt: full rank ladder, max-first (42842 = 3.3.5 max; the old ladder
    -- carried 10175/10176 Dampen Magic + 10177 Frost Ward — wrong-family).
    Frostbolt = define("Frostbolt", { 42842, 27072, 27071, 25304, 10181, 10180, 10179, 8408, 8407, 8406, 7322, 837, 205, 116 }, "Frostbolt"),
    FrostfireBolt = define("FrostfireBolt", 47610, "FrostfireBolt"), -- 47610 = max-rank FFB (44614 = rank 1)
    IceLance = define("IceLance", { 42914, 30455 }, "IceLance"),
    DeepFreeze = define("DeepFreeze", 44572, "DeepFreeze"),
    ColdSnap = define("ColdSnap", 11958, "ColdSnap"),
    Counterspell = define("Counterspell", { 2139 }, "Counterspell"),
    -- 2026-09-09 guide-pass additions (wowsims frost APL burst): Icy Veins
    -- 12472 (20% haste, 3-min CD, single rank) and Summon Water Elemental
    -- 31687 (permanent pet, 3-min CD, single rank) - both bridge-verified.
    IcyVeins = define("IcyVeins", 12472, "IcyVeins"),
    SummonWaterElemental = define("SummonWaterElemental", 31687, "SummonWaterElemental"),
    -- 2026-09-11 school-lockout wave: Fire Blast 42873 (fire school, instant) is
    -- the OFF-SCHOOL fallback the frost guides name for a frost lockout; the
    -- same audit-clean id fire_wotlk.lua defines. Ice Barrier is the full WotLK
    -- ladder (43039 r8 max 3300 absorb, 43038 r7 2860 — both Wowhead-verified
    -- this pass; 33405 r6 … 11426 r1 are bridge-present).
    FireBlast = define("FireBlast", { 42873 }, "FireBlast"),
    IceBarrier = define("IceBarrier", { 43039, 43038, 33405, 27134, 13033, 13032, 13031, 11426 }, "IceBarrier"),
    -- Burst + mana-recovery defines for the same wave: Mirror Image 55342 (3
    -- copies, 3-min CD) and Evocation 12051 (channeled mana refill) — the exact
    -- single-rank ids fire_wotlk.lua / arcane_wotlk.lua already carry
    -- audit-clean.
    MirrorImage = define("MirrorImage", { 55342 }, "MirrorImage"),
    Evocation = define("Evocation", { 12051 }, "Evocation"),
}

-- 44549 = the Frostfire Bolt DEBUFF aura (wowsims APL refreshes FFB on it);
-- 47610 is the CAST spell id, not a debuff (the old table was wrong).
local FROSTFIRE_BOLT_DEBUFF = { 44549 }
-- Frost Nova root family incl. the WotLK max rank 42917 (W3.3 fix: without it
-- a WotLK-rank Nova root was invisible to the frozen check).
local FROST_NOVA_DEBUFF = { 122, 865, 6131, 10230, 42917 }
-- Fingers of Frost proc buff (wowsims APL gates DeepFreeze on aura 44545).
local FINGERS_OF_FROST_BUFF = { 44545 }
-- Ice Barrier shield aura (mirrors the action ladder: max-rank-first so a
-- level-80 cast registers as up).
local ICE_BARRIER_BUFF = { 43039, 43038, 33405, 27134, 13033, 13032, 13031, 11426 }

local frost_state = {
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    frostfire_remains = 0,
    target_frozen = false,
    target_is_casting = false,
    icy_veins_ready = false,
    water_elemental_ready = false,
    has_pet = false,
    frost_locked = false,
    fire_locked = false,
    barrier_up = false,
    barrier_ready = false,
    evocation_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(frost_state)
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    -- context.hp / context.mana_pct are dispatcher-set; me:mana_pct() is the
    -- IZI SDK unit method (me:get_mana_percentage() is mock-only, W3.3).
    state.hp = (context and context.hp)
        or (me and me.get_health_percentage and me:get_health_percentage())
        or 100
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (NS.unit_mana_pct and NS.unit_mana_pct(me))
        or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    -- Cooldown availability (real API: NS.cooldown_remains, 0 = ready) for the
    -- guide-pass burst lanes; has_pet drives the elemental re-summon hold.
    local me_self = NS.PLAYER_UNIT or me
    state.icy_veins_ready = (ACTION.IcyVeins and NS.cooldown_remains and NS.cooldown_remains(ACTION.IcyVeins, me_self) <= 0) or false
    state.water_elemental_ready = (ACTION.SummonWaterElemental and NS.cooldown_remains and NS.cooldown_remains(ACTION.SummonWaterElemental, me_self) <= 0) or false
    state.has_pet = (NS.has_pet and NS.has_pet()) or false
    state.frostfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FROSTFIRE_BOLT_DEBUFF)) or 0
    -- Frozen = target rooted by the Frost Nova family (incl. WotLK 42917) OR
    -- the Fingers of Frost proc (44545) — the wowsims DeepFreeze gate.
    state.target_frozen = (target and NS.debuff_up and NS.debuff_up(target, FROST_NOVA_DEBUFF))
        or (me and NS.buff_up and NS.buff_up(me, FINGERS_OF_FROST_BUFF))
        or false
    state.target_is_casting = (target and target.is_casting and target:is_casting()) or false
    -- School lockout (engine LoC mask, published by main_sylvanas): the frost
    -- lanes hold while frost is locked and FireBlast is the off-school cast.
    state.frost_locked = school_gate.locked(context, school_gate.SCHOOL.FROST)
    state.fire_locked = school_gate.locked(context, school_gate.SCHOOL.FIRE)
    -- Defensive shield + mana lanes (guide band: keep the barrier rolling when
    -- pressured, Evocate when the pool runs dry). Both are real readiness reads.
    state.barrier_up = (me and NS.buff_up and NS.buff_up(me, ICE_BARRIER_BUFF)) or false
    state.barrier_ready = (ACTION.IceBarrier and NS.spell_ready and NS.spell_ready(ACTION.IceBarrier, me_self, { skip_range = true })) or false
    state.evocation_ready = (ACTION.Evocation and NS.spell_ready and NS.spell_ready(ACTION.Evocation, me_self, { skip_range = true })) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "Counterspell",
        conditions = {
            { type = "custom", fn = function(context, state)
                return cast_timing.context_interrupt_open(context, context and context.settings)
            end },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "target_is_casting", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Counterspell, target = "target" },
    },
    {
        name = "ColdSnap",
        conditions = {
            { type = "state", field = "hp", op = "<", value = 50 },
        },
        action = { type = "cast", spell = ACTION.ColdSnap, target = "self" },
    },
    {
        name = "SummonWaterElemental",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "water_elemental_ready", op = "truthy" },
            { type = "state", field = "has_pet", op = "falsy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.SummonWaterElemental, target = "self" },
    },
    {
        name = "IcyVeins",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "icy_veins_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.IcyVeins, target = "self" },
    },
    {
        name = "DeepFreeze",
        conditions = {
            { type = "state", field = "target_frozen", op = "truthy" },
            -- School lockout: DeepFreeze is frost — refuse to queue it while the
            -- engine would reject the cast (FireBlast below covers the window).
            { type = "state", field = "frost_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.DeepFreeze, target = "target" },
    },
    {
        name = "FrostfireBolt",
        conditions = {
            { type = "state", field = "frostfire_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 20 },
            { type = "state", field = "frost_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.FrostfireBolt, target = "target" },
    },
    {
        name = "FireBlast",
        conditions = {
            -- OFF-SCHOOL fallback (engine lockout signal): the frost school is
            -- locked, so the only frost-side casts the engine accepts are none —
            -- Fire Blast is the instant fire-school filler the guides name.
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "frost_locked", op = "truthy" },
            { type = "state", field = "fire_locked", op = "falsy" },
            { type = "state", field = "mana_pct", op = ">=", value = 10 },
        },
        action = { type = "cast", spell = ACTION.FireBlast, target = "target" },
    },
    {
        name = "IceLance",
        conditions = {
            { type = "state", field = "target_frozen", op = "truthy" },
            { type = "state", field = "frost_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.IceLance, target = "target" },
    },
    {
        name = "Frostbolt",
        conditions = {
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
            { type = "state", field = "frost_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Frostbolt, target = "target" },
    },
    -- 2026-09-11 guide-pass lanes (scorecard thinnest tier): burst CD, mana
    -- recovery and the defensive shield band — each mirroring the audit-clean
    -- fire_wotlk/arcane_wotlk idiom.
    {
        name = "MirrorImage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.MirrorImage, target = "self" },
        },
        action = { type = "cast", spell = ACTION.MirrorImage, target = "self" },
    },
    {
        name = "Evocation",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 40 },
            { type = "state", field = "evocation_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Evocation, target = "self" },
    },
    {
        name = "IceBarrier",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "barrier_up", op = "falsy" },
            { type = "state", field = "barrier_ready", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 70 },
        },
        action = { type = "cast", spell = ACTION.IceBarrier, target = "self" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "Counterspell" },
    { name = "SummonWaterElemental" },
    { name = "IcyVeins" },
    { name = "MirrorImage" },
    { name = "ColdSnap" },
    { name = "IceBarrier" },
    { name = "Evocation" },
    { name = "DeepFreeze" },
    { name = "FrostfireBolt" },
    { name = "FireBlast" },
    { name = "IceLance" },
    { name = "Frostbolt" },
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
    NS.rotation_registry:register("frost", strategies, { get_state = build_state })
end
if NS.log then NS.log("Mage Frost WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
