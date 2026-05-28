-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_leveling_dispatcher_prepass.lua"
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
-- Regression: under-70 characters may select the Leveling playstyle, but an
-- explicit normal spec selection must remain authoritative.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_distance = function() return 20 end,
    is_in_melee_range = function() return false end,
    is_player = function() return false end,
    is_boss = function() return false end,
}

local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_in_combat = function() return true end,
    get_target = function() return target end,
    get_effective_level = function() return 30 end,
    get_level = function() return 30 end,
}

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    get_instance_type = function() return "none" end,
}

local leveling_fired = false
local spec_fired = false

_G.EaxRotations = {
    settings = { active_playstyle = "elemental", playstyle = "elemental" },  -- playstyle must be set to prevent auto-leveling override
    class_middleware = { shaman = {} },
    rotation_registry = {
        class_config = { class_key = "shaman", default_playstyle = "elemental" },
        playstyles = {
            leveling = {
                {
                    name = "LevelingTest",
                    execute = function(context)
                        leveling_fired = context.active_playstyle == "leveling"
                        return true
                    end,
                },
            },
            elemental = {
                {
                    name = "SpecTest",
                    execute = function()
                        spec_fired = true
                        return true
                    end,
                },
            },
        },
        options = {},
    },
    log = function() end,
    log_warning = function() end,
    get_setting = function(key, default)
        local v = _G.EaxRotations.settings[key]
        if v == nil then return default end
        return v
    end,
    set_setting = function(key, value) _G.EaxRotations.settings[key] = value end,
    GetPlayer = function() return player end,
    GetTarget = function() return target end,
    is_hostile_unit = function() return true end,
    safe_field = function(obj, key) return obj and obj[key] or nil end,
    time_now = function() return 0 end,
    game_time_ms = function() return 0 end,
    GetEnemiesInRange = function() return {} end,
    unit_health_pct = function() return 100 end,
    mana_pct = function() return 100 end,
    gcd_remains = function() return 0 end,
    power_current = function() return 0 end,
    POWER_RAGE = 1,
    POWER_ENERGY = 3,
    POWER_FOCUS = 2,
    buff_up = function() return false end,
    get_player_stance = function() return 0 end,
    is_pvp_zone = function() return false end,
    is_in_party = function() return false end,
}

package.loaded.main_sylvanas = nil
local dispatcher = require("main_sylvanas")

assert_true(dispatcher.on_rotation_update() == true, "dispatcher should fire an action")
assert_true(leveling_fired == false, "leveling should not override an explicit selected spec")
assert_true(spec_fired == true, "selected spec should run for under-70 player")	_G.EaxRotations.settings.playstyle = "leveling"
leveling_fired = false
spec_fired = false

assert_true(dispatcher.on_rotation_update() == true, "dispatcher should fire selected leveling")
assert_true(leveling_fired == true, "leveling should run when explicitly selected")
assert_true(spec_fired == false, "normal spec should not run when leveling is selected")

print("PASS test_leveling_dispatcher_prepass")
