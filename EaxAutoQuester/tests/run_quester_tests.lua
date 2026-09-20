-- What: Main test runner for EaxAutoQuester
-- When: Executed via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Runs all EaxAutoQuester test suites with isolation and reporting
-- Safety: Never uses io.popen, os.execute, ffi.C, debug.*, or math.sqrt
-- Decision: Adapted from EaxRotations test runner pattern

local test_runner = require("EaxAutoQuester/tests/test_runner_lib")
local mode, root = test_runner.parse_args(arg, "EaxAutoQuester/tests")

-- Add EaxAutoQuester directory to package.path so requires like "utils_sylvanas" resolve
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ---------------------------------------------------------------------------
-- Discover test files (complete set or abort)
-- ---------------------------------------------------------------------------

-- Discovery refuses to yield a partial set: without luafilesystem it aborts
-- instead of falling back to a hand-kept list, and it cross-checks the directory
-- against tests/suite_manifest.lua in both directions (see discover_suites).
local names, discover_reason = test_runner.discover_suites(root)
if not names then
    io.stderr:write("ERROR: suite discovery failed — " .. tostring(discover_reason) .. "\n")
    io.stderr:write("ERROR: refusing to run — a partial battery must never report green.\n")
    os.exit(3)
end

local test_files = {}
for i, name in ipairs(names) do
    test_files[i] = root .. "/" .. name
end

-- ---------------------------------------------------------------------------
-- Run tests
-- ---------------------------------------------------------------------------

local passed = 0
local failed = 0
local failed_tests = {}

for _, path in ipairs(test_files) do
    local file_name = path:match("([^/\\]+)$") or path

    if mode == "verbose" then
        print("[ RUN      ] " .. file_name)
    end

    local output, ok, err = test_runner.run_test(path)

    if ok then
        passed = passed + 1
        if mode == "verbose" then
            print("[ PASS     ] " .. file_name)
        end
    else
        failed = failed + 1
        failed_tests[#failed_tests + 1] = { file = file_name, output = output, err = err }
        if mode ~= "quiet" then
            print("[ FAIL     ] " .. file_name)
            local first_fail = test_runner.first_failure_line(output)
            if first_fail then
                print("  -> " .. first_fail)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

print("")
print("========================================")
print("EaxAutoQuester Test Results")
print("========================================")
print("Total:  " .. tostring(passed + failed))
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))
print("========================================")

if failed > 0 and mode == "verbose" then
    print("")
    print("Failed test details:")
    for _, info in ipairs(failed_tests) do
        print("\n--- " .. info.file .. " ---")
        print(info.output)
    end
end

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
