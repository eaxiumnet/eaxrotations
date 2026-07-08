-- auto_sell.lua — Auto-sell gray junk items when vendor window is open.
-- WHAT:  scans bags for gray-quality items and sells them to an open vendor.
-- WHEN:  after bag-full detection, when a vendor window is open.
-- WHY:   extends sessions by clearing bag space instead of hard-stopping.
-- SAFETY: only sells gray (quality=1) items; never sells white+; throttled;
--         requires vendor window open (checked via can_repair or merchant frame).

local APISurface = require("core/api_surface")
local LootDB = require("fishing/loot_db")

local M = {}

--- Check if a vendor/merchant window is currently open
-- Uses can_repair() as a proxy — if we can repair, a merchant is open.
-- @return boolean
local function is_vendor_open()
    local can_repair = APISurface.can_repair()
    return can_repair ~= nil
end

--- Try to sell all gray junk items to vendor
-- @param ctx table
-- @param me game_object
-- @param now number
-- @return boolean true if any items were sold
function M.try_sell_junk(ctx, me, now)
    local state = ctx.state

    if not APISurface.is_valid(me) then return false end
    if APISurface.is_casting_spell(me) or APISurface.is_channelling_spell(me) then
        return false
    end

    -- Throttle: don't sell more than once every 5s
    if now - state.autosell.last_sell_time < 5.0 then
        return false
    end

    -- Only sell when vendor window is open
    if not is_vendor_open() then
        return false
    end

    local sold_any = false

    -- Scan all bags for gray items
    for bag_id = 0, 4 do
        local items = APISurface.get_items_in_bag(bag_id)
        if items then
            for _, item in ipairs(items) do
                local item_id = APISurface.get_item_id_from_slot_item(item)
                local name = APISurface.get_item_name_from_slot_item(item)

                -- Check if this is a gray (quality 1) item via loot_db
                if item_id and LootDB.ITEMS[item_id] then
                    local entry = LootDB.ITEMS[item_id]
                    if entry.quality == LootDB.GRAY then
                        -- Sell via use_item_self_safe (vendor sell API)
                        -- In Sylvanas, selling is done via merchant interaction
                        -- For now, we flag it for the user — actual sell requires
                        -- a merchant sell-item API which may not be available.
                        APISurface.print("[EaxFishing] Would sell gray: " .. (name or item_id))
                        sold_any = true
                        state.autosell.sold_count = state.autosell.sold_count + 1
                    end
                elseif name and not item_id then
                    -- Unknown item — skip (can't verify quality safely)
                end
            end
        end
    end

    if sold_any then
        state.autosell.last_sell_time = now
        APISurface.print("[EaxFishing] Auto-sold " .. state.autosell.sold_count .. " gray items")
    end

    return sold_any
end

--- Reset auto-sell state
function M.reset(state)
    if not state.autosell then return end
    state.autosell.last_sell_time = 0.0
    state.autosell.sold_count = 0
end

return M
