-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_combat_state_unknown_no_ooc.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Regression: unknown combat state must not be collapsed to OOC.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local combat_value = nil
local ooc_called = false
local middleware_calls = 0

local player = {
    get_class = function() return 9 end,
    get_target = function() return nil end,
    is_in_combat = function() return combat_value end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
}

_G.core = {
    time = function() return 10 end,
    game_time = function() return 10000 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 1.5 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
package.loaded.main_sylvanas = nil
package.loaded["shared/ooc_manager_sylvanas"] = {
    on_update = function()
        ooc_called = true
        return true
    end,
}
_G.EaxRotations = nil	local NS = require("core_sylvanas")
	NS.is_hostile_unit = function() return true end  -- required for valid_enemy check in dispatcher
	NS.rotation_registry:set_class_config({
	    class_key = "warlock",
	    default_playstyle = "destruction",
	    playstyles = { "destruction" },
	})
	NS.rotation_registry:register("destruction", {}, {})
NS.register_class_middleware("warlock", {
    {
        name = "CombatStateProbe",
        execute = function(context)
            if context.in_combat then
                middleware_calls = middleware_calls + 1
                return true
            end
            return false
        end,
    },
})

local dispatcher = require("main_sylvanas")

combat_value = nil
assert(dispatcher.on_rotation_update() == false, "unknown combat state with no target should not run combat rotation")
assert(ooc_called == false, "unknown combat state with no target should not run OOC manager")

combat_value = true
assert(dispatcher.on_rotation_update() == true, "known combat state should run middleware")

combat_value = nil
assert(dispatcher.on_rotation_update() == true, "unknown combat state should retain previous combat state")
assert(middleware_calls == 2, "middleware should run for known combat and retained combat")

print("PASS test_combat_state_unknown_no_ooc")
