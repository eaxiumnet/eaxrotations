-- Regression: try_cast should use IZI cast_safe before stubbed core.input.cast_target_spell.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local now = 0
local izi_casts = 0
local core_casts = 0

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
        is_spell_in_range = function() return false end,
    },
    input = {
        cast_target_spell = function()
            core_casts = core_casts + 1
            return false
        end,
    },
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")
NS.izi = {
    spell = function(spell_id)
        return {
            cast_safe = function(_, unit, reason)
                assert(spell_id == 686, "expected Shadow Bolt id")
                assert(unit == target, "expected selected target")
                assert(reason == "[TEST] Shadow Bolt", "expected reason to pass through")
                izi_casts = izi_casts + 1
                return true
            end,
        }
    end,
}

assert(NS.try_cast(686, target, "[TEST] Shadow Bolt") == true, "IZI cast_safe should make try_cast succeed")
assert(izi_casts == 1, "IZI cast_safe should be called")
assert(core_casts == 0, "core.input.cast_target_spell should not be used when IZI succeeds")

print("PASS test_try_cast_izi_primary")
