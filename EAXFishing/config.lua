-- Eax's Fishing - Configuration v2.1.0
local ok_izi, izi = pcall(require, "common/izi_sdk")
if not ok_izi then izi = nil end
local ok_color, color = pcall(require, "common/color")
if not ok_color then color = nil end

local config = {}

config.menu = {
    root    = core.menu.tree_node(),
    enabled = core.menu.checkbox(false, "fishing_enabled"),

    -- Gear
    auto_equip = core.menu.checkbox(true,  "fishing_auto_equip"),
    auto_lure  = core.menu.checkbox(true,  "fishing_auto_lure"),

    -- Visuals
    esp_enabled = core.menu.checkbox(true,  "fishing_esp_enabled"),
    esp_range   = core.menu.slider_int(10, 500, 150, "fishing_esp_range"),
    show_stats  = core.menu.checkbox(true,  "fishing_show_stats"),

    -- Pool Navigation
    pool_tracking            = core.menu.checkbox(false, "fishing_pool_tracking"),
    only_pools_wreckage      = core.menu.checkbox(false, "fishing_only_pools_wreckage"),
    pool_search_range        = core.menu.slider_int(10, 500, 250, "fishing_pool_search_range"),
    pool_standoff_distance   = core.menu.slider_int(5,  40,  15,  "fishing_pool_standoff_distance"),
    pool_shore_depth_tolerance = core.menu.slider_int(0, 8, 0,    "fishing_pool_shore_depth_tolerance"),

    -- Humanizer
    -- humanizer_enabled is the master gate for all timing variance
    humanizer_enabled   = core.menu.checkbox(true,  "fishing_humanizer_enabled"),
    random_delay        = core.menu.checkbox(true,  "fishing_random_delay"),  -- legacy alias, kept for backwards compat
    -- Cast delay: time between finishing one catch and casting again
    cast_delay_min_ms   = core.menu.slider_int(0, 5000, 900,  "fishing_cast_delay_min_ms"),
    cast_delay_max_ms   = core.menu.slider_int(0, 5000, 2200, "fishing_cast_delay_max_ms"),
    -- Catch reaction: time between bite detection and bobber click
    catch_delay_min_ms  = core.menu.slider_int(0, 1000, 150, "fishing_catch_delay_min_ms"),
    catch_delay_max_ms  = core.menu.slider_int(0, 1000, 400, "fishing_catch_delay_max_ms"),
    break_frequency     = core.menu.slider_int(0, 100, 10,  "fishing_break_freq"),
    anti_afk_enabled      = core.menu.checkbox(true,  "fishing_anti_afk_enabled"),
    anti_afk_interval_min = core.menu.slider_int(15, 300, 60,  "fishing_anti_afk_min"),
    anti_afk_interval_max = core.menu.slider_int(15, 600, 180, "fishing_anti_afk_max"),

    -- Advanced humanization toggles
    enable_missed_catches = core.menu.checkbox(true,  "fishing_enable_missed_catches"),
    enable_loot_delays    = core.menu.checkbox(true,  "fishing_enable_loot_delays"),
    enable_equip_delays   = core.menu.checkbox(true,  "fishing_enable_equip_delays"),
    enable_lure_delays    = core.menu.checkbox(true,  "fishing_enable_lure_delays"),
    enable_fish_escape    = core.menu.checkbox(true,  "fishing_enable_fish_escape"),
    ultra_safe_mode       = core.menu.checkbox(false, "fishing_ultra_safe_mode"),

    -- Utility
    auto_stop_full    = core.menu.checkbox(true,  "fishing_auto_stop_full"),
    auto_vendor_repair = core.menu.checkbox(false, "fishing_auto_vendor_repair"),
    debug             = core.menu.checkbox(false, "fishing_debug"),
}

return config
