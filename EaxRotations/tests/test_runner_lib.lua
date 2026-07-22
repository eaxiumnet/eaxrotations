-- test_runner_lib.lua -- test runner runner library tests.
-- WHAT:  test runner runner library tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- =============================================================================
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
-- Tables themselves are not deep-copied; we only capture the keys + values that
-- existed at snapshot time so restore() can re-apply them.
---@return table snap  snapshot table (do not mutate)
function M.snapshot()
    local g = {}
    for k, v in pairs(_G) do g[k] = v end
    local loaded = {}
    for k, v in pairs(package.loaded) do loaded[k] = v end
    local preload = {}
    for k, v in pairs(package.preload) do preload[k] = v end
    return {
        g = g,
        loaded = loaded,
        preload = preload,
        path = package.path,
        cpath = package.cpath,
    }
end

--- Restore _G and the package subsystem from a snapshot.
-- Strategy: re-insert the snapshot's keys+values. We deliberately do NOT
-- remove keys that were added during the test. Mutating a table while iterating
-- it with pairs() is undefined in Lua 5.1 and caused non-deterministic cleanup
-- (and different test results) on Windows vs Ubuntu. Preserving added keys keeps
-- the runner deterministic while still restoring modified values for keys that
-- existed at snapshot time.
function M.restore(snap)
    -- Restore _G, package.loaded, and package.preload from the snapshot.
    -- First remove any keys added during the test (deterministically, by
    -- collecting them before mutating), then re-apply snapshot values. This
    -- prevents mocks/stubs leaked via package.preload (or package.loaded) from
    -- contaminating later tests. We avoid mutating a table while iterating it
    -- with pairs(), which is undefined in Lua 5.1 and previously caused
    -- non-deterministic cleanup on Windows vs Ubuntu.
    local function added_keys(current, snapshot)
        local out = {}
        for k in pairs(current) do
            if snapshot[k] == nil then out[#out + 1] = k end
        end
        return out
    end

    -- _G
    local g_added = added_keys(_G, snap.g)
    for i = 1, #g_added do _G[g_added[i]] = nil end
    for k, v in pairs(snap.g) do _G[k] = v end

    -- package.loaded
    local loaded_added = added_keys(package.loaded, snap.loaded)
    for i = 1, #loaded_added do package.loaded[loaded_added[i]] = nil end
    for k, v in pairs(snap.loaded) do package.loaded[k] = v end

    -- package.preload
    local preload_added = added_keys(package.preload, snap.preload)
    for i = 1, #preload_added do package.preload[preload_added[i]] = nil end
    for k, v in pairs(snap.preload) do package.preload[k] = v end

    package.path = snap.path
    package.cpath = snap.cpath
end

--- Remove cached EaxRotations modules from package.loaded (and matching
-- package.preload entries so prior-test stubs do not shadow real files).
-- Call this at the top of a test that needs to load project modules fresh with
-- its own mocked _G state. Standard library / third-party modules are preserved.
function M.clear_eax_modules()
    for k in pairs(package.loaded) do
        if k:find("^shared/") or k:find("^classes/") or k:find("^common/")
           or k:find("^EaxRotations/")
           or k == "core_sylvanas" or k == "main_sylvanas" then
            package.loaded[k] = nil
        end
    end
    -- Also clear matching preload stubs; a previous test may have registered a
    -- lightweight fake under package.preload, and require() consults preload
    -- before searching package.path. Removing them enforces real-file loads.
    for k in pairs(package.preload) do
        if k:find("^shared/") or k:find("^classes/") or k:find("^common/")
           or k:find("^EaxRotations/")
           or k == "core_sylvanas" or k == "main_sylvanas" then
            package.preload[k] = nil
        end
    end
end

--- Clear specific modules from both package.loaded and package.preload.
-- Accepts either an array of module names, or varargs of names. Use this in
-- tests that need to evict a small, explicit set of modules without
-- resorting to repeated `package.loaded[name] = nil` lines.
function M.clear_loaded(names, ...)
    if type(names) == "string" then
        names = { names, ... }
    elseif type(names) ~= "table" then
        error("clear_loaded expects a table or string names", 2)
    end
    for i = 1, #names do
        local name = names[i]
        package.loaded[name] = nil
        package.preload[name] = nil
    end
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
-- Mock helpers for tests that exercise strategy.matches() directly.
-- These pre-populate context fields required by centralized generic guards
-- such as cat_sylvanas.lua::base_matches() (min_energy, min_combo,
-- requires_behind, required_form, target existence).
-- ---------------------------------------------------------------------------

M.Mock = {}

--- Return a default melee test context.
--
-- NOTE: This helper is currently tailored to feral-cat-style specs that use a
-- centralized base_matches() guard (e.g., cat_sylvanas.lua). As more specs
-- adopt centralized guards, extend or rename this helper to cover their
-- required fields.
-- Override any field by passing a table of overrides.
-- Default values are chosen so that base_matches-style guards pass:
--   in_combat = true
--   target = {}
--   enemy_count = 1
--   settings = {}
--   combo_points = 0
--   is_behind = true
--   is_cat = true
--   stance = 3  (cat form)
--   me = minimal mock unit with get_power/get_max_power/get_health_percentage
--
-- NOTE: `energy` is intentionally NOT defaulted. cat_sylvanas.lua's get_energy()
-- falls back to me.get_power() when context.energy is absent, so defaulting it
-- would silently override the me.get_power mock. Tests that need a specific
-- energy value should pass energy = <value> in overrides.
function M.Mock.DefaultMeleeContext(overrides)
    local ctx = {
        in_combat = true,
        has_valid_enemy_target = true,
        target = {},
        target_ttd = 60,
        enemy_count = 1,
        settings = {},
        combo_points = 0,
        pooling = false,
        is_behind = true,
        is_cat = true,
        stance = 3, -- cat form
        me = {
            get_power = function() return 50 end,
            get_max_power = function() return 100 end,
            get_health_percentage = function() return 100 end,
        },
    }
    if type(overrides) == "table" then
        -- Merge me overrides into the default me mock so tests don't have to
        -- re-supply get_max_power/get_health_percentage just to tweak get_power.
        if type(overrides.me) == "table" then
            for k, v in pairs(overrides.me) do
                ctx.me[k] = v
            end
        end
        for k, v in pairs(overrides) do
            if k ~= "me" then
                ctx[k] = v
            end
        end
    end
    return ctx
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
