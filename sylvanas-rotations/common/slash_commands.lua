-- =============================================================================
-- SLASH COMMANDS - Flux AIO command handler
-- Converted from flux/rotation/source/aio/settings.lua lines 757-811
-- =============================================================================

local core = _G.core
local FluxCompat = require("common/flux_compat")
local format = string.format

-- ============================================================================
-- COMMAND HANDLER
-- =============================================================================

local function handle_flux_command(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    
    -- Default: open settings
    if msg == "" then
        -- Open Sylvanas settings menu
        core.menu.open()
        return
    end
    
    -- Burst command
    if msg == "burst" then
        FluxCompat.set_force_flag("burst", 3.0)
        print("|cFF00FF00[Flux AIO]|r |cFFFFFF00Burst|r cooldowns activated!")
        return
    end
    
    -- Defensive command
    if msg == "defensive" or msg == "def" then
        FluxCompat.set_force_flag("defensive", 3.0)
        print("|cFF00FF00[Flux AIO]|r |cFFFFFF00Defensive|r cooldowns activated!")
        return
    end
    
    -- Gap closer command
    if msg == "gap" then
        FluxCompat.set_force_flag("gap", 3.0)
        print("|cFF00FF00[Flux AIO]|r |cFFFFFF00Gap closer|r activated!")
        return
    end
    
    -- Status/Dashboard toggle
    if msg == "status" then
        local dashboard = require("common/dashboard")
        if dashboard and dashboard.toggle then
            dashboard.toggle()
        else
            print("|cFF00FF00[Flux AIO]|r Dashboard not yet loaded.")
        end
        return
    end
    
    -- Debug log toggle
    if msg == "log" or msg == "debug" or msg == "fluxlog" then
        FluxCompat.toggle_debug_log()
        return
    end
    
    -- Help command
    if msg == "help" then
        print("|cFF00FF00[Flux AIO]|r Slash commands:")
        print("  /flux           - Open settings")
        print("  /flux burst     - Force burst cooldowns (3s)")
        print("  /flux def       - Force defensive cooldowns (3s)")
        print("  /flux gap       - Use gap closer (3s)")
        print("  /flux status    - Toggle combat dashboard")
        print("  /flux log       - Toggle debug log window")
        print("  /flux help      - Show this help")
        return
    end
    
    -- Unknown subcommand: fallback to settings toggle
    core.menu.open()
end

-- ============================================================================
-- COMMAND REGISTRATION
-- =============================================================================

-- Register /flux command
core.register_slash_command("flux", handle_flux_command)

-- Register /faio alias
core.register_slash_command("faio", handle_flux_command)

-- Register /fluxlog for debug window
core.register_slash_command("fluxlog", function()
    FluxCompat.toggle_debug_log()
end)

-- ============================================================================
-- MODULE LOADED
-- =============================================================================
print("|cFF00FF00[Flux AIO]|r Slash commands loaded! Use /flux or /faio")

-- Return API for other modules
return {
    handle_flux_command = handle_flux_command,
}
