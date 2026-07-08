-- test_potion_helper_module.lua -- potion helper helper tests module tests.
-- WHAT:  potion helper helper tests module tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Unit tests for the shared potion_helper_sylvanas module.
-- Covers: ID lists, try_use_potion execution, pcall safety.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- ============================================================================
-- Shared call-tracking helper
-- ============================================================================
local use_item_calls = {}
local function tracking_mock(return_true_for)
    return function(id, target)
        use_item_calls[#use_item_calls + 1] = { id = id, target = target }
        if return_true_for and return_true_for[id] then return true end
        if id == 22832 then return true end   -- default for success-path tests
        if id == 13444 then return true end
        return false
    end
end

_G.EaxRotations = {
    use_item_by_id = tracking_mock(),
}

-- ============================================================================
-- Load the module (NS is captured from _G.EaxRotations at this point)
-- ============================================================================
local potion_helper = require("shared/potion_helper_sylvanas")
assert_true(potion_helper, "potion_helper module should load")

-- ============================================================================
-- ID list tests
-- ============================================================================
assert_true(type(potion_helper.HEALTH_POTION_IDS) == "table", "HEALTH_POTION_IDS should be a table")
assert_true(#potion_helper.HEALTH_POTION_IDS > 0, "HEALTH_POTION_IDS should not be empty")
assert_true(type(potion_helper.MANA_POTION_IDS) == "table", "MANA_POTION_IDS should be a table")
assert_true(#potion_helper.MANA_POTION_IDS > 0, "MANA_POTION_IDS should not be empty")
assert_true(type(potion_helper.DAMAGE_POTION_IDS) == "table", "DAMAGE_POTION_IDS should be a table")
assert_true(#potion_helper.DAMAGE_POTION_IDS > 0, "DAMAGE_POTION_IDS should not be empty")

-- Check TBC-specific mana IDs are present
local has_tbc_ids = false
for _, id in ipairs(potion_helper.MANA_POTION_IDS) do
    if id == 33935 or id == 32948 or id == 22850 then has_tbc_ids = true; break end
end
assert_true(has_tbc_ids, "MANA_POTION_IDS should include TBC-specific potions (33935 Crystal Mana, 32948 Auchenai Mana, 22850 Super Rejuvenation)")

-- ============================================================================
-- try_use_potion: success path (stops on first available)
-- ============================================================================
use_item_calls = {}
local ctx = { me = { name = "Player" } }
local result = potion_helper.try_use_potion(ctx, potion_helper.MANA_POTION_IDS)
assert_true(result, "try_use_potion should return true when item use succeeds")
assert_true(#use_item_calls > 0, "use_item_by_id should have been called")
assert_eq(use_item_calls[1].id, 33935, "first ID tried should be 33935 (Crystal Mana, best first, succeeds immediately)")

-- ============================================================================
-- try_use_potion: iterates through IDs until success
-- ============================================================================
_G.EaxRotations.use_item_by_id = tracking_mock({ [13444] = true })
use_item_calls = {}
result = potion_helper.try_use_potion({ me = {} }, { 10000, 10001, 13444, 10002 })
assert_true(result, "should succeed when 3rd ID matches")
assert_eq(#use_item_calls, 3, "should call use_item_by_id 3 times before success")
assert_eq(use_item_calls[1].id, 10000, "first call should be first ID")
assert_eq(use_item_calls[3].id, 13444, "third call should be matching ID")

-- ============================================================================
-- try_use_potion: all IDs fail -> returns false, tries every ID
-- ============================================================================
_G.EaxRotations.use_item_by_id = tracking_mock({})  -- nothing succeeds
use_item_calls = {}
result = potion_helper.try_use_potion({ me = {} }, potion_helper.HEALTH_POTION_IDS)
assert_false(result, "should return false when no item use succeeds")
assert_eq(#use_item_calls, #potion_helper.HEALTH_POTION_IDS, "should try all IDs when none succeed")

-- ============================================================================
-- try_use_potion: pcall safety when context is nil
-- ============================================================================
_G.EaxRotations.use_item_by_id = tracking_mock({ [1] = true })
use_item_calls = {}
result = potion_helper.try_use_potion(nil, { 1 })
assert_true(result, "should handle nil context via pcall (target becomes nil)")

-- ============================================================================
-- try_use_potion: nil context.me (target passes as nil to use_item)
-- ============================================================================
_G.EaxRotations.use_item_by_id = function(id, target)
    use_item_calls[#use_item_calls + 1] = { id = id, target = target }
    return target ~= nil  -- succeed only if target is provided
end
use_item_calls = {}
result = potion_helper.try_use_potion({}, { 22832 })  -- context without .me
assert_false(result, "should return false when context.me is nil (no target for use_item)")

-- ============================================================================
-- try_use_potion: pcall safety when use_item_by_id throws
-- ============================================================================
_G.EaxRotations.use_item_by_id = function() error("simulated API crash") end
local ok, result_val = pcall(potion_helper.try_use_potion, { me = {} }, { 1 })
assert_true(ok, "should not throw when use_item_by_id throws (pcall catches)")
assert_false(result_val, "should return false when use_item_by_id throws for all IDs")

print("PASS test_potion_helper_module")
