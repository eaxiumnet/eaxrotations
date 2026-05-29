-- regression tests for equipped-item and set-bonus helper APIs.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local item_object = {
    get_item_id = function() return 29996 end,
}

local equipment = {
    [13] = { item_id = 28789 },
    [14] = { entry = 29383 },
    [17] = { object = item_object },
}

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_item_at_inventory_slot = function(_, slot) return equipment[slot] end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {},
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded.gear_sets_sylvanas = nil
_G.EaxRotations = nil
local NS = require("core_sylvanas")
local GearSets = require("gear_sets_sylvanas")

assert(NS.get_equipped_item_id(13) == 28789, "slot item_id shape")
assert(NS.get_equipped_item_id(14) == 29383, "slot entry shape")
assert(NS.get_equipped_item_id(17) == 29996, "slot object shape")
assert(NS.is_item_equipped(28789) == true, "single equipped item")
assert(NS.is_item_equipped({ 1, 29383 }) == true, "array equipped item")
assert(NS.count_equipped_set({ 28789, 29383, 29996, 1 }) == 3, "set count")
assert(NS.has_set_bonus({ 28789, 29383, 29996 }, 2) == true, "2-piece bonus")
assert(NS.has_set_bonus({ 28789, 29383, 29996 }, 4) == false, "missing 4-piece bonus")

local ids, count = NS.get_equipped_item_ids({})
assert(count == 3, "equipped item count")
assert(ids[1] == 28789 and ids[2] == 29383 and ids[3] == 29996, "equipped item ordering")

local skyshatter = GearSets.get("SKYSHATTER_HARNESS")
assert(skyshatter and skyshatter.id == 682, "Skyshatter Harness registry lookup")
assert(#skyshatter.items == 8, "Skyshatter Harness has 8 item IDs")
assert(skyshatter.items[1] == 31018 and skyshatter.items[8] == 34545, "Skyshatter Harness item IDs")

local malorne = GearSets.get(639)
assert(malorne and malorne.key == "MALORNE_REGALIA", "Malorne Regalia ID lookup")
assert(#malorne.items == 5, "Malorne Regalia has 5 item IDs")
local bonus_ids, bonus_count = GearSets.get_bonus_spell_ids("MALORNE_REGALIA", 4, {})
assert(bonus_count == 1 and bonus_ids[1] == 37297, "Malorne Regalia 4-piece spell ID")

equipment[1] = { item_id = 29093 }
equipment[3] = { item_id = 29095 }
assert(GearSets.count_equipped("MALORNE_REGALIA") == 2, "gear set equipped count")
assert(GearSets.has_bonus("MALORNE_REGALIA", 2) == true, "gear set 2-piece active")
assert(GearSets.has_bonus("MALORNE_REGALIA", 4) == false, "gear set 4-piece inactive")

local active, active_count = GearSets.get_active_bonuses("MALORNE_REGALIA", {})
assert(active_count == 1 and active[1].spell == 37295, "active set bonus list")

assert(NS.TBCGearSets == GearSets, "gear registry exported on namespace")
assert(NS.has_tbc_set_bonus("MALORNE_REGALIA", 2) == true, "namespace set bonus helper")

print("PASS test_gear_helpers")
