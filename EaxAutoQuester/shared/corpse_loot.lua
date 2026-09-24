-- What: Corpse loot helper — scan for the nearest lootable dead unit and loot it or NAV to it
-- When: Called by IDLE state (and potentially other states) to handle autoloot
-- Why: Extract duplicate corpse loot logic from idle_state.lua into a single helper
-- Safety: nil-guarded; returns nil on cooldown, nothing lootable, or loot window open
-- Decision: A corpse is recognised by TWO probes, and neither is sufficient alone — the truth
--   table below is the whole rule:
--
--     is_dead()  can_be_looted()  has_loot()      verdict
--     ---------  --------------  ------------    ---------------------------------
--     false      true            -               CORPSE — loot it. is_dead() reporting false
--                                                 for a corpse that still holds loot is a
--                                                 recorded live defect (do_action_state.lua,
--                                                 the Stonetusk Boar loop), so requiring it
--                                                 silently stopped autoloot after a kill.
--     true       true            -               CORPSE
--     true       false           true            CORPSE — can_be_looted() is false while
--                                                 has_loot() says there is something in it.
--     true       false           false/nil       already emptied → skip. This is what keeps
--                                                 the emptied-corpse loop shut: a corpse we
--                                                 looted still reports is_dead(), and the loop
--                                                 was "looting corpse (0yd)" every 2s for
--                                                 minutes (live: Stonevault Shaman).
--     false      false/nil       -               not a corpse → skip
--
--   can_be_looted() (scraped_docs_md/dev/api/game-object.md, "Loot and Interaction") and
--   has_loot() (.api/game_object.lua, "whether the game object contains loot") are read with
--   pcall, so a build without either answers "no evidence" rather than "no loot" — a missing
--   method can never silently disable autoloot.

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- The destination fields belong to shared/nav_destination.lua; a corpse walk is one of its
-- plain point destinations.
local nav_destination = require("shared/nav_destination")
local _loot_manager = nil

--- Let the existing loot manager evaluate bag fullness after this live corpse action.
--- Keeping the refresh there preserves its threshold, logging, and force-vendor flag owner.
local function refresh_force_vendor_state()
    if not _loot_manager then
        local ok, mod = pcall(require, "loot_manager_sylvanas")
        if ok and mod then _loot_manager = mod end
    end
    if _loot_manager and _loot_manager.refresh_force_vendor_state then
        pcall(_loot_manager.refresh_force_vendor_state)
    end
end

-- ============================================================================
-- Constants
-- ============================================================================

local LOOT_DIST_SQ = 9      -- 3yd — within range to immediately loot
local MAX_OBJECT_SCAN = 50  -- cap visible object scan

-- Method probes, called through pcall so a missing method is "no evidence" (see the header).
local function unit_is_unit(u) return u:is_unit() end
local function unit_is_player(u) return u:is_player() end
local function unit_is_dead(u) return u:is_dead() end
local function unit_can_be_looted(u) return u:can_be_looted() end
local function unit_has_loot(u) return u:has_loot() end
local function unit_get_position(u) return u:get_position() end

--- Is this unit a corpse, and is it proven to have nothing left in it?
--- See the truth table in the header: `can_be_looted() == true` stands on its own, and only a
--- definite "nothing in it" answer excludes a corpse — the answer that keeps the emptied-corpse
--- loop shut without making `is_dead()` (the unreliable probe) a requirement.
--- @param obj game_object
--- @return boolean corpse, boolean proven_empty
local function corpse_state(obj)
    local ok_dead, is_dead = pcall(unit_is_dead, obj)
    local ok_can, can_loot = pcall(unit_can_be_looted, obj)
    local ok_has, has_loot = pcall(unit_has_loot, obj)

    local lootable_now = ok_can and can_loot == true
    local corpse = lootable_now or (ok_dead and is_dead == true)

    -- has_loot() answers "anything left?" directly; can_be_looted() == false answers the same
    -- thing on builds where has_loot() is silent, but only when has_loot() has not said otherwise.
    local has_answer = ok_has and (has_loot == true or has_loot == false)
    local proven_empty = (has_answer and has_loot == false)
        or (ok_can and can_loot == false and not (has_answer and has_loot == true))

    return corpse, proven_empty
end

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

        local ok_unit, is_unit = pcall(unit_is_unit, obj)
        if ok_unit and is_unit then
            local ok_player, is_player = pcall(unit_is_player, obj)
            if not (ok_player and is_player) then
                local corpse, proven_empty = corpse_state(obj)
                if corpse and not proven_empty then
                    local ok_pos, opos = pcall(unit_get_position, obj)
                    local _, me_pos = pcall(unit_get_position, ctx.me)
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
        local _, lpos = pcall(unit_get_position, best_loot)
        if lpos then
            pcall(core.input.look_at, lpos)
        end
        pcall(core.input.set_target, best_loot)
        pcall(core.input.loot_object, best_loot)
        refresh_force_vendor_state()
        shared._loot_cooldown = ctx.now + 2.0
        ctx.debug_log("IDLE: looting corpse (" .. tostring(dist_yds) .. "yd)")
        return "IDLE"
    end

    -- Within nav range (or no limit) → set NAV destination
    if max_nav_dist_sq == nil or best_loot_sq <= max_nav_dist_sq then
        local _, lpos = pcall(unit_get_position, best_loot)
        if lpos then
            nav_destination.point(shared, lpos)
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
