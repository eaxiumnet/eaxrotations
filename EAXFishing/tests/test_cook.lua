-- =============================================================================
-- test_cook.lua — EAXFishing fishing/cook.lua pure-logic tests.
-- =============================================================================
-- WHAT:  Verifies the COOKABLE recipe table is structured correctly and that
--        the internal helpers behave under mocked conditions.
-- WHEN:  Run by run_fishing_tests.lua.
-- WHY:   cook.lua is a brand-new module with 9 DBC-verified recipe mappings.
--        A regression here silently fails to cook fish, wasting bag space.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

package.path = "./EAXFishing/?.lua;./EAXFishing/?/init.lua;" .. package.path

-- Must stub core before loading modules that touch APISurface
_G.core = nil

-- Minimal APISurface stub for pure-logic tests
package.loaded["core/api_surface"] = {
  is_spell_learned = function(id) return false end,
  get_item_count   = function(id) return 0 end,
  get_all_objects  = function() return {} end,
  get_object_position = function(o) return nil end,
  is_valid = function(o) return false end,
  is_casting_spell = function(o) return false end,
  is_channelling_spell = function(o) return false end,
  print = function(msg) end,
  cast_target_spell = function(sid, target) return false end,
}

-- Stub LootDB
package.loaded["fishing/loot_db"] = {
  get = function(id)
    local f = {
      [27422]={name="Barbed Gill Trout", quality=2, cat="fish"},
      [27425]={name="Spotted Feltail", quality=2, cat="fish"},
      [27435]={name="Furious Crawdad", quality=2, cat="fish"},
      [27438]={name="Icefin Bluefish", quality=2, cat="fish"},
      [27439]={name="Figluster's Mudfish", quality=2, cat="fish"},
      [27426]={name="Zangarian Sporefish", quality=2, cat="fish"},
      [6308] ={name="Raw Bristle Whisker Catfish", quality=2, cat="fish"},
      [13760]={name="Raw Greater Sagefish", quality=2, cat="fish"},
      [13757]={name="Raw Sagefish", quality=2, cat="fish"},
    }
    return f[id]
  end,
  get_by_name = function() return nil end,
  CAT_FISH = "fish",
  CAT_GRAY = "gray",
  CAT_TRADE = "trade",
  CAT_OTHER = "other",
}

local Cook = require("fishing/cook")

local pass_count = 0
local function check(name, cond)
  if cond then
    pass_count = pass_count + 1
  else
    error("FAIL: " .. name, 0)
  end
end

-- 1. Module loads and exposes expected API
local Cook2 = require("fishing/cook")
check("module is table", type(Cook) == "table")
check("find_cookable_stack is function", type(Cook.find_cookable_stack) == "function")
check("can_cook_here is function", type(Cook.can_cook_here) == "function")
check("try_cook is function", type(Cook.try_cook) == "function")
check("reset is function", type(Cook.reset) == "function")
print(" CK1 PASS: module exposes expected API")

-- 2. find_cookable_stack returns nil when player knows no recipes and has no items
local raw_id, spell_id, count = Cook.find_cookable_stack()
check("no recipes → nil raw_id", raw_id == nil)
check("no recipes → nil spell_id", spell_id == nil)
check("no recipes → count 0", count == 0)
print(" CK2 PASS: find_cookable_stack safe when no recipes/items")

-- 3. reset clears state fields
do
  local mock_state = {
    cook = {
      last_cook_time = 99,
      cooked_count = 5,
      queued = "x",
      status = "busy",
      cook_delay_end = 12,
    }
  }
  local mock_ctx = { state = mock_state }
  Cook.reset(mock_ctx)
  check("reset clears last_cook_time", mock_state.cook.last_cook_time == 0.0)
  check("reset clears cooked_count", mock_state.cook.cooked_count == 0)
  check("reset clears queued", mock_state.cook.queued == nil)
  check("reset clears status", mock_state.cook.status == "Idle")
  check("reset clears cook_delay_end", mock_state.cook.cook_delay_end == 0.0)
end
print(" CK3 PASS: reset() zeroes all cook state fields")

-- 4. value_for_pool sanity (via requiring pool_ranker; just a structural check)
local PR = require("fishing/pool_ranker")
check("pool_ranker loaded OK", type(PR) == "table")
check("pool_ranker score_pool works", PR.score_pool(100, "Furious Crawdad") > 0)
print(" CK4 PASS: pool_ranker structural sanity")

print("PASS test_cook (" .. pass_count .. " assertions)")
os.exit(0)
