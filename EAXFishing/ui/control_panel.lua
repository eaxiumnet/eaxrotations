-- =============================================================================
-- UI/ControlPanel Module - Control panel rendering
-- =============================================================================

local M = {}

--- Render control panel
-- @param ctx table context
-- @return table elements array
function M.render_control_panel(ctx)
    local state = ctx.state
    local deps = ctx.deps
    local elements = {}
    
    local current = deps.config.menu.enabled:get_state()
    local cp_id = "openfishing_main_toggle_" .. state.safety.stop_id
    
    local new_state = deps.control_panel_helper:insert_key_checkbox_(
        elements, "Eax's Fishing", current, 0, false, cp_id
    )
    
    -- Safety lock for bag full
    if not current and state.bag.next_alert_time < 0.0 then
        if new_state == false then
            state.bag.next_alert_time = 0.0
        else
            state.safety.stop_id = state.safety.stop_id + 1
            table.insert(elements, {type="label", text="Safety lock: toggle OFF once, then ON"})
            return elements
        end
    end
    
    -- Handle toggle change
    if new_state ~= current then
        -- Safely set menu value
        local item = deps.config.menu.enabled
        if item then
            if type(item.set_state) == "function" then
                item:set_state(new_state)
            elseif type(item.set) == "function" then
                item:set(new_state)
            end
        end
        
        if new_state then
            state.fishing.failed_cast_count = 0
            state.fishing.consecutive_catches = 0
            state.fishing.awaiting_bobber = false
            state.fishing.status = "Idle"
        else
            state.fishing.awaiting_bobber = false
            -- Stop nav
            local Client = require("navigation/client")
            Client.stop(ctx)
        end
    end
    
    -- Status display
    table.insert(elements, {type="label", text="Status: " .. state.fishing.status})
    table.insert(elements, {type="label", text="Casts: " .. state.session.attempts})
    
    return elements
end

return M
