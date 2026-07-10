-- test_fsr_positive_delta.lua — Verify FSR manager correctly recommends pause when regen delta is positive.
-- WHAT:  Mocks core + spec_kit + settings; covers configurable, fsr_seconds guard (>2s), negative delta, end-to-end healer strategies.
-- WHEN:  Run as part of rotation test suite.
-- WHY:   Hardening for PR-1: spec_kit paths, fsr_max_pause_seconds, robust pause logic.
-- SAFETY: isolated package.loaded + mocks; no side effects on real NS.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local mock_time = 1000
_G.EaxRotations = _G.EaxRotations or {}
_G.EaxRotations.time_now = function() return mock_time end
_G.core = _G.core or {}
_G.core.spell_book = _G.core.spell_book or {}

local _orig_get_base = nil
local _orig_get_casting = nil

local function setup_mock(base, casting)
    _orig_get_base = core.spell_book.get_base_power_regen
    _orig_get_casting = core.spell_book.get_casting_power_regen
    core.spell_book.get_base_power_regen = function() return base or 100 end
    core.spell_book.get_casting_power_regen = function() return casting or 20 end
end

local function teardown_mock()
    core.spell_book.get_base_power_regen = _orig_get_base
    core.spell_book.get_casting_power_regen = _orig_get_casting
end

-- reset and load manager (pcall spec_kit inside will fallback or use mock if we set)
package.loaded["shared/fsr_manager_sylvanas"] = nil
local FsrManager = require("shared/fsr_manager_sylvanas")
assert(FsrManager, "FsrManager must load")

-- also ensure is_fsr_pause_enabled exported
assert(type(FsrManager.is_fsr_pause_enabled) == "function", "is_fsr_pause_enabled helper must be exposed")

setup_mock(100, 20)

FsrManager.on_cast(1, 500)
assert(FsrManager.is_inside_fsr() == true, "Expected inside FSR immediately after cast")

mock_time = 1003.5
assert(FsrManager.is_inside_fsr() == true, "Expected still inside FSR after 3.5s")

local fsr_remaining = FsrManager.seconds_until_fsr()
assert(fsr_remaining > 0 and fsr_remaining < 5, string.format("Expected fsr_remaining in (0,5), got %.2f", fsr_remaining))

local delta = FsrManager.get_regen_delta()
assert(delta > 0, string.format("Expected positive regen delta, got %.0f", delta))

-- === Configurable settings via context.settings (fallback path) ===
local mock_state = { mana_pct = 25, lowest_hp_pct = 60, in_combat = true }
local mock_context = { settings = { fsr_emergency_hp = 40, fsr_mana_threshold = 30, fsr_max_pause_seconds = 0 } }
local pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == true, string.format("Expected pause=true via settings, got %s (%s)", tostring(pause_ok), reason or ""))

-- test threshold from settings
mock_state.mana_pct = 35
pause_ok, reason = FsrManager.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected false when mana > fsr_mana_threshold from settings")

-- === spec_kit path coverage (mock the module before re-require) ===
package.loaded["shared/spec_kit_sylvanas"] = {
  setting_bool = function(ctx, key, def)
    if key == "fsr_enabled" then return (ctx and ctx.settings and ctx.settings.fsr_enabled) ~= false end
    return def
  end,
  setting_number = function(ctx, key, def)
    local s = ctx and ctx.settings
    if s and type(s[key]) == "number" then return s[key] end
    return def
  end
}
package.loaded["shared/fsr_manager_sylvanas"] = nil
local FsrManager2 = require("shared/fsr_manager_sylvanas")
assert(FsrManager2, "reloaded FsrManager with spec_kit mock")

setup_mock(100, 20)
FsrManager2.on_cast(1, 500)
mock_time = 1001.0  -- ~4s remaining
mock_state = { mana_pct = 20, lowest_hp_pct = 70, in_combat = true }
mock_context = { settings = { fsr_enabled = true, fsr_mana_threshold = 35, fsr_emergency_hp = 50, fsr_max_pause_seconds = 0 } }
pause_ok, reason = FsrManager2.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == true, "Expected true via spec_kit path with max_pause=0 (full window)")

-- === fsr_seconds / max_pause guard cases (remaining >2s) ===
mock_time = 1000 + 3.5  -- remaining ~1.5s ? wait recal: window=5, 3.5 elapsed -> rem=1.5; set for >2
mock_time = 1000 + 2.5  -- rem ~2.5s
pause_ok, reason = FsrManager2.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == true, "max_pause=0 should allow even when rem>2s")

mock_context.settings.fsr_max_pause_seconds = 1
pause_ok, reason = FsrManager2.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected false when rem> max_pause_seconds (1s)")

mock_context.settings.fsr_max_pause_seconds = 0  -- restore
mock_context.settings.fsr_enabled = false
pause_ok, reason = FsrManager2.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected false when fsr_enabled=false via spec_kit")

-- === negative delta case ===
teardown_mock()
setup_mock(20, 100)  -- base < casting => delta <0
FsrManager2.on_cast(1, 500)
mock_time = 1001
mock_state = { mana_pct = 20, lowest_hp_pct = 70, in_combat = true }
mock_context = { settings = { fsr_mana_threshold=35, fsr_emergency_hp=50, fsr_max_pause_seconds=0 } }
pause_ok, reason = FsrManager2.should_pause_for_fsr(mock_state, mock_context)
assert(pause_ok == false, "Expected false on negative delta")
assert((reason or ""):find("no regen delta") ~= nil, "reason should mention no regen delta")

-- === minimal end-to-end: load healer strategies + simulate match ===
-- mock minimal to allow healer load without full engine
_G.EaxRotations.rotation_registry = { register = function() end }
_G.EaxRotations.FsrManager = FsrManager2
package.loaded["shared/potion_helper_sylvanas"] = { try_use_potion = function() return false end }
-- stub other common requires that resto pulls (minimal to reach strategies)
local function stub_mod(name)
  if not package.loaded[name] then
    package.loaded[name] = {}
  end
end
stub_mod("shared/preemptive_heal_sylvanas")
stub_mod("shared/stopcast_sylvanas")
stub_mod("shared/triage_sylvanas")
stub_mod("shared/snap_threat_sylvanas")
stub_mod("shared/combat_mode_sylvanas")

package.loaded["EaxRotations/classes/druid/resto_sylvanas"] = nil
local resto_result = dofile("EaxRotations/classes/druid/resto_sylvanas.lua")
local strategies = resto_result and (resto_result.strategies or resto_result) or {}
assert(type(strategies) == "table" and #strategies > 0, "healer strategies must load for end-to-end")

-- find FSRPause strategy
local fsr_strat = nil
for _, s in ipairs(strategies) do
  if s.name == "FSRPause" then fsr_strat = s; break end
end
assert(fsr_strat and type(fsr_strat.matches) == "function", "FSRPause strategy must exist with matches")

-- simulate context/state for positive case (note: matches delegates to manager)
local e2e_context = { in_combat = true, settings = { fsr_mana_threshold=35, fsr_emergency_hp=40, fsr_max_pause_seconds=0 } }
local e2e_state = { mana_pct=22, lowest_hp_pct=65, in_combat=true, fsr_inside=true, fsr_regen_delta=300 }
-- ensure inside fsr and positive delta in manager state
FsrManager2.on_cast(99, 123)
mock_time = 1001
setup_mock(80, 10)
local e2e_ok = fsr_strat.matches(e2e_context, e2e_state)
assert(e2e_ok == true, "end-to-end: FSRPause.matches should return true under positive conditions")

-- simulate run_list like first-match (but we just check this strat would win if reached)
assert(type(fsr_strat.execute) == "function", "FSRPause must have execute")
local exec_res = fsr_strat.execute(e2e_context, e2e_state)
assert(exec_res == true, "FSRPause execute returns true (signals pause)")

teardown_mock()
package.loaded["shared/spec_kit_sylvanas"] = nil  -- cleanup mock
package.loaded["shared/fsr_manager_sylvanas"] = nil

print("PASS test_fsr_positive_delta (config settings, spec_kit, >2s guard, neg delta, e2e healer load+match)")
