-- test_update_callback_void_registration.lua — Validate safe registration when rotation module is nil.
-- WHAT:  mocks a missing spec module and confirms the callback registers a no-op instead of crashing.
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   missing modules should degrade gracefully, not error on every frame.
-- SAFETY: fully mocked registry and callback; no casting.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local runner_lib = require("tests/test_runner_lib")

local now = 0
local engine_callback = nil

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
}

_G.core = {
    time = function() return now end,
    game_time = function() return now * 1000 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    register_on_update_callback = function(callback)
        engine_callback = callback
    end,
    object_manager = {
        get_local_player = function() return player end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 0 end,
        get_spell_cooldown = function() return 0 end,
    },
    input = {},
}

runner_lib.clear_loaded({
    "core_sylvanas",
    "shared/racial_manager_sylvanas",
    "shared/trinket_manager_sylvanas",
})
_G.EaxRotations = nil

package.preload["shared/racial_manager_sylvanas"] = function()
    return { register_racial_manager = function() end }
end
package.preload["shared/trinket_manager_sylvanas"] = function()
    return { register_trinket_manager = function() end }
end

local NS = require("core_sylvanas")

local calls = 0
local registered = NS.register_on_update_callback(function()
    calls = calls + 1
end)

assert(registered == true, "void engine registration should be treated as success")
assert(type(engine_callback) == "function", "engine update callback should be registered")

engine_callback()
engine_callback()
engine_callback()

assert(calls == 1, "shared callback should run after dispatcher throttle")

print("PASS test_update_callback_void_registration")
