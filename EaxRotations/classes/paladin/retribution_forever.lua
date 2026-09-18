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
--        Dispatch semantics (evidence, main_sylvanas.lua): the legacy
--        path runs playstyle lists POSITIONALLY — run_list (line 1757,
--        first-match loop at line 1773) never reads strategy.priority
--        (only the unified registry sorts by it, core_sylvanas.lua:4984,
--        unused here). The weave sits inside the filler block (immediately
--        above the baseline's Ret_SealRighteousness_Filler, below every
--        emergency/utility lane) so first-match dispatch can never shadow
--        an emergency cast — placement IS the priority.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.PaladinSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "retribution" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("paladin retribution", "classes/paladin/retribution_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- strike cast resolves through the max-rank mirror (max-level rotations
-- cast max rank: 10333@60, not the 678 rank-1 row); a nil lookup leaves
-- the lane dormant — never a guessed ID. Sentinel stand-ins for the name
-- are seeded per mirror by the battery's build_ns so the lane is
-- observable (Pattern 17) and mirror selection itself is pinned by the
-- unit suite (19000/19100 convention).
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank = mirrors.maxrank

local HOLY_STRIKE = resolve_id(by_maxrank, "Holy Strike")

-- ---------------------------------------------------------------------------
-- Forever constants (kit/DBC-tuned estimates; menu-tunable via spec_kit).
-- ---------------------------------------------------------------------------
local FOREVER_HOLY_STRIKE_MANA_FLOOR = 25
local FOREVER_HOLY_STRIKE_RANGE = 5     -- melee range in yards

local setting_value = forever.setting

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
        -- NOTE: no priority field — the legacy dispatcher (main_sylvanas.lua
        -- run_list, line 1757; first-match loop at 1773) is POSITIONAL and
        -- never reads strategy.priority; only the unified registry sorts by
        -- priority (core_sylvanas.lua:4984) and this delta does not use it.
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

baseline.register(combined)
if NS.log then
    NS.log("Paladin retribution Forever delta registered ("
        .. (weave_inserted and "Holy Strike weave" or "dormant (no bridge resolve)")
        .. " over " .. #baseline.strategies .. " baseline lanes)")
end

return combined
