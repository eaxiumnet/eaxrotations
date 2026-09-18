-- test_service_gossip.lua — Unit tests for service_gossip_sylvanas

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ============================================================================
-- Helpers
-- ============================================================================

local function set_gossip(options)
    mock._frames.gossip = true
    mock._gossip_options = options or {}
end

-- ============================================================================
-- S1: step_requires_hearth
-- ============================================================================
local sg = require("EaxAutoQuester/service_gossip_sylvanas")
assert(sg.step_requires_hearth("Set your Hearthstone to Goldshire") == true, "S1a FAIL")
assert(sg.step_requires_hearth("Set Hearth to Stormwind") == true, "S1b FAIL")
assert(sg.step_requires_hearth("Make this inn your home") == true, "S1c FAIL")
assert(sg.step_requires_hearth("Kill 10 boars") == false, "S1d FAIL")
print("  S1 PASS: step_requires_hearth")

-- ============================================================================
-- S2: find_service_option — inn
-- ============================================================================
set_gossip({
    { name = "I would like to browse your goods.", gossip_option_id = 1 },
    { name = "Make this inn your home", gossip_option_id = 2 },
})
local opt_id = sg.find_service_option(mock._gossip_options, {"inn"})
assert(opt_id == 2, "S2a FAIL: expected 2, got " .. tostring(opt_id))

-- No bank option → nil
opt_id = sg.find_service_option(mock._gossip_options, {"bank"})
assert(opt_id == nil, "S2b FAIL: no bank option should return nil")
print("  S2 PASS: find_service_option")

-- ============================================================================
-- S3: handle_service_gossip — inn
-- ============================================================================
mock.reset()
mock.set_time(10.0)
set_gossip({
    { name = "Make this inn your home", gossip_option_id = 5 },
})
local result = sg.handle_service_gossip("Set your Hearthstone to Goldshire")
assert(result == "service:inn", "S3a FAIL: expected service:inn, got " .. tostring(result))
local found = false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "select_gossip_option" and call[2] == 5 then found = true end
end
assert(found, "S3b FAIL: select_gossip_option(5) should be called")
print("  S3 PASS: handle_service_gossip inn")

-- ============================================================================
-- S4: handle_service_gossip — no match
-- ============================================================================
mock.reset()
mock.set_time(10.0)
set_gossip({
    { name = "I would like to browse your goods.", gossip_option_id = 1 },
})
result = sg.handle_service_gossip("Set your Hearthstone to Goldshire")
assert(result == nil, "S4 FAIL: no inn option should return nil")
print("  S4 PASS: no match → nil")

-- ============================================================================
-- S5: handle_service_gossip — no step text, no wanted services
-- ============================================================================
mock.reset()
mock.set_time(10.0)
set_gossip({
    { name = "Make this inn your home", gossip_option_id = 5 },
})
result = sg.handle_service_gossip(nil)
assert(result == nil, "S5 FAIL: no wanted services → nil")
print("  S5 PASS: no wanted services → nil")

print("PASS test_service_gossip")
os.exit(0)
