-- retribution_forever.lua — Paladin Retribution day-1 delta for WoW Forever (beta).
-- WHAT:  Forever kit delta spliced ON TOP of the vanilla baseline: the
--        HOLY STRIKE melee weave (the level-6 instant holy strike the kit
--        declares present in EVERY paladin rotation — the vanilla ret
--        baseline predates the spell and has no lane for it).
-- WHEN:  combat, Forever client (class loader prefers _forever over
--        _vanilla; every other era keeps retribution_vanilla/sylvanas/sod/
--        wotlk untouched).
-- WHY:   docs/forever/kits/paladin.md (Deep Dive 2026-09-13 + beta DBC
--        1.60.1.69893): Holy Strike (level 6) is a new melee weave in every
--        paladin rotation. DBC VERIFICATION: ladder 678@12 / 679@20 /
--        680@28 (legacy rank rows) with the bridge maxrank mirror resolving
--        10333@60 — the delta casts through the maxrank mirror, never a
--        literal. The kit's OTHER ret items need NO delta: "Judgement no
--        longer consumes the seal" is already correct in the baseline
--        (seal lanes re-apply only when the buff is missing, so a
--        non-consuming Judgement simply keeps the seal up and the
--        judgement lanes gain uptime for free); Vindication (440667/68)
--        and Templar's Bulwark (1311015) are passives. TWIST OF LIGHT
--        (1310735) is deliberately NOT laned: the beta client carries no
--        SpellClassOptions row for it (class NULL), the bridge generator
--        excludes it, so a by-name lane could never resolve on the real
--        bridge — a battery-only sentinel firing would be a production-dead
--        lane (Pattern 17). Revisit only with an explicit bridge override
--        backed by in-game proof.
-- SAFETY: ZERO numeric spell-ID literals — Holy Strike resolves BY NAME
--        through the DBC-derived bridge mirrors
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the
--        lane dormant — never a guessed ID. The vanilla baseline is
--        loaded through an intercepted registration (holy_forever
--        template) so this file edits nothing in retribution_vanilla.lua
--        and its safe_state-backed get_state is reused unchanged. The
--        weave sits inside the filler block (above the Seal of
--        Righteousness filler, below every emergency/utility lane) so
--        first-match dispatch can never shadow an emergency cast.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "retribution"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] paladin retribution delta: rotation_registry unavailable", 0)
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
package.loaded["classes/paladin/retribution_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/paladin/retribution_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] paladin retribution delta: baseline load failed: " .. tostring(baseline_result), 0)
end

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- strike cast resolves through the max-rank mirror (max-level rotations
-- cast max rank: 10333@60, not the 678 rank-1 row); a nil lookup leaves
-- the lane dormant — never a guessed ID. Sentinel stand-ins for the name
-- are seeded per mirror by the battery's build_ns so the lane is
-- observable (Pattern 17) and mirror selection itself is pinned by the
-- unit suite (19000/19100 convention).
-- ---------------------------------------------------------------------------
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local HOLY_STRIKE = resolve_id(by_maxrank, "Holy Strike")

-- ---------------------------------------------------------------------------
-- Forever constants (kit/DBC-tuned estimates; menu-tunable via spec_kit).
-- ---------------------------------------------------------------------------
local FOREVER_HOLY_STRIKE_MANA_FLOOR = 25
local FOREVER_HOLY_STRIKE_RANGE = 5     -- melee range in yards

local setting_value = spec_kit.setting

local HOLY_STRIKE_ACTION = nil
if HOLY_STRIKE then
    HOLY_STRIKE_ACTION = NS.spell_action({ HOLY_STRIKE }, "ForeverRetHolyStrike")
end

-- ---------------------------------------------------------------------------
-- Delta lanes. The Holy Strike weave sits inside the filler block: inserted
-- immediately above the baseline's "Ret_SealRighteousness_Filler" so it
-- outranks pure seal fillers but stays below every emergency/utility lane
-- (first-match dispatch: position IS priority in the baseline list).
-- ---------------------------------------------------------------------------
local function holy_strike_weave()
    return {
        name = "Forever_RetHolyStrikeWeave",
        priority = 480,
        matches = function(context, s)
            if not setting_value(context, "ret_forever_holy_strike", true) then return false end
            if not (context.has_valid_enemy_target and context.in_combat) then return false end
            if ((s and s.mana_pct) or 100) < setting_value(context,
                "ret_forever_holy_strike_mana_floor", FOREVER_HOLY_STRIKE_MANA_FLOOR) then
                return false
            end
            -- Melee-range gate: skip silently when the core helper is absent
            -- (mirrors holy_forever's weave; the real client always provides it).
            if NS.unit_distance and context.target and context.me then
                local dist = NS.unit_distance(context.target, context.me)
                if type(dist) == "number" and dist > FOREVER_HOLY_STRIKE_RANGE then return false end
            end
            return NS.spell_ready(HOLY_STRIKE_ACTION, context.target, {})
        end,
        execute = function(context)
            return NS.try_cast(HOLY_STRIKE_ACTION, context.target,
                "[FOREVER-RET] Holy Strike weave")
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: walk the baseline list; insert the weave above
-- Ret_SealRighteousness_Filler. When the bridge cannot resolve the strike
-- the baseline list is returned UNCHANGED (safe no-op delta).
-- ---------------------------------------------------------------------------
local combined = {}
local weave_inserted = false
if HOLY_STRIKE_ACTION then
    local weave = holy_strike_weave()
    for i = 1, #baseline.strategies do
        local st = baseline.strategies[i]
        if not weave_inserted and type(st) == "table"
            and st.name == "Ret_SealRighteousness_Filler" then
            combined[#combined + 1] = weave
            weave_inserted = true
        end
        combined[#combined + 1] = st
    end
    if not weave_inserted then
        -- Baseline shape drifted: append (matches are self-gating; the lane
        -- still fires, just last).
        combined[#combined + 1] = weave
        weave_inserted = true
    end
else
    for i = 1, #baseline.strategies do combined[#combined + 1] = baseline.strategies[i] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then
    NS.log("Paladin retribution Forever delta registered ("
        .. (weave_inserted and "Holy Strike weave" or "dormant (no bridge resolve)")
        .. " over " .. #baseline.strategies .. " baseline lanes)")
end

return combined
