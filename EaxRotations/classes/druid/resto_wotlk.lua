-- resto_wotlk.lua — Druid Restoration rotation for Wrath of the Lich King (3.3.5).
-- WHAT:  priority-list strategies for Restoration druid: Wild Growth on an
--        injured raid, Swiftmend on HoT'd low ally, Lifebloom 3-stack roll,
--        Rejuvenation/Regrowth HoT refresh, Nourish direct spot heal, Innervate
--        at low mana.
-- WHEN:  combat with valid friendly target.
-- WHY:   mirrors SimulationCraft / wowsims APL with WotLK-era mechanics.
-- SAFETY: state reads nil-guarded via spec_kit.safe_state(); no on_update() allocs.
-- DECISION: every heal targets the LOWEST-HP friendly unit (DSL target="friendly"
--         -> context.lowest.unit); the old file cast all five heals on the
--         (hostile) combat target and gated Wild Growth on enemy_count — it
--         could never fire in the single-boss fight it exists for (W3.1 audit).
--         mana comes from context.mana_pct (main_sylvanas:795) / NS.mana_pct(me)
--         — the mock-only me:get_mana_percentage() left the mana gates inert.
--         HoT buff tables carry the WotLK max-rank ids (48441/48443/48451) so
--         remains/stacks read real at level 80 (systemic injection #3).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local dsl      = require("shared/strategy_dsl_sylvanas")

-- Plain define_action: file-local WotLK rank lists must win over the
-- TBC-capped DruidSpells class table (precedent: mage/fire_wotlk.lua:20).
local define = spec_kit.define_action

local ACTION = {
    Rejuvenation = define("Rejuvenation", { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    WildGrowth = define("WildGrowth", { 53251, 48438 }, "WildGrowth"),
    Regrowth = define("Regrowth", { 48443, 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Swiftmend = define("Swiftmend", 18562, "Swiftmend"),
    Lifebloom = define("Lifebloom", { 48451, 33763 }, "Lifebloom"),
    Nourish = define("Nourish", { 50464 }, "Nourish"),
    Innervate = define("Innervate", { 29166 }, "Innervate"),
}

-- Max-rank-first HoT buff tables: WotLK Rejuv/Regrowth/Lifebloom auras are
-- 48441/48443/48451; the TBC-only tables read 0 at max rank and the refresh
-- gates re-cast every GCD (systemic injection #3).
local REJUVENATION_BUFF = { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH_BUFF = { 48443, 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local LIFEBLOOM_BUFF = { 48451, 33763 }

-- Nourish gains +20% per HoT on the target in WotLK; the gate simply needs a
-- hurt ally (spot-heal lane), the HoT-bonus math is implicit.
local NOURISH_CAST_TIME = 1.5

local resto_state = {
    mana_pct = 100,
    enemy_count = 1,
    in_combat = false,
    lowest_hp_pct = 100,
    party_injured_count = 0,
    rejuvenation_remains = 0,
    regrowth_remains = 0,
    lifebloom_remains = 0,
    lifebloom_stacks = 0,
}

local function build_state(context)
    local state = spec_kit.safe_state(resto_state)
    local me = (context and context.me) or NS.me or (NS.GetPlayer and NS.GetPlayer())
    -- Healing targets resolve to the lowest-HP friendly unit (DSL
    -- target="friendly" -> context.lowest.unit, populated by the engine party
    -- scan at main_sylvanas.lua:1245). HoT remains/stacks read THAT unit —
    -- never the (hostile) combat target.
    local lowest_unit = (context and context.lowest and context.lowest.unit)
        or (context and context.lowest_unit)
        or nil
    state.mana_pct = (context and context.mana_pct)
        or (NS.mana_pct and me and NS.mana_pct(me))
        or 100
    state.enemy_count = (context and context.enemy_count) or 1
    state.in_combat = (context and context.in_combat) or false
    state.lowest_hp_pct = (context and context.lowest_hp)
        or (context and context.lowest and context.lowest.hp)
        or 100
    -- Engine party-scan field (main_sylvanas.lua:1237) — the ally-side injury
    -- signal Wild Growth exists for.
    state.party_injured_count = (context and context.party_injured_count) or 0
    state.rejuvenation_remains = (lowest_unit and NS.buff_remains and NS.buff_remains(lowest_unit, REJUVENATION_BUFF)) or 0
    state.regrowth_remains = (lowest_unit and NS.buff_remains and NS.buff_remains(lowest_unit, REGROWTH_BUFF)) or 0
    state.lifebloom_remains = (lowest_unit and NS.buff_remains and NS.buff_remains(lowest_unit, LIFEBLOOM_BUFF)) or 0
    state.lifebloom_stacks = (lowest_unit and NS.buff_stacks and NS.buff_stacks(lowest_unit, LIFEBLOOM_BUFF)) or 0
    return state
end

-- Overheal gate: skip when the HealerDeficit engine module says the heal
-- would overheal. Absent module -> never skip (matches the TBC sibling's
-- predictive_overheal fall-through).
local function overheal_blocked(spell_key, unit, cast_time, context)
    if not NS.gate_overheal then return false end
    local ok, overheal = pcall(NS.gate_overheal, spell_key, unit, cast_time, context and context.settings)
    return ok and overheal == true
end

local DSL_DEFS = {
    {
        name = "WildGrowth",
        conditions = {
            -- W3.1 audit: was enemy_count >= 2 — never fired in the
            -- single-boss raid fight it exists for. Gate on injured ALLIES
            -- (engine party scan party_injured_count).
            { type = "state", field = "party_injured_count", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "spell_ready", spell = ACTION.WildGrowth, target = "self" },
        },
        action = { type = "cast", spell = ACTION.WildGrowth, target = "friendly" },
    },
    {
        name = "Swiftmend",
        conditions = {
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 50 },
            { type = "custom", fn = function(context, state)
                -- Consumes a Rejuv/Regrowth HoT on the target.
                return (state.rejuvenation_remains or 0) > 0 or (state.regrowth_remains or 0) > 0
            end },
            { type = "spell_ready", spell = ACTION.Swiftmend, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Swiftmend, target = "friendly" },
    },
    {
        name = "Lifebloom",
        conditions = {
            { type = "state", field = "lifebloom_remains", op = "<", value = 3 },
            { type = "custom", fn = function(context, state)
                -- 3-stack awareness: roll up stacks freely; at 3 stacks only
                -- refresh inside the last 1.2s so ticks aren't clipped and
                -- mana isn't burned (W3.1 audit: unconditional <3s refresh
                -- spammed to OOM once the mana gates were real).
                local stacks = state.lifebloom_stacks or 0
                if stacks >= 3 then return (state.lifebloom_remains or 0) < 1.2 end
                return true
            end },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
        },
        action = { type = "cast", spell = ACTION.Lifebloom, target = "friendly" },
    },
    {
        name = "Rejuvenation",
        conditions = {
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 88 },
            { type = "state", field = "rejuvenation_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                return not overheal_blocked("Rejuvenation", context and context.lowest and context.lowest.unit, 0, context)
            end },
        },
        action = { type = "cast", spell = ACTION.Rejuvenation, target = "friendly" },
    },
    {
        name = "Regrowth",
        conditions = {
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 70 },
            { type = "state", field = "regrowth_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                return not overheal_blocked("Regrowth", context and context.lowest and context.lowest.unit, 2.0, context)
            end },
        },
        action = { type = "cast", spell = ACTION.Regrowth, target = "friendly" },
    },
    {
        name = "Nourish",
        conditions = {
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 60 },
            { type = "state", field = "mana_pct", op = ">=", value = 15 },
            { type = "custom", fn = function(context, state)
                return not overheal_blocked("Nourish", context and context.lowest and context.lowest.unit, NOURISH_CAST_TIME, context)
            end },
            { type = "spell_ready", spell = ACTION.Nourish, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Nourish, target = "friendly" },
    },
    {
        name = "Innervate",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = 30 },
            { type = "spell_ready", spell = ACTION.Innervate, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Innervate, target = "self" },
    },
}

local strategies = {
    { name = "WildGrowth" },
    { name = "Swiftmend" },
    { name = "Lifebloom" },
    { name = "Rejuvenation" },
    { name = "Regrowth" },
    { name = "Nourish" },
    { name = "Innervate" },
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
    NS.rotation_registry:register("resto", strategies, { get_state = build_state })
end
if NS.log then NS.log("Druid resto rotation registered") end

return { strategies = strategies, build_state = build_state }
