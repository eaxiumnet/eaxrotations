-- protection_forever.lua — Paladin Protection day-1 delta for WoW Forever (beta).
-- WHAT:  Forever kit deltas spliced ON TOP of the vanilla baseline: the
--        SEAL OF FURY tank-seal pair — keep Fury up (the new prot seal) and
--        JUDGE it (Judgement now taunts while Fury is active and no longer
--        consumes ANY seal) — plus a ping-pong wrap of the baseline's
--        SealRighteousness lane so the two seal lanes cannot fight.
-- WHEN:  combat, Forever client (class loader prefers _forever over
--        _vanilla; every other era keeps protection_vanilla/sylvanas/sod/
--        wotlk untouched).
-- WHY:   docs/forever/kits/paladin.md (Deep Dive 2026-09-13 + beta DBC
--        1.60.1.69893): "Seal of Fury — tank seal; favors fast weapons,
--        grants small absorb shields, Judgment taunts while active".
--        DBC VERIFICATION: Seal of Fury ladder 1311649@10 / 1311656@18 /
--        20163@25 / 20419@34 / 20421@42 / 20422@50 / 20423@58 (bridge
--        maxrank -> 20423; trigger rows point at the Judgement ids), and
--        the baseline's own Judgement row 20271 carries RecoveryTime
--        10000 with the "does not consume the Seal" behavior on Forever
--        (seals stay 30s). The baseline's Judgement lane ALREADY judges
--        with either seal up — but its seal matcher cannot see Seal of
--        Fury (its buff table predates the seal), so without the wrap
--        SealRighteousness would re-stomp Fury every tick. The delta
--        replaces that lane with a Fury-aware version (identical
--        otherwise) and keeps Judgement of Wisdom alive: the upkeep
--        lane's mana floor TRACKS the baseline's prot_seal_of_wisdom_mana
--        band, so inside that band the SoW lane (later in the list, after
--        the seal slots) owns the seal slot — the floor hands it over,
--        not list position.
-- SAFETY: ZERO numeric spell-ID literals — Seal of Fury resolves BY NAME
--        through the DBC-derived bridge mirrors
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the
--        lanes dormant — never a guessed ID. The vanilla baseline is
--        loaded through an intercepted registration (holy_forever
--        template) so this file edits nothing in protection_vanilla.lua
--        and its safe_state-backed get_state is reused unchanged. Delta
--        Dispatch semantics (evidence, main_sylvanas.lua): the legacy
--        path runs playstyle lists POSITIONALLY — run_list (line 1757,
--        first-match loop at line 1773) reads strategy.priority nowhere;
--        only NS.register_strategy (core_sylvanas.lua:4984, unified
--        registry) sorts by priority, and our deltas never use it.
--        Lane placement therefore is list position: the delta lanes are
--        spliced immediately ABOVE the baseline's SealRighteousness
--        slot (after RighteousFury/HolyShield/Consecration/Judgement,
--        BEFORE HammerOfWrath and every later lane) — DivineShield /
--        LayOnHands (later still) stay reachable via first-match
--        ordering because these lanes never gate on hp.

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
-- "protection" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("paladin protection", "classes/paladin/protection_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- seal CAST resolves through the max-rank mirror (max-level rotations cast
-- max rank: 20423@58, not the 20163 rank-1 row) and the seal BUFF anchor
-- through the buff mirror; a nil lookup leaves the lanes dormant — never a
-- guessed ID. Sentinel stand-ins for these names are seeded per mirror by
-- the battery's build_ns so the lanes are observable (Pattern 17) and
-- mirror selection itself is pinned by the unit suite (19000/19100
-- convention).
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank, by_buff = mirrors.maxrank, mirrors.buff

-- Cast role: max-rank mirror. Buff anchor: buff mirror (the aura the client
-- applies when the seal is active — observed ranks 20163..20423; the buff
-- mirror resolves the always-present anchor and the ladder union below adds
-- the rest).
local SEAL_FURY_CAST = resolve_id(by_maxrank, "Seal of Fury")
local SEAL_FURY_BUFF_ANCHOR = resolve_id(by_buff, "Seal of Fury")

-- Seal-up detection needs every rank the client can apply: the ladder union
-- of the class map's rows (none — Seal of Fury is new on Forever), the buff
-- anchor, and the cast id. Built from resolved ids only (never literals).
local append_unique = forever.append_unique

local SEAL_FURY_IDS = {}
append_unique(SEAL_FURY_IDS, { SEAL_FURY_BUFF_ANCHOR, SEAL_FURY_CAST })

-- ---------------------------------------------------------------------------
-- Shared helpers (mirror the baseline's local semantics; file-locals there
-- are not importable) and Forever constants.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}
-- Default starvation floor; tracks the baseline's prot_seal_of_wisdom_mana
-- band so the baseline's SoW lane (later in the list) owns the seal slot
-- inside that band — the floor hands the slot over, not list position.
local FOREVER_SEAL_FURY_MANA_FLOOR = 30

local setting_value = forever.setting

local setting_bool = forever.setting_bool

local function unit_has_any_buff(unit, ids)
    if not unit or type(ids) ~= "table" or #ids == 0 or not NS.buff_up then return false end
    return NS.buff_up(unit, ids) and true or false
end

local SEAL_FURY = nil
if SEAL_FURY_CAST then
    SEAL_FURY = NS.spell_action({ SEAL_FURY_CAST }, "ForeverSealOfFury")
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Two seal slots + the judgement-taunt pairing. Judgement of
-- Fury (the taunt) sits at the TOP of the seal block — it is the tank's
-- threat tool and must outrank the pure-upkeep seal lane. Both lanes are
-- spliced above the baseline's HammerOfWrath execute (the splice anchor
-- precedes HoW); the baseline's hp-gated emergency lanes (DivineShield,
-- LayOnHands) sit later and stay reachable because none of these lanes
-- gate on hp.
-- ---------------------------------------------------------------------------

-- Seal of Fury upkeep: keep the tank seal up when any other seal is absent.
-- Dormant until the bridge resolves the cast id.
local function seal_fury_upkeep()
    return {
        name = "Forever_SealOfFuryUpkeep",
        matches = function(context, s)
            if not setting_bool(context, "prot_forever_seal_of_fury", true) then return false end
            if unit_has_any_buff(NS.PLAYER_UNIT, SEAL_FURY_IDS) then return false end
            -- Track the baseline's own wisdom-starvation band: below it the
            -- baseline's SealOfWisdom lane (later in the list) owns the seal
            -- slot — the floor hands the slot over so the mana engine wins.
            if (s.mana_pct or 100) < setting_value(context, "prot_seal_of_wisdom_mana",
                FOREVER_SEAL_FURY_MANA_FLOOR) then return false end
            return NS.spell_ready(SEAL_FURY, NS.PLAYER_UNIT, EMPTY_OPTS)
        end,
        execute = function()
            return NS.try_cast(SEAL_FURY, NS.PLAYER_UNIT,
                "[FOREVER-PROT] Seal of Fury upkeep", EMPTY_OPTS)
        end,
    }
end

-- Judgement of Fury: the taunt. Judgement no longer consumes the seal on
-- Forever and taunts while Fury is active — the FIRST prot taunt ever. Fires
-- on the kill target while Fury is up (any rank). Placement truth: the
-- splice anchor (SealRighteousness) precedes HammerOfWrath in the baseline
-- list, so this lane and the upkeep lane sit ABOVE HoW — at low target HP
-- the taunt outranks the execute (pinned by
-- test_paladin_protection_forever, Pin 6).
local function judgement_of_fury()
    return {
        name = "Forever_JudgementOfFury",
        matches = function(context, s)
            if not setting_bool(context, "prot_forever_seal_of_fury", true) then return false end
            if not (context.has_valid_enemy_target and context.in_combat) then return false end
            if not unit_has_any_buff(NS.PLAYER_UNIT, SEAL_FURY_IDS) then return false end
            return NS.spell_ready(SPELLS.Judgement, context.target, EMPTY_OPTS)
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.Judgement, context.target,
                "[FOREVER-PROT] Judgement of Fury (taunt)")
        end,
    }
end

-- Ping-pong wrap of the baseline's SealRighteousness lane: identical
-- matcher/execute, plus "Seal of Fury active" as a block. Without this the
-- baseline's lane (whose buff table predates the new seal) would re-stomp
-- Fury every tick.
local function wrapped_seal_righteousness(orig)
    return {
        name = orig.name,
        matches = function(context, s)
            if unit_has_any_buff(NS.PLAYER_UNIT, SEAL_FURY_IDS) then return false end
            return orig.matches(context, s)
        end,
        execute = orig.execute,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: walk the baseline list; wrap SealRighteousness
-- in place; insert the Fury pair immediately above it (their natural slot —
-- after the emergency/self-buff lanes the baseline puts first, before the
-- damage rotation). When the bridge cannot resolve the seal the lanes stay
-- dormant and the baseline list is returned UNCHANGED (safe no-op delta).
-- ---------------------------------------------------------------------------
local combined = {}
local fury_inserted = false
if SEAL_FURY then
    local judgement_lane = judgement_of_fury()
    local upkeep_lane = seal_fury_upkeep()
    for i = 1, #baseline.strategies do
        local st = baseline.strategies[i]
        if type(st) == "table" and st.name == "SealRighteousness" then
            if not fury_inserted then
                combined[#combined + 1] = judgement_lane
                combined[#combined + 1] = upkeep_lane
                fury_inserted = true
            end
            combined[#combined + 1] = wrapped_seal_righteousness(st)
        else
            combined[#combined + 1] = st
        end
    end
    if not fury_inserted then
        -- Baseline shape drifted: the splice anchor vanished. Prepending
        -- would put the seal pair above the baseline's emergency lanes, so
        -- keep the lanes DORMANT instead — vanilla behavior is the correct
        -- degradation, and the unit suite's splice-position pin fails
        -- loudly either way.
        for i = 1, #baseline.strategies do combined[#combined + 1] = baseline.strategies[i] end
        judgement_lane, upkeep_lane = nil, nil
    end
else
    for i = 1, #baseline.strategies do combined[#combined + 1] = baseline.strategies[i] end
end

baseline.register(combined)
if NS.log then
    NS.log("Paladin protection Forever delta registered ("
        .. (SEAL_FURY and "2 Fury lanes + wrapped SoR" or "dormant (no bridge resolve)")
        .. " over " .. #baseline.strategies .. " baseline lanes)")
end

return combined
