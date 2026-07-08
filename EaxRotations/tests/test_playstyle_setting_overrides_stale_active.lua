-- test_playstyle_setting_overrides_stale_active.lua -- Test Playstyle Setting Overrides Stale Active tests.
-- WHAT:  Test Playstyle Setting Overrides Stale Active tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- regression test for schema playstyle overriding stale active_playstyle at dispatch.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local casts = {}
local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_enemy_with = function() return true end,
    get_health_percentage = function() return 100 end,
    get_distance = function() return 30 end,
}

local player = {
    get_class = function() return 9 end,
    get_target = function() return target end,
    can_attack = function(_, unit) return unit == target end,
    is_in_combat = function() return true end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    gcd_remains = function() return 0 end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
    has_buff = function() return true end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return { target } end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0, 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {
        cast_target_spell = function(spell_id, unit)
            casts[#casts + 1] = { spell_id = spell_id, unit = unit }
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
package.loaded["classes/warlock/class_sylvanas"] = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")
NS.has_player_buff = function() return true end
NS.buff_up = function() return true end
require("classes/warlock/class_sylvanas")
NS.set_setting("active_playstyle", "affliction")
NS.set_setting("playstyle", "destruction")

local dispatcher = require("main_sylvanas")
assert(dispatcher.on_rotation_update() == true, "schema playstyle should override stale active_playstyle")
assert(NS.get_setting("active_playstyle") == "destruction", "dispatcher should normalize active_playstyle to schema playstyle")
assert(#casts > 0, "destruction dispatch should cast")

print("PASS test_playstyle_setting_overrides_stale_active")
