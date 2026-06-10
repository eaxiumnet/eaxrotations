package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local now = 0
local core_casts = 0
local seen = nil

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

local spell_helper = {}
function spell_helper:is_spell_castable(spell_id, caster, cast_target, skip_facing, skip_range)
    seen = {
        spell_id = spell_id,
        caster = caster,
        target = cast_target,
        skip_facing = skip_facing,
        skip_range = skip_range,
    }
    return spell_id == 686
        and caster == player
        and cast_target == target
        and type(skip_facing) == "boolean"
        and type(skip_range) == "boolean"
end

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
        get_spell_cooldown_information = function() return nil end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {
        cast_target_spell = function(spell_id, unit)
            assert(spell_id == 686, "expected Shadow Bolt spell id")
            assert(unit == target, "expected selected target")
            core_casts = core_casts + 1
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
package.loaded["common/utility/spell_helper"] = nil
package.loaded["shared/racial_manager_sylvanas"] = nil
package.loaded["shared/trinket_manager_sylvanas"] = nil
_G.EaxRotations = nil

package.preload["common/utility/spell_helper"] = function() return spell_helper end
package.preload["shared/racial_manager_sylvanas"] = function()
    return { register_racial_manager = function() end }
end
package.preload["shared/trinket_manager_sylvanas"] = function()
    return { register_trinket_manager = function() end }
end

local NS = require("core_sylvanas")

assert(NS.try_cast(686, target, "[TEST] Shadow Bolt") == true, "try_cast should pass native spell_helper with player caster and target")
assert(core_casts == 1, "core.input fallback should cast once after spell_helper allows it")
assert(seen and seen.caster == player, "spell_helper caster argument should be the player")
assert(seen and seen.target == target, "spell_helper target argument should be the selected target")
assert(type(seen.skip_facing) == "boolean", "spell_helper skip_facing should be a boolean")
assert(type(seen.skip_range) == "boolean", "spell_helper skip_range should be a boolean")

print("PASS test_spell_helper_castable_signature")
