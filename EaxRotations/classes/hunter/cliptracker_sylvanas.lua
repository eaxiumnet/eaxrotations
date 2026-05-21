-- lightweight Hunter shot timing state.

-- ============================================================================
-- What: Lightweight Hunter shot timing state for clip and auto-shot tracking
-- When: Loaded once, then updated by shot events and checks
-- Why: Centralizes timing state so marksmanship and survival can share it
-- Safety: NS time helpers only; static table reuse; conservative defaults when timing is unknown
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end

local M = { last_shot_ms = 0, last_auto_ms = 0, estimated_weapon_ms = 2800 }

local function now()
    return NS.game_time_ms()
end

function M.record_auto_shot()
    M.last_auto_ms = now()
end

function M.record_manual_shot()
    M.last_shot_ms = now()
end

function M.set_weapon_speed_seconds(speed)
    if type(speed) == "number" and speed > 0 then
        M.estimated_weapon_ms = math.floor(speed * 1000)
    end
end

function M.ms_until_auto()
    local elapsed = now() - (M.last_auto_ms or 0)
    local remain = (M.estimated_weapon_ms or 2800) - elapsed
    return remain > 0 and remain or 0
end

function M.can_cast_steady()
    local remain = M.ms_until_auto()
    return remain == 0 or remain > 450
end

function M.after_spell(spell_name)
    if spell_name then M.record_manual_shot() end
end

NS.HunterClipTracker = M
return M
