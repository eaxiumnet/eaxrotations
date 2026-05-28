-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_gcd_duration_does_not_block.lua"
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
-- regression test for GCD duration vs GCD remaining.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local target = { is_alive = function() return true end, is_valid = function() return true end }
local player = {
    get_target = function() return target end,
    is_alive = function() return true end,
    is_valid = function() return true end,
    gcd_remains = function() return 0 end,
    get_power = function() return 1000 end,
}
local cooldown_info = { enabled = false, start_time = 0, duration = 10 }

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = { get_local_player = function() return player end, get_visible_objects = function() return {} end },
    spell_book = {
        is_spell_learned = function() return true end,
        get_global_cooldown = function() return 1.5 end,
        get_spell_cooldown = function() return 10 end,
        get_spell_cooldown_information = function() return cooldown_info end,
        get_spell_costs = function() return {} end,
        is_spell_in_range = function() return true end,
    },
    input = {},
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil
local NS = require("core_sylvanas")
local spell = NS.spell_action(686, "ShadowBolt")

assert(NS.get_global_cooldown() == 1.5, "duration API returns positive GCD")
assert(NS.gcd_remains() == 0, "remaining GCD is ready")
assert(NS.spell_ready(spell, target) == true, "base cooldown duration must not block readiness")

cooldown_info = { enabled = true, start_time = 0, duration = 10 }
assert(NS.cooldown_remains(spell) == 10, "active cooldown info should produce remaining time")
assert(NS.spell_ready(spell, target) == false, "active cooldown should block readiness")

print("PASS test_gcd_duration_does_not_block")
