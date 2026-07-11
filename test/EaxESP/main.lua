-- ============================================================================
-- EaxESP - Bootstrap / Entry Point
-- ----------------------------------------------------------------------------
-- What: Loads sibling modules (config, reader, projection, renderer,
--   menu) and registers 3 callbacks with Project Sylvanas:
--   1. on_pre_tick — refresh candidate list (throttled)
--   2. on_render — draw ESP overlay (every frame)
--   3. on_render_menu — render the "EaxESP" tree in the main menu
-- When: Loaded by Project Sylvanas once header.lua gated plugin["load"].
-- Why: PS loader contract: header.lua must return plugin["load"]=true
--   and main.lua must register the menu callback so the user can
--   see the settings when they open the menu.
-- Safety: Lazy-init; every callback pcall-wraps; if core is missing at
--   script-load time we return without registering.
-- ============================================================================

local NS = {}
_G.EaxESP = NS

_G.EaxESP.modules = { _loaded = false }
local M = _G.EaxESP.modules

-- ============================================================================
-- Bootstrap
-- ============================================================================

local function safe_log(level, msg)
 local c = rawget(_G, "core")
 if type(c) ~= "table" then return end
 local fn = c[level]
 if type(fn) ~= "function" then return end
 pcall(fn, msg)
end

local function safe_require(name)
 local ok, mod = pcall(require, name)
 if ok and type(mod) == "table" then return mod end
 return nil
end

-- ============================================================================
-- High-resolution clock + frame-rate helpers (v0.4.3)
-- ----------------------------------------------------------------------------
-- What: Caches core.cpu_time (ns), core.game_time (ms), core.time (s) and
--   core.delta_time (per-frame delta) at module load (Pattern 2). Provides a
--   monotonic high-resolution seconds clock and a frame-delta helper so the
--   candidate-scan refresh cadence is frame-rate-independent and smooth on
--   every PC (30 / 60 / 144 / 240 FPS alike) and "matches the FPS".
-- Why: core.time() is low-precision (float seconds since injection) and tied
--   to the game-tick clock. core.cpu_time() gives nanosecond resolution and
--   core.delta_time() gives the true per-frame elapsed time, letting us scale
--   the ESP data refresh to the display's frame rate.
-- Safety: Every probe is pcall-wrapped; falls back gracefully through a
--   cpu_time -> game_time -> time chain. delta_time unit is auto-detected
--   (seconds vs milliseconds) by magnitude so it works across client builds.
-- ============================================================================

local _core_ref       = rawget(_G, "core")
local _cpu_time_fn    = _core_ref and type(_core_ref.cpu_time)    == "function" and _core_ref.cpu_time    or nil
local _game_time_fn   = _core_ref and type(_core_ref.game_time)   == "function" and _core_ref.game_time   or nil
local _core_time_fn   = _core_ref and type(_core_ref.time)        == "function" and _core_ref.time        or nil
local _delta_time_fn  = _core_ref and type(_core_ref.delta_time)  == "function" and _core_ref.delta_time  or nil

-- High-resolution monotonic clock in seconds.
-- Preference: cpu_time (ns -> s) -> game_time (ms -> s) -> time (s).
local function now_seconds()
 if _cpu_time_fn then
  local ok, ns = pcall(_cpu_time_fn)
  if ok and type(ns) == "number" then return ns * 1e-9 end
 end
 if _game_time_fn then
  local ok, ms = pcall(_game_time_fn)
  if ok and type(ms) == "number" then return ms * 0.001 end
 end
 if _core_time_fn then
  local ok, s = pcall(_core_time_fn)
  if ok and type(s) == "number" then return s end
 end
 return 0
end

-- Frame delta in seconds. core.delta_time() is documented as seconds since
-- the last frame, but some builds report milliseconds — auto-detect by
-- magnitude (a single-frame delta is always < 1.0s; anything >= 1.0 is
-- treated as ms and converted).
local function delta_seconds()
 if _delta_time_fn then
  local ok, dt = pcall(_delta_time_fn)
  if ok and type(dt) == "number" and dt > 0 then
   return dt >= 1.0 and (dt * 0.001) or dt
  end
 end
 return 0
end

-- FPS tracker (exponential moving average) for adaptive refresh + diagnostics.
local _fps_ema = 60.0

local function update_fps()
 local dt = delta_seconds()
 if dt > 0 and dt < 1.0 then
  local instant_fps = 1.0 / dt
  _fps_ema = _fps_ema * 0.9 + instant_fps * 0.1
 end
 return _fps_ema
end

-- Compute the effective refresh interval (seconds), optionally scaled by the
-- measured FPS so the data refresh "matches the FPS" — smoother on fast
-- displays (refresh more often), lighter on slow ones (refresh less often).
-- 60 FPS is the reference; the scale is clamped to [0.5x, 2.0x].
local function effective_refresh_interval(base)
 base = base or 1.0
 if not (M.config and M.config.fps_adaptive_refresh) then return base end
 -- "Match FPS" mode: scan every frame so the ESP data refresh matches the
 -- display's frame rate. Interval = 0 means reader.should_refresh() always
 -- returns true (now - last >= 0), so a full scan runs every on_pre_tick.
 return 0
end

local function bootstrap()
 if M._loaded then return end

 local hdr = safe_require("header")
 if not hdr or hdr["load"] ~= true then
  safe_log("log_warning",
     "[EaxESP] header load-gate failed (load ~= true). Aborting.")
  return false
 end

 M.config  = safe_require("config")
 M.reader  = safe_require("reader")
 M.projection = safe_require("projection")
 M.renderer = safe_require("renderer")
 M.menu  = safe_require("menu")
 M.compat  = safe_require("compat")

 if not (M.config and M.reader and M.projection and M.renderer and M.menu) then
  safe_log("log_warning",
     "[EaxESP] required module missing: config="
     .. tostring(M.config) .. " reader=" .. tostring(M.reader)
     .. " projection=" .. tostring(M.projection)
     .. " renderer=" .. tostring(M.renderer)
     .. " menu=" .. tostring(M.menu))
  return false
 end

 M._loaded = true
 safe_log("log", "[EaxESP] v" .. tostring(hdr["version"] or "?")
      .. " loaded — render_mode=" .. tostring(M.config.render_mode)
      .. ", max_distance=" .. tostring(M.config.max_distance)
      .. "yd, default-on (keybind 7).")

 -- Compatibility probe: logs which APIs are available (Vanilla vs TBC).
 if M.compat then
  pcall(M.compat.log_summary)
 end

 -- Attachment APIs are DISABLED — they crash the client with native AV.
 -- Even pcall + correct documented signatures cannot catch the crash.
 -- See plans/bug-report-sylvanas-attachment-api-crash.md
 -- Fallback (get_position + offset) is used unconditionally.
 -- if M.config and M.config.use_attachments then
 --  local ok_as, as = pcall(require, "attachment_safe")
 --  if ok_as and as then as.probe() end
 -- end

 local g = rawget(_G, "core") and rawget(_G, "core").graphics or {}
 safe_log("log", "[EaxESP] API probe: w2s=" .. tostring(type(g.w2s))
  .. " rect_2d=" .. tostring(type(g.rect_2d))
  .. " text_2d=" .. tostring(type(g.text_2d))
  .. " line_2d=" .. tostring(type(g.line_2d))
  .. " get_screen_size=" .. tostring(type(g.get_screen_size)))

 M.header = hdr
 return true
end

-- ============================================================================
-- Per-frame config sync
-- ============================================================================

local function sync_bool(cfg, key, menu_key, fallback)
 if M.menu and M.menu.get then
  local v = M.menu.get(menu_key, fallback)
  if v ~= nil then cfg[key] = v end
 end
end

local function sync_num(cfg, key, menu_key, fallback)
 if M.menu and M.menu.get then
  local v = tonumber(M.menu.get(menu_key, fallback))
  if v ~= nil then cfg[key] = v end
 end
end

local function sync_config_from_menu()
 if not (M.config and M.menu) then return end
 local cfg = M.config
 local m = M.menu

 cfg.show_box  = m.get("show_box",  cfg.show_box)
 cfg.show_nameplate = m.get("show_nameplate", cfg.show_nameplate)
 cfg.show_connector = m.get("show_connector", cfg.show_connector)

 cfg.show_questie_npcs  = m.get("show_quest_npc", cfg.show_questie_npcs)
 cfg.show_other_npcs  = m.get("show_other_npc", cfg.show_other_npcs)
 cfg.show_game_objects  = m.get("show_game_obj", cfg.show_game_objects)
 cfg.show_friendly_players = m.get("show_friendly", cfg.show_friendly_players)
 cfg.render_mode   = m.get("render_mode",  cfg.render_mode)

 cfg.max_distance  = tonumber(m.get("max_distance", cfg.max_distance))  or cfg.max_distance
 sync_bool(cfg, "fps_adaptive_refresh", "fps_match",    cfg.fps_adaptive_refresh)
 cfg.name_font_size = math.floor(tonumber(m.get("name_font_size", cfg.name_font_size)) or cfg.name_font_size)
 cfg.box_thickness = math.floor(tonumber(m.get("box_thickness", cfg.box_thickness)) or cfg.box_thickness)
 sync_num(cfg, "nameplate_z_offset", "nameplate_z_offset", cfg.nameplate_z_offset)
 sync_num(cfg, "cast_bar_z_offset",  "cast_bar_z_offset",  cfg.cast_bar_z_offset)
 sync_bool(cfg, "show_occlusion",   "show_occlusion",   cfg.show_occlusion)
 sync_bool(cfg, "show_threat",    "show_threat",    cfg.show_threat)
 sync_bool(cfg, "show_aggro_radius", "show_aggro_radius", cfg.show_aggro_radius)
 sync_bool(cfg, "use_attachments", "use_attachments", cfg.use_attachments)
 cfg.debug_log  = m.get("debug_log", cfg.debug_log) and true or false

 -- v0.3.0
 sync_bool(cfg, "show_health",   "show_health",   cfg.show_health)
 sync_bool(cfg, "show_distance",  "show_distance",  cfg.show_distance)
 sync_bool(cfg, "target_highlight",  "target_highlight", cfg.target_highlight)
 sync_bool(cfg, "show_offscreen_arrows","show_offscreen",  cfg.show_offscreen_arrows)
 -- alpha_fade/dynamic sync unchanged (PR1: defaults flipped in config+menu; effective clamps in renderer)
 sync_bool(cfg, "alpha_fade",   "alpha_fade",   cfg.alpha_fade)
 sync_bool(cfg, "dynamic_font_scale", "dynamic_font",  cfg.dynamic_font_scale)
 -- PR2 syncs (menu nil-safe via m.get; smallest additive)
 sync_bool(cfg, "force_min_visibility", "force_min_vis", cfg.force_min_visibility)
 sync_bool(cfg, "use_screen_space_boxes", "use_2d_boxes", cfg.use_screen_space_boxes)
 sync_bool(cfg, "show_3d_brackets", "show_3d_brackets", cfg.show_3d_brackets)
 sync_num(cfg, "min_font_size", "min_font", cfg.min_font_size)
 sync_num(cfg, "min_box_screen_dim", "min_box_px", cfg.min_box_screen_dim)
 local prof = m.get("vis_profile", cfg.visibility_profile)
 if prof ~= nil then cfg.visibility_profile = prof end
 sync_bool(cfg, "z_level_filter",  "z_level_filter",  cfg.z_level_filter)
 sync_num (cfg, "z_level_max",   "z_level_max",   cfg.z_level_max)
 sync_bool(cfg, "level_filter",   "level_filter",  cfg.level_filter)
 sync_num (cfg, "level_filter_min",  "level_filter_min", cfg.level_filter_min)
 sync_num (cfg, "level_filter_max",  "level_filter_max", cfg.level_filter_max)
 sync_bool(cfg, "show_elite_colors", "show_elite_colors", cfg.show_elite_colors)

 -- v0.3.1
 sync_bool(cfg, "filter_critters",  "filter_critters",  cfg.filter_critters)
 sync_bool(cfg, "filter_pets",   "filter_pets",   cfg.filter_pets)
 sync_bool(cfg, "filter_totems",  "filter_totems",  cfg.filter_totems)
 sync_bool(cfg, "city_mode_auto",  "city_mode_auto",  cfg.city_mode_auto)
 sync_num (cfg, "city_mode_threshold", "city_mode_threshold", cfg.city_mode_threshold)
 sync_num (cfg, "city_mode_distance", "city_mode_distance", cfg.city_mode_distance)
 sync_bool(cfg, "city_mode_health",  "city_mode_health", cfg.city_mode_health)
 sync_bool(cfg, "city_mode_connector", "city_mode_connector", cfg.city_mode_connector)
 sync_bool(cfg, "city_mode_npc",  "city_mode_npc",  cfg.city_mode_npc)
 sync_bool(cfg, "dynamic_lod",   "dynamic_lod",   cfg.dynamic_lod)
 sync_num (cfg, "lod_threshold",  "lod_threshold",  cfg.lod_threshold)
 sync_num (cfg, "lod_cap",    "lod_cap",    cfg.lod_cap)
 sync_bool(cfg, "nameplate_stack",  "nameplate_stack",  cfg.nameplate_stack)

 -- v0.4.0
 sync_bool(cfg, "show_loot_indicator",  "show_loot",   cfg.show_loot_indicator)
 sync_bool(cfg, "show_skin_indicator",  "show_skin",   cfg.show_skin_indicator)
 sync_bool(cfg, "show_interrupt_indicator", "show_interrupt",  cfg.show_interrupt_indicator)
 sync_bool(cfg, "show_ghost_indicator",  "show_ghost",   cfg.show_ghost_indicator)
 sync_bool(cfg, "show_cast_bar",   "show_cast_bar",  cfg.show_cast_bar)
 sync_bool(cfg, "show_marker_colors",  "show_marker_colors", cfg.show_marker_colors)
 sync_bool(cfg, "show_radar",    "show_radar",   cfg.show_radar)
 sync_num (cfg, "radar_size",    "radar_size",   cfg.radar_size)
 sync_num (cfg, "radar_pos_x",    "radar_pos_x",   cfg.radar_pos_x)
 sync_num (cfg, "radar_pos_y",    "radar_pos_y",   cfg.radar_pos_y)
 sync_bool(cfg, "radar_show_names",   "radar_show_names", cfg.radar_show_names)

 local enabled_raw = m.get("enable", cfg.enabled)
 cfg.enabled = (enabled_raw == nil) and cfg.enabled or enabled_raw

 if not cfg.debug_log then M._last_debug_log = 0 end
end

-- ============================================================================
-- Local player + world-position caches
-- ============================================================================

local function has_local_player()
 local c = rawget(_G, "core")
 if type(c) ~= "table" or type(c.object_manager) ~= "table"
  or type(c.object_manager.get_local_player) ~= "function" then
  return false, nil
 end
 local ok, me = pcall(c.object_manager.get_local_player)
 if not ok then return false, nil end
 return true, me
end

local _origin = { x = 0, y = 0, z = 0 }
local function try_refresh_origin()
 local have, me = has_local_player()
 if not have or not me then return end
 local ok, pos = pcall(function() return me:get_position() end)
 if ok and pos then
  _origin.x = pos.x or 0
  _origin.y = pos.y or 0
  _origin.z = pos.z or 0
 end
end

-- ============================================================================
-- Callbacks
-- ============================================================================
-- ============================================================================

local _last_diag_log = 0
local _last_auto_diag = 0
local _tick_count = 0

local function dbg_log(msg)
 if M.config and M.config.debug_log then
  safe_log("log", msg)
 end
end

local function on_pre_tick()
 _tick_count = _tick_count + 1
 local have_player = has_local_player()
 if not have_player then return end

 if not M._loaded then
  local ok = bootstrap()
  if not ok then
   return
  end
 end

 sync_config_from_menu()
 try_refresh_origin()

 if not M.config then
  safe_log("log_warning", "[EaxESP:on_pre_tick] M.config is nil")
  return
 end

 if not M.config.enabled then
  return
 end

 -- High-resolution clock (core.cpu_time ns -> game_time ms -> time s).
 local now = now_seconds()

 -- FPS-adaptive refresh interval: scales the scan cadence to the measured
 -- frame rate so the overlay data stays fresh and smooth on every PC.
 local base_interval = M.config.refresh_interval or 1.0
 local eff_interval  = effective_refresh_interval(base_interval)

 if M.reader and M.reader.update then
  local ok, err = pcall(M.reader.update, now, eff_interval, M.config)
  if not ok then
   safe_log("log_warning", "[EaxESP:on_pre_tick] reader.update FAILED: " .. tostring(err))
  end
 else
  safe_log("log_warning", "[EaxESP:on_pre_tick] M.reader.update not available")
 end

 if M.config.debug_log then
  if (now - _last_diag_log) >= (M.config.debug_log_interval or 5) then
   _last_diag_log = now
   local stats = (M.reader.stats and M.reader.stats()) or {}
   local questie = M.reader.is_active and (M.reader.is_active() and "(Questie loaded)" or "(Questie absent)") or "(Questie ?)"
   local city = stats.city_mode and "[CITY]" or ""
   local cnt = (M.renderer and M.renderer.counters) and M.renderer.counters() or {}
   safe_log("log",
      string.format(
       "[EaxESP] %s qtt=%s | candidates=%d (render_mode=%s) | drawn_bracket=%d drawn_text=%d drawn_line=%d health=%d arrow=%d err_bracket=%d err_text=%d err_line=%d err_health=%d err_arrow=%d | fps=%.0f scan_int=%.2fs tick:%s",
       city,
       questie,
       tostring(stats.last_scan_count),
       tostring(M.config.render_mode),
       tostring(cnt.bracket or 0),
       tostring(cnt.text or 0),
       tostring(cnt.line or 0),
       tostring(cnt.health or 0),
       tostring(cnt.arrow or 0),
       tostring(cnt.bracket_err or 0),
       tostring(cnt.text_err or 0),
       tostring(cnt.line_err or 0),
       tostring(cnt.health_err or 0),
       tostring(cnt.arrow_err or 0),
       _fps_ema,
       eff_interval,
       tostring(now)))

   -- Auto-run diagnostic dump every 30s when debug is on.
   -- This lets us diagnose missing quest objects without the user
   -- needing to run any manual commands.
   if (now - (_last_auto_diag or 0)) >= 30 then
    _last_auto_diag = now
    local diag = safe_require("EaxAutoQuester/diagnostic_dump_sylvanas")
    if diag and diag.dump then
     pcall(diag.dump)
    end
   end
  end
 end
end

local function on_render()
 if not M._loaded and not bootstrap() then return end
 -- Track frame rate from core.delta_time() so the adaptive refresh interval
 -- (computed in on_pre_tick) follows the display's actual FPS.
 update_fps()
 local have_player = has_local_player()
 if not have_player then return end
 sync_config_from_menu()
 try_refresh_origin()
 if not M.config.enabled then return end

 local max_d = M.config.max_distance or 80
 local max_dist_sq = max_d * max_d

 local drawn, skipped = 0, 0
 if M.renderer.render_frame then
  drawn, skipped = M.renderer.render_frame(
   M.config, M.reader.candidates or {}, M.projection, _origin, max_dist_sq)
 end

 if M.config.debug_log and M.reader.candidates and #M.reader.candidates > 0 and drawn == 0 then
  safe_log("log_warning",
     string.format(
      "[EaxESP] candidates=%d but DRAWN=0 (skipped=%d). check distance + box_min_dim + screen cull.",
      #M.reader.candidates, skipped or 0))
 end
end

local function on_render_menu()
 if not M._loaded and not bootstrap() then return end
 local have_player = has_local_player()
 if not have_player then return end
 if M.menu.render then pcall(M.menu.render, M.menu) end
end

-- ============================================================================
-- Register callbacks.
-- ============================================================================

local c = rawget(_G, "core")
if type(c) == "table" then
 if type(c.register_on_pre_tick_callback) == "function" then
  pcall(c.register_on_pre_tick_callback, on_pre_tick)
 end
 if type(c.register_on_render_callback) == "function" then
  pcall(c.register_on_render_callback, on_render)
 end
 if type(c.register_on_render_menu_callback) == "function" then
  pcall(c.register_on_render_menu_callback, on_render_menu)
 end
 pcall(bootstrap)
else
 NS.on_pre_tick = on_pre_tick
 NS.on_render  = on_render
 NS.on_render_menu = on_render_menu
 NS.bootstrap  = bootstrap
 NS.modules  = M
end

-- ============================================================================
-- Public surface
-- ============================================================================

function NS.get_state()
 local stats = M._loaded and M.reader and M.reader.stats and M.reader.stats() or {}
 return {
  enabled  = M._loaded and M.config and M.config.enabled or false,
  initialized = M._loaded == true,
  candidate_cnt = M._loaded and M.reader and M.reader.candidates
        and #M.reader.candidates or 0,
  render_mode = M._loaded and M.config and M.config.render_mode or "?",
  questie  = M._loaded and M.reader and M.reader.is_active
        and M.reader.is_active() or false,
  city_mode  = stats.city_mode or false,
  friendly_count = stats.friendly_count or 0,
 }
end

return NS
