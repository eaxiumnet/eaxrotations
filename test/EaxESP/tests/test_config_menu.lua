-- ============================================================================
-- EaxESP/tests/test_config_menu.lua (PR3)
-- ----------------------------------------------------------------------------
-- Verifies config defaults (PR1+PR2+PR3) + basic menu wiring simulation.
-- Run: lua EaxESP/tests/test_config_menu.lua
-- ============================================================================

local script_path = (debug.getinfo(1, "S").source:match("@(.*[/\\])") or "./")
if script_path:sub(-1) ~= "/" and script_path:sub(-1) ~= "\\" then
 script_path = script_path .. "/"
end
package.path = script_path .. "../?.lua;" .. script_path .. "../?/init.lua;" .. package.path

local results = { pass = 0, fail = 0, fails = {} }
local function check(name, cond, detail)
 if cond then
  results.pass = results.pass + 1
 else
  results.fail = results.fail + 1
  results.fails[#results.fails + 1] = name .. (detail and (" -- " .. detail) or "")
 end
end

-- Load config (provides defaults)
local ok, config = pcall(require, "config")
check("config module loads", ok and type(config) == "table", "err=" .. tostring(config))

if ok and config then
 check("alpha_fade default false (PR1)", config.alpha_fade == false)
 check("dynamic_font_scale default false (PR1)", config.dynamic_font_scale == false)
 check("force_min_visibility default true (PR1)", config.force_min_visibility == true)
 check("min_alpha default 0.90", config.min_alpha == 0.90)
 check("min_font_size default 11", config.min_font_size == 11)
 check("min_box_screen_dim default 24 (PR2)", config.min_box_screen_dim == 24)
 check("use_screen_space_boxes default false (PR2)", config.use_screen_space_boxes == false)
 check("show_3d_brackets default true (PR2)", config.show_3d_brackets == true)
 check("box_3d_fade_with_distance default false (PR3)", config.box_3d_fade_with_distance == false)
 check("visibility_profile default exploration", config.visibility_profile == "exploration")
end

-- Simulate menu widget (nil-safe pattern from design)
local function fake_checkbox(default, id) return { get = function() return default end } end
local function fake_slider_int(minv, maxv, default, id) return { get = function() return default end } end
local function fake_combobox(default, id) return { get = function() return default end } end

-- basic get wiring test (as if from menu)
local menu_sim = {
 use_2d = fake_checkbox(false, "eaxesp_use_2d_boxes"),
 show_3d = fake_checkbox(true, "eaxesp_show_3d_brackets"),
 min_box = fake_slider_int(8, 48, 24, "eaxesp_min_box_px"),
}
check("menu sim use_2d", menu_sim.use_2d.get() == false)
check("menu sim show_3d", menu_sim.show_3d.get() == true)

-- Report
io.write("\n[EaxESP tests/config_menu]\n")
io.write(string.format(" pass: %d\n fail: %d\n", results.pass, results.fail))
if results.fail > 0 then
 for _, f in ipairs(results.fails) do io.write(" FAIL: " .. f .. "\n") end
 os.exit(1)
end
io.write(" ALL GREEN\n")
