-- Feature audit for restoration_sylvanas: Healing Way stacking + missing features.
-- Documents gaps compared to reference implementation.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
 assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
 assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
 assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
-- Mock core global (used by restoration_sylvanas.lua via core.time)
_G.core = {
 time = function() return 0 end,
 log = function() end,
 get_game_version = function() return "Tbc" end,
}

_G.EaxRotations = {
 ShamanSpells = {
  HealingWave = 25416,
  LesserHealingWave = 25418,
  ChainHeal = 25423,
  EarthShield = 32593,
  WaterShield = 33707,
  LightningShield = 25472,
  NaturesSwiftness = 17116,
  ManaTideTotem = 16190,
  TremorTotem = 8143,
  EarthbindTotem = 2484,
  Bloodlust = 2825,
  GhostWolf = 2645,
 },
 CLASS_ID = { SHAMAN = 7 },
 spell_action = function(spell_ids, name)
  return { spell = spell_ids, name = name }
 end,
 -- Return nil so healing_sylvanas.lua early-returns at its class check
 GetPlayer = function()
  return nil
 end,
 has_player_buff = function() return false end,
 debuff_remains = function() return 0 end,
 import_helpers = function(...) return function() end, function() end, function() end end,
 game_time_ms = function() return 0 end,
 is_in_raid = function() return false end,
 is_in_party = function() return false end,
 has_healing_reduction_debuff = function() return false end,
 build_healing_entries = function() return 0 end,
 healing_get_tank = function() return nil end,
 healing_get_lowest_hp = function() return nil end,
 healing_all_above_hp = function() return false end,
 healing_get_cleanse_target = function() return nil end,
 healing_count_below_hp = function() return 0 end,
 has_dispel_type_debuff = function() return false end,
 log = function() end,
 rotation_registry = {
  register = function() end,
 },
}

local result = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")
assert_true(result, "strategies table should load")
local strategies = result.strategies or result
assert_true(type(strategies) == "table", "strategies table exists")

-- Collect strategy names for audit
local strategy_names = {}
local count = 0
for k, v in pairs(strategies) do
 if type(v) == "table" and v.name then
  strategy_names[v.name] = true
  count = count + 1
 end
end

-- ============================================================================
-- Feature Audit: Check which features exist vs missing
-- ============================================================================	-- Present features (verify core abilities exist - using actual spec strategy names)
	assert_true(strategy_names["SmartHeal"], "SmartHeal should be present (handles ChainHeal/HealingWave selection)")
	assert_true(strategy_names["EarthShieldTank"], "EarthShieldTank should be present")
	assert_true(strategy_names["ManaTideTotem"], "ManaTideTotem should be present")
	assert_true(strategy_names["WaterShield"], "WaterShield should be present")
	assert_true(strategy_names["NaturesSwiftness"], "NaturesSwiftness should be present")		-- Present features (now implemented)
		assert_true(strategy_names["HealingWay"], "HealingWay should be present - feature: healing throughput buff tracking")
		assert_true(strategy_names["ChainHeal"], "ChainHeal should be present - feature: Chain Heal smart targeting")
	
	print("PASS test_restoration_healing_way (gap audit: " .. count .. " strategies present, 2 gaps closed)")
