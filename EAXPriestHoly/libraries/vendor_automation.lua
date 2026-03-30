-- vendor_automation.lua
-- Shared vendor automation for repair and grey-item sales.

local vendor_automation = {}

local THROTTLE_SECONDS = 2.5
local last_repair_attempt_at = 0
local last_sell_attempt_at = 0

local function now_seconds()
    if core and core.time then
        return core.time()
    end
    return 0
end

local function log_debug(menu, utils, message)
    if utils and utils.log_debug then
        utils.log_debug(menu, message)
    elseif core and core.log then
        core.log(message)
    end
end

local function is_throttled(last_attempt_at)
    return (now_seconds() - last_attempt_at) < THROTTLE_SECONDS
end

local function get_item_quality(slot)
    if not slot then return nil end

    if type(slot.quality) == "number" then
        return slot.quality
    end

    local obj = slot.object
    if obj and type(obj.quality) == "number" then
        return obj.quality
    end

    if obj and obj.get_quality then
        local ok, quality = pcall(function() return obj:get_quality() end)
        if ok and type(quality) == "number" then
            return quality
        end
    end

    return nil
end

local function get_item_sell_price(slot)
    if not slot then return 0 end

    if type(slot.sell_price) == "number" then
        return slot.sell_price
    end

    local obj = slot.object
    if obj and type(obj.sell_price) == "number" then
        return obj.sell_price
    end

    return 0
end

function vendor_automation.try_auto_repair(me, menu, utils)
    if not me or not me.is_valid or not me:is_valid() then return false end
    if not core or not core.inventory or not core.input then return false end
    if type(core.inventory.get_total_repair_cost) ~= "function" then return false end
    if type(core.inventory.get_gold) ~= "function" then return false end
    if type(core.input.repair_all_items) ~= "function" then return false end
    if is_throttled(last_repair_attempt_at) then return false end

    last_repair_attempt_at = now_seconds()

    local ok_cost, repair_cost = pcall(core.inventory.get_total_repair_cost)
    if not ok_cost or type(repair_cost) ~= "number" or repair_cost <= 0 then
        return false
    end

    local ok_gold, gold = pcall(core.inventory.get_gold)
    if not ok_gold or type(gold) ~= "number" then
        return false
    end

    if gold < repair_cost then
        log_debug(menu, utils, "Vendor: repair skipped (insufficient gold)")
        return false
    end

    local ok_repair, repaired = pcall(core.input.repair_all_items, false)
    if ok_repair and repaired then
        log_debug(menu, utils, "Vendor: repaired all items")
        return true
    end

    return false
end

function vendor_automation.try_auto_sell_greys(me, menu, utils)
    if not me or not me.is_valid or not me:is_valid() then return false end
    if not core or not core.inventory or not core.input then return false end
    if type(core.inventory.get_items_in_bag) ~= "function" then return false end
    if type(core.input.use_container_item) ~= "function" then return false end
    if is_throttled(last_sell_attempt_at) then return false end

    last_sell_attempt_at = now_seconds()

    local sold_any = false
    for bag_id = 0, 4 do
        local ok_bag, items = pcall(core.inventory.get_items_in_bag, bag_id)
        if ok_bag and type(items) == "table" then
            for _, slot in ipairs(items) do
                local quality = get_item_quality(slot)
                local sell_price = get_item_sell_price(slot)
                local slot_id = slot and slot.slot_id

                if quality == 0 and type(slot_id) == "number" and sell_price > 0 then
                    local ok_sell, sold = pcall(core.input.use_container_item, bag_id, slot_id)
                    if ok_sell and sold then
                        sold_any = true
                    end
                end
            end
        end
    end

    if sold_any then
        log_debug(menu, utils, "Vendor: sold grey items")
    end

    return sold_any
end

return vendor_automation
