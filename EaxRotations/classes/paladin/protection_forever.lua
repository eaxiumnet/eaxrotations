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
--        otherwise) and keeps Judgement of Wisdom alive below it: when
--        the tank is starving, the baseline's SoW lane still wins (it is
--        checked FIRST in priority), so the mana engine survives.
-- SAFETY: ZERO numeric spell-ID literals — Seal of Fury resolves BY NAME
--        through the DBC-derived bridge mirrors
--        (shared/wowhead_data_bridge_spell_index_forever_sylvanas.lua,
--        pcall-required as an optional module); a nil lookup leaves the
--        lanes dormant — never a guessed ID. The vanilla baseline is
--        loaded through an intercepted registration (holy_forever
--        template) so this file edits nothing in protection_vanilla.lua
--        and its safe_state-backed get_state is reused unchanged. Delta
--        lanes sit at the baseline's own seal slots (Seal of Fury above
--        the wrapped SealRighteousness) — never above an emergency lane
--        (DivineShield / LayOnHands are untouched and stay reachable via
--        first-match dispatch ordering below the seal pair).

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")
local SPELLS = NS.PaladinSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: require the vanilla file while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, fail loudly — a silently missing "protection"
-- playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local registry = NS.rotation_registry
if not registry or type(registry.register) ~= "function" then
    error("[FOREVER] paladin protection delta: rotation_registry unavailable", 0)
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
package.loaded["classes/paladin/protection_vanilla"] = nil
local baseline_ok, baseline_result = pcall(require, "classes/paladin/protection_vanilla")
registry.register = original_register
if not baseline_ok or type(baseline) ~= "table" or type(baseline.strategies) ~= "table" then
    error("[FOREVER] paladin protection delta: baseline load failed: " .. tostring(baseline_result), 0)
end

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
local ok_bridge, ForeverBridge = pcall(require,
    "shared/wowhead_data_bridge_spell_index_forever_sylvanas")
if not ok_bridge or type(ForeverBridge) ~= "table" then ForeverBridge = nil end
local by_maxrank = (ForeverBridge
    and type(ForeverBridge.spell_maxrank_by_name_forever) == "table")
    and ForeverBridge.spell_maxrank_by_name_forever or {}
local by_buff = (ForeverBridge
    and type(ForeverBridge.spell_buff_by_name_forever) == "table")
    and ForeverBridge.spell_buff_by_name_forever or {}

local function resolve_id(map, client_name)
    local id = map[client_name]
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

-- Cast role: max-rank mirror. Buff anchor: buff mirror (the aura the client
-- applies when the seal is active — observed ranks 20163..20423; the buff
-- mirror resolves the always-present anchor and the ladder union below adds
-- the rest).
local SEAL_FURY_CAST = resolve_id(by_maxrank, "Seal of Fury")
local SEAL_FURY_BUFF_ANCHOR = resolve_id(by_buff, "Seal of Fury")

-- Seal-up detection needs every rank the client can apply: the ladder union
-- of the class map's rows (none — Seal of Fury is new on Forever), the buff
-- anchor, and the cast id. Built from resolved ids only (never literals).
local function append_unique(dst, src)
    if type(src) ~= "table" then return dst end
    for i = 1, #src do
        local v = src[i]
        if type(v) == "number" and v > 0 then
            local seen = false
            for j = 1, #dst do
                if dst[j] == v then seen = true break end
            end
            if not seen then dst[#dst + 1] = v end
        end
    end
    return dst
end

local SEAL_FURY_IDS = {}
append_unique(SEAL_FURY_IDS, { SEAL_FURY_BUFF_ANCHOR, SEAL_FURY_CAST })

-- ---------------------------------------------------------------------------
-- Shared helpers (mirror the baseline's local semantics; file-locals there
-- are not importable) and Forever constants.
-- ---------------------------------------------------------------------------
local format = string.format
local EMPTY_OPTS = {}

local function setting_bool(context, key, default)
    if type(spec_kit.setting_bool) == "function" then
        return spec_kit.setting_bool(context, key, default)
    end
    local v = spec_kit.setting(context, key, default)
    if v == nil then return default end
    return v ~= false
end

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
-- threat tool and must outrank the pure-upkeep seal lane; the baseline's
-- emergency lanes (DivineShield, LayOnHands) sit further down and stay
-- reachable because none of these lanes gate on hp.
-- ---------------------------------------------------------------------------

-- Seal of Fury upkeep: keep the tank seal up when any other seal is absent.
-- Dormant until the bridge resolves the cast id.
local function seal_fury_upkeep()
    return {
        name = "Forever_SealOfFuryUpkeep",
        matches = function(context, s)
            if not setting_bool(context, "prot_forever_seal_of_fury", true) then return false end
            if unit_has_any_buff(NS.PLAYER_UNIT, SEAL_FURY_IDS) then return false end
            -- respect the baseline's wisdom-starvation intent: below its mana
            -- band the SoW lane (checked earlier in the combined list) owns
            -- the seal slot; do not fight it.
            if (s.mana_pct or 100) < 30 then return false end
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
-- on the kill target while Fury is up (any rank); below the boss-death band
-- the baseline's HammerOfWrath execute still wins because it is positioned
-- above this lane in the combined list (seal slots sit mid-priority).
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
        -- Baseline shape drifted: keep the lanes live at the front (matches
        -- are self-gating; first-match dispatch keeps every baseline lane
        -- reachable behind them).
        combined = {}
        combined[#combined + 1] = judgement_lane
        combined[#combined + 1] = upkeep_lane
        for i = 1, #baseline.strategies do combined[#combined + 1] = baseline.strategies[i] end
        fury_inserted = true
    end
else
    for i = 1, #baseline.strategies do combined[#combined + 1] = baseline.strategies[i] end
end

original_register(registry, baseline.name, combined, baseline.options)
if NS.log then
    NS.log("Paladin protection Forever delta registered ("
        .. (SEAL_FURY and "2 Fury lanes + wrapped SoR" or "dormant (no bridge resolve)")
        .. " over " .. #baseline.strategies .. " baseline lanes)")
end

return combined
