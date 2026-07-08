-- test_destruction_mana_gem.lua -- Destruction mana management tests.
-- WHAT:  Destruction mana management tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Feature audit for destruction_sylvanas: Mana Gem auto-use.
-- Mana Gem auto-use at configurable threshold is a feature gap.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
 assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
 assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
 assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
_G.EaxRotations = {
 WarlockSpells = {
  Shadowburn = 17877,
  Immolate = 348,
  Conflagrate = 17962,
  Incinerate = 29722,
  ShadowBolt = 27209,
  Corruption = 172,
  CurseOfAgony = 27218,
  CurseOfDoom = 30910,
  SearingPain = 30459,
  SoulFire = 30545,
  DeathCoil = 27223,
  Fear = 6215,
  RainOfFire = 27212,
  Hellfire = 27213,
  SeedOfCorruption = 27243,
  DrainLife = 27220,
  LifeTap = 27222,
  DarkPact = 27265,
  HealthFunnel = 27259,
  FelArmor = 28176,
  DemonArmor = 27260,
  ShadowWard = 28610,
  CreateHealthstone = 27230,
  SummonImp = 688,
  SummonVoidwalker = 697,
  SummonSuccubus = 712,
  SummonFelhunter = 691,
  SummonFelguard = 30146,
  FelDomination = 18708,
  Soulshatter = 29858,
 },
 has_item = function() return false end,
 is_execute_phase = function() return false end,
 is_item_ready = function() return false end,
 use_item_by_id = function() end,
 spell_ready = function() return false end,
 try_cast = function() return false end,
 action_matches = function(ctx, act)
  return true
 end,
 spell_action = function(spell_ids, name)
  return { spell = spell_ids, name = name }
 end,
 log = function() end,
 rotation_registry = {
  register = function() end,
 },
}

local strategies = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries")

-- Collect strategy names for audit
local strategy_names = {}
for i = 1, #strategies do
 strategy_names[strategies[i].name] = true
end

-- ============================================================================
-- Feature Audit: Check which features exist vs missing
-- ============================================================================

-- Confirm core Destruction spells are present
assert_true(strategy_names["ShadowBolt"], "ShadowBolt should be present")
assert_true(strategy_names["Immolate"], "Immolate should be present")
assert_true(strategy_names["Conflagrate"], "Conflagrate should be present")
assert_true(strategy_names["Incinerate"], "Incinerate should be present")
assert_true(strategy_names["Corruption"], "Corruption should be present")
assert_true(strategy_names["CurseOfAgony"], "CurseOfAgony should be present")
assert_true(strategy_names["Shadowburn"], "Shadowburn should be present")
assert_true(strategy_names["SearingPain"], "SearingPain should be present")
assert_true(strategy_names["LifeTap"], "LifeTap should be present")
assert_true(strategy_names["DeathCoil"], "DeathCoil should be present")
assert_true(strategy_names["RainOfFire"], "RainOfFire should be present")
assert_true(strategy_names["SeedOfCorruption"], "SeedOfCorruption should be present") -- features now implemented
 assert_true(strategy_names["ManaGem"], "ManaGem should be present - feature: auto-use mana items at threshold")
 assert_true(strategy_names["Soulshatter"], "Soulshatter should be present - feature: threat management")
 
 print("PASS test_destruction_mana_gem (gap audit: " .. #strategies .. " strategies present, ManaGem + Soulshatter implemented)")
