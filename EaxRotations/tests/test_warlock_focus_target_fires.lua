-- regression test for Warlock focus-target rotation startup.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local casts = {}
local focus_target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_enemy_with = function() return true end,
    get_health_percentage = function() return 100 end,
    get_distance = function() return 30 end,
}

local fake_pet = { is_alive = function() return true end, is_valid = function() return true end }
local player = {
    get_class = function() return 9 end,
    get_target = function() return nil end,
    can_attack = function(_, unit) return unit == focus_target end,
    is_in_combat = function() return true end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    gcd_remains = function() return 0 end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
    has_buff = function() return true end,
    get_pet = function() return fake_pet end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_focus = function() return focus_target end,
        get_visible_objects = function() return { focus_target } end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0, 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {
        get_focus = function() return {} end,
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
NS.buff_up = function(unit) return unit == player end
require("classes/warlock/class_sylvanas")
NS.set_setting("active_playstyle", "destruction")

local dispatcher = require("main_sylvanas")
-- Call multiple times: self-buff strategies may fire first; we need an offensive cast at focus_target
local hit_focus = false
for attempt = 1, 20 do
    local result = dispatcher.on_rotation_update()
    if not result then break end
    for i = 1, #casts do
        if casts[i].unit == focus_target then hit_focus = true; break end
    end
    if hit_focus then break end
end
assert(hit_focus, "cast should be issued at focused hostile target")

print("PASS test_warlock_focus_target_fires")
