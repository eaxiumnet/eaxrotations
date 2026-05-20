-- regression test for Warlock casting through nearby-enemy fallback.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local casts = {}
local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_enemy_with = function() return true end,
    get_health_percentage = function() return 100 end,
    distance_to = function() return 28 end,
}

local player = {
    get_class = function() return 9 end,
    get_target = function() return nil end,
    get_enemies_in_range = function() return { target } end,
    can_attack = function() return false end,
    is_enemy_with = function() return false end,
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
        get_visible_objects = function() return {} end,
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
NS.has_player_buff = function() return true end  -- suppress Phase 1 middleware self-buffs
NS.buff_up = function() return true end  -- suppress spec-level Shadow Ward
NS.izi = { target = function() return nil end, ts = function() return nil end }
require("classes/warlock/class_sylvanas")
NS.set_setting("active_playstyle", "destruction")

local dispatcher = require("main_sylvanas")
-- Auto-targeting was removed: dispatcher should NOT fire damaging spells at
-- enemies when player has no selected target. Self-buffs from middleware are OK.
local _ = dispatcher.on_rotation_update()
-- Check no damaging cast went to the nearby enemy
local hit_enemy = false
for i = 1, #casts do
    if casts[i].unit == target then hit_enemy = true; break end
end
assert(not hit_enemy, "no damaging casts should target enemies without a selected target")
-- Self-buff middleware casts are acceptable even without a target

print("PASS test_warlock_enemy_scan_fallback_fires")
