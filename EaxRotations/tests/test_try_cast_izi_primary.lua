-- test_try_cast_izi_primary.lua — Validate try_cast with IZI primary spell path.
-- WHAT:  mocks player, target, and spell book to verify cast success/failure paths through IZI wrapper.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   IZI is the primary casting abstraction; regressions affect every spec.
-- SAFETY: fully mocked spell objects; no real casting.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local core_casts = 0
local izi_casts = 0

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
    get_distance = function() return 30 end,
}

local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_distance = function() return 30 end,
}

_G.core = {
    time = function() return 100 end,
    game_time = function() return 100000 end,
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
        cast_target_spell = function(spell_id, tgt)
            core_casts = core_casts + 1
            return true
        end,
    },
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

NS.izi = {
    spell = function(spell_id)
        izi_casts = izi_casts + 1
        return nil
    end,
}

local result = NS.try_cast(686, target, "[TEST] fallback")

assert(result == false, "expected try_cast to fail-close when IZI returns nil (no raw fallback for unregistered spells)")
assert(core_casts == 0, "expected core.input.cast_target_spell to NOT fire when IZI returns nil (core_casts=" .. tostring(core_casts) .. ")")
assert(izi_casts == 1, "expected IZI spell() to be queried once (izi_casts=" .. tostring(izi_casts) .. ")")

print("PASS test_try_cast_izi_primary")
