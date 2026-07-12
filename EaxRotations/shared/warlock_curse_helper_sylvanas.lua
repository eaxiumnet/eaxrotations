-- warlock_curse_helper_sylvanas.lua — shared Warlock curse constants and helpers.
-- WHAT:  unified refresh window, debuff ID tables, and curse-conflict check.
-- WHEN:  consumed by affliction/demonology/destruction specs.
-- WHY:   eliminates duplicated constants and inconsistent refresh thresholds.
-- SAFETY: nil-guarded; no side effects; no on_update allocations.

local M = {}

M.CURSE_REFRESH_WINDOW = 1.5

M.CURSE_OF_AGONY_DEBUFF        = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
M.CURSE_OF_DOOM_DEBUFF         = { 30910, 603 }
M.CURSE_OF_ELEMENTS_DEBUFF     = { 27228, 11722, 11721, 1490 }
M.CURSE_OF_RECKLESSNESS_DEBUFF = { 27227, 11717, 11716, 11715, 6209, 6208, 1109, 702 }
M.CURSE_OF_WEAKNESS_DEBUFF     = { 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 }

--- Check if a curse other than the one being cast is already active.
--- Accepts both long (agony_remains/doom_remains) and short (coa_remains/cod_remains)
--- field naming conventions used by different specs.
function M.other_curse_active(state, this_curse)
    local agony_remains = state.agony_remains or state.coa_remains or 0
    local doom_remains  = state.doom_remains  or state.cod_remains or 0
    if this_curse ~= "agony"        and agony_remains                > M.CURSE_REFRESH_WINDOW then return true end
    if this_curse ~= "doom"         and doom_remains                 > M.CURSE_REFRESH_WINDOW then return true end
    if this_curse ~= "elements"     and (state.coe_remains          or 0) > M.CURSE_REFRESH_WINDOW then return true end
    if this_curse ~= "recklessness" and (state.recklessness_remains or 0) > M.CURSE_REFRESH_WINDOW then return true end
    if this_curse ~= "weakness"     and (state.weakness_remains     or 0) > M.CURSE_REFRESH_WINDOW then return true end
    return false
end

return M
