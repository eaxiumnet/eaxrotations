-- What: Dialog/popup handler for EaxAutoQuester — auto-accepts detectable prompts
-- When: Polled by interact_state before frame handling each tick
-- Why: Dungeon ready checks, battlefield ports, and other confirmation dialogs
--        block the bot until manually clicked. This module auto-accepts them.
-- Safety: All API calls pcall-guarded; throttled to avoid spam; logs every action
-- Decision: Limited to APIs Project Sylvanas exposes. No raw frame access.

-- ============================================================================
-- API Caching at Module Load (Pattern 2)
-- ============================================================================

local _core_time = core.time
local _core_log = core.log

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- ============================================================================
-- Throttle state
-- ============================================================================

local _last_dungeon_check = 0
local _last_battlefield_check = 0
local _DUNGEON_INTERVAL = 2.0
local _BATTLEFIELD_INTERVAL = 2.0

-- ============================================================================
-- Dungeon Proposal — auto-accept LFG/LFR ready checks
-- ============================================================================

--- Check for and auto-accept dungeon/raid ready checks.
--- Uses core.input.has_dungeon_proposal() + accept_dungeon_proposal(true).
--- Throttled to 2s intervals.
--- @return boolean true if a proposal was accepted this tick
function M.handle_dungeon_proposal()
    local now = _core_time()
    if now - _last_dungeon_check < _DUNGEON_INTERVAL then return false end
    _last_dungeon_check = now

    local ok, has = pcall(core.input.has_dungeon_proposal)
    if not ok or not has then return false end

    local ok2 = pcall(function() core.input.accept_dungeon_proposal(true) end)
    if ok2 then
        _core_log("[EaxAutoQuester] Auto-accepted dungeon proposal")
        return true
    end
    return false
end

-- ============================================================================
-- Battlefield Port — auto-accept battleground queue
-- ============================================================================

--- Check for and auto-accept battlefield (battleground) port invitations.
--- Scans queue slots 1-3 for status "confirm", then calls accept_battlefield_port.
--- Throttled to 2s intervals.
--- @return boolean true if a port was accepted this tick
function M.handle_battlefield_port()
    local now = _core_time()
    if now - _last_battlefield_check < _BATTLEFIELD_INTERVAL then return false end
    _last_battlefield_check = now

    for i = 1, 3 do
        local ok, status = pcall(core.game_ui.get_battlefield_status, i)
        if ok and status == "confirm" then
            local ok2 = pcall(function() core.input.accept_battlefield_port(i, true) end)
            if ok2 then
                _core_log("[EaxAutoQuester] Auto-accepted battlefield port (queue " .. tostring(i) .. ")")
                return true
            end
        end
    end
    return false
end

-- ============================================================================
-- Master dispatcher — called once per tick
-- ============================================================================

--- Handle all detectable popups/dialogs in priority order.
--- Call from interact_state or coordinator each tick.
--- @return string|nil Action description if something was handled, nil otherwise
function M.handle_any_popup()
    local dungeon_result = M.handle_dungeon_proposal()
    if dungeon_result then return "dungeon_accepted" end
    local bf_result = M.handle_battlefield_port()
    if bf_result then return "battlefield_accepted" end
    return nil
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.static_popup = M

return M
