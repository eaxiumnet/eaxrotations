-- test_tbc_consumable_data.lua — Validate TBC consumable item IDs and cooldown mappings.
-- WHAT:  reads tbc_data_sylvanas and checks that potions, healthstones, and buff foods have valid entries.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   stale item IDs cause silent consumable failures in combat.
-- SAFETY: pure data validation; no casting.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error((label or "assert_eq failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assert_true(value, label)
    if not value then error(label or "assert_true failed", 2) end
end

local TBC = require("shared/tbc_data_sylvanas")

assert_eq(TBC.ITEMS.potions.destruction, 22839, "Destruction Potion item ID")
assert_eq(TBC.ITEMS.potions.haste, 22838, "Haste Potion item ID")
assert_eq(TBC.ITEMS.potions.super_mana, 22832, "Super Mana Potion item ID")
assert_eq(TBC.ITEMS.potions.super_healing, 22829, "Super Healing Potion item ID")
assert_eq(TBC.ITEMS.potions.ironshield, 22849, "Ironshield Potion item ID")

assert_eq(TBC.ITEMS.flasks.relentless_assault, 22854, "Flask of Relentless Assault item ID")
assert_eq(TBC.ITEMS.flasks.blinding_light, 22861, "Flask of Blinding Light item ID")
assert_eq(TBC.ITEMS.flasks.pure_death, 22866, "Flask of Pure Death item ID")
assert_eq(TBC.ITEMS.flasks.mighty_restoration, 22853, "Flask of Mighty Restoration item ID")

assert_eq(TBC.ITEMS.food.spicy_hot_talbuk, 33872, "Spicy Hot Talbuk item ID")
assert_eq(TBC.ITEMS.food.grilled_mudfish, 27664, "Grilled Mudfish item ID")
assert_eq(TBC.ITEMS.food.golden_fish_sticks, 27666, "Golden Fish Sticks item ID")
assert_eq(TBC.ITEMS.food.skullfish_soup, 33825, "Skullfish Soup item ID")
assert_eq(TBC.ITEMS.food.blackened_sporefish, 27663, "Blackened Sporefish item ID")
assert_eq(TBC.ITEMS.food.roasted_clefthoof, 27658, "Roasted Clefthoof item ID")

assert_eq(TBC.ITEMS.weapon_buffs.superior_wizard_oil, 22522, "Superior Wizard Oil item ID")
assert_eq(TBC.ITEMS.weapon_buffs.adamantite_sharpening_stone, 23529, "Adamantite Sharpening Stone item ID")
assert_eq(TBC.WEAPON_ENCHANTS.superior_wizard_oil, 2678, "Superior Wizard Oil enchant ID")
assert_eq(TBC.WEAPON_ENCHANTS.adamantite_sharpening_stone, 2713, "Adamantite Sharpening Stone enchant ID")

local forbidden = {
    22864, -- Blood Guard's Leather Grips, not a flask.
    22865, -- Blood Guard's Dreadweave Handwraps, not a flask.
    28514, -- Bracers of Maliciousness, not Destruction Potion.
    28517, -- Boots of Foretelling, not Haste Potion.
    33834, -- quest item, not Spicy Hot Talbuk.
    33836, -- quest item, not Golden Fish Sticks.
    33837, -- Cooking Pot, not Blackened Sporefish.
}

local function table_has_value(root, value)
    if type(root) ~= "table" then return false end
    for _, v in pairs(root) do
        if v == value then return true end
        if type(v) == "table" and table_has_value(v, value) then return true end
    end
    return false
end

for i = 1, #forbidden do
    assert_true(not table_has_value(TBC.ITEMS, forbidden[i]), "forbidden non-consumable ID should not be in TBC.ITEMS: " .. tostring(forbidden[i]))
end

print("PASS test_tbc_consumable_data")
