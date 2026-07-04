-- =============================================================================
-- Fishing/Loot Module - Loot handling with session stat tracking
-- =============================================================================

local APISurface = require("core/api_surface")
local Behavior   = require("core/behavior")
local LootDB     = require("fishing/loot_db")
local Alert      = require("core/alert")

local M = {}

--- Get current loot item count
function M.get_count(ctx)
    return APISurface.get_loot_item_count()
end

--- Record a looted item into session stats
-- Called once per item before clicking it
local function record_item(ctx, slot)
    local state = ctx.state
    local stats = state.session.stats

    local is_gold = APISurface.get_loot_is_gold(slot)
    if is_gold then
        -- Gold is tracked separately via get_gold() delta in render
        return
    end

    local item_id   = APISurface.get_loot_item_id(slot)
    local item_name = APISurface.get_loot_item_name(slot)

    if not item_name or item_name == "" then return end

    -- Look up in database (by id first, fallback to name)
    local db = (item_id and LootDB.get(item_id)) or LootDB.get_by_name(item_name)

    local cat     = (db and db.cat)     or "other"
    local quality = (db and db.quality) or 2

    -- Increment item counter
    stats.item_counts[item_name] = (stats.item_counts[item_name] or 0) + 1

    -- Increment category counters
    if cat == "fish" then
        stats.fish_count = stats.fish_count + 1
    elseif cat == "gray" or quality == 1 then
        stats.gray_count = stats.gray_count + 1
    end

    -- Track notable vendor items (Goldenscale Vendorfish = 6g confirmed)
    if db and db.vendor_copper and db.vendor_copper > 0 then
        stats.vendor_copper = stats.vendor_copper + db.vendor_copper
    end

    -- Rare catch alert: blue quality (4+), green with notable value, or high vendor value
    local is_rare = false
    if quality >= 4 then
        is_rare = true
    elseif quality == 3 and db and db.vendor_copper and db.vendor_copper >= 10000 then
        is_rare = true  -- Green items worth ≥1g (e.g., Stonescale Eel)
    elseif db and db.vendor_copper and db.vendor_copper >= 30000 then
        is_rare = true  -- Any item worth ≥3g
    end
    if is_rare then
        Alert.fire(ctx, item_name, quality, (db and db.vendor_copper) or 0)
    end
end

--- Process loot window
function M.process(ctx, me, now)
    local state = ctx.state
    local loot = state.loot
    local config = ctx.deps.config

    local loot_count = M.get_count(ctx)
    if loot_count <= 0 then
        loot.start_time = 0
        loot.slot_index = 0
        return false
    end

    -- Initialize loot session
    if loot.start_time == 0 then
        loot.start_time = now
        loot.slot_index = loot_count - 1
        -- Pick a random loot order (sometimes loot top-down, sometimes bottom-up)
        loot.reverse = math.random() > 0.5
        if loot.reverse then
            loot.slot_index = 0
        end
    end

    -- Behavior-scaled delay between loot clicks
    local delay = 0.0
    if Behavior.is_optional_feature(config.menu.enable_loot_delays, true) then
        delay = Behavior.scaled_delay(state, now, 120, 350, "loot")
    end

    if now - loot.last_time < delay then
        state.fishing.status = "Looting..."
        return true
    end

    -- Click next loot slot
    local slot
    if loot.reverse then
        slot = math.min(loot.slot_index, loot_count - 1)
    else
        slot = math.max(0, math.min(loot.slot_index, loot_count - 1))
    end

    -- Record item stats before clicking (while item info is still available in loot window)
    record_item(ctx, slot)

    local success = APISurface.loot_item(slot)

    if success then
        loot.last_time = now
        if loot.reverse then
            loot.slot_index = loot.slot_index + 1
            if loot.slot_index >= loot_count then
                loot.start_time = 0
                loot.slot_index = 0
            end
        else
            loot.slot_index = loot.slot_index - 1
            if loot.slot_index < 0 then
                loot.start_time = 0
                loot.slot_index = 0
            end
        end
    end

    return true
end

return M
