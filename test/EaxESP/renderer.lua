-- ============================================================================
-- EaxESP - Renderer (v0.4.3)
-- ----------------------------------------------------------------------------
-- What: Draws 3D corner-bracket boxes, 2D nameplates, connectors, health
--   bars, off-screen arrows, distance text, target highlight,
--   cast bars (circle_3d_percentage), loot/skin/interrupt/ghost
--   indicators, target marker colors, and the 2D radar.
-- When: Called once per registered render callback tick.
-- Safety: Every graphics call is pcall-wrapped; we never raise mid-frame.
-- ============================================================================

local M = {}

local function safe_require(name)
 local ok, mod = pcall(require, name)
 if ok and type(mod) == "table" then return mod end
 return nil
end

local _color = safe_require("common/color") or {}
local _vec2 = safe_require("common/geometry/vector_2")
local _vec3 = safe_require("common/geometry/vector_3")

local radar = safe_require("radar") or {}

-- Attachment-safe positioning (experimental). Falls back to get_position()+offset.
local _attach_safe = nil
local function attach_safe()
 if _attach_safe ~= nil then return _attach_safe end
 local ok, mod = pcall(require, "attachment_safe")
 if ok and type(mod) == "table" then
  _attach_safe = mod
 else
  _attach_safe = false
 end
 return _attach_safe
end

local _w2s, _screen, _line, _line3d, _text, _rect2d, _rect2df, _triangle2d
local _circle3d_pct, _circle3d
local _trace_line

local function bind_graphics()
 local g = rawget(_G, "core") and rawget(_G, "core").graphics
 if type(g) ~= "table" then return false end
 _w2s   = type(g.w2s)     == "function" and g.w2s     or nil
 _screen  = type(g.get_screen_size)  == "function" and g.get_screen_size  or nil
 _line   = type(g.line_2d)    == "function" and g.line_2d    or nil
 _line3d  = type(g.line_3d)    == "function" and g.line_3d    or nil
 _text   = type(g.text_2d)    == "function" and g.text_2d    or nil
 _rect2d  = type(g.rect_2d)    == "function" and g.rect_2d    or nil
 _rect2df  = type(g.rect_2d_filled)  == "function" and g.rect_2d_filled  or nil
 _triangle2d = type(g.triangle_2d_filled) == "function" and g.triangle_2d_filled or nil
 _circle3d_pct = type(g.circle_3d_percentage) == "function" and g.circle_3d_percentage or nil
 _circle3d   = type(g.circle_3d)     == "function" and g.circle_3d     or nil
 _trace_line  = type(g.trace_line)     == "function" and g.trace_line     or nil
 return _w2s ~= nil and _screen ~= nil
end

local _counters = {
 text = 0, bracket = 0, line = 0, health = 0, arrow = 0, cast = 0,
 text_err = 0, bracket_err = 0, line_err = 0, health_err = 0, arrow_err = 0,
 cast_err = 0,
}
function M.counters() return _counters end
function M.reset_counters()
 _counters = {
  text = 0, bracket = 0, line = 0, health = 0, arrow = 0, cast = 0,
  text_err = 0, bracket_err = 0, line_err = 0, health_err = 0, arrow_err = 0,
  cast_err = 0,
 }
end

-- ---------------------------------------------------------------------------
-- Color helpers
-- ---------------------------------------------------------------------------
local function norm_color(v)
 if type(v) ~= "number" then return 255 end
 if v <= 1.0 then return math.floor(v * 255 + 0.5) end
 return math.floor(v)
end

local function make_color(r, g, b, a)
 local R, G, B, A = norm_color(r), norm_color(g), norm_color(b), norm_color(a)
 if _color and type(_color.new) == "function" then
  local ok, c = pcall(_color.new, R, G, B, A)
  if ok and c then return c end
 end
 if _color and type(_color.rgba) == "function" then
  local ok, c = pcall(_color.rgba, R, G, B, A)
  if ok and c then return c end
 end
 return { r = R, g = G, b = B, a = A }
end

local function color_with_alpha(base, alpha_mul)
 alpha_mul = alpha_mul or 1.0
 local r = (base and base[1]) or 255
 local g = (base and base[2]) or 255
 local b = (base and base[3]) or 255
 local a = ((base and base[4]) or 255) * alpha_mul
 return make_color(r, g, b, a)
end

local function debug_log(msg)
 local c = rawget(_G, "core")
 if c and type(c.log) == "function" then pcall(c.log, msg) end
end

local function to_vec3(t)
 if not _vec3 or type(_vec3.new) ~= "function" then return t end
 if type(t) ~= "table" then return t end
 return _vec3.new(t.x or 0, t.y or 0, t.z or 0)
end

local function to_vec2(t)
 if not _vec2 or type(_vec2.new) ~= "function" then return t end
 if type(t) ~= "table" then return t end
 return _vec2.new(t.x or 0, t.y or 0)
end

local _w2s_fail_count = 0
local _last_w2s_err = nil
local _w2s_vec3_ok = false
local _last_w2s_spam_warn = 0
local function safe_w2s(position)
 if not _w2s or not position then return nil end

 -- Try direct pass first (works for engine vec3 userdata and sometimes tables)
 local ok, vec = pcall(_w2s, position)
 if ok and vec ~= nil then
  _w2s_fail_count = 0
  _last_w2s_err = nil
  return vec
 end

 -- Fallback: convert table via _vec3.new() — the library vec3 type
 -- matches what w2s expects on some builds.
 if type(position) == "table" and _vec3 and type(_vec3.new) == "function" then
  local v3 = _vec3.new(position.x or 0, position.y or 0, position.z or 0)
  local ok2, vec2 = pcall(_w2s, v3)
  if ok2 and vec2 ~= nil then
   _w2s_vec3_ok = true
   _w2s_fail_count = 0
   _last_w2s_err = nil
   return vec2
  end
 end

 _w2s_fail_count = _w2s_fail_count + 1
 if not ok then
  _last_w2s_err = tostring(vec)
  if _w2s_fail_count <= 5 then
   debug_log("[EaxESP:w2s] ERROR #".._w2s_fail_count.." type="..type(position).." err="..tostring(vec))
  end
 end
 return nil
end

-- ---------------------------------------------------------------------------
-- Target marker color override
-- ---------------------------------------------------------------------------
local MARKER_COLORS = {}

local function init_marker_colors(cfg)
 if not cfg or not cfg.show_marker_colors then return end
 MARKER_COLORS[1] = cfg.marker_star_color
 MARKER_COLORS[2] = cfg.marker_circle_color
 MARKER_COLORS[3] = cfg.marker_diamond_color
 MARKER_COLORS[4] = cfg.marker_triangle_color
 MARKER_COLORS[5] = cfg.marker_moon_color
 MARKER_COLORS[6] = cfg.marker_square_color
 MARKER_COLORS[7] = cfg.marker_cross_color
 MARKER_COLORS[8] = cfg.marker_skull_color
end

local function marker_color(idx, cfg)
 if not cfg or not cfg.show_marker_colors then return nil end
 local col = MARKER_COLORS[idx]
 if not col then return nil end
 return make_color(col[1] or 255, col[2] or 255, col[3] or 255, col[4] or 255)
end

-- ---------------------------------------------------------------------------
-- Classification color override
-- ---------------------------------------------------------------------------
local function classification_color(cls, cfg)
 if not cfg or not cfg.show_elite_colors then return nil end
 if cls == 1 then return cfg.elite_color end
 if cls == 2 then return cfg.rare_elite_color end
 if cls == 3 then return cfg.boss_color end
 if cls == 4 then return cfg.rare_color end
 return nil
end

local function colours_for_kind(kind, cfg, classification, marker_idx)
 local k = kind or "quest_npc"
 local box_t, name_t
 if k == "quest_npc" then box_t, name_t = cfg.box_color,   cfg.name_color
 elseif k == "friendly" then box_t, name_t = cfg.box_color_friendly, cfg.name_color_friendly
 elseif k == "object" then box_t, name_t = cfg.box_color_object, cfg.name_color_object
 else box_t, name_t = cfg.box_color_other,       cfg.name_color_other end

 -- Marker override takes highest priority.
 local mcol = marker_color(marker_idx, cfg)
 if mcol then box_t = nil; name_t = nil; box_t = { mcol.r, mcol.g, mcol.b, mcol.a }; name_t = box_t end

 -- Classification override (if no marker).
 local cls_col = classification_color(classification, cfg)
 if cls_col and not mcol then box_t = cls_col; name_t = cls_col end

 local b1, b2, b3, b4 = (box_t and box_t[1]) or 0.2, (box_t and box_t[2]) or 1, (box_t and box_t[3]) or 0.2, (box_t and box_t[4]) or 0.8
 local n1, n2, n3, n4 = (name_t and name_t[1]) or 1, (name_t and name_t[2]) or 1, (name_t and name_t[3]) or 1, (name_t and name_t[4]) or 1

 local box_c = make_color(b1, b2, b3, b4)
 local name_c = make_color(n1, n2, n3, n4)
 return box_c, name_c
end

-- ---------------------------------------------------------------------------
-- Alpha & font scaling by distance
-- ---------------------------------------------------------------------------
local function alpha_multiplier(dist, max_dist, cfg)
 if not cfg or not cfg.alpha_fade then return 1.0 end
 local start_pct = (cfg.alpha_fade_start_pct and cfg.alpha_fade_start_pct > 0) and cfg.alpha_fade_start_pct or 0.30
 local min_a = (cfg.alpha_fade_min and cfg.alpha_fade_min > 0) and cfg.alpha_fade_min or 0.25
 local start_dist = max_dist * start_pct
 if dist <= start_dist then return 1.0 end
 local t = (dist - start_dist) / (max_dist - start_dist)
 if t > 1 then t = 1 end
 return 1.0 - t * (1.0 - min_a)
end

local function font_size_for_distance(dist, max_dist, base_size, cfg)
 if not cfg or not cfg.dynamic_font_scale then return base_size end
 local start_pct = (cfg.font_scale_start_pct and cfg.font_scale_start_pct > 0) and cfg.font_scale_start_pct or 0.25
 local min_scale = (cfg.font_scale_min and cfg.font_scale_min > 0) and cfg.font_scale_min or 0.60
 local start_dist = max_dist * start_pct
 if dist <= start_dist then return base_size end
 local t = (dist - start_dist) / (max_dist - start_dist)
 if t > 1 then t = 1 end
 local scale = 1.0 - t * (1.0 - min_scale)
 return math.max(6, math.floor(base_size * scale))
end

-- Effective wrappers (PR1): clamp to min when force_min_visibility (default true).
-- This guarantees far objects (at max_distance) stay legible (alpha>=0.9, font>=11).
-- Original *multiplier funcs kept for explicit override tests.
local function effective_alpha(dist, max_dist, cfg)
 local a = alpha_multiplier(dist, max_dist, cfg)
 if not cfg or cfg.force_min_visibility == false then return a end
 local min_a = (cfg.min_alpha and cfg.min_alpha > 0) and cfg.min_alpha or 0.90
 -- NaN/Inf guard (hardening pattern)
 if type(a) ~= "number" or a ~= a or a < 0 or a > 1 then a = 1.0 end
 if a < min_a then a = min_a end
 return a
end

local function effective_font_size(dist, max_dist, base_size, cfg)
 local sz = font_size_for_distance(dist, max_dist, base_size, cfg)
 if not cfg or cfg.force_min_visibility == false then return sz end
 local min_f = (cfg.min_font_size and cfg.min_font_size > 0) and cfg.min_font_size or 11
 if type(sz) ~= "number" or sz ~= sz or sz < 1 then sz = base_size or 13 end
 if sz < min_f then sz = min_f end
 return sz
end

-- ---------------------------------------------------------------------------
-- 3D Bracket drawing
-- ---------------------------------------------------------------------------
local _segs = { {x=0,y=0,z=0}, {x=0,y=0,z=0} }

function draw_bracket_3d(cx, cy, cz, h, r, facing, colour, thickness)
 if not _line3d then return end
 local thick = thickness or 2
 local arm = r * 0.35
 local cos_a = math.cos(facing)
 local sin_a = math.sin(facing)

 local function seg(ax, ay, az, bx, by, bz)
  _segs[1].x = ax; _segs[1].y = ay; _segs[1].z = az
  _segs[2].x = bx; _segs[2].y = by; _segs[2].z = bz
  pcall(_line3d, to_vec3(_segs[1]), to_vec3(_segs[2]), colour, thick)
 end

 local _ca, _sa = cos_a, sin_a
 local function r2(px, py)
  return cx + (px - cx) * _ca - (py - cy) * _sa, cy + (px - cx) * _sa + (py - cy) * _ca
 end

 for dx = -1, 1, 2 do
  for dy = -1, 1, 2 do
   local crx, cry = cx + dx * r, cy + dy * r
   local rx, ry = r2(crx, cry)
   local adx, ady = dx > 0 and -1 or 1, dy > 0 and -1 or 1
   local arx, ary = r2(crx + adx * arm, cry)
   local arx2, ary2 = r2(crx, cry + ady * arm)

   seg(rx, ry, cz, arx, ary, cz)
   seg(rx, ry, cz, arx2, ary2, cz)
   seg(rx, ry, cz, rx, ry, cz+arm)
   seg(rx, ry, cz+h, arx, ary, cz+h)
   seg(rx, ry, cz+h, arx2, ary2, cz+h)
   seg(rx, ry, cz+h, rx, ry, cz+h-arm)
  end
 end
 _counters.bracket = _counters.bracket + 1
end

function draw_bracket_q(cx, cy, cz, h, r, facing, colour, thickness)
 draw_bracket_3d(cx, cy, cz, h, r, facing, colour, thickness)
 if not _line3d then return end
 local thick = thickness or 2
 local cos_a = math.cos(facing)
 local sin_a = math.sin(facing)

 local function r2(px, py)
  return cx + (px - cx) * cos_a - (py - cy) * sin_a,
    cy + (px - cx) * sin_a + (py - cy) * cos_a
 end

 local function seg(ax, ay, az, bx, by, bz)
  _segs[1].x = ax; _segs[1].y = ay; _segs[1].z = az
  _segs[2].x = bx; _segs[2].y = by; _segs[2].z = bz
  pcall(_line3d, to_vec3(_segs[1]), to_vec3(_segs[2]), colour, thick)
 end

 local brx, bry = r2(cx + r, cy + r)
 local ex = r * 1.2
 local tqx, tqy = r2(cx + ex, cy + ex)
 local mz = cz + h * 0.5
 seg(brx, bry, cz, tqx, tqy, mz)
 seg(tqx, tqy, mz, brx, bry, cz+h)

 local fqx, fqy = r2(cx - r, cy - r)
 seg(fqx, fqy, cz+h, fqx, fqy, cz+h + r*0.8)
end

-- ---------------------------------------------------------------------------
-- Health bar
-- ---------------------------------------------------------------------------
local function draw_health_bar(x, y, w, h, hp_pct, cfg, alpha_mul, threat_pct)
 if not _rect2df or not _rect2d then return end
 hp_pct = (type(hp_pct) == "number") and hp_pct or 100
 if hp_pct < 0 then hp_pct = 0 end
 if hp_pct > 100 then hp_pct = 100 end

 local bg = cfg.health_bar_bg or { 30, 30, 30, 180 }
 local fg
 if hp_pct >= 60 then fg = cfg.health_color_high or { 76, 216, 102, 220 }
 elseif hp_pct >= 30 then fg = cfg.health_color_mid or { 255, 204, 51, 220 }
 else fg = cfg.health_color_low or { 255, 51, 51, 220 } end

 local bg_c = color_with_alpha(bg, alpha_mul)
 local fg_c = color_with_alpha(fg, alpha_mul)
 local outline_c
 if threat_pct and cfg.show_threat then
  local tc
  if threat_pct >= 80 then tc = cfg.threat_color_high or { 255, 80, 80, 255 }
  elseif threat_pct >= 50 then tc = cfg.threat_color_mid or { 255, 204, 51, 255 }
  else tc = cfg.threat_color_low or { 76, 216, 102, 255 } end
  outline_c = color_with_alpha(tc, alpha_mul)
 else
  outline_c = color_with_alpha({ 0, 0, 0, 200 }, alpha_mul)
 end

 _counters.health = _counters.health + 1
 local ok1 = pcall(_rect2df, to_vec2({ x = x, y = y }), w, h, bg_c)
 if not ok1 then _counters.health_err = _counters.health_err + 1 end

 local fill_w = math.floor(w * (hp_pct / 100))
 if fill_w > 0 then
  local ok2 = pcall(_rect2df, to_vec2({ x = x, y = y }), fill_w, h, fg_c)
  if not ok2 then _counters.health_err = _counters.health_err + 1 end
 end

 local ok3 = pcall(_rect2d, to_vec2({ x = x, y = y }), w, h, outline_c, 1, 0)
 if not ok3 then _counters.health_err = _counters.health_err + 1 end
end

-- ---------------------------------------------------------------------------
-- 3D Cast Bar (circle_3d_percentage)
-- ---------------------------------------------------------------------------
local function draw_cast_bar(pos, cast_pct, cfg, alpha_mul)
 if not _circle3d_pct then return end
 if not cast_pct then return end
 local pct = math.min(100, math.max(0, cast_pct))
 -- Skip until cast has meaningful progress (avoids grey full-circle flash).
 if pct <= 0 then return end

 local col = cfg.cast_bar_color or { 255, 150, 50, 255 }
 local color = color_with_alpha(col, alpha_mul)

 local radius = cfg.cast_bar_radius or 1.2
 local thickness = cfg.cast_bar_thickness or 3

 local z_off = cfg.cast_bar_z_offset or 2.5
 _counters.cast = _counters.cast + 1
 local ok = pcall(_circle3d_pct,
  to_vec3({ x = pos.x, y = pos.y, z = pos.z + z_off }),
  radius, color, pct, thickness)
 if not ok then _counters.cast_err = _counters.cast_err + 1 end

 -- Background ring (full circle, very dim — only drawn when actively casting).
 local bg_col = cfg.cast_bar_bg_color or { 50, 50, 50, 80 }
 local bg_color = color_with_alpha(bg_col, alpha_mul * 0.3)
 pcall(_circle3d_pct,
  to_vec3({ x = pos.x, y = pos.y, z = pos.z + z_off }),
  radius, bg_color, 100, thickness)
end

-- ---------------------------------------------------------------------------
-- Aggro Radius circle (v0.4.3)
-- ---------------------------------------------------------------------------
local function aggro_radius_for(mob_level, my_level)
 if not mob_level or mob_level <= 0 then return 25 end -- skull/unknown = max radius
 local diff = mob_level - (my_level or mob_level)
 local r = 20 + diff * 1.5
 if r < 5 then r = 5 end
 if r > 30 then r = 30 end
 return r
end

local function draw_aggro_circle(pos, mob_level, my_level, dist, cfg, alpha_mul)
 if not _circle3d then return end
 local radius = aggro_radius_for(mob_level, my_level)
 local col
 if dist <= radius * 0.5 then
  col = cfg.aggro_radius_color_danger or { 255, 60, 60, 160 }
 elseif dist <= radius then
  col = cfg.aggro_radius_color_warn or { 255, 200, 50, 120 }
 else
  col = cfg.aggro_radius_color_safe or { 100, 255, 100, 80 }
 end
 local color = color_with_alpha(col, alpha_mul)
 local thickness = (dist <= radius) and 2 or 1
 pcall(_circle3d, to_vec3(pos), radius, color, thickness)
end

-- ---------------------------------------------------------------------------
-- Off-screen arrow
-- ---------------------------------------------------------------------------
local function draw_offscreen_arrow(screen_x, screen_y, target_x, target_y, color, size)
 if not _triangle2d then return end
 size = size or 10
 local dx = target_x - screen_x * 0.5
 local dy = target_y - screen_y * 0.5
 local angle = math.atan(dy, dx)

 local edge_x = screen_x * 0.5 + math.cos(angle) * (screen_x * 0.45)
 local edge_y = screen_y * 0.5 + math.sin(angle) * (screen_y * 0.45)

 local p1 = { x = edge_x + math.cos(angle) * size, y = edge_y + math.sin(angle) * size }
 local p2 = { x = edge_x + math.cos(angle + 2.4) * size, y = edge_y + math.sin(angle + 2.4) * size }
 local p3 = { x = edge_x + math.cos(angle - 2.4) * size, y = edge_y + math.sin(angle - 2.4) * size }

 _counters.arrow = _counters.arrow + 1
 local ok = pcall(_triangle2d, to_vec2(p1), to_vec2(p2), to_vec2(p3), color)
 if not ok then _counters.arrow_err = _counters.arrow_err + 1 end
end

-- ---------------------------------------------------------------------------
-- Nameplate deconfliction
-- ---------------------------------------------------------------------------
local _nameplate_boxes = {}

local function reset_nameplate_boxes()
 _nameplate_boxes = {}
end

local function text_width_estimate(text, font_size)
 local len = type(text) == "string" and #text or 4
 return math.floor(len * font_size * 0.55)
end

local function find_stack_offset(text_x, text_y, text_w, text_h, step)
 step = step or 14
 local x1, y1 = text_x - text_w * 0.5, text_y
 local x2, y2 = text_x + text_w * 0.5, text_y + text_h

 local offset = 0
 local max_iter = 8
 for _ = 1, max_iter do
  local overlaps = false
  for _, box in ipairs(_nameplate_boxes) do
   if not (x2 < box[1] or x1 > box[3] or y2 < box[2] or y1 > box[4]) then
    overlaps = true
    break
   end
  end
  if not overlaps then break end
  offset = offset + step
  y1 = y1 - step
  y2 = y2 - step
 end

 table.insert(_nameplate_boxes, { x1, y1, x2, y2 })
 return -offset
end

-- ---------------------------------------------------------------------------
-- Build display name with all indicators.
-- ---------------------------------------------------------------------------
local function build_display_name(cand, cfg, dist)
 local parts = {}

 -- Prefixes (in priority order).
 if cfg.show_ghost_indicator then
  if cand.is_ghost then table.insert(parts, cfg.ghost_prefix or "[GHOST] ") end
  if cand.is_feign then table.insert(parts, cfg.feign_prefix or "[FEIGN] ") end
 end
 if cfg.show_interrupt_indicator and cand.is_casting and cand.interruptable then
  table.insert(parts, cfg.interrupt_prefix or "[I] ")
 end
 if cfg.show_loot_indicator and (cand.can_loot or cand.has_loot) then
  table.insert(parts, cfg.loot_prefix or "[L] ")
 end
 if cfg.show_skin_indicator and cand.can_skin then
  table.insert(parts, cfg.skin_prefix or "[S] ")
 end

 -- Base name.
 table.insert(parts, cand.name or "?")

 -- Quest tag.
 if cand.kind == "quest_npc" then
  parts[#parts] = "[Q] " .. parts[#parts]
 end

 -- Distance.
 if cfg.show_distance and dist then
  parts[#parts] = parts[#parts] .. " " .. math.floor(dist) .. (cfg.distance_suffix or "m")
 end

 return table.concat(parts, "")
end

-- ---------------------------------------------------------------------------
-- Main render pass
-- ---------------------------------------------------------------------------
local _scratch_head = { x = 0, y = 0, z = 0 }

function M.render_frame(cfg, candidates, projection, origin_pos, _max_dist_sq)
 if not bind_graphics() then return 0, 0 end
 if type(cfg) ~= "table" or cfg.enabled ~= true then return 0, 0 end
 if type(candidates) ~= "table" or #candidates == 0 then return 0, 0 end

 M.reset_counters()
 reset_nameplate_boxes()
 init_marker_colors(cfg)

 -- Cache local player for threat lookups
 local _me = nil
 local c = rawget(_G, "core")
 if c and c.object_manager and type(c.object_manager.get_local_player) == "function" then
  local ok, p = pcall(c.object_manager.get_local_player)
  if ok and p then _me = p end
 end
 local _my_level = nil
 if _me then
  local ok_lv, lv = pcall(function() return _me:get_level() end)
  if ok_lv and type(lv) == "number" then _my_level = lv end
 end

 local max_d = cfg.max_distance or 80
 local max_dist_sq = _max_dist_sq or (max_d * max_d)

 local candidate_count = #candidates
 local cap = cfg.max_esp_per_frame or 32
 local crowded = false
 if cfg.dynamic_lod then
  local threshold = (cfg.lod_threshold and cfg.lod_threshold > 0) and cfg.lod_threshold or 30
  if candidate_count > threshold then
   crowded = true
   cap = (cfg.lod_cap and cfg.lod_cap > 0) and cfg.lod_cap or 16
  end
 end

 local city_mode = (candidate_count > 0 and candidates[1] ~= nil and candidates[1].city_mode == true)

 local drawn, skipped = 0, 0
 local sx, sy = 1920, 1080
 if _screen then
  local ok, size = pcall(_screen)
  if ok and type(size) == "table" then
   sx = tonumber(size.x) or sx
   sy = tonumber(size.y) or sy
  end
 end
 if projection and projection.begin_frame then
  projection.begin_frame(sx, sy, cfg.screen_padding or 4,
        cfg.box_min_dim or 8, cfg.box_max_dim or 600)
 end

 local now = 0
 local c = rawget(_G, "core")
 if c and type(c.time) == "function" then
  local ok, t = pcall(c.time)
  if ok and type(t) == "number" then now = t end
 end

 -- Player rotation for radar.
 local player_rot = 0
 if candidates[1] and candidates[1].obj then
  local ok, rot = pcall(function() return candidates[1].obj:get_rotation() end)
  if ok and type(rot) == "number" then player_rot = rot end
 end

 for i = 1, #candidates do
  if drawn >= cap then break end
  local cand = candidates[i]

  -- Refresh facing from object if still alive, but NEVER re-fetch position
  -- from cand.obj — stale object references return nil from get_position().
  -- The scan-time vec3 userdata (raw_position) is the only reliable source.
  if cand and cand.obj then
   local ok2, rot = pcall(function() return cand.obj:get_rotation() end)
   if ok2 and type(rot) == "number" then cand.facing = rot end
  end

  local skip_reason = nil
  if type(cand) ~= "table" or type(cand.position) ~= "table" or type(cand.position.x) ~= "number" then
   skip_reason = "bad_pos"
   skipped = skipped + 1
   if cfg.debug_log then
    local name = cand.name or "?"
    debug_log("[EaxESP:renderer] SKIP '" .. tostring(name) .. "' reason=bad_pos")
   end
  elseif projection and projection.squared_dist(cand.position, origin_pos) > max_dist_sq then
   skip_reason = "distance"
   skipped = skipped + 1
   if cfg.debug_log then
    local name = cand.name or "?"
    local dist = math.sqrt(projection.squared_dist(cand.position, origin_pos))
    debug_log("[EaxESP:renderer] SKIP '" .. tostring(name) .. "' reason=distance dist=" .. math.floor(dist) .. " max=" .. math.floor(max_d))
   end
  else
   local pos = cand.position
   -- ALWAYS use cached raw_position. Re-fetching from stale object
   -- references returns a plain Lua table that w2s silently rejects.
   -- The cached vec3 userdata is the only proven-working source.
   local w2s_input = cand.raw_position or pos
   local feet_sp = safe_w2s(w2s_input)
   local dist = cand.distance or math.sqrt(projection.squared_dist(pos, origin_pos))
   local alpha_mul = effective_alpha(dist, max_d, cfg)
   if cfg.debug_log and i <= 3 and cand.kind == "object" then
    local vec_type = type(feet_sp)
    local input_type = type(w2s_input)
    local has_raw = (cand.raw_position ~= nil) and "yes" or "no"
    local vx = feet_sp and feet_sp.x or "nil"
    local vy = feet_sp and feet_sp.y or "nil"
    debug_log(string.format(
     "[EaxESP:renderer] cand[%d] kind=%s pos=(%.1f,%.1f,%.1f) dist=%.1f input_type=%s has_raw=%s w2s=%s x=%s y=%s",
     i, tostring(cand.kind or "?"),
     pos.x or 0, pos.y or 0, pos.z or 0,
     dist or 0,
     input_type, has_raw, vec_type, tostring(vx), tostring(vy)))
   end

   -- Off-screen arrow.
   if feet_sp then
    local fx, fy = feet_sp.x, feet_sp.y
    local on_screen = (fx >= 0 and fx <= sx and fy >= 0 and fy <= sy)
    if not on_screen and cfg.show_offscreen_arrows then
     local arrow_c = color_with_alpha(cfg.arrow_color or { 255, 234, 51, 200 }, alpha_mul)
     if arrow_c then
      draw_offscreen_arrow(sx, sy, feet_sp.x, feet_sp.y, arrow_c, cfg.arrow_size or 10)
     end
    end
   end

   if not feet_sp then
    skip_reason = "w2s"
    skipped = skipped + 1
    if cfg.debug_log and cand.kind == "object" then
     local name = cand.name or "?"
     local has_raw = (cand.raw_position ~= nil) and "yes" or "no"
     debug_log("[EaxESP:renderer] SKIP '" .. tostring(name) .. "' reason=w2s has_raw=" .. has_raw .. " w2s_err=" .. tostring(_last_w2s_err or "none"))
    end
   else
    local is_target = cand.is_target == true

    -- Occlusion cull: skip units behind walls if trace_line is available.
    local _occluded = false
    if cfg.show_occlusion and _trace_line and origin_pos then
     local ok_los, visible = pcall(_trace_line, origin_pos, w2s_input)
     if ok_los and visible == false then
      _occluded = true
      skipped = skipped + 1
     end
    end

    if not _occluded then
    local box_colour, name_colour = colours_for_kind(cand.kind, cfg, cand.classification, cand.marker_index)

    if alpha_mul < 1.0 then
     box_colour = color_with_alpha(
      { box_colour.r or 76, box_colour.g or 216, box_colour.b or 102, box_colour.a or 255 },
      alpha_mul)
     name_colour = color_with_alpha(
      { name_colour.r or 255, name_colour.g or 234, name_colour.b or 51, name_colour.a or 255 },
      alpha_mul)
    end

    local box_thick = cfg.box_thickness or 2
    if is_target and cfg.target_highlight then
     box_colour = color_with_alpha(cfg.target_color or { 255, 255, 255, 255 }, alpha_mul)
     box_thick = math.floor(box_thick * (cfg.target_thickness_mul or 2.0))
    end

    if cfg.show_box and box_colour and _line3d then
     local draw_fn = (cand.kind == "quest_npc") and draw_bracket_q or draw_bracket_3d
     draw_fn(pos.x, pos.y, pos.z, 2.0, 0.5, cand.facing or 0,
       box_colour, box_thick)
    end

    -- Aggro radius circle for hostile mobs (including hostile quest NPCs).
    local is_aggro_target = (cand.kind == "hostile") or
       (cand.kind == "quest_npc" and cand.can_attack == true)
    if cfg.show_aggro_radius and _circle3d and is_aggro_target then
     draw_aggro_circle(pos, cand.level, _my_level, dist, cfg, alpha_mul)
    end

    -- 3D Cast bar.
    if cfg.show_cast_bar and cand.is_casting and _circle3d_pct then
     draw_cast_bar(pos, cand.cast_pct, cfg, alpha_mul)
    end

    if cfg.show_nameplate and _text and name_colour then
     -- Attachment-based head position (experimental, gated).
     local head_pos = nil
     if cfg.use_attachments and cand.obj then
      local as = attach_safe()
      if as then
       head_pos = as.head_position(cand.obj, cfg.nameplate_z_offset or 2.0)
      end
     end
     if head_pos then
      _scratch_head.x = head_pos.x
      _scratch_head.y = head_pos.y
      _scratch_head.z = head_pos.z
     else
      _scratch_head.x = pos.x
      _scratch_head.y = pos.y
      _scratch_head.z = pos.z + (cfg.nameplate_z_offset or 2.0)
     end
     local head_sp = safe_w2s(_scratch_head)
     local text_x = feet_sp.x
     local base_y = (head_sp and head_sp.y or feet_sp.y - 36) - (cfg.name_offset_y or 6)

     local display_name = build_display_name(cand, cfg, dist)

     local base_font = cfg.name_font_size or 13
     local font_sz = effective_font_size(dist, max_d, base_font, cfg)

     -- Nameplate deconfliction.
     local text_w = text_width_estimate(display_name, font_sz)
     local text_h = font_sz + 2
     local stack_offset = 0
     if cfg.nameplate_stack then
      stack_offset = find_stack_offset(text_x, base_y, text_w, text_h,
               cfg.nameplate_stack_step or 14)
     end
     local text_y = base_y + stack_offset

     local text_pos = to_vec2({ x = text_x, y = text_y })
     _counters.text = _counters.text + 1
     local ok = pcall(_text, display_name, text_pos, font_sz, name_colour, true, nil)
     if not ok then _counters.text_err = _counters.text_err + 1 end

     -- Health bar.
     local skip_health = false
     if city_mode and cfg.city_mode_health == false then skip_health = true end
     if crowded and cfg.lod_skip_health_dist then
      local pct = (cfg.lod_skip_health_dist > 0 and cfg.lod_skip_health_dist < 1) and cfg.lod_skip_health_dist or 0.5
      if dist > max_d * pct then skip_health = true end
     end

     if cfg.show_health and cand.health_pct and _rect2df and not skip_health then
      local bar_w = cfg.health_bar_width or 60
      local bar_h = cfg.health_bar_height or 4
      local bar_x = text_x - bar_w * 0.5
      local bar_y = text_y + font_sz + 2

      -- Threat lookup: get_threat_situation returns {is_tanking, status, threat_percent}
      local threat_pct = nil
      if cfg.show_threat and _me and cand.obj then
       local ok_t, threat = pcall(function() return cand.obj:get_threat_situation(_me) end)
       if ok_t and threat and type(threat) == "table" then
        threat_pct = threat.threat_percent or 0
       end
      end

      draw_health_bar(bar_x, bar_y, bar_w, bar_h, cand.health_pct, cfg, alpha_mul, threat_pct)
     end

     -- Connector.
     local skip_connector = false
     if city_mode and cfg.city_mode_connector == false then skip_connector = true end
     if crowded and cfg.lod_skip_connector then skip_connector = true end

     if cfg.show_connector and _line and not skip_connector then
      _counters.line = _counters.line + 1
      local feet_2d = to_vec2({ x = feet_sp.x, y = feet_sp.y })
      local ok2 = pcall(_line, feet_2d, text_pos,
           box_colour or name_colour,
           cfg.connector_thickness or 1)
      if not ok2 then _counters.line_err = _counters.line_err + 1 end
     end
    end

    drawn = drawn + 1
    end -- not _occluded
   end
  end
 end

 -- Render 2D radar.
 local radar_drawn = 0
 if radar and radar.render_radar then
  radar_drawn = radar.render_radar(cfg, candidates, origin_pos, player_rot)
 end

 if cfg.debug_log then
  local city_str = city_mode and "[CITY]" or ""
  local lod_str = crowded and "[LOD]" or ""
  local vec3_status = "nil"
  if _vec3 then
   vec3_status = type(_vec3.new) == "function" and "ok" or "no_new"
  end
  debug_log("[EaxESP:renderer] DONE " .. city_str .. lod_str
   .. " drawn=" .. tostring(drawn)
   .. " radar=" .. tostring(radar_drawn)
   .. " skipped=" .. tostring(skipped)
   .. " bracket=" .. tostring(_counters.bracket) .. "/" .. tostring(_counters.bracket_err)
   .. " text=" .. tostring(_counters.text) .. "/" .. tostring(_counters.text_err)
   .. " line=" .. tostring(_counters.line) .. "/" .. tostring(_counters.line_err)
   .. " health=" .. tostring(_counters.health) .. "/" .. tostring(_counters.health_err)
   .. " arrow=" .. tostring(_counters.arrow) .. "/" .. tostring(_counters.arrow_err)
   .. " cast=" .. tostring(_counters.cast) .. "/" .. tostring(_counters.cast_err)
   .. " w2s_fail=" .. tostring(_w2s_fail_count)
   .. " vec3=" .. vec3_status
   .. " w2s_err=" .. tostring(_last_w2s_err or "none"))
 end
 if drawn == 0 and candidate_count > 0 and _w2s_fail_count > 0 and _w2s_fail_count >= candidate_count then
  local now = (core and core.time and core.time()) or 0
  if now - _last_w2s_spam_warn > 10.0 then
   _last_w2s_spam_warn = now
   debug_log("[EaxESP] ALL candidates skipped due to w2s failure — check vec3 conversion")
  end
 end
 return drawn, skipped
end

return M
