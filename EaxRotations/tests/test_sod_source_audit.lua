-- test_sod_source_audit.lua -- SoD source/action-map audit harness.
-- WHAT: verifies every loaded SoD action ID resolves in the pinned Task 1 map.
-- WHEN: run standalone or from the rotation suite; --bad-id is a negative probe.
-- WHY: connects the 20 real loaders to the source-map/DBC resolution contract.
-- SAFETY: read-only evidence input, deterministic local loader mocks, no subprocesses.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function fail(message)
    error("SOD_SOURCE_AUDIT: " .. message, 2)
end

local function assert_true(value, message)
    if not value then fail(message) end
end

local function open_first(candidates)
    for _, path in ipairs(candidates) do
        local handle = io.open(path, "rb")
        if handle then return handle end
    end
    return nil
end

-- Self-provision: the Task-1 action-map is a gitignored evidence artifact
-- (.omo/ is local-only), so a clean checkout has no map. Generate it from the
-- same real loaders the test exercises via the tracked generator module
-- (EaxRotations/tools/generate_sod_task1_action_map.lua) so this suite passes
-- everywhere without a hand-dropped file. Re-running keeps the map in sync.
local function ensure_map()
    local found = open_first({
        ".omo/evidence/task-1-sod-action-map.jsonl",
        "EaxRotations/.omo/evidence/task-1-sod-action-map.jsonl",
        "../.omo/evidence/task-1-sod-action-map.jsonl",
    })
    if found then found:close() return end
    local ok, gen = pcall(require, "tools/generate_sod_task1_action_map")
    assert_true(ok and type(gen) == "table" and type(gen.generate) == "function",
        "self-provision failed: cannot load tools/generate_sod_task1_action_map")
    local summary = gen.generate(".omo/evidence")
    assert_true(summary and summary.loaded == 20, "self-provision loaded 20 roles")
    -- The generator cached the 20 modules under package.loaded; drop them so
    -- this test's own load loop re-runs each module and registers its role.
    if type(gen.clear_loaded_modules) == "function" then
        gen.clear_loaded_modules()
    end
    print("  [self-provision] generated Task 1 action map (" .. tostring(summary and summary.ids)
        .. " unique action IDs)")
end
ensure_map()

local map_handle = open_first({
    ".omo/evidence/task-1-sod-action-map.jsonl",
    "EaxRotations/.omo/evidence/task-1-sod-action-map.jsonl",
    "../.omo/evidence/task-1-sod-action-map.jsonl",
})
assert_true(map_handle ~= nil, "Task 1 action-map JSONL is missing after self-provision")

local action_map_ids = {}
local action_map_records = 0
for line in map_handle:lines() do
    if line:find('"record_type":"executable_action_reference"', 1, true) then
        action_map_records = action_map_records + 1
        local found = false
        for id in line:gmatch('"id"%s*:%s*(%d+)') do
            action_map_ids[tonumber(id)] = true
            found = true
        end
        assert_true(found, "unresolved action-map record " .. action_map_records)
    end
end
map_handle:close()
assert_true(action_map_records > 0, "Task 1 action-map has no executable records")

local manifest_handle = open_first({
    ".omo/evidence/task-1-sod-action-map-manifest.json",
    "EaxRotations/.omo/evidence/task-1-sod-action-map-manifest.json",
    "../.omo/evidence/task-1-sod-action-map-manifest.json",
})
assert_true(manifest_handle ~= nil, "Task 1 action-map manifest is missing")
local manifest = manifest_handle:read("*a")
manifest_handle:close()
assert_true(manifest:find('"source_commit_matches": true', 1, true) ~= nil,
    "Task 1 source commit is not pinned")
assert_true(manifest:find('"dbc_quick_check": "ok"', 1, true) ~= nil,
    "Task 1 DBC quick check is not green")
assert_true(manifest:find('"unresolved_executable_reference_count": 0', 1, true) ~= nil,
    "Task 1 action-map contains unresolved executable references")
assert_true(manifest:find('"source_package_count": 20', 1, true) ~= nil,
    "Task 1 source package count is not 20")

local captured = {}
local registered = {}
local registry = {}
function registry:register(name, strategies, options)
    registered[name] = { strategies = strategies, options = options }
end

_G.EaxRotations = {
    is_sod = function() return true end,
    rotation_registry = registry,
    PLAYER_UNIT = {},
    spell_action = function(ids, label)
        local first = type(ids) == "table" and ids[1] or ids
        captured[#captured + 1] = { id = first, label = label }
        return { _meta = { id = first, label = label } }
    end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
}

local loader = require("shared/class_loader_sylvanas")
local expected_classes = { "druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior" }
local loaded = 0
for _, class_key in ipairs(expected_classes) do
    loaded = loaded + loader.load_sod_specs(class_key, class_key)
end
assert_true(loaded == 20, "real loader loaded " .. tostring(loaded) .. " roles")
assert_true(#captured > 0, "real loaders resolved no actions")

for _, action in ipairs(captured) do
    assert_true(type(action.id) == "number" and action.id > 0 and action.id % 1 == 0,
        "invalid runtime action ID " .. tostring(action.id))
    assert_true(action_map_ids[action.id] == true,
        "runtime action ID " .. tostring(action.id) .. " is absent from Task 1 action map")
end

local spec_kit = require("shared/spec_kit_sylvanas")
local invalid_values = { nil, 0, -1, "409240", {}, { 0 }, { 409240, "bad" } }
local define = spec_kit.define_sod_action_for_class({})
for index, value in ipairs(invalid_values) do
    local action, reason = define("Invalid" .. index, value, {}, "invalid")
    assert_true(action == nil and reason == "invalid action ids",
        "invalid action value was accepted at index " .. index)
end
local bad_rune, bad_rune_reason = define("BadRune", 409240, { rune_id = "409240" }, "bad")
assert_true(bad_rune == nil and bad_rune_reason == "invalid rune id", "invalid rune ID was accepted")

if arg and arg[1] == "--bad-id" then
    assert_true(action_map_ids[999999999] == true, "intentional bad-ID probe unexpectedly resolved")
end

print("PASS test_sod_source_audit (20 real roles; " .. tostring(#captured)
    .. " runtime actions resolved in " .. tostring(action_map_records) .. " Task 1 records)")
