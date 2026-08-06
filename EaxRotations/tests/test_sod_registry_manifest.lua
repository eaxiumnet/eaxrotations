-- test_sod_registry_manifest.lua -- SoD registry manifest and loader contract tests.
-- WHAT: checks exact class/entry enumeration and per-module registration cardinality.
-- WHEN: run during the rotation suite and as a focused loader validation.
-- WHY: prevents duplicate, missing, or mis-keyed SoD registrations from reaching dispatch.
-- SAFETY: deterministic require/registry doubles; no game API or persistent state.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2) end
end
local function assert_true(value, label)
    if not value then error(label or "assert_true failed", 2) end
end

_G.EaxRotations = { log_warning = function() end }
package.loaded["shared/class_loader_sylvanas"] = nil
local loader = require("shared/class_loader_sylvanas")

local manifest = assert(loader.SOD_MANIFEST, "production SoD manifest is missing")
local classes = { "druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior" }
local seen = {}
local total = 0
for _, class_key in ipairs(classes) do
    local entries = assert(manifest[class_key], "missing SoD class " .. class_key)
    assert_true(#entries > 0, "empty SoD class " .. class_key)
    for _, entry in ipairs(entries) do
        assert_true(type(entry.key) == "string" and entry.key ~= "", "missing SoD key")
        assert_true(not seen[entry.key], "duplicate SoD registry key " .. entry.key)
        seen[entry.key] = true
        total = total + 1
    end
end
assert_eq(total, 20, "SoD registry entry count")
assert_eq(loader.sod_class_count(), 9, "SoD class count")

local registered = {}
local registry = {
    register = function(self, name, strategies, options)
        registered[name] = { strategies = strategies, options = options }
    end,
}
_G.EaxRotations.rotation_registry = registry
local original_require = require
require = function(path)
    if path:match("^classes/") then
        _G.EaxRotations.rotation_registry:register("raw", {}, { get_state = function() return {} end })
        return { strategies = {}, build_state = function() return {} end }
    end
    return original_require(path)
end
for _, class_key in ipairs(classes) do
    local loaded = loader.load_sod_specs(class_key, class_key)
    assert_eq(loaded, #manifest[class_key], "loaded entry count for " .. class_key)
end
require = original_require
local registered_count = 0
for _ in pairs(registered) do registered_count = registered_count + 1 end
assert_eq(registered_count, 20, "registered SoD entry count")
for key in pairs(seen) do assert_true(registered[key] ~= nil, "missing registered SoD key " .. key) end

local original_register = registry.register
local function assert_loader_failure(mode, expected_fragment)
    local module_path = "classes/hunter/dps_hunter_sod"
    require = function(path)
        if path == module_path then
            if mode == "duplicate" then
                _G.EaxRotations.rotation_registry:register("raw", {}, {})
                _G.EaxRotations.rotation_registry:register("raw", {}, {})
            end
            return { strategies = {} }
        end
        return original_require(path)
    end
    local ok, err = pcall(loader.load_sod_specs, "hunter", "Hunter")
    require = original_require
    assert_true(not ok, mode .. " registration must fail")
    assert_true(tostring(err):match(expected_fragment) ~= nil,
        mode .. " failure should identify the registration contract: " .. tostring(err))
    assert_true(registry.register == original_register, mode .. " failure must restore registry.register")
end

assert_loader_failure("duplicate", "registered more than once")
assert_loader_failure("missing", "registered no playstyle")

_G.EaxRotations = nil
print("PASS test_sod_registry_manifest (9 classes, 20 unique entries, loader dispatch)")
