-- =============================================================================
-- run_tests.lua — Main test runner entry point for EaxProfession.
-- =============================================================================
-- WHAT:  Discovers every test_*.lua in the tests/ directory, runs each in
--        isolation, prints PASS/FAIL counts, and exits with code 0 or 1.
-- WHEN:  Run manually: `lua EaxProfession/tests/run_tests.lua`
-- WHY:   Standalone test runner — no dependencies on other Eax projects.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================
-- Usage:
--   lua EaxProfession/tests/run_tests.lua           — normal mode
--   lua EaxProfession/tests/run_tests.lua -v         — verbose mode
--   lua EaxProfession/tests/run_tests.lua -q         — quiet mode
-- =============================================================================

local test_runner = require("EaxProfession/tests/test_runner_lib")
local mode, root = test_runner.parse_args(arg, "EaxProfession/tests")

-- Add project directory to package.path so requires like
-- "core/api_surface" resolve correctly.
package.path = table.concat({
  "./EaxProfession/?.lua",
  "./EaxProfession/?/init.lua",
  package.path,
}, ";")

-- -----------------------------------------------------------------------------
-- Discover test files
-- -----------------------------------------------------------------------------
local test_files = {}

-- Try lfs first; fall back to hardcoded list if lfs is unavailable.
local has_lfs, lfs = pcall(require, "lfs")
if has_lfs and lfs then
  for file in lfs.dir(root) do
    if file:match("^test_.*%.lua$") then
      test_files[#test_files + 1] = root .. "/" .. file
    end
  end
else
  -- Fallback: hardcoded known test files
  local known_tests = {
    "test_api_surface.lua",
    "test_crafting_engine.lua",
    "test_skill_gain_and_menu.lua",
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

-- -----------------------------------------------------------------------------
-- Run tests
-- -----------------------------------------------------------------------------
local passed = 0
local failed = 0
local failed_tests = {}

for _, path in ipairs(test_files) do
  local file_name = path:match("([^/\\]+)$") or path

  if mode == "verbose" then
    print("[ RUN  ] " .. file_name)
  end

  local output, ok, err = test_runner.run_test(path)

  if ok then
    passed = passed + 1
    if mode == "verbose" then
      print("[ PASS  ] " .. file_name)
    end
  else
    failed = failed + 1
    failed_tests[#failed_tests + 1] = { file = file_name, output = output, err = err }
    if mode ~= "quiet" then
      print("[ FAIL  ] " .. file_name)
      local first_fail = test_runner.first_failure_line(output)
      if first_fail then
        print(" -> " .. first_fail)
      end
    end
  end
end

-- -----------------------------------------------------------------------------
-- Summary
-- -----------------------------------------------------------------------------
print("")
print("========================================")
print("EaxProfession Test Results")
print("========================================")
print("Total: " .. tostring(passed + failed))
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
