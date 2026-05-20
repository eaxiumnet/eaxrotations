-- Regression: try_cast must not globally lock every spell for 5 seconds.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local now = 0
local casts = 0

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
}

_G.core = {
    time = function() return now end,
    game_time = function() return now * 1000 end,
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
        is_spell_in_range = function() return true end,
    },
    input = {
        cast_target_spell = function()
            casts = casts + 1
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

assert(NS.try_cast(172, player, "[TEST] Corruption", { skip_range = true }) == true, "first cast should fire")
now = 2
assert(NS.try_cast(172, player, "[TEST] Corruption", { skip_range = true }) == true, "same spell should not be blocked for 5 seconds")
assert(casts == 2, "cast_target_spell should be called twice")

print("PASS test_try_cast_no_global_5s_lockout")
