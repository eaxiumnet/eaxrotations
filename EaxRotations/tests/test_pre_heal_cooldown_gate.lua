-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_pre_heal_cooldown_gate.lua"
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
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local cooldown_value = 0
local cast_calls = {}

_G.core = {
    time = function() return 100 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function()
            return {
                is_alive = function() return true end,
                is_valid = function() return true end,
                get_health_percentage = function() return 100 end,
                is_in_combat = function() return true end,
                is_casting = function() return false end,
            }
        end,
    },
    spell_book = {
        get_spell_cooldown = function(id)
            return cooldown_value
        end,
    },
    input = {
        cast_target_spell = function(spell_id, target)
            cast_calls[#cast_calls + 1] = { spell_id = spell_id, target = target }
            return true
        end,
    },
}

_G.EaxRotations = {}

local mock_target = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    get_health_percentage = function() return 70 end,
    get_guid = function() return "mock-guid-1" end,
}

package.loaded["shared/healer_engine_sylvanas"] = nil
local healer = require("shared/healer_engine_sylvanas")

local ctx = { mana_pct = 80, in_combat = true, incoming_dps = 100 }

cooldown_value = 5
cast_calls = {}
healer.reset_preheal()
local result_on_cd = healer.pre_heal(mock_target, 2060, ctx)

assert_true(result_on_cd == false, "pre_heal must return false when spell is on cooldown (cd=" .. tostring(cooldown_value) .. "); actual=" .. tostring(result_on_cd))
assert_eq(#cast_calls, 0, "pre_heal must never call cast_target_spell")

cooldown_value = 0
cast_calls = {}
healer.reset_preheal()
local result_ready = healer.pre_heal(mock_target, 2060, ctx)

assert_true(type(result_ready) == "table", "pre_heal must return an intent table when spell is ready; actual=" .. tostring(result_ready))
assert_eq(result_ready.spell_id, 2060, "intent.spell_id must be the requested spell")
assert_eq(result_ready.target, mock_target, "intent.target must be the passed target")
assert_eq(#cast_calls, 0, "pre_heal must never call cast_target_spell directly")

cooldown_value = nil
cast_calls = {}
healer.reset_preheal()
local result_nil_cd = healer.pre_heal(mock_target, 2060, ctx)

assert_true(result_nil_cd == false, "pre_heal must return false when get_spell_cooldown returns nil (unknown state); actual=" .. tostring(result_nil_cd))
assert_eq(#cast_calls, 0, "pre_heal must never call cast_target_spell")

cooldown_value = 0
cast_calls = {}
healer.reset_preheal()
local low_mana_result = healer.pre_heal(mock_target, 2060, { mana_pct = 10, in_combat = true, incoming_dps = 100 })

assert_true(low_mana_result == false, "pre_heal must return false when mana is below floor")
assert_eq(#cast_calls, 0, "pre_heal must never call cast_target_spell")

print("PASS test_pre_heal_cooldown_gate")
