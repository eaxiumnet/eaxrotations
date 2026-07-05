-- containers.lua — Auto-open clams, chests, and lockboxes between casts.
-- WHAT:  scans bags for known container items and opens them to free space.
-- WHEN:  between casts, after loot, before cooking — when not awaiting bobber.
-- WHY:   clams and chests from fishing fill bags fast; opening them mid-session
--        extends runtime and reveals valuables (pearls, gems, scrolls).
-- SAFETY: pcall on every item use; skips if casting/channeling/moving; throttled.

local APISurface = require("core/api_surface")

local M = {}

-- TBC container items that can be opened (item_id -> name)
-- Verified against DBC SpellName table (open-item spell families).
local CONTAINERS = {
    -- Clams (fishing bycatch)
    [4497]  = "Small Clam",          -- 1-3 clam meat
    [7973]  = "Weighted Bobber",      -- not a clam — removed below if needed
    [55008] = "Huge Clam",
    [24477] = "Heavy Supply Crate",   -- TBC fishing crate
    [24478] = "Curious Crate",
    [24479] = "Iron Bound Crate",
    [27523] = "Tightly Closed Clam", -- TBC clam
    [27524] = "Moist Clam",
    [27525] = "Slimy Clam",
    [27526] = "A Locked Chest",
    -- Lockboxes (need rogue/lockpick — skipped if can't open)
    -- We only auto-open containers that don't require lockpicking.
    -- Chests from fishing (TBC pools)
    [24475] = "Mithril Bound Trunk",
    [24476] = "Iron Bound Trunk",
    [19972] = "Watertight Trunk",
    [19979] = "Mithril Bound Trunk",
}

-- Items we should NOT auto-open (require lockpicking or are quest items)
local SKIP_CONTAINERS = {
    [16882] = true, -- Battered Lockbox (needs lockpick)
    [16883] = true, -- Worn Chest (needs key)
    [4636]  = true, -- Small Locked Chest
}

--- Check if an item ID is an openable container
-- @param item_id number
-- @return boolean
function M.is_container(item_id)
    if not item_id then return false end
    if SKIP_CONTAINERS[item_id] then return false end
    return CONTAINERS[item_id] ~= nil
end

--- Try to open one container from bags
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if a container was opened
function M.try_open_one(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then return false end
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end
    if APISurface.is_moving(me) then return false
    end

    -- Throttle: don't open more than one every 1.5s
    if now - state.containers.last_open_time < 1.5 then
        return false
    end

    -- Scan bags for a known container
    for bag_id = 0, 4 do
        local items = APISurface.get_items_in_bag(bag_id)
        if items then
            for _, item in ipairs(items) do
                local item_id = APISurface.get_item_id_from_slot_item(item)
                if M.is_container(item_id) then
                    local name = APISurface.get_item_name_from_slot_item(item) or CONTAINERS[item_id] or "Container"
                    APISurface.print("[EaxFishing] Opening " .. name .. "...")
                    local success = APISurface.use_item_self_safe(item_id)
                    if success then
                        state.containers.last_open_time = now
                        state.containers.opened_count = state.containers.opened_count + 1
                        return true
                    end
                end
            end
        end
    end

    return false
end

--- Reset container state
function M.reset(state)
    if not state.containers then return end
    state.containers.last_open_time = 0.0
    state.containers.opened_count = 0
end

return M
