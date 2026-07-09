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

local lfs = require("lfs")
assert(lfs, "lfs (LuaFileSystem) is required for cross-platform directory scanning")

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

    -- (b) CONVERTED specs only: canonical mechanical contract.
    if is_converted then
        converted_count = converted_count + 1

        -- spec_kit require present.
        if not (has_lit(text, 'require("shared/spec_kit_sylvanas")') or
                has_lit(text, "require('shared/spec_kit_sylvanas')")) then
            add_issue(issues, path, "converted-missing-spec_kit", "spec_kit require not found")
        end

        -- define_action_for_class usage.
        if not has_lit(text, "define_action_for_class") then
            add_issue(issues, path, "converted-missing-define_action", "spec_kit.define_action_for_class not used")
        end

        -- Guarded registration form (nil-safe in unit tests).
        if not has_lit(text, "NS.rotation_registry and NS.rotation_registry.register") then
            add_issue(issues, path, "converted-unguarded-registration", "guarded registration form not found")
        end

        -- build_state symbol exists (function definition or aliased in return).
        local has_build_state_fn = has_lit(text, "function build_state") or
            text:find("build_state%s*=%s*function", 1) ~= nil
        local has_build_state_alias = text:find("build_state%s*=", 1) ~= nil
        if not (has_build_state_fn or has_build_state_alias) then
            add_issue(issues, path, "converted-missing-build_state", "build_state function or alias not found")
        end

        -- Valid return shape: "return strategies", "return module" (table with
        -- strategies key), or "return { strategies" — all accepted.
        if not (has_lit(text, "return strategies") or
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
-- must be listed in run_rotation_tests.lua (excluding the runner itself).
local runner_text = read_file("EaxRotations/tests/run_rotation_tests.lua")
local test_dir_files = {}
for _, full in ipairs(scan_dir("EaxRotations/tests", "^test_[^_]+%.lua$")) do
    local filename = full:match("([^/]+)$") or full
    test_dir_files[filename] = true
end

local runner_missing = {}
for filename, _ in pairs(test_dir_files) do
    if filename ~= "test_runner_lib.lua" and not has_lit(runner_text, filename) then
        runner_missing[#runner_missing + 1] = filename
    end
end

if #runner_missing > 0 then
    table.sort(runner_missing)
    add_issue(issues, "EaxRotations/tests/run_rotation_tests.lua", "unregistered-test-files",
        "test files not registered in runner: " .. table.concat(runner_missing, ", "))
end

-- (f) Test files: banned-API scan (close self-exemption loophole).
local test_banned_found = {}
for _, full in ipairs(scan_dir("EaxRotations/tests", "%.lua$")) do
    local text = read_file(full)
    local filename = full:match("([^/]+)$") or full
    if filename ~= "test_runner_lib.lua" then
        for _, ln in ipairs(first_n_lines(text, 9999)) do
        if not ln:match("^%-%-") then
            -- Flag actual calls, not references inside string literals.
            if ln:find("ffi%.C%(", 1) or ln:find("io%.popen%(", 1) or ln:find("os%.execute%(", 1) then
                    test_banned_found[#test_banned_found + 1] = filename
                    break
                end
            end
        end
    end
end
if #test_banned_found > 0 then
    table.sort(test_banned_found)
    add_issue(issues, "EaxRotations/tests/", "banned-api-in-test",
        "banned API (ffi.C / io.popen / os.execute) found in test files: " .. table.concat(test_banned_found, ", "))
end

if #issues > 0 then
    error("spec layout compliance failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print(string.format("PASS test_spec_layout_compliance (%d converted, %d legacy, %d shared/core, %d vanilla)", converted_count, legacy_count, shared_checked, vanilla_checked))