-- protection_wotlk.lua — Paladin Protection rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Protection paladin tanking: Righteous Fury
--          upkeep, Holy Shield charge management (Pattern 11 buff_points),
--          Avengers Shield, Shield of Righteousness, Hammer of the Righteous,
--          Consecration, Judgement.
-- WHEN:  combat with a valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims WotLK Protection APL with 3.3.5-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); Holy Shield charges
--         tracked via NS.buff_points with a configurable refresh floor; Righteous
--         Fury lane carries a 3s anti-loop throttle; DSL conditions replace
--         imperative match functions; no on_update() allocations.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Plain define_action (NOT define_action_for_class): the WotLK client loads the
-- TBC class_sylvanas.lua into NS.<Class>Spells, so the class-first resolver would
-- shadow these WotLK rank ladders with TBC-era rank lists.
local define = spec_kit.define_action

local ACTION = {
    -- 48999 removed (2026-08-08): wowhead WotLK Classic spell=48999 is Warrior
    -- Counterattack, NOT Avenger's Shield — a rank-list typo (see
    -- tests/run_wotlk_audit_tests.lua WOTLK_REJECTED_IDS).
    AvengersShield = define("AvengersShield", { 48827, 48826, 32700, 32699, 31935 }, "AvengersShield"),
    HammerOfTheRighteous = define("HammerOfTheRighteous", 53595, "HammerOfTheRighteous"),
    ShieldOfRighteousness = define("ShieldOfRighteousness", { 53600, 61411 }, "ShieldOfRighteousness"),
    Consecration = define("Consecration", { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }, "Consecration"),
    Judgement = define("Judgement", { 20271, 53407, 53408 }, "Judgement"),
    RighteousFury = define("RighteousFury", 25780, "RighteousFury"),
    -- Holy Shield ladder: 48927 = 3.3.5 max rank, 27179/20925 = TBC-era ranks
    -- (all pinned in run_wotlk_audit_tests.lua WOTLK_REFERENCE_ALIASES).
    HolyShield = define("HolyShield", { 48927, 27179, 20925 }, "HolyShield"),
}

local CONSECRATION_DEBUFF = { 48819, 27173, 20924, 20923, 20922, 20116, 26573 }
local RIGHTEOUS_FURY_BUFF = { 25780 }
local HOLY_SHIELD_BUFF = { 48927, 27179, 20925 }

-- -----------------------------------------------------------------------------
-- State table (raw; safe_state proxy applied in build_state)
-- -----------------------------------------------------------------------------
local protection_state = {
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    consecration_remains = 0,
    righteous_fury_up = false,
    holy_shield_up = false,
    holy_shield_charges = 0,
    holy_shield_ready = false,
}

-- -----------------------------------------------------------------------------
-- build_state(context) — populate state from context + NS, return safe_state proxy
-- -----------------------------------------------------------------------------
local function build_state(context)
    local state = spec_kit.safe_state(protection_state)
    context = context or {}
    local me = NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context.target

    -- context.mana_pct is dispatcher-set (main_sylvanas.lua:795); me:mana_pct()
    -- is the IZI SDK unit method. me:get_mana_percentage() is mock-only (W3.4).
    state.mana_pct = (context and context.mana_pct)
        or (me and me.mana_pct and me:mana_pct())
        or (NS.unit_mana_pct and NS.unit_mana_pct(me))
        or 100
    state.enemy_count = (context.enemy_count or 1)
    state.in_combat = (context.in_combat == true)
    state.consecration_remains = (target and NS.debuff_remains and NS.debuff_remains(target, CONSECRATION_DEBUFF)) or 0
    state.righteous_fury_up = (me and NS.buff_up and NS.buff_up(me, RIGHTEOUS_FURY_BUFF)) or false
    state.holy_shield_up = (me and NS.buff_up and NS.buff_up(me, HOLY_SHIELD_BUFF)) or false
    -- Pattern 11: buff.points[1] is the remaining Holy Shield block count
    -- (8 base, 10 with Imp Holy Shield) — drive the proactive refresh floor.
    state.holy_shield_charges = 0
    if state.holy_shield_up and type(NS.buff_points) == "function" then
        local pts = NS.buff_points(me, HOLY_SHIELD_BUFF)
        state.holy_shield_charges = (pts and pts[1]) or 0
    end
    state.holy_shield_ready = (me and NS.spell_ready and NS.spell_ready(ACTION.HolyShield, me, { skip_range = true, expected_cooldown = 10 })) or false

    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
-- Righteous Fury anti-loop throttle (must be declared BEFORE the DSL_DEFS
-- closure references it — a later declaration resolves to a global nil and the
-- `now - stamp` arithmetic errors inside the pcall'd custom fn).
local _last_righteous_fury_match_time = -999

local DSL_DEFS = {
    {
        name = "AvengersShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.AvengersShield, target = "target" },
    },
    {
        name = "ShieldOfRighteousness",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.ShieldOfRighteousness, target = "target" },
    },
    {
        name = "HammerOfTheRighteous",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.HammerOfTheRighteous, target = "target" },
    },
    {
        name = "Consecration",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "consecration_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Consecration, target = "target" },
    },
    {
        name = "Judgement",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
        },
        action = { type = "cast", spell = ACTION.Judgement, target = "target" },
    },
    -- Righteous Fury upkeep: the tanking threat multiplier is never applied by
    -- any other lane. Unconditional (no setting gate) with a 3s anti-loop
    -- throttle mirroring protection_sylvanas.lua — the buff-outcome read can
    -- lag a cast, and re-matching every tick would re-cast a 30-min buff.
    {
        name = "RighteousFury",
        conditions = {
            { type = "state", field = "righteous_fury_up", op = "falsy" },
            { type = "custom", fn = function(context, state)
                local now = NS.time_now and NS.time_now() or 0
                if (now - _last_righteous_fury_match_time) < 3.0 then return false end
                _last_righteous_fury_match_time = now
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.RighteousFury, target = "self" },
    },
    -- Holy Shield charge management (Pattern 11): refresh when the buff is down
    -- OR remaining blocks drop to the configured floor (default 2). Keeps the
    -- 100%-uptime tanking convention without re-casting a full-charge shield.
    {
        name = "HolyShield",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "holy_shield_ready", op = "truthy" },
            { type = "custom", fn = function(context, state)
                if state.holy_shield_up then
                    local charges = state.holy_shield_charges or 0
                    local refresh_at = spec_kit.setting_number(context, "prot_holy_shield_charges", 2)
                    if charges > refresh_at then return false end
                end
                return true
            end },
        },
        action = { type = "cast", spell = ACTION.HolyShield, target = "self" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "AvengersShield" },
    { name = "ShieldOfRighteousness" },
    { name = "HammerOfTheRighteous" },
    { name = "Consecration" },
    { name = "Judgement" },
    { name = "RighteousFury" },
    { name = "HolyShield" },
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
    NS.rotation_registry:register("protection", strategies, { get_state = build_state })
end
if NS.log then NS.log("Paladin Protection WotLK rotation registered") end

return { strategies = strategies, build_state = build_state }
