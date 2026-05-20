-- smoke test for API-probe compatibility aliases.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_distance = function() return 20 end,
    get_buff_data = function(_, spec)
        if spec == 111 then return { is_active = false, remaining = 30000, stacks = 5 } end
        if spec == 222 then return { is_active = true, remaining = 4000, expire_time = 5250, stacks = 2 } end
        return nil
    end,
    get_debuff_data = function(_, spec)
        if spec == 333 then return { is_active = false, remaining = 30000, stacks = 5 } end
        if spec == 444 then return { is_active = true, remaining = 2500, stacks = 3 } end
        return nil
    end,
}

local player = {
    get_target = function() return target end,
    can_attack = function(_, unit) return unit == target end,
    is_alive = function() return true end,
    is_valid = function() return true end,
}

_G.core = {
    time = function() return 1.25 end,
    game_time = function() return 1250 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return { target } end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0 end,
        get_spell_cooldown = function() return 0 end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil
local NS = require("core_sylvanas")

assert(type(NS.CreateSpell) == "function", "CreateSpell alias")
assert(NS.GetTarget() == target, "GetTarget alias")
assert(type(NS.GetEnemiesInRange(40)) == "table", "GetEnemiesInRange alias")
assert(NS.GetEnemiesCount(40) == 1, "GetEnemiesCount alias")
assert(type(NS.GetFriendsInRange(40)) == "table", "GetFriendsInRange alias")
assert(type(NS.find_dead_party_ally) == "function", "find_dead_party_ally alias")
assert(NS.time_now() == 1.25, "time_now alias")
assert(type(NS.register_on_update_callback) == "function", "update callback wrapper")
assert(type(NS.register_on_spell_cast) == "function", "spell cast callback wrapper")
assert(type(NS.spell_id_is_known) == "function", "known spell helper")
assert(type(NS.spell_in_range) == "function", "range helper alias")
assert(type(NS.cooldown_remains) == "function", "cooldown remaining helper")
assert(NS.buff_up(target, 111) == false, "inactive buff_manager data should not count as active")
assert(NS.buff_up(target, 222) == true, "active buff_manager data should count as active")
assert(NS.buff_remains(target, 222) == 4, "buff_manager expire_time ms should be normalized to seconds")
assert(NS.debuff_up(target, 333) == false, "inactive debuff_manager data should not count as active")
assert(NS.debuff_remains(target, 444) == 2.5, "buff_manager remaining ms should be normalized to seconds")
assert(NS.unit_alive({ is_valid = function() return true end, is_alive = function() return false end }) == false, "is_alive=false should mark unit unavailable")

print("PASS test_runtime_compat_aliases")
