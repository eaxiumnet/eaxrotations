-- test_range_false_fallback_allows_cast.lua — Validate range-check fallback behavior.
-- WHAT:  mocks units with/without get_distance to confirm that missing range info does not block casts.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   some units lack range data; a hard failure would freeze the rotation.
-- SAFETY: fully mocked; no real spell casting.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local izi_casts = 0
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
        cast_target_spell = function(spell_id, unit)
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

NS.izi = {
    spell = function(spell_id)
        return {
            is_castable_to_unit = function(_, unit, opts)
                return true, nil
            end,
            cast_safe = function(_, unit, reason)
                izi_casts = izi_casts + 1
                return true
            end,
        }
    end,
}

assert(NS.is_spell_in_range(686, target) == true, "false range API should fall back to 30-yard distance")

assert(NS.try_cast(686, target, "[TEST] Shadow Bolt") == true, "range fallback should allow cast")

assert(izi_casts == 1, "IZI cast_safe should be called when range fallback allows cast")

print("PASS test_range_false_fallback_allows_cast")
