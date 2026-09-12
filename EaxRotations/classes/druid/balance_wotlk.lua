-- balance_wotlk.lua — Druid Balance rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Balance druid: Moonkin form upkeep,
--        Starfall on cooldown (single-target included), Moonfire/Insect Swarm
--        refresh, Eclipse-driven Starfire/Wrath spell-switching (solar eclipse
--        buffs Wrath; no/solar-down and lunar eclipse favor Starfire).
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION: mana comes from context.mana_pct (main_sylvanas:795) or
--         NS.mana_pct(me) — the mock-only me:get_mana_percentage() made the
--         mana gates inert live (unrestrained casting to OOM, W3.1 audit).
--         Starfall 48505 is the only castable WotLK rank (50286 is a
--         non-player proc spell, not a second rank — omission intentional).
--         Insect Swarm does not snapshot in this simple DSL (the TBC sibling
--         owns snapshot support via snapshot_sylvanas); the DoT is plain
--         refresh-gated. Starfire stays ABOVE Wrath (APL pin).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")
-- Engine school-lockout gate: balance is the one caster school-swapping spec —
-- Wrath is nature, Starfire/Moonfire are arcane. After an interrupt the locked
-- school must be dropped for the other one, which is exactly what the gate
-- below drives (main_sylvanas publishes the native lockout mask).
local school_gate = require("shared/spell_school_gate_sylvanas")

-- Plain define_action: file-local WotLK rank lists must win over the
-- TBC-capped DruidSpells class table (precedent: mage/fire_wotlk.lua:20).
local define = spec_kit.define_action

local ACTION = {
    MoonkinForm = define("MoonkinForm", 24858, "MoonkinForm"),
    InsectSwarm = define("InsectSwarm", { 48468, 27013, 24977, 24976, 24975, 24974, 5570 }, "InsectSwarm"),
    Moonfire = define("Moonfire", { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }, "Moonfire"),
    Starfall = define("Starfall", 48505, "Starfall"),
    Wrath = define("Wrath", { 48461, 26985, 26984, 9912, 8905, 6780, 5180, 5179, 5178, 5177, 5176 }, "Wrath"),
    Starfire = define("Starfire", { 48465, 26986, 25298, 9876, 9875, 8951, 8950, 8949, 2912 }, "Starfire"),
    -- Guide-priority additions: Faerie Fire debuff upkeep (3% spell hit,
    -- caster ladder — no WotLK rank exists; 26993 stays the max, mirroring
    -- caster_sylvanas) and Hurricane 48467 (Wowhead-verified single WotLK
    -- rank; channeled 10y AoE). Hurricane is a CHANNEL action (resto_wotlk
    -- Tranquility idiom) — a plain cast would re-queue every GCD.
    FaerieFire = define("FaerieFire", { 26993, 9907, 9749, 778, 770 }, "FaerieFire"),
    Hurricane = define("Hurricane", { 48467 }, "Hurricane"),
    -- 2026-09-11 guide-pass lanes: Force of Nature 33831 (3 treants, 30s, the
    -- balance burst CD — Wowhead-verified single rank; bear/resto siblings
    -- already carry Barkskin 22812 and Innervate 29166 audit-clean).
    ForceOfNature = define("ForceOfNature", 33831, "ForceOfNature"),
    Barkskin = define("Barkskin", 22812, "Barkskin"),
    Innervate = define("Innervate", { 29166 }, "Innervate"),
}

-- Max-rank-first debuff tables: the WotLK DoT auras are 48463 (Moonfire) /
-- 48468 (Insect Swarm); TBC-only tables read 0 at max rank and re-cast every
-- GCD (systemic injection #3).
local MOONKIN_FORM_BUFF = { 24858 }
local ECLIPSE_SOLAR_BUFF = { 48517 }
local ECLIPSE_LUNAR_BUFF = { 48518 }
local INSECT_SWARM_DEBUFF = { 48468, 27013, 24977, 24976, 24975, 24974, 5570 }
local MOONFIRE_DEBUFF = { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }
local FAERIE_FIRE_DEBUFF = { 26993, 9907, 9749, 778, 770 }

local balance_state = {
    hp = 100,
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    moonkin_up = false,
    eclipse_solar = false,
    eclipse_lunar = false,
    insect_swarm_remains = 0,
    moonfire_remains = 0,
    faerie_remains = 0,
    nature_locked = false,
    arcane_locked = false,
    barkskin_ready = false,
    innervate_ready = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(balance_state)
    local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.mana_pct = (context and context.mana_pct)
        or (NS.mana_pct and me and NS.mana_pct(me))
        or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.moonkin_up = (me and NS.buff_up and NS.buff_up(me, MOONKIN_FORM_BUFF)) or false
    -- Eclipse: solar (48517) buffs Wrath; lunar (48518) buffs Starfire. The
    -- talent procs swap the buff on crits — tracking both drives the
    -- spell-switch gates below (W3.1 audit: Eclipse was entirely missing).
    state.eclipse_solar = (me and NS.buff_up and NS.buff_up(me, ECLIPSE_SOLAR_BUFF)) or false
    state.eclipse_lunar = (me and NS.buff_up and NS.buff_up(me, ECLIPSE_LUNAR_BUFF)) or false
    state.insect_swarm_remains = (target and NS.debuff_remains and NS.debuff_remains(target, INSECT_SWARM_DEBUFF)) or 0
    state.moonfire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MOONFIRE_DEBUFF)) or 0
    state.faerie_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_DEBUFF)) or 0
    -- School lockout (engine LoC mask): nature locks drop Wrath, arcane locks
    -- drop Starfire/Moonfire — the fallback lane below casts the other school.
    state.nature_locked = school_gate.locked(context, school_gate.SCHOOL.NATURE)
    state.arcane_locked = school_gate.locked(context, school_gate.SCHOOL.ARCANE)
    -- Defensive/utility readiness (real engine reads; Barkskin + Innervate are
    -- the balance survival/mana tools in the guides).
    state.hp = (context and context.hp) or (me and me.get_health_percentage and me:get_health_percentage()) or 100
    state.barkskin_ready = (ACTION.Barkskin and NS.spell_ready and NS.spell_ready(ACTION.Barkskin, me, { skip_range = true })) or false
    state.innervate_ready = (ACTION.Innervate and NS.spell_ready and NS.spell_ready(ACTION.Innervate, me, { skip_range = true })) or false
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "MoonkinForm",
        conditions = {
            -- in_combat guard: prevents OOC form-shift GCD spam (W3.1 nit).
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "moonkin_up", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.MoonkinForm, target = "self" },
    },
    {
        name = "Starfall",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            -- W3.1 audit: the enemy_count >= 2 gate made Starfall never fire
            -- on a single target — its primary use (the APL pin excludes
            -- Starfall, so the gate is freely fixable).
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 60) then return false end
                return true
            end },
            -- Real engine readiness (spell_action exposes no cooldown_remaining).
            { type = "spell_ready", spell = ACTION.Starfall, target = "target" },
        },
        action = { type = "cast", spell = ACTION.Starfall, target = "target" },
    },
    {
        name = "Moonfire",
        conditions = {
            { type = "state", field = "moonfire_remains", op = "<", value = 3 },
            -- School lockout (engine LoC mask): Moonfire is arcane — while the
            -- arcane school is interrupted the engine refuses it, so the lane
            -- holds and Wrath (nature) keeps the damage flowing below.
            { type = "state", field = "arcane_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Moonfire, target = "target" },
    },
    {
        name = "Starfire",
        conditions = {
            -- Eclipse switching (proper spell-switch, mirroring the pinned
            -- wowsims APL druid_balance_wotlk.apl.json: Starfire gates on
            -- LUNAR eclipse 48518, Wrath on SOLAR 48517). Starfire is skipped
            -- during solar; it fires during lunar eclipse AND as the
            -- no-eclipse filler (the no-eclipse casts are what proc solar).
            -- The explicit eclipse_lunar branch mirrors the APL's 48518 gate
            -- (W3.4: reads the field — eclipse_lunar is tracked, not
            -- vestigial) while the not-solar fallback preserves the filler.
            { type = "OR", conditions = {
                { type = "state", field = "eclipse_lunar", op = "truthy" },
                { type = "state", field = "eclipse_solar", op = "falsy" },
                -- School-lockout fallback: with nature interrupted, arcane is
                -- the only school the engine accepts, so Starfire fires even
                -- during solar eclipse (where it would normally hold).
                { type = "state", field = "nature_locked", op = "truthy" },
            } },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
            -- School lockout: Starfire is arcane — an arcane interrupt refuses
            -- the cast, so the lane holds and nature (Wrath) covers instead.
            { type = "state", field = "arcane_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Starfire, target = "target" },
    },
    {
        name = "Wrath",
        conditions = {
            -- Eclipse: Wrath is the solar filler — plus the school-lockout
            -- fallback below (arcane interrupted ⇒ nature is the only school
            -- left, so Wrath fires regardless of eclipse state).
            { type = "OR", conditions = {
                { type = "state", field = "eclipse_solar", op = "truthy" },
                { type = "state", field = "arcane_locked", op = "truthy" },
            } },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
            -- School lockout: Wrath is nature; a nature interrupt holds it and
            -- the arcane lanes above become the fallback — the canonical WotLK
            -- balance school-swap the guides describe.
            { type = "state", field = "nature_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.Wrath, target = "target" },
    },
    {
        name = "FaerieFire",
        conditions = {
            -- Debuff upkeep (guide priority): 3% spell hit on the target;
            -- refresh in the last 3s like the DoT lanes.
            { type = "state", field = "faerie_remains", op = "<", value = 3 },
            -- Faerie Fire is nature: hold it while that school is interrupted
            -- (refreshes as soon as the lock expires).
            { type = "state", field = "nature_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.FaerieFire, target = "target" },
    },
    {
        name = "InsectSwarm",
        conditions = {
            { type = "state", field = "insect_swarm_remains", op = "<", value = 3 },
            { type = "state", field = "nature_locked", op = "falsy" },
        },
        action = { type = "cast", spell = ACTION.InsectSwarm, target = "target" },
    },
    {
        name = "HurricaneAoE",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                -- AoE wave (3+ in 10y self radius, hurricane_aoe idiom) —
                -- the guide's balance cleave slot after DoTs are rolling.
                return (state.enemy_count or 1) >= 3
                    and NS.aoe_target_meets and NS.aoe_target_meets(3, (NS.AOE_RADIUS and NS.AOE_RADIUS.SELF_10) or 10, context and context.target, context)
            end },
            -- Channel readiness (real engine cooldown read) + school lockout
            -- (Hurricane is nature; a nature interrupt refuses the channel).
            { type = "spell_ready", spell = ACTION.Hurricane, target = "target" },
            { type = "state", field = "nature_locked", op = "falsy" },
        },
        -- Channeled AoE (resto_wotlk Tranquility idiom — the DSL has no
        -- channel action type; a custom fn routes the cast directly).
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.Hurricane, context and context.target, "[BALANCE WOTLK] Hurricane") == true
        end },
    },
    -- 2026-09-11 engine-signal wave (scorecard thinnest tier): the guide's
    -- balance burst, defensive and mana tools. The school-lockout fallback is
    -- expressed by the `*_locked` conditions on Moonfire/Starfire (arcane) and
    -- Wrath (nature) above — when one school is interrupted the other keeps
    -- casting, which is the whole point of the engine's lockout signal.
    {
        name = "ForceOfNature",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if NS.should_use_long_cd and not NS.should_use_long_cd(context, 180) then return false end
                return true
            end },
            { type = "spell_ready", spell = ACTION.ForceOfNature, target = "self" },
        },
        action = { type = "cast", spell = ACTION.ForceOfNature, target = "self" },
    },
    {
        name = "Barkskin",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "hp", op = "<", value = 60 },
            { type = "state", field = "barkskin_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Barkskin, target = "self" },
    },
    {
        name = "Innervate",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "mana_pct", op = "<", value = 25 },
            { type = "state", field = "innervate_ready", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Innervate, target = "self" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "MoonkinForm" },
    { name = "ForceOfNature" },
    { name = "Starfall" },
    { name = "Innervate" },
    { name = "Barkskin" },
    { name = "Moonfire" },
    { name = "Starfire" },
    { name = "Wrath" },
    { name = "InsectSwarm" },
    { name = "FaerieFire" },
    { name = "HurricaneAoE" },
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
