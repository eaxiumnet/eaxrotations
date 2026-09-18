-- cat_forever.lua — Druid Feral Cat delta for WoW Forever (beta 2026-09-17).
-- WHAT:  DESTRUCTIVE delta over the vanilla baseline: the Powershift lane is
--        REMOVED (Furor rework — shifting no longer nets energy) and the
--        Tiger's Fury lane is REPLACED with the reworked semantics (free,
--        30s CD, +16% physical 6s), plus a new Berserk burst lane (the
--        DBC-confirmed form-branched 3-min CD: +101% crit to combo-point
--        generators, fear immunity, 15s). The rest of the in-form priority
--        (Rip/Rake snapshot, Shred, FB execute, Omen Shred) is baseline.
-- WHEN:  combat, cat form, Forever client (class loader prefers _forever).
-- WHY:   docs/forever/kits/druid.md (Icy Veins overview 2026-09-15; beta DBC
--        2026-09-17): Furor's new text is "you will regain X% of the Energy
--        you had when you were last in Cat Form, plus Y Energy for each
--        second you spent not in [animal] Form, up to a maximum of Z Energy"
--        (17056) — a capped restore, not the classic flat +40 on shift, so
--        the vanilla powershift lane's premise (shift → net energy) is dead
--        (exact percentages live behind unresolved $ tokens: in-game probe).
--        Tiger's Fury 5217 now reads "+16% physical for 6s ... and instantly
--        grants $417046s1 Energy" (with King of the Jungle) at 30s CD and NO
--        energy cost, so the baseline's "+30 fits under the cap" gate would
--        wrongly block a free damage CD above 70 energy. Berserk 417141
--        (granted by 424759) is the new burst window.
-- SAFETY: ZERO numeric spell-ID literals — the fail-closed forever audit
--        (run_forever_audit_tests.lua) resolves every ID through the bridge.
--        Berserk resolves BY NAME through the maxrank mirror (pinned to the
--        druid row 417141 in the builder's MIRROR_NAME_OVERRIDES: the
--        cross-class lowest-id dedupe would pick the Warrior 23397 row);
--        Tiger's Fury is era-shared from the class map (NS.DruidSpells) with
--        its buff id from the buff mirror. A nil lookup leaves the lane
--        dormant — never a guessed ID. The vanilla baseline is loaded through
--        an intercepted registration (holy_forever template) so this file
--        edits nothing in cat_vanilla.lua, and its safe_state-backed
--        get_state is reused unchanged. Splice geometry: the burst lane lands
--        just above the first damage lane ("Rip"); the Tiger's Fury
--        replacement lands exactly where the baseline's lane sat — never
--        above the opener/utility/defensive head lanes.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.DruidSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "cat" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("druid cat", "classes/druid/cat_vanilla")

-- ---------------------------------------------------------------------------
-- By-name resolution (zero-literal contract, dbc_runbook.md step 3b): the
-- Berserk CAST resolves through the maxrank mirror (417141, the druid row
-- pinned in the builder); the Tiger's Fury BUFF check resolves through the
-- buff mirror (5217 — the client carries a single Tiger's Fury row, whose
-- self-aura is the buff the class map's lane reads). A nil lookup leaves the
-- lane dormant -- never a guessed ID. Sentinel stand-ins are seeded per
-- mirror by the battery's build_ns so mirror selection itself is pinned.
-- ---------------------------------------------------------------------------
local mirrors = forever.mirrors()
local resolve_id = forever.resolve_id
local by_maxrank, by_buff = mirrors.maxrank, mirrors.buff

local BERSERK = resolve_id(by_maxrank, "Berserk")
local TIGERS_FURY_BUFF = resolve_id(by_buff, "Tiger's Fury")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local format = string.format
local SELF_OPTS = { skip_range = true }

-- DBC-confirmed: RecoveryTime 180000 on the druid Berserk (417141), 15s aura.
local FOREVER_BERSERK_CD = 180
-- The burst window is worth pressing with energy in hand (the +101% crit
-- applies to generators you are about to spend energy on).
local FOREVER_BERSERK_ENERGY = 40

local setting = forever.setting

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lanes. Rotational deltas only: the Berserk burst sits above the
-- first damage lane; the Tiger's Fury replacement sits exactly where the
-- baseline's lane was. No opener/utility/defensive lane is shadowed.
-- ---------------------------------------------------------------------------

local delta_head = {}

-- Berserk-cat burst (DBC: 180s CD, 15s, +101% crit to combo-point
-- generators, fear immunity, and the bear-side Mangle branches that cat
-- ignores). Fires inside the long-CD gate with energy in hand so the crit
-- window lands on a real generator sequence.
if BERSERK then
    delta_head[#delta_head + 1] = {
        name = "Forever_BerserkCat",
        matches = function(context, s)
            if not s.is_cat then return false end
            if not context or not context.in_combat then return false end
            if not has_valid_enemy(context) then return false end
            if (s.energy or 0) < setting(context, "cat_forever_berserk_energy", FOREVER_BERSERK_ENERGY) then return false end
            if NS.should_use_long_cd and not NS.should_use_long_cd(context, FOREVER_BERSERK_CD) then return false end
            return NS.spell_ready(BERSERK, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function(_, s)
            return NS.try_cast(BERSERK, NS.PLAYER_UNIT,
                format("[FOREVER-CAT] Berserk burst (%.0f energy)", s and (s.energy or 0) or 0), SELF_OPTS)
        end,
    }
end

local delta_tf = {}

-- Tiger's Fury, reworked (DBC: 5217 has a 30s RecoveryTime, 6s buff, and no
-- energy cost — the classic 30-energy price is gone; with King of the Jungle
-- it also grants ~60 energy). The baseline's "gain fits under the cap" gate
-- would block a FREE damage CD whenever energy > 70, so the replacement
-- fires whenever the buff is down, in combat, and not stealthed. The energy
-- gain is a bonus, not the gate. Dormant when the bridge cannot resolve the
-- buff id (the lane must be able to see the buff it refreshes).
if TIGERS_FURY_BUFF then
    delta_tf[#delta_tf + 1] = {
        name = "Forever_TigersFuryBurst",
        matches = function(context, s)
            if not s.is_cat then return false end
            if not context or not context.in_combat then return false end
            if s.is_stealthed then return false end
            if NS.has_player_buff(TIGERS_FURY_BUFF) then return false end
            return NS.spell_ready(SPELLS.TigersFury, NS.PLAYER_UNIT, SELF_OPTS)
        end,
        execute = function()
            return NS.try_cast(SPELLS.TigersFury, NS.PLAYER_UNIT,
                "[FOREVER-CAT] Tiger's Fury (free damage window)", SELF_OPTS)
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Splice + re-register: the Powershift and baseline TigersFury lanes are
-- DROPPED (Furor rework killed the first; the second is replaced above), the
-- Berserk burst is inserted just above the first damage lane ("Rip"), and
-- the Tiger's Fury replacement takes the baseline lane's exact position.
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "cat" playstyle on Forever.
-- ---------------------------------------------------------------------------
local DROPPED_LANES = { Powershift = true, TigersFury = true }

local combined = {}
local berserk_inserted = false
local tf_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if type(st) == "table" and st.name == "TigersFury" then
        for j = 1, #delta_tf do combined[#combined + 1] = delta_tf[j] end
        tf_inserted = true
    elseif type(st) == "table" and not DROPPED_LANES[st.name] then
        if not berserk_inserted and st.name == "Rip" then
            for j = 1, #delta_head do combined[#combined + 1] = delta_head[j] end
            berserk_inserted = true
        end
        combined[#combined + 1] = st
    end
end
if not berserk_inserted then
    for j = 1, #delta_head do combined[#combined + 1] = delta_head[j] end
end
if not tf_inserted then
    for j = 1, #delta_tf do combined[#combined + 1] = delta_tf[j] end
end

baseline.register(combined)
if NS.log then NS.log("Druid cat Forever delta registered (" ..
    #delta_head .. " berserk + " .. #delta_tf .. " tigers-fury lane, " ..
    "2 baseline lanes dropped, over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
