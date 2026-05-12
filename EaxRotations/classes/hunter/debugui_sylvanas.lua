-- Readability notes:
--   What: optional Hunter debug facade.
--   When: load_order loads hunter support modules or a user enables verbose tracing.
--   Why: keeps debug logging centralized without depending on UI widgets.
--   Safety: functions are no-ops unless explicitly enabled.

-- Decision notes:
--   Playstyle files are ordered priority lists: earlier strategies must be more urgent or more time-sensitive.
--   Matches functions explain when an action is allowed; execute functions only perform the already-gated cast.
--   Role logic follows TBC expectations and avoids post-TBC spells, speculative target swaps, and impossible casts.
local NS = _G.EaxRotations
if not NS then return nil end

local M = { enabled = false }

function M.set_enabled(value)
    M.enabled = value == true
end

function M.log(message)
    if M.enabled then NS.log("[HUNTER DEBUG] " .. tostring(message or "")) end
end

function M.snapshot(context)
    if not M.enabled then return end
    M.log(string.format(
        "hp=%.1f mana=%.1f target=%s enemies=%d",
        tonumber(context and context.hp) or 0,
        tonumber(context and context.mana_pct) or 0,
        tostring(context and context.has_valid_enemy_target),
        tonumber(context and context.enemy_count) or 0
    ))
end

NS.HunterDebugUI = M
return M
