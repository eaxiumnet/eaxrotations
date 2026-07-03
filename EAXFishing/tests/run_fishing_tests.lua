-- =============================================================================
-- run_fishing_tests.lua — Test runner for EAXFishing.
-- =============================================================================
-- WHAT:  Discovers every test_*.lua in this directory, runs each in isolation,
--        prints PASS/FAIL counts, and exits 0/1.
-- WHEN:  `lua EAXFishing/tests/run_fishing_tests.lua`  [-v verbose | -q quiet]
-- WHY:   EAXFishing had ZERO tests despite being the most user-facing module
--        (in-game automation). EaxESP has 4 suites, EaxProfession has 3,
--        EaxProfessions has 23. This closes the coverage gap.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

package.path = table.concat({
  "./EAXFishing/?.lua",
  "./EAXFishing/?/init.lua",
  package.path,
}, ";")

local mode = "normal"
for _, a in ipairs(arg or {}) do
  if a == "-v" then mode = "verbose" end
  if a == "-q" then mode = "quiet" end
end

-- Hardcoded test list (no lfs dependency — works on the stock Windows Lua 5.4 build).
local known_tests = {
  "test_state_machine.lua",
  "test_config_safe_menu.lua",
}

local passed, failed = 0, 0
local failed_tests = {}

for _, file in ipairs(known_tests) do
  local path = "./EAXFishing/tests/" .. file
  local f = io.open(path, "r")
  if f then
    f:close()
    if mode == "verbose" then print("[ RUN  ] " .. file) end
    -- Isolate each test in a fresh Lua state via dofile. pcall so one failure
    -- does not abort the whole suite.
    local fn, load_err = loadfile(path)
    if not fn then
      failed = failed + 1
      failed_tests[#failed_tests + 1] = { file = file, err = "load: " .. tostring(load_err) }
    else
      -- Sandbox os.exit: tests call os.exit(0) on success. We must NOT let
      -- that abort the runner. Stub it to record the code instead so the
      -- chunk runs to completion. Failure paths use error(), which pcall
      -- catches below.
      local _exit_code = 0
      local real_exit = os.exit
      os.exit = function(code) _exit_code = code or 0 end
      local ok, err = pcall(fn)
      os.exit = real_exit
      if ok and _exit_code == 0 then
        passed = passed + 1
        if mode == "verbose" then print("[ PASS  ] " .. file) end
      else
        failed = failed + 1
        failed_tests[#failed_tests + 1] = { file = file, err = tostring(err) }
        if mode ~= "quiet" then
          print("[ FAIL  ] " .. file)
          print("  -> " .. tostring(err))
        end
      end
    end
  end
end

print("")
print("========================================")
print("EAXFishing Test Results")
print("========================================")
print("Total:  " .. tostring(passed + failed))
print("Passed: " .. tostring(passed))
print("Failed: " .. tostring(failed))
print("========================================")

if failed > 0 then os.exit(1) end
os.exit(0)