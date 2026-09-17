-- run_leveling_tests.lua — EAX Leveling Rotation Test Suite Runner.
-- WHAT:  discovers and executes all leveling unit-test suites under EaxRotations/tests/.
-- WHEN:  invoked via lua EaxRotations/tests/run_leveling_tests.lua.
-- WHY:   single entry point for 13 leveling-suite validations; ensures no regressions.
-- SAFETY: pure orchestration; no rotation logic; fails fast on first suite error.

-- Context-aware module paths (cross-worktree leak fix, 2026-09-17): the old
-- unconditional '../?.lua' prepend resolved the PARENT directory, which inside
-- a git worktree is ANOTHER checkout -- an uncommitted edit there shadowed this
-- tree's modules (the pre-commit gate false-failed). The parent pattern is only
-- correct when CWD is <root>/EaxRotations (runner invoked from inside the tree,
-- detected via arg[0] lacking the 'EaxRotations/' prefix) -- and there '../' is
-- this tree itself, so no leak is possible. From the repo root, Lua's default
-- './?.lua' already resolves EaxRotations/... modules. The runner strips the
-- prepended pattern after its chdir fallback (runner.relax_parent_pattern).
-- Context is detected by PROBING THE FILESYSTEM, not arg[0] (some Lua
-- builds normalize arg[0] to an absolute path, which misfires the check).
--   Repo-root context (gate/CI): ./EaxRotations/tests/test_runner_lib.lua
--   exists -> default './?.lua' resolves every module; NO parent pattern.
--   In-tree context (cd EaxRotations && lua tests/...): only ../ has the
--   tree -> prepend; there '../' IS this tree, so no leak is possible.
-- The unconditional runner.relax_parent_pattern() below strips the parent
-- pattern once the chdir fallback has normalized CWD to the repo root.
local function repo_root_here()
    local f = io.open("EaxRotations/tests/test_runner_lib.lua", "rb")
    if f then f:close() return true end
    return false
end
if not repo_root_here() then
    package.path = "../?.lua;../?/init.lua;" .. package.path
end
local runner = require("EaxRotations/tests/test_runner_lib")
local mode, root = runner.parse_args(arg, "EaxRotations")
-- Root is now resolved and all downstream resolution is CWD-relative: no
-- invocation context (repo root, in-tree, or from-parent) still needs a
-- parent pattern. Strip it unconditionally so a worktree never resolves
-- the main checkout (or vice versa).
runner.relax_parent_pattern()
if not runner.file_exists(root .. "/tests/run_leveling_tests.lua") then
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs.chdir("..") then
        root = "EaxRotations"
        runner.relax_parent_pattern() -- CWD is the repo root now; '../' must not leak
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
    "test_paladin_leveling_forever.lua",
    "test_druid_leveling_forever.lua",
    "test_warrior_leveling_forever.lua",
    "test_hunter_leveling_forever.lua",
    "test_warlock_leveling_forever.lua",
    "test_rogue_leveling_forever.lua",
    "test_shaman_leveling_forever.lua",
    "test_mage_leveling_forever.lua",
    "test_leveling_paladin.lua",
    "test_leveling_load.lua",
    "test_leveling_shared.lua",
    "test_leveling_compliance.lua",
    "test_warrior_leveling_vanilla_spells.lua",
    "test_rogue_leveling_vanilla_combo_energy.lua",
    "test_leveling_dispatcher_prepass.lua",
    "test_leveling_dispatcher_registration.lua",
    "test_leveling_edge_cases.lua",
    "test_shaman_leveling_registration.lua",
    "test_wotlk_leveling_load.lua",
    "test_rogue_leveling_wotlk_dsl_priority.lua",
    "test_rogue_leveling_wotlk_strategies.lua",
    "test_hunter_leveling_wotlk_dsl_priority.lua",
    "test_priest_leveling_wotlk_dsl_priority.lua",
    "test_warlock_leveling_wotlk_dsl_priority.lua",
    "test_shaman_leveling_wotlk_dsl_priority.lua",
    "test_paladin_leveling_wotlk_dsl_priority.lua",
    "test_druid_leveling_wotlk_dsl_priority.lua",
    "test_mage_leveling_wotlk_dsl_priority.lua",
    "test_warrior_leveling_wotlk_dsl_priority.lua",
    "test_warrior_leveling_wotlk_strategies.lua",
    "test_deathknight_leveling_wotlk_dsl_priority.lua",
    "test_deathknight_leveling_wotlk_strategies.lua",
    "test_mage_leveling_wotlk_strategies.lua",
    "test_warlock_leveling_wotlk_strategies.lua",
    "test_shaman_leveling_wotlk_strategies.lua",
    "test_priest_leveling_wotlk_strategies.lua",
    "test_vanilla_leveling_ladders.lua",
    "test_tbc_leveling_ladders.lua",
    "test_wotlk_leveling_ladders.lua",
}

local function first_failure_line(output)
    return runner.first_failure_line(output)
end

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
    if not runner.file_exists(path) then
        failed = failed + 1
        failed_names[#failed_names + 1] = file .. " (missing)"
        if mode ~= "quiet" then print("  [ MISSING ] " .. file) end
    else
        local output, ok = runner.run_test(path)
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
