-- run_wotlk_tests.lua — EAX WotLK rotation test runner.
-- WHAT:  discovers and executes all WotLK-specific test suites under EaxRotations/tests/.
-- WHEN:  invoked via lua EaxRotations/tests/run_wotlk_tests.lua.
-- WHY:   single entry point for WotLK rotation validations; ensures no regressions.
-- SAFETY: pure orchestration; no rotation logic; fails fast on first suite error.

local runner = require("EaxRotations/tests/test_runner_lib")
local mode, root = runner.parse_args(arg, "EaxRotations")

local tests = {
    "test_warrior_arms_wotlk.lua",
    "test_wotlk_integration.lua",
    "test_wotlk_specs_load.lua",
}

local function first_failure_line(output)
    return runner.first_failure_line(output)
end

local passed, failed = 0, 0
local failed_names = {}

if mode ~= "quiet" then
    print("=============================================================================")
    print(" EAX WotLK Rotation Tests")
    print(" Root: " .. root)
    print(" Files: " .. tostring(#tests) .. " suites")
    print("=============================================================================")
    print("")
end

for i = 1, #tests do
    local file = tests[i]
    local path = root .. "/tests/" .. file
    if not runner.file_exists(path) then
        failed = failed + 1
        failed_names[#failed_names + 1] = file .. " (missing)"
        if mode ~= "quiet" then print(" [ MISSING ] " .. file) end
    else
        local output, ok = runner.run_test(path)
        if mode == "verbose" then
            print("=== " .. file .. " ===")
            io.write(output)
            if output:sub(-1) ~= "\n" then print("") end
        end

        if ok then
            passed = passed + 1
            if mode ~= "quiet" then print(string.format(" [ PASS ] %-32s ok", file)) end
        else
            failed = failed + 1
            failed_names[#failed_names + 1] = file
            if mode ~= "quiet" then
                print(string.format(" [ FAIL ] %-32s %s", file, first_failure_line(output) or "failed"))
            end
        end
    end
end

print("")
print("=============================================================================")
print(" RESULTS")
print("=============================================================================")
print(string.format(" Total: %3d suites", #tests))
print(string.format(" Passed: %3d", passed))
print(string.format(" Failed: %3d", failed))

if #failed_names > 0 then
    print(" Failed suites:")
    for i = 1, #failed_names do print(" - " .. failed_names[i]) end
end

print("=============================================================================")

if failed > 0 then os.exit(1) end
