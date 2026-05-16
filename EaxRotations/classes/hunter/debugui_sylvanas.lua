-- optional Hunter debug facade.

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
