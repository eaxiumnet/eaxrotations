-- What: NAV state handler — navigate to destination with retry/stuck logic
-- When: Called by coordinator when shared._state == "NAV"
-- Why: Centralize navigation: updates, stuck detection, retry with backoff, arrival handling
-- API: exports run(shared, ctx) → next_state string
-- Unit destinations: a destination set for a LIVE unit (a mob to engage, a target to close on)
--   is a moving point. The caller records the owner in shared._nav_unit_dest with the exact
--   position table it assigned in shared._nav_unit_dest_key, so a later assignment of a
--   different destination invalidates the record on its own. While it holds, this handler
--   refreshes the destination from the unit's live position before anything measures against
--   it, because the client walks to the coordinates it was handed and the stand-off was
--   measured against those same frozen coordinates: when the mob moved, the bot walked to
--   where it had been — into melee range, past where the class should have stopped — and the
--   arrival test could never fire at range. Live: "objective-first … found at 39yd -> NAV",
--   then the priest ended up 2yd from the mob while SentinelNavClient reported
--   "Stuck detected" against a point the mob had long left. Corpses and waypoints are not
--   moving points and are deliberately never recorded here.
-- Ownership: the destination fields are shared/nav_destination.lua's, resolved through
--   nav_destination.claim() at the top of every travelling tick. That call is what makes the pull
--   gate's retreat outrank a destination another writer set in the same tick — the gate publishes
--   the point it wants and never writes these fields itself, so whoever wrote last is not the
--   decision; this handler re-asserts the claim at the moment it consumes the destination.

local nav_destination = require("shared/nav_destination")
local pull_safety = require("shared/pull_safety")

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- Hoisted probes (perf pass): this handler runs every tick the bot is travelling, and each of
-- these was an inline `pcall(function() ... end)` closure built per call. Module-level functions
-- handed their unit through the pcall keep every return value and the pcall's error protection.
local function unit_is_in_combat(u) return u:is_in_combat() end
local function unit_get_position(u) return u:get_position() end
local function unit_is_dead(u) return u:is_dead() end
local function unit_is_unit(u) return u:is_unit() end
local function unit_can_attack(u, other) return u:can_attack(other) end

--- Is this unit one we would fight? The en-route pre-tag treats a quest giver and a quest MOB
--- differently: tagging the giver is free, tagging the mob is starting the fight while walking.
--- A build that cannot answer `can_attack` says "not hostile", i.e. the pre-tag keeps working.
--- @param ctx table Per-tick context
--- @param obj game_object|nil
--- @return boolean
local function hostile_to_me(ctx, obj)
    if not obj or not ctx or not ctx.me then return false end
    local ok, can = pcall(unit_can_attack, obj, ctx.me)
    return ok and can == true
end

--- Take the player off their mount on the way out of NAV. A mounted player cannot cast, so every
--- walk that ends with the bot about to fight or interact has to dismount. The coordinator's
--- equivalent call was `nav.dismount`, a field the navigation module never had — nil, so it did
--- nothing; this goes through the module that actually owns mounting.
--- @param ctx table Per-tick context
--- @param why string reason, for the log line
local function dismount_for(ctx, why)
    local ok, mm = pcall(require, "mount_manager_sylvanas")
    if ok and mm and mm.dismount_now then
        mm.dismount_now(ctx.me, why)
    end
end

--- How far a followed unit must move from the point the client was last given before the walk is
--- re-issued, and the shortest gap between two re-issues. The client walks to the coordinates it
--- was handed, not to the table, so a moving target needs a fresh instruction — but a mob nudging
--- back and forth must not restart its path every tick.
local REISSUE_AT_SQ = 9.0      -- 3 yards
local REISSUE_COOLDOWN = 0.5

-- The unreachable-place memory (which places the client could not walk to, and for how long they
-- are left alone) is shared/nav_destination.lua's: the producers that must not hand the same
-- coordinates straight back have to ask the same question, and "the same place" has one answer.
local function nav_dest_mark_unreachable(shared, ctx, point)
    nav_destination.mark_unreachable(shared, ctx and ctx.now, point)
end

--- Drop the destination and every field describing it, including the live-unit link, through
--- the fields' owner (shared/nav_destination.lua). The travel bookkeeping below is this
--- handler's own and is cleared alongside.
local function nav_dest_clear(shared)
    nav_destination.clear(shared)
    shared._nav_issued_x = nil
    shared._nav_issued_y = nil
    shared._nav_reissue_at = nil
end

--- Squared distance at which the current destination counts as reached.
--- A destination set for a ranged engagement carries its stand-off distance, so travelling
--- toward a mob stops at casting range instead of walking on top of it. The threshold is only
--- honoured while it still belongs to the destination it was set with, which makes any other
--- assignment of _nav_destination invalidate it implicitly.
--- @param shared table Shared state variables
--- @return number|nil stand_off_sq nil when the destination has no stand-off
local function stand_off_sq(shared)
    if shared._nav_engage_dest and shared._nav_engage_dest == shared._nav_destination then
        return shared._nav_engage_sq
    end
    return nil
end

-- ============================================================================
-- State: NAV — Navigate to destination with retry logic
-- ============================================================================

--- Manage navigation to shared._nav_destination.
--- Calls navigation.update() each tick for stuck detection.
--- Retries up to 3 times (2s pause on stuck, immediate retry on fail).
--- @param shared table Shared state variables
--- @param ctx table Per-tick context with submodules, me, helpers
--- @return string next_state
function M.run(shared, ctx)
    -- (No "waiting for an async probe" branch here: the only asynchronous navigation work is the
    --  reachability probe, and navigation_sylvanas owns that wait as its own VALIDATING state
    --  with its own timeout. The field this branch read was never armed by anything.)

    -- Combat check: stop navigation and let EaxRotations handle
    if ctx.me then
        local ok, combat = pcall(unit_is_in_combat, ctx.me)
        if ok and combat then
            local nav = ctx.nav
            if nav then nav.stop() end
            ctx.debug_log("NAV: combat detected — stopped navigation")
            return "IDLE"
        end
    end

    local nav = ctx.nav
    if not nav then return "IDLE" end

    -- Resolve the destination for this tick before anything reads it: the pull gate's retreat
    -- outranks every other source while its hold is armed (see the header). Claiming here — past
    -- the paths that stop before navigating — rather than accepting what the fields happen to hold
    -- is what keeps a retreat from being replaced by a same-tick write, which is the failure this
    -- handler used to be unable to see.
    nav_destination.claim(shared, ctx)

    -- The client's state BEFORE nav.update() polls it below. Used only to decide whether the
    -- client is already walking a destination (the follow block) — the arrival/failure decision
    -- must use the state nav.update() has just refreshed, or it lags a tick behind the client.
    local client_walking = nav.get_state() ~= "IDLE"

    -- Follow a live unit's destination (see the header). A non-unit or an already-gone unit
    -- destination is left exactly as it was: game objects and corpses do not move, and an
    -- unavailable position must not silently become a destination of its own.
    do
        local dest = shared._nav_destination
        local unit = shared._nav_unit_dest
        if dest and unit and shared._nav_unit_dest_key == dest then
            local ok_unit, is_unit = pcall(unit_is_unit, unit)
            if ok_unit and is_unit then
                local ok_dead, dead = pcall(unit_is_dead, unit)
                local ok_pos, upos = pcall(unit_get_position, unit)
                if (ok_dead and dead) or not (ok_pos and upos) then
                    -- The target died or despawned: there is nothing left to walk to. The owner
                    -- drops the destination and the descriptors together.
                nav_destination.clear(shared)
                shared._nav_retries = 0
                nav.stop()
                ctx.debug_log("NAV: destination unit is gone — stopping")
                dismount_for(ctx, "target gone")
                return "IDLE"
                end
                -- Same table, so the stand-off recorded with it stays valid.
                dest.x, dest.y, dest.z = upos.x, upos.y, upos.z

                -- Hand the client the target's new position, or it keeps walking to where the
                -- unit stood when this destination was set — the walk ends inside the mob.
                -- Only while the client is actually walking: the start-navigation block below is
                -- the single place that issues the first walk of a destination.
                if client_walking and (shared._nav_retry_timer or 0) == 0
                    and ctx.now >= (shared._nav_reissue_at or 0) then
                    local moved_sq
                    if shared._nav_issued_x then
                        local dx = dest.x - shared._nav_issued_x
                        local dy = dest.y - shared._nav_issued_y
                        moved_sq = dx * dx + dy * dy
                    else
                        moved_sq = REISSUE_AT_SQ + 1
                    end
                    if moved_sq > REISSUE_AT_SQ then
                        shared._nav_issued_x, shared._nav_issued_y = dest.x, dest.y
                        shared._nav_reissue_at = ctx.now + REISSUE_COOLDOWN
                        nav.navigate_to(dest, nil)
                        ctx.debug_log("NAV: target moved — refreshed path to " ..
                            tostring(math.floor((dest.x or 0))) .. "," .. tostring(math.floor((dest.y or 0))))
                    end
                end
            end
        end
    end

    -- Stand-off arrival: an engagement destination is "reached" at its stand-off distance, so
    -- stop the client as soon as the player is inside it rather than walking onto the mob.
    do
        local engage_sq = stand_off_sq(shared)
        if engage_sq and shared._nav_destination and ctx.me and ctx.utils then
            local ok_pos, pos = pcall(unit_get_position, ctx.me)
            if ok_pos and pos
                and ctx.utils.squared_distance(pos, shared._nav_destination) <= engage_sq then
                -- Reached: the destination AND its stand-off go together (the owner), so neither
                -- survives to describe the next one.
                nav_destination.clear(shared)
                shared._nav_retries = 0
                nav.stop()
                ctx.debug_log("NAV: in stand-off range - stopping to engage")
                -- Casting is impossible while mounted, and this return goes straight into the
                -- attack that the stand-off exists for.
                dismount_for(ctx, "engaging")
                return "IDLE"
            end
        end
    end

    -- Per-tick update for stuck detection (Pattern 5 from AGENTS.md)
    nav.update()

    -- Mount management: step off the mount when the destination is close. Mounting is NOT
    -- attempted here — a mount is a cast that movement cancels, so it belongs before the walk is
    -- issued (see the start-navigation block below), not on a tick where the client is walking.
    do
        local mm_ok, mm = pcall(require, "mount_manager_sylvanas")
        if mm_ok and mm and mm.update then
            mm.update(ctx.me, shared._nav_destination)
        end
    end

    -- Continuous side scan: pre-tag the current goal's quest NPC while walking
    -- (every 1.5s). Starts the fight on arrival instead of after a target scan,
    -- and the friendly interact half is limited to the same fixed 5yd gate as
    -- DO_ACTION. The wider 50yd scan remains a targeting/search radius, not an
    -- interaction permission.
    -- (Ported: docs/phase1_port_list.md item 6. The monolith re-checked combat
    -- here; by this point the handler has already returned IDLE for combat, so
    -- the check is structurally impossible and is omitted.)
    local utils = ctx.utils
    if utils and utils.throttle and utils.throttle("nav_target_scan", 1.5) then
        local zygor = ctx.zygor
        local npc = ctx.npc_manager
        if zygor and npc and npc.find_nearest_npc and zygor.has_current_step
            and zygor.has_current_step() then
            local step = zygor.get_current_step_info()
            local goals = step and ctx.safe(step.goals, nil)
            if goals then
                for i = 1, #goals do
                    local g = goals[i]
                    if type(g) == "table" and not ctx.safe(g.is_complete, false) then
                        local nid = ctx.safe(g.npc_id, 0)
                        if not nid or nid <= 0 then nid = ctx.safe(g.target_id, 0) end
                        if nid and nid > 0 then
                            local nearest = npc.find_nearest_npc({ nid }, 50, nil, ctx.object_scanner)
                            if nearest then
                                -- Tagging a quest giver while walking is free. Tagging a HOSTILE
                                -- while walking is starting the fight en route, and at low health
                                -- or mana that is exactly the pull the gate refuses — the goal's
                                -- own mob, tagged at 50yd, with the rotation already able to cast
                                -- on it before the bot has even arrived.
                                --
                                -- Asked DRY (would_refuse): a walk already under way must not be
                                -- turned around because the bot passes a mob it would not have
                                -- chosen to fight. Refusing here means only "do not tag it".
                                local hostile = hostile_to_me(ctx, nearest)
                                if hostile
                                    and pull_safety.would_refuse(ctx, nearest) then
                                    break
                                end
                                pcall(core.input.set_target, nearest)
                                if hostile then
                                    -- Hostile pre-tag behavior is unchanged: this interaction is
                                    -- the existing combat opener, bounded by the combat scan.
                                    pcall(core.input.interact_with_object, nearest)
                                else
                                    -- A friendly NPC may be selected by the 50yd search, but
                                    -- interaction is still an in-range action. Do not dispatch
                                    -- it remotely while the walk is still in progress.
                                    local me_pos_ok, me_pos = pcall(unit_get_position, ctx.me)
                                    local npc_pos_ok, npc_pos = pcall(unit_get_position, nearest)
                                    if me_pos_ok and npc_pos_ok and me_pos and npc_pos
                                        and ctx.utils and ctx.utils.squared_distance
                                        and ctx.utils.squared_distance(me_pos, npc_pos) <= 25 then
                                        pcall(core.input.interact_with_object, nearest)
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Anti-cheat: random jump every 10-25s while navigating. This live movement
    -- action is owned here; the former anti_detection module is retired and has
    -- no second source of delays, jitter, or proximity behavior. (Ported:
    -- docs/phase1_port_list.md item 7.)
    if utils and utils.throttle and utils.throttle("random_jump_nav", math.random(10, 25)) then
        pcall(core.input.jump)
    end

    -- Read the state nav.update() just refreshed: this is what the transition decision uses.
    local nav_state_val = nav.get_state()

    -- Check if retry timer is active and waiting
    if shared._nav_retry_timer > 0 and ctx.now < shared._nav_retry_timer then
        return "NAV"
    end

    -- Timer expired — restart navigation if needed
    if shared._nav_retry_timer > 0 and ctx.now >= shared._nav_retry_timer then
        shared._nav_retry_timer = 0
        if shared._nav_destination then
            -- Z-adjustment on retry: if destination Z differs wildly from
            -- player Z (indicating wrong floor/underground), try player Z
            -- as fallback. Only after 2+ failures to avoid adjusting on
            -- temporary navmesh hiccups.
            if shared._nav_retries >= 2 then
                local dest = shared._nav_destination
                if ctx.me and dest then
                    local pos_ok, pos = pcall(unit_get_position, ctx.me)
                    if pos_ok and pos and pos.z then
                        local z_diff = math.abs((dest.z or 0) - pos.z)
                        local xy_dist_sq = ((dest.x or 0) - pos.x)^2 + ((dest.y or 0) - pos.y)^2
                        if z_diff > 30 and xy_dist_sq < 100000 then
                            -- Replaced table: the owner keeps every link that pointed at the old
                            -- one, or the stand-off stops being honoured (the client walks onto
                            -- the mob) and the follow in the header silently stops refreshing.
                            nav_destination.repoint(shared, dest, { x = dest.x, y = dest.y, z = pos.z })
                            shared._nav_issued_x, shared._nav_issued_y = nil, nil
                            ctx.debug_log("NAV: retrying with adjusted Z (player Z fallback)")
                        end
                    end
                end
            end
            ctx.debug_log("NAV: retrying navigation")
            nav.navigate_to(shared._nav_destination, nil)
        end
        return "NAV"
    end

    -- A PLACE the client could not path to after its retries and fallbacks is left alone for the
    -- memory's window (shared/nav_destination.lua) instead of being retried from the top forever.
    -- Live: 40 minutes of "nav failed (max_stuck_exceeded) — asking the client to replan" at the
    -- same coordinates, with the client reporting "Stuck detected" on it in between — and, once
    -- the producers learned to ask the same question the same way, the same one-second loop with
    -- the client reporting "arrived" for a destination it never walked to.
    if nav_state_val == "FAILED" and nav_destination.recently_unreachable(shared, ctx.now) then
        ctx.debug_log("NAV: destination unreachable recently — skipping")
        nav_dest_clear(shared)
        nav.stop()
        return "IDLE"
    end

    -- Check for catastrophic navigation failure — warn and stop
    if nav_state_val == "FAILED" and shared._nav_retries == 0 then
        local nav_type = nav.get_nav_type and nav.get_nav_type() or "unknown"
        if nav_type == "simple" or nav_type == nil then
            local ns = _G.EaxAutoQuester
            if ns and ns.set_warning then
                ns.set_warning("Navigation unavailable - check SentinelNavClient", 8.0)
            end
        end
    end

    -- Handle terminal navigation states
    if nav_state_val == "ARRIVED" then
        if shared._nav_destination and ctx.me then
            local _, pos = pcall(unit_get_position, ctx.me)
            if pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(pos, shared._nav_destination)
                if dist_sq > (stand_off_sq(shared) or 9) then
                    local dist_yds = math.floor(math.sqrt(dist_sq))
                    shared._nav_retries = shared._nav_retries + 1
                    if ctx.record_event then
                        local dest = shared._nav_destination
                        ctx.record_event("nav_short_arrival", {
                            x = dest.x,
                            y = dest.y,
                            z = dest.z,
                            distance_yds = dist_yds,
                            retry = shared._nav_retries,
                        }, ctx.now)
                    end
                    ctx.debug_log("NAV: arrived callback but still " .. tostring(dist_yds) .. "yd away (retry " .. tostring(shared._nav_retries) .. "/3)")
                    if shared._nav_retries >= 3 then
                        if ctx.record_event then
                            local dest = shared._nav_destination
                            ctx.record_event("nav_abandoned", {
                                x = dest.x,
                                y = dest.y,
                                z = dest.z,
                                retry = shared._nav_retries,
                                reason = "arrived_far",
                            }, ctx.now)
                        end
                        ctx.log("Navigation arrived but still far after 3 retries — giving up")
                        -- Remember the PLACE, not just this attempt: the producer that chose it is
                        -- about to run again, and without the memory it offers the same coordinates
                        -- straight back — a one-second IDLE/NAV loop that never covers the rest of
                        -- the step (live: "arrived callback but still 13yd away", forever).
                        nav_dest_mark_unreachable(shared, ctx)
                        nav_dest_clear(shared)
                        -- The counter belongs to the destination it counted, not to the handler:
                        -- without this reset the next destination starts at 3/3 and gives up on its
                        -- first arrival, however good a destination it was.
                        shared._nav_retries = 0
                        nav.stop()
                        dismount_for(ctx, "arrival flagged far")
                        return "IDLE"
                    end
                    nav.navigate_to(shared._nav_destination, nil)
                    return "NAV"
                end
            end
        end
        if ctx.record_event and shared._nav_destination then
            local dest = shared._nav_destination
            ctx.record_event("nav_arrived", {
                x = dest.x,
                y = dest.y,
                z = dest.z,
            }, ctx.now)
        end
        ctx.debug_log("NAV: arrived")
        nav_dest_clear(shared)
        shared._nav_retries = 0
        shared._nav_wp_fallback = false
        shared._nav_mesh_fallback = false
        shared._just_arrived = true
        -- Arriving is the other end of a mounted walk: whatever IDLE does next (loot, talk to an
        -- NPC, attack) needs the player off the mount.
        dismount_for(ctx, "arrived")
        -- Settle pause before IDLE re-evaluates: arriving and immediately
        -- re-deciding can miss an NPC that has not rendered yet.
        -- (Ported: docs/phase1_port_list.md item 5.)
        shared._action_pause_timer = ctx.now + 1.5
        nav.stop()
        return "IDLE"
    end

    if nav_state_val == "FAILED" then
        shared._nav_retries = shared._nav_retries + 1
        ctx.debug_log("NAV: failed (retry " .. ctx.safe(shared._nav_retries, 0) .. "/3)")

        if shared._nav_retries >= 3 then
            if ctx.record_event and shared._nav_destination then
                local dest = shared._nav_destination
                ctx.record_event("nav_abandoned", {
                    x = dest.x,
                    y = dest.y,
                    z = dest.z,
                    retry = shared._nav_retries,
                    reason = "failed",
                }, ctx.now)
            end
            ctx.log("Navigation failed after 3 retries")
            local failed_point = shared._nav_destination
            if not shared._nav_wp_fallback then
                shared._nav_wp_fallback = true
                local zygor = ctx.zygor
                if zygor then
                    local wp = zygor.get_current_waypoint_world()
                    if wp then
                        nav_destination.point(shared, wp)
                        shared._nav_retries = 0
                        ctx.debug_log("NAV: falling back to waypoint")
                        return "NAV"
                    end
                end
            end
            if not shared._nav_mesh_fallback then
                shared._nav_mesh_fallback = true
                local dest = shared._nav_destination
                local nav = ctx.nav
                if dest and nav and nav.move_direct then
                    ctx.debug_log("NAV: using direct movement")
                    nav.move_direct(dest)
                    return "NAV"
                end
            end
            local ns = _G.EaxAutoQuester
            if ns and ns.set_warning then
                ns.set_warning("Navigation failed - check path", 8.0)
            end
            nav_dest_mark_unreachable(shared, ctx, failed_point)
            nav_dest_clear(shared)
            shared._nav_retries = 0
            shared._nav_wp_fallback = false
            shared._nav_mesh_fallback = false
            return "IDLE"
        end

        -- Immediate retry on failure — schedule restart next tick
        shared._nav_retry_timer = ctx.now + 0.1
        return "NAV"
    end

    if nav_state_val == "STUCK" then
        shared._nav_retries = shared._nav_retries + 1
        ctx.debug_log("NAV: stuck (retry " .. ctx.safe(shared._nav_retries, 0) .. "/3)")

        if shared._nav_retries >= 3 then
            ctx.log("Navigation stuck after 3 retries — giving up")
            local ns = _G.EaxAutoQuester
            if ns and ns.set_warning then
                ns.set_warning("Character stuck - manual input needed", 10.0)
            end
            nav_dest_mark_unreachable(shared, ctx)
            nav_dest_clear(shared)
            shared._nav_retries = 0
            return "IDLE"
        end

        -- Progressive stuck recovery: a character wedged on geometry never frees
        -- itself from a plain wait, so escalate before the 2s backoff — retry 1
        -- and retry 2 both jump. (Ported: docs/phase1_port_list.md item 4.)
        --
        -- The turn tap retry 2 used to add is gone. It called turn_*_start and then turn_*_stop in
        -- the SAME tick, which turns for zero frames and so never helped a wedged character — while
        -- being one forgotten *_stop away from holding an arrow key down forever (that is exactly
        -- what combat_helper's unpaired turn did: "I'm spinning around in circles"). The quester no
        -- longer drives the turn keys at all; the jump and the re-issued path do the work.
        if shared._nav_retries == 1 or shared._nav_retries == 2 then
            pcall(core.input.jump)
        end

        -- 2s pause on stuck
        shared._nav_retry_timer = ctx.now + 2.0
        return "NAV"
    end

    -- Start navigation if not already navigating and destination set
    if nav_state_val == "IDLE" and shared._nav_destination then
        -- Mount BEFORE the walk is issued, and hold the walk for the cast. A mount is a 1.5s cast
        -- and movement cancels it, so attempting it on a tick where the client is already walking
        -- the player could never complete — the bag scan ran, the cast was issued, and the player
        -- still travelled on foot (live: "I would like it to auto mount"). begin_travel returns
        -- true only while the cast is in flight; it is bounded by its cast timeout and backed off
        -- by a failure cooldown, so it can neither stall nor loop.
        do
            local mm_ok, mm = pcall(require, "mount_manager_sylvanas")
            if mm_ok and mm and mm.begin_travel then
                local hold, why = mm.begin_travel(ctx.me, shared._nav_destination, ctx.now)
                if hold then
                    ctx.debug_log("NAV: mounting before travel — holding the walk for the cast")
                    return "NAV"
                end
                -- On foot with a long walk ahead: say WHY, once per walk issued. Without this the
                -- field symptom ("it didn't mount for a 300yd run") has no cause attached to it.
                if why then
                    ctx.debug_log("NAV: travelling on foot — " .. tostring(why))
                end
            end
        end
        ctx.debug_log("NAV: starting navigation")
        shared._nav_issued_x = shared._nav_destination.x
        shared._nav_issued_y = shared._nav_destination.y
        nav.navigate_to(shared._nav_destination, nil)
    end

    return "NAV"
end

return M
