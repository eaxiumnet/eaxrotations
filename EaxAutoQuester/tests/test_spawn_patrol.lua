-- What: shared/spawn_patrol.lua — where the bot walks to LOOK for its objective's mobs.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Live: twelve consecutive "IDLE: waiting for respawn (Lesser Rock Elementals)" minutes with
--      the bot standing still. The wait's only sensor was a 50yd `get_nearest_enemy` probe fired
--      every 5s from wherever the last kill happened, and the mob's other spawn points — 18 of
--      them, spread over ~250yd (measured from the shipped cMaNGOS index) — were outside it by
--      construction. Nothing ever moved, so "waiting for respawn" was "waiting at one corpse".
--      Each scenario here pins one rule of the replacement search:
--        P1 the goal's mob is resolved from its plural Zygor name and its own spawn points are the
--           candidates, nearest first, with the terrain fix-up applied once (not per tick)
--        P2 standing on a point marks it searched and the sweep moves to a different one
--        P3 a point the bot cannot reach costs ONE leg (progress-based retirement), not the search
--        P4 the pull gate's hold outranks the search (a retreat is a decision not to enter a camp)
--        P5 a goal with nothing to search is latched, not re-searched every tick
--        P6 the Zygor step's own path is the fallback when the name resolves to nothing
--        P7 spawn points on another map are never walked to
--        P8 a different goal is a different search (fresh candidates, cleared marks)
--        P9 the spawn index is asked once per goal, not per tick
--        P10 a completed sweep rebuilds on a throttle, not on every tick
--        P11 a leg in flight is published once per interval, not every tick
--        P19-P22 the optional game-object index: no data leaves the sweep unchanged; an objective's
--           entry or name adds its coordinates, and the two entry namespaces merge
-- Safety: pure module + stubs; no client, no network, no file writes. The spawn index is the real
--      tracked one (EaxAutoQuester/npc_spawns), wrapped in counters.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local _time = 1000
local _map_id = 0
local _visible = {}
local _logs = {}

core = {
    time = function() return _time end,
    log = function() end,
    log_warning = function() end,
    get_map_id = function() return _map_id end,
    object_manager = {
        get_visible_objects = function() return _visible end,
        get_local_player = function() return nil end,
    },
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.set_warning = function() end

-- =============================================================================
-- Stubs (installed before the module that caches them is first used)
-- =============================================================================

-- The terrain fix-up is recorded and stubbed BEFORE any scenario runs: spawn_patrol caches the
-- fixer on its first success, so a stub installed later would never be reached (same rule the pull
-- gate's suite documents).
-- It returns a NEW table (identity is what proves the published point is the fixed one) whose z is
-- the input plus a marker: the candidate filter compares real 3D distance, so a stub that returned
-- a made-up height would silently change which spawn points count as "near the player".
local Z_MARKER = 0.5
local _fix_calls = 0
local _last_fixed = nil
package.loaded["waypoint_fixer_sylvanas"] = {
    fix_z = function(pos)
        _fix_calls = _fix_calls + 1
        _last_fixed = { x = pos and pos.x or 0, y = pos and pos.y or 0,
                        z = (pos and pos.z or 0) + Z_MARKER }
        return _last_fixed
    end,
}

-- The real spawn index, wrapped in counters so "asked once per goal, not once per tick" is
-- observable. The optional object index is explicitly unavailable for the pre-AQ-P4-1 scenarios:
-- a developer who has generated the ignored build output must still get the same old contract.
package.loaded["object_spawns"] = { available = false }
local real_spawns = require("npc_spawns")
local _spawn_queries = 0
local _name_queries = 0
package.loaded["npc_spawns"] = {
    find_npc_spawns = function(npc_id)
        _spawn_queries = _spawn_queries + 1
        return real_spawns.find_npc_spawns(npc_id)
    end,
    find_npc_ids_by_name = function(name)
        _name_queries = _name_queries + 1
        return real_spawns.find_npc_ids_by_name(name)
    end,
}

local spawn_patrol = require("shared/spawn_patrol")
local pull_safety = require("shared/pull_safety")
local nav_destination = require("shared/nav_destination")

-- =============================================================================
-- Fixtures
-- =============================================================================

local LESSER_ROCK_ELEMENTAL = 2735     -- the mob from the live log
local LESSER_CAMP = { x = -6648.3, y = -2554.05, z = 249.4 }   -- one of its own spawn points

local function player(o)
    o = o or {}
    return {
        get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
        get_health = function() return o.hp or 1000 end,
        get_max_health = function() return o.max_hp or 1000 end,
        get_power = function() return o.mana or 0 end,
        get_max_power = function() return o.max_mana or 0 end,
        is_in_combat = function() return false end,
        is_unit = function() return true end,
        is_dead = function() return false end,
        can_attack = function() return false end,
        get_movement_speed = function() return 0 end,
    }
end

local function mob(o)
    o = o or {}
    return {
        is_unit = function() return true end,
        is_dead = function() return false end,
        can_attack = function() return true end,
        get_position = function() return o.pos or { x = 0, y = 0, z = 0 } end,
        get_movement_speed = function() return 0 end,
        is_in_combat = function() return false end,
    }
end

local _waypoints = nil
local function ctx_for(o)
    o = o or {}
    return {
        me = o.me,
        now = o.now or _time,
        menu = o.menu,
        utils = {
            squared_distance = function(a, b)
                local dx = (a.x or 0) - (b.x or 0)
                local dy = (a.y or 0) - (b.y or 0)
                local dz = (a.z or 0) - (b.z or 0)
                return dx * dx + dy * dy + dz * dz
            end,
        },
        zygor = {
            get_step_waypoints_world = function() return _waypoints end,
        },
        debug_log = function(msg) _logs[#_logs + 1] = tostring(msg) end,
    }
end

--- The spawn points the patrol SHOULD hold for this mob on this map within the build radius:
--- computed from the raw index, independently of the module under test.
local BUILD_RADIUS = 400
local function expected_points(npc_id, from, map_id)
    local out = {}
    local maps = real_spawns.find_npc_spawns(npc_id)
    for i = 1, #maps do
        local m = maps[i]
        if m.map_id == map_id then
            local dx = m.x - (from.x or 0)
            local dy = m.y - (from.y or 0)
            local dz = (m.z or 0) - (from.z or 0)
            if dx * dx + dy * dy + dz * dz <= BUILD_RADIUS * BUILD_RADIUS then
                out[#out + 1] = m
            end
        end
    end
    return out
end

local function seen_count(shared)
    local n = 0
    for _ in pairs(shared._patrol_seen or {}) do n = n + 1 end
    return n
end

local function same_xy(a, b)
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy < 0.01
end

-- =============================================================================
-- P1 — a plural, name-only goal resolves to its own spawn points; nearest first
-- =============================================================================
do
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    _time = 1000
    local ctx = ctx_for({ me = me, now = _time })
    _fix_calls = 0

    local expected = expected_points(LESSER_ROCK_ELEMENTAL, LESSER_CAMP, _map_id)
    assert(#expected > 1, "P1a FAIL: fixture error — expected several nearby spawn points, got " ..
        tostring(#expected))

    local point = spawn_patrol.next_point(shared, ctx, goal)
    assert(point ~= nil, "P1b FAIL: a name-only goal must resolve to its mob's spawn points")
    assert(#shared._patrol_points == #expected,
        "P1c FAIL: candidate list must be the mob's own same-map spawn points within " ..
        tostring(BUILD_RADIUS) .. "yd: expected " .. tostring(#expected) .. ", got " ..
        tostring(#shared._patrol_points))

    -- Nearest first — and the point the player is STANDING ON counts as searched, so the first leg
    -- is the nearest unsearched candidate, not the spawn point underfoot.
    local nearest, nearest_sq = nil, nil
    local second, second_sq = nil, nil
    for i = 1, #expected do
        local dx = expected[i].x - LESSER_CAMP.x
        local dy = expected[i].y - LESSER_CAMP.y
        local dz = (expected[i].z or 0) - LESSER_CAMP.z
        local d = dx * dx + dy * dy + dz * dz
        if nearest_sq == nil or d < nearest_sq then
            second, second_sq = nearest, nearest_sq
            nearest, nearest_sq = expected[i], d
        elseif second_sq == nil or d < second_sq then
            second, second_sq = expected[i], d
        end
    end
    assert(nearest_sq < 1.0,
        "P1d FAIL: fixture error — the player should be standing on a spawn point")
    assert(same_xy(point, second),
        "P1e FAIL: the first leg must be the nearest unsearched candidate, got " ..
        tostring(point.x) .. "," .. tostring(point.y))
    assert(shared._patrol_seen[1],
        "P1f FAIL: the spawn point underfoot must be marked searched at choice time")

    -- Terrain fix-up applied: the published point IS the table the fixer returned, and it was asked
    -- once per point rather than per tick (the point underfoot was never walked, so never fixed).
    assert(point == _last_fixed,
        "P1g FAIL: the published point must be the fixed one, not the raw spawn coordinate")
    assert(point.z == second.z + Z_MARKER,
        "P1h FAIL: the fixed height must be what is published, got z=" .. tostring(point.z))
    assert(_fix_calls == 1,
        "P1i FAIL: the fix-up must run once per point, got " .. tostring(_fix_calls) .. " calls")

    -- The index was walked for the name variants (the plural Zygor writes, then the singular the
    -- world uses — the expansion is because the plural does NOT resolve against world names) and
    -- once for the spawns of the entry it found.
    assert(_name_queries == 2 and _spawn_queries == 1,
        "P1j FAIL: index queries should be 2 name / 1 spawn, got " .. tostring(_name_queries) .."/" ..
        tostring(_spawn_queries))
    print("  P1 PASS: plural name-only goal -> " .. tostring(#expected) ..
        " spawn points, nearest walked to, Z fixed once")
end

-- =============================================================================
-- P2 — standing on a point marks it searched and the sweep moves on
-- =============================================================================
do
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = 1100 })
    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first, "P2a FAIL: expected a first point")
    -- The point underfoot was searched at choice time; the leg is the next one out.
    assert(seen_count(shared) == 1,
        "P2b FAIL: the spawn point underfoot must already be marked, got " ..
        tostring(seen_count(shared)))

    -- Arrive: the player is now standing on it.
    me = player({ pos = { x = first.x, y = first.y, z = first.z } })
    ctx = ctx_for({ me = me, now = 1101 })
    local second = spawn_patrol.next_point(shared, ctx, goal)
    assert(second, "P2c FAIL: the sweep must continue after a point has been searched")
    assert(not same_xy(first, second),
        "P2d FAIL: a searched point must not be issued again within the same sweep")
    local expected_marks = seen_count(shared)
    assert(expected_marks == 2,
        "P2e FAIL: arrival must mark the walked point too, got " .. tostring(expected_marks))

    -- Walk the whole sweep out. Every arrival must produce a point that has not been searched yet:
    -- a repeat inside one sweep is what turns a search into pacing between two spawn points.
    local candidates = #shared._patrol_points
    local issued = {}
    local key0 = string.format("%.2f:%.2f", first.x, first.y)
    issued[key0] = true
    local point = second
    local live = candidates - expected_marks     -- arrivals left before the sweep completes
    for i = 1, live do
        assert(point, "P2f FAIL: the sweep ended after " .. tostring(i) .. " of " ..
            tostring(live) .. " searchable points")
        local key = string.format("%.2f:%.2f", point.x, point.y)
        if i < live then
            assert(not issued[key],
                "P2g FAIL: point " .. key .. " was issued twice inside one sweep")
        end
        issued[key] = true
        me = player({ pos = { x = point.x, y = point.y, z = point.z } })
        ctx = ctx_for({ me = me, now = 1102 + i })
        point = spawn_patrol.next_point(shared, ctx, goal)
        if i < live then
            assert(seen_count(shared) == expected_marks + i,
                "P2h FAIL: after " .. tostring(i) .. " more arrivals " ..
                tostring(expected_marks + i) .. " points must be marked searched, got " ..
                tostring(seen_count(shared)))
        end
    end

    -- Every candidate searched: the search restarts around the player instead of ending, which is
    -- what would leave the bot standing still again — the failure this whole module exists for.
    assert((shared._patrol_sweeps or 0) == 1,
        "P2i FAIL: a completed sweep must restart the search (sweeps=" ..
        tostring(shared._patrol_sweeps) .. ")")
    assert(point ~= nil, "P2j FAIL: the restarted sweep must issue a point")
    print("  P2 PASS: arrival marks the point searched; the sweep visits every spawn point once " ..
        "and then restarts")
end

-- =============================================================================
-- P3 — a point the bot cannot reach costs one leg, not the search
-- =============================================================================
do
    -- Standing away from the camp, so the first issued point is a walk rather than an arrival.
    local start = { x = LESSER_CAMP.x + 150, y = LESSER_CAMP.y, z = LESSER_CAMP.z }
    local me = player({ pos = start })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = 1200 })
    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first, "P3a FAIL: expected a first point")
    local leg = shared._patrol_target_i
    assert(leg ~= nil, "P3a FAIL: the issued leg must be recorded")

    -- 3s later: still walking it — no movement, but not yet a failure.
    ctx = ctx_for({ me = me, now = 1203 })
    spawn_patrol.next_point(shared, ctx, goal)
    assert(seen_count(shared) == 0,
        "P3b FAIL: a leg 3s in must not be retired yet")
    assert(shared._patrol_target_i == leg,
        "P3b FAIL: a leg 3s in must still be the leg being walked")

    -- 16s with no progress: the leg is retired and another point is tried.
    ctx = ctx_for({ me = me, now = 1216 })
    local next_point = spawn_patrol.next_point(shared, ctx, goal)
    assert(shared._patrol_seen[leg] == true,
        "P3c FAIL: a leg with no movement for 16s must be retired")
    assert(seen_count(shared) == 1,
        "P3d FAIL: exactly the stuck leg must be marked searched, got " ..
        tostring(seen_count(shared)))
    assert(next_point and not same_xy(next_point, first),
        "P3e FAIL: the search must move to a different point after an unreachable leg")

    -- The retired point does not come back this sweep: a spawn point inside geometry would
    -- otherwise be tried every 15s forever while the rest of the camp is never searched.
    local came_back = false
    local p = next_point
    local step = 0
    while p and step < #shared._patrol_points do
        if same_xy(p, first) then came_back = true break end
        me = player({ pos = { x = p.x, y = p.y, z = p.z } })
        step = step + 1
        ctx = ctx_for({ me = me, now = 1216 + step })
        p = spawn_patrol.next_point(shared, ctx, goal)
    end
    assert(not came_back,
        "P3f FAIL: an unreachable point must not be re-issued inside the same sweep")
    print("  P3 PASS: an unreachable spawn point costs one leg, not the search")
end

-- =============================================================================
-- P4 — the pull gate's hold outranks the search
-- =============================================================================
do
    pull_safety.reset()
    _time = 1300
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z },
                        hp = 1000, max_hp = 1000, mana = 100, max_mana = 1000 })   -- 10% mana
    local enemy = mob({ pos = { x = LESSER_CAMP.x + 10, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    _visible = { enemy }
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = _time })

    assert(pull_safety.gate(ctx, shared, enemy) == true,
        "P4a FAIL: a caster at 10% mana must refuse this pull")
    assert(pull_safety.holding(ctx) == true, "P4b FAIL: the gate must arm a hold")
    assert(spawn_patrol.next_point(shared, ctx, goal) == nil,
        "P4c FAIL: while the gate holds, the search must not walk toward the camp")

    -- The hold is the reason, not something else: released, the same scene walks again.
    pull_safety.reset()
    assert(pull_safety.holding(ctx) == false, "P4d FAIL: reset must clear the hold")
    assert(spawn_patrol.next_point(shared, ctx, goal) ~= nil,
        "P4e FAIL: with the hold released the search must resume")
    _visible = {}
    print("  P4 PASS: the gate's hold suppresses the search and releasing it resumes it")
end

-- =============================================================================
-- P5 — a goal with nothing to search is latched, not re-searched every tick
-- =============================================================================
do
    _time = 1400
    _waypoints = nil
    local me = player({ pos = { x = 0, y = 0, z = 0 } })
    local shared = {}
    local goal = { type = "area", target = "No Such Mob Anywhere", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = _time })
    local before_spawns, before_names = _spawn_queries, _name_queries

    assert(spawn_patrol.next_point(shared, ctx, goal) == nil,
        "P5a FAIL: an unknown objective has nothing to search")
    assert(shared._patrol_points == false,
        "P5b FAIL: the miss must be latched (false), not left as nil for a rebuild each tick")
    local after_spawns, after_names = _spawn_queries, _name_queries

    for i = 1, 20 do
        ctx = ctx_for({ me = me, now = _time + i * 0.2 })
        assert(spawn_patrol.next_point(shared, ctx, goal) == nil,
            "P5c FAIL: a latched miss must keep returning nothing")
    end
    assert(_spawn_queries == after_spawns and _name_queries == after_names,
        "P5d FAIL: a latched miss must not re-walk the index (spawns " ..
        tostring(before_spawns) .. "->" .. tostring(_spawn_queries) .. ", names " ..
        tostring(before_names) .. "->" .. tostring(_name_queries) .. ")")
    print("  P5 PASS: nothing to search is latched — the index is walked once, then never again")
end

-- =============================================================================
-- P6 — the Zygor step's own path is the fallback
-- =============================================================================
do
    _time = 1500
    _waypoints = {
        { x = 100, y = 100, z = 10 },
        { x = 160, y = 100, z = 12 },
    }
    local me = player({ pos = { x = 100, y = 100, z = 10 } })
    local shared = {}
    local goal = { type = "area", target = "No Such Mob Anywhere", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = _time })

    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first ~= nil, "P6a FAIL: the guide's own path must be walked when nothing else resolves")
    assert(same_xy(first, _waypoints[1]) or same_xy(first, _waypoints[2]),
        "P6b FAIL: the point must be one of the step's waypoints, got " ..
        tostring(first.x) .. "," .. tostring(first.y))

    -- Arrive → the other waypoint, not the same one again.
    me = player({ pos = { x = first.x, y = first.y, z = first.z } })
    ctx = ctx_for({ me = me, now = _time + 1 })
    local second = spawn_patrol.next_point(shared, ctx, goal)
    assert(second and not same_xy(second, first),
        "P6c FAIL: the guide path must be swept too, not parked on one waypoint")
    _waypoints = nil
    print("  P6 PASS: the Zygor step waypoints are the fallback path, swept the same way")
end

-- =============================================================================
-- P7 — spawn points on another map are never walked to
-- =============================================================================
do
    _time = 1600
    local previous_map = _map_id
    _map_id = 530                                  -- Outland: this mob does not spawn there
    _waypoints = { { x = 7, y = 8, z = 9 } }
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = _time })

    local point = spawn_patrol.next_point(shared, ctx, goal)
    assert(point ~= nil, "P7a FAIL: with no spawns on this map the guide path must still be walked")
    assert(same_xy(point, _waypoints[1]),
        "P7b FAIL: the point must come from the guide path, not from another map's spawns, got " ..
        tostring(point.x) .. "," .. tostring(point.y))
    -- Explicitly: none of the issued candidates is a spawn coordinate of the mob.
    local maps = real_spawns.find_npc_spawns(LESSER_ROCK_ELEMENTAL)
    for i = 1, #(shared._patrol_points or {}) do
        for j = 1, #maps do
            assert(not same_xy(shared._patrol_points[i], maps[j]),
                "P7c FAIL: a spawn point from map " .. tostring(maps[j].map_id) ..
                " must not be walked to from map " .. tostring(_map_id))
        end
    end
    _map_id = previous_map
    _waypoints = nil
    print("  P7 PASS: another map's spawn points are excluded from the search")
end

-- =============================================================================
-- P8 — a different goal is a different search
-- =============================================================================
do
    _time = 1700
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local ctx = ctx_for({ me = me, now = _time })
    local first_goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    local first = spawn_patrol.next_point(shared, ctx, first_goal)
    assert(first, "P8a FAIL: expected a first point")
    local first_count = #shared._patrol_points
    local first_points = shared._patrol_points
    local baseline = seen_count(shared)     -- the spawn point underfoot, marked at choice time

    -- Search that point, so the old goal's mark exists before the goal changes.
    me = player({ pos = { x = first.x, y = first.y, z = first.z } })
    ctx = ctx_for({ me = me, now = _time + 1 })
    spawn_patrol.next_point(shared, ctx, first_goal)
    assert(seen_count(shared) == baseline + 1,
        "P8b FAIL: arriving must mark the point searched, got " .. tostring(seen_count(shared)) ..
        " (baseline " .. tostring(baseline) .. ")")

    -- A new objective: same NPC id, different target string, and (deliberately) the same mob's
    -- spawns so only the RESET is observable.
    local second_goal = { type = "kill", target = "Greater Rock Elemental", npc_id = 2735 }
    local second = spawn_patrol.next_point(shared, ctx, second_goal)
    assert(second ~= nil, "P8c FAIL: a new goal must build its own candidates")
    assert(baseline + 1 >= 2, "P8a2 FAIL: fixture error - expected marks from the first goal")
    assert(shared._patrol_name == second_goal.target,
        "P8d FAIL: the search must be re-identified with the new goal, got " ..
        tostring(shared._patrol_name))
    assert(shared._patrol_points ~= first_points,
        "P8e FAIL: the new goal's candidates must be rebuilt, not inherited")
    -- The only mark the new search can carry is the spawn point the player is standing on (marked
    -- at choice time); nothing from the old goal's sweep survives.
    assert(seen_count(shared) <= 1,
        "P8f FAIL: the new goal's search must start fresh (old marks cleared), got " ..
        tostring(seen_count(shared)) .. " marks")
    -- The candidates are rebuilt for the new goal, around where the player is now.
    local expected_now = expected_points(2735, { x = first.x, y = first.y, z = first.z }, _map_id)
    assert(shared._patrol_points and #shared._patrol_points == #expected_now,
        "P8g FAIL: the new goal's candidates should be the mob's spawn points near the player " ..
        "(expected " .. tostring(#expected_now) .. ", got " ..
        tostring(shared._patrol_points and #shared._patrol_points) .. ")")
    print("  P8 PASS: a new goal resets the search (fresh candidates, cleared marks)")
end

-- =============================================================================
-- P9 — the spawn index is asked once per goal, not per tick
-- =============================================================================
do
    _time = 1800
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = _time })

    local spawns_before, names_before = _spawn_queries, _name_queries
    spawn_patrol.next_point(shared, ctx, goal)
    local spawns_after_build, names_after_build = _spawn_queries, _name_queries
    -- One spawn lookup, and one name resolution per expanded name variant (the expansion is
    -- "Lesser Rock Elementals" -> that plus "Lesser Rock Elemental").
    assert(spawns_after_build == spawns_before + 1,
        "P9a FAIL: building must look the mob's spawns up exactly once, got " ..
        tostring(spawns_after_build - spawns_before) .. " queries")
    local names_used = names_after_build - names_before
    assert(names_used >= 1 and names_used <= 2,
        "P9b FAIL: name resolution must be bounded by the name variants, got " ..
        tostring(names_used) .. " queries")

    -- 25 tick-path calls over 10s (no movement, so no arrival and no sweep completion).
    for i = 1, 25 do
        ctx = ctx_for({ me = me, now = _time + i * 0.4 })
        spawn_patrol.next_point(shared, ctx, goal)
    end
    assert(_spawn_queries == spawns_after_build and _name_queries == names_after_build,
        "P9c FAIL: the per-tick path must not re-walk the index (spawns " ..
        tostring(spawns_after_build) .. "->" .. tostring(_spawn_queries) .. ")")
    print("  P9 PASS: the index is walked once per goal; the tick path does none of it")
end

-- =============================================================================
-- P10 — a completed sweep rebuilds on a throttle, not on every tick
-- =============================================================================
-- The bot spends the whole wait standing on the last point it searched, and a rebuild walks the
-- spawn index from end to end; the wait's ticks must therefore not each rebuild. This is the case a
-- position-based guard got wrong both ways at once: it allowed a rebuild on every move (a two-point
-- camp ping-ponged forever) and blocked one at every other spot. A single-candidate goal makes the
-- rebuild the only thing that can change anything, so its count is the whole observable.
do
    _time = 2000
    _waypoints = { { x = 400, y = 400, z = 5 } }        -- one point: the bot is standing on it
    local me = player({ pos = { x = 400, y = 400, z = 5 } })
    local shared = {}
    local goal = { type = "kill", target = "Zz Spawn Patrol Probe", npc_id = 0 }
    local wp_calls = 0
    local function ctx_at(now)
        local ctx = ctx_for({ me = me, now = now })
        ctx.zygor = {
            get_step_waypoints_world = function()
                wp_calls = wp_calls + 1
                return _waypoints
            end,
        }
        return ctx
    end

    -- First call: the guide's path is built (1), the only candidate is the point underfoot so it is
    -- marked at choice time, and the sweep is already complete, so the rebuild spends (2).
    assert(spawn_patrol.next_point(shared, ctx_at(_time), goal) == nil,
        "P10a FAIL: a single spawn point underfoot leaves nothing to walk to")
    local built = wp_calls
    assert(built == 2, "P10b FAIL: expected the build plus one rebuild, got " .. tostring(built))
    assert((shared._patrol_sweeps or 0) == 1,
        "P10c FAIL: the rebuild must count as a sweep, got " .. tostring(shared._patrol_sweeps))

    -- 10 ticks over the next 4s, standing still: no rebuild.
    for i = 1, 10 do
        spawn_patrol.next_point(shared, ctx_at(_time + i * 0.4), goal)
    end
    assert(wp_calls == built,
        "P10d FAIL: 4s of ticks rebuilt the candidate list " .. tostring(wp_calls - built) .. " time(s)")

    -- Past the throttle: the sweep restarts (a search that keeps looking, not a bot that parks).
    spawn_patrol.next_point(shared, ctx_at(_time + 6), goal)
    assert(wp_calls == built + 1,
        "P10e FAIL: after the throttle the sweep must rebuild, got " ..
        tostring(wp_calls - built) .. " rebuild(s)")
    assert((shared._patrol_sweeps or 0) == 2,
        "P10f FAIL: the second rebuild must count as a second sweep, got " ..
        tostring(shared._patrol_sweeps))
    print("  P10 PASS: a completed sweep rebuilds on a throttle, not on every tick")
    _waypoints = nil
end

-- =============================================================================
-- P11 — a leg in flight is published once per interval, not every tick
-- =============================================================================
-- The states hand the walk to the client and the client owns it from there; re-publishing the same
-- destination on every tick restarts the path every frame. The module therefore answers nil while a
-- leg is in flight and re-publishes after REISSUE_SECONDS (which is also what recovers the search
-- when a navigation died without the module being told).
do
    _time = 2100
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = 0 }

    local first = spawn_patrol.next_point(shared, ctx_for({ me = me, now = _time }), goal)
    assert(first, "P11a FAIL: expected a first leg")
    local issued = shared._patrol_issued_at

    -- The same tick-and-a-bit, still walking: nothing is re-published.
    for i = 1, 3 do
        assert(spawn_patrol.next_point(shared, ctx_for({ me = me, now = _time + i * 0.4 }), goal) == nil,
            "P11b FAIL: a leg in flight must not be re-published every tick")
    end
    assert(shared._patrol_issued_at == issued,
        "P11c FAIL: the re-issue clock must not move while the leg is refused")

    -- Past the interval: the same leg is published again.
    local again = spawn_patrol.next_point(shared, ctx_for({ me = me, now = _time + 1.6 }), goal)
    assert(again and same_xy(again, first),
        "P11d FAIL: after the interval the leg must be published again")
    assert(shared._patrol_issued_at == _time + 1.6,
        "P11e FAIL: publishing must stamp the re-issue clock, got " ..
        tostring(shared._patrol_issued_at))
    print("  P11 PASS: a leg in flight is published once per interval, not every tick")
end

-- =============================================================================
-- P12 — the goal's own id is what the search is scoped to, not its visible name
-- Three Rock Elemental variants share the words: 92 "Rock Elemental" (the only one that drops
-- Large Stone Slab), 2735 "Lesser Rock Elemental" and 2736 "Greater Rock Elemental". The guide
-- tells them apart with the `##id` on every kill goal, so a step change between two of them must
-- re-scope the walk; a search keyed on the name alone would keep the previous mob's camp.
-- =============================================================================
do
    _time = 2200
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local slab = { type = "kill", target = "Rock Elementals", npc_id = 0, targetid = 92 }
    local greater = { type = "kill", target = "Rock Elementals", npc_id = 0, targetid = 2736 }

    -- (a) The id decides the camp, and nothing has to be guessed from the name to know it.
    local queries_before, names_before = _spawn_queries, _name_queries
    local leg = spawn_patrol.next_point(shared, ctx_for({ me = me, now = _time }), slab)
    assert(leg, "P12a FAIL: expected a first leg for the mob the goal names")
    local camp = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z }
    local expected = expected_points(92, camp, _map_id)
    assert(#expected > 0, "P12b FAIL: fixture error — no Rock Elemental spawns near this camp")
    assert(#shared._patrol_points == #expected,
        "P12c FAIL: the candidates must be the goal mob's own spawn points (expected " ..
        tostring(#expected) .. ", got " .. tostring(#shared._patrol_points) .. ")")
    assert(_name_queries == names_before,
        "P12d FAIL: with an id there is nothing to guess from the name, but " ..
        tostring(_name_queries - names_before) .. " name lookup(s) ran")
    assert(_spawn_queries == queries_before + 1,
        "P12e FAIL: expected exactly one spawn-index lookup for the goal's id")
    local slab_points = shared._patrol_points

    -- (b) A different mob behind the SAME two words re-scopes the search. Greater Rock Elementals
    -- have no spawn point within the search radius of this camp, so the walk becomes one leg toward
    -- their camp — and never one of 92's points.
    local leg2 = spawn_patrol.next_point(shared, ctx_for({ me = me, now = _time + 1 }), greater)
    assert(shared._patrol_points ~= slab_points,
        "P12f FAIL: a new goal must rebuild the candidate list, not reuse the previous mob's")
    assert(leg2, "P12g FAIL: a mob whose camp is far away must still produce a leg toward it")
    local in_slab = false
    for i = 1, #shared._patrol_points do
        for j = 1, #slab_points do
            if same_xy(shared._patrol_points[i], slab_points[j]) then in_slab = true break end
        end
    end
    assert(not in_slab,
        "P12h FAIL: the new goal's search still holds the previous mob's spawn points")

    -- (c) And back: the search re-scopes to the first mob's camp again.
    local leg3 = spawn_patrol.next_point(shared, ctx_for({ me = me, now = _time + 2 }), slab)
    assert(leg3 and #shared._patrol_points == #expected,
        "P12i FAIL: switching back must rebuild the first mob's camp, got " ..
        tostring(#shared._patrol_points) .. " candidate(s)")
    print("  P12 PASS: the search is scoped to the goal's own id and re-scopes when the goal changes")
end

-- =============================================================================
-- P13 — the guide's step path joins the candidates on a kill goal with index spawns
-- =============================================================================
-- Live shape: a mob with one or two nearby spawn points paces between them while the guide's
-- objective path (the route the author chose for this quest) is never walked. The merge makes
-- both the search.
do
    _time = 1700
    -- The player stands in the mob's own camp; the guide's path for this step runs through two
    -- points the index knows nothing about.
    _waypoints = {
        { x = -6650.0, y = -2500.0, z = 0 },
        { x = -6600.0, y = -2450.0, z = 0 },
    }
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = LESSER_ROCK_ELEMENTAL }
    local ctx = ctx_for({ me = me, now = _time })

    -- The candidates must hold BOTH sources: every index spawn within the radius plus the two
    -- step waypoints, so the sweep covers the guide's path instead of pacing the spawns.
    local expected_idx = #expected_points(LESSER_ROCK_ELEMENTAL, LESSER_CAMP, _map_id)
    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first ~= nil, "P13a FAIL: a kill goal with index spawns must still search")
    assert(#shared._patrol_points == expected_idx + 2,
        "P13b FAIL: candidates must be index spawns PLUS the guide's step waypoints: expected " ..
        tostring(expected_idx + 2) .. ", got " .. tostring(#shared._patrol_points))
    local has_wp1, has_wp2 = false, false
    for i = 1, #shared._patrol_points do
        if same_xy(shared._patrol_points[i], _waypoints[1]) then has_wp1 = true end
        if same_xy(shared._patrol_points[i], _waypoints[2]) then has_wp2 = true end
    end
    assert(has_wp1 and has_wp2,
        "P13c FAIL: both guide waypoints must be candidates alongside the spawns")
    print("  P13 PASS: the guide's step path joins a kill goal's search beside its spawn points")
end

-- =============================================================================
-- P14 — dedup by place: a waypoint standing on a spawn point is not a second leg
-- =============================================================================
do
    _time = 1750
    -- Waypoint 1 IS the camp spawn (same place: identical x,y after the 0.1yd grid), waypoint 2
    -- is a different place.
    _waypoints = {
        { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = 0 },
        { x = LESSER_CAMP.x + 40, y = LESSER_CAMP.y + 10, z = 0 },
    }
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = LESSER_ROCK_ELEMENTAL }
    local ctx = ctx_for({ me = me, now = _time })

    local expected_idx = #expected_points(LESSER_ROCK_ELEMENTAL, LESSER_CAMP, _map_id)
    spawn_patrol.next_point(shared, ctx, goal)
    assert(#shared._patrol_points == expected_idx + 1,
        "P14a FAIL: the duplicate place must be merged, not walked twice: expected " ..
        tostring(expected_idx + 1) .. ", got " .. tostring(#shared._patrol_points))
    -- And the surviving entry for that place is the spawn point's Z (the index's terrain height),
    -- because spawn points are added first and win the tie. Compared against the RAW index z —
    -- the fixture constant is rounded for readability.
    local camp_z_ok = false
    local raw_z = real_spawns.find_npc_spawns(LESSER_ROCK_ELEMENTAL)[1].z
    for i = 1, #shared._patrol_points do
        local p = shared._patrol_points[i]
        if same_xy(p, LESSER_CAMP) then
            if math.abs(p.z - raw_z) < 0.01 then camp_z_ok = true end
        end
    end
    assert(camp_z_ok,
        "P14b FAIL: the spawn point's own Z must win the tie, got no camp point with its Z")
    print("  P14 PASS: a guide waypoint on a spawn point merges into one candidate")
end

-- =============================================================================
-- P15 — no waypoints, no merge: an index-only search is unchanged
-- =============================================================================
do
    _time = 1800
    _waypoints = nil
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elementals", npc_id = LESSER_ROCK_ELEMENTAL }
    local ctx = ctx_for({ me = me, now = _time })

    local expected_idx = #expected_points(LESSER_ROCK_ELEMENTAL, LESSER_CAMP, _map_id)
    local point = spawn_patrol.next_point(shared, ctx, goal)
    assert(point ~= nil, "P15a FAIL: an index-only search must still run")
    assert(#shared._patrol_points == expected_idx,
        "P15b FAIL: with no step waypoints the candidate list must be exactly the index spawns: " ..
        "expected " .. tostring(expected_idx) .. ", got " .. tostring(#shared._patrol_points))
    print("  P15 PASS: without step waypoints the search is index-only, as before")
end

-- =============================================================================
-- P16 — a waypoint under the player is searched, not published as a 0yd leg
-- The guide's step waypoints come out of the map conversion with z=0, and the
-- bot's terrain is not at 0. A 3D arrive test therefore read the waypoint the
-- player was standing on as hundreds of yards away and published it as a leg.
-- Live: "SPAWN PATROL: searching spawn point 5/5 (0yd)", then 15s later "spawn
-- point 2 unreachable" — the sweep spending its life on places already covered.
-- =============================================================================
do
    _time = 1900
    _waypoints = { { x = 0, y = 0, z = 0 } }
    local me = player({ pos = { x = 0, y = 0, z = 250 } })
    local shared = {}
    local goal = { type = "area", target = "Ogre Remains", npc_id = 233818 }
    local ctx = ctx_for({ me = me, now = _time })
    local log_start = #_logs

    local point = spawn_patrol.next_point(shared, ctx, goal)
    assert(point == nil,
        "P16a FAIL: the only candidate is under the player, so there is nothing to walk to, got x=" ..
        tostring(point and point.x))
    assert(shared._patrol_seen[1] == true,
        "P16b FAIL: a candidate the player is standing on must be marked searched at choice time")
    for i = log_start + 1, #_logs do
        assert(not _logs[i]:find("searching spawn point", 1, true),
            "P16c FAIL: no leg may be published for a place already covered, got: " .. _logs[i])
    end
    print("  P16 PASS: a step waypoint under the player is searched, not walked (0yd leg is gone)")
end

-- =============================================================================
-- P17 — a place the client refused is not offered again
-- nav_destination owns the verdict "the client could not walk to this place".
-- Offering it back spends every pass on the same point and the rest of the
-- step's path is never covered — the failure this module exists to end.
-- =============================================================================
do
    _time = 1950
    _waypoints = { { x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 } }
    local me = player({ pos = { x = 0, y = 0, z = 250 } })
    local shared = {}
    local goal = { type = "area", target = "Ogre Remains", npc_id = 233818 }
    local ctx = ctx_for({ me = me, now = _time })
    local log_start = #_logs

    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first and math.abs(first.x - 50) < 0.01,
        "P17a FAIL: expected the one walkable candidate, got " .. tostring(first and first.x))
    nav_destination.mark_unreachable(shared, _time + 1, first)

    -- 17s with no movement: the leg ends, the sweep rebuilds, and the refused
    -- place must not come back from the index or the waypoint list.
    ctx = ctx_for({ me = me, now = _time + 17 })
    local next_point = spawn_patrol.next_point(shared, ctx, goal)
    assert(next_point == nil,
        "P17b FAIL: a refused place must not be re-offered after the rebuild, got x=" ..
        tostring(next_point and next_point.x))
    local logged_unreachable = false
    for i = log_start + 1, #_logs do
        if _logs[i]:find("unreachable", 1, true) then logged_unreachable = true end
    end
    assert(logged_unreachable,
        "P17c FAIL: the leg the client refused must be reported as unreachable")
    print("  P17 PASS: a refused place is retired from the search and reported as unreachable")
end

-- =============================================================================
-- P18 — a leg that merely ended is not called unreachable
-- The same 17s timeout, with no refusal on record: the walk ended short, which
-- is not a fault the search should go looking for.
-- =============================================================================
do
    _time = 2000
    _waypoints = { { x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 } }
    local me = player({ pos = { x = 0, y = 0, z = 250 } })
    local shared = {}
    local goal = { type = "area", target = "Ogre Remains", npc_id = 233818 }
    local ctx = ctx_for({ me = me, now = _time })
    local log_start = #_logs

    assert(spawn_patrol.next_point(shared, ctx, goal),
        "P18a FAIL: expected a first leg")
    ctx = ctx_for({ me = me, now = _time + 17 })
    spawn_patrol.next_point(shared, ctx, goal)

    local logged = ""
    for i = log_start + 1, #_logs do
        if _logs[i]:find("trying another", 1, true) then logged = _logs[i] end
    end
    assert(logged:find("walk ended short", 1, true),
        "P18b FAIL: a leg with no refusal on record must not be reported unreachable, got: " .. logged)
    print("  P18 PASS: a leg that ended short is reported as such, not as a nav failure")
end

-- =============================================================================
-- AQ-P4-1 — the quest OBJECT index, in both of its states.
-- The accessor ships without its generated data, so P19 pins the state a fresh checkout is in:
-- an object-shaped goal knows nothing but the guide's waypoints, exactly as before. P20-P22 then
-- install the data and pin the capability that was missing: an objective game's entry resolves to
-- the coordinates it spawns at, so the sweep walks to the objective instead of around the camp.
-- =============================================================================

-- P19 — no object data: unchanged behaviour, and the precondition is asserted rather than assumed
do
    _time = 2100
    _waypoints = { { x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 } }
    local me = player({ pos = { x = 0, y = 0, z = 250 } })
    local shared = {}
    local goal = { type = "area", target = "Ogre Remains", npc_id = 233818 }
    local ctx = ctx_for({ me = me, now = _time })

    assert(package.loaded["object_spawns"].available == false,
        "P19a FAIL: scene error — this scenario is the no-data state, so the index must be " ..
        "unavailable (did an earlier scenario install a fixture?)")
    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first and math.abs(first.x - 50) < 0.01,
        "P19b FAIL: without object data the sweep must be the one it always was — the step's " ..
        "waypoints — got x=" .. tostring(first and first.x))
    assert(#shared._patrol_points == 2,
        "P19c FAIL: only the two step waypoints may be candidates with no index data, got " ..
        tostring(#shared._patrol_points))
    print("  P19 PASS: with no object data the sweep is unchanged (step waypoints only)")
end

-- The generated data, at a size a test can read: the live entry, a lookalike name, and one entry
-- that deliberately shares a number with a creature — the two namespaces are separate, which is
-- why the sweep has to ask both.
package.loaded["object_spawns/manifest"] = {
    chunk_count = 1,
    entry_count = 3,
    generated_from = "test fixture",
}
package.loaded["object_spawns/chunk_000"] = {
    by_entry = {
        ["233818"] = {
            name = "Ogre Remains",
            maps = {
                { map_id = 0, x = 60, y = 0, z = 5 },
                { map_id = 0, x = 90, y = 0, z = 5 },
            },
        },
        ["190000"] = {
            name = "Ogre Remains Cache",
            maps = { { map_id = 0, x = 70, y = 40, z = 5 } },
        },
        ["2735"] = {
            name = "Rock Elemental Cache",
            maps = { { map_id = 0, x = LESSER_CAMP.x + 300, y = LESSER_CAMP.y, z = 5 } },
        },
    },
}
package.loaded["object_spawns"] = nil
local object_spawns = require("object_spawns")
assert(object_spawns.reload() == true, "P20a FAIL: scene error — the fixture must load")
package.loaded["shared/spawn_patrol"] = nil
spawn_patrol = require("shared/spawn_patrol")

-- P20 — the goal's own id, asked of the object index, is the sweep's candidate list
do
    _time = 2200
    _waypoints = nil
    local me = player({ pos = { x = 0, y = 0, z = 0 } })
    local shared = {}
    local goal = { type = "area", target = "Ogre Remains", npc_id = 233818 }   -- the live goal shape
    local ctx = ctx_for({ me = me, now = _time })

    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first and math.abs(first.x - 60) < 0.01,
        "P20b FAIL: the nearest of the objective's own spawn points must be the first leg, got " ..
        "x=" .. tostring(first and first.x))
    assert(#shared._patrol_points == 2,
        "P20c FAIL: the candidate list must be exactly the object's two spawn points, got " ..
        tostring(#shared._patrol_points))
    local object_log = false
    for i = 1, #_logs do
        if _logs[i]:find("object spawn index supplied 2 point(s)", 1, true) then object_log = true end
    end
    assert(object_log,
        "P20d FAIL: the first build must say when object-index coordinates supplied candidates")
    print("  P20 PASS: an objective game's entry resolves to the coordinates it spawns at")
end

-- P21 — one id, two namespaces: both answers belong in one search
do
    _time = 2300
    _waypoints = nil
    local me = player({ pos = { x = LESSER_CAMP.x, y = LESSER_CAMP.y, z = LESSER_CAMP.z } })
    local shared = {}
    local goal = { type = "kill", target = "Lesser Rock Elemental", npc_id = LESSER_ROCK_ELEMENTAL }
    local ctx = ctx_for({ me = me, now = _time })
    local expected = expected_points(LESSER_ROCK_ELEMENTAL, LESSER_CAMP, _map_id)

    assert(spawn_patrol.next_point(shared, ctx, goal) ~= nil,
        "P21a FAIL: scene error — the creature camp must still answer")
    assert(#shared._patrol_points == #expected + 1,
        "P21b FAIL: the search must hold the mob's own spawns AND the object that shares the " ..
        "entry number: expected " .. tostring(#expected + 1) .. ", got " ..
        tostring(#shared._patrol_points))
    local has_object_point = false
    for i = 1, #shared._patrol_points do
        local p = shared._patrol_points[i]
        if math.abs(p.x - (LESSER_CAMP.x + 300)) < 0.01 then has_object_point = true end
    end
    assert(has_object_point,
        "P21c FAIL: the object index's answer for the same id must reach the candidate list")
    print("  P21 PASS: one id resolved in both namespaces merges both sets of spawn points")
end

-- P22 — a goal with no id at all still finds the object, by name
do
    _time = 2400
    _waypoints = nil
    local me = player({ pos = { x = 0, y = 0, z = 0 } })
    local shared = {}
    local goal = { type = "area", target = "Ogre Remains", npc_id = 0 }
    local ctx = ctx_for({ me = me, now = _time })

    local first = spawn_patrol.next_point(shared, ctx, goal)
    assert(first and math.abs(first.x - 60) < 0.01,
        "P22a FAIL: a name-only goal must resolve through the object name index, and the nearest " ..
        "candidate wins — got x=" .. tostring(first and first.x))
    local exact_points, lookalike = 0, false
    for i = 1, #shared._patrol_points do
        local p = shared._patrol_points[i]
        if p.x == 60 or p.x == 90 then exact_points = exact_points + 1 end
        if p.x == 70 then lookalike = true end
    end
    assert(exact_points == 2,
        "P22b FAIL: both spawn points of the exactly named entry must be candidates, got " ..
        tostring(exact_points))
    -- The third candidate is goal_names.expand's singular variant at work: "Ogre Remains" ends in
    -- "s", so "Ogre Remain" is searched too, and that partial name also matches the fixture's
    -- lookalike entry. Pre-existing, documented name behaviour, harmless here because the exact
    -- entry is in the list and candidates are nearest-first — pinned so a future change to the
    -- expansion is a deliberate decision rather than a silent one.
    assert(lookalike,
        "P22c FAIL: scene error — the lookalike's point is expected from the singular variant")
    print("  P22 PASS: a name-only objective resolves through the object name index")
end

_waypoints = nil

print("PASS test_spawn_patrol")
os.exit(0)
