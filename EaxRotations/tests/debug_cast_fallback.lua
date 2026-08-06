-- debug_cast_fallback.lua—Diagnostic script for cast fallback path tracing.
-- WHAT: mocks player/target and logs which casting path (core.input vs IZI) is taken.
-- WHEN: run manually during debugging; not part of CI suite.
-- WHY: helps trace why a spell that should cast is being skipped in production.
-- SAFETY: fully mocked; outputs logs only; no real casting.

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
 log = function(...) print("LOG:", ...) end,
 log_warning = function(...) end,
 log_error = function(...) end,
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
 print("RAW CAST called with id=", spell_id)
 return true
 end,
 },
}

-- Ensure EVERYTHING is pristine
package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

print("DEBUG: _G.core.input.cast_target_spell before require =", tostring(_G.core.input.cast_target_spell))

local NS = require("core_sylvanas")

print("DEBUG: NS.try_cast type =", type(NS.try_cast))
print("DEBUG: NS.izi =", tostring(NS.izi))

NS.izi = {
 spell = function(spell_id)
 print("IZI.spell called for", spell_id)
 return nil
 end,
}

print("DEBUG about to call try_cast with IZI nil")
print("DEBUG core_casts before =", core_casts)

local ok, result = pcall(function()
 return NS.try_cast(686, target, "[TEST] fallback")
end)

print("DEBUG pcall ok =", ok, "result =", result)
print("DEBUG core_casts after =", core_casts)

if not ok then
 print("ERROR:", result)
end

if core_casts > 0 then
 print("CONFIRMED BUG: try_cast used raw core.input.cast_target_spell when IZI is unavailable")
else
 print("NO BUG: raw core.input.cast_target_spell was NOT used")
end
