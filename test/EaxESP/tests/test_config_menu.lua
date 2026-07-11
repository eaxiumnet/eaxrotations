-- test_config_menu.lua — Verifies config defaults + menu widget wiring.
local script_path = (debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./")
if script_path:sub(-1) ~= "/" and script_path:sub(-1) ~= "\\" then
 script_path = script_path .. "/"
end
package.path = script_path .. "../?.lua;" .. script_path .. "../?/init.lua;" .. package.path

local pass, fail = 0, 0
local function assert_eq(a, b, msg)
 if a == b then pass = pass + 1
 else fail = fail + 1; print("  [FAIL] " .. msg .. ": expected " .. tostring(b) .. " got " .. tostring(a)) end
end

-- Test config defaults
local config = require("config")
assert_eq(type(config), "table", "config is a table")
assert_eq(config.enabled, true, "enabled default")
assert_eq(config.max_distance, 80.0, "max_distance default")
assert_eq(config.nameplate_z_offset, 2.0, "nameplate_z_offset default")
assert_eq(config.cast_bar_z_offset, 2.5, "cast_bar_z_offset default")
assert_eq(config.show_occlusion, false, "show_occlusion default")
assert_eq(config.show_skeleton, nil, "skeleton config removed")
assert_eq(type(config.box_color), "table", "box_color is table")
assert_eq(#config.box_color, 4, "box_color has 4 components")
assert_eq(config.debug_log, true, "debug_log default")
-- PR1 visibility defaults
assert_eq(config.alpha_fade, false, "alpha_fade default false (no fade by default)")
assert_eq(config.dynamic_font_scale, false, "dynamic_font_scale default false")
assert_eq(config.force_min_visibility, true, "force_min_visibility default true")
assert_eq(config.min_alpha, 0.90, "min_alpha default")
assert_eq(config.min_font_size, 11, "min_font_size default")
-- PR2 new fields (from config)
assert_eq(config.min_box_screen_dim, 24, "min_box_screen_dim default")
assert_eq(config.use_screen_space_boxes, false, "use_screen_space_boxes default")
assert_eq(config.show_3d_brackets, true, "show_3d_brackets default true (preserves 3D)")
assert_eq(config.visibility_profile, "exploration", "visibility_profile default")

-- Test menu module loads (with fake core.menu)
local _orig_core = rawget(_G, "core")
_G.core = {
 menu = {
  checkbox = function(default, id) return { get_state = function() return default end, render = function() end } end,
  slider_int = function(min, max, default, id) return { get = function() return default end, render = function() end } end,
  slider_float = function(min, max, default, id) return { get = function() return default end, render = function() end } end,
  combobox = function(default, id) return { get = function() return default end, render = function() end } end,
  tree_node = function() return { render = function(_, name, fn) fn() end } end,
  header = function() return { render = function() end } end,
 },
}
local menu = require("menu")
assert_eq(type(menu), "table", "menu is a table")
assert_eq(type(menu.get), "function", "menu.get is a function")
assert_eq(type(menu.render), "function", "menu.render is a function")

-- Test menu.get returns config defaults for new keys
assert_eq(menu.get("nameplate_z_offset", 2.0), 2.0, "menu.get nameplate_z_offset")
assert_eq(menu.get("cast_bar_z_offset", 2.5), 2.5, "menu.get cast_bar_z_offset")
assert_eq(menu.get("show_occlusion", false), false, "menu.get show_occlusion")
assert_eq(menu.get("show_skeleton", nil), nil, "menu.get skeleton removed")
-- PR2 menu get paths (nil-safe)
assert_eq(menu.get("force_min_vis", true), true, "menu.get force_min_vis")
assert_eq(menu.get("use_2d_boxes", false), false, "menu.get use_2d_boxes")
assert_eq(menu.get("show_3d_brackets", true), true, "menu.get show_3d_brackets")
assert_eq(menu.get("min_font", 11), 11, "menu.get min_font")
assert_eq(menu.get("min_box_px", 24), 24, "menu.get min_box_px")
assert_eq(menu.get("vis_profile", "exploration"), "exploration", "menu.get vis_profile")
assert_eq(menu.get("visibility_profile", "exploration"), "exploration", "menu.get visibility_profile")

-- Restore core
if _orig_core then _G.core = _orig_core else _G.core = nil end

print(string.format("\n[EaxESP tests/config_menu]\n pass: %d\n fail: %d\n %s",
 pass, fail, fail == 0 and "ALL GREEN" or "HAS FAILURES"))
return fail
