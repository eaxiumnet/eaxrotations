-- profiler_helper_sylvanas.lua -- nil-safe wrapper for the Sylvanas profiler module.
-- WHAT:  exposes start/stop profiling helpers that no-op when the module is absent.
-- WHEN:  called from spec match/execute functions when debug profiling is enabled.
-- WHY:   the profiler module is optional; this helper prevents crashes when it is missing.
-- SAFETY: every public function returns safely when profiler is unavailable.
-- DECISION: keep the module tiny; callers gate usage behind a debug setting.

local M = {}

local _profiler_ok, _profiler = pcall(require, "common/modules/profiler")
if not _profiler_ok or type(_profiler) ~= "table" then _profiler = nil end

local function safe_call(method_name, ...)
    if not _profiler then return end
    local method = _profiler[method_name]
    if type(method) ~= "function" then return end
    pcall(method, _profiler, ...)
end

function M.start(key)
    if not key then return end
    safe_call("start", key)
end

function M.stop(key, is_failed)
    if not key then return end
    safe_call("stop", key, is_failed == true)
end

function M.wrap(key, fn, ...)
    if not key or type(fn) ~= "function" then return fn(...) end
    M.start(key)
    local ok, result = pcall(fn, ...)
    M.stop(key, not ok)
    if not ok then error(result, 0) end
    return result
end

return M
