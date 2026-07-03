-- =============================================================================
-- Eax's Fishing - Main Entry Point
-- Version: 2.1.0
-- =============================================================================

local APISurface = require("core/api_surface")
local constants = require("constants")
local config = require("config")
local control_panel_helper = require("common/utility/control_panel_helper")
local has_inventory_helper, inventory_helper = pcall(require, "common/utility/inventory_helper")
local has_coords_helper, coords_helper = pcall(require, "common/utility/coords_helper")
local has_color_helper, color_helper = pcall(require, "common/color")
local App = require("core/app")

if not has_inventory_helper then inventory_helper = nil end
if not has_coords_helper   then coords_helper   = nil end
if not has_color_helper    then color_helper    = nil end

APISurface.print("[EaxFishing] v2.1.0 loaded")

-- Seed the PRNG so behavior profiles, delays, and break timing are non-deterministic
local now = APISurface.now()
if now and now > 0 then
    math.randomseed(now % 1000000)
end

-- Create app instance with dependency injection
local app = App.new({
    core = core,  -- Kept for legacy compatibility
    config = config,
    constants = constants,
    control_panel_helper = control_panel_helper,
    inventory_helper = inventory_helper,
    coords_helper = coords_helper,
    color = color_helper,
})

-- Register callbacks using APISurface
-- Combined update loop (fishing tick + vendor repair)
-- Both are called from a single callback to avoid overwriting if the runtime
-- only supports one handler per registration type.
APISurface.register_on_update(function()
    local ok, err = pcall(app.on_update)
    if not ok then
        APISurface.print("[EaxFishing] Update error: " .. tostring(err))
    end
    -- Vendor repair has its own internal throttle, so calling every tick is safe.
    if config.menu.auto_vendor_repair and config.menu.auto_vendor_repair:get_state() then
        local ok2, err2 = pcall(app.on_vendor_update)
        if not ok2 then
            APISurface.print("[EaxFishing] Vendor error: " .. tostring(err2))
        end
    end
end)

-- Render callback for ESP/HUD
APISurface.register_on_render(function()
    local ok, err = pcall(app.on_render)
    if not ok then
        APISurface.print("[EaxFishing] Render error: " .. tostring(err))
    end
end)

-- Register PS menu callback (standard menu)
APISurface.register_on_render_menu(function()
    local ok, err = pcall(app.on_render_menu)
    if not ok then
        APISurface.print("[EaxFishing] Menu error: " .. tostring(err))
    end
end)

-- Register control panel callback
APISurface.register_on_render_control_panel(function()
    local ok, result = pcall(app.on_render_control_panel)
    if not ok then
        APISurface.print("[EaxFishing] Control panel error: " .. tostring(result))
        return {}
    end
    return result
end)

return app
