-- dot_ttd_gating_sylvanas.lua — Reusable DoT TTD gating for TBC Anniversary (2.5.5).
-- WHAT:  Skip DoT reapplication if target will die before DoT runs full duration.
-- WHEN:  All DoT specs (Shadow Priest, Affliction Lock, etc.).
-- WHY:   Don't waste GCDs on targets that die in 3s.
-- SAFETY: nil-guarded; returns false (don't skip) when data is missing.

local NS = _G.EaxRotations
if not NS then return {} end

local M = {}

--- Estimate whether a DoT should be skipped based on target TTD.
-- Returns true if the target's estimated time-to-death is shorter than
-- the DoT duration multiplied by the threshold.
--
-- @param ttd           number  Estimated time-to-death in seconds (0 = unknown)
-- @param dot_duration  number  Full DoT duration in seconds
-- @param threshold     number  Fraction 0.0-1.0 (default 0.5)
-- @return boolean  true = skip the DoT, false = apply it
function M.should_skip_dot(ttd, dot_duration, threshold)
    if not ttd or ttd <= 0 then return false end
    if not dot_duration or dot_duration <= 0 then return false end
    threshold = threshold or 0.5
    if threshold <= 0 then return false end
    return ttd < (dot_duration * threshold)
end

--- Convenience wrapper that extracts TTD from context.
-- @param context       table   Rotation context (expects context.ttd, context.ttd_known)
-- @param dot_duration  number  Full DoT duration in seconds
-- @param threshold     number  Fraction 0.0-1.0 (default 0.5)
-- @return boolean  true = skip the DoT
function M.should_skip_dot_from_context(context, dot_duration, threshold)
    if not context then return false end
    if not context.ttd_known then return false end
    return M.should_skip_dot(context.ttd, dot_duration, threshold)
end

--- Per-DoT duration constants for TBC spells (seconds).
M.DOT_DURATIONS = {
    vampiric_touch      = 15,
    shadow_word_pain    = 18,
    devouring_plague    = 24,
    corruption          = 18,
    unstable_affliction = 18,
    siphon_life         = 30,
    immolate            = 15,
    curse_of_agony      = 24,
    curse_of_doom       = 60,
    serpent_sting       = 15,
}

if NS then
    NS.DotTTD = M
end

return M
