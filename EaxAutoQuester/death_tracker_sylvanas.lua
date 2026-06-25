-- What: Death tracker — records zone deaths and blacklists zones with ≥3 deaths
-- When: Loaded at startup; record_death() called by coordinator and dead_state
-- Why: Prevent infinite death loops by blacklisting high-fatality zones
-- Safety: No hard dependencies on other modules; pcall-guarded map_id access
-- Decision: Standalone module (not EaxRotations), uses _G.EaxAutoQuester for export

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _core_get_map_id = nil

-- ============================================================================
-- Module Table (defined first, exported at end)
-- ============================================================================

local M = {}

-- ============================================================================
-- Internal State — deaths keyed by map_id (string)
-- ============================================================================

local deaths = {}
local BLACKLIST_THRESHOLD = 3

-- ============================================================================
-- Public API
-- ============================================================================

--- Record a death in the given map zone.
--- Increments death count for map_id. If map_id is nil (pcall failed), no-op.
--- @param map_id number|nil Zone map ID to record death in
--- @return number New death count for this zone (0 if map_id was nil)
function M.record_death(map_id)
    if not map_id then return 0 end
    local key = tostring(map_id)
    local count = (deaths[key] or 0) + 1
    deaths[key] = count
    return count
end

--- Get the death count for a zone.
--- @param map_id number|nil Zone map ID
--- @return number Death count (0 if none recorded or map_id nil)
function M.get_death_count(map_id)
    if not map_id then return 0 end
    return deaths[tostring(map_id)] or 0
end

--- Check if a zone should be blacklisted (deaths >= threshold).
--- @param map_id number|nil Zone map ID
--- @return boolean true if death count >= 3
function M.should_blacklist(map_id)
    return M.get_death_count(map_id) >= BLACKLIST_THRESHOLD
end

--- Reset death count for a specific zone.
--- @param map_id number|nil Zone map ID to clear
function M.reset_zone(map_id)
    if not map_id then return end
    deaths[tostring(map_id)] = nil
end

--- Reset all death counts across all zones.
function M.reset_all()
    deaths = {}
end

--- Get a list of all blacklisted zone map_ids (death count >= 3).
--- @return table Array of blacklisted map_id strings
function M.get_blacklisted_zones()
    local _t = {}
    local n = 0
    for key, count in pairs(deaths) do
        if count >= BLACKLIST_THRESHOLD then
            n = n + 1
            _t[n] = tonumber(key) or key
        end
    end
    return _t
end

-- ============================================================================
-- Global Export — registered on _G.EaxAutoQuester
-- ============================================================================

local ns = _G.EaxAutoQuester
if ns then
    ns.death_tracker = M
end

return M
