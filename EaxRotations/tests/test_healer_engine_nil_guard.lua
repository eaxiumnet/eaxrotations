-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_healer_engine_nil_guard.lua"
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
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_equal(a, b, label) if a ~= b then error((label or "assert_equal failed") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local function live_unit(hp, dist)
    return {
        is_valid = function() return true end,
        is_alive = function() return true end,
        get_health_percentage = function() return hp or 100 end,
        get_distance = function() return dist or 20 end,
        get_guid = function() return tostring(hp or 100) .. ":" .. tostring(dist or 20) end,
    }
end

local dead_unit = {
    is_valid = function() return true end,
    is_alive = function() return false end,
    get_health_percentage = function() error("dead unit hp should not be read") end,
}

local invalid_throwing_unit = {
    is_valid = function() error("invalid unit API failed") end,
    is_alive = function() error("alive should not be called after invalid failure") end,
}

local self_unit = live_unit(70, 0)
local ally_unit = live_unit(55, 25)

_G.EaxRotations = {
    cancel_spells = function() error("zero-duration casts must not cancel") end,
}

_G.core = {
    time = function() return 10 end,
    spell_book = {
        get_spell_cooldown = function() return 0 end,
    },
    object_manager = {
        get_local_player = function() return self_unit end,
        get_enemy_list = function() return {} end,
        get_party_frames = function() return { dead_unit, invalid_throwing_unit, ally_unit } end,
    },
}

package.loaded["shared/healer_engine_sylvanas"] = nil
local engine = require("shared/healer_engine_sylvanas")

assert_false(engine.check_stopcast(ally_unit, 9, 0, 85), "zero cast_duration should not divide or cancel")
assert_false(engine.check_stopcast(ally_unit, 9, -1, 85), "negative cast_duration should not divide or cancel")
assert_false(engine.pre_heal(dead_unit, 2061, { mana_pct = 100 }, {}), "dead pre-heal target should be skipped")
assert_equal(engine.score_heal_target(nil), -999, "nil target should score as invalid")
assert_equal(engine.score_heal_target(invalid_throwing_unit), -999, "throwing invalid target should score as invalid")

local targets = engine.get_heal_targets(true, 40)
assert_equal(#targets, 2, "self plus one live ally should remain after nil/dead/invalid filtering")
assert_true(targets[1] == self_unit, "solo/self fallback should include self first")
assert_true(targets[2] == ally_unit, "valid live party ally should be included")

print("PASS test_healer_engine_nil_guard")
