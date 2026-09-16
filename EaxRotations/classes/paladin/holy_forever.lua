-- holy_forever.lua — Paladin Holy delta for WoW Forever (beta 2026-09-17).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: Infusion-
--        of-Light Holy Light weave and Light's Vigil burst CD (healing
--        priority), 10s Holy Shock core + Holy Strike melee weave (filler
--        priority, above the baseline solo block); re-registered as the
--        "holy" playstyle with the vanilla strategies kept below.
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/paladin.md (Deep Dive 2026-09-13): Holy Shock on a
--        10s CD becomes a core rotational spell instead of a niche proc;
--        Infusion of Light turns Holy Shock/FoL crits into fast Holy Lights;
--        Light's Vigil is a high-cost burst CD that resets Holy Shock; Holy
--        Strike (level 6) is a new melee weave in EVERY paladin rotation.
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge,
--        so a hardcoded literal could never pass on beta day. Forever-new
--        spells resolve BY NAME through the DBC-derived bridge module
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the
--        lane dormant — never a guessed ID.
--        Era-shared spells come from the class map (NS.PaladinSpells). The
--        vanilla baseline is loaded through an intercepted registration
--        (load_sod_specs pattern) so this file edits nothing in
--        holy_vanilla.lua, and its safe_state-backed get_state is reused
--        unchanged. Healer-first ordering: conditional healing lanes sit
--        above the whole baseline; rotational fillers sit just above the
--        baseline's solo-damage block and below every heal/utility lane, so
--        no delta lane can shadow an emergency cast (first-match dispatch).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. We then
-- re-register the combined list. If the baseline cannot load, fail loudly —
-- a silently missing "holy" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] paladin holy delta: rotation_registry unavailable", 0)
end
local original_register = registry.register
local baseline = nil
registry.register = function(self, name, strategies, options)
    registry.register = original_register
    baseline = { name = name, strategies = strategies, options = options or {} }
    return true
end
-- Force baseline re-execution so its registration always reaches the
-- interceptor above, even if some earlier require() cached the module.
package.loaded["classes/paladin/holy_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/paladin/holy_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] paladin holy delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- bridge is empty until the beta DBC lands, so before beta day the
-- bridge-resolved lanes stay dormant. Exact client names come from
-- docs/forever/kits/paladin.md; sentinel stand-ins for these names are
-- seeded by the battery's build_ns so the lanes are observable (Pattern 17)
-- today and byte-identical in production once the real bridge arrives.
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_name = (ForeverBridge
    and type(ForeverBridge.spell_index_by_name_forever) == "table")
    and ForeverBridge.spell_index_by_name_forever or {}

local function resolve_id(client_name)
    local id = by_name[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local HOLY_STRIKE = resolve_id("Holy Strike")
local LIGHTS_VIGIL = resolve_id("Light's Vigil")
local INFUSION_OF_LIGHT_BUFF = resolve_id("Infusion of Light")

-- ---------------------------------------------------------------------------
-- Shared helpers (mirror the baseline's local semantics; file-locals there
-- are not importable) and Forever constants. Thresholds are menu-tunable
-- via spec_kit.setting; the "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}
local SELF_OPTS = { skip_range = true }

local FOREVER_HOLY_SHOCK_CD = 10        -- Deep Dive: 30s in TBC -> 10s in Forever
local FOREVER_HOLY_SHOCK_MANA_FLOOR = 20
local FOREVER_IOL_HL_DEFICIT = 30       -- fast big heal only when it matters
local FOREVER_IOL_MANA_FLOOR = 25
local FOREVER_VIGIL_HP_GATE = 70        -- burst window: someone actually hurt
local FOREVER_VIGIL_MANA_FLOOR = 50     -- high-cost CD: never at starvation
local FOREVER_VIGIL_CD_ESTIMATE = 180   -- estimated until DBC; tune on beta day
local FOREVER_HOLY_STRIKE_MANA_FLOOR = 30
local FOREVER_HOLY_STRIKE_RANGE = 5     -- melee range in yards

local function hp_of(entry, fallback)
    if entry and type(entry.effective_hp) == "number" then return entry.effective_hp end
    if entry and type(entry.hp) == "number" then return entry.hp end
    return fallback or 100
end

local function can_help(entry)
    if not entry or not entry.unit then return false end
    if entry.is_dead == true or entry.dead == true then return false end
    return true
end

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- Healer-first discipline: fillers must never outrank topping off a hurt
-- ally (mirrors the baseline's solo_damage_enabled safe_hp gate).
local function group_healthy(s)
    if s and can_help(s.lowest) and hp_of(s.lowest) < 88 then return false end
    return true
end

local function setting(context, key, default)
    return spec_kit.setting(context, key, default)
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Healing-priority lanes (conditional, never hot) sit above the
-- whole baseline; rotational fillers sit just above the baseline's
-- solo-damage block ("SealOfRighteousnessSolo"; fallback: append).
-- ---------------------------------------------------------------------------

local delta_head = {}

-- Infusion of Light weave (kit: HS/FoL crits reduce Holy Light cast time):
-- while the buff is up and an ally is hurt enough to deserve the big heal,
-- Holy Light becomes the fast filler. Dormant until the bridge resolves the
-- buff id (battery drives it through the sentinel map).
if INFUSION_OF_LIGHT_BUFF then
    delta_head[#delta_head + 1] = {
        name = "Forever_InfusionOfLightWeave",
        matches = function(context, s)
            if not can_help(s.lowest) then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_iol_mana_floor", FOREVER_IOL_MANA_FLOOR) then return false end
            if not NS.has_player_buff(INFUSION_OF_LIGHT_BUFF) then return false end
            if 100 - hp_of(s.lowest) < setting(context, "holy_forever_iol_deficit", FOREVER_IOL_HL_DEFICIT) then return false end
            return NS.spell_ready(SPELLS.HolyLight, s.lowest.unit, EMPTY_OPTS)
        end,
        execute = function(_, s)
            return NS.try_cast(SPELLS.HolyLight, s.lowest.unit,
                format("[FOREVER-HOLY] IoL Holy Light weave %.0f%%", hp_of(s.lowest)))
        end,
    }
end

-- Light's Vigil burst (kit: high-cost CD that resets Holy Shock and channels
-- extra damage or party-wide healing through an ally): fire inside a burst
-- window while Holy Shock is at least half spent, so the reset buys a full
-- core cooldown instead of overlapping one. use_cooldowns-gated via
-- NS.should_use_long_cd, like the baseline's Divine Favor lane.
if LIGHTS_VIGIL then
    delta_head[#delta_head + 1] = {
        name = "Forever_LightsVigilBurst",
        matches = function(context, s)
            if not can_help(s.lowest) then return false end
            if hp_of(s.lowest) > setting(context, "holy_forever_vigil_hp", FOREVER_VIGIL_HP_GATE) then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_vigil_mana_floor", FOREVER_VIGIL_MANA_FLOOR) then return false end
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, FOREVER_VIGIL_CD_ESTIMATE) then return false end
            local hs_remains = NS.cooldown_remains and NS.cooldown_remains(SPELLS.HolyShock) or 0
            if hs_remains < FOREVER_HOLY_SHOCK_CD / 2 then return false end
            return NS.spell_ready(LIGHTS_VIGIL, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function(_, s)
            return NS.try_cast(LIGHTS_VIGIL, s.lowest.unit,
                format("[FOREVER-HOLY] Light's Vigil burst (Holy Shock reset, %.0f%%)", hp_of(s.lowest)),
                SELF_OPTS)
        end,
    }
end

local delta_weave = {}

-- Holy Shock core (kit: 10s CD, "significantly more uptime than TBC's 30s"):
-- the baseline's HolyShock lane only fires as an emergency heal below 40%;
-- on Forever it is a rotational spell — spend it as holy damage on the kill
-- target when the group is healthy, otherwise heal the lowest ally. Positioned
-- below every baseline heal/utility lane so it can never shadow one.
delta_weave[#delta_weave + 1] = {
    name = "Forever_HolyShockCore",
    matches = function(context, s)
        if not (can_help(s.lowest) or has_valid_enemy(context)) then return false end
        if (s.mana_pct or 100) < setting(context, "holy_forever_shock_mana_floor", FOREVER_HOLY_SHOCK_MANA_FLOOR) then return false end
        return NS.spell_ready(SPELLS.HolyShock, NS.PLAYER_UNIT, EMPTY_OPTS)
    end,
    execute = function(context, s)
        if has_valid_enemy(context) and group_healthy(s) then
            return NS.try_cast(SPELLS.HolyShock, context.target, "[FOREVER-HOLY] Holy Shock core (damage)")
        end
        return NS.try_cast(SPELLS.HolyShock, s.lowest.unit,
            format("[FOREVER-HOLY] Holy Shock core %.0f%%", hp_of(s.lowest)))
    end,
}

-- Holy Strike weave (kit: level-6 instant Holy strike on a 12s CD, present
-- in EVERY paladin rotation): melee-range filler, gated on a healthy group so
-- it can never outrank healing.
if HOLY_STRIKE then
    delta_weave[#delta_weave + 1] = {
        name = "Forever_HolyStrikeWeave",
        matches = function(context, s)
            if not HOLY_STRIKE then return false end
            if not has_valid_enemy(context) then return false end
            if not group_healthy(s) then return false end
            if (s.mana_pct or 100) < setting(context, "holy_forever_strike_mana_floor", FOREVER_HOLY_STRIKE_MANA_FLOOR) then return false end
            if NS.unit_distance and NS.unit_distance(context.target, context.me) > FOREVER_HOLY_STRIKE_RANGE then return false end
            return NS.spell_ready(HOLY_STRIKE, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(HOLY_STRIKE, context.target, "[FOREVER-HOLY] Holy Strike weave")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: healing-priority deltas first, then everything
-- vanilla in order, with the rotational fillers inserted just above the
-- baseline's solo-damage block. Re-registering the playstyle name replaces
-- the baseline wholesale — the combined list IS the "holy" playstyle on
-- Forever.
-- ---------------------------------------------------------------------------
local combined = {}
for i = 1, #delta_head do combined[#combined + 1] = delta_head[i] end
local weave_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not weave_inserted and type(st) == "table" and st.name == "SealOfRighteousnessSolo" then
        for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
        weave_inserted = true
    end
    combined[#combined + 1] = st
end
if not weave_inserted then
    for j = 1, #delta_weave do combined[#combined + 1] = delta_weave[j] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then NS.log("Paladin holy Forever delta registered (" .. #delta_head .. " head + " .. #delta_weave .. " filler lanes over " .. #baseline.strategies .. " baseline lanes)") end

return combined
