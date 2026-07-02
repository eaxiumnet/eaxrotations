-- =============================================================================
-- test_runner_lib.lua — Standalone test runner library for EaxProfession.
-- =============================================================================
-- WHAT:  Minimal test runner that loads a test file in a protected environment,
--        captures output, and reports PASS/FAIL.
-- WHEN:  Called by run_tests.lua for each test_*.lua file.
-- WHY:   Standalone — no dependencies on EaxRotations or other projects.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

local M = {}

-- -----------------------------------------------------------------------------
-- Parse command-line arguments.
-- @param arg table  CLI args from the Lua runtime
-- @param default_root string  Default test directory
-- @return string mode  "normal" | "verbose" | "quiet"
-- @return string root  Path to the test directory
-- -----------------------------------------------------------------------------
function M.parse_args(arg, default_root)
  local mode = "normal"
  local root = default_root or "tests"

  for i = 1, #arg do
    local a = arg[i]
    if a == "-v" or a == "--verbose" then
      mode = "verbose"
    elseif a == "-q" or a == "--quiet" then
      mode = "quiet"
    elseif a and not a:match("^-") then
      root = a
    end
  end

  return mode, root
end

-- -----------------------------------------------------------------------------
-- Run a single test file in a protected environment.
-- @param path string  Absolute or relative path to the test .lua file
-- @return string output  Captured stdout
-- @return boolean ok    True if the test passed (exited 0)
-- @return string|nil err Error message if the test failed
-- -----------------------------------------------------------------------------
function M.run_test(path)
  -- Load the file
  local fn, load_err = loadfile(path)
  if not fn then
    return "", false, "Load error: " .. tostring(load_err)
  end

  -- Capture output by redirecting print
  local output_lines = {}
  local original_print = print
  local function captured_print(...)
    local args = { ... }
    local line = table.concat(args, "\t")
    output_lines[#output_lines + 1] = line
  end

  -- Override os.exit to prevent actual exit
  local original_exit = os.exit
  local exit_code = 0
  os.exit = function(code)
    exit_code = code or 0
    error({ __test_exit = true, code = exit_code }, 0)
  end

  -- Run the test with captured print
  print = captured_print
  local ok, err = pcall(fn)
  print = original_print
  os.exit = original_exit

  local output = table.concat(output_lines, "\n")

  -- If the test called os.exit(0), that's a pass
  if not ok and type(err) == "table" and err.__test_exit then
    if err.code == 0 then
      return output, true, nil
    else
      return output, false, "Test exited with code " .. tostring(err.code)
    end
  end

  -- If pcall failed for any other reason, it's a failure
  if not ok then
    output_lines[#output_lines + 1] = "ERROR: " .. tostring(err)
    output = table.concat(output_lines, "\n")
    return output, false, tostring(err)
  end

  -- If pcall succeeded but no exit was called, assume pass
  -- (test didn't call os.exit — treat as implicit pass)
  return output, true, nil
end

-- -----------------------------------------------------------------------------
-- Extract the first failure line from test output.
-- @param output string  Captured test output
-- @return string|nil  First line containing "FAIL" or "ERROR"
-- -----------------------------------------------------------------------------
function M.first_failure_line(output)
  if not output then return nil end
  for line in output:gmatch("[^\r\n]+") do
    if line:find("FAIL") or line:find("ERROR") then
      return line
    end
  end
  return nil
end

return M
