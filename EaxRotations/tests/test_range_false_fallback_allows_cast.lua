-- Regression: core.spell_book.is_spell_in_range=false may be a stub and must fall back to distance.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local casts = 0
local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
}

local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_distance = function() return 30 end,
    get_health_percentage = function() return 100 end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return false end,
    },
    input = {
        cast_target_spell = function(_, unit)
            if unit == target then casts = casts + 1 end
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")
assert(NS.is_spell_in_range(686, target) == true, "false range API should fall back to 30-yard distance")
assert(NS.try_cast(686, target, "[TEST] Shadow Bolt") == true, "range fallback should allow cast")
assert(casts == 1, "cast_target_spell should be called on target")

print("PASS test_range_false_fallback_allows_cast")
