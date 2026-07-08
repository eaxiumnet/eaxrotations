-- What: Unit tests for static_popup_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify dungeon proposal and battlefield port auto-accept

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- S1: no dungeon proposal → returns nil, no accept called
package.loaded["EaxAutoQuester/static_popup_sylvanas"] = nil
do
    mock._dungeon_proposal = false
    local sp = require("EaxAutoQuester/static_popup_sylvanas")
    local result = sp.handle_any_popup()
    assert(result == nil, "S1 FAIL: no proposal should return nil, got " .. tostring(result))
    -- Verify accept_dungeon_proposal was NOT called
    local found = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "accept_dungeon_proposal" then found = true end
    end
    assert(not found, "S1 FAIL: accept_dungeon_proposal should NOT be called")
    print("  S1 PASS: no proposal → nil, no action")
end

-- S2: dungeon proposal active → auto-accepts
package.loaded["EaxAutoQuester/static_popup_sylvanas"] = nil
mock.reset()
mock.set_time(10.0)
do
    mock._dungeon_proposal = true
    local sp = require("EaxAutoQuester/static_popup_sylvanas")
    local result = sp.handle_any_popup()
    assert(result == "dungeon_accepted", "S2 FAIL: proposal should be accepted, got " .. tostring(result))
    local found = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "accept_dungeon_proposal" and call[2] == true then found = true end
    end
    assert(found, "S2 FAIL: accept_dungeon_proposal(true) should be called")
    print("  S2 PASS: dungeon proposal → auto-accepted")
end

-- S3: battlefield port confirm → auto-accepts
package.loaded["EaxAutoQuester/static_popup_sylvanas"] = nil
mock.reset()
mock.set_time(10.0)
do
    mock._battlefield_status = { [1] = "confirm", [2] = "none", [3] = "none" }
    local sp = require("EaxAutoQuester/static_popup_sylvanas")
    local result = sp.handle_any_popup()
    assert(result == "battlefield_accepted", "S3 FAIL: battlefield port should be accepted, got " .. tostring(result))
    local found = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "accept_battlefield_port" and call[2] == 1 and call[3] == true then found = true end
    end
    assert(found, "S3 FAIL: accept_battlefield_port(1, true) should be called")
    print("  S3 PASS: battlefield confirm → auto-accepted")
end

-- S4: throttle — second call within interval should not re-trigger
package.loaded["EaxAutoQuester/static_popup_sylvanas"] = nil
mock.reset()
mock.set_time(10.0)
do
    mock._dungeon_proposal = true
    local sp = require("EaxAutoQuester/static_popup_sylvanas")
    local r1 = sp.handle_any_popup()
    assert(r1 == "dungeon_accepted", "S4a FAIL: first call should accept")
    mock._input_calls = {}  -- clear calls
    local r2 = sp.handle_dungeon_proposal()
    assert(r2 == false, "S4b FAIL: throttled call should return false, got " .. tostring(r2))
    print("  S4 PASS: throttled → no duplicate accept")
end

print("PASS test_static_popup")
os.exit(0)
