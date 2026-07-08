-- test_buff_upgrade.lua -- buff management buff upgrade tests.
-- WHAT:  buff management buff upgrade tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Buff Upgrade System — rank detection + upgrade trigger
-- Contract: when a unit has a lower-rank buff active and the player knows a
--           higher rank, try_buff_upgrades returns true and casts the upgrade.
-- ============================================================================
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local function assert_true(v, label)
    if not v then error((label or "assert_true") .. ": expected true, got " .. tostring(v), 2) end
end

local function assert_false(v, label)
    if v then error((label or "assert_false") .. ": expected false, got " .. tostring(v), 2) end
end

-- ================================================================
-- Setup: mock NS with all required functions
-- ================================================================

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

NS.CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
                SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

local casts = {}
local buff_rank_returns = {}  -- unit_key -> {active_id, rank_pos}

NS.buff_rank = function(unit, ids)
    local key = unit._test_key or "self"
    local r = buff_rank_returns[key]
    if r then return r[1], r[2] end
    return nil, nil
end

NS.spell_ready = function(spell, target, opts) return true end

NS.try_cast = function(spell, target, reason)
    casts[#casts + 1] = { spell = spell, target = target, reason = reason }
    return true
end

NS.spell_action = function(ids, label)
    return { _ids = ids, _label = label }
end

NS.broken_api_throttled = nil  -- no throttle in tests

NS.GetPartyMembers = function() return {} end

NS.get_setting = function(key, fallback) return fallback end

NS.gcd_remains = function() return 0 end
NS.time_now = function() return 100 end

-- ================================================================
-- Load the module under test
-- ================================================================

package.loaded["shared/buff_upgrade_sylvanas"] = nil
local ok, mod = pcall(require, "shared/buff_upgrade_sylvanas")
assert(ok, "Failed to load buff_upgrade_sylvanas: " .. tostring(mod))

local needs_upgrade = mod.needs_upgrade
local try_buff_upgrades = mod.try_buff_upgrades

-- ================================================================
-- Test data
-- ================================================================

local TEST_IDS = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 }
local entry = { ids = TEST_IDS, key = "fort" }

local me = { _test_key = "self",
    is_alive = function() return true end,
    get_class_id = function() return 5 end,  -- Priest
}

local party1 = { _test_key = "party1",
    is_alive = function() return true end,
}

-- ================================================================
-- 1. needs_upgrade: false when no buff active
-- ================================================================

buff_rank_returns["self"] = { nil, nil }
assert_false(needs_upgrade(me, entry), "no buff -> not an upgrade")
print("PASS buff_upgrade_no_buff")

-- ================================================================
-- 2. needs_upgrade: false when highest rank active (position 1)
-- ================================================================

buff_rank_returns["self"] = { 25389, 1 }
assert_false(needs_upgrade(me, entry), "highest rank -> no upgrade needed")
print("PASS buff_upgrade_highest_rank")

-- ================================================================
-- 3. needs_upgrade: true when lower rank active (position > 1)
-- ================================================================

buff_rank_returns["self"] = { 1243, 7 }  -- lowest rank
assert_true(needs_upgrade(me, entry), "lowest rank -> upgrade needed")
print("PASS buff_upgrade_low_rank")

buff_rank_returns["self"] = { 10937, 3 }  -- mid rank
assert_true(needs_upgrade(me, entry), "mid rank -> upgrade needed")
print("PASS buff_upgrade_mid_rank")

-- ================================================================
-- 4. try_buff_upgrades: self upgrade triggers cast
-- ================================================================

casts = {}
buff_rank_returns["self"] = { 1243, 7 }
local r = try_buff_upgrades({}, {}, me)
assert_true(r, "self upgrade should return true")
assert_eq(#casts, 1, "should cast once for self upgrade")
print("PASS buff_upgrade_self_cast")

-- ================================================================
-- 5. try_buff_upgrades: no-op when at highest rank
-- ================================================================

casts = {}
buff_rank_returns["self"] = { 25389, 1 }
r = try_buff_upgrades({}, {}, me)
assert_false(r, "no upgrade needed -> return false")
assert_eq(#casts, 0, "should not cast when at highest rank")
print("PASS buff_upgrade_no_op")

-- ================================================================
-- 6. try_buff_upgrades: party member upgrade
-- ================================================================

casts = {}
NS.GetPartyMembers = function() return { party1 } end
buff_rank_returns["self"] = { 25389, 1 }  -- self is fine
buff_rank_returns["party1"] = { 1243, 7 }  -- party member has low rank

r = try_buff_upgrades({}, {}, me)
assert_true(r, "party upgrade should return true")
assert_eq(#casts, 1, "should cast once for party upgrade")
print("PASS buff_upgrade_party_cast")

-- ================================================================
-- 7. try_buff_upgrades: both self and party — self wins (priority)
-- ================================================================

casts = {}
buff_rank_returns["self"] = { 1243, 7 }
buff_rank_returns["party1"] = { 1243, 7 }

r = try_buff_upgrades({}, {}, me)
assert_true(r, "self+party upgrade should return true")
assert_eq(#casts, 1, "should cast once (self checked first)")
print("PASS buff_upgrade_self_priority")

-- ================================================================
-- 8. try_buff_upgrades: no class buffs -> no-op
-- ================================================================

casts = {}
buff_rank_returns["self"] = { 1243, 7 }
local warrior = { _test_key = "self",
    is_alive = function() return true end,
    get_class_id = function() return 1 end,  -- Warrior — no party buffs defined
}

r = try_buff_upgrades({}, {}, warrior)
assert_false(r, "warrior has no party buffs -> no-op")
print("PASS buff_upgrade_no_class_buffs")

-- ================================================================
-- 9. try_buff_upgrades: dead party member skipped
-- ================================================================

casts = {}
NS.GetPartyMembers = function() return { party1 } end
buff_rank_returns["self"] = { 25389, 1 }
buff_rank_returns["party1"] = { 1243, 7 }
party1.is_alive = function() return false end  -- dead

r = try_buff_upgrades({}, {}, me)
assert_false(r, "dead party member -> no cast")
assert_eq(#casts, 0, "should not cast on dead member")
print("PASS buff_upgrade_dead_party")

-- Reset
party1.is_alive = function() return true end

print("PASS test_buff_upgrade")
