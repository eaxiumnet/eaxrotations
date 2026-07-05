-- Eax's Fishing - Configuration v2.2.1
local ok_izi, izi = pcall(require, "common/izi_sdk")
if not ok_izi then izi = nil end
local ok_color, color = pcall(require, "common/color")
if not ok_color then color = nil end

-- Dummy menu item that returns safe defaults when core.menu APIs fail.
-- Prevents nil crashes in engine.lua when a menu item is missing.
local DUMMY = {
    get_state = function() return false end,
    set_state = function() end,
    get       = function() return 0 end,
    set       = function() end,
    render    = function() end,
}

-- Safely call a core.menu factory; return DUMMY on any failure.
-- `core.menu` is captured ONCE, nil-safely, so the eager `core.menu.tree_node`
-- argument evaluation below never crashes when `core` or `core.menu` is absent
-- (unit-test environments, older runtime, loading screen, etc.).
local _menu = (core and core.menu) or {}
local function safe_menu(fn, ...)
    if type(fn) == "function" then
        local ok, result = pcall(fn, ...)
        if ok and result ~= nil then return result end
    end
    return DUMMY
end

local config = {}

config.menu = {
    root    = safe_menu(_menu.tree_node),
    enabled = safe_menu(_menu.checkbox, false, "fishing_enabled"),

    -- v2.4.1: Collapsible menu sections
    gear_tree     = safe_menu(_menu.tree_node),
    timing_tree   = safe_menu(_menu.tree_node),
    pool_tree     = safe_menu(_menu.tree_node),
    auto_tree     = safe_menu(_menu.tree_node),
    sound_tree    = safe_menu(_menu.tree_node),
    stealth_tree  = safe_menu(_menu.tree_node),
    visuals_tree  = safe_menu(_menu.tree_node),

    -- Gear
    auto_equip    = safe_menu(_menu.checkbox, true,  "fishing_auto_equip"),
    auto_lure     = safe_menu(_menu.checkbox, true,  "fishing_auto_lure"),
    auto_cook     = safe_menu(_menu.checkbox, false, "fishing_auto_cook"),
    -- v2.4.0: container + Mr. Pinchy
    auto_open_containers = safe_menu(_menu.checkbox, true,  "fishing_auto_open_containers"),
    auto_pinchy          = safe_menu(_menu.checkbox, true,  "fishing_auto_pinchy"),

    -- Stealth Mode
    stealth_mode  = safe_menu(_menu.checkbox, true,  "fishing_stealth_mode"),
    stealth_range = safe_menu(_menu.slider_int, 10, 100, 30, "fishing_stealth_range"),

    -- Rare Catch Alert
    rare_alert_enabled = safe_menu(_menu.checkbox, true, "fishing_rare_alert"),

    -- Visuals
    esp_enabled = safe_menu(_menu.checkbox, true,  "fishing_esp_enabled"),
    esp_range   = safe_menu(_menu.slider_int, 10, 500, 150, "fishing_esp_range"),
    show_stats  = safe_menu(_menu.checkbox, true,  "fishing_show_stats"),

    -- Pool Navigation
    pool_tracking            = safe_menu(_menu.checkbox, false, "fishing_pool_tracking"),
    smart_pool_ranking       = safe_menu(_menu.checkbox, true,  "fishing_smart_pool_ranking"),
    only_pools_wreckage      = safe_menu(_menu.checkbox, false, "fishing_only_pools_wreckage"),
    pool_search_range        = safe_menu(_menu.slider_int, 10, 500, 250, "fishing_pool_search_range"),
    pool_standoff_distance   = safe_menu(_menu.slider_int, 5,  40,  15,  "fishing_pool_standoff_distance"),
    pool_shore_depth_tolerance = safe_menu(_menu.slider_int, 0, 8, 0,    "fishing_pool_shore_depth_tolerance"),

    -- Humanizer
    -- humanizer_enabled is the master gate for all timing variance
    humanizer_enabled   = safe_menu(_menu.checkbox, true,  "fishing_humanizer_enabled"),
    random_delay        = safe_menu(_menu.checkbox, true,  "fishing_random_delay"),  -- legacy alias
    -- Cast delay: time between finishing one catch and casting again
    cast_delay_min_ms   = safe_menu(_menu.slider_int, 0, 5000, 900,  "fishing_cast_delay_min_ms"),
    cast_delay_max_ms   = safe_menu(_menu.slider_int, 0, 5000, 2200, "fishing_cast_delay_max_ms"),
    -- Catch reaction: time between bite detection and bobber click
    catch_delay_min_ms  = safe_menu(_menu.slider_int, 0, 1000, 150, "fishing_catch_delay_min_ms"),
    catch_delay_max_ms  = safe_menu(_menu.slider_int, 0, 1000, 400, "fishing_catch_delay_max_ms"),
    break_frequency     = safe_menu(_menu.slider_int, 0, 100, 10,  "fishing_break_freq"),
    anti_afk_enabled      = safe_menu(_menu.checkbox, true,  "fishing_anti_afk_enabled"),
    anti_afk_interval_min = safe_menu(_menu.slider_int, 15, 300, 60,  "fishing_anti_afk_min"),
    anti_afk_interval_max = safe_menu(_menu.slider_int, 15, 600, 180, "fishing_anti_afk_max"),

    -- Advanced humanization toggles
    enable_missed_catches = safe_menu(_menu.checkbox, true,  "fishing_enable_missed_catches"),
    enable_loot_delays    = safe_menu(_menu.checkbox, true,  "fishing_enable_loot_delays"),
    enable_equip_delays   = safe_menu(_menu.checkbox, true,  "fishing_enable_equip_delays"),
    enable_lure_delays    = safe_menu(_menu.checkbox, true,  "fishing_enable_lure_delays"),
    enable_fish_escape    = safe_menu(_menu.checkbox, true,  "fishing_enable_fish_escape"),
    ultra_safe_mode       = safe_menu(_menu.checkbox, false, "fishing_ultra_safe_mode"),
    cast_jitter_enabled   = safe_menu(_menu.checkbox, true,  "fishing_cast_jitter_enabled"),
    cast_jitter_degrees   = safe_menu(_menu.slider_int, 1, 15, 5, "fishing_cast_jitter_deg"),
    -- Z-dip bite fallback. Sylvanas' bobber:does_bobber_have_fish() currently
    -- always returns false, so we detect the splash by the bobber dipping
    -- below its resting Z baseline. Toggle lets users disable once PS fixes
    -- the API (or if it causes false clicks).
    dip_bite_fallback     = safe_menu(_menu.checkbox, true,  "fishing_dip_bite_fallback"),
    dip_threshold         = safe_menu(_menu.slider_int, 5, 50, 10, "fishing_dip_threshold"), -- 0.10 yd

    -- Session limits (anti-marathon detection)
    session_time_limit    = safe_menu(_menu.slider_int, 0, 480, 0, "fishing_session_limit"),

    -- Utility
    auto_stop_full    = safe_menu(_menu.checkbox, true,  "fishing_auto_stop_full"),
    auto_vendor_repair = safe_menu(_menu.checkbox, false, "fishing_auto_vendor_repair"),
    debug             = safe_menu(_menu.checkbox, false, "fishing_debug"),

    -- v2.4.0: Auto-sell junk + auto-delete worthless
    auto_sell_junk    = safe_menu(_menu.checkbox, false, "fishing_auto_sell_junk"),
    auto_delete_junk  = safe_menu(_menu.checkbox, false, "fishing_auto_delete_junk"),

    -- v2.4.0: Pool depletion + cast telemetry
    pool_depletion_threshold = safe_menu(_menu.slider_int, 3, 15, 5, "fishing_pool_depletion_threshold"),
    show_cast_rate    = safe_menu(_menu.checkbox, true,  "fishing_show_cast_rate"),

    -- v2.4.0: Whisper responder
    auto_respond      = safe_menu(_menu.checkbox, false, "fishing_auto_respond"),

    -- v2.4.0: Auto-hearth when bags full
    auto_hearth_full  = safe_menu(_menu.checkbox, false, "fishing_auto_hearth_full"),

    -- v2.4.0: Auto-relog on disconnect
    auto_relog        = safe_menu(_menu.checkbox, false, "fishing_auto_relog"),

    -- v2.4.0: Night-only fishing (time window)
    night_fishing_only = safe_menu(_menu.checkbox, false, "fishing_night_only"),

    -- v2.4.1: Sound alerts (master + per-event)
    sound_alerts_enabled  = safe_menu(_menu.checkbox, true,  "fishing_sound_alerts"),
    sound_rare            = safe_menu(_menu.checkbox, true,  "fishing_sound_rare"),
    sound_bags_full       = safe_menu(_menu.checkbox, true,  "fishing_sound_bags_full"),
    sound_pool_depleted   = safe_menu(_menu.checkbox, false, "fishing_sound_pool_depleted"),
    sound_lure_expiring   = safe_menu(_menu.checkbox, true,  "fishing_sound_lure_expiring"),
    sound_whisper         = safe_menu(_menu.checkbox, true,  "fishing_sound_whisper"),
    sound_disconnect      = safe_menu(_menu.checkbox, true,  "fishing_sound_disconnect"),
    sound_catch           = safe_menu(_menu.checkbox, false, "fishing_sound_catch"),

    -- v2.4.1: QoL toggles
    show_coordinates      = safe_menu(_menu.checkbox, true,  "fishing_show_coords"),
    show_catch_streak     = safe_menu(_menu.checkbox, true,  "fishing_show_streak"),
    show_lure_timer       = safe_menu(_menu.checkbox, true,  "fishing_show_lure_timer"),
    lure_expiry_warn_secs = safe_menu(_menu.slider_int, 30, 300, 60, "fishing_lure_expiry_warn"),
    auto_pause_low_hp     = safe_menu(_menu.checkbox, false, "fishing_auto_pause_low_hp"),
    auto_pause_hp_threshold = safe_menu(_menu.slider_int, 1, 50, 20, "fishing_pause_hp_threshold"),

    -- v2.4.2: Water walking buff
    auto_water_walking  = safe_menu(_menu.checkbox, false, "fishing_auto_water_walking"),
    water_walking_refresh_secs = safe_menu(_menu.slider_int, 10, 300, 60, "fishing_water_walk_refresh"),

    -- v2.4.3: Advanced stealth
    stealth_face_away = safe_menu(_menu.checkbox, true, "fishing_stealth_face_away"),
}

return config
