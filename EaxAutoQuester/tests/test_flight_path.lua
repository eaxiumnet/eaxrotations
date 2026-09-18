-- test_flight_path.lua — Unit tests for flight_path_sylvanas

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
-- S1: extract_destination
-- ============================================================================
local fp = require("EaxAutoQuester/flight_path_sylvanas")
assert(fp.extract_destination("Fly to Thunder Bluff") == "Thunder Bluff", "S1a FAIL")
assert(fp.extract_destination("Take the flight path to Orgrimmar.") == "Orgrimmar", "S1b FAIL")
assert(fp.extract_destination("Get the flight path to Crossroads") == "Crossroads", "S1c FAIL")
assert(fp.extract_destination("Kill 10 boars") == nil, "S1d FAIL: non-flight step should return nil")
print("  S1 PASS: extract_destination works")

-- ============================================================================
-- S2: is_flight_master_gossip — by NPC name
-- ============================================================================
mock.reset()
set_gossip({})
assert(fp.is_flight_master_gossip("Doras the Wind Rider Master") == true, "S2a FAIL")
assert(fp.is_flight_master_gossip("Innkeeper Pala") == false, "S2b FAIL")
print("  S2 PASS: is_flight_master_gossip by name")

-- ============================================================================
-- S3: find_gossip_option_for_destination
-- ============================================================================
mock.reset()
set_gossip({
    { name = "I would like to browse your goods.", gossip_option_id = 1, gossip_type = "vendor" },
    { name = "Thunder Bluff", gossip_option_id = 2, gossip_type = "flight" },
    { name = "Orgrimmar", gossip_option_id = 3, gossip_type = "flight" },
})
local opt_id = fp.find_gossip_option_for_destination("Thunder Bluff")
assert(opt_id == 2, "S3a FAIL: expected 2, got " .. tostring(opt_id))

opt_id = fp.find_gossip_option_for_destination("Orgrimmar")
assert(opt_id == 3, "S3b FAIL: expected 3, got " .. tostring(opt_id))

opt_id = fp.find_gossip_option_for_destination("Crossroads")
assert(opt_id == nil, "S3c FAIL: no match should return nil")
print("  S3 PASS: find_gossip_option_for_destination")

-- ============================================================================
-- S4: select_flight_destination
-- ============================================================================
mock.reset()
mock.set_time(10.0)
set_gossip({
    { name = "Thunder Bluff", gossip_option_id = 5 },
})
local selected = fp.select_flight_destination("Thunder Bluff")
assert(selected == true, "S4a FAIL: should select")
local found = false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "select_gossip_option" and call[2] == 5 then found = true end
end
assert(found, "S4b FAIL: select_gossip_option(5) should be called")
print("  S4 PASS: select_flight_destination")

-- ============================================================================
-- S5: handle_flight_gossip — full flow
-- ============================================================================
mock.reset()
mock.set_time(10.0)
set_gossip({
    { name = "Orgrimmar", gossip_option_id = 7 },
})
local result = fp.handle_flight_gossip("Fly to Orgrimmar", "Doras the Wind Rider Master")
assert(result == "flight_selected", "S5 FAIL: expected flight_selected, got " .. tostring(result))
print("  S5 PASS: handle_flight_gossip")

-- ============================================================================
-- S6: step_requires_flight
-- ============================================================================
assert(fp.step_requires_flight("Fly to Orgrimmar") == true, "S6a FAIL")
assert(fp.step_requires_flight("Kill 10 boars") == false, "S6b FAIL")
print("  S6 PASS: step_requires_flight")

print("PASS test_flight_path")
os.exit(0)
