-- test_spell_id_table.lua -- spell resolution ID table tests.
-- WHAT:  spell resolution ID table tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Unit tests for spell_id_table_sylvanas.lua
-- Validates expansion-aware spell ID resolution for swapped spells.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS for TBC
_G.EaxRotations = {
    is_vanilla = function() return false end,
    is_tbc = function() return true end,
}

local spell_table = dofile("EaxRotations/shared/spell_id_table_sylvanas.lua")
assert_true(spell_table, "spell_table should load")

-- ============================================================================
-- Test: is_swapped
-- ============================================================================
assert_true(spell_table.is_swapped("Death Wish"), "Death Wish should be swapped")
assert_true(spell_table.is_swapped("Sweeping Strikes"), "Sweeping Strikes should be swapped")
assert_true(spell_table.is_swapped("Cold Snap"), "Cold Snap should be swapped")
assert_true(spell_table.is_swapped("Arcane Missiles"), "Arcane Missiles should be swapped")
assert_true(spell_table.is_swapped("Icy Veins"), "Icy Veins should be swapped (ID reuse conflict)")
assert_false(spell_table.is_swapped("NonexistentSpell"), "Nonexistent spell should NOT be swapped")
-- Use Taunt as a non-swapped example (same ID in both expansions)
assert_false(spell_table.is_swapped("Taunt"), "Taunt should NOT be swapped (same ID in both)")

-- ============================================================================
-- Test: tbc_id / vanilla_id
-- ============================================================================
assert_eq(spell_table.tbc_id("Death Wish"), 12292, "Death Wish TBC ID")
assert_eq(spell_table.vanilla_id("Death Wish"), 12328, "Death Wish Vanilla ID")
assert_eq(spell_table.tbc_id("Sweeping Strikes"), 12328, "Sweeping Strikes TBC ID")
assert_eq(spell_table.vanilla_id("Sweeping Strikes"), 12292, "Sweeping Strikes Vanilla ID")
assert_eq(spell_table.tbc_id("Cold Snap"), 11958, "Cold Snap TBC ID")
assert_eq(spell_table.vanilla_id("Cold Snap"), 12472, "Cold Snap Vanilla ID")
assert_eq(spell_table.tbc_id("Arcane Missiles"), 8418, "Arcane Missiles TBC ID")
assert_eq(spell_table.vanilla_id("Arcane Missiles"), 8417, "Arcane Missiles Vanilla ID")
-- Icy Veins: TBC-only, ID reuse conflict with Vanilla Cold Snap
assert_eq(spell_table.tbc_id("Icy Veins"), 12472, "Icy Veins TBC ID")
assert_eq(spell_table.vanilla_id("Icy Veins"), nil, "Icy Veins has no Vanilla ID (TBC-only)")
assert_eq(spell_table.tbc_id("Nonexistent"), nil, "Nonexistent spell tbc_id returns nil")

-- ============================================================================
-- Test: resolve for TBC expansion
-- ============================================================================
spell_table._reset_expansion()
assert_eq(spell_table.resolve("Death Wish"), 12292, "TBC: Death Wish should resolve to 12292")
assert_eq(spell_table.resolve("Sweeping Strikes"), 12328, "TBC: Sweeping Strikes should resolve to 12328")
assert_eq(spell_table.resolve("Cold Snap"), 11958, "TBC: Cold Snap should resolve to 11958")
assert_eq(spell_table.resolve("Arcane Missiles"), 8418, "TBC: Arcane Missiles should resolve to 8418")
assert_eq(spell_table.resolve("Icy Veins"), 12472, "TBC: Icy Veins should resolve to 12472")

-- ============================================================================
-- Test: resolve for Vanilla expansion
-- ============================================================================
_G.EaxRotations.is_vanilla = function() return true end
_G.EaxRotations.is_tbc = function() return false end
spell_table._reset_expansion()

assert_eq(spell_table.resolve("Death Wish"), 12328, "Vanilla: Death Wish should resolve to 12328")
assert_eq(spell_table.resolve("Sweeping Strikes"), 12292, "Vanilla: Sweeping Strikes should resolve to 12292")
assert_eq(spell_table.resolve("Cold Snap"), 12472, "Vanilla: Cold Snap should resolve to 12472")
assert_eq(spell_table.resolve("Arcane Missiles"), 8417, "Vanilla: Arcane Missiles should resolve to 8417")
assert_eq(spell_table.resolve("Icy Veins"), nil, "Vanilla: Icy Veins should resolve to nil (TBC-only)")

-- ============================================================================
-- Test: resolve for non-swapped spell returns nil
-- ============================================================================
assert_eq(spell_table.resolve("Taunt"), nil, "Non-swapped spell (Taunt) should return nil")
assert_eq(spell_table.resolve("Nonexistent"), nil, "Nonexistent spell should return nil")

-- ============================================================================
-- Test: get_all_swapped returns sorted list
-- ============================================================================
local all = spell_table.get_all_swapped()
assert_true(#all > 0, "get_all_swapped should return entries")
assert_true(#all >= 5, "get_all_swapped should have at least 5 entries (got " .. #all .. ")")
-- Verify sorted
for i = 2, #all do
    assert_true(all[i-1] <= all[i], "get_all_swapped should be sorted: " .. all[i-1] .. " <= " .. all[i])
end

-- ============================================================================
-- Test: default expansion (no NS) defaults to TBC
-- ============================================================================
_G.EaxRotations = nil
spell_table._reset_expansion()
assert_eq(spell_table.resolve("Death Wish"), 12292, "No NS: should default to TBC (12292)")

print("PASS test_spell_id_table (all " .. #all .. " swapped spells verified)")
