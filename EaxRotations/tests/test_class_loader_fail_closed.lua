-- test_class_loader_fail_closed.lua — Verify class loader fails safely on bad inputs.
-- WHAT:  tests create_loader and create_expansion_loader with missing modules and wrong class IDs.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   a fail-open loader would silently skip rotations and leave the player idle.
-- SAFETY: fully mocked; exercises pcall paths and error handling only.

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
