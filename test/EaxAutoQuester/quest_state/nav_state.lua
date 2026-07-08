-- What: NAV state handler — navigate to destination with retry/stuck logic
-- When: Called by coordinator when shared._state == "NAV"
-- Why: Centralize navigation: updates, stuck detection, retry with backoff, arrival handling
-- API: exports run(shared, ctx) → next_state string

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

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
    -- Async fallback pending: wait for navmesh probe callback
    if shared._nav_fallback_pending then
        ctx.debug_log("NAV: waiting for navmesh probe")
        return "NAV"
    end

    -- Combat check: stop navigation and let EaxRotations handle
    if ctx.me then
        local ok, combat = pcall(function() return ctx.me:is_in_combat() end)
        if ok and combat then
            local nav = ctx.nav
            if nav then nav.stop() end
            ctx.debug_log("NAV: combat detected — stopped navigation")
            return "IDLE"
        end
    end

    local nav = ctx.nav
    if not nav then return "IDLE" end

    -- Per-tick update for stuck detection (Pattern 5 from AGENTS.md)
    nav.update()

    -- Mount management: mount when far, dismount when close
    do
        local mm_ok, mm = pcall(require, "mount_manager_sylvanas")
        if mm_ok and mm and mm.update then
            mm.update(ctx.me, shared._nav_destination)
        end
    end

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
                    local pos_ok, pos = pcall(function() return ctx.me:get_position() end)
                    if pos_ok and pos and pos.z then
                        local z_diff = math.abs((dest.z or 0) - pos.z)
                        local xy_dist_sq = ((dest.x or 0) - pos.x)^2 + ((dest.y or 0) - pos.y)^2
                        if z_diff > 30 and xy_dist_sq < 100000 then
                            shared._nav_destination = { x = dest.x, y = dest.y, z = pos.z }
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
            local _, pos = pcall(function() return ctx.me:get_position() end)
            if pos and ctx.utils then
                local dist_sq = ctx.utils.squared_distance(pos, shared._nav_destination)
                if dist_sq > 9 then
                    local dist_yds = math.floor(math.sqrt(dist_sq))
                    shared._nav_retries = shared._nav_retries + 1
                    ctx.debug_log("NAV: arrived callback but still " .. tostring(dist_yds) .. "yd away (retry " .. tostring(shared._nav_retries) .. "/3)")
                    if shared._nav_retries >= 3 then
                        ctx.log("Navigation arrived but still far after 3 retries — giving up")
                        shared._nav_destination = nil
                        shared._nav_retries = 0
                        nav.stop()
                        return "IDLE"
                    end
                    nav.navigate_to(shared._nav_destination, nil)
                    return "NAV"
                end
            end
        end
        ctx.debug_log("NAV: arrived")
        shared._nav_destination = nil
        shared._nav_retries = 0
        shared._nav_wp_fallback = false
        shared._nav_mesh_fallback = false
        shared._just_arrived = true
        nav.stop()
        return "IDLE"
    end

    if nav_state_val == "FAILED" then
        shared._nav_retries = shared._nav_retries + 1
        ctx.debug_log("NAV: failed (retry " .. ctx.safe(shared._nav_retries, 0) .. "/3)")

        if shared._nav_retries >= 3 then
            ctx.log("Navigation failed after 3 retries")
            if not shared._nav_wp_fallback then
                shared._nav_wp_fallback = true
                local zygor = ctx.zygor
                if zygor then
                    local wp = zygor.get_current_waypoint_world()
                    if wp then
                        shared._nav_destination = wp
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
            shared._nav_destination = nil
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
            shared._nav_destination = nil
            shared._nav_retries = 0
            return "IDLE"
        end

        -- 2s pause on stuck
        shared._nav_retry_timer = ctx.now + 2.0
        return "NAV"
    end

    -- Start navigation if not already navigating and destination set
    if nav_state_val == "IDLE" and shared._nav_destination then
        ctx.debug_log("NAV: starting navigation")
        nav.navigate_to(shared._nav_destination, nil)
    end

    return "NAV"
end

return M
