-- =============================================================================
-- Inventory/Vendor Module - Vendor repair functionality
-- REPLACED: core.vendor.repair_all with documented core.input.repair_all_items
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

--- Try to auto vendor and repair
-- Uses documented repair flow: check cost -> check gold -> repair
-- @param ctx table context
-- @param now number current time
-- @return boolean success
function M.try_vendor_repair(ctx, now)
    local state = ctx.state
    
    -- Throttle
    if now < state.vendor.next_repair_time then
        return false
    end
    
    -- Check if we can repair (has cost and enough gold)
    local can_repair, repair_cost = APISurface.can_repair()
    
    if not can_repair then
        if repair_cost > 0 then
            -- Not enough gold
            APISurface.print("[EaxFishing] Repair skipped: insufficient gold (need " .. repair_cost .. ", have " .. APISurface.get_gold() .. ")")
        end
        return false
    end
    
    -- Attempt repair
    APISurface.print("[EaxFishing] Repairing all items (cost: " .. repair_cost .. " copper)...")
    local success = APISurface.repair_all_items(false)
    
    if success then
        state.vendor.next_repair_time = now + 60.0
        APISurface.print("[EaxFishing] Repair completed successfully")
        return true
    else
        APISurface.print("[EaxFishing] Repair failed")
        return false
    end
end

return M
