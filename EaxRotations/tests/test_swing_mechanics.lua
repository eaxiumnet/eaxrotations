-- test_swing_mechanics.lua — Validates parry-haste, enemy-swing tracking, and
-- Overpower dodge-proc detection ported into swing_diagnostics from SuperSwingTimer.
-- WHAT:  Injects synthetic CLEU args via the captured dispatcher callback and asserts
--        parry compression (40%, 20% floor), Overpower 5s proc window, enemy swing timer.
-- WHY:   These mechanics let tanks/DPS time swings/Slam/Overpower precisely (CLEU-authoritative).

local _G = _G
local NS = {}
_G.EaxRotations = NS

NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function()
    return { get_guid = function() return "PLAYER-GUID" end }
end

local _test_now = 10.0
NS.time_now = function() return _test_now end

-- Capture the CLEU callback registered by swing_diagnostics so we can inject events.
local _captured_callbacks = {}
NS.register_on_game_event = function(event_name, callback)
    _captured_callbacks[event_name] = callback
    return true
end

local function assert_true(v, msg)
    if not v then error("FAIL " .. tostring(msg), 2) end
end
local function assert_eq(a, b, msg)
    if type(a) == "number" and type(b) == "number" then
        if math.abs(a - b) > 0.05 then error(("FAIL %s: %.3f ~= %.3f"):format(msg, a, b), 2) end
    elseif a ~= b then
        error("FAIL " .. tostring(msg) .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end
local function assert_nil(v, msg)
    if v ~= nil then error("FAIL " .. tostring(msg) .. ": expected nil, got " .. tostring(v), 2) end
end

-- CLEU fixed-prefix layout (apidocs/pages/dev/api/events.md):
-- [1]timestamp [2]sub_event [3]hide_caster [4]source_guid [5]source_name [6]source_flags
-- [7]source_raid_flags [8]dest_guid [9]dest_name [10]dest_flags [11]dest_raid_flags
-- SWING_MISSED suffix: [12]=missType [13]=isOffHand
-- SPELL_MISSED suffix: [12]=spell_id [13]=spell_name [14]=spell_school [15]=missType [16]=isOffHand
local function cleu(sub, src_guid, dest_guid, miss_type, spell_id)
    local a = {}
    a[1], a[2], a[3] = _test_now, sub, false
    a[4], a[5], a[6], a[7] = src_guid, "Unit", 0, 0
    a[8], a[9], a[10], a[11] = dest_guid, "Unit", 0, 0
    if sub == "SWING_MISSED" then
        a[12], a[13] = miss_type, false
    elseif sub == "SPELL_MISSED" then
        a[12], a[13], a[14], a[15], a[16] = spell_id or 12294, "Mortal Strike", 1, miss_type, false
    elseif sub == "SWING_DAMAGE" then
        a[12] = 100           -- amount
        a[21] = false         -- isOffHand (MH)
    end
    return a
end

local function inject(args)
    local cb = _captured_callbacks["COMBAT_LOG_EVENT_UNFILTERED"]
    assert_true(cb ~= nil, "CLEU callback was registered")
    cb("COMBAT_LOG_EVENT_UNFILTERED", args)
end

-- Load the module under test.
local mod_ok, mod_err = pcall(dofile, "EaxRotations/shared/swing_diagnostics_sylvanas.lua")
if not mod_ok then error("could not load swing_diagnostics: " .. tostring(mod_err)) end
local M = NS.SwingDiagnostics
assert_true(M ~= nil, "NS.SwingDiagnostics loaded")

-- register_seals triggers ensure_registered → captures the CLEU callback.
M.register_seals({ 31892 })
assert_true(_captured_callbacks["COMBAT_LOG_EVENT_UNFILTERED"] ~= nil, "CLEU callback captured after register_seals")

-- ---------------------------------------------------------------------------
-- Test 1: No data yet → all accessors return nil/false
-- ---------------------------------------------------------------------------
M.reset()
_test_now = 10.0
assert_nil(M.get_swing_remains(), "swing remains nil before any swing")
assert_true(M.is_overpower_proc_active() == false, "no Overpower proc before any dodge")
assert_nil(M.get_enemy_swing_remains(), "enemy swing remains nil before any incoming swing")
assert_nil(M.get_last_parry_time(), "no parry recorded yet")
print("  [ PASS ] initial state clean")

-- ---------------------------------------------------------------------------
-- Test 2: Player MH swing → swing timer established
-- ---------------------------------------------------------------------------
inject(cleu("SWING_DAMAGE", "PLAYER-GUID", "ENEMY-GUID"))  -- player source, MH
_test_now = 10.0  -- swing recorded at t=10, interval stays default 3.5 (first swing)
assert_eq(M.get_swing_remains(), 3.5, "swing remains ~3.5s after first swing (at t=10)")
_test_now = 11.0
assert_eq(M.get_swing_remains(), 2.5, "swing remains ticks down")
print("  [ PASS ] MH swing timing tracked")

-- ---------------------------------------------------------------------------
-- Test 3: Parry-haste — player parries incoming → swing compressed 40%, floor 20%
-- ---------------------------------------------------------------------------
_test_now = 10.5
local pre_parry = M.get_swing_remains()  -- (13.5 - 10.5) = 3.0
inject(cleu("SWING_MISSED", "ENEMY-GUID", "PLAYER-GUID", "PARRY"))  -- player DEST, PARRY
local post_parry = M.get_swing_remains()
-- reduction = 0.4 * 3.5 = 1.4; new remaining = max(3.0 - 1.4, 0.7) = 1.6
assert_eq(post_parry, 1.6, "parry compresses swing from 3.0 to 1.6s")
assert_eq(M.get_last_parry_time(), 10.5, "parry time recorded")
print("  [ PASS ] parry-haste compresses swing (40%)")

-- ---------------------------------------------------------------------------
-- Test 4: Second parry before swing lands → floored at 20% of weapon speed
-- ---------------------------------------------------------------------------
_test_now = 10.6
inject(cleu("SWING_MISSED", "ENEMY-GUID", "PLAYER-GUID", "PARRY"))
local floored = M.get_swing_remains()
-- floor = 0.2 * 3.5 = 0.7; remaining was ~1.5, -1.4 → 0.1, floored to 0.7
assert_eq(floored, 0.7, "repeated parry floored at 20% of weapon speed (0.7s)")
print("  [ PASS ] parry floor (20%) respected")

-- ---------------------------------------------------------------------------
-- Test 5: New MH swing lands → parry adjustment cleared, interval updates
-- ---------------------------------------------------------------------------
_test_now = 13.0
inject(cleu("SWING_DAMAGE", "PLAYER-GUID", "ENEMY-GUID"))  -- new swing at t=13
-- interval = 13 - 10 = 3.0; no parry pending; remains = (13+3.0) - 13 = 3.0
assert_eq(M.get_swing_remains(), 3.0, "new swing clears parry adjustment, updates interval")
print("  [ PASS ] new swing clears parry adjustment")

-- ---------------------------------------------------------------------------
-- Test 6: Overpower proc — player's white swing DODGED → 5s window
-- ---------------------------------------------------------------------------
_test_now = 14.0
assert_true(M.is_overpower_proc_active() == false, "no Overpower proc before dodge")
inject(cleu("SWING_MISSED", "PLAYER-GUID", "ENEMY-GUID", "DODGE"))  -- player source, DODGE
assert_true(M.is_overpower_proc_active() == true, "Overpower proc active after white-swing dodge")
assert_eq(M.get_overpower_proc_remains(), 5.0, "Overpower proc window is 5s")
_test_now = 19.1  -- > 5s elapsed
assert_true(M.is_overpower_proc_active() == false, "Overpower proc expires after 5s")
print("  [ PASS ] Overpower proc window (5s) after white-swing dodge")

-- ---------------------------------------------------------------------------
-- Test 7: SPELL_MISSED dodge (special dodged) also procs Overpower
-- ---------------------------------------------------------------------------
_test_now = 20.0
inject(cleu("SPELL_MISSED", "PLAYER-GUID", "ENEMY-GUID", "DODGE", 12294))  -- Mortal Strike dodged
assert_true(M.is_overpower_proc_active() == true, "SPELL_MISSED dodge procs Overpower")
print("  [ PASS ] SPELL_MISSED dodge procs Overpower")

-- ---------------------------------------------------------------------------
-- Test 8: Enemy swing timer — incoming swings on player tracked
-- ---------------------------------------------------------------------------
M.reset()
_test_now = 30.0
assert_nil(M.get_enemy_swing_remains(), "enemy swing nil before any incoming attack")
inject(cleu("SWING_DAMAGE", "ENEMY-GUID", "PLAYER-GUID"))  -- enemy hits player
_test_now = 30.0
assert_true(M.get_enemy_swing_remains() ~= nil, "enemy swing remains available after incoming hit")
local intv = M.get_enemy_swing_interval()
_test_now = 32.5
inject(cleu("SWING_MISSED", "ENEMY-GUID", "PLAYER-GUID", "MISS"))  -- enemy swings again (misses player)
assert_eq(M.get_enemy_swing_interval(), 2.5, "enemy swing interval = 2.5s between incoming swings")
_test_now = 33.0
assert_eq(M.get_enemy_swing_remains(), 2.0, "enemy swing remains ticks down (35.0 - 33.0)")
print("  [ PASS ] enemy swing timer tracked (player as defender)")

-- ---------------------------------------------------------------------------
-- Test 9: reset() clears all mechanic state
-- ---------------------------------------------------------------------------
M.reset()
_test_now = 40.0
assert_nil(M.get_swing_remains(), "reset clears swing state")
assert_true(M.is_overpower_proc_active() == false, "reset clears Overpower proc")
assert_nil(M.get_enemy_swing_remains(), "reset clears enemy swing state")
assert_nil(M.get_last_parry_time(), "reset clears parry time")
print("  [ PASS ] reset clears all mechanic state")

print("PASS test_swing_mechanics (parry-haste + enemy swing + Overpower proc)")
