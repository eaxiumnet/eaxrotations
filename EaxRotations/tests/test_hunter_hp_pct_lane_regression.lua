-- test_hunter_hp_pct_lane_regression.lua — regression for the hunter hp_pct
-- dead-lane bug found by the behavioral battery audit (2026-08-07).
-- WHAT:  all three hunter sylvanas specs (beast_mastery / marksmanship /
--        survival) gate Healthstone (hp<=28) and Deterrence (hp<=25) on
--        state.hp_pct, but build_state never assigned hp_pct — it stayed at
--        the 100 default, so both lanes could never fire in live play.
-- WHEN:  rotation suite execution.
-- WHY:   behavioral_audit.lua reported Healthstone/Deterrence never-firing
--        even in low-self scenarios; state.hp_pct was never written.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local SPECS = { "beast_mastery", "marksmanship", "survival" }

for _, spec in ipairs(SPECS) do
    local result, err, ns = aud.load_spec("hunter", spec)
    assert_true(result ~= nil, spec .. " load failed: " .. tostring(err))

    local function find_strategy(name)
        for _, s in ipairs(result.strategies) do
            if s.name == name then return s end
        end
        return nil
    end

    local hs = find_strategy("Healthstone")
    assert_true(hs ~= nil, spec .. " Healthstone strategy missing")

    -- Low-self scenario: hp=15 (<=28), in combat, healthstone available.
    local ctx = aud.build_context_for("hunter", {
        name = "low_self",
        overrides = { hp = 15, player_hp = 15, has_potions = true },
    })
    aud.apply_battery_state(ns, ctx, "hunter")
    local ok, st = pcall(result.build_state, ctx)
    assert_true(ok, spec .. " build_state crashed: " .. tostring(st))
    local state = ok and st or ctx
    assert_true((state.hp_pct or 100) <= 28,
        spec .. " state.hp_pct must reflect low self HP, got " .. tostring(state.hp_pct))

    local mok, m = pcall(hs.matches, ctx, state)
    assert_true(mok, spec .. " Healthstone matcher crashed: " .. tostring(m))
    assert_true(m == true, spec .. " Healthstone must match at hp_pct<=28 in low-self context")

    -- Deterrence (where present) must also match at hp<=25.
    local det = find_strategy("Deterrence")
    if det ~= nil then
        local mok2, m2 = pcall(det.matches, ctx, state)
        assert_true(mok2, spec .. " Deterrence matcher crashed: " .. tostring(m2))
        assert_true(m2 == true, spec .. " Deterrence must match at hp<=25 in low-self context")
    end

    print("PASS: hunter/" .. spec .. " hp_pct lane regression (Healthstone + Deterrence)")
end
