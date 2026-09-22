-- What: shared/facing.lua — the one place the quester aims at a unit, and its throttle.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Live report: "the fucking arrow keys movement needs to stop, im spinning around in
--      circles". movement_handler:look_at_target(lock_duration, delay, target) does not snap a
--      facing — it HOLDS one for the duration and releases only when it expires or is unlocked
--      (scraped_docs_md/dev/api/movement-handler.md, "Locks the camera to face a target unit. The
--      look-at is maintained for the specified duration or until manually unlocked"). The quest
--      states re-issued it with 0.5s every tick at whatever unit was selected, so the character was
--      servo-driven continuously — at a mob circling in melee, at an alternating "best enemy", or
--      at the client's stale target after a kill, which is a corpse. This suite pins the three
--      rules that stop that, and each scenario is written so removing its rule fails it.
-- Safety: pure module + a stub movement_handler; no client, no network, no writes.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- Minimal core, installed before the module is required (it caches core.time at load).
local _time = 1000
local _locks = {}
local _pauses = 0

core = {
    time = function() return _time end,
    object_manager = { get_local_player = function() return nil end },
}

-- A unit stub: position plus the two probes facing.ensure consults.
local function unit(opts)
    opts = opts or {}
    return {
        is_alive = function() return opts.alive ~= false end,
        can_be_looted = function() return opts.lootable == true end,
        get_position = function() return opts.pos or { x = 0, y = 0, z = 0 } end,
        get_direction = function() return opts.dir end,
    }
end

local _me = {
    get_position = function() return { x = 0, y = 0, z = 0 } end,
    get_direction = function() return { x = 1, y = 0, z = 0 } end,   -- facing +X
}

-- Stub movement_handler on package.loaded, the way the module requires it.
package.loaded["common/utility/movement_handler"] = {
    look_at_target = function(_, duration, delay, target)
        _locks[#_locks + 1] = { duration = duration, delay = delay, target = target }
    end,
    pause_movement_light = function() _pauses = _pauses + 1 end,
}

local facing = require("shared/facing")

local function reset()
    _locks = {}
    _pauses = 0
    facing.reset()
end

local function lock_count() return #_locks end

-- =============================================================================
-- F1 — one lock per interval: the per-tick re-issue is what spun the player
-- =============================================================================

do
    reset()
    -- Target due east (+X, 10yd away) while facing +X would be satisfied... so face -X instead.
    _me.get_direction = function() return { x = -1, y = 0, z = 0 } end
    local mob = unit({ pos = { x = 10, y = 0, z = 0 } })

    assert(facing.ensure(_me, mob) == true, "F1a FAIL: an unfaced target must be aimed at")
    assert(lock_count() == 1, "F1b FAIL: expected exactly one lock (got " .. lock_count() .. ")")

    -- Every later tick inside the interval: same target, same everything. These are the ticks that
    -- used to restart the servo.
    for _ = 1, 20 do
        facing.ensure(_me, mob)
    end
    assert(lock_count() == 1,
        "F1c FAIL: the lock was re-issued " .. lock_count() .. " times — one per tick is the spin")

    _time = _time + 3.1
    facing.ensure(_me, mob)
    assert(lock_count() == 2, "F1d FAIL: after the interval a fresh aim is allowed")
    print("  F1 PASS: at most one look-at lock per interval (the per-tick servo is gone)")
end

-- =============================================================================
-- F2 — already facing it: no lock at all
-- =============================================================================

do
    reset()
    _me.get_direction = function() return { x = 1, y = 0, z = 0 } end
    local mob = unit({ pos = { x = 10, y = 0, z = 0 } })   -- dead ahead

    assert(facing.ensure(_me, mob) == false, "F2a FAIL: a target inside the cone needs no aim")
    assert(lock_count() == 0, "F2b FAIL: no lock may be issued when already facing the target")
    assert(_pauses == 0, "F2c FAIL: movement must not be paused to face something already faced")
    print("  F2 PASS: a target already inside the facing cone is not aimed at")
end

-- =============================================================================
-- F3 — a corpse is never aimed at (the client keeps a dead unit selected)
-- =============================================================================

do
    reset()
    _me.get_direction = function() return { x = -1, y = 0, z = 0 } end
    local corpse = unit({ alive = false, pos = { x = 10, y = 0, z = 0 } })

    assert(facing.ensure(_me, corpse) == false, "F3a FAIL: a dead unit must not be aimed at")
    assert(lock_count() == 0, "F3b FAIL: aiming at a corpse is what turned the player on the body")
    assert(_pauses == 0, "F3c FAIL: movement must not be paused for a corpse")

    -- A lootable body is the same case reached a different way: can_be_looted() true.
    reset()
    local looted = unit({ pos = { x = 10, y = 0, z = 0 }, lootable = true })
    assert(facing.ensure(_me, looted) == false, "F3d FAIL: a lootable corpse must not be aimed at")
    assert(lock_count() == 0, "F3e FAIL: no lock for a lootable body")
    print("  F3 PASS: dead and lootable units are never aimed at")
end

-- =============================================================================
-- F4 — the throttle is not a dead end: a new target outside the interval still aims
-- =============================================================================

do
    reset()
    _me.get_direction = function() return { x = -1, y = 0, z = 0 } end
    local first = unit({ pos = { x = 10, y = 0, z = 0 } })
    local second = unit({ pos = { x = 0, y = 10, z = 0 } })   -- north, still outside the cone

    facing.ensure(_me, first)
    local before = _time
    facing.ensure(_me, second)
    assert(lock_count() == 1, "F4a FAIL: a second lock inside the interval would resume the servo")
    _time = before + 3.1
    facing.ensure(_me, second)
    assert(lock_count() == 2, "F4b FAIL: the new target must be aimable after the interval")
    assert(_locks[2].target == second, "F4c FAIL: the lock must be aimed at the new target")
    print("  F4 PASS: the interval throttles re-aims without wedging the aimer")
end

-- =============================================================================
-- F5 — a client that cannot answer is not a crash, and not a permanent no-aim
-- =============================================================================

do
    reset()
    _me.get_direction = function() error("no direction on this client") end
    local mob = unit({ pos = { x = 10, y = 0, z = 0 } })

    assert(facing.ensure(_me, mob) == true,
        "F5a FAIL: without a readable facing the rule degrades to 'aim once per interval', not to " ..
        "'never aim' — a character that cannot turn cannot cast")
    assert(lock_count() == 1, "F5b FAIL: expected one lock")
    for _ = 1, 5 do facing.ensure(_me, mob) end
    assert(lock_count() == 1, "F5c FAIL: still only one lock per interval without a facing read")

    -- No movement_handler at all: still no error.
    reset()
    _me.get_direction = function() return { x = -1, y = 0, z = 0 } end
    package.loaded["common/utility/movement_handler"] = nil
    local ok = pcall(facing.ensure, _me, mob)
    assert(ok, "F5d FAIL: a build without movement_handler must not raise")
    print("  F5 PASS: unreadable facing and a missing movement_handler both degrade safely")
end

print("PASS test_facing")
os.exit(0)
