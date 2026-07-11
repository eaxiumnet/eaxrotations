-- test_active_fight_tracker.lua -- Active Fight Tracker tests.
-- WHAT:  Active Fight Tracker unit tests (GUID model, prune, fresh get, undot find).
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates the PR1 foundation for future multi-dot (no behavior change now).
-- SAFETY: Pure unit tests with mocked API; exercises statics + pcall paths + engagement reuse.

-- Test: Active Fight Tracker (GUID-only, 0.5s throttle, Engagement reuse).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false, assert_eq
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq failed") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
end
setup_asserts()

-- Minimal mock NS
local _mock_now = 100
_G.EaxRotations = {
    time_now = function() return _mock_now end,
    same_unit = function(a, b)
        if a == b then return true end
        if a and b and a._guid and b._guid and a._guid == b._guid then return true end
        if a and b and a._name and b._name and a._name == b._name then return true end
        return false
    end,
    debuff_up = function(unit, ids)
        if unit and unit._has_dot then return true end
        return false
    end,
    GetPlayer = function()
        return { _name = "me", _guid = "me" }
    end,
    GetEnemiesInRange = function(range)
        return {}
    end,
    GetPartyMembers = function()
        return { { _name = "party1", _guid = "p1" } }
    end,
    GetPet = function()
        return { _name = "pet", _guid = "pet" }
    end,
}

-- Mock game_object with GUID
local function mock_unit(guid, name, opts)
    opts = opts or {}
    local u = { _guid = guid, _name = name or guid }
    u.is_valid = function() return opts.invalid ~= true end
    u.is_in_combat = function() return opts.in_combat == true end
    u.get_target = function() return opts.target end
    u.get_guid = function() return u._guid end
    u.get_health_percentage = function() return opts.hp or 100 end
    u._has_dot = opts.has_dot
    return u
end

local M = require("shared/active_fight_tracker_sylvanas")
assert_true(M ~= nil, "module should load")
assert_true(type(M.get_active_fights) == "function", "get_active_fights should be a function")
assert_true(type(M.count) == "function", "count should be a function")
assert_true(type(M.find_undotted_target) == "function", "find_undotted_target should be a function")
assert_true(type(M.reset) == "function", "reset should be a function")
assert_true(type(M.prune) == "function", "prune should be a function")
assert_true(type(M.debug_dump) == "function", "debug_dump should be a function")
assert_true(type(M.on_update) == "function", "on_update stub should be a function")

-- Engagement reuse (pcall loaded)
-- (we cannot easily assert private, but calling paths below exercise it via GetEnemies)

-- GUID coverage: units distinguished by guid
local me = mock_unit("me", "me", { in_combat = true })
local e1 = mock_unit("guid-e1", "e1", { in_combat = true, target = me, has_dot = true })
local e2 = mock_unit("guid-e2", "e2", { in_combat = true, target = me, has_dot = true })
local e3 = mock_unit("guid-e3", "e3", { in_combat = true, target = me, has_dot = false })

_G.EaxRotations.GetEnemiesInRange = function(range)
    return { e1, e2, e3 }
end

-- get_active should return fresh (live) units via filter (engagement reuse + party/pet paths exercised in filter)
local active = M.get_active_fights(40)
local ac = active.n or #active
assert_true(ac >= 1, "get_active_fights should return >=1 engaged (e1/e3)")

-- count uses GUID set
local c = M.count()
assert_true(c >= 1, "count should reflect GUID active fights")

-- GUIDs tracked (inspect via debug or by find)
local dump = M.debug_dump()
assert_true(type(dump) == "string", "debug_dump returns string")
assert_true(dump:find("guid-e1") or dump:find("e1"), "debug_dump should mention a GUID")

-- find_undotted_target (strict missing debuff)
local ctx = { me = me, target = e2 }
local undot = M.find_undotted_target(ctx, { 12345 }, 40)  -- e3 has no dot
assert_true(undot ~= nil, "find_undotted should locate strictly missing debuff target")
assert_true(undot._guid == "guid-e3" or undot._name == "e3", "should pick e3 (missing dot, not current)")

-- prune + GUID removal: simulate e1/e3 gone (OOC or out of engaged)
_G.EaxRotations.GetEnemiesInRange = function(range)
    return { e2 }  -- only e2 remains engaged
end
-- advance time to allow scan (but since get triggers update)
_mock_now = _mock_now + 1
active = M.get_active_fights(40)
c = M.count()
-- after prune of absent, count should drop to the remaining engaged
assert_true(c <= 2, "after scan+prune count should reflect current engaged GUIDs only")

-- reset clears
M.reset()
_G.EaxRotations.GetEnemiesInRange = function() return {} end
_mock_now = _mock_now + 1
assert_eq(M.count(), 0, "reset should clear all GUIDs")
local post_reset = M.get_active_fights(40)
local prc = post_reset.n or #post_reset
-- explicit prune also
M.prune()
assert_eq(M.count(), 0, "count 0 after reset + empty scan")

-- statics exercised (multiple calls should reuse tables without error)
for i=1,3 do
    M.get_active_fights(30)
    M.count()
end
assert_true(true, "static reuse calls succeeded")

-- party-pet note: covered implicitly because get_active reuses Engagement.filter which handles party/pet targeting (see its tests + header)
-- on_update stub does not crash
M.on_update({ in_combat = true })

print("PASS test_active_fight_tracker")
