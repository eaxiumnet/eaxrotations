-- safe_helpers_sylvanas.lua -- nil-safe wrappers for has_buff/buff_remains/health_pct APIs that crash on nil units.
-- WHAT:   nil-safe wrappers for has_buff/buff_remains/health_pct APIs that crash on nil units
-- WHEN:   called everywhere spec code touches a game_object without nil check
-- WHY:    eliminates a class of nil method error crashes in spec code
-- SAFETY: all wrappers nil-check inputs; return sensible defaults
-- DECISION: consumed by specs via require(); no on_update side-effects.

--
-- Centralized pcall wrappers used across shared/ modules.
-- Replaces the per-file `safe(fn, ...)` + `safe_field(obj, key)` pair
-- that was copy-pasted in ooc_manager, racial_manager, and trinket_manager
-- (12 lines each, mostly verbatim), plus a 4th sibling safe_method() in
-- interrupt_manager.
--
-- WHY THIS EXISTS
--   Each shared file needed a local safe() function to swallow Lua errors
--   when pinging optional NS.* methods (Pattern 14: runtime-tolerable APIs).
--   Three of the four copies were verbatim, with two of those already
--   proxying to NS.safe_field when present — clear half-attempted centralization.
--   consolidating now means the upstream-proxy branch in the three callers
--   becomes a no-op (safe_field is installed by core_sylvanas.lua).
--
-- CONTRACT
--   - safe(fn, ...):            returns the first success value of pcall(fn, ...)
--                                (a, b) tuple form. Type-guards fn first.
--   - safe_field(obj, key):     pcall-protected read of obj[key]; returns nil
--                                on obj=nil or any error. Proxies to NS.safe_field
--                                if present (so core can override).
--   - safe_method(unit, name):  pcall-protected unit:name() call. Returns nil
--                                on unit=nil, missing method, or any error.
--   - safe_method_or(unit, name, fallback): safe_method() with a default value
--                                when the read is missing/nil (the druid files'
--                                historical shape).
--   - safe_method_arg_or(unit, name, arg, fallback): the one-arg variant.
--   - install(NS):              installs safe + safe_field onto the NS table
--                                so individual shared files don't need to require
--                                this module. Idempotent.

local M = {}

function M.safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    if b ~= nil then return a, b end
    return a, nil
end

-- Hoisted raw reader: `pcall(raw_read, obj, key)` is the closure-free pcall
-- form, so safe_field allocates nothing per call. The previous inline
-- `pcall(function() return obj[key] end)` built a fresh closure on EVERY call,
-- which is exactly why cast_timing_sylvanas and the four druid class files each
-- kept a private copy of this helper (they are hot-path). With this fixed the
-- shared module can be the single owner without paying a per-frame price.
local function raw_read(obj, key)
    return obj[key]
end

function M.safe_field(obj, key)
    if obj == nil then return nil end
    local ok, value = pcall(raw_read, obj, key)
    if not ok then return nil end
    return value
end

function M.safe_method(unit, method_name)
    if unit == nil then return nil end
    local fn = unit[method_name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, unit)
    if not ok then return nil end
    return value
end

-- safe_method_or(unit, name, fallback): safe_method() with a default. The four
-- druid class files (bear/cat, sylvanas/vanilla) each carried a private copy of
-- this exact shape; they now delegate here.
function M.safe_method_or(unit, name, fallback)
    if unit == nil then return fallback end
    local fn = M.safe_field(unit, name)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, unit)
    if not ok or value == nil then return fallback end
    return value
end

-- safe_method_arg_or(unit, name, arg, fallback): the one-argument variant.
function M.safe_method_arg_or(unit, name, arg, fallback)
    if unit == nil then return fallback end
    local fn = M.safe_field(unit, name)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, unit, arg)
    if not ok or value == nil then return fallback end
    return value
end

function M.install(NS)
    if type(NS) ~= "table" then return end
    NS.safe = M.safe
    NS.safe_field = M.safe_field
    NS.safe_method = M.safe_method
    NS.safe_method_or = M.safe_method_or
    NS.safe_method_arg_or = M.safe_method_arg_or
    -- safe_field was previously proxied by callers; provide the same
    -- public surface so ooc_manager / racial_manager / trinket_manager
    -- can drop their local copies without needing a require.
end

return M
