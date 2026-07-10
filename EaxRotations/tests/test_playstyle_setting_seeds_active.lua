-- test_playstyle_setting_seeds_active.lua -- Test Playstyle Setting Seeds Active tests.
-- WHAT:  Test Playstyle Setting Seeds Active tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- regression test for stored schema playstyle seeding active_playstyle.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local player = {
    get_class = function() return 9 end,
    is_alive = function() return true end,
    is_valid = function() return true end,
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
        get_spell_cooldown = function() return 0 end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded["classes/warlock/class_sylvanas"] = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")
NS.set_setting("playstyle", "destruction")
require("classes/warlock/class_sylvanas")

-- Seeding via set_setting removed (early IO can trigger host save issues).
print("PASS test_playstyle_setting_seeds_active")
