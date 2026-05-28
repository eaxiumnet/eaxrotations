-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/run_leveling_tests.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
local root = "EaxRotations"
local mode = "normal"

if arg then
    for i = 1, #arg do
        if arg[i] == "-v" or arg[i] == "--verbose" then
            mode = "verbose"
        elseif arg[i] == "-q" or arg[i] == "--quiet" then
            mode = "quiet"
        elseif arg[i] ~= "" then
            root = arg[i]
        end
    end
end

local tests = {
    "test_leveling_mage.lua",
    "test_leveling_warlock.lua",
    "test_leveling_priest.lua",
    "test_leveling_rogue.lua",
    "test_leveling_shaman.lua",
    "test_leveling_warrior.lua",
    "test_leveling_druid.lua",
    "test_leveling_hunter.lua",
    "test_leveling_paladin.lua",
    "test_leveling_load.lua",
    "test_leveling_shared.lua",
}

local function quote(path)
    return '"' .. tostring(path):gsub('"', '\\"') .. '"'
end

local function read_command(command)
    local pipe = io.popen(command .. " 2>&1")
    if not pipe then return "", false end
    local output = pipe:read("*a") or ""
    local ok = pipe:close()
    return output, ok == true
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

local function first_failure_line(output)
    for line in output:gmatch("[^\r\n]+") do
        local lower = line:lower()
        if lower:find("fail", 1, true) or lower:find("error", 1, true) or lower:find("assert", 1, true) then
            return line
        end
    end
    return nil
end

local lua_bin = os.getenv("LUA") or "lua"
local passed, failed = 0, 0
local failed_names = {}

if mode ~= "quiet" then
    print("=============================================================================")
    print("  EAX Leveling Rotation Tests")
    print("  Root:  " .. root)
    print("  Files: " .. tostring(#tests) .. " suites")
    print("=============================================================================")
    print("")
end

for i = 1, #tests do
    local file = tests[i]
    local path = root .. "/tests/" .. file
    if not file_exists(path) then
        failed = failed + 1
        failed_names[#failed_names + 1] = file .. " (missing)"
        if mode ~= "quiet" then print("  [ MISSING ] " .. file) end
    else
        local output, ok = read_command(lua_bin .. " " .. quote(path))
        if mode == "verbose" then
            print("=== " .. file .. " ===")
            io.write(output)
            if output:sub(-1) ~= "\n" then print("") end
        end

        if ok then
            passed = passed + 1
            if mode ~= "quiet" then print(string.format("  [ PASS ] %-32s ok", file)) end
        else
            failed = failed + 1
            failed_names[#failed_names + 1] = file
            if mode ~= "quiet" then
                print(string.format("  [ FAIL ] %-32s %s", file, first_failure_line(output) or "failed"))
            end
        end
    end
end

print("")
print("=============================================================================")
print("  RESULTS")
print("=============================================================================")
print(string.format("  Total:  %3d suites", #tests))
print(string.format("  Passed: %3d", passed))
print(string.format("  Failed: %3d", failed))

if #failed_names > 0 then
    print("  Failed suites:")
    for i = 1, #failed_names do print("    - " .. failed_names[i]) end
end

print("=============================================================================")

if failed > 0 then os.exit(1) end
