-- los_guard_sylvanas.lua -- Line-of-sight guard used by cast-time spells that need LOS on target..
-- WHAT:   Line-of-sight guard used by cast-time spells that need LOS on target.
-- WHEN:   called per-frame before any cast_time spell
-- WHY:    silently skips casts when target is obscured (no-op, no crash)
-- SAFETY: PCalled on LineOfSight api; nil-guarded unit
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.

-- Wraps game_object:los_to() and core.graphics.is_line_of_sight().
--
-- When: Called by NS.try_cast() before spell execution to verify the target
--       is in line of sight. Also available as a standalone check for callers
--       that want LOS validation outside the cast pipeline.
-- Why: Prevents failed cast attempts — and the associated resource waste and
--       UI flicker — when the target is behind a pillar, wall, or terrain.
--       Without this check, Project Sylvanas will attempt the cast (for spells
--       the engine does not LOS-check internally) and waste a frame.
-- Safety: All API calls are pcall-wrapped. Missing methods, nil returns, and
--         absent modules are handled gracefully (returns true / "assume LOS").
-- Decision: Prefers IZI SDK unit:los_to() for best engine integration. Falls
--           back to core.graphics.is_line_of_sight() when IZI is unavailable.
--           When neither API is available, returns true (do NOT block the
--           cast — the caller may have its own LOS strategy).
-- Cache: 100ms TTL per (caster, target) pair to avoid per-frame API spam.
--        Sized as a static-table cache (single entry group) to keep GC zero.

local M = {}
local _G = _G
local NS = _G.EaxRotations or {}
local _core = _G.core or {}

-- --------------------------------------------------------------------------
-- Time source: resolved at call time so NS.time_now (defined later in
-- core_sylvanas.lua bootstrap) is available even though this module may be
-- loaded early during core_sylvanas init.
-- --------------------------------------------------------------------------
local function _time()
    if NS.time_now then return NS.time_now() end
    if type(_core.time) == "function" then return _core.time() end
    return 0
end

-- --------------------------------------------------------------------------
-- LOS cache: 100ms TTL per (caster, target) pair
-- Uses tostring identity keys since game_object references are stable pointers
-- in the PS runtime.
--
-- BUGFIX (2026-06-29): the unit-keyed cache used to grow unbounded as
-- the player swapped targets repeatedly during a long session (every
-- enemy ever seen stays keyed forever).  Added a MAX_LOS_CACHE_ENTRIES=64
-- FIFO eviction inside M.check + a public M.clear() for zone changes.
-- --------------------------------------------------------------------------
local _CACHE_TTL = 0.1     -- 100 milliseconds
local _cache = {}
local _los_cache_order = {}  -- FIFO of cache keys (oldest first)
local MAX_LOS_CACHE_ENTRIES = 64

local function _evict_oldest_los()
    if #_los_cache_order == 0 then return end
    local oldest = table.remove(_los_cache_order, 1)
    _cache[oldest] = nil
end

local function _cache_key(caster, target)
    return tostring(caster) .. "::" .. tostring(target)
end

--- BUGFIX (2026-06-29): public clear method, useful on zone / BG change.
function M.clear()
    for k in pairs(_cache) do _cache[k] = nil end
    for i = 1, #_los_cache_order do _los_cache_order[i] = nil end
end

-- --------------------------------------------------------------------------
-- Check line of sight between the local player and `target`.
--
-- Returns true (safe, assume LOS) when:
--   * target is nil / false / absent
--   * the local player cannot be determined (GetPlayer absent or returns nil)
--   * the target is the player (self-cast is always in LOS)
--   * neither API (los_to, is_line_of_sight) is available
--
---@param target game_object The target unit to check LOS against.
---@return boolean            True if target is in line of sight (or if LOS
--                            determination is unavailable).
-- ============================================================================
function M.check(target)
    -- Nil target → trivially in LOS; don't block.
    if not target then return true end

    local caster = (NS.GetPlayer and NS.GetPlayer()) or nil
    if not caster then
        local get_local = _core.object_manager and _core.object_manager.get_local_player
        if type(get_local) == "function" then
            local ok, result = pcall(get_local)
            if ok then caster = result end
        end
    end
    if not caster then return true end

    -- Self-cast is always in LOS. NS.same_unit is optional — this repo never
    -- assigns it, and every other call site guards it (balance_sylvanas:276,
    -- bear_sylvanas:261). When absent, skip the shortcut and let the LOS APIs
    -- decide: both report true for the player itself, and the try_cast caller
    -- already excludes self-casts upstream (core_sylvanas:2303).
    if NS.same_unit and NS.same_unit(caster, target) then return true end

    local now = _time()
    local key = _cache_key(caster, target)

    -- Cache hit within TTL.
    local cached = _cache[key]
    if cached and (now - cached.time) < _CACHE_TTL then
        return cached.result
    end

    local result

    -- 1. IZI SDK path: unit:los_to(other)
    if type(target.los_to) == "function" then
        local ok, los = pcall(target.los_to, target, caster)
        if ok and type(los) == "boolean" then
            result = los
        end
    end

    -- 2. Fallback path: core.graphics.is_line_of_sight(caster, target)
    if result == nil then
        local graphics = _core.graphics
        if graphics and type(graphics.is_line_of_sight) == "function" then
            local ok, los = pcall(graphics.is_line_of_sight, graphics, caster, target)
            if ok and type(los) == "boolean" then
                result = los
            end
        end
    end

    -- 3. Neither API available → assume LOS, do NOT block the cast.
    if result == nil then
        result = true
    end

    -- Cache the result for the TTL window, with FIFO eviction at MAX.
    _cache[key] = { result = result, time = now }
    _los_cache_order[#_los_cache_order + 1] = key
    while #_los_cache_order > MAX_LOS_CACHE_ENTRIES do
        _evict_oldest_los()
    end

    return result
end

-- --------------------------------------------------------------------------
-- Module export: both NS.LosGuard (table) and individual function for
-- convenience.
-- --------------------------------------------------------------------------
if NS then
    NS.LosGuard = M
end

return M
