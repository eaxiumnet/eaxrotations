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
-- Discover test files
-- ---------------------------------------------------------------------------

local test_files = {}

-- Try to list files using lfs or os.execute fallback
local has_lfs, lfs = pcall(require, "lfs")
if has_lfs and lfs then
    for file in lfs.dir(root) do
        if file:match("^test_.*%.lua$") then
            test_files[#test_files + 1] = root .. "/" .. file
        end
    end
else
    -- Fallback: hardcode known test files if lfs unavailable
    local known_tests = {
        "test_utils_sylvanas.lua",
        "test_npc_manager.lua",
        "test_combat_helper.lua",
        "test_loot_manager.lua",
        "test_vendor_manager.lua",
        "test_vendor_bag_trigger.lua",
        "test_idle_state.lua",
        "test_nav_state.lua",
        "test_interact_state.lua",
        "test_do_action_state.lua",
        "test_waiting_state.lua",
        "test_dead_state.lua",
        "test_death_tracker.lua",
        "test_coordinator.lua",
        "test_object_scanner.lua",
        "test_safe_api_wrapper.lua",
        "test_integration_quest_flow.lua",
        "test_integration_vendor_flow.lua",
        "test_integration_death_flow.lua",
        "test_auto_equip.lua",
        "test_quest_blacklist.lua",
    }
    for _, file in ipairs(known_tests) do
        local path = root .. "/" .. file
        local f = io.open(path, "r")
        if f then
            f:close()
            test_files[#test_files + 1] = path
        end
    end
end

-- Sort for deterministic order
table.sort(test_files)

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
