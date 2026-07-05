-- =============================================================================
-- Eax's Fishing - Menu (v2.4.1 — reorganized with collapsible tree nodes)
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
    C.new_badge = color.new(100, 255, 100, 255)  -- green "NEW" badge
end

function M.render_menu(ctx)
    local config = ctx.deps.config
    local color  = ctx.deps.color
    local core   = ctx.deps.core

    if not C.brand then init_colors(color) end

    local h = nil
    if core and core.menu and type(core.menu.header) == "function" then
        local ok, result = pcall(core.menu.header)
        if ok and result then h = result end
    end
    if not h then return end  -- Can't render without header API

    config.menu.root:render("Eax's Fishing", function()

        -- ── Identity ───────────────────────────────────────────────────────
        h:render("Eax's Fishing  v2.4.1", C.brand)
        h:render("Enable / Disable in the Control Panel", C.dim)

        -- ═══════════════════════════════════════════════════════════════════
        -- GEAR & LURES (collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.gear_tree then
            config.menu.gear_tree:render("Gear & Lures", function()
                h:render("GEAR", C.section)
                config.menu.auto_equip:render("Auto-Equip Fishing Pole",
                    "Automatically equips your best pole from any bag slot before casting.")
                config.menu.auto_lure:render("Auto-Apply Lure",
                    "Uses the highest-bonus lure in your bags. Applies to the pole, not yourself.")
                config.menu.auto_cook:render("Auto-Cook Raw Fish",
                    "When a campfire is nearby, casts cooking recipes to turn raw fish into valuable cooked buff food.")

                h:render("LURE OPTIONS", C.sub)
                config.menu.show_lure_timer:render("Show Lure Timer in HUD",
                    "Displays remaining lure time in the HUD. Turns gray in the last 60s.")
                config.menu.lure_expiry_warn_secs:render("Lure Expiry Warning (s)",
                    "Plays a sound this many seconds before the lure expires. Default 60s.")
            end)
        else
            -- Fallback if tree_node not available
            h:render("GEAR & LURES", C.section)
            config.menu.auto_equip:render("Auto-Equip Fishing Pole", "")
            config.menu.auto_lure:render("Auto-Apply Lure", "")
            config.menu.auto_cook:render("Auto-Cook Raw Fish", "")
            config.menu.show_lure_timer:render("Show Lure Timer in HUD", "")
            config.menu.lure_expiry_warn_secs:render("Lure Expiry Warning (s)", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- TIMING & HUMANIZER (collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.timing_tree then
            config.menu.timing_tree:render("Timing & Humanizer", function()
                h:render("Natural Timing", C.section)
                config.menu.humanizer_enabled:render("Natural Timing  (master toggle)",
                    "Enables a randomised behavior profile that shifts your timing every 15-25 min so no two sessions look the same.")
                config.menu.ultra_safe_mode:render("Ultra-Safe Mode",
                    "Pushes all delays to maximum. Recommended on high-value or watched accounts.")
                config.menu.cast_jitter_enabled:render("Cast Jitter",
                    "Applies a small random facing offset before each cast so bobbers land in different spots.")
                config.menu.cast_jitter_degrees:render("Jitter Range (degrees)",
                    "How far the bobber landing can vary. Default 5 degrees. ±this many degrees from current facing.")

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
                config.menu.anti_afk_interval_min:render("Jump interval min (s)", "")
                config.menu.anti_afk_interval_max:render("Jump interval max (s)", "")

                h:render("Small Delays", C.sub)
                config.menu.enable_loot_delays:render("Stagger Loot Clicks", "")
                config.menu.enable_equip_delays:render("Stagger Pole Equip", "")
                config.menu.enable_lure_delays:render("Stagger Lure Apply", "")

                h:render("Miss Simulation", C.sub)
                config.menu.enable_missed_catches:render("Deliberate Misses",
                    "Randomly misses 1 in ~25 catches after a streak of 5+. Looks human.")
                config.menu.enable_fish_escape:render("Fish Escape Window", "")

                h:render("Bite Detection (Fallback)", C.sub)
                config.menu.dip_bite_fallback:render("Z-Dip Splash Detection",
                    "Detects bites by the bobber diving below its rest line. Needed while Sylvanas' bobber:does_bobber_have_fish() is broken. Keep ON.")
                config.menu.dip_threshold:render("Dip Sensitivity (x10 yd)", "")

                h:render("Session Limits", C.sub)
                config.menu.session_time_limit:render("Auto-Stop After (min)",
                    "Hard-stops fishing after this many minutes (0 = no limit).")
            end)
        else
            h:render("TIMING & HUMANIZER", C.section)
            config.menu.humanizer_enabled:render("Natural Timing", "")
            config.menu.ultra_safe_mode:render("Ultra-Safe Mode", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- POOL ROUTING (collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.pool_tree then
            config.menu.pool_tree:render("Pool Routing", function()
                h:render("POOL NAVIGATION", C.section)
                h:render("Requires SentinelNavClient to be loaded", C.warning)
                config.menu.pool_tracking:render("Navigate to Pools",
                    "Automatically walks to nearby fish pools before casting.")
                config.menu.smart_pool_ranking:render("Smart Pool Ranking",
                    "When enabled, prefers high-value pools over closer low-value pools.")
                config.menu.only_pools_wreckage:render("Only Cast at Pools",
                    "Skips open water — only casts when standing near a named pool.")
                config.menu.pool_search_range:render("Scan Range (y)", "")
                config.menu.pool_standoff_distance:render("Stand Distance (y)", "")
                config.menu.pool_shore_depth_tolerance:render("Shore Depth Tolerance", "")

                h:render("DEPLETION & TELEMETRY", C.sub)
                config.menu.pool_depletion_threshold:render("Pool Depletion Threshold",
                    "Skip pool after this many casts with 0 catches. Default 5.")
                config.menu.show_cast_rate:render("Show Cast Success Rate",
                    "Shows cast success percentage in HUD.")
            end)
        else
            h:render("POOL ROUTING", C.section)
            h:render("Requires SentinelNavClient to be loaded", C.warning)
            config.menu.pool_tracking:render("Navigate to Pools", "")
            config.menu.smart_pool_ranking:render("Smart Pool Ranking", "")
            config.menu.only_pools_wreckage:render("Only Cast at Pools", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- AUTO-MATION (v2.4.0 features — collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.auto_tree then
            config.menu.auto_tree:render("Automation (v2.4.0)", function()
                h:render("BAG MANAGEMENT", C.section)
                config.menu.auto_open_containers:render("Auto-Open Containers",
                    "Opens clams, chests, and supply crates between casts to free bag space.")
                config.menu.auto_sell_junk:render("Auto-Sell Junk at Vendor",
                    "Sells gray-quality items when a vendor window is open. Opt-in.")
                config.menu.auto_delete_junk:render("Auto-Delete Worthless Items",
                    "Deletes gray items with no vendor value when bags are full. Destructive — opt-in.")
                config.menu.auto_hearth_full:render("Auto-Hearth When Bags Full",
                    "Uses Hearthstone to teleport to inn for vendoring. Saves return position.")
                config.menu.auto_stop_full:render("Stop When Bags Full",
                    "Disables fishing after 3 consecutive full-bag checks.")

                h:render("RARE CATCHES", C.sub)
                config.menu.auto_pinchy:render("Auto-Use Mr. Pinchy",
                    "Detects Mr. Pinchy (27436) in bags and auto-uses its 3 charges. Alerts on each use.")

                h:render("QUEST TRACKING", C.sub)
                h:render("Auto-detected from quest items in bags", C.dim)
                -- Quest tracking is passive — no toggle needed, just info

                h:render("BUFFS & CONSUMABLES", C.sub)
                config.menu.auto_water_walking:render("Auto-Water Walking",
                    "Applies Water Walking (Shaman), Levitate (Priest), or Path of Frost (DK) before casting. Falls back to Elixir of Water Walking consumable. Disabled by default — opt-in for water fishing.")
                config.menu.water_walking_refresh_secs:render("Water Walking Refresh (s)",
                    "Re-applies the buff this many seconds before it expires. Default 60s. Set to 0 to disable refresh (only applies when missing).")

                h:render("SESSION RESILIENCE", C.sub)
                config.menu.auto_vendor_repair:render("Auto Repair at Vendor",
                    "Repairs all gear when a vendor window is open.")
                config.menu.auto_relog:render("Disconnect Alert",
                    "Detects server disconnects and alerts with sound + overlay. (Detection-only — no relog API.)")
                config.menu.night_fishing_only:render("Night-Only Fishing",
                    "Only fish during night time window. (Framework — API not yet available.)")

                h:render("WHISPER DETECTION", C.sub)
                config.menu.auto_respond:render("Whisper Alert",
                    "Alerts when a whisper is received (sound + overlay). Detection-only — no auto-reply API.")
            end)
        else
            h:render("AUTOMATION (v2.4.0)", C.section)
            config.menu.auto_open_containers:render("Auto-Open Containers", "")
            config.menu.auto_pinchy:render("Auto-Use Mr. Pinchy", "")
            config.menu.auto_sell_junk:render("Auto-Sell Junk", "")
            config.menu.auto_delete_junk:render("Auto-Delete Junk", "")
            config.menu.auto_hearth_full:render("Auto-Hearth", "")
            config.menu.auto_stop_full:render("Stop When Bags Full", "")
            config.menu.auto_vendor_repair:render("Auto Repair", "")
            config.menu.auto_relog:render("Disconnect Alert", "")
            config.menu.auto_respond:render("Whisper Alert", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- SOUND ALERTS (v2.4.1 — collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.sound_tree then
            config.menu.sound_tree:render("Sound Alerts (v2.4.1)", function()
                h:render("AUDIO FEEDBACK", C.section)
                config.menu.sound_alerts_enabled:render("Enable Sound Alerts",
                    "Master toggle for all sound alerts. Turn off to silence everything.")
                h:render("Per-Event Sounds", C.sub)
                config.menu.sound_rare:render("Rare Catch Sound",
                    "Quest Complete fanfare when you catch something valuable.")
                config.menu.sound_bags_full:render("Bags Full Sound",
                    "PvP warning sound when bags are full and fishing stops.")
                config.menu.sound_pool_depleted:render("Pool Depleted Sound",
                    "Subtle 'done' sound when a pool is fished out.")
                config.menu.sound_lure_expiring:render("Lure Expiring Sound",
                    "Soft chime when lure is about to expire.")
                config.menu.sound_whisper:render("Whisper Sound",
                    "Whisper notification sound when someone messages you.")
                config.menu.sound_disconnect:render("Disconnect Sound",
                    "Error buzzer when server connection is lost.")
                config.menu.sound_catch:render("Catch Sound",
                    "Soft splash on every catch. Can be noisy — off by default.")
            end)
        else
            h:render("SOUND ALERTS (v2.4.1)", C.section)
            config.menu.sound_alerts_enabled:render("Enable Sound Alerts", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- STEALTH (collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.stealth_tree then
            config.menu.stealth_tree:render("Stealth", function()
                h:render("ANTI-DETECTION", C.section)
                config.menu.stealth_mode:render("Slow Down When Players Near",
                    "Temporarily slows cast rhythm and takes longer breaks when another player is nearby. Looks less robotic.")
                config.menu.stealth_range:render("Stealth Range (y)",
                    "How close a player must be to trigger slowdown. Default 30y.")
            end)
        else
            h:render("STEALTH", C.section)
            config.menu.stealth_mode:render("Slow Down When Players Near", "")
            config.menu.stealth_range:render("Stealth Range (y)", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- VISUALS & HUD (collapsible)
        -- ═══════════════════════════════════════════════════════════════════
        if config.menu.visuals_tree then
            config.menu.visuals_tree:render("Visuals & HUD", function()
                h:render("ESP", C.section)
                config.menu.esp_enabled:render("Pool ESP",
                    "Draws lines to fishing pools in range.")
                config.menu.esp_range:render("ESP Range (y)", "")

                h:render("HUD", C.sub)
                config.menu.show_stats:render("Session HUD",
                    "Shows casts, catches, catch rate, fish count, gold gained, and more on screen.")
                config.menu.show_cast_rate:render("Show Cast Success Rate", "")
                config.menu.show_catch_streak:render("Show Catch Streak",
                    "Shows current consecutive catch streak + best streak.")
                config.menu.show_coordinates:render("Show Coordinates",
                    "Shows current X, Y position in HUD.")
                config.menu.rare_alert_enabled:render("Rare Catch Alert",
                    "Plays a sound and flashes a big message when you catch something valuable.")

                h:render("SAFETY", C.sub)
                config.menu.auto_pause_low_hp:render("Auto-Pause on Low HP",
                    "Pauses fishing when HP drops below threshold. Prevents fishing while dying.")
                config.menu.auto_pause_hp_threshold:render("Low HP Threshold %",
                    "Pause fishing when HP falls below this percentage. Default 20%.")
            end)
        else
            h:render("VISUALS & HUD", C.section)
            config.menu.esp_enabled:render("Pool ESP", "")
            config.menu.show_stats:render("Session HUD", "")
            config.menu.rare_alert_enabled:render("Rare Catch Alert", "")
        end

        -- ═══════════════════════════════════════════════════════════════════
        -- DEBUG
        -- ═══════════════════════════════════════════════════════════════════
        h:render("DEBUG", C.muted)
        config.menu.debug:render("Console Logging",
            "Logs object scans and API calls. Turn off during normal use.")

    end)
end

return M
