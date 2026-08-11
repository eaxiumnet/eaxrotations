-- test_sod_class_loader_integration.lua -- real nine-class SoD loader coverage.
-- WHAT: loads every production class loader and its manifest-listed SoD modules.
-- WHEN: run with the rotation suite or as a focused loader integration test.
-- WHY: proves class wiring reaches real modules instead of synthetic require results.
-- SAFETY: only the Sylvanas engine boundary is stubbed; duplicate/missing probes are isolated.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local function assert_true(value, label)
    if not value then error(label or "assert_true failed", 2) end
end

local classes = {
    { key = "druid", id = 11 },
    { key = "hunter", id = 3 },
    { key = "mage", id = 8 },
    { key = "paladin", id = 2 },
    { key = "priest", id = 5 },
    { key = "rogue", id = 4 },
    { key = "shaman", id = 7 },
    { key = "warlock", id = 9 },
    { key = "warrior", id = 1 },
}
local class_ids = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}

local original_ns = _G.EaxRotations
local original_require = require
local loader
local total = 0
local seen = {}

local function clear_modules(class_key, entries)
    package.loaded["classes/" .. class_key .. "/class_sylvanas"] = nil
    for _, entry in ipairs(entries) do
        package.loaded["classes/" .. class_key .. "/" .. entry.module] = nil
    end
end

local function make_registry()
    local registry = { playstyles = {}, options = {}, registered = {}, class_config = nil }
    function registry:set_class_config(config)
        self.class_config = config
    end
    function registry:register(name, strategies, options)
        assert_true(self.registered[name] == nil, "real loader registered duplicate key " .. tostring(name))
        self.registered[name] = { strategies = strategies, options = options }
        self.playstyles[name] = strategies
        self.options[name] = options
    end
    return registry
end

local function make_spell_action(definition, label)
    local ids = type(definition) == "table" and definition.ids or definition
    if type(ids) ~= "table" then ids = { ids } end
    local spell = {
        [1] = ids[1],
        _meta = { id = ids, ids = ids, label = (type(definition) == "table" and definition.name) or label },
    }
    function spell:id() return self._meta.ids[1] end
    return spell
end

local function load_real_class(class_info)
    local entries = loader.SOD_MANIFEST[class_info.key]
    local registry = make_registry()
    local player = { get_class = function() return class_info.id end }
    _G.EaxRotations = {
        CLASS_ID = class_ids,
        is_sod = function() return true end,
        GetPlayer = function() return player end,
        spell_action = make_spell_action,
        spell_ready = function() return false end,
        try_cast = function() return false end,
        register_class_middleware = function() end,
        PLAYER_UNIT = "player",
        rotation_registry = registry,
        log = function() end,
        log_warning = function() end,
    }

    clear_modules(class_info.key, entries)
    local ok, config = pcall(require, "classes/" .. class_info.key .. "/class_sylvanas")
    assert_true(ok, "real " .. class_info.key .. " class loader failed: " .. tostring(config))
    assert_true(type(config) == "table", "real " .. class_info.key .. " loader returned no config")
    assert_eq(#config.playstyles, #entries, class_info.key .. " manifest playstyle count")

    for _, entry in ipairs(entries) do
        assert_true(registry.registered[entry.key] ~= nil,
            class_info.key .. " missing real registration " .. entry.key)
        seen[entry.key] = (seen[entry.key] or 0) + 1
        total = total + 1
    end
    return registry
end

_G.EaxRotations = { CLASS_ID = class_ids, log_warning = function() end }
package.loaded["shared/class_loader_sylvanas"] = nil
loader = require("shared/class_loader_sylvanas")

for _, class_info in ipairs(classes) do
    load_real_class(class_info)
end

assert_eq(total, 20, "real SoD loader entry count")
for key, count in pairs(seen) do
    assert_eq(count, 1, "real SoD registration count for " .. key)
end

local registry = make_registry()
_G.EaxRotations = {
    is_sod = function() return true end,
    rotation_registry = registry,
    log_warning = function() end,
}
local module_path = "classes/hunter/dps_hunter_sod"
local original_register = registry.register

local function assert_loader_failure(mode, expected_fragment)
    require = function(path)
        if path == module_path then
            if mode == "duplicate" then
                registry:register("duplicate", {}, {})
                registry:register("duplicate", {}, {})
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
    assert_true(registry.register == original_register, mode .. " must restore registry.register")
end

assert_loader_failure("duplicate", "registered more than once")
assert_loader_failure("missing", "registered no playstyle")

require = original_require
_G.EaxRotations = original_ns
print("PASS test_sod_class_loader_integration (9 real class loaders, 20 real SoD entries, duplicate/missing negatives)")
