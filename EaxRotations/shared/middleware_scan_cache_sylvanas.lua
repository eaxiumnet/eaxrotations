-- middleware_scan_cache_sylvanas.lua — Per-context scan memoization for middleware.
-- WHAT:  lets middleware strategies cache expensive scan results on `context`
--         so they are computed at most once per tick without module-level timers.
-- WHEN:  any middleware scan that currently uses `_last_*_scan` + interval.
-- WHY:   context is rebuilt/reused per engine tick, so a per-context cache is
--         a pure-API way to throttle scans to once per tick.
-- SAFETY: never stores nil as a cache value (uses false sentinel); nil-guards
--         on missing NS / context.

local M = {}

--- Unique sentinel to distinguish "no result" from nil in the cache.
local NO_RESULT = {}

--- Return the per-context cache table, creating it if necessary.
-- @param context table The strategy context.
-- @return table The cache table.
function M.cache_for(context)
    if not context then return {} end
    if not context._scan_cache then context._scan_cache = {} end
    return context._scan_cache
end

--- Memoize a scan function for the current context.
-- The result is cached on `context._scan_cache[key]` and reused for the rest
-- of the current tick.  If `fn` errors or returns nil, the cache stores a
-- sentinel "no result" and subsequent calls return nil.
-- @param context table The strategy context.
-- @param key string Cache key.
-- @param fn function Scan function returning any value.
-- @return any The cached or freshly computed result (nil if none).
function M.memoize(context, key, fn)
    local cache = M.cache_for(context)
    local cached = cache[key]
    if cached == NO_RESULT then
        return nil
    end
    if cached ~= nil then
        return cached
    end
    local ok, result = pcall(fn)
    if not ok or result == nil then
        cache[key] = NO_RESULT
        return nil
    end
    cache[key] = result
    return result
end

--- Memoize a boolean scan function for the current context.
-- Convenient wrapper for scans that only need true/false and where false is a
-- meaningful cached value.
-- @param context table The strategy context.
-- @param key string Cache key.
-- @param fn function Scan function returning a boolean.
-- @return boolean The cached or freshly computed result.
function M.memoize_bool(context, key, fn)
    local cache = M.cache_for(context)
    local cached = cache[key]
    if cached ~= nil then
        return cached == true
    end
    local ok, result = pcall(fn)
    if not ok or type(result) ~= "boolean" then
        cache[key] = false
        return false
    end
    cache[key] = result
    return result
end

return M
