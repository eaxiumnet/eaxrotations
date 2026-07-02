-- =============================================================================
-- Eax's Fishing - Menu
-- =============================================================================

local M = {}

-- Brand colors
local C = {}

local function init_colors(color)
    C.brand    = color.new(80,  200, 255, 255)   -- icy blue  (title)
    C.section  = color.new(255, 195, 0,   255)   -- amber     (section headers)
    C.sub      = color.new(160, 220, 160, 255)   -- soft green (subsection)
    C.warning  = color.new(255, 120, 60,  255)   -- orange    (pool routing note)
    C.muted    = color.new(130, 130, 140, 255)   -- grey      (meta info)
    C.dim      = color.new(90,  90,  100, 255)   -- dimmer grey
end

function M.render_menu(ctx)
    local config = ctx.deps.config
    local color  = ctx.deps.color
    local core   = ctx.deps.core

    if not C.brand then init_colors(color) end

    local h = core.menu.header()

    config.menu.root:render("Eax's Fishing", function()

        -- ── Identity ───────────────────────────────────────────────────────
        h:render("Eax's Fishing  v2.1.0", C.brand)
        h:render("Enable / Disable in the Control Panel", C.dim)

        -- ── Gear ───────────────────────────────────────────────────────────
        h:render("GEAR", C.section)
        config.menu.auto_equip:render("Auto-Equip Fishing Pole",
            "Automatically equips your best pole from any bag slot before casting.")
        config.menu.auto_lure:render("Auto-Apply Lure",
            "Uses the highest-bonus lure in your bags. Applies to the pole, not yourself.")

        -- ── Timing (Humanizer) ─────────────────────────────────────────────
        h:render("TIMING", C.section)
        config.menu.humanizer_enabled:render("Natural Timing  (master toggle)",
            "Enables a randomised behavior profile that shifts your timing every 15-25 min so no two sessions look the same.")
        config.menu.ultra_safe_mode:render("Ultra-Safe Mode",
            "Pushes all delays to maximum. Recommended on high-value or watched accounts.")

        h:render("Cast Delays", C.sub)
        config.menu.cast_delay_min_ms:render("Min delay after catch (ms)",
            "Shortest pause before the next cast. Default 900ms.")
        config.menu.cast_delay_max_ms:render("Max delay after catch (ms)",
            "Longest pause before the next cast. Default 2200ms.")

        h:render("Reaction Delays", C.sub)
        config.menu.catch_delay_min_ms:render("Min reaction time (ms)",
            "Fastest click after a bite. 0 = instant. Default 150ms.")
        config.menu.catch_delay_max_ms:render("Max reaction time (ms)",
            "Slowest click after a bite. Default 400ms.")

        h:render("Breaks & AFK", C.sub)
        config.menu.break_frequency:render("Micro-break Frequency  (0 = off)",
            "How often to pause 10-30s mid-session. Higher = more frequent breaks.")
        config.menu.anti_afk_enabled:render("Anti-AFK Jump",
            "Jumps every so often to prevent idle-disconnect.")
        config.menu.anti_afk_interval_min:render("Jump interval min (s)",
            "Shortest gap between jumps. Default 60s.")
        config.menu.anti_afk_interval_max:render("Jump interval max (s)",
            "Longest gap between jumps. Default 180s.")

        h:render("Small Delays", C.sub)
        config.menu.enable_loot_delays:render("Stagger Loot Clicks",
            "120-350ms between each loot click, scaled by behavior profile.")
        config.menu.enable_equip_delays:render("Stagger Pole Equip",
            "Brief pause before swapping to fishing pole.")
        config.menu.enable_lure_delays:render("Stagger Lure Apply",
            "0.4-1.0s pause before applying a lure.")

        h:render("Miss Simulation", C.sub)
        config.menu.enable_missed_catches:render("Deliberate Misses",
            "Randomly misses 1 in ~25 catches after a streak of 5+. Looks human.")
        config.menu.enable_fish_escape:render("Fish Escape Window",
            "If you don't click within the escape window, the fish gets away.")

        -- ── Pool Routing ───────────────────────────────────────────────────
        h:render("POOL ROUTING", C.section)
        h:render("Requires SentinelNavClient to be loaded", C.warning)
        config.menu.pool_tracking:render("Navigate to Pools",
            "Automatically walks to nearby fish pools before casting.")
        config.menu.only_pools_wreckage:render("Only Cast at Pools",
            "Skips open water — only casts when standing near a named pool.")
        config.menu.pool_search_range:render("Scan Range (y)",
            "How far to look for pools. Default 250y.")
        config.menu.pool_standoff_distance:render("Stand Distance (y)",
            "Distance from pool edge when positioning. Default 15y.")
        config.menu.pool_shore_depth_tolerance:render("Shore Depth Tolerance",
            "Allows standing spots slightly below pool surface. 0 = dry land only.")

        -- ── Visuals ────────────────────────────────────────────────────────
        h:render("VISUALS", C.section)
        config.menu.esp_enabled:render("Pool ESP",
            "Draws lines to fishing pools in range.")
        config.menu.esp_range:render("ESP Range (y)",
            "How far to draw pool lines. Default 150y.")
        config.menu.show_stats:render("Session HUD",
            "Shows casts, catches, catch rate and session time on screen.")

        -- ── Utility ────────────────────────────────────────────────────────
        h:render("UTILITY", C.section)
        config.menu.auto_stop_full:render("Stop When Bags Full",
            "Disables fishing after 3 consecutive full-bag checks.")
        config.menu.auto_vendor_repair:render("Auto Repair at Vendor",
            "Repairs all gear when a vendor window is open.")

        -- ── Debug ──────────────────────────────────────────────────────────
        h:render("DEBUG", C.muted)
        config.menu.debug:render("Console Logging",
            "Logs object scans and API calls. Turn off during normal use.")

    end)
end

return M
