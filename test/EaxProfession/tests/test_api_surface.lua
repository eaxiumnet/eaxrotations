-- =============================================================================
-- test_api_surface.lua — Tests for core/api_surface.lua profession wrappers.
-- =============================================================================
-- WHAT:  Verifies that every api_surface wrapper returns safe defaults and
--        correctly delegates to the mock core.* APIs.
-- WHEN:  Run by run_tests.lua.
-- WHY:   The api_surface is the only module touching core.* — it must be
--        thoroughly tested for nil-safety and correct delegation.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

-- Set up package path for standalone requires
package.path = package.path
  .. ";./EaxProfession/?.lua;./EaxProfession/?/init.lua"

-- Install mock core BEFORE requiring api_surface (it caches at load time)
local mock = require("EaxProfession/tests/mock_core")
mock.install()
mock.reset()

-- Clear any stale api_surface from prior test runs
package.loaded["core/api_surface"] = nil

local APISurface = require("core/api_surface")

local pass_count = 0
local function check(name, cond)
  if cond then
    pass_count = pass_count + 1
  else
    error("FAIL: " .. name, 0)
  end
end

-- 1. Function existence
check("get_professions is function", type(APISurface.get_professions) == "function")
check("get_profession_info is function", type(APISurface.get_profession_info) == "function")
check("get_profession_skill_rank is function", type(APISurface.get_profession_skill_rank) == "function")
check("get_profession_max_rank is function", type(APISurface.get_profession_max_rank) == "function")
check("open_profession is function", type(APISurface.open_profession) == "function")
check("do_trade_skill is function", type(APISurface.do_trade_skill) == "function")
check("get_num_trade_skills is function", type(APISurface.get_num_trade_skills) == "function")
check("get_trade_skill_info is function", type(APISurface.get_trade_skill_info) == "function")
check("do_craft is function", type(APISurface.do_craft) == "function")
check("get_num_crafts is function", type(APISurface.get_num_crafts) == "function")
check("get_num_skill_lines is function", type(APISurface.get_num_skill_lines) == "function")
check("get_api_status is function", type(APISurface.get_api_status) == "function")
print(" AS1 PASS: All api_surface wrappers are functions (" .. pass_count .. " checks)")

-- 2. PROFESSION_ENUM
check("PROFESSION_ENUM is table", type(APISurface.PROFESSION_ENUM) == "table")
check("PROFESSION_ENUM.ALCHEMY == 1", APISurface.PROFESSION_ENUM.ALCHEMY == 1)
check("PROFESSION_ENUM.ENCHANTING == 4", APISurface.PROFESSION_ENUM.ENCHANTING == 4)
print(" AS2 PASS: PROFESSION_ENUM populated")

-- 3. get_professions
mock.reset()
mock._skill_ranks[182] = 300
mock._skill_ranks[186] = 250
local slots = APISurface.get_professions()
check("slots is table", type(slots) == "table")
check("slots.prof1 is number", type(slots.prof1) == "number")
check("slots.prof2 is number", type(slots.prof2) == "number")
print(" AS3 PASS: get_professions returns slots")

-- 4. get_profession_info
local info1 = APISurface.get_profession_info(slots.prof1)
check("info1 is table", type(info1) == "table")
check("info1.skill_line is number", type(info1.skill_line) == "number")
check("info1.skill_level > 0", info1.skill_level > 0)
check("info1.max_skill_level == 375", info1.max_skill_level == 375)
print(" AS4 PASS: get_profession_info returns info")

-- 5. get_profession_skill_rank
check("herb rank == 300", APISurface.get_profession_skill_rank(182) == 300)
check("mine rank == 250", APISurface.get_profession_skill_rank(186) == 250)
check("unknown rank == 0", APISurface.get_profession_skill_rank(999) == 0)
check("invalid rank == 0", APISurface.get_profession_skill_rank(-1) == 0)
print(" AS5 PASS: get_profession_skill_rank resolves")

-- 6. get_profession_max_rank
mock._skill_max[182] = 375
check("herb max == 375", APISurface.get_profession_max_rank(182) == 375)
check("unknown max == 0", APISurface.get_profession_max_rank(999) == 0)
print(" AS6 PASS: get_profession_max_rank works")

-- 7. open_profession
mock._profession_opened = nil
check("open_profession returns true", APISurface.open_profession(mock.profession.ALCHEMY) == true)
check("core.profession.open_profession called", mock._profession_opened == mock.profession.ALCHEMY)
check("open_profession nil returns false", APISurface.open_profession(nil) == false)
print(" AS7 PASS: open_profession delegates")

-- 8. trade_skill safe defaults when window closed
mock.reset()
check("get_num_trade_skills == 0", APISurface.get_num_trade_skills() == 0)
check("get_trade_skill_info == nil", APISurface.get_trade_skill_info(1) == nil)
check("get_trade_skill_num_reagents == 0", APISurface.get_trade_skill_num_reagents(1) == 0)
check("get_trade_skill_reagent_info == nil", APISurface.get_trade_skill_reagent_info(1, 1) == nil)
check("get_trade_skill_line == nil", APISurface.get_trade_skill_line() == nil)
check("get_trade_skill_cooldown == 0", APISurface.get_trade_skill_cooldown(1) == 0)
check("get_trade_skill_selection_index == 0", APISurface.get_trade_skill_selection_index() == 0)
check("get_first_trade_skill == 1", APISurface.get_first_trade_skill() == 1)
check("get_num_primary_professions == 2", APISurface.get_num_primary_professions() == 2)
check("get_trade_skill_tools == {}", #APISurface.get_trade_skill_tools(1) == 0)
print(" AS8 PASS: trade_skill safe defaults when closed")

-- 9. do_trade_skill delegation
mock.reset()
mock._trade_skill_window_open = true
mock._trade_skill_do_calls = {}
APISurface.do_trade_skill(5, 3)
check("do_trade_skill recorded", #mock._trade_skill_do_calls == 1)
check("do_trade_skill index == 5", mock._trade_skill_do_calls[1].index == 5)
check("do_trade_skill count == 3", mock._trade_skill_do_calls[1].count == 3)
APISurface.do_trade_skill(2)
check("do_trade_skill default count == 1", mock._trade_skill_do_calls[2].count == 1)
check("do_trade_skill nil returns false", APISurface.do_trade_skill(nil) == false)
print(" AS9 PASS: do_trade_skill delegation")

-- 10. craft safe defaults
mock.reset()
check("get_num_crafts == 0", APISurface.get_num_crafts() == 0)
check("get_craft_info == nil", APISurface.get_craft_info(1) == nil)
check("get_craft_num_reagents == 0", APISurface.get_craft_num_reagents(1) == 0)
check("get_craft_selection_index == 0", APISurface.get_craft_selection_index() == 0)
print(" AS10 PASS: craft safe defaults")

-- 11. do_craft delegation
mock._craft_do_calls = {}
APISurface.do_craft(3)
check("do_craft recorded", #mock._craft_do_calls == 1)
check("do_craft index == 3", mock._craft_do_calls[1] == 3)
check("do_craft nil returns false", APISurface.do_craft(nil) == false)
print(" AS11 PASS: do_craft delegation")

-- 12. skill safe defaults
mock.reset()
check("get_num_skill_lines == 0", APISurface.get_num_skill_lines() == 0)
check("get_skill_line_info == nil", APISurface.get_skill_line_info(1) == nil)
check("get_selected_skill == 0", APISurface.get_selected_skill() == 0)
check("is_trainer_service_learn_spell == false", APISurface.is_trainer_service_learn_spell(1) == false)
print(" AS12 PASS: skill safe defaults")

-- 13. Retail C_TradeSkillUI wrappers (mock functions exist and don't error)
mock.reset()
check("craft_recipe returns true (pcall ok)", APISurface.craft_recipe(12345) == true)
check("craft_recipe nil returns false", APISurface.craft_recipe(nil) == false)
check("open_trade_skill returns false (mock returns false)", APISurface.open_trade_skill(171) == false)
check("get_recipe_info == nil", APISurface.get_recipe_info(12345) == nil)
check("get_all_recipe_ids == {}", #APISurface.get_all_recipe_ids() == 0)
check("get_craftable_count == 0", APISurface.get_craftable_count(12345) == 0)
check("get_recipe_cooldown == 0", APISurface.get_recipe_cooldown(12345) == 0)
print(" AS13 PASS: retail C_TradeSkillUI wrappers work")

-- 14. API availability probing
mock.reset()
check("is_trade_skill_available == true", APISurface.is_trade_skill_available() == true)
check("is_craft_available == true", APISurface.is_craft_available() == true)
check("is_profession_enum_available == true", APISurface.is_profession_enum_available() == true)
local status = APISurface.get_api_status()
check("api_status.trade_skill == true", status.trade_skill == true)
check("api_status.craft == true", status.craft == true)
check("api_status.profession_enum == true", status.profession_enum == true)
print(" AS14 PASS: API availability probing")

print("PASS test_api_surface (" .. pass_count .. " assertions)")
os.exit(0)
