-- =============================================================================
-- test_config_safe_menu.lua — EAXFishing config.lua safe-menu / DUMMY tests.
-- =============================================================================
-- WHAT:  Verifies the safe_menu() guard and DUMMY defaults in config.lua so the
--        engine never crashes when core.menu is missing, empty, or partially
--        populated. Also asserts every menu widget exposes the accessor methods
--        the engine calls (get_state / get / set) — a regression guard for the
--        nil-guard work (see plans/multi-module-deepscan-2026-07-03.md BUG-2).
-- WHEN:  Run by run_fishing_tests.lua.
-- WHY:   config.lua is the contract surface the engine reads every tick via
--        guarded `menu.X and menu.X.get_state then` checks. If a widget ever
--        returns a bare nil instead of a DUMMY, the engine crashes mid-cast.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

package.path = "./EAXFishing/?.lua;./EAXFishing/?/init.lua;" .. package.path

local pass_count = 0
local function check(name, cond)
  if cond then
    pass_count = pass_count + 1
  else
    error("FAIL: " .. name, 0)
  end
end

-- Helper: assert a widget is non-nil and exposes the listed method names.
local function assert_widget(name, widget, methods)
  check(name .. " is non-nil", widget ~= nil)
  for _, m in ipairs(methods) do
    check(name .. " has " .. m, type(widget[m]) == "function")
  end
end

-- Fresh-load helper: config.lua reads `core` at load time, so we must clear
-- package.loaded and set _G.core before each require.
local function load_config_with(core_val)
  package.loaded["config"] = nil
  _G.core = core_val
  return require("config")
end

-- 1. core.menu is nil entirely → all widgets are DUMMY with safe defaults
do
  _G.core = { menu = nil }  -- safe_menu's `menu` lookup returns DUMMY path
  local config = load_config_with(_G.core)
  local m = config.menu
  check("menu table exists when core.menu nil", type(m) == "table")
  check("enabled is DUMMY (bool false)", m.enabled:get_state() == false)
  check("esp_range DUMMY get() == 0", m.esp_range:get() == 0)
  assert_widget("auto_equip", m.auto_equip, { "get_state" })
  assert_widget("auto_lure", m.auto_lure, { "get_state" })
  assert_widget("auto_stop_full", m.auto_stop_full, { "get_state" })
  assert_widget("cast_delay_min_ms", m.cast_delay_min_ms, { "get", "set" })
  print(" CSM1 PASS: core.menu nil → all widgets DUMMY-safe")
end

-- 2. core.menu is an empty table → constructors missing → DUMMY
do
  _G.core = { menu = {} }
  local config = load_config_with(_G.core)
  local m = config.menu
  check("enabled DUMMY get_state false (empty menu)", m.enabled:get_state() == false)
  check("auto_equip DUMMY get_state false (empty menu)", m.auto_equip:get_state() == false)
  check("pool_search_range DUMMY get 0 (empty menu)", m.pool_search_range:get() == 0)
  check("session_time_limit DUMMY get 0 (empty menu)", m.session_time_limit:get() == 0)
  print(" CSM2 PASS: core.menu empty table → all widgets DUMMY-safe")
end

-- 3. core is nil entirely → DUMMY path (the `core and core.menu and` guard)
do
  local config = load_config_with(nil)
  local m = config.menu
  check("menu table exists when core nil", type(m) == "table")
  check("enabled DUMMY false when core nil", m.enabled:get_state() == false)
  assert_widget("enabled", m.enabled, { "get_state", "set_state" })
  print(" CSM3 PASS: core nil → widgets DUMMY-safe")
end

-- 4. core.menu fully mocked → real widgets returned with correct defaults
do
  local function mk(state_kind, default)
    return {
      get_state = function() return default end,
      get       = function() return default end,
      set       = function() end,
      set_state = function() end,
    }
  end
  _G.core = {
    menu = {
      tree_node  = function() return mk("tree", false) end,
      checkbox   = function(d, id) return mk("check", d) end,
      slider_int = function(mi, ma, d, id) return mk("slider", d) end,
      slider_float = function(mi, ma, d, id) return mk("slider", d) end,
      combobox   = function(d, id) return mk("combo", d) end,
      keybind    = function(k, t, id) return mk("key", false) end,
    },
  }
  local config = load_config_with(_G.core)
  local m = config.menu
  -- enabled defaults to false (config passes `false` to checkbox)
  check("enabled default honors constructor (false)", m.enabled:get_state() == false)
  -- auto_equip defaults to true (config passes `true`)
  check("auto_equip default true (constructor arg)", m.auto_equip:get_state() == true)
  -- esp_range default 150 (slider_int(10, 500, 150, ...))
  check("esp_range default 150", m.esp_range:get() == 150)
  -- pool_search_range default 250
  check("pool_search_range default 250", m.pool_search_range:get() == 250)
  -- cast_delay_min_ms default 900
  check("cast_delay_min_ms default 900", m.cast_delay_min_ms:get() == 900)
  -- anti_afk_interval_min default 60
  check("anti_afk_interval_min default 60", m.anti_afk_interval_min:get() == 60)
  print(" CSM4 PASS: full core.menu mock returns real widgets + defaults honored")
end

-- 5. A constructor that THROWS (pcall failure inside safe_menu) → DUMMY
do
  _G.core = {
    menu = {
      tree_node = function() return {} end,
      checkbox  = function(d, id) error("boom") end,  -- constructor errors
      slider_int = function(mi, ma, d, id) return nil end, -- returns nil
      combobox  = function(d, id) return mk_dummy() end,
    },
  }
  -- Provide a fallback combobox maker for the test
  _G.core.menu.combobox = function() return { get = function() return 1 end } end
  local config = load_config_with(_G.core)
  local m = config.menu
  -- checkbox throwing → DUMMY (get_state returns false, no error propagation)
  check("throwing checkbox → DUMMY get_state false", m.enabled:get_state() == false)
  check("throwing checkbox auto_equip → DUMMY false", m.auto_equip:get_state() == false)
  -- slider returning nil → DUMMY (get returns 0)
  check("nil slider → DUMMY get 0", m.esp_range:get() == 0)
  print(" CSM5 PASS: throwing/nil constructors → DUMMY (no error propagation)")
end

-- 6. Every engine-read menu key exists on the menu table (contract check).
--    This is the BUG-2 regression guard: the engine reads these keys; any
--    missing key would break the `if menu.X and menu.X.get_state` nil-guard.
do
  _G.core = nil
  local config = load_config_with(nil)
  local m = config.menu
  local engine_keys = {
    "enabled", "auto_equip", "auto_lure", "auto_cook", "esp_enabled", "esp_range",
    "pool_tracking", "smart_pool_ranking", "pool_search_range", "pool_standoff_distance",
    "humanizer_enabled", "cast_delay_min_ms", "cast_delay_max_ms",
    "catch_delay_min_ms", "catch_delay_max_ms", "anti_afk_enabled",
    "anti_afk_interval_min", "anti_afk_interval_max", "enable_missed_catches",
    "enable_fish_escape", "auto_stop_full", "auto_vendor_repair",
    "break_frequency", "session_time_limit", "cast_jitter_enabled",
    "cast_jitter_degrees", "dip_bite_fallback", "dip_threshold",
  }
  for _, k in ipairs(engine_keys) do
    check("menu key exists: " .. k, m[k] ~= nil)
  end
  print(" CSM6 PASS: all " .. #engine_keys .. " engine-read menu keys present (BUG-2 guard)")
end

print("PASS test_config_safe_menu (" .. pass_count .. " assertions)")
os.exit(0)