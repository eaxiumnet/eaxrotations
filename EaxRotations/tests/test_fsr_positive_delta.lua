-- test_fsr_positive_delta.lua — Verify FSR manager correctly recommends pause when regen delta is positive.
-- WHAT:  Mocks core.spell_book regen APIs to simulate positive FSR delta.
-- WHEN:  Run as part of rotation test suite.
-- WHY:   Oracle identified FSR positive-delta path was untested.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local mock_time = 1000
_G.EaxRotations = _G.EaxRotations or {}
_G.EaxRotations.time_now = function() return mock_time end
_G.core = _G.core or {}
_G.core.spell_book = _G.core.spell_book or {}

local _orig_get_base = nil
local _orig_get_casting = nil

local function setup_mock()
    _orig_get_base = core.spell_book.get_base_power_regen
    _orig_get_casting = core.spell_book.get_casting_power_regen
    core.spell_book.get_base_power_regen = function() return 100 end
    core.spell_book.get_casting_power_regen = function() return 20 end
end

local function teardown_mock()
    core.spell_book.get_base_power_regen = _orig_get_base
    core.spell_book.get_casting_power_regen = _orig_get_casting
end

package.loaded["shared/fsr_manager_sylvanas"] = nil
local FsrManager = require("shared/fsr_manager_sylvanas")

assert(FsrManager, "FsrManager must load")

setup_mock()

FsrManager.on_cast(1, 500)
assert(FsrManager.is_inside_fsr() == true, "Expected inside FSR immediately after cast")

mock_time = 1003.5
assert(FsrManager.is_inside_fsr() == true, "Expected still inside FSR after 3.5s")

local fsr_remaining = FsrManager.seconds_until_fsr()
assert(fsr_remaining <= 2.0, string.format("Expected fsr_remaining <= 2.0, got %.2f", fsr_remaining))

local delta = FsrManager.get_regen_delta()
assert(delta > 0, string.format("Expected positive regen delta, got %.0f", delta))

local mock_state = {
    mana_pct = 25,
    lowest_hp_pct = 60,
    in_combat = true,
}
local mock_context = {
    settings = { fsr_emergency_hp = 40 }
}
local pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == true, string.format("Expected should_pause_for_fsr=true, got %s (reason: %s)", tostring(pause_ok), reason or "nil"))

mock_state.mana_pct = 50
pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected should_pause_for_fsr=false when mana > 35%")

mock_state.mana_pct = 25
mock_state.lowest_hp_pct = 35
pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected should_pause_for_fsr=false when emergency HP")

teardown_mock()

print("PASS test_fsr_positive_delta (5/5 assertions)")
