-- test_fsr_positive_delta.lua — Verify FSR manager correctly recommends pause when regen delta is positive.
-- WHAT:  Mocks core.spell_book regen APIs to simulate positive FSR delta.
-- WHEN:  Run as part of rotation test suite.
-- WHY:   Oracle identified FSR positive-delta path was untested.

local NS = _G.EaxRotations or {}
NS.time_now = NS.time_now or function() return os.clock() end

-- Mock the APIs that FsrManager needs
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

-- Load FsrManager fresh (it lazy-loads the APIs)
package.loaded["shared/fsr_manager_sylvanas"] = nil
local FsrManager = require("shared/fsr_manager_sylvanas")

assert(FsrManager, "FsrManager must load")

-- Test 1: is_inside_fsr after cast
setup_mock()
FsrManager.on_cast(1, 500)
assert(FsrManager.is_inside_fsr() == true, "Expected inside FSR immediately after cast")

-- Test 2: get_regen_delta with mocked APIs
local delta = FsrManager.get_regen_delta()
assert(delta > 0, string.format("Expected positive regen delta, got %.0f", delta))

-- Test 3: should_pause_for_fsr returns true when conditions met
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

-- Test 4: should_pause_for_fsr returns false when mana is high
mock_state.mana_pct = 50
pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected should_pause_for_fsr=false when mana > 35%")

-- Test 5: should_pause_for_fsr returns false when emergency
mock_state.mana_pct = 25
mock_state.lowest_hp_pct = 35
pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected should_pause_for_fsr=false when emergency HP")

teardown_mock()

print("PASS test_fsr_positive_delta (5/5 assertions)")
