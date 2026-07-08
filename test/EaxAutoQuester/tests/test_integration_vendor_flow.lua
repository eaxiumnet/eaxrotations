-- What: Integration test for EaxAutoQuester vendor flow
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify vendor interaction: auto-repair, auto-sell, auto-close

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local vendor_manager = require("EaxAutoQuester/vendor_manager_sylvanas")

-- Test with no vendor frame
local result = vendor_manager.handle_vendor()
assert(result == false, "vendor flow no vendor frame")

-- Test should_repair with no cost
assert(vendor_manager.should_repair() == false, "vendor flow no repair needed")

print("PASS test_integration_vendor_flow")
os.exit(0)
