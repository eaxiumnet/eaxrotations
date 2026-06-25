-- What: Unit tests for EaxAutoQuester/equipment_compare_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify slot classification and equipment upgrade heuristic
-- Scenarios: S1 empty, S2 upgrade, S3 downgrade, S4 type mismatch, S5 keyword bonus, S6 classifier names
-- Safety: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local ok, eq = pcall(require, "EaxAutoQuester/equipment_compare_sylvanas")
assert(ok, "equipment_compare_sylvanas module must load without error")
assert(eq ~= nil, "module must return a value")
assert(type(eq.classify_slot) == "function", "classify_slot must be a function")
assert(type(eq.should_equip) == "function", "should_equip must be a function")

-- ============================================================================
-- S6: Classifier Sanity
-- ============================================================================

assert(eq.classify_slot("Hood of the Whelpling") == "HEAD",
    "classify_slot 'Hood of the Whelpling' → HEAD")
assert(eq.classify_slot("Bracers of the Bear") == "WRIST",
    "classify_slot 'Bracers of the Bear' → WRIST")
assert(eq.classify_slot("Battle Axe") == "WEAPON_MAIN",
    "classify_slot 'Battle Axe' → WEAPON_MAIN")
assert(eq.classify_slot("Cured Leather Tunic") == "CHEST",
    "classify_slot 'Cured Leather Tunic' → CHEST")
assert(eq.classify_slot("Worn Sword") == "WEAPON_MAIN",
    "classify_slot 'Worn Sword' → WEAPON_MAIN")
assert(eq.classify_slot("Knight's Gauntlets") == "HANDS",
    "classify_slot \"Knight's Gauntlets\" → HANDS")
assert(eq.classify_slot("Pauldrons of Might") == "SHOULDERS",
    "classify_slot 'Pauldrons of Might' → SHOULDERS")
assert(eq.classify_slot("Leggings of the Fang") == "LEGS",
    "classify_slot 'Leggings of the Fang' → LEGS")
assert(eq.classify_slot("Old Blunderbuss") == "RANGED",
    "classify_slot 'Old Blunderbuss' → RANGED")
assert(eq.classify_slot("Wooden Shield") == "WEAPON_OFF",
    "classify_slot 'Wooden Shield' → WEAPON_OFF")

-- ============================================================================
-- S1: Empty equipped list — should equip, no slot to replace
-- ============================================================================

local equip, slot = eq.should_equip("Superior Tunic", 3, {})
assert(equip == true, "S1: empty equipped → should_equip=true")
assert(slot == nil, "S1: empty equipped → slot_to_replace=nil")

-- ============================================================================
-- S2: Upgrade same type (quality higher)
-- Equipped: "Tunic of the Bear" (Common, q=2, CHEST)
-- Candidate: "Superior Tunic" (Uncommon, q=3, CHEST)
-- ============================================================================

local equipped_s2 = {
    { slot = "CHEST", name = "Tunic of the Bear", quality = 2 },
}
equip, slot = eq.should_equip("Superior Tunic", 3, equipped_s2)
assert(equip == true, "S2: upgrade same type → should_equip=true")
assert(slot == "CHEST", "S2: upgrade same type → slot_to_replace=CHEST, got " .. tostring(slot))

-- ============================================================================
-- S3: Downgrade same type (quality lower)
-- Equipped: "Cured Leather Tunic" (Uncommon, q=3, CHEST)
-- Candidate: "Cheap Cloth Tunic" (Common, q=1, CHEST)
-- ============================================================================

local equipped_s3 = {
    { slot = "CHEST", name = "Cured Leather Tunic", quality = 3 },
}
equip, slot = eq.should_equip("Cheap Cloth Tunic", 1, equipped_s3)
assert(equip == false, "S3: downgrade same type → should_equip=false")

-- ============================================================================
-- S4: Different types — candidate slot (CHEST) not in equipped list
-- Equipped: "Worn Sword" (Common, q=2, WEAPON_MAIN)
-- Candidate: "Haste Cloth Robe" (Rare, q=4, CHEST) — no CHEST in equipped
-- Result: empty CHEST slot → equip without replacement
-- ============================================================================

local equipped_s4 = {
    { slot = "WEAPON_MAIN", name = "Worn Sword", quality = 2 },
}
equip, slot = eq.should_equip("Haste Cloth Robe", 4, equipped_s4)
assert(equip == true, "S4: no CHEST in equipped → should_equip=true")
assert(slot == nil, "S4: no CHEST in equipped → slot_to_replace=nil")

-- ============================================================================
-- S5: Keyword bonus — "Knight" in name triggers equip even at same quality
-- Equipped: "Cured Leather Gloves" (Uncommon, q=3, HANDS)
-- Candidate: "Knight's Gauntlets" (Uncommon, q=3, HANDS)
-- ============================================================================

local equipped_s5 = {
    { slot = "HANDS", name = "Cured Leather Gloves", quality = 3 },
}
equip, slot = eq.should_equip("Knight's Gauntlets", 3, equipped_s5)
assert(equip == true, "S5: keyword bonus (Knight) → should_equip=true")
assert(slot == "HANDS", "S5: keyword bonus → slot_to_replace=HANDS, got " .. tostring(slot))

-- ============================================================================
-- S5b: Same quality without keyword bonus → no equip
-- ============================================================================

equip, slot = eq.should_equip("Simple Cloth Gloves", 3, equipped_s5)
assert(equip == false, "S5b: same quality no keyword → should_equip=false")

-- ============================================================================
-- S5c: Keyword bonus on higher quality → still works (quality > bonus case)
-- Equipped: "Cured Leather Gloves" (Common, q=2, HANDS)
-- Candidate: "Knight's Gauntlets" (Uncommon, q=3, HANDS)
-- ============================================================================

local equipped_s5c = {
    { slot = "HANDS", name = "Cured Leather Gloves", quality = 2 },
}
equip, slot = eq.should_equip("Knight's Gauntlets", 3, equipped_s5c)
assert(equip == true, "S5c: higher quality + keyword → should_equip=true")
assert(slot == "HANDS", "S5c: higher quality + keyword → slot_to_replace=HANDS")

-- ============================================================================
-- S7: Nil-guard — nil name or quality returns false
-- ============================================================================

equip, slot = eq.should_equip(nil, 3, {})
assert(equip == false, "S7: nil name → false")

equip, slot = eq.should_equip("Superior Tunic", nil, {})
assert(equip == false, "S7: nil quality → false")

equip, slot = eq.should_equip("Superior Tunic", 3, nil)
assert(equip == false, "S7: nil equipped list → false")

-- ============================================================================
-- S8: Empty slot for that type (other slots equipped)
-- Equipped: legs item, candidate is chest piece
-- ============================================================================

local equipped_s8 = {
    { slot = "LEGS", name = "Leggings of the Bear", quality = 2 },
}
equip, slot = eq.should_equip("Superior Tunic", 3, equipped_s8)
assert(equip == true, "S8: candidate slot empty in equipped list → should_equip=true")
assert(slot == nil, "S8: candidate slot empty → slot_to_replace=nil")

-- ============================================================================
-- S9: Unclassified item name → should not crash, returns false
-- Names without any slot keyword (no helm/cap/robe/boot etc.)
-- ============================================================================

equip, slot = eq.should_equip("Crushed Soulspinner", 5, {})
assert(equip == false, "S9: unclassified name → false")

print("PASS test_auto_equip")
os.exit(0)
