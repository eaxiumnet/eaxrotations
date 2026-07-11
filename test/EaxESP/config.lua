-- ============================================================================
-- EaxESP/config.lua (PR3)
-- ----------------------------------------------------------------------------
-- What: Default configuration table for EaxESP (merged PR1/PR2/PR3 fields).
-- When: required by tests (test_config_menu) and main sync.
-- Safety: Pure data module; no side effects.
-- ============================================================================

local M = {}

-- Core
M.enabled = true
M.max_distance = 80.0
M.max_esp_per_frame = 32
M.show_box = true
M.show_nameplate = true
M.show_health = true
M.show_connector = true
M.show_distance = true
M.show_offscreen_arrows = true
M.target_highlight = true
M.alpha_fade = false
M.dynamic_font_scale = false
M.force_min_visibility = true
M.min_alpha = 0.90
M.min_font_size = 11
M.box_min_dim = 8
M.box_max_dim = 600
M.min_box_screen_dim = 24
M.use_screen_space_boxes = false
M.show_3d_brackets = true
M.box_3d_fade_with_distance = false
M.visibility_profile = "exploration"

-- Colors and misc (subset for tests)
M.box_color = { 0.30, 0.85, 0.40, 1.00 }
M.name_color = { 1.00, 0.92, 0.20, 1.00 }
M.name_font_size = 13
M.name_offset_y = 6
M.connector_color = { 0.30, 0.85, 0.40, 0.55 }
M.connector_thickness = 1
M.screen_padding = 4
M.health_bar_width = 60
M.health_bar_height = 4
M.health_bar_bg = { 30, 30, 30, 180 }
M.target_color = { 255, 255, 255, 255 }
M.target_thickness_mul = 2.0
M.arrow_size = 10
M.arrow_color = { 255, 234, 51, 200 }
M.alpha_fade_start_pct = 0.30
M.alpha_fade_min = 0.25
M.font_scale_min = 0.60
M.font_scale_start_pct = 0.25
M.distance_suffix = "m"

M.show_radar = true
M.radar_size = 120
M.radar_dot_radius = 3

-- PR3 / others
M.show_cast_bar = true
M.cast_bar_radius = 1.2
M.show_aggro_radius = true
M.show_marker_colors = true
M.show_elite_colors = true
M.occlusion_culling = true
M.dynamic_lod = true
M.lod_threshold = 30
M.lod_cap = 16
M.nameplate_stack = true
M.nameplate_stack_step = 14
M.debug_log = true

return M
