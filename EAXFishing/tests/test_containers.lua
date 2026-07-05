-- test_containers.lua — Unit tests for the container opening module.
-- Validates the container detection and opening logic.

local Containers = require("fishing/containers")

local assertions = 0
local failures = 0

local function CHECK(cond, msg)
    assertions = assertions + 1
    if not cond then
        failures = failures + 1
        print("  FAIL: " .. msg)
    end
end

-- TC1: module exposes expected API
CHECK(type(Containers) == "table", "Containers is a table")
CHECK(type(Containers.is_container) == "function", "is_container is a function")
CHECK(type(Containers.try_open_one) == "function", "try_open_one is a function")
CHECK(type(Containers.reset) == "function", "reset is a function")

-- TC2: is_container returns true for known containers
CHECK(Containers.is_container(4497) == true, "Small Clam (4497) is a container")
CHECK(Containers.is_container(27523) == true, "Tightly Closed Clam (27523) is a container")
CHECK(Containers.is_container(24475) == true, "Mithril Bound Trunk (24475) is a container")

-- TC3: is_container returns false for non-containers
CHECK(Containers.is_container(6529) == false, "Shiny Bauble (6529) is NOT a container")
CHECK(Containers.is_container(27435) == false, "Furious Crawdad (27435) is NOT a container")
CHECK(Containers.is_container(nil) == false, "nil is NOT a container")
CHECK(Containers.is_container(0) == false, "0 is NOT a container")

-- TC4: is_container returns false for locked containers (skip list)
CHECK(Containers.is_container(16882) == false, "Battered Lockbox (16882) is skipped (needs lockpick)")

-- TC5: try_open_one returns false with nil state (safe under unit test env)
local ctx = { state = { containers = { last_open_time = 0, opened_count = 0 } }, deps = { config = { menu = {} } } }
local result = Containers.try_open_one(ctx, nil, 0)
CHECK(result == false, "try_open_one returns false with nil player")

-- TC6: reset zeroes all state fields
local state = { containers = { last_open_time = 999.0, opened_count = 5 } }
Containers.reset(state)
CHECK(state.containers.last_open_time == 0.0, "reset zeroes last_open_time")
CHECK(state.containers.opened_count == 0, "reset zeroes opened_count")

print(string.format("PASS test_containers (%d assertions, %d failures)", assertions, failures))
return { assertions = assertions, failures = failures }
