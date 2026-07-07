-- Feature audit for elemental_sylvanas: Weapon buff auto-apply + missing totem management.
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
_G.EaxRotations = {
 ShamanSpells = {
  LightningBolt = 25449,
  ChainLightning = 27079,
  FlameShock = 25457,
  EarthShock = 25454,
  FrostShock = 25464,
  ElementalMastery = 16166,
  NaturesSwiftness = 17116,
  Bloodlust = 2825,
  LightningShield = 25472,
  WaterShield = 33707,
  GhostWolf = 2645,
  TremorTotem = 8143,
  EarthbindTotem = 2484,
  ManaTideTotem = 16190,
  ChainHeal = 25423,
  HealingWave = 25416,
  LesserHealingWave = 25418,
  FlametongueWeapon = 25489,
  WindfuryWeapon = 25505,
  RockbiterWeapon = 25485,
 },
 spell_action = function(spell_ids, name)
  return { spell = spell_ids, name = name }
 end,
 log = function() end,
 rotation_registry = {
  register = function() end,
 },
}

local strategies = dofile("EaxRotations/classes/shaman/elemental_sylvanas.lua").strategies
assert_true(strategies, "strategies table should load")

-- Collect strategy names for audit
local strategy_names = {}
if strategies and #strategies > 0 then
 assert_true(#strategies > 0, "strategies table should have entries")
 for i = 1, #strategies do
  strategy_names[strategies[i].name] = true
 end
end

-- ============================================================================
-- Feature Audit: Check which features exist vs missing
-- ============================================================================

-- Present features
assert_true(strategy_names["LightningBolt"], "LightningBolt should be present")
assert_true(strategy_names["ChainLightning"], "ChainLightning should be present")
assert_true(strategy_names["FlameShock"], "FlameShock should be present")
assert_false(strategy_names["EarthShock"], "EarthShock interrupt should NOT be in spec (handled by interrupt_manager middleware)")
assert_true(strategy_names["EarthShockMoving"], "EarthShockMoving (DPS filler) should be present")
assert_true(strategy_names["FrostShockMoving"], "FrostShockMoving should be present (named 'FrostShock')")
assert_true(strategy_names["ElementalMastery"], "ElementalMastery should be present")
assert_true(strategy_names["Bloodlust"], "Bloodlust should be present") -- features now implemented
 assert_true(strategy_names["FlametongueWeapon"], "FlametongueWeapon is now IMPLEMENTED")
 assert_true(strategy_names["WindfuryWeapon"], "WindfuryWeapon is now IMPLEMENTED")
 assert_true(strategy_names["RockbiterWeapon"], "RockbiterWeapon is now IMPLEMENTED")
 assert_true(strategy_names["HealingWave"], "HealingWave is now IMPLEMENTED")
 assert_true(strategy_names["TotemicCall"], "TotemicCall is now IMPLEMENTED")

 print("PASS test_elemental_weapon_buffs (gap audit: " .. #strategies .. " strategies present, 5 gaps closed)")
