-- =============================================================================
-- Inventory/Bags Module - Bag slot management
-- Uses APISurface for all inventory operations
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

--- Get total free bag slots
-- @param ctx table context
-- @return number free slots
function M.get_total_free_slots(ctx)
    local state = ctx.state
    local deps = ctx.deps
    
    -- Use APISurface which handles inventory_helper + manual fallback internally
    local free_slots = APISurface.get_total_free_slots()
    
    if type(free_slots) == "number" then
        local result = math.max(math.floor(free_slots), 0)
        state.bag.last_helper_free = result
        
        -- Debug logging when debug mode is on (throttled to once per 10s)
        local debug_on = deps and deps.config and deps.config.menu.debug
            and deps.config.menu.debug.get_state and deps.config.menu.debug:get_state()
        if debug_on then
            local now_t = APISurface.now()
            if not state.bag._last_debug_log or now_t - state.bag._last_debug_log >= 10.0 then
                state.bag._last_debug_log = now_t
                APISurface.print("[EaxFishing] Bags: " .. result .. " free slots")
            end
        end
        
        return result
    end
    
    -- Should not reach here since APISurface always returns a number,
    -- but guard anyway to avoid a false bags-full stop.
    return 999
end

--- Get cached free bag slots with throttling
-- @param ctx table context
-- @return number? cached free slots
function M.get_cached_free_slots(ctx)
    local state = ctx.state
    local now = APISurface.now()
    
    -- Refresh if needed
    if now >= state.bag.next_space_check_time then
        M.get_total_free_slots(ctx)
        state.bag.next_space_check_time = now + 2.0
    end
    
    return state.bag.cached_free_slots
end

--- Check if bags are full
-- @param ctx table context
-- @return boolean
function M.is_bags_full(ctx)
    local free = M.get_total_free_slots(ctx)
    return free <= 0
end

--- Get bag full confirmation count
-- @param ctx table context
-- @return number
function M.get_full_confirm_count(ctx)
    return ctx.state.bag.full_confirm_count
end

--- Increment bag full confirmation
-- @param ctx table context
function M.increment_full_confirm(ctx)
    ctx.state.bag.full_confirm_count = ctx.state.bag.full_confirm_count + 1
end

--- Reset bag full confirmation
-- @param ctx table context
function M.reset_full_confirm(ctx)
    ctx.state.bag.full_confirm_count = 0
end

return M
