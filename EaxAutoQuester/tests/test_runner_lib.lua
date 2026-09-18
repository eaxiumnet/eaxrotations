-- What: Test runner library for EaxAutoQuester tests
-- When: Required by run_quester_tests.lua and individual test files
-- Why: Provides isolated test execution with snapshot/restore, output capture, and failure detection
-- Safety: Never uses io.popen, os.execute, ffi.C, debug.*, or math.sqrt
-- Decision: Adapted from EaxRotations/tests/test_runner_lib.lua for EaxAutoQuester

local M = {}

-- ---------------------------------------------------------------------------
-- CLI parsing
-- ---------------------------------------------------------------------------

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

local EXIT_SENTINEL_PREFIX = "\1__OS_EXIT__:"

function M.run_with_exit_trap(fn, ...)
    local orig_exit = os.exit
    os.exit = function(code)
        error(EXIT_SENTINEL_PREFIX .. tostring(code or 0), 0)
    end
    local ok, err = pcall(fn, ...)
    os.exit = orig_exit
    return ok, err
end

function M.parse_exit_code(err)
    if type(err) ~= "string" then return nil end
    if err:sub(1, #EXIT_SENTINEL_PREFIX) ~= EXIT_SENTINEL_PREFIX then return nil end
    return tonumber(err:sub(#EXIT_SENTINEL_PREFIX + 1)) or 0
end

-- ---------------------------------------------------------------------------
-- Failure detection in captured output
-- ---------------------------------------------------------------------------

local FAIL_PATTERNS_ANCHORED = {
    "^%s*%[?%s*fail",
    "^%s*missing",
    "^lua:%s",
}
local FAIL_PATTERNS_SUBSTR = {
    "assertion failed",
    "stack traceback",
    "fail:",
    "error:",
}

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
-- Test execution
-- ---------------------------------------------------------------------------

function M.run_test(path)
    local snap = M.snapshot()

    local output, ok, err = M.capture(function()
        local inner_ok, inner_err = M.run_with_exit_trap(function() dofile(path) end)
        if not inner_ok then error(inner_err, 0) end
    end)

    M.restore(snap)

    local exit_code = M.parse_exit_code(err)
    local fail = false
    local fail_reason
    if exit_code ~= nil then
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
