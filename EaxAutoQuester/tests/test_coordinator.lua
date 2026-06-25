-- What: Unit tests for EaxAutoQuester/quest_state/coordinator.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify state dispatch, stop_navigation, render_debug, and combat override
--      (must NOT block user mouse movement, must NOT call look_at_target on invalid targets)

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local coordinator = require("EaxAutoQuester/quest_state/coordinator")

-- Test update runs without error
assert(type(coordinator.update) == "function", "coordinator.update is function")
assert(type(coordinator.stop_navigation) == "function", "coordinator.stop_navigation is function")
assert(type(coordinator.render_debug) == "function", "coordinator.render_debug is function")

-- Test stop_navigation
coordinator.stop_navigation()

-- Test render_debug (no crash)
coordinator.render_debug()

-- =============================================================================
-- Combat override scenarios — coordinator must not block user input or crash on
-- stale targets. Live bugs: pause_movement_light(0.5) every tick prevented
-- mouse movement; look_at_target with invalid target → "Invalid game object"
-- errors in movement_handler.lua:206.
-- =============================================================================

-- Install a mock movement_handler that records every call
local mh_calls = { pause_movement_light = 0, look_at_target = 0, look_at_target_invalid = 0 }
package.loaded["common/utility/movement_handler"] = {
    pause_movement_light = function(self)
        mh_calls.pause_movement_light = mh_calls.pause_movement_light + 1
    end,
    look_at_target = function(self, _, _, target)
        mh_calls.look_at_target = mh_calls.look_at_target + 1
        if target and target.is_valid and not target:is_valid() then
            mh_calls.look_at_target_invalid = mh_calls.look_at_target_invalid + 1
        end
    end,
}

-- S5 — combat + valid target → coordinator must NOT call pause_movement_light
-- (the user needs to be able to move the mouse during combat)
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 10, y = 0, z = 0 },
        name = "Defias Thug",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_100",
    })
    target._target = target  -- player target = this enemy
    mock._objects = { target }
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    mock._player._target = target

    -- Reset the call counters
    mh_calls.pause_movement_light = 0
    mh_calls.look_at_target = 0

    coordinator.update()

    assert(mh_calls.pause_movement_light == 0,
        "S5 FAIL: coordinator's combat block must NOT call pause_movement_light " ..
        "(user can't move mouse). Got " .. tostring(mh_calls.pause_movement_light) .. " calls.")
    print("  S5 PASS: combat override does NOT call pause_movement_light (mouse stays free)")
end

-- S6 — combat + INVALID target → coordinator must NOT call look_at_target
-- (causes "Invalid game object" errors in movement_handler.lua:206)
do
    mock.reset()
    local dead_target = mock.create_object({
        pos = { x = 5, y = 0, z = 0 },
        name = "Dead Enemy",
        npc_id = 100,
        unit = true,
        valid = false,  -- invalid!
        dead = true,
        guid = "dead_enemy",
    })
    mock._objects = { dead_target }
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    mock._player._target = dead_target

    mh_calls.look_at_target = 0
    mh_calls.look_at_target_invalid = 0

    coordinator.update()

    assert(mh_calls.look_at_target_invalid == 0,
        "S6 FAIL: coordinator must NOT call look_at_target on invalid target " ..
        "(causes 'Invalid game object' error). Got " .. tostring(mh_calls.look_at_target_invalid) .. " invalid calls.")
    print("  S6 PASS: combat override guards look_at_target with is_valid()")
end

-- S7 — combat + valid target → core.input.look_at NOT called
-- The auto-quester does NOT auto-face in combat. EaxRotations handles facing
-- for casts via face_for_cast / face_for_spell. The user reported the bot
-- was doing a jarring 180° turn on combat entry — that was the
-- auto-quester snapping to face the enemy. EaxRotations rotates when
-- actually needed (before a cast), not continuously.
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Enemy Behind",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_behind",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target

    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S7 FAIL: auto-quester must NOT call look_at in combat. " ..
        "EaxRotations handles facing for casts. Got " .. tostring(look_at_count) ..
        " look_at calls — this is what caused the 180° turn on combat entry.")
    print("  S7 PASS: combat facing removed (EaxRotations handles it) — no 180° snap")
end

-- S7b — combat + valid target IN FRONT of player → core.input.look_at NOT called
-- With the 90° soft-facing threshold, the bot does NOT rotate when the enemy
-- is within 90° of the current facing. This prevents camera-snap desync — the
-- user can keep moving the mouse without the bot fighting their camera control.
do
    mock.reset()
    -- Player faces NORTH (rotation 0). Enemy is directly NORTH (pos y = 10).
    -- Angle between facing and enemy = 0° → < 90° → bot should NOT rotate.
    local target = mock.create_object({
        pos = { x = 0, y = 10, z = 0 },
        name = "Enemy In Front",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_in_front",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0  -- facing north (same direction as enemy)
    mock._player._target = target

    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S7b FAIL: enemy directly in front (0° off) should NOT trigger rotation " ..
        "(soft facing protects camera control). Got " .. tostring(look_at_count) .. " calls.")
    print("  S7b PASS: soft facing — enemy in front → look_at NOT called (no desync)")
end

-- S8 — combat + same target across 5 ticks → core.input.look_at NEVER called
-- The auto-quester does NOT auto-face in combat — at all. EaxRotations handles
-- facing for casts. The previous "throttled to once" behavior was a 0.3s
-- re-rotation that caused the 180° snap. Now: never rotate from the quester.
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Throttle Test Enemy",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "throttle_test_enemy",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target

    for i = 1, 5 do coordinator.update() end

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S8 FAIL: auto-quester must NEVER call look_at in combat. " ..
        "EaxRotations handles facing for casts. Got " .. tostring(look_at_count) ..
        " look_at calls across 5 ticks — this is what caused the 180° turn spam.")
    print("  S8 PASS: combat — same target across 5 ticks → look_at NEVER called (EaxRotations handles facing)")
end

-- S9 — combat + target moves > 5yd → core.input.look_at NEVER called
-- (auto-quester never auto-faces; EaxRotations handles facing for casts)
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Moving Enemy",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "moving_enemy",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target

    coordinator.update()
    target._pos = { x = 0, y = -20, z = 0 }
    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S9 FAIL: target movement must not trigger look_at. " ..
        "EaxRotations handles facing. Got " .. tostring(look_at_count) .. " calls.")
    print("  S9 PASS: target moves > 5yd → look_at NEVER called (no auto-face)")
end

-- S10 — combat + new target GUID → core.input.look_at NEVER called
-- (auto-quester never auto-faces; EaxRotations handles facing for casts)
do
    mock.reset()
    local target_a = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Enemy A",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_a",
    })
    local target_b = mock.create_object({
        pos = { x = 5, y = -10, z = 0 },
        name = "Enemy B",
        npc_id = 101,
        unit = true,
        valid = true,
        guid = "enemy_b",
    })
    mock._objects = { target_a, target_b }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target_a

    coordinator.update()
    mock._player._target = target_b
    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S10 FAIL: new target GUID must not trigger look_at. " ..
        "EaxRotations handles facing. Got " .. tostring(look_at_count) .. " calls.")
    print("  S10 PASS: new target GUID → look_at NEVER called (no auto-face)")
end

print("PASS test_coordinator")
os.exit(0)
