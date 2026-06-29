-- match_helpers_sylvanas.lua -- distance/state/HP/combo match-function predicates shared by specs.
-- WHAT:   distance/state/HP/combo match-function predicates shared by specs
-- WHEN:   called by spec match functions in every strategy table
-- WHY:    replaces ~30 hand-written `(state.x or 0) < y` snippets per spec
-- SAFETY: pure predicates; no api calls; cached dependencies
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- ============================================================================
-- Shared Helper: Match Helpers
-- What:   Boolean gate helpers for common strategy match-function patterns.
-- When:   Loaded at module init. Used by spec match functions via NS.match_helpers.
-- Why:    Eliminates duplicate inline guards across 16+ spec files.
-- Safety: Pure boolean logic — no side effects, no engine API calls.
-- Decision: Start with ttd_gate (highest ROI: 43 occurrences, 16 files).
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
if not NS then return M end

-- ============================================================================
-- ttd_gate(ctx, min_ttd)
-- ============================================================================
-- Returns false if the target's time-to-death is known and below the minimum
-- threshold (meaning the target will die too soon for this spell/DoT to be
-- worth casting). Returns true in all other cases (unknown TTD, TTD above
-- threshold, or TTD non-positive).
--
-- Canonical replacement for:
--   if context.ttd_known and context.ttd > 0 and context.ttd < N then return false end
--
-- @param ctx table — must contain ttd_known (boolean) and ttd (number|nil)
-- @param min_ttd number — minimum acceptable TTD in seconds
-- @return boolean — true = safe to proceed, false = skip (target dying too soon)
-- ============================================================================

function M.ttd_gate(ctx, min_ttd)
    if not ctx.ttd_known then return true end
    local ttd = ctx.ttd or 999
    if ttd > 0 and ttd < min_ttd then return false end
    return true
end

-- ============================================================================
-- NS Registration
-- ============================================================================

NS.match_helpers = M

return M
