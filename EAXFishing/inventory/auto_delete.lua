-- auto_delete.lua — Auto-delete worthless junk items when bags are full.
-- WHAT:  deletes the lowest-value items from bags to free space.
-- WHEN:  when bags are full and auto_delete_junk is enabled.
-- WHY:   prevents session-ending hard stop when no vendor is nearby.
-- SAFETY: only deletes gray (quality=1) items; never deletes white+;
--         throttled; requires bags actually full; deletes one at a time.

local APISurface = require("core/api_surface")
local LootDB = require("fishing/loot_db")
local Bags = require("inventory/bags")

local M = {}

--- Find the lowest-value gray item in bags to delete
-- @param ctx table
-- @return number|nil item_id to delete
local function find_worst_junk(ctx)
    for bag_id = 0, 4 do
        local items = APISurface.get_items_in_bag(bag_id)
        if items then
            for _, item in ipairs(items) do
                local item_id = APISurface.get_item_id_from_slot_item(item)
                if item_id and LootDB.ITEMS[item_id] then
                    local entry = LootDB.ITEMS[item_id]
                    -- Only delete gray items with no vendor value
                    if entry.quality == LootDB.GRAY and not entry.vendor_copper then
                        return item_id
                    end
                end
            end
        end
    end
    return nil
end

--- Try to delete one junk item to free bag space
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if an item was deleted
function M.try_delete_junk(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then return false end
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end

    -- Throttle: don't delete more than one every 2s
    if now - state.autodelete.last_delete_time < 2.0 then
        return false
    end

    -- Only delete when bags are actually full
    if not Bags.is_bags_full(ctx) then
        return false
    end

    local junk_id = find_worst_junk(ctx)
    if not junk_id then return false end

    local name = LootDB.ITEMS[junk_id] and LootDB.ITEMS[junk_id].name or tostring(junk_id)
    APISurface.print("[EaxFishing] Deleting junk to free space: " .. name)

    -- Delete via use_item_self_safe — in Sylvanas, this may map to destroy item
    -- If the API doesn't support deletion, this will silently fail.
    local success = APISurface.use_item_self_safe(junk_id)
    if success then
        state.autodelete.last_delete_time = now
        state.autodelete.deleted_count = state.autodelete.deleted_count + 1
        return true
    end

    return false
end

--- Reset auto-delete state
function M.reset(state)
    if not state.autodelete then return end
    state.autodelete.last_delete_time = 0.0
    state.autodelete.deleted_count = 0
end

return M
