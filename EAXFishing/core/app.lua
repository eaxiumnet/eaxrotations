-- =============================================================================
-- Core/App Module - Application bootstrap
-- Uses APISurface for all runtime operations
-- =============================================================================

local Context = require("core/context")
local Engine = require("fishing/engine")
local Vendor = require("inventory/vendor")
local Render = require("ui/render")
local Menu = require("ui/menu")
local ControlPanel = require("ui/control_panel")
local APISurface = require("core/api_surface")
local Responder = require("core/responder")

local M = {}

--- Create new app instance
--- @param deps table dependencies
--- @return table app
function M.new(deps)
    local ctx = Context.create(deps)
    
    return {
        ctx = ctx,
        
        on_update = function()
            Engine.tick(ctx)
        end,
        
        on_vendor_update = function()
            Vendor.try_vendor_repair(ctx, APISurface.now())
        end,
        
        on_render = function()
            Render.render(ctx)
        end,
        
        on_render_menu = function()
            Menu.render_menu(ctx)
        end,
        
        on_render_control_panel = function()
            return ControlPanel.render_control_panel(ctx)
        end,

        -- v2.4.0: Game event handler (whisper detection, etc.)
        on_game_event = function(event_name, args)
            Responder.on_game_event(ctx, event_name, args)
        end,
    }
end

return M
