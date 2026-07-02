-- =============================================================================
-- test_crafting_engine.lua — Tests for professions/crafting_engine.lua.
-- =============================================================================
-- WHAT:  Verifies the crafting engine: skill rank checking, profession opening,
--        recipe scanning, reagent checking, crafting operations, statistics.
-- WHEN:  Run by run_tests.lua.
-- WHY:   The crafting engine is the core business logic — it must correctly
--        delegate to api_surface and handle all edge cases.
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

-- Set up package path for standalone requires
package.path = package.path
  .. ";./EaxProfession/?.lua;./EaxProfession/?/init.lua"

-- Install mock core BEFORE requiring api_surface (it caches at load time)
local mock = require("EaxProfession/tests/mock_core")
mock.install()
mock.reset()

-- Clear stale modules from prior test runs
package.loaded["core/api_surface"] = nil
package.loaded["professions/crafting_engine"] = nil

local Crafting = require("professions/crafting_engine")

local pass_count = 0
local function check(name, cond)
  if cond then
    pass_count = pass_count + 1
  else
    error("FAIL: " .. name, 0)
  end
end

-- 1. Skill rank checking
mock.reset()
mock._skill_ranks[171] = 200
check("get_skill_rank(171) == 200", Crafting.get_skill_rank(171) == 200)
check("get_skill_max_rank(171) == 375", Crafting.get_skill_max_rank(171) == 375)
check("has_profession(171) == true", Crafting.has_profession(171) == true)
check("has_profession(164) == false", Crafting.has_profession(164) == false)
check("get_skill_rank(999) == 0", Crafting.get_skill_rank(999) == 0)
print(" CE1 PASS: Skill rank checking works")

-- 2. can_craft_profession
mock._skill_ranks[182] = 300  -- Herbalism (gathering)
check("can_craft_profession(171) == true", Crafting.can_craft_profession(171) == true)
check("can_craft_profession(182) == false", Crafting.can_craft_profession(182) == false)
check("can_craft_profession(999) == false", Crafting.can_craft_profession(999) == false)
check("can_craft_profession(164) == false", Crafting.can_craft_profession(164) == false)
print(" CE2 PASS: can_craft_profession filters correctly")

-- 3. open_profession uses enum
mock.reset()
mock._skill_ranks[171] = 200
mock._profession_opened = nil
check("open_profession returns true", Crafting.open_profession(171) == true)
check("open_profession called with ALCHEMY enum", mock._profession_opened == mock.profession.ALCHEMY)
check("open_profession(999) returns false", Crafting.open_profession(999) == false)
print(" CE3 PASS: open_profession uses core.profession enum")

-- 4. scan_trade_skill_recipes — empty when closed
mock.reset()
check("scan returns empty when closed", #Crafting.scan_trade_skill_recipes() == 0)
print(" CE4 PASS: scan empty when window closed")

-- 5. scan_trade_skill_recipes — returns recipes when open
mock.reset()
mock._skill_ranks[171] = 200
mock._trade_skill_window_open = true
mock._trade_skill_recipes[1] = {
  name = "Minor Healing Potion", type = "optimal", num_available = 5,
  reagents = {
    { name = "Peacebloom", count = 1, player_count = 10 },
    { name = "Silverleaf", count = 1, player_count = 10 },
  },
  cooldown = 0,
}
mock._trade_skill_recipes[2] = {
  name = "Lesser Healing Potion", type = "optimal", num_available = 3,
  reagents = { { name = "Minor Healing Potion", count = 1, player_count = 5 } },
  cooldown = 0,
}
local recipes = Crafting.scan_trade_skill_recipes()
check("scan returns 2 recipes", #recipes == 2)
check("recipe 1 name correct", recipes[1].name == "Minor Healing Potion")
check("recipe 1 num_available == 5", recipes[1].num_available == 5)
check("recipe 1 num_reagents == 2", recipes[1].num_reagents == 2)
print(" CE5 PASS: scan returns recipes when open")

-- 6. find_recipe — case-insensitive substring
local found = Crafting.find_recipe(171, "minor healing")
check("find_recipe finds by substring", found ~= nil)
check("find_recipe name matches", found.name == "Minor Healing Potion")
check("find_recipe nil for no match", Crafting.find_recipe(171, "nonexistent") == nil)
check("find_recipe nil for empty string", Crafting.find_recipe(171, "") == nil)
print(" CE6 PASS: find_recipe substring match works")

-- 7. has_reagents
check("has_reagents(1) == true", Crafting.has_reagents(1) == true)
mock._trade_skill_recipes[1].reagents[1].player_count = 0
check("has_reagents(1) == false after depleting", Crafting.has_reagents(1) == false)
mock._trade_skill_recipes[3] = { name = "Empty", type = "trivial", reagents = nil }
check("has_reagents(3) == true (no reagents)", Crafting.has_reagents(3) == true)
print(" CE7 PASS: has_reagents checks correctly")

-- 8. craft_by_name — full flow
mock.reset()
mock._skill_ranks[171] = 200
mock._trade_skill_window_open = true
mock._trade_skill_recipes[1] = {
  name = "Minor Healing Potion", type = "optimal", num_available = 20,
  reagents = {
    { name = "Peacebloom", count = 1, player_count = 10 },
    { name = "Silverleaf", count = 1, player_count = 10 },
  }, cooldown = 0,
}
mock._trade_skill_do_calls = {}
check("craft_by_name returns true", Crafting.craft_by_name(171, "Minor Healing", 5) == true)
check("do_trade_skill was called", #mock._trade_skill_do_calls == 1)
check("do_trade_skill index == 1", mock._trade_skill_do_calls[1].index == 1)
check("do_trade_skill count == 5", mock._trade_skill_do_calls[1].count == 5)
print(" CE8 PASS: craft_by_name full flow works")

-- 9. craft_by_name — fails when reagents insufficient
mock._trade_skill_recipes[1].reagents[1].player_count = 0
mock._trade_skill_do_calls = {}
check("craft_by_name false when no reagents", Crafting.craft_by_name(171, "Minor Healing", 1) == false)
check("do_trade_skill not called", #mock._trade_skill_do_calls == 0)
print(" CE9 PASS: craft_by_name fails when no reagents")

-- 10. craft_by_name — fails on cooldown
mock._trade_skill_recipes[1].reagents[1].player_count = 10
mock._trade_skill_recipes[1].cooldown = 300
mock._trade_skill_do_calls = {}
check("craft_by_name false on cooldown", Crafting.craft_by_name(171, "Minor Healing", 1) == false)
check("do_trade_skill not called on cd", #mock._trade_skill_do_calls == 0)
print(" CE10 PASS: craft_by_name fails on cooldown")

-- 11. craft_by_name — fails for non-craftable profession
mock.reset()
mock._skill_ranks[182] = 300
check("craft_by_name false for gathering", Crafting.craft_by_name(182, "test", 1) == false)
print(" CE11 PASS: craft_by_name fails for non-craftable")

-- 12. craft_by_index
mock.reset()
mock._skill_ranks[171] = 200
mock._trade_skill_window_open = true
mock._trade_skill_recipes[3] = {
  name = "Elixir of Wisdom", type = "optimal", num_available = 10,
  reagents = { { name = "Mageroyal", count = 1, player_count = 5 } }, cooldown = 0,
}
mock._trade_skill_do_calls = {}
check("craft_by_index returns true", Crafting.craft_by_index(171, 3, 2) == true)
check("craft_by_index called", #mock._trade_skill_do_calls == 1)
check("craft_by_index index == 3", mock._trade_skill_do_calls[1].index == 3)
check("craft_by_index count == 2", mock._trade_skill_do_calls[1].count == 2)
print(" CE12 PASS: craft_by_index works")

-- 13. craft_enchant_by_name — uses Craft UI
mock.reset()
mock._skill_ranks[333] = 250
mock._craft_window_open = true
mock._craft_recipes[1] = {
  name = "Enchant Bracer - Minor Strength", type = "optimal", num_available = 1,
  reagents = { { name = "Strange Dust", count = 1, player_count = 5 } },
}
mock._craft_do_calls = {}
check("craft_enchant returns true", Crafting.craft_enchant_by_name(333, "Minor Strength") == true)
check("do_craft was called", #mock._craft_do_calls == 1)
check("do_craft index == 1", mock._craft_do_calls[1] == 1)
print(" CE13 PASS: craft_enchant_by_name uses Craft UI")

-- 14. craft_all — mass production
mock.reset()
mock._skill_ranks[171] = 200
mock._trade_skill_window_open = true
mock._trade_skill_recipes[1] = {
  name = "Recipe A", type = "optimal", num_available = 5,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}
mock._trade_skill_recipes[2] = {
  name = "Recipe B", type = "optimal", num_available = 3,
  reagents = { { name = "Herb", count = 1, player_count = 10 } }, cooldown = 0,
}
mock._trade_skill_recipes[3] = {
  name = "Recipe C", type = "optimal", num_available = 2,
  reagents = { { name = "Herb", count = 1, player_count = 0 } }, cooldown = 0,
}
mock._trade_skill_do_calls = {}
local total = Crafting.craft_all(171, 10)
check("craft_all returns total > 0", total > 0)
check("craft_all crafted 2 (A+B, not C)", #mock._trade_skill_do_calls == 2)
print(" CE14 PASS: craft_all mass production works")

-- 15. Statistics tracking
local stats = Crafting.get_stats()
check("stats is table", type(stats) == "table")
check("stats.crafts_attempted > 0", stats.crafts_attempted > 0)
check("stats.crafts_succeeded > 0", stats.crafts_succeeded > 0)
Crafting.reset_stats()
check("stats reset to 0", Crafting.get_stats().crafts_attempted == 0)
print(" CE15 PASS: Statistics tracking works")

-- 16. get_player_professions — discovery
mock.reset()
mock._skill_ranks[171] = 200
mock._skill_ranks[182] = 300
mock._skill_ranks[185] = 250
local profs = Crafting.get_player_professions()
check("get_player_professions returns 3", #profs == 3)
local alchemy, herbalism
for _, prof in ipairs(profs) do
  check("prof has skill_id", type(prof.skill_id) == "number")
  check("prof has name", type(prof.name) == "string")
  check("prof has is_craftable", type(prof.is_craftable) == "boolean")
  if prof.skill_id == 171 then alchemy = prof end
  if prof.skill_id == 182 then herbalism = prof end
end
check("Alchemy is_craftable == true", alchemy.is_craftable == true)
check("Herbalism is_craftable == false", herbalism.is_craftable == false)
print(" CE16 PASS: get_player_professions discovery works")

print("PASS test_crafting_engine (" .. pass_count .. " assertions)")
os.exit(0)
