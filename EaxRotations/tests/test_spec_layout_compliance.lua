-- test_spec_layout_compliance.lua -- Canonical spec-file layout contract (Phase 0 standardization).
-- WHAT:  reads all _sylvanas.lua spec files and asserts the canonical layout contract:
--          (a) Pattern 15 header present (WHAT + SAFETY keys in first 30 lines) -- ALL specs.
--          (b) For CONVERTED specs (spec_kit adopters): spec_kit require,
--              define_action_for_class, guarded registration, build_state symbol, valid return.
-- WHEN:  run as a standalone test or via run_rotation_tests.lua.
-- WHY:   locks the standardization contract so new spec files conform and converted
--        specs do not regress. Legacy specs are tracked via a migration state table.
-- SAFETY: pure file-read static analysis; no engine API calls; no module loading.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local lfs_ok, lfs = pcall(require, "lfs")
if not lfs_ok or not lfs then
    print("SKIP test_spec_layout_compliance (lfs not available on this Lua build)")
    return
end

local function read_file(path)
    local f = assert(io.open(path, "rb"), "open failed: " .. path)
    local text = f:read("*a") or ""
    f:close()
    return text
end

-- Same spec file list as test_rotation_static_compliance.lua / test_rotation_strategy_compliance.lua.
local spec_files = {
    "EaxRotations/classes/druid/balance_sylvanas.lua",
    "EaxRotations/classes/druid/bear_sylvanas.lua",
    "EaxRotations/classes/druid/cat_sylvanas.lua",
    "EaxRotations/classes/druid/caster_sylvanas.lua",
    "EaxRotations/classes/druid/healing_sylvanas.lua",
    "EaxRotations/classes/druid/leveling_sylvanas.lua",
    "EaxRotations/classes/druid/resto_sylvanas.lua",
    "EaxRotations/classes/hunter/beast_mastery_sylvanas.lua",
    "EaxRotations/classes/hunter/marksmanship_sylvanas.lua",
    "EaxRotations/classes/hunter/survival_sylvanas.lua",
    "EaxRotations/classes/hunter/leveling_sylvanas.lua",
    "EaxRotations/classes/mage/arcane_sylvanas.lua",
    "EaxRotations/classes/mage/fire_sylvanas.lua",
    "EaxRotations/classes/mage/frost_sylvanas.lua",
    "EaxRotations/classes/mage/leveling_sylvanas.lua",
    "EaxRotations/classes/paladin/holy_sylvanas.lua",
    "EaxRotations/classes/paladin/protection_sylvanas.lua",
    "EaxRotations/classes/paladin/retribution_sylvanas.lua",
    "EaxRotations/classes/paladin/leveling_sylvanas.lua",
    "EaxRotations/classes/priest/discipline_sylvanas.lua",
    "EaxRotations/classes/priest/holy_sylvanas.lua",
    "EaxRotations/classes/priest/shadow_sylvanas.lua",
    "EaxRotations/classes/priest/smite_sylvanas.lua",
    "EaxRotations/classes/priest/leveling_sylvanas.lua",
    "EaxRotations/classes/rogue/assassination_sylvanas.lua",
    "EaxRotations/classes/rogue/combat_sylvanas.lua",
    "EaxRotations/classes/rogue/subtlety_sylvanas.lua",
    "EaxRotations/classes/rogue/leveling_sylvanas.lua",
    "EaxRotations/classes/shaman/elemental_sylvanas.lua",
    "EaxRotations/classes/shaman/enhancement_sylvanas.lua",
    "EaxRotations/classes/shaman/restoration_sylvanas.lua",
    "EaxRotations/classes/shaman/leveling_sylvanas.lua",
    "EaxRotations/classes/warlock/affliction_sylvanas.lua",
    "EaxRotations/classes/warlock/demonology_sylvanas.lua",
    "EaxRotations/classes/warlock/destruction_sylvanas.lua",
    "EaxRotations/classes/warlock/leveling_sylvanas.lua",
    "EaxRotations/classes/warrior/arms_sylvanas.lua",
    "EaxRotations/classes/warrior/fury_sylvanas.lua",
    "EaxRotations/classes/warrior/kebab_sylvanas.lua",
    "EaxRotations/classes/warrior/protection_sylvanas.lua",
    "EaxRotations/classes/warrior/leveling_sylvanas.lua",
}

-- Specs that have adopted spec_kit.define_action_for_class (the mechanical conversion).
-- Add a spec here ONLY after it has been converted AND the full 234+13 suite passes.
-- The full canonical template (safe_state + return {strategies, build_state}) is Phase 3.
local CONVERTED = {
    ["EaxRotations/classes/warrior/arms_sylvanas.lua"] = true,
    ["EaxRotations/classes/warrior/fury_sylvanas.lua"] = true,
    ["EaxRotations/classes/warrior/protection_sylvanas.lua"] = true,
    ["EaxRotations/classes/warrior/kebab_sylvanas.lua"] = true,
    ["EaxRotations/classes/druid/balance_sylvanas.lua"] = true,
    ["EaxRotations/classes/druid/cat_sylvanas.lua"] = true,
    ["EaxRotations/classes/druid/bear_sylvanas.lua"] = true,
    ["EaxRotations/classes/druid/caster_sylvanas.lua"] = true,
    ["EaxRotations/classes/druid/resto_sylvanas.lua"] = true,
    ["EaxRotations/classes/priest/discipline_sylvanas.lua"] = true,
    ["EaxRotations/classes/priest/holy_sylvanas.lua"] = true,
    ["EaxRotations/classes/priest/shadow_sylvanas.lua"] = true,
    ["EaxRotations/classes/mage/fire_sylvanas.lua"] = true,
    ["EaxRotations/classes/warlock/destruction_sylvanas.lua"] = true,
    ["EaxRotations/classes/mage/frost_sylvanas.lua"] = true,
    ["EaxRotations/classes/shaman/restoration_sylvanas.lua"] = true,
    ["EaxRotations/classes/warlock/affliction_sylvanas.lua"] = true,
    ["EaxRotations/classes/rogue/combat_sylvanas.lua"] = true,
    ["EaxRotations/classes/warlock/demonology_sylvanas.lua"] = true,
    ["EaxRotations/classes/shaman/elemental_sylvanas.lua"] = true,
    ["EaxRotations/classes/shaman/enhancement_sylvanas.lua"] = true,
    ["EaxRotations/classes/rogue/assassination_sylvanas.lua"] = true,
    ["EaxRotations/classes/hunter/marksmanship_sylvanas.lua"] = true,
    ["EaxRotations/classes/paladin/retribution_sylvanas.lua"] = true,
    ["EaxRotations/classes/rogue/subtlety_sylvanas.lua"] = true,
    ["EaxRotations/classes/hunter/survival_sylvanas.lua"] = true,
    ["EaxRotations/classes/paladin/protection_sylvanas.lua"] = true,
    ["EaxRotations/classes/hunter/beast_mastery_sylvanas.lua"] = true,
    ["EaxRotations/classes/paladin/holy_sylvanas.lua"] = true,
    ["EaxRotations/classes/mage/arcane_sylvanas.lua"] = true,
    ["EaxRotations/classes/priest/smite_sylvanas.lua"] = true,
    -- Leveling specs (spec_kit migration 2026-07)
    ["EaxRotations/classes/warrior/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/druid/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/hunter/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/mage/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/paladin/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/priest/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/rogue/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/shaman/leveling_sylvanas.lua"] = true,
    ["EaxRotations/classes/warlock/leveling_sylvanas.lua"] = true,
    -- Non-spec helper modules (uses spec_kit but no strategies/registration)
    ["EaxRotations/classes/druid/healing_sylvanas.lua"] = true,
}

-- Non-spec modules: use spec_kit but are helper modules without strategies/registration.
-- Exempt from rule (b) registration, build_state, and return-shape checks.
local NON_SPEC_MODULES = {
    ["EaxRotations/classes/druid/healing_sylvanas.lua"] = true,
}

local function add_issue(issues, path, rule, detail)
    issues[#issues + 1] = string.format("%s :: %s :: %s", path, rule, detail)
end

local function first_n_lines(text, n)
    local lines = {}
    for ln in text:gmatch("[^\r\n]+") do
        lines[#lines + 1] = ln
        if #lines >= n then break end
    end
    return lines
end

-- Literal string search (plain=true avoids pattern metacharacter issues).
local function has_lit(text, needle)
    return text:find(needle, 1, true) ~= nil
end

local issues = {}
local converted_count = 0
local legacy_count = 0

for _, path in ipairs(spec_files) do
    local text = read_file(path)
    local is_converted = CONVERTED[path] == true

    -- (a) ALL specs: Pattern 15 header -- WHAT and SAFETY keys in first 30 lines.
    local header_lines = first_n_lines(text, 30)
    local has_what, has_safety = false, false
    for _, ln in ipairs(header_lines) do
        if ln:find("WHAT:", 1, true) then has_what = true end
        if ln:find("SAFETY:", 1, true) then has_safety = true end
    end
    if not has_what then
        add_issue(issues, path, "missing-header-WHAT", "Pattern 15 WHAT: key not found in first 30 lines")
    end
    if not has_safety then
        add_issue(issues, path, "missing-header-SAFETY", "Pattern 15 SAFETY: key not found in first 30 lines")
    end

    -- (a2) ALL specs: banned APIs, math.sqrt, bare menu access.
    local all_lines = first_n_lines(text, 9999)
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") then
            if ln:find("ffi%.C", 1) or ln:find("io%.popen", 1) or ln:find("os%.execute", 1) then
                add_issue(issues, path, "banned-api", "banned API (ffi.C / io.popen / os.execute) found in spec")
                break
            end
        end
    end
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") and ln:find("debug%.", 1) then
            add_issue(issues, path, "banned-api-debug", "debug.* usage found in spec (not comment)")
            break
        end
    end
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") and ln:find("math%.sqrt", 1, true) then
            add_issue(issues, path, "math.sqrt", "math.sqrt found in spec — use squared distance (Pattern 3)")
            break
        end
    end
    if not path:find("schema_sylvanas") then
        for _, ln in ipairs(all_lines) do
            if not ln:match("^%-%-") and ln:find("menu%.[a-zA-Z_]+%:get%(", 1) then
                add_issue(issues, path, "bare-menu-access", "bare menu.x:get() found in spec outside schema file")
                break
            end
        end
    end

    -- (b) CONVERTED specs only: canonical mechanical contract.
    if is_converted then
        converted_count = converted_count + 1

        -- spec_kit require present.
        if not (has_lit(text, 'require("shared/spec_kit_sylvanas")') or
                has_lit(text, "require('shared/spec_kit_sylvanas')")) then
            add_issue(issues, path, "converted-missing-spec_kit", "spec_kit require not found")
        end

        -- define_action_for_class usage. Module-style converted specs (plain
        -- spell tables + shared helpers) prove conversion via spec_kit.safe_state
        -- instead; either marker satisfies the mechanical contract.
        if not has_lit(text, "define_action_for_class") and not has_lit(text, "safe_state") then
            add_issue(issues, path, "converted-missing-define_action", "spec_kit.define_action_for_class (or safe_state) not used")
        end

        -- Guarded registration form (nil-safe in unit tests).
        if not NON_SPEC_MODULES[path] and not has_lit(text, "NS.rotation_registry and NS.rotation_registry.register") then
            add_issue(issues, path, "converted-unguarded-registration", "guarded registration form not found")
        end

        -- build_state symbol exists (function definition or aliased in return).
        if not NON_SPEC_MODULES[path] then
        local has_build_state_fn = has_lit(text, "function build_state") or
            text:find("build_state%s*=%s*function", 1) ~= nil
        local has_build_state_alias = text:find("build_state%s*=", 1) ~= nil
        if not (has_build_state_fn or has_build_state_alias) then
            add_issue(issues, path, "converted-missing-build_state", "build_state function or alias not found")
        end
        end

        -- Valid return shape: "return strategies", "return module" (table with
        -- strategies key), or "return { strategies" — all accepted.
        if not NON_SPEC_MODULES[path] and not (has_lit(text, "return strategies") or
                has_lit(text, "return module") or
                text:find("return%s*%{%s*strategies", 1) ~= nil) then
            add_issue(issues, path, "converted-invalid-return", "no return strategies/module/{ strategies found")
        end
    else
        legacy_count = legacy_count + 1
    end
end

-- (c) SHARED + CORE + TOP-LEVEL + CLASS INFRASTRUCTURE files.
-- Dynamically scanned so new files are automatically checked (no hardcoded lists).
local function scan_dir(dir, pattern)
    local files = {}
    local attr = lfs.attributes(dir)
    if attr and attr.mode == "directory" then
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local full = dir .. "/" .. entry
                local fattr = lfs.attributes(full)
                if fattr and fattr.mode == "file" then
                    if not pattern or entry:match(pattern) then
                        files[#files + 1] = full
                    end
                end
            end
        end
    end
    return files
end

local shared_core_files = {}
for _, f in ipairs(scan_dir("EaxRotations", "%.lua$")) do
    shared_core_files[#shared_core_files + 1] = f
end
for _, f in ipairs(scan_dir("EaxRotations/core", "%.lua$")) do
    shared_core_files[#shared_core_files + 1] = f
end
for _, f in ipairs(scan_dir("EaxRotations/shared", "%.lua$")) do
    shared_core_files[#shared_core_files + 1] = f
end

local classes = { "druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior" }
for _, class in ipairs(classes) do
    local dir = "EaxRotations/classes/" .. class
    for _, full in ipairs(scan_dir(dir, "_sylvanas%.lua$")) do
        local filename = full:match("([^/]+)$") or full
        local is_spec = false
        for _, spec_path in ipairs(spec_files) do
            if spec_path == full then is_spec = true; break end
        end
        if not is_spec and not filename:find("_vanilla%.lua$") then
            shared_core_files[#shared_core_files + 1] = full
        end
    end
end

assert(#shared_core_files > 0, "scan_dir returned 0 files — lfs may not be working")

local shared_checked = 0
for _, path in ipairs(shared_core_files) do
    local text = read_file(path)
    shared_checked = shared_checked + 1

    -- Pattern 15 header.
    local header_lines = first_n_lines(text, 30)
    local has_what, has_safety = false, false
    for _, ln in ipairs(header_lines) do
        if ln:find("WHAT:", 1, true) then has_what = true end
        if ln:find("SAFETY:", 1, true) then has_safety = true end
    end
    if not has_what then
        add_issue(issues, path, "missing-header-WHAT", "Pattern 15 WHAT: key not found in first 30 lines")
    end
    if not has_safety then
        add_issue(issues, path, "missing-header-SAFETY", "Pattern 15 SAFETY: key not found in first 30 lines")
    end

    -- Banned APIs (ffi.C, io.popen, os.execute, debug.*).
    -- Skip comment lines; only flag executable code.
    local all_lines = first_n_lines(text, 9999)
    local has_banned_api = false
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") then
            if ln:find("ffi%.C", 1) or ln:find("io%.popen", 1) or ln:find("os%.execute", 1) then
                has_banned_api = true
                break
            end
        end
    end
    if has_banned_api then
        add_issue(issues, path, "banned-api", "banned API (ffi.C / io.popen / os.execute) found in code")
    end
    -- debug.* is allowed in comments, but not in executable code.
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") and ln:find("debug%.", 1) then
            add_issue(issues, path, "banned-api-debug", "debug.* usage found in code (not comment)")
            break
        end
    end

    -- math.sqrt.
    local has_math_sqrt = false
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") and ln:find("math%.sqrt", 1, true) then
            has_math_sqrt = true
            break
        end
    end
    if has_math_sqrt then
        add_issue(issues, path, "math.sqrt", "math.sqrt found in code — use squared distance (Pattern 3)")
    end

    -- Bare menu access outside schema files.
    if not path:find("schema_sylvanas") then
        local has_bare_menu = false
        for _, ln in ipairs(all_lines) do
            if not ln:match("^%-%-") and ln:find("menu%.[a-zA-Z_]+%:get%(", 1) then
                has_bare_menu = true
                break
            end
        end
        if has_bare_menu then
            add_issue(issues, path, "bare-menu-access", "bare menu.x:get() found in code outside schema file")
        end
    end

    -- Core file caching (Phase 2 item): main_sylvanas.lua and core_sylvanas.lua should have load-time _core / core = _G.core cache (Pattern 2).
    if path:find("EaxRotations/main_sylvanas%.lua$") or path:find("EaxRotations/core_sylvanas%.lua$") then
        if not has_lit(text, "_core = _G.core") and not has_lit(text, "core = _G.core") then
            add_issue(issues, path, "core-missing-load-cache", "core/main file missing _core = _G.core or core = _G.core load cache (Pattern 2)")
        end
    end
end

-- (d) VANILLA spec files: Pattern 15 header + banned API checks.
local vanilla_files = {}
for _, class in ipairs(classes) do
    local dir = "EaxRotations/classes/" .. class
    for _, full in ipairs(scan_dir(dir, "_vanilla%.lua$")) do
        vanilla_files[#vanilla_files + 1] = full
    end
end

assert(#vanilla_files > 0, "vanilla scan returned 0 files")

local vanilla_checked = 0
for _, path in ipairs(vanilla_files) do
    local text = read_file(path)
    vanilla_checked = vanilla_checked + 1

    local header_lines = first_n_lines(text, 30)
    local has_what, has_safety = false, false
    for _, ln in ipairs(header_lines) do
        if ln:find("WHAT:", 1, true) then has_what = true end
        if ln:find("SAFETY:", 1, true) then has_safety = true end
    end
    if not has_what then
        add_issue(issues, path, "missing-header-WHAT", "Pattern 15 WHAT: key not found in first 30 lines")
    end
    if not has_safety then
        add_issue(issues, path, "missing-header-SAFETY", "Pattern 15 SAFETY: key not found in first 30 lines")
    end

    local all_lines = first_n_lines(text, 9999)
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") then
            if ln:find("ffi%.C", 1) or ln:find("io%.popen", 1) or ln:find("os%.execute", 1) then
                add_issue(issues, path, "banned-api", "banned API found in vanilla file")
                break
            end
        end
    end
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") and ln:find("debug%.", 1) then
            add_issue(issues, path, "banned-api-debug", "debug.* usage found in vanilla file")
            break
        end
    end
    for _, ln in ipairs(all_lines) do
        if not ln:match("^%-%-") and ln:find("math%.sqrt", 1, true) then
            add_issue(issues, path, "math.sqrt", "math.sqrt found in vanilla file")
            break
        end
    end
end

-- (e) Test file registration check: every test_*.lua in EaxRotations/tests/
-- must be listed in run_rotation_tests.lua or run_leveling_tests.lua.
local runner_text = read_file("EaxRotations/tests/run_rotation_tests.lua")
local leveling_runner_text = read_file("EaxRotations/tests/run_leveling_tests.lua")
local test_dir_files = {}
for _, full in ipairs(scan_dir("EaxRotations/tests", "^test_[^/]+%.lua$")) do
    local filename = full:match("([^/]+)$") or full
    test_dir_files[filename] = true
end

local runner_missing = {}
for filename, _ in pairs(test_dir_files) do
    if filename ~= "test_runner_lib.lua"
        and not has_lit(runner_text, filename)
        and not has_lit(leveling_runner_text, filename) then
        runner_missing[#runner_missing + 1] = filename
    end
end

if #runner_missing > 0 then
    table.sort(runner_missing)
    add_issue(issues, "EaxRotations/tests/run_rotation_tests.lua", "unregistered-test-files",
        "test files not registered in runner: " .. table.concat(runner_missing, ", "))
end

-- (f) ALL .lua files in tests/: banned-API scan (close self-exemption loophole).
-- Exempts runners and the enforcer itself (contains search patterns, not calls).
local function scan_tests_for_banned(pattern)
    local found = {}
    for _, full in ipairs(scan_dir("EaxRotations/tests", "%.lua$")) do
        local filename = full:match("([^/]+)$") or full
        if filename == "test_spec_layout_compliance.lua" then
            -- skip self (contains search patterns)
        elseif filename:match("^run_.*%.lua$") or filename == "test_runner_lib.lua" then
            -- skip runners
        else
            local text = read_file(full)
            for _, ln in ipairs(first_n_lines(text, 9999)) do
                if not ln:match("^%-%-") then
                    if ln:find(pattern, 1) then
                        found[#found + 1] = filename
                        break
                    end
                end
            end
        end
    end
    return found
end

local test_banned_ffi = scan_tests_for_banned("ffi%.C%(")
local test_banned_popen = scan_tests_for_banned("io%.popen%(")
local test_banned_exec = scan_tests_for_banned("os%.execute%(")
local test_banned_found = {}
for _, v in ipairs(test_banned_ffi) do test_banned_found[#test_banned_found + 1] = v end
for _, v in ipairs(test_banned_popen) do test_banned_found[#test_banned_found + 1] = v end
for _, v in ipairs(test_banned_exec) do test_banned_found[#test_banned_found + 1] = v end
local test_debug_found = scan_tests_for_banned("debug%.%w+%(")
local test_math_sqrt_found = scan_tests_for_banned("math%.sqrt%(")

if #test_banned_found > 0 then
    table.sort(test_banned_found)
    add_issue(issues, "EaxRotations/tests/", "banned-api-in-test",
        "banned API (ffi.C / io.popen / os.execute) found in test files: " .. table.concat(test_banned_found, ", "))
end
if #test_debug_found > 0 then
    table.sort(test_debug_found)
    add_issue(issues, "EaxRotations/tests/", "banned-api-debug-in-test",
        "debug.* usage found in test files: " .. table.concat(test_debug_found, ", "))
end
if #test_math_sqrt_found > 0 then
    table.sort(test_math_sqrt_found)
    add_issue(issues, "EaxRotations/tests/", "math.sqrt-in-test",
        "math.sqrt found in test files — use squared distance: " .. table.concat(test_math_sqrt_found, ", "))
end

-- (g) Leveling test registration check: every test_*leveling*.lua in EaxRotations/tests/
-- must be listed in run_leveling_tests.lua.
local leveling_runner_text = read_file("EaxRotations/tests/run_leveling_tests.lua")
local leveling_dir_files = {}
for _, full in ipairs(scan_dir("EaxRotations/tests", "^test_[^/]*leveling[^/]*%.lua$")) do
    local filename = full:match("([^/]+)$") or full
    leveling_dir_files[filename] = true
end

local leveling_missing = {}
for filename, _ in pairs(leveling_dir_files) do
    if not has_lit(leveling_runner_text, filename) then
        leveling_missing[#leveling_missing + 1] = filename
    end
end

if #leveling_missing > 0 then
    table.sort(leveling_missing)
    add_issue(issues, "EaxRotations/tests/run_leveling_tests.lua", "unregistered-leveling-test-files",
        "leveling test files not registered in runner: " .. table.concat(leveling_missing, ", "))
end

if #issues > 0 then
    local issues_str = table.concat(issues, "; ")
    print("spec layout compliance issues: " .. issues_str)
    error("spec layout compliance failed: " .. issues_str, 0)
end

print(string.format("PASS test_spec_layout_compliance (%d converted, %d legacy, %d shared/core, %d vanilla)", converted_count, legacy_count, shared_checked, vanilla_checked))