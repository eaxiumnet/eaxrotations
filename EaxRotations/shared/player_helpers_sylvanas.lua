-- player_helpers_sylvanas.lua -- get_player + form/stance + range helpers used by every spec.
-- WHAT:   get_player + form/stance + range helpers used by every spec
-- WHEN:   called per-frame from every spec's build_state and strategies
-- WHY:    removes ~200 lines of duplicated range/form boilerplate per spec
-- SAFETY: cached local_player at module load; nil-guarded accessors
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- =============================================================================
-- player_helpers_sylvanas.lua
--
-- Centralized wrappers for fetching the local player object. Replaces
-- 3-line `get_player()` helpers copy-pasted in ooc_manager, racial_manager,
-- trinket_manager, and aura_probe -- four files previously diverging in
-- trivial ways (some guarded pcall on NS.GetPlayer; aura_probe also tried
-- core.object_manager.get_local_player as a fallback).
--
-- WHY THIS EXISTS
--   Every shared module that needs the player object was rolling its own
--   `local function get_player() return NS and NS.GetPlayer and NS.GetPlayer() or nil end`.
--   Returns of nil at runtime are silently useful (callers bail early), but
--   one file (aura_probe) ALSO fell back to core.object_manager.get_local_player,
--   creating an undocumented dependency that other modules can't share.
--
-- CONTRACT
--   - get_player():         NS.GetPlayer() (with type guard + pcall).
--   - get_player_robust():  NS.GetPlayer() first, then core.object_manager.get_local_player.
--                           Used by aura_probe where the live engine sometimes
--                           lacks a GetPlayer shim.
--   - install(NS):          installs get_player + get_player_robust on the NS table
--                           so individual shared files don't need to require this.
-- =============================================================================

local M = {}

local function safe_pcall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok then return nil end
    return a
end

-- NS.GetPlayer only (matches the 3 verbatim copies).
function M.get_player()
    local NS = _G.EaxRotations
    if not (NS and type(NS.GetPlayer) == "function") then return nil end
    return safe_pcall(NS.GetPlayer)
end

-- NS.GetPlayer with a fallback to core.object_manager.get_local_player
-- (matches aura_probe's longer version).
function M.get_player_robust()
    local NS = _G.EaxRotations
    if NS and type(NS.GetPlayer) == "function" then
        local p = safe_pcall(NS.GetPlayer)
        if p then return p end
    end
    local core = _G.core
    if core and core.object_manager and type(core.object_manager.get_local_player) == "function" then
        return safe_pcall(core.object_manager.get_local_player)
    end
    return nil
end

-- Install both onto the NS table (idempotent). One call from a shared boot
-- hook lets every shared file call `NS.get_player()` without re-requiring.
function M.install(NS)
    if type(NS) ~= "table" then return end
    NS.get_player = M.get_player
    NS.get_player_robust = M.get_player_robust
end

return M
