-- What: Unit tests for EaxAutoQuester/object_scanner.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify per-tick cache invalidation, scan, find_nearest, count behavior

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local obj_scanner = require("EaxAutoQuester/object_scanner")

-- ============================================================================
-- S1: get_visible_objects() returns table
-- ============================================================================
do
    local objects = obj_scanner.get_visible_objects()
    assert(type(objects) == "table", "S1 FAIL: should return table")
    print("  S1 PASS: get_visible_objects returns table")
end

-- ============================================================================
-- S2: invalidate() forces cache refresh on next access
-- ============================================================================
do
    local old_objects = obj_scanner.get_visible_objects()
    mock._objects = { mock.create_object({ name = "A" }), mock.create_object({ name = "B" }) }
    obj_scanner.invalidate()
    local new_objects = obj_scanner.get_visible_objects()
    assert(#new_objects == 2, "S2 FAIL: should reflect new objects after invalidate. Got " .. tostring(#new_objects))
    print("  S2 PASS: invalidate() forces refresh")
end

-- ============================================================================
-- S3: scan() returns filtered results
-- ============================================================================
do
    mock.reset()
    obj_scanner.invalidate()
    mock._objects = {
        mock.create_object({ name = "Enemy", unit = true, enemy = true, pos = { x = 5, y = 0, z = 0 } }),
        mock.create_object({ name = "Friendly", unit = true, enemy = false, pos = { x = 10, y = 0, z = 0 } }),
        mock.create_object({ name = "Tree", unit = false, pos = { x = 15, y = 0, z = 0 } }),
    }
    obj_scanner.invalidate()
    local enemies = obj_scanner.scan(function(o)
        local u_ok, u = pcall(function() return o:is_unit() end)
        local e_ok, e = pcall(function() return o:is_enemy_with({}) end)
        return u_ok and u and e_ok and e
    end, 50)
    assert(#enemies == 1, "S3 FAIL: should find 1 enemy. Got " .. tostring(#enemies))
    assert(enemies[1]._name == "Enemy", "S3 FAIL: should find named Enemy")
    print("  S3 PASS: scan() returns filtered results")
end

-- ============================================================================
-- S4: scan() cap by max_count
-- ============================================================================
do
    mock.reset()
    obj_scanner.invalidate()
    local many = {}
    for i = 1, 100 do many[i] = mock.create_object({ pos = { x = i, y = 0, z = 0 } }) end
    mock._objects = many
    obj_scanner.invalidate()
    local result = obj_scanner.scan(nil, 10)
    assert(#result == 10, "S4 FAIL: scan cap should limit to 10. Got " .. tostring(#result))
    print("  S4 PASS: scan() respects max_count")
end

-- ============================================================================
-- S5: find_nearest() returns closest match by squared distance
-- ============================================================================
do
    mock.reset()
    obj_scanner.invalidate()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    mock._objects = {
        mock.create_object({ pos = { x = 30, y = 0, z = 0 }, unit = true }),
        mock.create_object({ pos = { x = 5, y = 0, z = 0 }, unit = true }),
        mock.create_object({ pos = { x = 50, y = 0, z = 0 }, unit = true }),
    }
    obj_scanner.invalidate()
    local nearest = obj_scanner.find_nearest(function(o)
        local u_ok, u = pcall(function() return o:is_unit() end)
        return u_ok and u
    end, 60)
    assert(nearest, "S5 FAIL: should find nearest")
    assert(nearest._pos.x == 5, "S5 FAIL: should find x=5 object. Got " .. tostring(nearest._pos.x))
    print("  S5 PASS: find_nearest() picks closest by squared distance")
end

-- ============================================================================
-- S6: count() returns matching count
-- ============================================================================
do
    mock.reset()
    obj_scanner.invalidate()
    mock._objects = {
        mock.create_object({ unit = true }),
        mock.create_object({ unit = false }),
        mock.create_object({ unit = true }),
    }
    obj_scanner.invalidate()
    local c = obj_scanner.count(function(o)
        local u_ok, u = pcall(function() return o:is_unit() end)
        return u_ok and u
    end)
    assert(c == 2, "S6 FAIL: count should be 2. Got " .. tostring(c))
    print("  S6 PASS: count() returns match count")
end

-- ============================================================================
-- S7: get_local_player() returns cached player
-- ============================================================================
do
    mock.reset()
    obj_scanner.invalidate()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    obj_scanner.invalidate()
    local p = obj_scanner.get_local_player()
    assert(p, "S7 FAIL: should return player")
    assert(p:get_position().x == 0, "S7 FAIL: position should match")
    print("  S7 PASS: get_local_player() returns cached player")
end

print("PASS test_object_scanner")
os.exit(0)
