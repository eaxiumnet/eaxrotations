-- Readability notes:
--   What: regression test for legacy/capitalized playstyle settings.
--   When: saved settings contain a display label instead of the registry key.
--   Why: invalid active_playstyle values previously made the dispatcher run no list.
--   Safety: local API stub records casts only.

-- Decision notes:
--   Tests use local stubs instead of a live Sylvanas client so API-bound behavior remains reproducible.
--   Each case protects one previous failure mode or role rule; keep assertions narrow and descriptive.
--   No test should call real input/cast APIs because regression runs must be safe outside the game.
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
    has_buff = function(_, id) return id == 28189 or id == 28176 end,
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
require("classes/warlock/class_sylvanas")
NS.set_setting("active_playstyle", "Destruction")

local dispatcher = require("main_sylvanas")
assert(dispatcher.on_rotation_update() == true, "display-label playstyle should normalize to registry key")
assert(#casts > 0 and casts[1].unit == target, "cast should execute after playstyle normalization")

print("PASS test_playstyle_label_fallback_fires")
