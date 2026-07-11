-- ============================================================================
-- EaxESP - Configuration Defaults (v0.4.3)
-- ----------------------------------------------------------------------------
-- What: Settings table consumed by reader.lua + renderer.lua + main.lua.
--   menu.lua writes back from widget values each frame (Pattern 8).
-- When: Read each frame; safe to mutate live.
-- Safety: All values are plain numbers, tables, or scalars. No functions.
-- ============================================================================

local M = {}

-- Master toggle.
M.enabled = true

-- Distance cap (yards).
M.max_distance = 80.0

-- Per-frame hard cap on draws.
M.max_esp_per_frame = 32

-- FPS-adaptive refresh: scale the candidate-scan interval to the measured
-- frame rate so the overlay stays smooth on 30 / 60 / 144 / 240 FPS displays.
-- 60 FPS is the reference; the interval scale is clamped to [0.5x, 2.0x].
-- (Replaces the dead render_frame_skip knob — the renderer already draws
--  every frame; this governs how often the *data* behind it is refreshed.)
M.fps_adaptive_refresh = true

-- Throttle on the visible-object scan (seconds).
M.refresh_interval = 1.0

-- ===== Render mode =========================================================
M.render_mode = "all" -- "questie" | "all" | "both"

M.show_questie_npcs  = true
M.show_other_npcs  = true
M.show_game_objects  = true
M.show_friendly_players = false

-- ===== Visual style =======================================================
M.show_box   = true
M.show_nameplate = true
M.show_connector = true

M.box_color   = { 76, 216, 102, 255 }
M.box_color_other  = { 216, 140, 51, 255 }
M.box_color_friendly = { 102, 165, 242, 255 }
M.box_color_object = { 178, 76, 216, 255 }
M.box_thickness  = 2
M.box_min_dim   = 8
M.box_max_dim   = 600

M.name_color   = { 255, 234, 51, 255 }
M.name_color_other  = { 255, 209, 102, 255 }
M.name_color_friendly = { 216, 234, 255, 255 }
M.name_color_object = { 216, 140, 255, 255 }
M.name_font_size  = 13
M.name_offset_y  = 6
M.nameplate_z_offset = 2.0  -- yards above feet; tune for race/mount
M.cast_bar_z_offset  = 2.5  -- yards above feet; tune for race/mount
M.show_occlusion  = false  -- hide units behind walls (needs trace_line)
M.show_threat   = false  -- color health bar border by threat %
M.threat_color_low  = { 76, 216, 102, 255 }  -- green: safe
M.threat_color_mid  = { 255, 204, 51, 255 }  -- yellow: gaining
M.threat_color_high = { 255, 80, 80, 255 }  -- red: about to pull

-- ===== Attachment-based positioning (experimental) ========================
-- Uses get_attachment_name_position() for pixel-perfect nameplate anchoring.
-- OFF by default — safe-probed on enable. Falls back to get_position()+offset
-- if the API is broken or returns invalid data.
-- See EaxESP/attachment_safe.lua and plans/bug-report-sylvanas-attachment-api-crash.md
M.use_attachments = false
M.show_aggro_radius = false  -- draw ground circle showing mob aggro range
M.aggro_radius_color_safe  = { 100, 255, 100, 80 }   -- green: outside aggro
M.aggro_radius_color_warn  = { 255, 200, 50, 120 }   -- yellow: close to aggro
M.aggro_radius_color_danger = { 255, 60, 60, 160 }    -- red: inside aggro range

M.connector_color  = { 76, 216, 102, 140 }
M.connector_thickness = 1
M.screen_padding  = 4

-- ===== Health bars ========================================================
M.show_health   = true
M.health_bar_width  = 60
M.health_bar_height = 4
M.health_color_high = { 76, 216, 102, 220 }
M.health_color_mid  = { 255, 204, 51, 220 }
M.health_color_low  = { 255, 51, 51, 220 }
M.health_bar_bg  = { 30, 30, 30, 180 }

-- ===== Distance display ===================================================
M.show_distance  = true
M.distance_suffix  = "m"

-- ===== Target highlight ===================================================
M.target_highlight  = true
M.target_color   = { 255, 255, 255, 255 }
M.target_thickness_mul = 2.0

-- ===== Off-screen arrows ==================================================
M.show_offscreen_arrows = true
M.arrow_size   = 10
M.arrow_color   = { 255, 234, 51, 200 }

-- ===== Distance-based alpha fading ========================================
M.alpha_fade   = false
M.alpha_fade_start_pct = 0.30
M.alpha_fade_min  = 0.25

-- ===== Dynamic font scaling ===============================================
M.dynamic_font_scale = false
M.font_scale_min  = 0.60
M.font_scale_start_pct = 0.25

-- ===== Min clamps for guaranteed visibility at distance (PR1) ============
-- force_min_visibility (default true) ensures effective_alpha / effective_font
-- never drop below min when alpha_fade/dynamic are off (or when on for artistic).
M.force_min_visibility = true
M.min_alpha   = 0.90
M.min_font_size  = 11

-- ===== Visibility profile + hybrid controls (PR2) =========================
-- Expose min visibility + menu controls. show_3d_brackets=true default
-- preserves pre-existing 3D bracket behavior for close range.
-- use_screen_space_boxes / profile / min_box_screen_dim prepared for PR3.
M.min_box_screen_dim = 24
M.use_screen_space_boxes = false
M.show_3d_brackets = true
M.box_3d_fade_with_distance = false
M.visibility_profile = "exploration"  -- "exploration" | "balanced" | "stealth"

-- ===== Z-level filtering ==================================================
M.z_level_filter  = true
M.z_level_max   = 25

-- ===== Level filtering ====================================================
M.level_filter   = false
M.level_filter_min  = -5
M.level_filter_max  = 5

-- ===== Classification colors ==============================================
M.show_elite_colors = true
M.elite_color   = { 255, 204, 51, 255 }
M.rare_elite_color  = { 178, 76, 216, 255 }
M.boss_color   = { 255, 51, 51, 255 }
M.rare_color   = { 102, 165, 242, 255 }

-- ===== NEW v0.4.0: Loot / Skin / Interrupt / Ghost indicators ============
M.show_loot_indicator  = true
M.show_skin_indicator  = true
M.show_interrupt_indicator = true
M.show_ghost_indicator  = true
M.loot_prefix    = "[L] "
M.skin_prefix    = "[S] "
M.interrupt_prefix   = "[I] "
M.ghost_prefix    = "[GHOST] "
M.feign_prefix    = "[FEIGN] "

-- ===== NEW v0.4.0: 3D Cast Bar ============================================
M.show_cast_bar   = true
M.cast_bar_radius   = 1.2
M.cast_bar_color   = { 255, 150, 50, 255 }
M.cast_bar_bg_color  = { 50, 50, 50, 180 }
M.cast_bar_thickness  = 3
M.cast_bar_segments  = 40

-- ===== NEW v0.4.0: Target Marker (Raid Icon) colors ======================
M.show_marker_colors  = true
M.marker_star_color  = { 255, 255, 0, 255 } -- 1
M.marker_circle_color  = { 255, 128, 0, 255 } -- 2
M.marker_diamond_color  = { 255, 0, 255, 255 } -- 3
M.marker_triangle_color = { 0, 255, 0, 255 } -- 4
M.marker_moon_color  = { 128, 128, 255, 255 } -- 5
M.marker_square_color  = { 0, 128, 255, 255 } -- 6
M.marker_cross_color  = { 255, 0, 0, 255 } -- 7
M.marker_skull_color  = { 255, 255, 255, 255 } -- 8

-- ===== NEW v0.4.0: 2D Radar / Minimap ====================================
M.show_radar    = true
M.radar_size    = 120
M.radar_pos_x    = 20  -- px from left
M.radar_pos_y    = 20  -- px from top
M.radar_bg_color   = { 20, 20, 20, 180 }
M.radar_border_color  = { 120, 120, 120, 200 }
M.radar_player_dot_color = { 255, 255, 255, 255 }
M.radar_enemy_dot_color = { 255, 50, 50, 255 }
M.radar_quest_dot_color = { 50, 255, 50, 255 }
M.radar_friendly_dot_color = { 50, 150, 255, 255 }
M.radar_object_dot_color = { 200, 50, 255, 255 }
M.radar_dot_radius   = 3
M.radar_border_thickness = 1
M.radar_show_names   = false

-- ===== Crowded-area / City-mode features ==================================
M.filter_critters  = true
M.filter_pets   = true
M.filter_totems  = true

M.city_mode_auto  = true
M.city_mode_threshold = 20
M.city_mode_distance = 40
M.city_mode_health  = false
M.city_mode_connector = false
M.city_mode_npc  = false

M.dynamic_lod   = true
M.lod_threshold  = 30
M.lod_cap    = 16
M.lod_skip_health_dist = 0.50
M.lod_skip_connector = true

M.nameplate_stack  = true
M.nameplate_stack_step = 14

-- ===== Diagnostics ========================================================
M.debug_log   = true
M.debug_log_interval = 5.0

-- ===== Reader cap ========================================================
M.scan_cap    = 200

-- ===== Visibility overhaul (PR1 + PR2 wiring) ============================
-- Defaults make ESP elements visible at distance (no artificial fade/shrink).
-- force_min_visibility guarantees min legibility even if artistic fade is enabled.
M.force_min_visibility = true
M.min_alpha            = 0.90
M.min_font_size        = 11
M.min_box_screen_dim   = 24
M.use_screen_space_boxes = false
M.show_3d_brackets     = true
M.visibility_profile   = "exploration"

return M
