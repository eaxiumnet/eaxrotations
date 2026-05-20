-- regression test for legacy/capitalized playstyle settings.

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
    is_in_combat = function() return false end,
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
            -- Silently drop Shadow Ward self-buff; middleware casts it before
            -- spec-level damaging spells can fire, consuming the rotation tick.
            if spell_id == 28610 then return false end
            casts[#casts + 1] = { spell_id = spell_id, unit = unit }
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
package.loaded["classes/warlock/class_sylvanas"] = nil
_G.EaxRotations = nil	local NS = require("core_sylvanas")
	NS.has_player_buff = function() return true end  -- suppress Phase 1 middleware self-buffs
	NS.buff_up = function() return true end  -- suppress spec-level Shadow Ward (uses NS.buff_up, not has_buff)
	NS.is_hostile_unit = function() return true end  -- required for valid_enemy check in dispatcher
require("classes/warlock/class_sylvanas")	NS.set_setting("playstyle", "Destruction")

local dispatcher = require("main_sylvanas")
assert(dispatcher.on_rotation_update() == true, "display-label playstyle should normalize to registry key")
-- Middleware may fire self-buffs first; at least one damaging cast must hit the target
local hit_target = false
for i = 1, #casts do
    if casts[i].unit == target then hit_target = true; break end
end
assert(hit_target, "at least one cast should execute after playstyle normalization")

print("PASS test_playstyle_label_fallback_fires")
