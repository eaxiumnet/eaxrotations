-- What: Unit tests for waypoint_fixer_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify Z-fix logic and map-to-world conversion wrappers

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- S1: fix_z returns position with corrected Z when coords_helper available
-- (Simulate by mocking coords_helper behavior)
do
    mock.reset()
    -- Mock coords_helper module
    package.loaded["common/utility/coords_helper"] = {
        get_terrain_height = function(self, x, y)
            -- Fake terrain: z = 50 for all positions
            return 50
        end,
        map_to_world = function(self, map_id, map_pos, extra_height)
            return { x = 100, y = 200, z = 0 }
        end,
    }

    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local fixed = wf.fix_z({ x = 10, y = 20, z = 0 })
    assert(fixed ~= nil, "S1: fix_z should return a position")
    assert(fixed.x == 10, "S1: x should be preserved")
    assert(fixed.y == 20, "S1: y should be preserved")
    assert(fixed.z == 50, "S1: z should be corrected to terrain height 50, got " .. tostring(fixed.z))
    print("  S1 PASS: fix_z corrects z=0 to terrain height")
end

-- S2: fix_z returns original position when coords_helper not available
package.loaded["common/utility/coords_helper"] = nil
do
    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    -- Force re-require by clearing cached module
    package.loaded["EaxAutoQuester/waypoint_fixer_sylvanas"] = nil
    wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local fixed = wf.fix_z({ x = 10, y = 20, z = 5 })
    assert(fixed ~= nil, "S2: fix_z should return original when no coords_helper")
    assert(fixed.z == 5, "S2: z should remain 5 when coords_helper missing, got " .. tostring(fixed.z))
    print("  S2 PASS: fix_z returns original when coords_helper unavailable")
end

-- S3: map_to_world_fixed returns position with fixed Z
package.loaded["common/utility/coords_helper"] = {
    get_terrain_height = function(self, x, y) return 75 end,
    map_to_world = function(self, map_id, map_pos, extra_height)
        return { x = 300, y = 400, z = 0 }
    end,
}
package.loaded["EaxAutoQuester/waypoint_fixer_sylvanas"] = nil
do
    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local pos = wf.map_to_world_fixed(1, { x = 0.5, y = 0.5 })
    assert(pos ~= nil, "S3: map_to_world_fixed should return position")
    assert(pos.z == 75, "S3: z should be 75 (terrain height), got " .. tostring(pos.z))
    print("  S3 PASS: map_to_world_fixed fixes Z via terrain height")
end

-- S4: fix_positions array wrapper
package.loaded["EaxAutoQuester/waypoint_fixer_sylvanas"] = nil
do
    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local positions = {
        { x = 1, y = 2, z = 0 },
        { x = 3, y = 4, z = 0 },
    }
    local fixed = wf.fix_positions(positions)
    assert(#fixed == 2, "S4: should return 2 positions")
    assert(fixed[1].z == 75, "S4: first z fixed")
    assert(fixed[2].z == 75, "S4: second z fixed")
    print("  S4 PASS: fix_positions fixes all positions")
end

-- S5: fix_z with terrain_height=0 AND original z=0, player nearby at z=150 → uses player Z
package.loaded["common/utility/coords_helper"] = {
    get_terrain_height = function(self, x, y) return 0 end,
}
package.loaded["EaxAutoQuester/waypoint_fixer_sylvanas"] = nil
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 150 } })
    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local fixed = wf.fix_z({ x = 10, y = 20, z = 0 })
    assert(fixed ~= nil, "S5: fix_z should return a position")
    assert(fixed.z == 150, "S5: z should fall back to player Z (150) when terrain=0 and original=0, got " .. tostring(fixed.z))
    print("  S5 PASS: fix_z falls back to player Z when terrain height returns 0")
end

-- S6: fix_z with terrain_height=0 AND original z=0, player far away (>500yd) → returns z=0
package.loaded["EaxAutoQuester/waypoint_fixer_sylvanas"] = nil
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 150 } })
    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local fixed = wf.fix_z({ x = 1000, y = 1000, z = 0 })  -- 1414yd away
    assert(fixed ~= nil, "S6: fix_z should return a position")
    assert(fixed.z == 0, "S6: z should stay 0 when player is far away, got " .. tostring(fixed.z))
    print("  S6 PASS: fix_z keeps z=0 when player is too far away for reliable Z")
end

-- S7: fix_z terrain_height errors and original z=0 → uses player Z fallback
package.loaded["common/utility/coords_helper"] = {
    get_terrain_height = function(self, x, y) error("no terrain data") end,
}
package.loaded["EaxAutoQuester/waypoint_fixer_sylvanas"] = nil
do
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 200 } })
    local wf = require("EaxAutoQuester/waypoint_fixer_sylvanas")
    local fixed = wf.fix_z({ x = 10, y = 20, z = 0 })
    assert(fixed ~= nil, "S7: fix_z should return a position")
    assert(fixed.z == 200, "S7: z should fall back to player Z (200) when terrain raycast errors, got " .. tostring(fixed.z))
    print("  S7 PASS: fix_z falls back to player Z when terrain raycast errors")
end

print("PASS test_waypoint_fixer")
os.exit(0)
