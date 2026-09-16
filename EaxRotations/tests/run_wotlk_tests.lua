-- run_wotlk_tests.lua — EAX WotLK rotation test runner.
-- WHAT:  discovers and executes all WotLK-specific test suites under EaxRotations/tests/.
-- WHEN:  invoked via lua EaxRotations/tests/run_wotlk_tests.lua.
-- WHY:   single entry point for WotLK rotation validations; ensures no regressions.
-- SAFETY: pure orchestration; no rotation logic; fails fast on first suite error.

-- Context-aware module paths (same contract as run_rotation_tests.lua, 2026-09-17):
-- the parent pattern is only added when CWD is NOT the repo root (in-tree or
-- from-parent invocation); there '../' is this tree, so no cross-worktree leak.
-- relax_parent_pattern() then strips it once root normalization has run.
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
-- In-tree/from-parent invocation: normalize CWD to the repo root (the other
-- runners have this fallback; this one was repo-root-only before).
if not runner.file_exists(root .. "/tests/run_wotlk_tests.lua") then
    local ok, lfs = pcall(require, "lfs")
    if ok and lfs.chdir("..") then
        root = "EaxRotations"
    end
end
-- Root resolved; all downstream resolution is CWD-relative. Strip parent
-- patterns so a worktree never resolves another checkout.
runner.relax_parent_pattern()

local tests = {
    "test_warrior_arms_wotlk.lua",
    "test_arms_wotlk_dsl_priority.lua",
    "test_fury_wotlk_strategies.lua",
    "test_fury_wotlk_dsl_priority.lua",
    "test_protection_wotlk_strategies.lua",
    "test_protection_wotlk_dsl_priority.lua",
    "test_warrior_leveling_wotlk_strategies.lua",
    "test_frost_wotlk_dsl_priority.lua",
    "test_blood_wotlk_dsl_priority.lua",
    "test_fire_wotlk_dsl_priority.lua",
    "test_retribution_wotlk_dsl_priority.lua",
    "test_paladin_retribution_wotlk_strategies.lua",
    "test_arcane_wotlk_dsl_priority.lua",
    "test_balance_wotlk_dsl_priority.lua",
    "test_bear_wotlk_dsl_priority.lua",
    "test_cat_wotlk_dsl_priority.lua",
    "test_druid_balance_wotlk_strategies.lua",
    "test_druid_bear_wotlk_strategies.lua",
    "test_druid_cat_wotlk_strategies.lua",
    "test_shadow_wotlk_dsl_priority.lua",
    "test_enhancement_wotlk_dsl_priority.lua",
    "test_unholy_wotlk_dsl_priority.lua",
    "test_deathknight_unholy_wotlk_strategies.lua",
    "test_frost_deathknight_wotlk_dsl_priority.lua",
    "test_frost_deathknight_wotlk_strategies.lua",
    "test_survival_wotlk_dsl_priority.lua",
    "test_marksmanship_wotlk_dsl_priority.lua",
    "test_beast_mastery_wotlk_dsl_priority.lua",
    "test_hunter_survival_wotlk_strategies.lua",
    "test_hunter_marksmanship_wotlk_strategies.lua",
    "test_hunter_beast_mastery_wotlk_strategies.lua",
    "test_protection_paladin_wotlk_dsl_priority.lua",
    "test_holy_wotlk_dsl_priority.lua",
    "test_paladin_protection_wotlk_strategies.lua",
    "test_paladin_holy_wotlk_strategies.lua",
    "test_elemental_wotlk_dsl_priority.lua",
    "test_restoration_wotlk_dsl_priority.lua",
    "test_combat_wotlk_dsl_priority.lua",
    "test_assassination_wotlk_dsl_priority.lua",
    "test_subtlety_wotlk_dsl_priority.lua",
    "test_rogue_leveling_wotlk_dsl_priority.lua",
    "test_rogue_combat_wotlk_strategies.lua",
    "test_rogue_assassination_wotlk_strategies.lua",
    "test_rogue_subtlety_wotlk_strategies.lua",
    "test_rogue_leveling_wotlk_strategies.lua",
    "test_hunter_leveling_wotlk_dsl_priority.lua",
    "test_priest_leveling_wotlk_dsl_priority.lua",
    "test_warlock_leveling_wotlk_dsl_priority.lua",
    "test_shaman_leveling_wotlk_dsl_priority.lua",
    "test_paladin_leveling_wotlk_dsl_priority.lua",
    "test_druid_leveling_wotlk_dsl_priority.lua",
    "test_mage_arcane_wotlk_strategies.lua",
    "test_mage_fire_wotlk_strategies.lua",
    "test_mage_frost_wotlk_strategies.lua",
    "test_mage_leveling_wotlk_dsl_priority.lua",
    "test_warrior_leveling_wotlk_dsl_priority.lua",
    "test_deathknight_leveling_wotlk_dsl_priority.lua",
    "test_deathknight_leveling_wotlk_strategies.lua",
    "test_deathknight_blood_wotlk_strategies.lua",
    "test_discipline_wotlk_dsl_priority.lua",
    "test_affliction_wotlk_dsl_priority.lua",
    "test_resto_wotlk_dsl_priority.lua",
    "test_druid_resto_wotlk_strategies.lua",
    "test_holy_priest_wotlk_dsl_priority.lua",
    "test_demonology_wotlk_dsl_priority.lua",
    "test_destruction_wotlk_dsl_priority.lua",
    "test_warlock_affliction_wotlk_strategies.lua",
    "test_warlock_demonology_wotlk_strategies.lua",
    "test_warlock_destruction_wotlk_strategies.lua",
    "test_shaman_elemental_wotlk_strategies.lua",
    "test_shaman_enhancement_wotlk_strategies.lua",
    "test_shaman_restoration_wotlk_strategies.lua",
    "test_priest_shadow_wotlk_strategies.lua",
    "test_priest_discipline_wotlk_strategies.lua",
    "test_priest_holy_wotlk_strategies.lua",
    "test_mage_leveling_wotlk_strategies.lua",
    "test_warlock_leveling_wotlk_strategies.lua",
    "test_shaman_leveling_wotlk_strategies.lua",
    "test_priest_leveling_wotlk_strategies.lua",
    "test_apl_conformance.lua",
    "test_wotlk_specs_load.lua",
    "test_wotlk_battery_regression.lua",
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
