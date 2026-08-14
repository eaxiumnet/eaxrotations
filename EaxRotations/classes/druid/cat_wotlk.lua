-- cat_wotlk.lua — Druid Feral Cat rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Feral Cat druid: FF upkeep, Tiger's Fury
--        + Berserk CDs above the refresh cycle, SavageRoar/Rip 5-CP finishers,
--        FerociousBite execute + healthy-window 5-CP dump, Mangle debuff
--        refresh, Rake/Shred builders, Omen-of-Clarity free Shred.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); DSL conditions
--         replace imperative match functions; no on_update() allocs.
-- DECISION: energy/combo come from context (main_sylvanas:816/878) or
--         me:get_power(POWER_ENERGY/POWER_COMBO) — the mock-only
--         me:get_energy()/me:get_combo_points() pinned both at 0 live and
--         collapsed every spender/finisher into never-lanes (W3.1 audit).
--         Ravage is stealth-opener only: Prowl is manual (no auto-Prowl lane
--         here — the TBC sibling owns the OOC Prowl automation). Rip/Rake
--         snapshot upgrade support lives in the TBC sibling via
--         snapshot_sylvanas; this simple DSL refresh-gates only.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl = require("shared/strategy_dsl_sylvanas")

-- Plain define_action: file-local WotLK rank lists must win over the
-- TBC-capped DruidSpells class table (precedent: mage/fire_wotlk.lua:20).
local define = spec_kit.define_action

local ACTION = {
    FaerieFireFeral = define("FaerieFireFeral", { 27011, 17392, 17391, 17390, 16857 }, "FaerieFireFeral"),
    Ravage = define("Ravage", { 48579, 27005, 9867, 9866, 6787, 6785 }, "Ravage"),
    TigersFury = define("TigersFury", { 48479, 5217 }, "TigersFury"),
    Berserk = define("Berserk", { 50334 }, "Berserk"),
    MangleCat = define("MangleCat", { 48566, 33983, 33982, 33876 }, "MangleCat"),
    Rake = define("Rake", { 48574, 27003, 9904, 1824, 1823, 1822 }, "Rake"),
    Rip = define("Rip", { 49800, 27008, 9896, 9894, 9752, 9493, 9492, 1079 }, "Rip"),
    SavageRoar = define("SavageRoar", 52610, "SavageRoar"),
    FerociousBite = define("FerociousBite", { 48576, 24248, 31018, 22829, 22828, 22827, 22568 }, "FerociousBite"),
    Shred = define("Shred", { 48572, 27002, 27001, 9830, 9829, 8992, 6800, 5221 }, "Shred"),
}

-- Max-rank-first debuff/aura tables: WotLK DoT auras use the WotLK spell ids
-- (48574 Rake / 49800 Rip), so TBC-only tables read 0 at max rank and the
-- refresh gates re-cast every GCD (systemic injection #3).
local RAKE_DEBUFF = { 48574, 27003, 9904, 1824, 1823, 1822 }
local RIP_DEBUFF = { 49800, 27008, 9896, 9894, 9752, 9493, 9492, 1079 }
local FAERIE_FIRE_FERAL_DEBUFF = { 27011, 17392, 17391, 17390, 16857 }
-- Mangle (Cat) applies a bleed-vulnerability debuff with the same ids as the
-- spell ranks; wowsims mangleNow fires only when this debuff needs refreshing
-- (mangleRefreshNow = !bleedAura.IsActive()), NOT as an unconditional filler.
local MANGLE_DEBUFF = { 48566, 33983, 33982, 33876 }
local SAVAGE_ROAR_BUFF = { 52610 }
local TIGERS_FURY_BUFF = { 48479, 5217 }
local BERSERK_BUFF = { 50334 }
local OMEN_OF_CLARITY_BUFF = { 16864 }
local PROWL_BUFF = { 9913, 6783, 5215 }

local cat_state = {
    target_hp = 100,
    energy = 0,
    combo_points = 0,
    enemy_count = 1,
    in_combat = false,
    rake_remains = 0,
    rip_remains = 0,
    faerie_fire_remains = 0,
    mangle_remains = 0,
    savage_roar_remains = 0,
    clearcasting = false,
    has_tigers_fury = false,
    is_stealthed = false,
    is_behind = false,
}

local function build_state(context)
    local state = spec_kit.safe_state(cat_state)
    local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
    local target = context and context.target
    state.target_hp = (target and target.get_health_percentage and target:get_health_percentage()) or (context and context.target_hp) or 100
    state.energy = (context and context.energy)
        or (me and me.get_power and me:get_power(NS.POWER_ENERGY))
        or 0
    state.combo_points = (context and context.combo_points)
        or (me and me.get_power and me:get_power(NS.POWER_COMBO))
        or 0
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.rake_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RAKE_DEBUFF)) or 0
    state.rip_remains = (target and NS.debuff_remains and NS.debuff_remains(target, RIP_DEBUFF)) or 0
    state.faerie_fire_remains = (target and NS.debuff_remains and NS.debuff_remains(target, FAERIE_FIRE_FERAL_DEBUFF)) or 0
    state.mangle_remains = (target and NS.debuff_remains and NS.debuff_remains(target, MANGLE_DEBUFF)) or 0
    state.savage_roar_remains = (me and NS.buff_remains and NS.buff_remains(me, SAVAGE_ROAR_BUFF)) or 0
    state.clearcasting = (me and NS.buff_up and NS.buff_up(me, OMEN_OF_CLARITY_BUFF)) or false
    state.has_tigers_fury = (me and NS.buff_up and NS.buff_up(me, TIGERS_FURY_BUFF)) or false
    state.is_stealthed = (context and context.is_stealthed == true) or (me and NS.buff_up and NS.buff_up(me, PROWL_BUFF)) or false
    -- Strict behind check for Shred (spell requires being behind target)
    if context and context.is_behind ~= nil then
        state.is_behind = context.is_behind == true
    elseif NS.is_behind_target and target then
        state.is_behind = NS.is_behind_target(target) == true
    else
        state.is_behind = false
    end
    return state
end

-- -----------------------------------------------------------------------------
-- Declarative Strategy DSL definitions
-- -----------------------------------------------------------------------------
local DSL_DEFS = {
    {
        name = "FaerieFireFeral",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "faerie_fire_remains", op = "<", value = 3 },
        },
        action = { type = "cast", spell = ACTION.FaerieFireFeral, target = "target" },
    },
    {
        name = "Ravage",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "is_stealthed", op = "truthy" },
            { type = "state", field = "is_behind", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 60 },
        },
        action = { type = "cast", spell = ACTION.Ravage, target = "target" },
    },
    {
        name = "TigersFury",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "has_tigers_fury", op = "falsy" },
            -- The 30s CD + buff-up gate prevents re-fire after the 6s buff
            -- expires; spell_ready is the real engine CD read (spell_action
            -- exposes no cooldown_remaining member — systemic injection #1).
            { type = "spell_ready", spell = ACTION.TigersFury, target = "self" },
            -- 60-energy gain must fit under the 100 cap; never preempt a
            -- 5-CP finisher.
            { type = "state", field = "energy", op = "<=", value = 40 },
            { type = "state", field = "combo_points", op = "<", value = 5 },
        },
        action = { type = "cast", spell = ACTION.TigersFury, target = "self" },
    },
    {
        name = "Berserk",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "spell_ready", spell = ACTION.Berserk, target = "self" },
            { type = "state", field = "combo_points", op = "<", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Berserk, target = "self" },
    },
    {
        name = "SavageRoar",
        conditions = {
            { type = "state", field = "savage_roar_remains", op = "<", value = 3 },
            -- 5-CP spend (~36s duration). The old >= 1 gate produced an ~8s
            -- SR refreshed every ~6s — GCD- and CP-inefficient (W3.1 audit).
            { type = "state", field = "combo_points", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.SavageRoar, target = "self" },
    },
    {
        name = "Rip",
        conditions = {
            { type = "state", field = "rip_remains", op = "<", value = 3 },
            { type = "state", field = "combo_points", op = ">=", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Rip, target = "target" },
    },
    {
        name = "FerociousBite",
        conditions = {
            { type = "state", field = "combo_points", op = ">=", value = 5 },
            { type = "custom", fn = function(context, state)
                -- Execute band always bites. Above it, dump 5 CP only when
                -- Rip and Savage Roar are both healthy (they sit above this
                -- lane and would fire first if expiring) — otherwise CP is
                -- banked for the imminent refresh instead of idle-GCDs
                -- (W3.1 audit: no dump above the execute band).
                if (state.target_hp or 100) < 25 then return true end
                return (state.rip_remains or 0) >= 3 and (state.savage_roar_remains or 0) >= 3
            end },
        },
        action = { type = "cast", spell = ACTION.FerociousBite, target = "target" },
    },
    {
        name = "MangleCat",
        conditions = {
            -- wowsims mangleNow is bleed-debuff-refresh gated (mangleRefreshNow
            -- = !bleedAura.IsActive()); without this gate the reorder above
            -- Rake would let an unconditional Mangle filler preempt Rake
            -- refreshes at 45+ energy. Interim gate: refresh only when the
            -- Mangle bleed debuff is down or expiring.
            { type = "state", field = "mangle_remains", op = "<", value = 3 },
            { type = "state", field = "energy", op = ">=", value = 45 },
        },
        action = { type = "cast", spell = ACTION.MangleCat, target = "target" },
    },
    {
        name = "Rake",
        conditions = {
            { type = "state", field = "rake_remains", op = "<", value = 3 },
            { type = "state", field = "energy", op = ">=", value = 40 },
        },
        action = { type = "cast", spell = ACTION.Rake, target = "target" },
    },
    {
        name = "Shred",
        conditions = {
            { type = "state", field = "is_behind", op = "truthy" },
            { type = "state", field = "energy", op = ">=", value = 50 },
        },
        action = { type = "cast", spell = ACTION.Shred, target = "target" },
    },
    {
        name = "ShredOmen",
        conditions = {
            -- Omen of Clarity proc: consume with a free Shred even below the
            -- 50-energy gate (the paid Shred lane above already handles the
            -- energy-ample case).
            { type = "state", field = "clearcasting", op = "truthy" },
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "is_behind", op = "truthy" },
            { type = "state", field = "combo_points", op = "<", value = 5 },
        },
        action = { type = "cast", spell = ACTION.Shred, target = "target" },
    },
}

-- -----------------------------------------------------------------------------
-- Strategies (name-only placeholders; substituted by DSL). Priority preserved.
-- -----------------------------------------------------------------------------
local strategies = {
    { name = "FaerieFireFeral" },
    { name = "Ravage" },
    { name = "TigersFury" },
    { name = "Berserk" },
    { name = "SavageRoar" },
    { name = "Rip" },
    { name = "FerociousBite" },
    { name = "MangleCat" },
    { name = "Rake" },
    { name = "Shred" },
    { name = "ShredOmen" },
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
    NS.rotation_registry:register("cat", strategies, { get_state = build_state })
end

return { strategies = strategies, build_state = build_state }
