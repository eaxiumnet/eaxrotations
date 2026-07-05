-- test_mr_pinchy.lua — Unit tests for the Mr. Pinchy handler module.

local MrPinchy = require("fishing/mr_pinchy")

local assertions = 0
local failures = 0

local function CHECK(cond, msg)
    assertions = assertions + 1
    if not cond then
        failures = failures + 1
        print("  FAIL: " .. msg)
    end
end

-- TP1: module exposes expected API
CHECK(type(MrPinchy) == "table", "MrPinchy is a table")
CHECK(type(MrPinchy.has_pinchy) == "function", "has_pinchy is a function")
CHECK(type(MrPinchy.try_use) == "function", "try_use is a function")
CHECK(type(MrPinchy.reset) == "function", "reset is a function")

-- TP2: has_pinchy returns false under unit test (no API)
local ctx = { state = { pinchy = { last_use_time = 0, uses_total = 0 } }, deps = { config = { menu = {} } } }
local has, count = MrPinchy.has_pinchy(ctx)
CHECK(has == false, "has_pinchy returns false with no API")
CHECK(count == 0, "has_pinchy count is 0 with no API")

-- TP3: try_use returns false with nil player
local result = MrPinchy.try_use(ctx, nil, 0)
CHECK(result == false, "try_use returns false with nil player")

-- TP4: reset zeroes all state fields
local state = { pinchy = { last_use_time = 999.0, uses_total = 3, crawdad_won = true } }
MrPinchy.reset(state)
CHECK(state.pinchy.last_use_time == 0.0, "reset zeroes last_use_time")
CHECK(state.pinchy.uses_total == 0, "reset zeroes uses_total")
CHECK(state.pinchy.crawdad_won == false, "reset clears crawdad_won")

print(string.format("PASS test_mr_pinchy (%d assertions, %d failures)", assertions, failures))
return { assertions = assertions, failures = failures }
