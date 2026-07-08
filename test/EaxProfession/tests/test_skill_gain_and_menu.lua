-- =============================================================================
-- test_skill_gain_and_menu.lua — Skill-gain filter + menu render regression.
-- =============================================================================
-- WHAT:  Verifies (a) the skill_gain_only filter skips grey/green recipes in
--          craft_all / craft_by_name / craft_enchant_by_name, and (b) the menu
--          module builds + renders without crashing and exposes safe accessor
--          defaults when core.menu is empty (the test mock) or fully populated.
-- WHEN:  Run by run_tests.lua.
-- WHY:   BUG-3 fixed a menu that NEVER rendered (on_render_menu referenced an
--        undefined _menu global). FEATURE-2 added skill-gain mode. Both need
--        regression guards so the bugs don't silently return.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

package.path = package.path
  .. ";./EaxProfession/?.lua;./EaxProfession/?/init.lua"

local mock = require("EaxProfession/tests/mock_core")
mock.install()
mock.reset()

-- Clear stale modules from prior test runs
package.loaded["core/api_surface"] = nil
package.loaded["professions/crafting_engine"] = nil
package.loaded["ui/menu"] = nil

local Crafting = require("professions/crafting_engine")
package.loaded["ui/menu"] = nil
local Menu = require("ui/menu")

local pass_count = 0
local function check(name, cond)
  if cond then
    pass_count = pass_count + 1
  else
    error("FAIL: " .. name, 0)
  end
end

-- =============================================================================
-- Part A: Skill-gain filter
-- =============================================================================
-- Set up an alchemy window with an orange (optimal), yellow (medium),
-- green (easy), and grey (trivial) recipe, all with reagents + no cooldown.

mock.reset()
mock._skill_ranks[171] = 200              -- Alchemy learned
mock._trade_skill_window_open = true
mock._trade_skill_recipes[1] = {
  name = "Orange Brew", type = "optimal", num_available = 5,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}
mock._trade_skill_recipes[2] = {
  name = "Yellow Brew", type = "medium", num_available = 5,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}
mock._trade_skill_recipes[3] = {
  name = "Green Brew", type = "easy", num_available = 5,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}
mock._trade_skill_recipes[4] = {
  name = "Grey Brew", type = "trivial", num_available = 5,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}

-- A1: craft_all WITHOUT skill-gain crafts all 4 recipes
mock._trade_skill_do_calls = {}
local total_all = Crafting.craft_all(171, 1, false)
check("craft_all (no filter) total == 4", total_all == 4)
check("craft_all (no filter) issued 4 do_trade_skill calls", #mock._trade_skill_do_calls == 4)
print(" SGM1 PASS: craft_all crafts all recipes when skill_gain=false")

-- A2: craft_all WITH skill-gain skips green + grey (only optimal + medium)
mock._trade_skill_do_calls = {}
local total_gain = Crafting.craft_all(171, 1, true)
check("craft_all (skill-gain) total == 2", total_gain == 2)
check("craft_all (skill-gain) issued 2 do_trade_skill calls", #mock._trade_skill_do_calls == 2)
print(" SGM2 PASS: craft_all skips grey/green in skill-gain mode")

-- A3: craft_by_name with skill-gain skips a grey recipe
mock._trade_skill_do_calls = {}
local grey_ok = Crafting.craft_by_name(171, "Grey Brew", 1, true)
check("craft_by_name grey skipped in skill-gain mode", grey_ok == false)
check("do_trade_skill not called for grey in skill-gain mode", #mock._trade_skill_do_calls == 0)
print(" SGM3 PASS: craft_by_name skips grey in skill-gain mode")

-- A4: craft_by_name with skill-gain crafts an orange recipe
mock._trade_skill_do_calls = {}
local orange_ok = Crafting.craft_by_name(171, "Orange Brew", 1, true)
check("craft_by_name orange crafted in skill-gain mode", orange_ok == true)
check("do_trade_skill called for orange in skill-gain mode", #mock._trade_skill_do_calls == 1)
print(" SGM4 PASS: craft_by_name crafts orange in skill-gain mode")

-- A5: craft_by_name WITHOUT skill-gain crafts a grey recipe (back-compat)
mock._trade_skill_do_calls = {}
local grey_ok2 = Crafting.craft_by_name(171, "Grey Brew", 1, false)
check("craft_by_name grey crafted when skill_gain=false", grey_ok2 == true)
check("do_trade_skill called for grey when skill_gain=false", #mock._trade_skill_do_calls == 1)
print(" SGM5 PASS: craft_by_name back-compat (no filter) crafts grey")

-- A6: nil recipe type treated as skill-up eligible (older clients)
mock._trade_skill_recipes[5] = {
  name = "Unknown Type Brew", type = nil, num_available = 2,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}
mock._trade_skill_do_calls = {}
local nil_ok = Crafting.craft_by_name(171, "Unknown Type", 1, true)
check("craft_by_name nil-type crafted in skill-gain mode", nil_ok == true)
check("do_trade_skill called for nil-type in skill-gain mode", #mock._trade_skill_do_calls == 1)
print(" SGM6 PASS: nil recipe type treated as skill-up eligible")

-- =============================================================================
-- Part B: Menu build + render with EMPTY mock core.menu (the test default)
-- =============================================================================
mock.reset()  -- core.menu = {} (empty table)
package.loaded["ui/menu"] = nil
Menu = require("ui/menu")

Menu.build()
-- B1: Accessors return safe defaults when no widgets exist
check("is_enabled() == false (empty menu)", Menu.is_enabled() == false)
check("get_profession_index() == 1 (default)", Menu.get_profession_index() == 1)
check("get_recipe_filter() == '' (default)", Menu.get_recipe_filter() == "")
check("get_craft_count() == 1 (default)", Menu.get_craft_count() == 1)
check("is_mass_craft() == false (default)", Menu.is_mass_craft() == false)
check("is_auto_open() == true (default)", Menu.is_auto_open() == true)
check("is_skill_gain_mode() == false (default)", Menu.is_skill_gain_mode() == false)
print(" SMR1 PASS: menu accessors return safe defaults (empty core.menu)")

-- B2: render() is a no-op (no crash) when no widgets
local render_ok = true
local function try_render() Menu.render() end
render_ok = pcall(try_render)
check("render() does not crash with empty menu", render_ok == true)
check("PROFESSION_OPTIONS has 9 entries", #Menu.PROFESSION_OPTIONS == 9)
check("PROFESSION_OPTIONS[1] == 'Alchemy'", Menu.PROFESSION_OPTIONS[1] == "Alchemy")
check("PROFESSION_OPTIONS[9] == 'Jewelcrafting'", Menu.PROFESSION_OPTIONS[9] == "Jewelcrafting")
print(" SMR2 PASS: render() no-crash + option labels correct")

-- =============================================================================
-- Part C: Menu build with a fully-populated mock core.menu
-- =============================================================================
mock.reset()
local _calls = { tree = 0, render_calls = 0 }
local function mk_widget(default_val, val_kind)
  local state = default_val
  return {
    get_state = function() return state end,
    get       = function() return state end,
    set       = function(v) state = v end,
    render    = function(self, label, opt_b, opt_c)
      _calls.render_calls = _calls.render_calls + 1
      _calls.last_label = label
    end,
  }
end
mock.menu = {
  tree_node  = function() _calls.tree = _calls.tree + 1 return mk_widget(true, "tree") end,
  checkbox   = function(d, id) return mk_widget(d, "check") end,
  combobox   = function(d, id) return mk_widget(d, "combo") end,
  text_input = function(d, id) return mk_widget(d, "text") end,
  slider_int = function(mi, ma, d, id) return mk_widget(d, "slider") end,
}
-- Re-install so api_surface (cached core) sees the new menu — but menu.lua reads
-- core.menu fresh via safe_menu at build() time, so just rebuild.
package.loaded["ui/menu"] = nil
Menu = require("ui/menu")
Menu.build()

-- C1: build() created the tree_node + all widgets
check("build created tree_node (tree count >= 1)", _calls.tree >= 1)
check("is_enabled() == true (checkbox default true)", Menu.is_enabled() == true)
check("get_profession_index() == 1 (combobox default 1)", Menu.get_profession_index() == 1)
check("get_craft_count() == 1 (slider default 1)", Menu.get_craft_count() == 1)
check("is_auto_open() == true (checkbox default true)", Menu.is_auto_open() == true)
check("is_skill_gain_mode() == false (skill-gain default false)", Menu.is_skill_gain_mode() == false)
print(" SMR3 PASS: build() populated widgets with full core.menu mock")

-- C2: render() actually draws widgets (render_calls increments)
local _render_calls_before = _calls.render_calls
Menu.render()
check("render() invoked widget render methods", _calls.render_calls > _render_calls_before)
print(" SMR4 PASS: render() actually draws widgets (BUG-3 regression guard)")

print("PASS test_skill_gain_and_menu (" .. pass_count .. " assertions)")
os.exit(0)