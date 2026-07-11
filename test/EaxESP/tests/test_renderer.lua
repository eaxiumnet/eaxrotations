-- ============================================================================
-- EaxESP/tests/test_renderer.lua (v0.4.0)
-- ----------------------------------------------------------------------------
-- What: Drives renderer.lua against a fake core.graphics. Verifies:
--   - All legacy features (boxes, nameplates, health, connectors)
--   - Distance text, target highlight, off-screen arrows
--   - Alpha fading, dynamic font, elite colors
--   - Nameplate deconfliction, dynamic LOD, occlusion culling
--   - Loot/skin/interrupt/ghost indicators, marker colors, cast bars
--   - 2D radar
-- Safety: Test-fixture only; resets _G.core with a recording backend.
-- ============================================================================

local script_path = (debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./")
if script_path:sub(-1) ~= "/" and script_path:sub(-1) ~= "\\" then
 script_path = script_path .. "/"
end
package.path = script_path .. "../?.lua;" .. script_path .. "../?/init.lua;"
     .. package.path

local _calls = { rect = {}, rect_filled = {}, text = {}, line = {}, line3d = {}, triangle = {},
     circle3dpct = {}, circle2df = {}, circle2d = {}, line2d = {}, w2s = 0 }

local function fake_w2s(pos)
 _calls.w2s = _calls.w2s + 1
 return {
  x = 960 + (pos.x or 0) * 50,
  y = 540 + (pos.z or 0) * 50,
 }
end

local function fake_rect(tl, w, h, color, thickness, rounding)
 _calls.rect[#_calls.rect + 1] = { x = tl.x, y = tl.y, w = w, h = h, c = color, t = thickness, r = rounding }
end
local function fake_rect_filled(tl, w, h, color, rounding)
 _calls.rect_filled[#_calls.rect_filled + 1] = { x = tl.x, y = tl.y, w = w, h = h, c = color, r = rounding }
end
local function fake_text(text, pos, font_size, color, centered, font_id)
 _calls.text[#_calls.text + 1] = { text = text, x = pos.x, y = pos.y, sz = font_size, c = color, ctr = centered }
end
local function fake_line(a, b, color, thickness)
 _calls.line[#_calls.line + 1] = { ax = a.x, ay = a.y, bx = b.x, by = b.y, c = color, t = thickness }
end
local function fake_line3d(a, b, color, thickness)
 _calls.line3d[#_calls.line3d + 1] = { ax = a.x, ay = a.y, az = a.z, bx = b.x, by = b.y, bz = b.z, c = color, t = thickness }
end
local function fake_triangle(p1, p2, p3, color)
 _calls.triangle[#_calls.triangle + 1] = { ax = p1.x, ay = p1.y, bx = p2.x, by = p2.y, cx = p3.x, cy = p3.y, c = color }
end
local function fake_circle3d_pct(center, radius, color, percentage, thickness)
 _calls.circle3dpct[#_calls.circle3dpct + 1] = { cx = center.x, cy = center.y, cz = center.z,
  r = radius, c = color, pct = percentage, t = thickness }
end
local function fake_circle2d_filled(center, radius, color)
 _calls.circle2df[#_calls.circle2df + 1] = { x = center.x, y = center.y, r = radius, c = color }
end
local function fake_circle2d(center, radius, color, thickness)
 _calls.circle2d[#_calls.circle2d + 1] = { x = center.x, y = center.y, r = radius, c = color, t = thickness }
end

-- trace_line returns true = visible, false = blocked
local function fake_trace_line(a, b, flags)
 if b.z and b.z >= 100 then return false end
 return true
end

_G.core = {
 graphics = {
  w2s    = fake_w2s,
  get_screen_size = function() return { x = 1920, y = 1080 } end,
  rect_2d   = fake_rect,
  rect_2d_filled = fake_rect_filled,
  text_2d   = fake_text,
  line_2d   = fake_line,
  line_3d   = fake_line3d,
  triangle_2d_filled = fake_triangle,
  circle_3d_percentage = fake_circle3d_pct,
  circle_2d_filled = fake_circle2d_filled,
  circle_2d  = fake_circle2d,
  trace_line  = fake_trace_line,
  get_text_width = function() return 80 end,
 },
 time = function() return 0 end,
}

local renderer = require("renderer")
local projection = require("projection")

local results = { pass = 0, fail = 0, fails = {} }
local function check(name, cond, detail)
 if cond then
  results.pass = results.pass + 1
 else
  results.fail = results.fail + 1
  results.fails[#results.fails + 1] = tostring(name)
       .. (detail and (" — " .. detail) or "")
 end
end

local function reset_calls()
 _calls.rect, _calls.rect_filled = {}, {}
 _calls.text, _calls.line, _calls.line3d, _calls.triangle = {}, {}, {}, {}
 _calls.circle3dpct, _calls.circle2df, _calls.circle2d = {}, {}, {}
 _calls.w2s = 0
end

local function default_cfg()
 return {
  enabled   = true,
  max_distance  = 80,
  max_esp_per_frame = 32,
  show_box   = true,
  show_nameplate = true,
  show_connector = true,
  show_health  = true,
  show_distance = true,
  target_highlight = true,
  show_offscreen_arrows = true,
  alpha_fade  = false,
  dynamic_font_scale = false,
  force_min_visibility = true,
  min_alpha = 0.90,
  min_font_size = 11,
  show_elite_colors = true,
  box_color  = { 0.30, 0.85, 0.40, 1.00 },
  box_color_other = { 216, 140, 51, 255 },
  box_color_friendly = { 102, 165, 242, 255 },
  box_color_object = { 178, 76, 216, 255 },
  box_thickness = 2,
  box_min_dim  = 8,
  box_max_dim  = 600,
  name_color  = { 1.00, 0.92, 0.20, 1.00 },
  name_color_other = { 255, 209, 102, 255 },
  name_color_friendly = { 216, 234, 255, 255 },
  name_color_object = { 216, 140, 255, 255 },
  name_font_size = 13,
  name_offset_y = 6,
  connector_color = { 0.30, 0.85, 0.40, 0.55 },
  connector_thickness = 1,
  screen_padding = 4,
  health_bar_width = 60,
  health_bar_height = 4,
  health_color_high = { 76, 216, 102, 220 },
  health_color_mid = { 255, 204, 51, 220 },
  health_color_low = { 255, 51, 51, 220 },
  health_bar_bg = { 30, 30, 30, 180 },
  target_color  = { 255, 255, 255, 255 },
  target_thickness_mul = 2.0,
  arrow_size  = 10,
  arrow_color  = { 255, 234, 51, 200 },
  alpha_fade_start_pct = 0.30,
  alpha_fade_min = 0.25,
  font_scale_min = 0.60,
  font_scale_start_pct = 0.25,
  distance_suffix = "m",
  elite_color  = { 255, 204, 51, 255 },
  rare_elite_color = { 178, 76, 216, 255 },
  boss_color  = { 255, 51, 51, 255 },
  rare_color  = { 102, 165, 242, 255 },
  -- v0.3.1
  occlusion_culling = true,
  occlusion_budget = 12,
  occlusion_ttl = 0.25,
  nameplate_stack = true,
  nameplate_stack_step = 14,
  dynamic_lod = true,
  lod_threshold = 30,
  lod_cap = 16,
  lod_skip_health_dist = 0.50,
  lod_skip_connector = true,
  city_mode_health = false,
  city_mode_connector = false,
  city_mode_npc = false,
  -- v0.4.0
  show_loot_indicator = true,
  show_skin_indicator = true,
  show_interrupt_indicator = true,
  show_ghost_indicator = true,
  loot_prefix = "[L] ",
  skin_prefix = "[S] ",
  interrupt_prefix = "[I] ",
  ghost_prefix = "[GHOST] ",
  feign_prefix = "[FEIGN] ",
  show_cast_bar = true,
  cast_bar_radius = 1.2,
  cast_bar_color = { 255, 150, 50, 255 },
  cast_bar_bg_color = { 50, 50, 50, 180 },
  cast_bar_thickness = 3,
  cast_bar_segments = 40,
  show_marker_colors = true,
  marker_star_color = { 255, 255, 0, 255 },
  marker_circle_color = { 255, 128, 0, 255 },
  marker_diamond_color = { 255, 0, 255, 255 },
  marker_triangle_color = { 0, 255, 0, 255 },
  marker_moon_color = { 128, 128, 255, 255 },
  marker_square_color = { 0, 128, 255, 255 },
  marker_cross_color = { 255, 0, 0, 255 },
  marker_skull_color = { 255, 255, 255, 255 },
  show_radar = true,
  radar_size = 120,
  radar_pos_x = 20,
  radar_pos_y = 20,
  radar_bg_color = { 20, 20, 20, 180 },
  radar_border_color = { 120, 120, 120, 200 },
  radar_player_dot_color = { 255, 255, 255, 255 },
  radar_enemy_dot_color = { 255, 50, 50, 255 },
  radar_quest_dot_color = { 50, 255, 50, 255 },
  radar_friendly_dot_color = { 50, 150, 255, 255 },
  radar_object_dot_color = { 200, 50, 255, 255 },
  radar_dot_radius = 3,
  radar_border_thickness = 1,
  radar_show_names = false,
 }
end

local function make_candidate(npc_id, name, x, y, z, opts)
 opts = opts or {}
 return {
  obj   = {},
  npc_id  = npc_id,
  position  = { x = x, y = y, z = z },
  name   = name,
  distance  = opts.distance or math.sqrt(x*x + y*y + z*z),
  health_pct = opts.health_pct,
  level   = opts.level,
  classification = opts.classification,
  is_target  = opts.is_target,
  kind   = opts.kind or "hostile",
  city_mode  = opts.city_mode,
  -- v0.4.0
  can_loot  = opts.can_loot,
  has_loot  = opts.has_loot,
  can_skin  = opts.can_skin,
  is_casting = opts.is_casting,
  cast_pct  = opts.cast_pct,
  interruptable = opts.interruptable,
  is_ghost  = opts.is_ghost,
  is_feign  = opts.is_feign,
  marker_index = opts.marker_index,
 }
end

local origin = { x = 0, y = 0, z = 0 }

-- ============================================================================
-- Tests 1-8: legacy
-- ============================================================================

-- 1. disabled cfg → 0 draws.
do
 reset_calls()
 local cfg = default_cfg(); cfg.enabled = false
 local d = renderer.render_frame(cfg, {}, projection, origin, 80*80)
 check("disabled cfg → 0 draws", d == 0 and #_calls.text == 0 and #_calls.line == 0)
end

-- 2. empty candidates → 0 draws.
do
 reset_calls()
 local d = renderer.render_frame(default_cfg(), {}, projection, origin, 80*80)
 check("empty candidates → 0 draws", d == 0)
end

-- 3. in-range candidate → box + nameplate + connector + health bar.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Bob", 5, 5, 0, { health_pct = 75 }) }
 local d = renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("in-range draws 24 line_3d segments",
   #_calls.line3d == 24, "line3d=" .. #_calls.line3d)
 check("in-range draws 1 text", #_calls.text == 1, "text=" .. #_calls.text)
 check("text content includes distance",
   #_calls.text >= 1 and _calls.text[1].text:find("m") ~= nil)
 check("health bar drawn (2 filled rects + 1 outline)",
   #_calls.rect_filled >= 2 and #_calls.rect >= 1)
 check("in-range draws connector line", #_calls.line >= 1)
end

-- 4. out-of-range → not drawn.
do
 reset_calls()
 local cfg = default_cfg(); cfg.max_distance = 50; cfg.show_radar = false
 local candidates = { make_candidate(1, "Far", 200, 200, 0) }
 local d = renderer.render_frame(cfg, candidates, projection, origin, 50*50)
 check("out-of-range → 0 draws",
   d == 0 and #_calls.text == 0 and #_calls.line == 0)
end

-- 5. all visuals disabled → 0 draw calls.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_radar = false
 cfg.show_box, cfg.show_nameplate, cfg.show_connector = false, false, false
 cfg.show_health, cfg.show_distance = false, false
 local candidates = { make_candidate(1, "NameTog", 5, 5, 0) }
 local d = renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("all visuals disabled → 0 draw calls",
   d == 1 and #_calls.text == 0 and #_calls.line == 0 and #_calls.rect_filled == 0)
end

-- 6. max_esp_per_frame caps drawn count.
do
 reset_calls()
 local cfg = default_cfg(); cfg.max_esp_per_frame = 2
 local candidates = {
  make_candidate(1, "A", 5, 5, 0),
  make_candidate(2, "B", 6, 6, 0),
  make_candidate(3, "C", 7, 7, 0),
 }
 local d = renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("per-frame cap respected (d <= 2)", d <= 2, "d=" .. tostring(d))
 check("line_3d draws respect cap", #_calls.line3d <= 48, "line3d=" .. #_calls.line3d)
end

-- 7. missing core.graphics → returns 0, doesn't crash.
do
 local saved = _G.core.graphics
 _G.core.graphics = nil
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Bob", 5, 5, 0) }
 local ok, d = pcall(renderer.render_frame, cfg, candidates, projection, origin, 100*100)
 check("missing graphics survives", ok and d == 0, "ok=" .. tostring(ok) .. " d=" .. tostring(d))
 _G.core.graphics = saved
end

-- 8. nil candidate entry → skipped without crash.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { nil, make_candidate(1, "Bob", 5, 5, 0), "string-not-table" }
 local ok, d = pcall(renderer.render_frame, cfg, candidates, projection, origin, 100*100)
 check("malformed candidates tolerated", ok and d == 1, "ok=" .. tostring(ok) .. " d=" .. tostring(d))
end

-- ============================================================================
-- Tests 9-17: v0.3.0 features
-- ============================================================================

-- 9. Distance text appended to name.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Bob", 3, 4, 0, { distance = 5 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("distance text appended",
   #_calls.text >= 1 and _calls.text[1].text:find("5m") ~= nil)
end

-- 10. Distance text hidden when show_distance=false.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_distance = false
 local candidates = { make_candidate(1, "Bob", 3, 4, 0, { distance = 5 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("distance text hidden when show_distance=false",
   #_calls.text >= 1 and _calls.text[1].text:find("m") == nil)
end

-- 11. Health bar green for high HP.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Bob", 5, 5, 0, { health_pct = 80 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local found_green = false
 for _, rf in ipairs(_calls.rect_filled) do
  if rf.c and rf.c.g and rf.c.g > 200 then found_green = true end
 end
 check("health bar green for high HP (80%)", found_green)
end

-- 12. Health bar red for low HP.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Bob", 5, 5, 0, { health_pct = 15 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local found_red = false
 for _, rf in ipairs(_calls.rect_filled) do
  if rf.c and rf.c.r and rf.c.r > 200 and (rf.c.g or 0) < 100 then found_red = true end
 end
 check("health bar red for low HP (15%)", found_red)
end

-- 13. Target highlight draws thicker white box.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Bob", 5, 5, 0, { is_target = true }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local found_thick = false
 for _, l in ipairs(_calls.line3d) do
  if l.t and l.t >= 3 then found_thick = true end
 end
 check("target highlight uses thicker lines", found_thick)
end

-- 14. Alpha fading still draws distant object.
do
 reset_calls()
 local cfg = default_cfg(); cfg.alpha_fade = true; cfg.alpha_fade_start_pct = 0.3; cfg.force_min_visibility = false
 local candidates = { make_candidate(1, "Far", 80, 0, 0, { distance = 80 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 80*80)
 check("alpha fading still draws distant object", #_calls.text >= 1, "text=" .. #_calls.text)
end

-- 15. Dynamic font scaling reduces font size for distant objects.
do
 reset_calls()
 local cfg = default_cfg(); cfg.dynamic_font_scale = true; cfg.font_scale_min = 0.5; cfg.force_min_visibility = false
 local candidates_near = { make_candidate(1, "Near", 3, 4, 0, { distance = 5 }) }
 renderer.render_frame(cfg, candidates_near, projection, origin, 80*80)
 local near_font = (#_calls.text >= 1) and _calls.text[1].sz or 13

 reset_calls()
 local candidates_far = { make_candidate(1, "Far", 80, 0, 0, { distance = 80 }) }
 renderer.render_frame(cfg, candidates_far, projection, origin, 80*80)
 local far_font = (#_calls.text >= 1) and _calls.text[1].sz or 13

 check("dynamic font: far font <= near font",
   far_font <= near_font, "near=" .. tostring(near_font) .. " far=" .. tostring(far_font))
end

-- PR1: with new defaults (no fade/scale, force_min), far object still full size/alpha.
do
 reset_calls()
 local cfg = default_cfg()  -- alpha_fade=false, dynamic=false, force_min=true, min_* set
 local candidates = { make_candidate(1, "FarFull", 70, 0, 0, { distance = 70 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 80*80)
 local far_font = (#_calls.text >= 1) and _calls.text[1].sz or 0
 check("default: far object full font size (no shrink)", far_font >= 11, "font=" .. tostring(far_font))
 local full_alpha = true
 for _, t in ipairs(_calls.text) do
  local ca = t.c and (t.c.a or (t.c[4]))
  if ca and ca < 250 then full_alpha = false end
 end
 check("default: far object full alpha (no fade)", full_alpha, "alpha not full")
end

-- 16. Elite classification changes box color.
do
 reset_calls()
 local cfg = default_cfg()
 local candidates = { make_candidate(1, "Boss", 5, 5, 0, { classification = 3 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local found_red = false
 for _, l in ipairs(_calls.line3d) do
  if l.c and l.c.r and l.c.r > 200 and (l.c.g or 0) < 100 then found_red = true end
 end
 check("boss classification uses red color", found_red)
end

-- 17. Off-screen arrow drawn when target is off screen but within distance.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_offscreen_arrows = true
 local candidates = { make_candidate(1, "Off", 50, 0, 0, { distance = 50 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 80*80)
 check("off-screen arrow drawn", #_calls.triangle >= 1, "triangles=" .. #_calls.triangle)
end

-- ============================================================================
-- Tests 18-24: v0.3.1 crowded-area features
-- ============================================================================

-- 18. Nameplate deconfliction nudges overlapping text upward.
do
 reset_calls()
 local cfg = default_cfg(); cfg.nameplate_stack = true; cfg.nameplate_stack_step = 14
 local candidates = {
  make_candidate(1, "A", 5, 5, 0),
  make_candidate(2, "B", 5, 5, 0),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local y1 = (#_calls.text >= 1) and _calls.text[1].y or 0
 local y2 = (#_calls.text >= 2) and _calls.text[2].y or 0
 check("nameplate deconfliction nudges second text upward",
   y2 < y1, "y1=" .. tostring(y1) .. " y2=" .. tostring(y2))
end

-- 19. Nameplate deconfliction disabled → no nudge.
do
 reset_calls()
 local cfg = default_cfg(); cfg.nameplate_stack = false
 local candidates = {
  make_candidate(1, "A", 5, 5, 0),
  make_candidate(2, "B", 5, 5, 0),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local y1 = (#_calls.text >= 1) and _calls.text[1].y or 0
 local y2 = (#_calls.text >= 2) and _calls.text[2].y or 0
 check("nameplate stacking disabled → no nudge",
   y1 == y2, "y1=" .. tostring(y1) .. " y2=" .. tostring(y2))
end

-- 20. Dynamic LOD reduces draw cap when crowded.
do
 reset_calls()
 local cfg = default_cfg()
 cfg.dynamic_lod = true; cfg.lod_threshold = 5; cfg.lod_cap = 3; cfg.max_esp_per_frame = 32
 local candidates = {
  make_candidate(1, "A", 5, 5, 0),
  make_candidate(2, "B", 6, 6, 0),
  make_candidate(3, "C", 7, 7, 0),
  make_candidate(4, "D", 8, 8, 0),
  make_candidate(5, "E", 9, 9, 0),
  make_candidate(6, "F", 10, 10, 0),
 }
 local d = renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("dynamic LOD caps draws at lod_cap when candidates > threshold",
   d <= 3, "d=" .. tostring(d))
end

-- 21. Dynamic LOD skips connectors when crowded.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_radar = false
 cfg.dynamic_lod = true; cfg.lod_threshold = 2; cfg.lod_skip_connector = true
 local candidates = {
  make_candidate(1, "A", 5, 5, 0),
  make_candidate(2, "B", 6, 6, 0),
  make_candidate(3, "C", 7, 7, 0),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("dynamic LOD skips connectors when crowded",
   #_calls.line == 0, "line=" .. #_calls.line)
end

-- 22. City mode hides health bars.
do
 reset_calls()
 local cfg = default_cfg()
 cfg.show_health = true
 local candidates = {
  make_candidate(1, "Bob", 5, 5, 0, { health_pct = 75, city_mode = true }),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("city mode suppresses health bars",
   #_calls.rect_filled == 0, "rect_filled=" .. #_calls.rect_filled)
end

-- 23. City mode hides connectors.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_radar = false
 cfg.show_connector = true
 local candidates = {
  make_candidate(1, "Bob", 5, 5, 0, { city_mode = true }),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("city mode suppresses connectors",
   #_calls.line == 0, "line=" .. #_calls.line)
end

-- 24. Occlusion culling hides targets behind walls.
do
 reset_calls()
 local cfg = default_cfg()
 cfg.occlusion_culling = true
 local candidates = {
  make_candidate(1, "Visible", 5, 5, 0),
  make_candidate(2, "BehindWall", 5, 5, 100),
 }
 local d = renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local visible_found = false
 local behind_found = false
 for _, t in ipairs(_calls.text) do
  if t.text:find("Visible") then visible_found = true end
  if t.text:find("BehindWall") then behind_found = true end
 end
 check("occlusion culling hides BehindWall (z=100)",
   visible_found and not behind_found,
   "d=" .. tostring(d) .. " text_count=" .. #_calls.text)
end

-- ============================================================================
-- Tests 25-35: v0.4.0 loot/skin/interrupt/ghost/marker/cast/radar
-- ============================================================================

-- 25. Loot indicator prefix in nameplate.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_loot_indicator = true
 local candidates = { make_candidate(1, "LootMob", 5, 5, 0, { can_loot = true, has_loot = true }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("loot indicator prefix appears",
   #_calls.text >= 1 and _calls.text[1].text:find("%[L%]") ~= nil,
   "text=" .. (#_calls.text >= 1 and _calls.text[1].text or "nil"))
end

-- 26. Skin indicator prefix in nameplate.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_skin_indicator = true
 local candidates = { make_candidate(1, "SkinMob", 5, 5, 0, { can_skin = true }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("skin indicator prefix appears",
   #_calls.text >= 1 and _calls.text[1].text:find("%[S%]") ~= nil)
end

-- 27. Interrupt indicator prefix on interruptable cast.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_interrupt_indicator = true
 local candidates = { make_candidate(1, "Caster", 5, 5, 0,
  { is_casting = true, cast_pct = 50, interruptable = true }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("interrupt indicator prefix appears",
   #_calls.text >= 1 and _calls.text[1].text:find("%[I%]") ~= nil)
end

-- 28. Ghost indicator prefix.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_ghost_indicator = true
 local candidates = { make_candidate(1, "Ghost", 5, 5, 0, { is_ghost = true }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("ghost indicator prefix appears",
   #_calls.text >= 1 and _calls.text[1].text:find("GHOST") ~= nil)
end

-- 29. Feign indicator prefix.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_ghost_indicator = true
 local candidates = { make_candidate(1, "Feign", 5, 5, 0, { is_feign = true }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("feign indicator prefix appears",
   #_calls.text >= 1 and _calls.text[1].text:find("FEIGN") ~= nil)
end

-- 30. Cast bar drawn for casting unit.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_cast_bar = true
 local candidates = { make_candidate(1, "Caster", 5, 5, 0,
  { is_casting = true, cast_pct = 65 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("cast bar drawn (circle_3d_percentage called)",
   #_calls.circle3dpct >= 1, "circle3dpct=" .. #_calls.circle3dpct)
 check("cast bar percentage ≈ 65%",
   #_calls.circle3dpct >= 1 and _calls.circle3dpct[1].pct == 65,
   "pct=" .. tostring(#_calls.circle3dpct >= 1 and _calls.circle3dpct[1].pct or "nil"))
end

-- 31. Cast bar NOT drawn for non-casting unit.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_cast_bar = true
 local candidates = { make_candidate(1, "NotCasting", 5, 5, 0) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 check("no cast bar for non-casting unit",
   #_calls.circle3dpct == 0, "circle3dpct=" .. #_calls.circle3dpct)
end

-- 32. Marker color overrides box color (skull = white).
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_marker_colors = true
 local candidates = { make_candidate(1, "Marked", 5, 5, 0, { marker_index = 8 }) }
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local found_white = false
 for _, l in ipairs(_calls.line3d) do
  if l.c and l.c.r and l.c.r > 240 and l.c.g and l.c.g > 240 and l.c.b and l.c.b > 240 then
   found_white = true
  end
 end
 check("marker color (skull=white) overrides box color", found_white)
end

-- 33. Marker color takes priority over classification color.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_marker_colors = true; cfg.show_elite_colors = true
 local candidates = { make_candidate(1, "BossMarked", 5, 5, 0,
  { classification = 3, marker_index = 1 }) } -- boss + star marker
 renderer.render_frame(cfg, candidates, projection, origin, 100*100)
 local found_yellow = false
 for _, l in ipairs(_calls.line3d) do
  if l.c and l.c.r and l.c.r > 240 and l.c.g and l.c.g > 240 and (l.c.b or 0) < 50 then
   found_yellow = true
  end
 end
 check("marker color (star=yellow) takes priority over boss red", found_yellow)
end

-- 34. Radar draws background and dots.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_radar = true
 local candidates = {
  make_candidate(1, "Enemy", 10, 0, 0, { kind = "hostile" }),
  make_candidate(2, "Quest", 0, 10, 0, { kind = "quest_npc" }),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 80*80)
 check("radar draws background circle",
   #_calls.circle2df >= 1, "circle2df=" .. #_calls.circle2df)
 check("radar draws enemy dot",
   #_calls.circle2df >= 2, "circle2df=" .. #_calls.circle2df)
end

-- 35. Radar disabled → no circle_2d_filled calls.
do
 reset_calls()
 local cfg = default_cfg(); cfg.show_radar = false
 local candidates = {
  make_candidate(1, "Enemy", 10, 0, 0, { kind = "hostile" }),
 }
 renderer.render_frame(cfg, candidates, projection, origin, 80*80)
 check("radar disabled → no circle2df calls",
   #_calls.circle2df == 0, "circle2df=" .. #_calls.circle2df)
end

-- ============================================================================
-- Report
-- ============================================================================

io.write("\n[EaxESP tests/renderer]\n")
io.write(string.format(" pass: %d\n fail: %d\n", results.pass, results.fail))
if results.fail > 0 then
 for _, name in ipairs(results.fails) do
  io.write(" FAIL: " .. name .. "\n")
 end
 os.exit(1)
end
io.write(" ALL GREEN\n")
