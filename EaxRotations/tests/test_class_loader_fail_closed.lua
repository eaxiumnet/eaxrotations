-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_class_loader_fail_closed.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

_G.EaxRotations = {
    log_warning = function(...) end,
    log = function(...) end,
    log_error = function(...) end,
}

local loader = require("shared/class_loader_sylvanas")

local load_fn = loader.create_loader("nonexistent", "NonExistent")

local ok, err = pcall(function()
    load_fn("this_module_does_not_exist")
end)

assert_true(not ok, "Missing required module must hard-fail. Expected error thrown, got success with result=" .. tostring(ok))
assert_true(err ~= nil, "Error message must not be nil")

local ok2, result2 = pcall(function()
    return load_fn("this_module_does_not_exist", true)
end)

assert_true(ok2, "Missing optional module should return nil without error, but got error=" .. tostring(result2))
assert_true(result2 == nil, "Optional missing module should return nil")

_G.EaxRotations = nil
print("PASS test_class_loader_fail_closed")
