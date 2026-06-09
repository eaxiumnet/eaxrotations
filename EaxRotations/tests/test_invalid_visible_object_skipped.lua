-- regression test for stale game objects in the visible object list.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local casts = {}
local bad_object = setmetatable({}, {
    __index = function()
        error("Invalid game object!")
    end,
})
local stale_checks = 0
local stale_object = {
    is_unit = function() return true end,
    is_valid = function()
        stale_checks = stale_checks + 1
        if stale_checks > 1 then error("Invalid game object!") end
        return true
    end,
    is_dead = function() return false end,
    is_ghost = function() return false end,
}

local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_distance = function() return 30 end,
}

local player = {
    get_class = function() return 9 end,
    get_target = function() return target end,
    can_attack = function(_, unit) return unit == target end,
    is_in_combat = function() return false end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    gcd_remains = function() return 0 end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return { bad_object, stale_object, target } end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 1.5 end,
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
NS.is_hostile_unit = function(me, target) return target ~= nil end
require("classes/warlock/class_sylvanas")
NS.set_setting("active_playstyle", "destruction")

local dispatcher = require("main_sylvanas")
assert(dispatcher.on_rotation_update() == true, "rotation should skip invalid visible object and cast")
assert(#casts > 0, "cast should still be issued")

print("PASS test_invalid_visible_object_skipped")
