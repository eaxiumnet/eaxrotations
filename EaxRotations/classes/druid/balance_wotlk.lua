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
}

-- Max-rank-first debuff tables: the WotLK DoT auras are 48463 (Moonfire) /
-- 48468 (Insect Swarm); TBC-only tables read 0 at max rank and re-cast every
-- GCD (systemic injection #3).
local MOONKIN_FORM_BUFF = { 24858 }
local ECLIPSE_SOLAR_BUFF = { 48517 }
local ECLIPSE_LUNAR_BUFF = { 48518 }
local INSECT_SWARM_DEBUFF = { 48468, 27013, 24977, 24976, 24975, 24974, 5570 }
local MOONFIRE_DEBUFF = { 48463, 26988, 26987, 9835, 9834, 9833, 8929, 8928, 8927, 8926, 8925, 8924, 8921 }

local balance_state = {
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    moonkin_up = false,
    eclipse_solar = false,
    eclipse_lunar = false,
    insect_swarm_remains = 0,
    moonfire_remains = 0,
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
            } },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Starfire, target = "target" },
    },
    {
        name = "Wrath",
        conditions = {
            { type = "state", field = "eclipse_solar", op = "truthy" },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
        },
        action = { type = "cast", spell = ACTION.Wrath, target = "target" },
    },
    {
        name = "InsectSwarm",
        conditions = {
            { type = "state", field = "insect_swarm_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.InsectSwarm, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL)
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "MoonkinForm" },
    { name = "Starfall" },
    { name = "Moonfire" },
    { name = "Starfire" },
    { name = "Wrath" },
    { name = "InsectSwarm" },
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
