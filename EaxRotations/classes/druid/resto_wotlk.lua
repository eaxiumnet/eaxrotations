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

-- Friendly multi-DoT cycling (shared/periodic_cycler_sylvanas.lua): pick the
-- ally that should get the NEXT HoT instead of always the single lowest. Absent
-- module => nil, and every lane keeps the lowest-only target it had.
local _cyc_ok, periodic_cycler = pcall(require, "shared/periodic_cycler_sylvanas")
if not _cyc_ok or type(periodic_cycler) ~= "table" then periodic_cycler = nil end

-- Plain define_action: file-local WotLK rank lists must win over the
-- TBC-capped DruidSpells class table (precedent: mage/fire_wotlk.lua:20).
local define = spec_kit.define_action

-- 2026-09-16 WotLK deficit-fit wave: per-rank HT ladder from the heal-value
-- module's WotLK family (era-less build_ladder -- already era-distinct).
-- Fail-closed: without the module the ladder stays nil and the fallback
-- lane below casts the exact legacy max-rank action. Lean-embedder guard
-- mirrors the priest/paladin WotLK precedent (NS.spell_action may be
-- stubbed in standalone dofile suites).
local WOTLK_HT_RANKS
local _HealValue = NS.HealValue
if not _HealValue then
    local _hv_ok, _mod = pcall(require, "shared/heal_value_sylvanas")
    if _hv_ok and type(_mod) == "table" then
        _HealValue = _mod
        NS.HealValue = NS.HealValue or _mod
    end
end
if type(_HealValue) == "table" and type(NS.spell_action) == "function" then
    WOTLK_HT_RANKS = _HealValue.build_ladder("druid", "WotlkHealingTouch",
        function(id) return NS.spell_action(id, "HealingTouch") end)
end

local ACTION = {
    Rejuvenation = define("Rejuvenation", { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }, "Rejuvenation"),
    WildGrowth = define("WildGrowth", { 53251, 48438 }, "WildGrowth"),
    Regrowth = define("Regrowth", { 48443, 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }, "Regrowth"),
    Swiftmend = define("Swiftmend", 18562, "Swiftmend"),
    Lifebloom = define("Lifebloom", { 48451, 33763 }, "Lifebloom"),
    Nourish = define("Nourish", { 50464 }, "Nourish"),
    Innervate = define("Innervate", { 29166 }, "Innervate"),
    -- Guide cooldowns (Icy-Veins WotLK resto priority #1/#4 + battle rez):
    -- NS is the emergency enabler (next Nature spell instant), HT its payload,
    -- Rebirth the per-encounter battle rez (10 min CD, Wowhead), Tranquility
    -- the party-wide burst channel. Rank ladders mirror leveling_wotlk.lua
    -- (audit-clean) and the Wowhead-verified WotLK max ranks.
    NaturesSwiftness = define("NaturesSwiftness", { 17116 }, "NaturesSwiftness"),
    HealingTouch = define("HealingTouch", { 48378, 26979, 26978, 25297, 9889, 9888, 9758, 8903, 6778, 5189, 5188, 5187, 5186, 5185 }, "HealingTouch"),
    Rebirth = define("Rebirth", { 48477, 26994, 20484 }, "Rebirth"),
    Tranquility = define("Tranquility", { 48447 }, "Tranquility"),
    -- Self-preservation: Barkskin (22812, damage reduction, usable in
    -- form; the TBC/Vanilla siblings all carry this lane — W3 audit gap).
    Barkskin = define("Barkskin", { 22812 }, "Barkskin"),
}

-- Max-rank-first HoT buff tables: WotLK Rejuv/Regrowth/Lifebloom auras are
-- 48441/48443/48451; the TBC-only tables read 0 at max rank and the refresh
-- gates re-cast every GCD (systemic injection #3).
local REJUVENATION_BUFF = { 48441, 26982, 26981, 25299, 9841, 9840, 9839, 8910, 3627, 2091, 2090, 1430, 1058, 774 }
local REGROWTH_BUFF = { 48443, 26980, 9858, 9857, 9856, 9750, 8941, 8940, 8939, 8938, 8936 }
local LIFEBLOOM_BUFF = { 48451, 33763 }

-- Nature's Swiftness self-buff (aura id = spell id 17116, Wowhead). The
-- NS+HT pair is split across two lanes exactly like the TBC sibling: cast NS
-- when a critical ally exists and the buff is absent; spend it on Healing
-- Touch when the buff is present.
local NATURES_SWIFTNESS_BUFF = { 17116 }
local NATURES_SWIFTNESS_EXPECTED_CD = 180  -- 3 min (Wowhead)
local TRANQUILITY_EXPECTED_CD = 600        -- 8 min (Wowhead)
local REBIRTH_EXPECTED_CD = 600            -- 10 min in WotLK (Wowhead; TBC was 1200)

-- try_cast/spell_ready opts (TBC sibling idiom: skip_range for self-aura CDs,
-- expected_cooldown feeds the swing-diagnostic drift check).
local NS_OPTS = { skip_range = true, expected_cooldown = NATURES_SWIFTNESS_EXPECTED_CD }
local TRANQUILITY_OPTS = { skip_range = true, expected_cooldown = TRANQUILITY_EXPECTED_CD }
local BARKSKIN_EXPECTED_CD = 60          -- 1 min (Wowhead)
local BARKSKIN_OPTS = { skip_range = true, expected_cooldown = BARKSKIN_EXPECTED_CD }
local REBIRTH_OPTS = { skip_range = true, expected_cooldown = REBIRTH_EXPECTED_CD }


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
    has_natures_swiftness = false,
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
    -- Friendly cycling: when the lowest ally already carries the HoT, cover the
    -- next injured ally instead of holding the lane -- the "two people at 60%
    -- and only one gets a HoT" deficit. Falls back to the lowest unit (the
    -- pre-existing target) without the module or a party list, so a solo fight
    -- is unchanged.
    local hot_unit = lowest_unit
    if periodic_cycler then
        hot_unit = periodic_cycler.friendly(context, REJUVENATION_BUFF, { hp_below = 88 }) or lowest_unit
    end
    state.hot_unit = hot_unit
    state.hot_remains = (hot_unit and NS.buff_remains and NS.buff_remains(hot_unit, REJUVENATION_BUFF)) or 0
    -- Nature's Swiftness self-buff (emergency pair enable state, TBC sibling
    -- resto_sylvanas has_natures_swiftness idiom).
    state.has_natures_swiftness = (me and NS.buff_up and NS.buff_up(me, NATURES_SWIFTNESS_BUFF)) or false
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
            -- The refresh window and the overheal check follow the CYCLED unit,
            -- not the lowest: the ally this lane is about to cover is the one
            -- whose HoT state matters.
            { type = "state", field = "hot_remains", op = "<", value = 3 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                return not overheal_blocked("Rejuvenation", state.hot_unit, 0, context)
            end },
        },
        action = { type = "custom", fn = function(_, state)
            -- Cast on the cycler's pick (state.hot_unit); the DSL "friendly"
            -- target resolves to the single lowest ally and cannot cycle.
            local unit = state.hot_unit
            if not unit then return false end
            return NS.try_cast(ACTION.Rejuvenation, unit, "[RESTO] Rejuvenation")
        end },
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
        -- 2026-09-16 WotLK deficit-fit wave: the TBC sibling's
        -- FallbackHealingTouch has no WotLK counterpart -- every other
        -- direct lane is single-rank (Nourish), refresh-gated (Regrowth),
        -- instant (Swiftmend, NS+HT) or group-aggregate (Wild Growth), so a
        -- deficit-fit HT fallback is the only fittable direct single-target
        -- heal in the spec. It sits AFTER Nourish (fallback position: fires
        -- only when no HoT/direct lane above matches) and mirrors the TBC
        -- gate (lowest <= 80, HT ready, standing still, no predicted
        -- overheal). The fit picks the smallest HT rank covering the
        -- deficit at player_level 80; fail-closed to the legacy 48382 max.
        -- No explicit deficit guard: the raw unit goes to the hook, whose
        -- legacy walk lands on the ladder head -- the legacy max by
        -- construction (priest 2.28.0 precedent).
        name = "FallbackHealingTouch",
        conditions = {
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 80 },
            { type = "state", field = "mana_pct", op = ">=", value = 25 },
            { type = "custom", fn = function(context, state)
                if context and context.is_moving then return false end
                local unit = context and context.lowest and context.lowest.unit or nil
                if not unit then return false end
                return not overheal_blocked("HealingTouch", unit, 3.0, context)
            end },
            { type = "spell_ready", spell = ACTION.HealingTouch, target = "self" },
        },
        action = { type = "custom", fn = function(context, state)
            local target = context and context.lowest and context.lowest.unit or nil
            if not target then return false end
            if type(WOTLK_HT_RANKS) == "table" and type(NS.cast_best_heal_rank) == "function" then
                local chosen, rank_label = NS.cast_best_heal_rank(WOTLK_HT_RANKS, target,
                    context, "[RESTO] HealingTouch", { player_level = 80 })
                if chosen then return NS.try_cast(chosen, target, rank_label) == true end
            end
            return NS.try_cast(ACTION.HealingTouch, target, "[RESTO] HealingTouch") == true
        end },
    },
    {
        name = "Innervate",
        conditions = {
            { type = "state", field = "mana_pct", op = "<=", value = 30 },
            { type = "spell_ready", spell = ACTION.Innervate, target = "self" },
        },
        action = { type = "cast", spell = ACTION.Innervate, target = "self" },
    },
    -- Guide cooldowns (Icy-Veins WotLK resto priority; mirrors TBC sibling
    -- resto_sylvanas lanes RebirthBattleRez / NaturesSwiftness pair /
    -- TranquilityEmergency):
    {
        name = "Rebirth",
        conditions = {
            { type = "in_combat" },
            { type = "custom", fn = function(context, state)
                -- Group-utility guard (TBC sibling idiom): battle rez is a
                -- group tool; solo no target exists anyway.
                local in_group = (context and (context.is_group or context.is_raid))
                    or (NS.is_in_party and NS.is_in_party())
                    or (NS.is_in_raid and NS.is_in_raid())
                if not in_group then return false end
                local dead = NS.find_dead_party_ally and NS.find_dead_party_ally() or nil
                if not dead then return false end
                -- TBC sibling form: is_player is a unit METHOD (mock + live
                -- engine both expose the callable; accept boolean too).
                local isp = (type(dead.is_player) == "function") and dead.is_player(dead) or dead.is_player
                if not isp then return false end
                local ok, ready = pcall(NS.spell_ready, ACTION.Rebirth, dead, REBIRTH_OPTS)
                return ok and ready == true
            end },
        },
        action = { type = "custom", fn = function(context, state)
            local dead = NS.find_dead_party_ally and NS.find_dead_party_ally() or nil
            if not dead then return false end
            return NS.try_cast(ACTION.Rebirth, dead, "[RESTO] Rebirth battle rez", REBIRTH_OPTS) == true
        end },
    },
    {
        name = "NaturesSwiftness",
        conditions = {
            { type = "in_combat" },
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 30 },
            { type = "state", field = "has_natures_swiftness", op = "falsy" },
            { type = "spell_ready", spell = ACTION.NaturesSwiftness, target = "self", opts = NS_OPTS },
        },
        action = { type = "custom", fn = function(context, state)
            return NS.try_cast(ACTION.NaturesSwiftness, nil, "[RESTO] Nature's Swiftness", NS_OPTS) == true
        end },
    },
    {
        name = "NaturesSwiftnessHealingTouch",
        conditions = {
            { type = "in_combat" },
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 30 },
            { type = "state", field = "has_natures_swiftness", op = "truthy" },
            { type = "spell_ready", spell = ACTION.HealingTouch, target = "self" },
        },
        action = { type = "cast", spell = ACTION.HealingTouch, target = "friendly" },
    },
    {
        name = "Tranquility",
        conditions = {
            { type = "in_combat" },
            { type = "state", field = "party_injured_count", op = ">=", value = 3 },
            { type = "state", field = "lowest_hp_pct", op = "<=", value = 50 },
            { type = "spell_ready", spell = ACTION.Tranquility, target = "self", opts = TRANQUILITY_OPTS },
        },
        action = { type = "custom", fn = function(context, state)
            -- Channeled, self-centered: cast on self (nil target = self idiom).
            return NS.try_cast(ACTION.Tranquility, nil, "[RESTO] Tranquility party burst", TRANQUILITY_OPTS) == true
        end },
    },
    {
        name = "BarkskinSelfPreservation",
        conditions = {
            { type = "in_combat" },
            -- Own-HP gate (NOT lowest ally: this is self-preservation).
            -- Same setting key + 55 default as the TBC sibling, so one
            -- knob governs Barkskin across eras.
            { type = "custom", fn = function(context, state)
                return (context.hp or 100) <= spec_kit.setting_number(context, "barkskin_hp", 55)
            end },
            { type = "spell_ready", spell = ACTION.Barkskin, target = "self", opts = BARKSKIN_OPTS },
        },
        action = { type = "custom", fn = function()
            return NS.try_cast(ACTION.Barkskin, nil, "[RESTO] Barkskin self", BARKSKIN_OPTS) == true
        end },
    },
}

local strategies = {
    -- Emergency/utility band first (guide priority: NS emergency + battle rez
    -- outrank HoT upkeep; Rebirth must not sit behind cast-time heals).
    { name = "NaturesSwiftness" },
    { name = "NaturesSwiftnessHealingTouch" },
    { name = "Rebirth" },
    { name = "Tranquility" },
    { name = "BarkskinSelfPreservation" },
    { name = "WildGrowth" },
    { name = "Swiftmend" },
    { name = "Lifebloom" },
    { name = "Rejuvenation" },
    { name = "Regrowth" },
    { name = "Nourish" },
    { name = "FallbackHealingTouch" },
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
