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
-- Suite discovery — the single source of truth for "what runs"
--
-- The runner must never report a green total over a partial battery, so discovery
-- either yields every suite in the directory or refuses to run. A hardcoded
-- fallback list used to hide missing suites when luafilesystem was unavailable:
-- it named a subset of the directory, so a partial run looked complete.
-- ---------------------------------------------------------------------------

local MANIFEST_NAME = "suite_manifest.lua"
local SUITE_PATTERN = "^test_.*%.lua$"

--- Load the checked-in manifest of suite filenames.
--- `read` is injectable for tests.
--- @return table|nil manifest, string|nil reason
function M.load_manifest(dir, read)
    read = read or function(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local data = f:read("*a")
        f:close()
        return data
    end

    local path = dir .. "/" .. MANIFEST_NAME
    local src = read(path)
    if not src then return nil, "manifest missing: " .. path end

    -- The manifest is data, not code: pull the names out of its `names = { ... }`
    -- block instead of executing the file. That keeps the loader free of
    -- loadstring/load (which differ across Lua versions) and means a malformed
    -- manifest can only ever produce a set mismatch, which the cross-check below
    -- turns into a refusal.
    local block = src:match("names%s*=%s*{([^}]*)}")
    if not block then
        return nil, path .. " must contain a names = { ... } block"
    end

    local names = {}
    for name in block:gmatch('"([^"]+)"') do
        if name:sub(-4) == ".lua" then names[#names + 1] = name end
    end
    if #names == 0 then
        return nil, path .. " lists no suites"
    end

    local manifest = { names = names }
    local set = {}
    for _, name in ipairs(names) do set[name] = true end
    manifest.set = set
    manifest.count = #names
    return manifest, nil
end

--- Discover every suite to run — all of them, or a reason why none can be run.
--- @param dir string Directory holding the suites
--- @param opts table|nil { lfs = <module|false>, read = <fn> }. Omit `lfs` to use the
---        real module; pass `false` to exercise the unavailable path.
--- @return table|nil names, string|nil reason
function M.discover_suites(dir, opts)
    opts = opts or {}

    local manifest, manifest_reason = M.load_manifest(dir, opts.read)
    if not manifest then return nil, manifest_reason end

    local lfs = opts.lfs
    if lfs == nil then
        local ok, mod = pcall(require, "lfs")
        lfs = ok and mod or nil
    end
    if not lfs then
        return nil, "luafilesystem unavailable: cannot enumerate " .. dir .. " (" ..
            tostring(manifest.count) .. " suites are listed in " .. MANIFEST_NAME ..") — " ..
            "refusing to run a partial battery"
    end

    local found = {}
    local listed_ok = pcall(function()
        for entry in lfs.dir(dir) do
            if type(entry) == "string" and entry:match(SUITE_PATTERN) then
                found[#found + 1] = entry
            end
        end
    end)
    if not listed_ok then
        return nil, "cannot read " .. dir .. " (lfs.dir failed) — refusing to run a partial battery"
    end
    if #found == 0 then
        return nil, "no suites found in " .. dir .. " (" .. tostring(manifest.count) ..
            " listed in " .. MANIFEST_NAME .. ") — refusing to report green over an empty battery"
    end

    table.sort(found)

    local on_disk = {}
    for _, name in ipairs(found) do on_disk[name] = true end

    local unlisted, missing = {}, {}
    for _, name in ipairs(found) do
        if not manifest.set[name] then unlisted[#unlisted + 1] = name end
    end
    for _, name in ipairs(manifest.names) do
        if not on_disk[name] then missing[#missing + 1] = name end
    end

    if #unlisted > 0 or #missing > 0 then
        local parts = {}
        if #unlisted > 0 then
            parts[#parts + 1] = tostring(#unlisted) .. " on disk but not in the manifest (" ..
                table.concat(unlisted, ", ") .. ")"
        end
        if #missing > 0 then
            parts[#parts + 1] = tostring(#missing) .. " in the manifest but not on disk (" ..
                table.concat(missing, ", ") .. ")"
        end
        return nil, "suite discovery/manifest drift: " .. table.concat(parts, "; ")
    end

    return found, nil
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
