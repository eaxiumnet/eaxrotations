-- shared/spawn_patrol.lua — where the bot walks to look for the mobs its goal asks for.
-- WHAT:  next_point(shared, ctx, goal) -> the point to search next, or nil. Candidates are the
--        goal mob's own spawn points from the local cMaNGOS spawn index (npc_spawns), which is
--        every individual spawn, falling back to the Zygor step's waypoints when the goal names
--        nothing the index knows (a quest object, an unknown name, spawn data absent).
-- WHEN:  while the bot is waiting for its objective to exist — idle_state's respawn wait — and
--        from do_action_state's "no enemy found, go to where the mob lives" path.
-- WHY:   The wait used to be a park: one 50yd enemy probe fired every 5s from wherever the last
--        kill happened, and nothing ever moved. A camp's spawn points are spread over hundreds of
--        yards (Lesser Rock Elemental: 18 points across ~250yd), so a respawn anywhere but under
--        the player's feet was invisible by construction and the bot stood still for minutes —
--        live: twelve consecutive "waiting for respawn (Lesser Rock Elementals)" minutes, then
--        the same 60s wait re-armed because a corpse was still underfoot. A search has to be a
--        walk; this owns that walk.
--        One sweep is: nearest unsearched spawn point -> walk -> at 10yd it counts as searched ->
--        next. A candidate the bot is already standing on counts as searched at choice time (so the
--        first leg of a wait is never a walk to where the bot already is), and a rebuild that
--        leaves nothing walkable returns nil rather than re-walking the index every tick. When
--        every point has been searched the list is rebuilt around the player's current position
--        and the sweep starts over, so arriving at the camp widens the search to the rest of the
--        camp instead of freezing the candidate set chosen from 400yd away. Two throttles keep
--        that from becoming a per-frame storm: a rebuild at most every REBUILD_SECONDS, and a leg
--        already in flight re-published at most every REISSUE_SECONDS (the client owns the walk).
-- SAFETY: never walks while the pull gate holds a retreat (the retreat outranks a search leg: the
--        gate exists to not enter a camp, and this is exactly a walk toward one). A leg with no
--        movement for STUCK_SECONDS is retired so a spawn point the bot cannot reach cannot wedge
--        the search. Arrival is measured on the ground plane, because a candidate's height is not
--        always the terrain's (a guide waypoint arrives with z=0) and a wrong height turned "the
--        bot is standing here" into a 0yd leg. A place the client has already refused is not
--        offered again. Every probe pcall-guarded; the tick path allocates nothing (the candidate
--        list and the visited marks are built once per goal, not per tick).
-- DECISION: a shared module rather than logic inside idle_state, because do_action_state needs the
--        same walk and a second copy would drift. The point is RETURNED, not written: the states
--        that own navigation apply it (see shared/nav_destination.lua for who owns the fields).
-- NOTE:   Whether SentinelNavClient accepts a spawn point as a destination is the client's answer,
--        not this module's: what is asserted here is that the point published is the mob's own
--        spawn coordinate with a terrain-fixed Z, and that the next point is chosen when it has
--        been reached.

local M = {}

local goal_names = require("shared/goal_names")
local nav_destination = require("shared/nav_destination")
local objective_match = require("shared/objective_match")

-- Hoisted probes: the tick path must not build closures (see tests/test_tick_allocation.lua).
local function unit_get_position(u) return u:get_position() end
local _get_map_id = core.get_map_id

-- Lazy module handles, cached after the first success only, so a test that installs a stub later
-- still gets it. `_failed` latches a miss so a missing module is asked for once, not every tick.
local _pull_safety = nil
local function pull_safety()
    if not _pull_safety then
        local ok, ps = pcall(require, "shared/pull_safety")
        if ok and ps then _pull_safety = ps end
    end
    return _pull_safety
end

local _spawns = nil
local _spawns_failed = false
local function spawns()
    if not _spawns and not _spawns_failed then
        local ok, s = pcall(require, "npc_spawns")
        if ok and s then _spawns = s else _spawns_failed = true end
    end
    return _spawns
end

local _fixer = nil
local _fixer_failed = false
local function fixer()
    if not _fixer and not _fixer_failed then
        local ok, wf = pcall(require, "waypoint_fixer_sylvanas")
        if ok and wf and wf.fix_z then _fixer = wf else _fixer_failed = true end
    end
    return _fixer
end

-- ============================================================================
-- Tunables
-- ============================================================================

--- At this range a spawn point has been searched, so the sweep moves on. 10yd: the bot is at the
--- spawn coordinate, not merely near the camp.
local ARRIVE_SQ = 100.0

--- Movement toward the current point that counts as progress (5yd) and how long a leg may make no
--- progress before it is retired. A spawn point inside geometry or on an island the navmesh does
--- not reach must cost one leg, not the whole search.
local PROGRESS_SQ = 25.0
local STUCK_SECONDS = 15.0

--- Distance on the ground plane. "Is the player standing on this place?" must not depend on a
--- height: the guide's step waypoints come out of the map conversion with z=0
--- (zygor_reader_sylvanas.lua get_step_waypoints_world), so a 3D compare read the waypoint the bot
--- was standing on as hundreds of yards away, published it as a 0-1yd leg, and retired it 15s later
--- as unreachable (live: "spawning spawn point 5/5 (0yd)" -> "spawn point 2 unreachable").
local function ground_sq(a, b)
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

--- How often a leg that is still being walked is re-published. The states hand the walk to the
--- client and the client owns it; re-publishing every tick would restart a path each frame, and
--- never re-publishing would park the search after any navigation that died (a combat stop, a
--- client failure).
local REISSUE_SECONDS = 1.5

--- Spawn points kept for one goal. A camp has tens; this only bounds a mob whose spawns are
--- spread across a whole continent.
local MAX_POINTS = 512

--- How often a completed sweep may rebuild its candidate list. A rebuild walks the whole spawn
--- index, and the bot spends the whole wait standing on the last point it searched, so an
--- unthrottled rebuild is an index walk (and a log line) per tick. Rebuilding every few seconds
--- also keeps the search moving: the bot re-walks the camp looking for a respawn instead of
--- standing on the one spawn point it happened to finish on.
local REBUILD_SECONDS = 5.0

--- Spawn points kept for one sweep must be within this range of the player (400yd) — the search is
--- local by nature. When the mob has no spawn point that close, the nearest one is kept as a
--- single candidate so the bot walks toward the camp; the list is rebuilt once that leg ends.
local BUILD_RADIUS_SQ = 160000.0

-- ============================================================================
-- Candidate list
-- ============================================================================

--- The goal's mob identity: the target string and the NPC id, as the goal carries them. Compared
--- field by field (not concatenated) so the per-tick identity check allocates nothing.
--- The id comes from shared/objective_match.lua, which reads every spelling the bridge and the
--- addon use (npc_id, target_id, targetid, id, multi-target pairs) — the guide's own step data
--- carries the id of the mob that drops the objective item, and that is the whole identity.
--- @param goal table|nil
--- @return string|nil target, number npc_id
local function identity(goal)
    if type(goal) ~= "table" then return nil, 0 end
    local target = goal.target or goal.npc or goal.npc_name
    if type(target) ~= "string" or target == "" then target = nil end
    return target, objective_match.goal_id(goal) or 0
end

--- Build the candidate points for a goal around the player's current position.
--- @param ctx table Per-tick context
--- @param goal table|nil
--- @param me_pos table Player position
--- @return table[] Array of { x, y, z } (may be empty)
local function build_points(ctx, goal, me_pos)
    local target, npc_id = identity(goal)
    local points = {}
    -- Which grid cells already hold a candidate, for the step-waypoint merge below. Built once
    -- per rebuild (the same cadence as `points`), never per tick. 0.1yd cells: the key must
    -- merge exact duplicates (the same coordinates from both sources) and nothing coarser —
    -- near-duplicates are the arrive radius's job, not the grid's.
    local added = {}
    local utils = ctx.utils

    local map_id = nil
    if _get_map_id then
        local ok, mid = pcall(_get_map_id)
        if ok then map_id = mid end
    end

    local db = spawns()
    if db and db.find_npc_spawns then
        -- Which entries to look up. The goal's own ids are the goal telling us exactly which mobs
        -- it means — every one of them, since a multi-target kill goal names several — and only
        -- when it carries none does the target name get resolved against the spawn index.
        local ids = {}
        local goal_ids, goal_id_count = objective_match.mob_ids(goal)
        for i = 1, goal_id_count do ids[i] = goal_ids[i] end
        if #ids == 0 and target and db.find_npc_ids_by_name then
            local names = goal_names.expand(target)
            for i = 1, #names do
                local matches = db.find_npc_ids_by_name(names[i])
                for j = 1, #matches do
                    local id = matches[j].npc_id
                    if id then
                        local dup = false
                        for k = 1, #ids do
                            if ids[k] == id then dup = true break end
                        end
                        if not dup then ids[#ids + 1] = id end
                    end
                end
            end
        end

        local nearest_far, nearest_far_sq = nil, nil
        for i = 1, #ids do
            local maps = db.find_npc_spawns(ids[i])
            if maps then
                for j = 1, #maps do
                    local m = maps[j]
                    if m and m.x and m.y and (map_id == nil or m.map_id == map_id) then
                        local d_sq = utils and utils.squared_distance(me_pos, m) or 0
                        if d_sq <= BUILD_RADIUS_SQ then
                            points[#points + 1] = { x = m.x, y = m.y, z = m.z or 0 }
                            -- Record the place for dedup: spawn points are added first, so a
                            -- guide waypoint standing on the same spot is dropped (spawn data
                            -- carries the real terrain height; a converted waypoint may not).
                            local gx = math.floor(m.x * 10)
                            local gy = math.floor(m.y * 10)
                            added[gx] = added[gx] or {}
                            added[gx][gy] = true
                            if #points >= MAX_POINTS then break end
                        elseif nearest_far_sq == nil or d_sq < nearest_far_sq then
                            -- Remember the closest point outside the search range: it is the way
                            -- back to the camp when nothing is nearby.
                            nearest_far_sq = d_sq
                            nearest_far = m
                        end
                    end
                end
            end
            if #points >= MAX_POINTS then break end
        end

        if #points == 0 and nearest_far then
            points[1] = { x = nearest_far.x, y = nearest_far.y, z = nearest_far.z or 0 }
        end
    end

    -- The guide's own path for this step joins the candidates on EVERY goal, not only when the
    -- index resolves nothing. Live, a mob with one or two nearby index spawns paces between them
    -- forever while the guide's kill/collect objective path — the route the guide author chose
    -- for exactly this quest — is never walked. A mob's spawns say WHERE it can be; the guide's
    -- path says where the quest wants the player to look. Both belong in one search.
    -- Dedup is by EXACT PLACE (0.1yd grid over x,y): the same camp is often both a spawn
    -- coordinate and a guide waypoint (same source data, rounded differently), and walking the
    -- same place twice is the pacing the merge exists to end. Spawn points win the tie (they
    -- carry real terrain height from the client's DBC). A near-duplicate a yard or two off is
    -- NOT merged here — it does not need to be: the 10yd arrive radius marks both searched the
    -- moment either is reached, so it can never become a leg.
    if ctx.zygor and ctx.zygor.get_step_waypoints_world then
        local ok, waypoints = pcall(ctx.zygor.get_step_waypoints_world)
        if ok and waypoints then
            for i = 1, #waypoints do
                local w = waypoints[i]
                if w and w.x and w.y then
                    local gx = math.floor(w.x * 10)
                    local gy = math.floor(w.y * 10)
                    if not added[gx] or not added[gx][gy] then
                        added[gx] = added[gx] or {}
                        added[gx][gy] = true
                        points[#points + 1] = { x = w.x, y = w.y, z = w.z or 0 }
                        if #points >= MAX_POINTS then break end
                    end
                end
            end
        end
    end

    return points
end

-- ============================================================================
-- State
-- ============================================================================

--- Forget the current goal's search. Called when the goal changes and on a step change.
--- @param shared table Shared state variables
function M.clear(shared)
    if not shared then return end
    shared._patrol_name = nil
    shared._patrol_npc = nil
    shared._patrol_points = nil
    shared._patrol_seen = nil
    shared._patrol_target_i = nil
    shared._patrol_issued_at = nil
    shared._patrol_anchor_x = nil
    shared._patrol_anchor_y = nil
    shared._patrol_anchor_at = nil
    shared._patrol_sweeps = nil
    shared._patrol_rebuilt_at = nil
    -- shared._patrol_seen is NOT cleared here: the only way to reach a mark is through
    -- shared._patrol_points, and every path that builds points installs a fresh table (see
    -- ensure_points). Clearing it here was a line no behaviour could depend on.
end

--- Make sure the candidate list for this goal exists.
--- @return boolean true when there is something to search
local function ensure_points(shared, ctx, goal, me_pos)
    local points = shared._patrol_points
    if points == false then return false end       -- already established: nothing to search
    if points then return true end

    points = build_points(ctx, goal, me_pos)
    if #points == 0 then
        -- Latched, not retried: a goal the index and the guide both know nothing about would
        -- otherwise walk the whole spawn index again on every tick of the wait.
        shared._patrol_points = false
        return false
    end

    shared._patrol_points = points
    shared._patrol_seen = {}
    ctx.debug_log("SPAWN PATROL: " .. tostring(#points) .. " spawn point(s) to search for '" ..
        tostring(shared._patrol_name or "goal") .. "'")
    return true
end

--- Nearest candidate the bot has NOT already searched, or nil when there is nothing walkable.
--- A candidate the player is standing on counts as searched — the same rule the arrival branch
--- applies, evaluated here at choice time so the first leg of a wait is not a walk to where the bot
--- already is. Marking them here is what makes a single-spawn objective (the bot parked on the
--- only spawn point) answer "nothing to walk to", which is the truth: the 5s scan watches that spot.
--- A place the client already refused is not offered: the sweep would spend every pass on it and
--- never cover the rest of the path, which is the module's own failure mode.
--- @param points table[] Candidate points
--- @param seen table Visited marks, mutated: proximity-searched points are marked
--- @param me_pos table Player position
--- @return number|nil index, number|nil squared distance
local function choose(shared, ctx, points, seen, me_pos)
    local best, best_sq = nil, nil
    for i = 1, #points do
        local point = points[i]
        if point and not seen[i]
            and not nav_destination.recently_unreachable(shared, ctx.now, point) then
            local d_sq = ctx.utils.squared_distance(me_pos, point)
            if ground_sq(me_pos, point) <= ARRIVE_SQ then
                seen[i] = true
            elseif best_sq == nil or d_sq < best_sq then
                best = i
                best_sq = d_sq
            end
        end
    end
    return best, best_sq
end

--- Nearest point not yet searched. When every point has been searched the list is rebuilt around
--- the player's current position — that is what widens the search to the rest of the camp once the
--- bot has walked to it — and the sweep starts again, at most once every REBUILD_SECONDS.
--- @return number|nil index into shared._patrol_points
local function select_next(shared, ctx, goal, me_pos)
    local points = shared._patrol_points
    local seen = shared._patrol_seen

    local best = choose(shared, ctx, points, seen, me_pos)
    if best then return best end

    -- Nothing walkable: the sweep is complete. A rebuild walks the spawn index, so it is throttled
    -- rather than repeated — the wait's own ticks would otherwise each re-walk the index and log.
    if ctx.now - (shared._patrol_rebuilt_at or -1e9) < REBUILD_SECONDS then
        return nil
    end
    shared._patrol_rebuilt_at = ctx.now

    local rebuilt = build_points(ctx, goal, me_pos)
    if #rebuilt == 0 then
        shared._patrol_points = false
        return nil
    end
    shared._patrol_points = rebuilt
    points = rebuilt
    shared._patrol_seen = {}
    seen = shared._patrol_seen
    shared._patrol_sweeps = (shared._patrol_sweeps or 0) + 1
    ctx.debug_log("SPAWN PATROL: sweep " .. tostring(shared._patrol_sweeps) ..
        " complete — re-scanning " .. tostring(#points) .. " spawn point(s)")

    return choose(shared, ctx, points, seen, me_pos)
end

-- ============================================================================
-- Public API
-- ============================================================================

--- The point to walk to next while searching for this goal's mobs, or nil to stay put.
--- @param shared table Shared state variables
--- @param ctx table Per-tick context
--- @param goal table|nil The current goal
--- @return table|nil vec3
function M.next_point(shared, ctx, goal)
    if not shared or not ctx or not ctx.me then return nil end
    if not ctx.utils or not ctx.utils.squared_distance then return nil end

    -- The pull gate's hold is a decision not to enter a camp. A search leg walks toward one, so
    -- while the hold lives the retreat is the destination and the search waits.
    local ps = pull_safety()
    if ps and ps.holding(ctx) then return nil end

    -- A new goal is a new search.
    local target, npc_id = identity(goal)
    if shared._patrol_name ~= target or shared._patrol_npc ~= npc_id then
        M.clear(shared)
        shared._patrol_name = target
        shared._patrol_npc = npc_id
    end

    local ok_pos, me_pos = pcall(unit_get_position, ctx.me)
    if not ok_pos or not me_pos then return nil end
    if not ensure_points(shared, ctx, goal, me_pos) then return nil end

    local points = shared._patrol_points
    local idx = shared._patrol_target_i

    if idx then
        local point = points[idx]
        local d_sq = ctx.utils.squared_distance(me_pos, point)
        if ground_sq(me_pos, point) <= ARRIVE_SQ then
            -- Searched: the bot is standing on it, and the 5s scan has had its chance here.
            shared._patrol_seen[idx] = true
            shared._patrol_target_i = nil
        else
            -- Progress bookkeeping. A leg that has not moved the player in STUCK_SECONDS is not a
            -- walk in progress, whatever the client believes about it.
            local anchor_x, anchor_y = shared._patrol_anchor_x, shared._patrol_anchor_y
            if anchor_x == nil then
                shared._patrol_anchor_x, shared._patrol_anchor_y = me_pos.x or 0, me_pos.y or 0
                shared._patrol_anchor_at = ctx.now
            else
                local dx = (me_pos.x or 0) - anchor_x
                local dy = (me_pos.y or 0) - anchor_y
                if dx * dx + dy * dy > PROGRESS_SQ then
                    shared._patrol_anchor_x, shared._patrol_anchor_y = me_pos.x or 0, me_pos.y or 0
                    shared._patrol_anchor_at = ctx.now
                elseif ctx.now - (shared._patrol_anchor_at or 0) > STUCK_SECONDS then
                    shared._patrol_seen[idx] = true
                    shared._patrol_target_i = nil
                    -- The client's word, not a guess: shared/nav_destination.lua owns "the client
                    -- could not walk to this place". A leg that simply stopped without that record
                    -- was reached as far as the client is concerned, and calling it unreachable sent
                    -- the sweep hunting a fault that was not there — live, an 18s walk the client
                    -- reported as arrived was retired as unreachable and offered again.
                    local refused = nav_destination.recently_unreachable(shared, ctx.now, point)
                    ctx.debug_log("SPAWN PATROL: spawn point " .. tostring(idx) ..
                        (refused and " unreachable" or " walk ended short") .. " — trying another")
                end
            end

            if shared._patrol_target_i then
                -- Still walking it. Publish the point only on the re-issue interval: the states
                -- hand the walk to the client, and a fresh instruction every tick restarts the
                -- path every frame.
                if ctx.now - (shared._patrol_issued_at or 0) >= REISSUE_SECONDS then
                    shared._patrol_issued_at = ctx.now
                    return point
                end
                return nil
            end
        end
    end

    idx = select_next(shared, ctx, goal, me_pos)
    if not idx then return nil end

    points = shared._patrol_points
    local point = points[idx]
    -- Z once per point. The spawn index carries real terrain height from the client's own DBC, but
    -- the fix-up is what the rest of the plugin applies to every destination it produces, and a
    -- point the client will not accept is a leg that can never arrive.
    if point and not point.fixed then
        local wf = fixer()
        if wf then
            local okz, fixed = pcall(wf.fix_z, point)
            if okz and fixed then
                points[idx] = fixed
                point = fixed
            end
        end
        if point then point.fixed = true end
    end
    if not point then return nil end

    local d_sq = ctx.utils.squared_distance(me_pos, point)
    shared._patrol_target_i = idx
    shared._patrol_issued_at = ctx.now
    shared._patrol_anchor_x, shared._patrol_anchor_y = me_pos.x or 0, me_pos.y or 0
    shared._patrol_anchor_at = ctx.now
    ctx.debug_log("SPAWN PATROL: searching spawn point " .. tostring(idx) .. "/" ..
        tostring(#points) .. " (" .. tostring(math.floor(math.sqrt(d_sq))) .. "yd)")
    return point
end

return M
