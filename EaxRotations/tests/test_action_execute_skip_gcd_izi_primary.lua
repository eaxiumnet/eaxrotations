-- test_action_execute_skip_gcd_izi_primary.lua -- action execution execute skip-GCD skip-GCD GCD handling IZI primary tests.
-- WHAT:  action execution execute skip-GCD skip-GCD GCD handling IZI primary tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Regression: action_execute skip_gcd path should use IZI before stubbed core.input.

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
            cast_safe = function(_, unit)
                assert(spell_id == 686, "expected Shadow Bolt id")
                assert(unit == target, "expected selected target")
                izi_casts = izi_casts + 1
                return true
            end,
        }
    end,
}

local ok = NS.action_execute({
    target = target,
    has_valid_enemy_target = true,
}, {
    name = "ShadowBolt",
    spell = 686,
    skip_gcd = true,
}, "[TEST]")

assert(ok == true, "skip_gcd action should cast through IZI")
assert(izi_casts == 1, "IZI cast_safe should be called")
assert(core_casts == 0, "core.input.cast_target_spell should not be used when IZI succeeds")

print("PASS test_action_execute_skip_gcd_izi_primary")
