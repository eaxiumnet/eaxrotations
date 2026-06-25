-- What: Corpse loot helper — scan for nearest dead non-player unit and loot or NAV to it
-- When: Called by IDLE state (and potentially other states) to handle autoloot
-- Why: Extract duplicate corpse loot logic from idle_state.lua into a single helper
-- Safety: nil-guarded; returns nil on cooldown, no corpse, or loot window open

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local LOOT_DIST_SQ = 9      -- 3yd — within range to immediately loot
local MAX_OBJECT_SCAN = 50  -- cap visible object scan

-- ============================================================================
-- Public API
-- ============================================================================

--- Scan for the nearest dead non-player unit and loot or NAV to it.
--- @param shared table Shared state variables (._loot_cooldown, ._nav_destination)
--- @param ctx table Per-tick context (.me, .utils, .now, .debug_log)
--- @param max_nav_dist_sq number|nil Max squared nav distance. nil = no limit.
--- @param debug_tag string|nil Optional suffix for debug log (e.g. "[autoloot]")
--- @return string|nil "IDLE" if looted, "NAV" if approaching, nil if nothing to loot
function M.try_loot_nearest_corpse(shared, ctx, max_nav_dist_sq, debug_tag)
    -- Guard: must have player context
    if not ctx or not ctx.me then return nil end

    -- Check if loot window is already open
    local loot_window_open = false
    local ok_count, loot_count = pcall(core.game_ui.get_loot_item_count)
    if ok_count and loot_count and loot_count > 0 then loot_window_open = true end

    -- If loot window is not open and cooldown is active, skip
    if not loot_window_open and shared._loot_cooldown > 0 and ctx.now and ctx.now < shared._loot_cooldown then
        return nil
    end

    -- If loot window is open, let the caller handle it
    if loot_window_open then return nil end

    -- Scan visible objects for dead non-player units (cached scanner preferred, fallback to direct API)
    local objects = nil
    if ctx.object_scanner and ctx.object_scanner.get_visible_objects then
        objects = ctx.object_scanner.get_visible_objects()
    else
        local ok
        ok, objects = pcall(core.object_manager.get_visible_objects)
        if not ok then objects = nil end
    end
    if not objects or #objects == 0 then return nil end

    local best_loot = nil
    local best_loot_sq = 1e9
    local limit = #objects > MAX_OBJECT_SCAN and MAX_OBJECT_SCAN or #objects

    for i = 1, limit do
        local obj = objects[i]
        if not obj then break end

        local ok_unit, is_unit = pcall(function() return obj:is_unit() end)
        if ok_unit and is_unit then
            local ok_player, is_player = pcall(function() return obj:is_player() end)
            if not (ok_player and is_player) then
                local ok_dead, is_dead = pcall(function() return obj:is_dead() end)
                if ok_dead and is_dead then
                    local ok_pos, opos = pcall(function() return obj:get_position() end)
                    local _, me_pos = pcall(function() return ctx.me:get_position() end)
                    if ok_pos and opos and me_pos and ctx.utils then
                        local dist_sq = ctx.utils.squared_distance(me_pos, opos)
                        if dist_sq < best_loot_sq then
                            best_loot = obj
                            best_loot_sq = dist_sq
                        end
                    end
                end
            end
        end
    end

    if not best_loot then return nil end

    local dist_yds = math.floor(math.sqrt(best_loot_sq))

    -- Within 3yd (9 dist_sq) → loot immediately
    if best_loot_sq <= LOOT_DIST_SQ then
        local _, lpos = pcall(function() return best_loot:get_position() end)
        if lpos then
            pcall(core.input.look_at, lpos)
        end
        pcall(core.input.set_target, best_loot)
        pcall(core.input.loot_object, best_loot)
        shared._loot_cooldown = ctx.now + 2.0
        ctx.debug_log("IDLE: looting corpse (" .. tostring(dist_yds) .. "yd)")
        return "IDLE"
    end

    -- Within nav range (or no limit) → set NAV destination
    if max_nav_dist_sq == nil or best_loot_sq <= max_nav_dist_sq then
        local _, lpos = pcall(function() return best_loot:get_position() end)
        if lpos then
            shared._nav_destination = lpos
        end
        local log_msg = "IDLE: approaching lootable corpse (" .. tostring(dist_yds) .. "yd)"
        if debug_tag then log_msg = log_msg .. " " .. debug_tag end
        ctx.debug_log(log_msg)
        return "NAV"
    end

    return nil
end

-- ============================================================================
-- Exports
-- ============================================================================

return M
