-- Feature audit for survival_sylvanas: Concussive Shot kiting + Misdirection.
-- These are documented gaps in the current implementation.
-- Documents which features exist vs are missing in the rotation.

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
 HunterSpells = {
  SteadyShot = 34120,
  ArcaneShot = 27019,
  MultiShot = 27021,
  SerpentSting = 27016,
  ViperSting = 30334,
  ScorpidSting = 27013,
  HuntersMark = 25283,
  KillCommand = 34026,
  RapidFire = 3045,
  Readiness = 34027,
  FeignDeath = 5384,
  ExplosiveTrap = 27025,
  FreezingTrap = 27027,
  AspectOfTheHawk = 27044,
  AspectOfTheViper = 34074,
  CallPet = 883,
  RevivePet = 982,
  MendPet = 27047,
  AutoShot = 75,
  RaptorStrike = 27015,
  WingClip = 27016,
  Volley = 27029,
  ConcussiveShot = 5116,
  Misdirection = 34477,
 },
 has_pet = function() return true end,
 log = function() end,
 rotation_registry = {
  register = function() end,
 },
}

local strategies = dofile("EaxRotations/classes/hunter/survival_sylvanas.lua")
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

-- Present features
assert_true(strategy_names["SteadyShot"], "SteadyShot should be present")
assert_true(strategy_names["ArcaneShot"], "ArcaneShot should be present")
assert_true(strategy_names["MultiShot"], "MultiShot should be present")
assert_true(strategy_names["SerpentSting"], "SerpentSting should be present")
assert_true(strategy_names["ViperSting"], "ViperSting should be present")
assert_true(strategy_names["HuntersMark"], "HuntersMark should be present")
assert_true(strategy_names["KillCommand"], "KillCommand should be present")
assert_true(strategy_names["RapidFire"], "RapidFire should be present")
assert_true(strategy_names["Readiness"], "Readiness should be present")
assert_true(strategy_names["FeignDeath"], "FeignDeath should be present")
assert_true(strategy_names["ExplosiveTrap"], "ExplosiveTrap should be present")
assert_true(strategy_names["FreezingTrap"], "FreezingTrap should be present")
assert_true(strategy_names["MendPet"], "MendPet should be present")
assert_true(strategy_names["CallPet"], "CallPet should be present")
assert_true(strategy_names["RevivePet"], "RevivePet should be present")	-- Previously missing features (now implemented)
	assert_true(strategy_names["ConcussiveShot"], "ConcussiveShot should be present - feature: kiting utility")
	assert_true(strategy_names["Misdirection"], "Misdirection should be present - feature: threat management")		-- Previously missing gaps (now implemented)
		assert_true(strategy_names["Volley"], "Volley should be present - feature: AoE")
		assert_true(strategy_names["ScorpidSting"], "ScorpidSting should be present - feature: debuff mode")
		assert_true(strategy_names["RaptorStrike"], "RaptorStrike should be present - feature: melee weaving")
		assert_true(strategy_names["WingClip"], "WingClip should be present - feature: slow")
		
		print("PASS test_survival_concussive_misdirection (gap audit: " .. #strategies .. " strategies present, 6 gaps closed)")

-- Print strategy inventory for reference
local sorted_names = {}
for name, _ in pairs(strategy_names) do
 sorted_names[#sorted_names + 1] = name
end
table.sort(sorted_names)
print(" Strategies present: " .. table.concat(sorted_names, ", "))
