-- fury_forever.lua — Warrior Fury delta for WoW Forever (beta 2026-09-17).
-- WHAT:  ADDITIVE day-1 fury delta over the vanilla baseline: a Recklessness
--        burst lane (the CD-split change makes it an independent 30-minute
--        cooldown instead of sharing the vanilla interlock with
--        Retaliation/Shield Wall, and the baseline never presses it). The
--        kit's other fury items are passives or value changes that need no
--        lane: ambient Enrage (no baseline lane reads Enrage; the buff is a
--        passive proc), cheaper Cleave / both-weapon Whirlwind (talent
--        passives — the shape of the AoE loop survives), Bloodthirst's 35%
--        AP coefficient (confirmed in the DBC, priority order unchanged).
-- WHEN:  combat, Forever client (class loader prefers _forever over _vanilla).
-- WHY:   docs/forever/kits/warrior.md (Icy Veins overview 2026-09-13; beta
--        DBC 2026-09-17): "Major CD split: Recklessness / Retaliation /
--        Shield Wall no longer share a cooldown ... each becomes an
--        independent lane (dps burst vs panic defense decoupled)". DBC
--        confirmed: Recklessness 1719 carries its own RecoveryTime 1800000
--        with no SpellCategories row (Retaliation 900000 / Shield Wall
--        900000 likewise — the vanilla interlock is gone), +101% crit /
--        +21% damage taken / 15s / fear immunity. The P2 warrior
--        rage-from-damage probe is NOT resolvable from the client data (rage
--        math is not in any extracted table) — per the build-order decision
--        table this delta ships the verdict-independent subset only (CD
--        split + the documented passives); every baseline rage gate keeps
--        its conservative reserve until the in-game verdict lands.
-- SAFETY: ZERO numeric spell-ID literals — Recklessness is era-shared from
--        the class map (NS.WarriorSpells, id 1719) like the baseline's other
--        actions, so this lane needs no bridge lookup and always splices;
--        the fail-closed forever audit still scans the file. The vanilla
--        baseline is loaded through an intercepted registration
--        (holy_forever template) so this file edits nothing in
--        fury_vanilla.lua, and its safe_state-backed get_state is reused
--        unchanged. Splice geometry: the lane lands immediately above the
--        baseline's "DeathWish" burst lane (the two are independent now;
--        Recklessness has the longer cooldown) and below Execute/Pummel, so
--        nothing defensive or reactive is shadowed.

local NS = _G.EaxRotations
if not NS then return nil end

local forever = require("shared/spec_kit_forever_delta")

local SPELLS = NS.WarriorSpells or {}

-- ---------------------------------------------------------------------------
-- Baseline capture: the vanilla baseline is loaded through the shared
-- forever-delta owner (spec_kit_forever_delta.lua) while intercepting
-- NS.rotation_registry.register so its registration (strategies +
-- get_state) is captured instead of overwriting this playstyle. If the
-- baseline cannot load, it fails loudly there — a silently missing
-- "fury" playstyle is worse than a hard error.
-- ---------------------------------------------------------------------------
local baseline = forever.forever_delta("warrior fury", "classes/warrior/fury_vanilla")

-- ---------------------------------------------------------------------------
-- Shared helpers and Forever constants. Thresholds are menu-tunable via
-- spec_kit.setting; "estimated" values are tuned on beta day.
-- ---------------------------------------------------------------------------
local SELF_OPTS = { skip_range = true }

-- DBC-confirmed: RecoveryTime 1800000 on Recklessness 1719 and no
-- SpellCategories row (the vanilla shared-cooldown interlock is gone).
local FOREVER_RECKLESSNESS_CD = 1800

local function has_valid_enemy(context)
    return context and context.has_valid_enemy_target and context.target
end

-- ---------------------------------------------------------------------------
-- Delta lane. One burst CD, above the baseline's DeathWish so a fight
-- opener can press both independently; nothing else changes.
-- ---------------------------------------------------------------------------

local delta_burst = {}

delta_burst[#delta_burst + 1] = {
    name = "Forever_RecklessnessBurst",
    matches = function(context, s)
        if not context or not context.in_combat then return false end
        if not has_valid_enemy(context) then return false end
        if NS.should_use_long_cd and not NS.should_use_long_cd(context, FOREVER_RECKLESSNESS_CD) then return false end
        return NS.spell_ready(SPELLS.Recklessness, NS.PLAYER_UNIT, SELF_OPTS)
    end,
    execute = function()
        return NS.try_cast(SPELLS.Recklessness, NS.PLAYER_UNIT,
            "[FOREVER-FURY] Recklessness (independent burst CD)", SELF_OPTS)
    end,
}

-- ---------------------------------------------------------------------------
-- Splice + re-register: the burst lane lands immediately above the
-- baseline's "DeathWish" lane (fallback: above "Bloodthirst"; then append).
-- Re-registering the playstyle name replaces the baseline wholesale — the
-- combined list IS the "fury" playstyle on Forever.
-- ---------------------------------------------------------------------------
local ANCHORS = { DeathWish = true, Bloodthirst = true }

local combined = {}
local burst_inserted = false
for i = 1, #baseline.strategies do
    local st = baseline.strategies[i]
    if not burst_inserted and type(st) == "table" and ANCHORS[st.name] then
        for j = 1, #delta_burst do combined[#combined + 1] = delta_burst[j] end
        burst_inserted = true
    end
    combined[#combined + 1] = st
end
if not burst_inserted then
    for j = 1, #delta_burst do combined[#combined + 1] = delta_burst[j] end
end

baseline.register(combined)
if NS.log then NS.log("Warrior fury Forever delta registered (" ..
    #delta_burst .. " burst lane over " .. #baseline.strategies ..
    " baseline lanes)") end

return combined
