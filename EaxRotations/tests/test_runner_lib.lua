-- =============================================================================
-- test_runner_lib.lua
--
-- Shared helpers for the EaxRotations test runners
-- (run_rotation_tests.lua, run_leveling_tests.lua).
--
-- Replaces the previous io.popen-based child-process model with in-process
-- test execution:
--
--   * Snapshot _G and package state before each test, then restore afterwards
--     so per-test mocks / require caches do not leak between suites.
--   * Capture print() and io.write() output during the test for verbose mode
--     and for failure diagnostics.
--   * Translate os.exit(code) calls inside a test into a captured error so
--     the runner can decide pass/fail (mirroring the previous child-process
--     exit-code semantics: code 0 = pass, non-zero = fail).
--   * Never invokes io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- CLI parsing
-- ---------------------------------------------------------------------------

--- Parse command-line flags.
-- Recognised:
--   -v / --verbose   -> mode = "verbose"
--   -q / --quiet     -> mode = "quiet"
--   <positional>     -> root override (path passed to the runner)
---@param arg table   process arg table (the script's `arg`)
---@param default_root string  root used when no positional is supplied
---@return string mode   ("normal" | "verbose" | "quiet")
---@return string root   (root path string)
function M.parse_args(arg, default_root)
    local mode = "normal"
    local root = default_root
    if arg then
        for i = 1, #arg do
            local a = arg[i]
            if a == "-v" or a == "--verbose" then
                mode = "verbose"
            elseif a == "-q" or a == "--quiet" then
                mode = "quiet"
            elseif a ~= nil and a ~= "" then
                root = a
            end
        end
    end
    return mode, root
end

-- ---------------------------------------------------------------------------
-- Output capture
-- ---------------------------------------------------------------------------

--- Run `fn` while capturing print() and io.write() output into a single string.
-- Restores the originals before returning. Errors raised inside fn are caught
-- by pcall and returned to the caller as (ok=false, err=...).
--
-- Special handling: prints are reproduced exactly (tab-separated args + "\n")
-- so that replaying the captured buffer via io.write produces byte-identical
-- output to the un-captured invocation.
---@return string output  concatenated captured chunks
---@return boolean ok     pcall success flag
---@return any err        error object (when ok is false)
function M.capture(fn, ...)
    local chunks = {}
    local orig_print = _G.print
    local orig_write = io.write
    local ok, err

    local function emit(s)
        if s ~= nil then chunks[#chunks + 1] = tostring(s) end
    end

    _G.print = function(...)
        local n = select("#", ...)
        if n == 0 then
            emit("\n")
            return
        end
        local parts = {}
        for i = 1, n do parts[i] = tostring(select(i, ...)) end
        emit(table.concat(parts, "\t") .. "\n")
    end
    io.write = function(...)
        local n = select("#", ...)
        for i = 1, n do
            local s = select(i, ...)
            if s ~= nil then emit(s) end
        end
    end

    ok, err = pcall(fn, ...)

    _G.print = orig_print
    io.write = orig_write

    return table.concat(chunks), ok, err
end

-- ---------------------------------------------------------------------------
-- State snapshot / restore
-- ---------------------------------------------------------------------------

--- Capture a shallow snapshot of _G and the package subsystem.
-- Used to roll back mutations that a test might leave behind (e.g. module
-- caches in package.loaded, mocks in _G.EaxRotations, _G.core, package.path).
-- Tables themselves are not deep-copied; we only need the keys + values that
-- exist at snapshot time so we can wipe + restore them after a test.
---@return table snap  snapshot table (do not mutate)
function M.snapshot()
    local g = {}
    for k, v in pairs(_G) do g[k] = v end
    local loaded = {}
    for k, v in pairs(package.loaded) do loaded[k] = v end
    return {
        g = g,
        loaded = loaded,
        path = package.path,
        cpath = package.cpath,
    }
end

--- Restore _G and the package subsystem from a snapshot.
-- Strategy: re-insert the snapshot's keys+values first, then remove any keys
-- the test added that were not present in the snapshot. This avoids wiping
-- the global table's `_G` entry mid-loop (which would break the very loop
-- trying to clean up) and is equivalent in result to a wipe-then-restore.
function M.restore(snap)
    for k, v in pairs(snap.g) do _G[k] = v end
    for k in pairs(_G) do
        if snap.g[k] == nil then _G[k] = nil end
    end

    for k, v in pairs(snap.loaded) do package.loaded[k] = v end
    for k in pairs(package.loaded) do
        if snap.loaded[k] == nil then package.loaded[k] = nil end
    end

    package.path = snap.path
    package.cpath = snap.cpath
end

-- ---------------------------------------------------------------------------
-- os.exit interception
-- ---------------------------------------------------------------------------

-- Sentinel error used to signal that a test called os.exit(N) with code N.
-- Format: leading marker (so we can detect it) + numeric code.
local EXIT_SENTINEL_PREFIX = "\1__OS_EXIT__:"

--- Wrap a test invocation so that any os.exit call inside the test raises a
-- sentinel error which pcall catches. The sentinel is decoded by run_test()
-- to translate exit code -> pass/fail.
-- Mutates `os.exit` for the duration of the call and restores it on the way
-- out (success or failure).
function M.run_with_exit_trap(fn, ...)
    local orig_exit = os.exit
    os.exit = function(code)
        error(EXIT_SENTINEL_PREFIX .. tostring(code or 0), 0)
    end
    local ok, err = pcall(fn, ...)
    os.exit = orig_exit
    return ok, err
end

--- Return the exit code embedded in a sentinel error, or nil if not a sentinel.
function M.parse_exit_code(err)
    if type(err) ~= "string" then return nil end
    if err:sub(1, #EXIT_SENTINEL_PREFIX) ~= EXIT_SENTINEL_PREFIX then return nil end
    return tonumber(err:sub(#EXIT_SENTINEL_PREFIX + 1)) or 0
end

-- ---------------------------------------------------------------------------
-- Failure detection in captured output
-- ---------------------------------------------------------------------------

-- Patterns looked for in the captured output. We unify the two original
-- runners' approaches: the rotation runner's "line-anchored" markers plus
-- the leveling runner's substring markers. A test is considered to have
-- reported failure if any of these match (this mirrors the old
-- `read_command` fallback that re-checked stdout when exit code was 0).
local FAIL_PATTERNS_ANCHORED = {
    "^%s*%[?%s*fail",   -- [ FAIL  /  FAIL:
    "^%s*missing",      -- our runner's own "  [ MISSING ]" lines
    "^lua:%s",          -- "lua: " runtime errors
}
local FAIL_PATTERNS_SUBSTR = {
    "assertion failed",
    "stack traceback",
    -- Substring markers from the leveling runner (used to catch custom
    -- "FAIL: foo" / "assert(...)" messages printed by tests that wrap their
    -- own assertions in pcall):
    "fail:",
    "error:",
}

--- True if the captured output contains a failure marker.
function M.output_indicates_failure(output)
    if not output or output == "" then return false end
    for line in output:gmatch("[^\r\n]+") do
        local lower = line:lower()
        for _, p in ipairs(FAIL_PATTERNS_ANCHORED) do
            if lower:match(p) then return true end
        end
        for _, p in ipairs(FAIL_PATTERNS_SUBSTR) do
            if lower:find(p, 1, true) then return true end
        end
    end
    return false
end

--- Return the first line in the output that looks like a failure marker,
-- or nil. Used for the "[ FAIL ] <file> <reason>" tail of the per-test line.
function M.first_failure_line(output)
    if not output or output == "" then return nil end
    for line in output:gmatch("[^\r\n]+") do
        local lower = line:lower()
        for _, p in ipairs(FAIL_PATTERNS_ANCHORED) do
            if lower:match(p) then return line end
        end
        for _, p in ipairs(FAIL_PATTERNS_SUBSTR) do
            if lower:find(p, 1, true) then return line end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Filesystem
-- ---------------------------------------------------------------------------

function M.file_exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

-- ---------------------------------------------------------------------------
-- Shared assertion helpers
-- ---------------------------------------------------------------------------

function M.assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

function M.assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq failed") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- ---------------------------------------------------------------------------
-- Test execution
-- ---------------------------------------------------------------------------

--- Run a single test file with full isolation.
--  1. Snapshot _G + package state.
--  2. Trap os.exit so tests that exit directly become normal errors.
--  3. dofile(path) inside pcall, capturing print/io.write output.
--  4. Restore _G + package state.
--  5. Decide pass/fail:
--       - pcall ok AND no exit sentinel AND no failure marker -> PASS
--       - pcall ok AND exit sentinel with code 0             -> PASS
--       - pcall ok AND exit sentinel with code != 0          -> FAIL
--       - pcall ok AND output contains a failure marker      -> FAIL
--       - pcall not ok                                       -> FAIL
--  6. Return (output, ok, err_or_nil).
function M.run_test(path)
    local snap = M.snapshot()

    local output, ok, err = M.capture(function()
        local inner_ok, inner_err = M.run_with_exit_trap(function() dofile(path) end)
        -- If the test exited via os.exit, propagate the sentinel so the
        -- outer capture also returns ok=false. This keeps the captured
        -- output intact (everything the test printed up to the exit call).
        if not inner_ok then error(inner_err, 0) end
    end)

    M.restore(snap)

    -- Interpret the result.
    local exit_code = M.parse_exit_code(err)
    local fail = false
    local fail_reason
    if exit_code ~= nil then
        -- os.exit was called.
        if exit_code ~= 0 then
            fail = true
            fail_reason = "exit(" .. tostring(exit_code) .. ")"
        end
    elseif not ok then
        fail = true
        fail_reason = tostring(err)
    elseif M.output_indicates_failure(output) then
        fail = true
    end

    if fail and fail_reason and not output:find("ERROR", 1, true) then
        output = output .. "ERROR: " .. fail_reason .. "\n"
    end

    return output, not fail, err
end

return M
