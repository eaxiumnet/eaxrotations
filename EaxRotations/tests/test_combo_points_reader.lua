-- test_combo_points_reader.lua - Combo point READER contract test.
-- WHAT:  Proves the CP reader prefers get_power(POWER_COMBO) over a broken IZI SDK
--        combo_points_current() that returns 0 instead of nil.
-- WHEN:  rotation suite / standalone.
-- WHY:   Live probe on client 2.5.5 showed combo_points_current()==0 while
--        get_power(4) correctly reported 0->1->2->3. Because 0 is a number, the
--        `type(cp) == "number"` check short-circuited and get_power was NEVER
--        reached, so every finisher (Rip/Ferocious Bite/Maim) saw 0 CP forever.
-- SAFETY: fully mocked player object; no engine, no real API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/shared/?.lua;./?.lua;api/?.lua;"
    .. package.path

local all_ok = true

local function assert_eq(got, want, msg)
    if got ~= want then
        print("FAIL " .. tostring(msg) .. ": got " .. tostring(got) .. " want " .. tostring(want))
        all_ok = false
        return
    end
    print("PASS " .. tostring(msg))
end

local POWER_COMBO = 4

local function make_player(opts)
    local me = {}
    if opts.sdk ~= "absent" then
        me.combo_points_current = function() return opts.sdk end
    end
    if opts.power ~= "absent" then
        me.get_power = function(_, idx)
            if idx == POWER_COMBO then return opts.power end
            if idx == 3 then return 100 end
            return 0
        end
    end
    return me
end

local read_combo_points = dofile("EaxRotations/shared/combo_points_reader_sylvanas.lua")

if type(read_combo_points) ~= "function" then
    print("FAIL combo_points_reader_sylvanas.lua did not return a function")
    os.exit(1)
end

-- S5: the reported bug. Broken SDK reports 0 while get_power has the truth.
assert_eq(read_combo_points(make_player({ sdk = 0, power = 3 }), POWER_COMBO), 3,
    "S5 broken SDK 0 is overridden by get_power=3")

assert_eq(read_combo_points(make_player({ sdk = 3, power = 3 }), POWER_COMBO), 3,
    "agreeing non-zero readers return 3")

-- S6: genuine zero. Both agree; must stay 0, not nil.
assert_eq(read_combo_points(make_player({ sdk = 0, power = 0 }), POWER_COMBO), 0,
    "S6 genuine zero returns 0")

-- S7: get_power absent -> fall back to the SDK value rather than failing.
assert_eq(read_combo_points(make_player({ sdk = 4, power = "absent" }), POWER_COMBO), 4,
    "S7 get_power absent falls back to SDK=4")

-- S8: SDK absent -> get_power alone is sufficient.
assert_eq(read_combo_points(make_player({ sdk = "absent", power = 2 }), POWER_COMBO), 2,
    "S8 SDK absent uses get_power=2")

-- S9: both readers unavailable -> nil (NOT 0) so consumers' fallbacks activate.
assert_eq(read_combo_points(make_player({ sdk = "absent", power = "absent" }), POWER_COMBO), nil,
    "S9 both readers absent returns nil")

-- S10: nil unit must not crash.
assert_eq(read_combo_points(nil, POWER_COMBO), nil, "S10 nil unit returns nil")

assert_eq(read_combo_points(make_player({ sdk = 5, power = 0 }), POWER_COMBO), 0,
    "S11 authoritative get_power=0 overrides stale SDK=5")

local native_zero_calls, stale_sdk_calls = 0, 0
local native_zero_player = {
    get_power = function(_, power_type)
        native_zero_calls = native_zero_calls + 1
        if power_type == POWER_COMBO then return 0 end
        return nil
    end,
    combo_points_current = function()
        stale_sdk_calls = stale_sdk_calls + 1
        return 5
    end,
}
assert_eq(read_combo_points(native_zero_player, POWER_COMBO), 0,
    "S12 authoritative get_power=0 returns before stale SDK=5")
assert_eq(native_zero_calls, 1, "S12 reads the requested combo power once")
assert_eq(stale_sdk_calls, 0, "S12 does not consult SDK after native zero")

if all_ok then
    print("ALL PASS test_combo_points_reader")
else
    print("FAILURES in test_combo_points_reader")
    os.exit(1)
end
