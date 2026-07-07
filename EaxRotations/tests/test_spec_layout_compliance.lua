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

        -- build_state symbol exists (function definition).
        if not (has_lit(text, "function build_state") or
                text:find("build_state%s*=%s*function", 1) ~= nil) then
            add_issue(issues, path, "converted-missing-build_state", "build_state function not found")
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

if #issues > 0 then
    error("spec layout compliance failed:\n- " .. table.concat(issues, "\n- "), 0)
end

print(string.format("PASS test_spec_layout_compliance (%d converted, %d legacy)", converted_count, legacy_count))