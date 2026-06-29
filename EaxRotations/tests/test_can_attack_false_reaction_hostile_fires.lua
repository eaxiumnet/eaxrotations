-- test_can_attack_false_reaction_hostile_fires.lua — Validate reaction hostile triggers without can_attack.
-- WHAT:  mocks a unit with hostile reaction but can_attack=false (e.g., out of range).
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   some actions (dots, buffs) should still be considered when reaction is hostile.
-- SAFETY: fully mocked; no real unit interaction.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local casts = {}
local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_reaction = function() return 2 end,
    get_health_percentage = function() return 100 end,
    get_distance = function() return 30 end,
}

local player = {
    get_class = function() return 9 end,
    get_target = function() return target end,
    can_attack = function() return false end,
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
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
package.loaded["classes/warlock/class_sylvanas"] = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")
NS.has_player_buff = function() return true end
NS.buff_up = function(unit) return unit == player end
NS.is_hostile_unit = function() return true end

-- IZI mock so casts go through the API surface instead of raw fallback
NS.izi = {
    spell = function(spell_id)
        return {
            is_castable_to_unit = function(_, unit, opts)
                return true, nil
            end,
            cast_safe = function(_, unit, reason)
                if spell_id == 28610 then return false end
                casts[#casts + 1] = { spell_id = spell_id, unit = unit }
                return true
            end,
        }
    end,
}

require("classes/warlock/class_sylvanas")
NS.set_setting("playstyle", "destruction")

local dispatcher = require("main_sylvanas")
assert(dispatcher.on_rotation_update() == true, "hostile reaction should override stale can_attack=false")

local hit_target = false
for i = 1, #casts do
    if casts[i].unit == target then hit_target = true; break end
end
assert(hit_target, "at least one cast should use selected hostile reaction target")

print("PASS test_can_attack_false_reaction_hostile_fires")
