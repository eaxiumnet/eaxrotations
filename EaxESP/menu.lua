-- ============================================================================
-- EaxESP - Menu (Plugin Configuration UI) v0.4.2
-- ----------------------------------------------------------------------------
-- What: Configuration UI. Tree + sub-categories + checkboxes + sliders.
-- When: Rendered via core.register_on_render_menu_callback.
-- Safety: All widgets nil-guarded; widgets created once at module load.
-- ============================================================================

local M = {}

local _core_menu = rawget(_G, "core") and rawget(_G, "core").menu or nil

local function safe_widget(fn_name, ...)
 if not (_core_menu and type(_core_menu[fn_name]) == "function") then return nil end
 local ok, widget = pcall(_core_menu[fn_name], ...)
 if ok and widget then return widget end
 return nil
end

local IDs = {
 tree     = "eaxesp_tree",
 enable      = "eaxesp_enable",
 debug_log      = "eaxesp_debug_log",
 render_mode      = "eaxesp_render_mode",
 -- General
 max_distance     = "eaxesp_max_distance",
 fps_match      = "eaxesp_fps_match",
 -- Target types
 show_quest_npc    = "eaxesp_show_quest_npc",
 show_other_npc    = "eaxesp_show_other_npc",
 show_game_obj     = "eaxesp_show_game_obj",
 show_friendly     = "eaxesp_show_friendly",
 -- Visuals
 show_box      = "eaxesp_show_box",
 show_nameplate    = "eaxesp_show_nameplate",
 show_connector    = "eaxesp_show_connector",
 name_font_size    = "eaxesp_name_font_size",
 box_thickness     = "eaxesp_box_thickness",
 nameplate_z_offset   = "eaxesp_nameplate_z_offset",
 cast_bar_z_offset  = "eaxesp_cast_bar_z_offset",
 show_occlusion   = "eaxesp_show_occlusion",
 show_threat    = "eaxesp_show_threat",
 show_aggro_radius = "eaxesp_show_aggro_radius",
 -- Experimental
 use_attachments   = "eaxesp_use_attachments",
 show_health     = "eaxesp_show_health",
 show_distance     = "eaxesp_show_distance",
 target_highlight    = "eaxesp_target_highlight",
 show_offscreen    = "eaxesp_show_offscreen",
 show_elite_colors   = "eaxesp_show_elite_colors",
 alpha_fade      = "eaxesp_alpha_fade",
 dynamic_font     = "eaxesp_dynamic_font",
 nameplate_stack    = "eaxesp_nameplate_stack",
 -- PR2 visibility controls
 vis_profile      = "eaxesp_vis_profile",
 force_min_vis     = "eaxesp_force_min_vis",
 use_2d_boxes     = "eaxesp_use_2d_boxes",
 min_font      = "eaxesp_min_font",
 min_box_px      = "eaxesp_min_box_px",
 show_3d_brackets    = "eaxesp_show_3d_brackets",
 -- Filtering
 z_level_filter    = "eaxesp_z_level_filter",
 z_level_max     = "eaxesp_z_level_max",
 level_filter     = "eaxesp_level_filter",
 level_filter_min    = "eaxesp_level_filter_min",
 level_filter_max    = "eaxesp_level_filter_max",
 filter_critters    = "eaxesp_filter_critters",
 filter_pets     = "eaxesp_filter_pets",
 filter_totems     = "eaxesp_filter_totems",
 -- City mode
 city_mode_auto    = "eaxesp_city_mode_auto",
 city_mode_threshold   = "eaxesp_city_mode_threshold",
 city_mode_distance    = "eaxesp_city_mode_distance",
 city_mode_health    = "eaxesp_city_mode_health",
 city_mode_connector   = "eaxesp_city_mode_connector",
 city_mode_npc     = "eaxesp_city_mode_npc",
 -- Performance
 dynamic_lod     = "eaxesp_dynamic_lod",
 lod_threshold     = "eaxesp_lod_threshold",
 lod_cap      = "eaxesp_lod_cap",
 -- Indicators
 show_loot_indicator   = "eaxesp_show_loot",
 show_skin_indicator   = "eaxesp_show_skin",
 show_interrupt_indicator  = "eaxesp_show_interrupt",
 show_ghost_indicator    = "eaxesp_show_ghost",
 show_cast_bar     = "eaxesp_show_cast_bar",
 show_marker_colors    = "eaxesp_show_marker_colors",
 -- Radar
 show_radar      = "eaxesp_show_radar",
 radar_size      = "eaxesp_radar_size",
 radar_pos_x     = "eaxesp_radar_pos_x",
 radar_pos_y     = "eaxesp_radar_pos_y",
 radar_show_names    = "eaxesp_radar_show_names",
}

local RENDER_MODES = { "Questie only", "Questie + Nearby", "All visible" }

if _core_menu then
 -- Main tree (flat - no nested tree nodes, use headers for categories)
 M.tree    = safe_widget("tree_node")

 M.enable    = safe_widget("checkbox", true, IDs.enable)
 M.debug_log   = safe_widget("checkbox", true, IDs.debug_log)
 M.render_mode   = safe_widget("combobox", 3,  IDs.render_mode)

 M.show_box   = safe_widget("checkbox", true, IDs.show_box)
 M.show_nameplate  = safe_widget("checkbox", true, IDs.show_nameplate)
 M.show_connector  = safe_widget("checkbox", true, IDs.show_connector)

 M.show_quest_npc  = safe_widget("checkbox", true, IDs.show_quest_npc)
 M.show_other_npc  = safe_widget("checkbox", true, IDs.show_other_npc)
 M.show_game_obj  = safe_widget("checkbox", true, IDs.show_game_obj)
 M.show_friendly  = safe_widget("checkbox", false, IDs.show_friendly)

 M.max_distance  = safe_widget("slider_float", 20.0, 200.0, 80.0, IDs.max_distance)
 M.fps_match   = safe_widget("checkbox", true, IDs.fps_match)
 M.name_font_size  = safe_widget("slider_int", 8, 32, 13,  IDs.name_font_size)
 M.box_thickness  = safe_widget("slider_int", 1, 6,  2,  IDs.box_thickness)
 M.nameplate_z_offset = safe_widget("slider_float", 0.5, 5.0, 2.0, IDs.nameplate_z_offset)
 M.cast_bar_z_offset  = safe_widget("slider_float", 0.5, 5.0, 2.5, IDs.cast_bar_z_offset)
 M.show_occlusion  = safe_widget("checkbox", false, IDs.show_occlusion)
 M.show_threat   = safe_widget("checkbox", false, IDs.show_threat)
 M.show_aggro_radius = safe_widget("checkbox", false, IDs.show_aggro_radius)
 M.use_attachments = safe_widget("checkbox", false, IDs.use_attachments)

 -- v0.3.0
 M.show_health   = safe_widget("checkbox", true, IDs.show_health)
 M.show_distance  = safe_widget("checkbox", true, IDs.show_distance)
 M.target_highlight = safe_widget("checkbox", true, IDs.target_highlight)
 M.show_offscreen  = safe_widget("checkbox", true, IDs.show_offscreen)
 M.alpha_fade   = safe_widget("checkbox", false, IDs.alpha_fade)
 M.dynamic_font  = safe_widget("checkbox", false, IDs.dynamic_font)
 -- PR2: new visibility widgets (nil-safe via safe_widget)
 M.force_min_vis  = safe_widget("checkbox", true, IDs.force_min_vis)
 M.use_2d_boxes  = safe_widget("checkbox", false, IDs.use_2d_boxes)
 M.show_3d_brackets = safe_widget("checkbox", true, IDs.show_3d_brackets)
 M.min_font   = safe_widget("slider_int", 8, 20, 11, IDs.min_font)
 M.min_box_px  = safe_widget("slider_int", 8, 48, 24, IDs.min_box_px)
 M.vis_profile  = safe_widget("combobox", 1, IDs.vis_profile)
 M.z_level_filter  = safe_widget("checkbox", true, IDs.z_level_filter)
 M.z_level_max   = safe_widget("slider_int", 5, 60, 25,  IDs.z_level_max)
 M.level_filter  = safe_widget("checkbox", false, IDs.level_filter)
 M.level_filter_min = safe_widget("slider_int", -20, 0,  -5,  IDs.level_filter_min)
 M.level_filter_max = safe_widget("slider_int", 0, 20, 5,  IDs.level_filter_max)
 M.show_elite_colors = safe_widget("checkbox", true, IDs.show_elite_colors)

 -- v0.3.1
 M.filter_critters  = safe_widget("checkbox", true, IDs.filter_critters)
 M.filter_pets   = safe_widget("checkbox", true, IDs.filter_pets)
 M.filter_totems  = safe_widget("checkbox", true, IDs.filter_totems)
 M.city_mode_auto  = safe_widget("checkbox", true, IDs.city_mode_auto)
 M.city_mode_threshold = safe_widget("slider_int", 5, 50, 20,  IDs.city_mode_threshold)
 M.city_mode_distance = safe_widget("slider_float", 10.0, 80.0, 40.0, IDs.city_mode_distance)
 M.city_mode_health = safe_widget("checkbox", false, IDs.city_mode_health)
 M.city_mode_connector = safe_widget("checkbox", false, IDs.city_mode_connector)
 M.city_mode_npc  = safe_widget("checkbox", false, IDs.city_mode_npc)
 M.dynamic_lod   = safe_widget("checkbox", true, IDs.dynamic_lod)
 M.lod_threshold  = safe_widget("slider_int", 10, 60, 30,  IDs.lod_threshold)
 M.lod_cap    = safe_widget("slider_int", 4, 24, 16,  IDs.lod_cap)
 M.nameplate_stack  = safe_widget("checkbox", true, IDs.nameplate_stack)

 -- v0.4.0
 M.show_loot_indicator  = safe_widget("checkbox", true, IDs.show_loot_indicator)
 M.show_skin_indicator  = safe_widget("checkbox", true, IDs.show_skin_indicator)
 M.show_interrupt_indicator = safe_widget("checkbox", true, IDs.show_interrupt_indicator)
 M.show_ghost_indicator  = safe_widget("checkbox", true, IDs.show_ghost_indicator)
 M.show_cast_bar   = safe_widget("checkbox", true, IDs.show_cast_bar)
 M.show_marker_colors  = safe_widget("checkbox", true, IDs.show_marker_colors)
 M.show_radar    = safe_widget("checkbox", true, IDs.show_radar)
 M.radar_size    = safe_widget("slider_int", 60, 200, 120, IDs.radar_size)
 M.radar_pos_x    = safe_widget("slider_int", 0, 400, 20, IDs.radar_pos_x)
 M.radar_pos_y    = safe_widget("slider_int", 0, 400, 20, IDs.radar_pos_y)
 -- v0.4.3
end

-- Unified widget reader - replaces read_checkbox / read_slider / read_enable.
-- Checkboxes use get_state(); sliders/comboboxes use get().
-- Returns nil if the widget is missing or the pcall fails.
local function read_widget(w)
 if w == nil then return nil end
 if w.get_state then
  local ok, v = pcall(function() return w:get_state() end)
  if ok and v ~= nil then return v end
 end
 if w.get then
  local ok, v = pcall(function() return w:get() end)
  if ok and v ~= nil then return v end
 end
 return nil
end

-- Render-mode combobox maps 1-based index to "questie"/"both"/"all".
-- PS combobox get() returns 1-based: 1="Questie only", 2="Questie + Nearby", 3="All visible".
local RENDER_MODE_MAP = { [1] = "questie", [2] = "both", [3] = "all" }

function M.get(key, fallback)
 if not key then return fallback end
 -- Render mode: combobox index -> string
 if key == "render_mode" then
  local v = read_widget(M.render_mode)
  if v == nil then return fallback end
  return RENDER_MODE_MAP[v] or "all"
 end
 -- PR2 visibility profile: combobox index -> string (stub, applicator in PR4)
 if key == "vis_profile" or key == "visibility_profile" then
  local v = read_widget(M.vis_profile)
  if v == nil then return fallback end
  local PROFILE_MAP = { [1] = "exploration", [2] = "balanced", [3] = "stealth" }
  return PROFILE_MAP[v] or "exploration"
 end
 -- All other keys: unified read
 local v = read_widget(M[key])
 return v == nil and fallback or v
end

-- Lazy color module for header text color (nil = default white).
local _color
do
 local ok, c = pcall(require, "common/color")
 if ok and type(c) == "table" and type(c.new) == "function" then
  _color = c
 end
end

local function hdr_color(r, g, b)
 if _color and _color.new then
  local ok, col = pcall(_color.new, _color, r, g, b, 230)
  if ok and col then return col end
 end
 return nil
end

-- Pre-created header widget (reused every frame, like EaxRotations does).
local _header_widget
if _core_menu and type(_core_menu.header) == "function" then
 local ok, hw = pcall(_core_menu.header)
 if ok and hw and type(hw.render) == "function" then
  _header_widget = hw
 end
end
local _header_color = hdr_color(180, 200, 255)

-- Render a category header inside the tree (inline, no ID needed).
local function category_header(text)
 if _header_widget then
  if _header_color then
   pcall(_header_widget.render, _header_widget, text, _header_color)
  else
   pcall(_header_widget.render, _header_widget, text)
  end
 end
end

function M.render()
 if M.tree == nil or M.tree.render == nil then return false end

 local ok = pcall(function()
  M.tree:render("EaxESP", function()

   -- General
   category_header("General")
   if M.enable   then M.enable:render("Enable ESP", "Master toggle - uncheck to disable all ESP.") end
   if M.debug_log  then M.debug_log:render("Debug Log", "Print a single ingest/frame summary to console every N seconds.") end
   if M.render_mode then M.render_mode:render("Render Mode", RENDER_MODES) end
   if M.fps_match  then M.fps_match:render("Match FPS", "Scan every frame so ESP data refreshes at your display's FPS. Uses core.cpu_time for high-resolution timing. Turn off to throttle scans (lighter on CPU).") end
   if M.max_distance then M.max_distance:render("Max Distance (yards)", "") end

   -- Target Types
   category_header("Target Types")
   if M.show_quest_npc then M.show_quest_npc:render("Show Questie NPCs", "Units flagged by is_quest_unit().") end
   if M.show_other_npc then M.show_other_npc:render("Show Nearby NPCs", "Hostile and non-flagged NPCs.") end
   if M.show_game_obj then M.show_game_obj:render("Show Game Objects", "Herbs / chests / quest objects.") end
   if M.show_friendly then M.show_friendly:render("Show Friendly", "Friendly players and NPCs.") end

   -- Visuals
   category_header("Visuals")
   if M.show_box  then M.show_box:render("Bounding Box", "Outline rectangle on screen.") end
   if M.show_nameplate then M.show_nameplate:render("Nameplate", "Show NPC name above the box.") end
   if M.show_connector then M.show_connector:render("Feet-to-Name Line", "Faint line from feet to nameplate.") end
   if M.name_font_size then M.name_font_size:render("Name Font Size", "") end
   if M.box_thickness then M.box_thickness:render("Box Thickness", "") end
   if M.nameplate_z_offset then M.nameplate_z_offset:render("Nameplate Z Offset", "Height above feet in yards. Increase for mounted/large models.") end
   if M.cast_bar_z_offset then M.cast_bar_z_offset:render("Cast Bar Z Offset", "Height above feet in yards for cast bar ring.") end
   if M.show_occlusion then M.show_occlusion:render("Occlusion Cull", "Hide units behind walls (needs trace_line API).") end
   if M.show_threat then M.show_threat:render("Threat Indicator", "Color health bar border by your threat % (green→yellow→red).") end
   if M.show_aggro_radius then M.show_aggro_radius:render("Aggro Radius", "Draw ground circle around mobs showing their detect range. Red = inside aggro range.") end
   -- DISABLED: Attachment APIs crash the client with native AV (pcall cannot catch).
   -- See plans/bug-report-sylvanas-attachment-api-crash.md
   -- if M.use_attachments then M.use_attachments:render("Use Attachment Positioning", "DISABLED — crashes client") end
   if M.show_health  then M.show_health:render("Show Health Bar", "Small HP bar under each nameplate.") end
   if M.show_distance then M.show_distance:render("Show Distance", "Append distance (e.g. \"42m\") to name.") end
   if M.target_highlight then M.target_highlight:render("Target Highlight", "Thick white box around your current target.") end
   if M.show_offscreen then M.show_offscreen:render("Off-Screen Arrows", "Arrow at screen edge pointing to off-screen targets.") end
   if M.show_elite_colors then M.show_elite_colors:render("Elite/Rare Colors", "Gold/Purple/Red for elite, rare, boss units.") end
   if M.alpha_fade  then M.alpha_fade:render("Distance Alpha Fade", "Artistic fade for immersion (not recommended for questing).") end
   if M.dynamic_font then M.dynamic_font:render("Dynamic Font Scale", "Smaller text for distant targets (artistic; off by default).") end
   if M.nameplate_stack then M.nameplate_stack:render("Stack Nameplates", "Prevent overlapping text in crowds.") end

   -- Visibility (PR2): min visibility config + menu controls. show_3d_brackets default true.
   category_header("Visibility (ESP Legibility)")
   if M.force_min_vis then M.force_min_vis:render("Prevent Distance Fade (Guaranteed Visibility)", "Clamp alpha/font to mins at range (default on).") end
   if M.use_2d_boxes then M.use_2d_boxes:render("Use Screen-Space 2D Boxes (constant size)", "Future 2D rect_2d (PR3).") end
   if M.show_3d_brackets then M.show_3d_brackets:render("Show 3D Brackets (close-range depth cues)", "Legacy 3D for <=~30yd. Default true preserves pre-existing behavior.") end
   if M.min_font then M.min_font:render("Minimum Font Size (px)", "") end
   if M.min_box_px then M.min_box_px:render("Minimum Box Size (px)", "") end
   if M.vis_profile then M.vis_profile:render("Visibility Profile", { "Exploration / ESP", "Balanced", "Stealth / Minimal" }) end

   -- Filtering
   category_header("Filtering")
   if M.z_level_filter then M.z_level_filter:render("Z-Level Filter", "Hide targets too far above/below you.") end
   if M.z_level_max  then M.z_level_max:render("Z-Level Max (yards)", "") end
   if M.level_filter then M.level_filter:render("Level Filter", "Only show mobs within level range.") end
   if M.level_filter_min then M.level_filter_min:render("Level Diff Min", "") end
   if M.level_filter_max then M.level_filter_max:render("Level Diff Max", "") end
   if M.filter_critters then M.filter_critters:render("Filter Critters", "Hide rabbits, squirrels, etc.") end
   if M.filter_pets  then M.filter_pets:render("Filter Non-Combat Pets", "Hide companion pets.") end
   if M.filter_totems then M.filter_totems:render("Filter Totems", "Hide shaman totems.") end

   -- City Mode
   category_header("City Mode")
   if M.city_mode_auto then M.city_mode_auto:render("Auto City Mode", "Shrink range + hide NPCs when many players nearby.") end
   if M.city_mode_threshold then M.city_mode_threshold:render("City Threshold (players)", "Friendlies needed to trigger city mode.") end
   if M.city_mode_distance then M.city_mode_distance:render("City Mode Range (yards)", "Shortened ESP range in cities.") end
   if M.city_mode_health then M.city_mode_health:render("City: Show Health", "Allow health bars even in city mode.") end
   if M.city_mode_connector then M.city_mode_connector:render("City: Show Connectors", "Allow connector lines even in city mode.") end
   if M.city_mode_npc then M.city_mode_npc:render("City: Hide Non-Quest NPCs", "Only players + quest targets in city mode.") end

   -- Performance
   category_header("Performance")
   if M.dynamic_lod  then M.dynamic_lod:render("Dynamic LOD", "Reduce detail when many targets nearby.") end
   if M.lod_threshold then M.lod_threshold:render("LOD Threshold (candidates)", "Candidate count to trigger LOD.") end
   if M.lod_cap   then M.lod_cap:render("LOD Draw Cap", "Max draws when crowded.") end

   -- Indicators
   category_header("Indicators")
   if M.show_loot_indicator then M.show_loot_indicator:render("Loot Indicator", "[L] prefix on lootable corpses.") end
   if M.show_skin_indicator then M.show_skin_indicator:render("Skin Indicator", "[S] prefix on skinnable mobs.") end
   if M.show_interrupt_indicator then M.show_interrupt_indicator:render("Interrupt Indicator", "[I] prefix on interruptable casts.") end
   if M.show_ghost_indicator then M.show_ghost_indicator:render("Ghost/Feign Indicator", "[GHOST] / [FEIGN] prefix.") end
   if M.show_cast_bar then M.show_cast_bar:render("3D Cast Bar", "Ring above units casting spells.") end
   if M.show_marker_colors then M.show_marker_colors:render("Marker Colors", "Raid icon overrides box color.") end

   -- Radar
   category_header("Radar")
   if M.show_radar  then M.show_radar:render("2D Radar", "Corner minimap showing nearby units.") end
   if M.radar_size  then M.radar_size:render("Radar Size (px)", "") end
   if M.radar_pos_x  then M.radar_pos_x:render("Radar X Offset", "Pixels from left edge.") end
   if M.radar_pos_y  then M.radar_pos_y:render("Radar Y Offset", "Pixels from top edge.") end
   if M.radar_show_names then M.radar_show_names:render("Radar Labels", "Show N/S/E/W labels on radar.") end

  end)
 end)
 return ok == true
end

_G.EaxESP = _G.EaxESP or {}
_G.EaxESP.menu = M

return M
