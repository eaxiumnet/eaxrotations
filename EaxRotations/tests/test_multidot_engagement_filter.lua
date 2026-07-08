-- test_multidot_engagement_filter.lua -- multi-dotting tests.
-- WHAT:  multi-dotting tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Test: Multi-DoT Engagement Filter.

package.path = 'EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;' .. package.path

local assert_true, assert_false, assert_eq
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or 'assert_true failed', 2) end end
    assert_false = function(v, label) if v then error(label or 'assert_false failed', 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or 'assert_eq failed') .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b), 2) end end
end
setup_asserts()

-- Minimal mock NS with required functions
local _mock_now = 100
_G.EaxRotations = {
    time_now = function() return _mock_now end,
    same_unit = function(a, b)
        if a == b then return true end
        if a and b and a._name and b._name and a._name == b._name then return true end
        return false
    end,
    debuff_up = function(unit, ids)
        if unit and unit._has_dot then return true end
        return false
    end,
    GetPartyMembers = function()
        return { { _name = 'party1' } }
    end,
    GetPet = function()
        return { _name = 'pet' }
    end,
    GetPlayer = function()
        return { _name = 'me' }
    end,
    GetEnemiesInRange = function(range)
        return {}
    end,
}

-- Mock game_object helpers
local function mock_unit(name, opts)
    opts = opts or {}
    local u = { _name = name }
    u.is_valid = function() return opts.invalid ~= true end
    u.is_in_combat = function() return opts.in_combat == true end
    u.get_target = function() return opts.target end
    u.get_health_percentage = function() return opts.hp or 100 end
    return u
end

local M = require('shared/multidot_engagement_filter_sylvanas')
assert_true(M ~= nil, 'module should load')
assert_true(type(M.is_engaged_with_us) == 'function', 'is_engaged_with_us should be a function')
assert_true(type(M.filter_engaged_enemies) == 'function', 'filter_engaged_enemies should be a function')
assert_true(type(M.find_multidot_target) == 'function', 'find_multidot_target should be a function')

-- === is_engaged_with_us tests ===
local me = mock_unit('me', { in_combat = true })
local pet = mock_unit('pet')

-- Out-of-combat enemy: always false
local patrol = mock_unit('patrol', { in_combat = false })
assert_false(M.is_engaged_with_us(patrol, me), 'patrol (OOC) should not be engaged')

-- In-combat, targeting me: true
local targeting_me = mock_unit('targeting_me', { in_combat = true, target = me })
assert_true(M.is_engaged_with_us(targeting_me, me), 'enemy targeting me should be engaged')

-- In-combat, damaged, but NO target info (stub-like) -> false in strict mode
local damaged_no_target = mock_unit('damaged_no_target', { in_combat = true, hp = 85 })
assert_false(M.is_engaged_with_us(damaged_no_target, me), 'damaged enemy with no target info (strict) should NOT be engaged')

-- In-combat, damaged, targeting me -> true
local damaged_targeting_me = mock_unit('damaged_targeting_me', { in_combat = true, hp = 85, target = me })
assert_true(M.is_engaged_with_us(damaged_targeting_me, me), 'damaged enemy targeting me should be engaged')

-- In-combat, full HP, no target: false (strict)
local fresh = mock_unit('fresh', { in_combat = true, hp = 100, target = nil })
assert_false(M.is_engaged_with_us(fresh, me), 'fresh in-combat enemy (strict) should NOT be engaged')

-- In-combat, full HP, no target methods (stub): lenient allows if me is in combat
assert_true(M.is_engaged_with_us(fresh, me, nil, nil, 'lenient'), 'fresh in-combat enemy stub (lenient) should be engaged')

-- In-combat, targeting party member: true
local party1 = { _name = 'party1' }
local targeting_party = mock_unit('targeting_party', { in_combat = true, target = party1 })
assert_true(M.is_engaged_with_us(targeting_party, me), 'enemy targeting party member should be engaged')

-- In-combat, targeting pet: true
local targeting_pet = mock_unit('targeting_pet', { in_combat = true, target = pet })
assert_true(M.is_engaged_with_us(targeting_pet, me, nil, pet), 'enemy targeting pet should be engaged')

-- In-combat, damaged, targeting a STRANGER (not party/raid/me) -> false
local stranger = { _name = 'stranger' }
local targeting_stranger = mock_unit('targeting_stranger', { in_combat = true, hp = 85, target = stranger })
assert_false(M.is_engaged_with_us(targeting_stranger, me), 'enemy targeting stranger should NOT be engaged (do not help randoms)')

-- === filter_engaged_enemies tests ===
local enemies = {
    mock_unit('e1', { in_combat = true, target = me }),       -- engaged
    mock_unit('e2', { in_combat = false, target = me }),       -- OOC (skip)
    mock_unit('e3', { in_combat = true, hp = 90, target = nil }), -- NOT engaged (no target, not stub)
    mock_unit('e4', { in_combat = true, hp = 100, target = nil }), -- not engaged (strict)
}
local engaged = M.filter_engaged_enemies(enemies, me)
local count = engaged.n or #engaged
assert_eq(count, 1, 'should find 1 engaged enemy (e1 only)')
assert_true(engaged[1]._name == 'e1', 'first engaged should be e1')

-- === find_multidot_target tests ===
_G.EaxRotations.GetEnemiesInRange = function(range)
    return {
        mock_unit('e1', { in_combat = true, target = me, _has_dot = true }),    -- has dot
        mock_unit('e2', { in_combat = true, target = me, _has_dot = false }),   -- missing dot, engaged
        mock_unit('e3', { in_combat = false, target = me, _has_dot = false }),  -- OOC (skip)
    }
end

local ctx = { me = me, target = enemies[1], settings = {} }
local target = M.find_multidot_target(ctx, { 1 }, 30)
assert_true(target ~= nil, 'should find a multidot target')
assert_true(target._name == 'e2', 'multidot target should be e2 (engaged, missing dot)')

-- === count_engaged_enemies tests ===
local count2 = M.count_engaged_enemies(ctx, 30)
assert_eq(count2, 2, 'should count 2 engaged enemies (e1 and e2 both target me)')

print('PASS test_multidot_engagement_filter')
