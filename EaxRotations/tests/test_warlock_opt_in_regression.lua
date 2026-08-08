-- test_warlock_opt_in_regression.lua — pins the 12 (a) opt-in warlock lanes
-- unblocked by the ranked #11 battery upgrade (2026-08-07): the 9 curse
-- lanes (CurseOfElements/CurseOfRecklessness/CurseOfWeakness across
-- affliction/demonology/destruction) + 3 Healthstone lanes (one per spec).
-- WHAT:  behavioral_audit.lua now carries four warlock opt-in scenarios that
--        drive the spec settings through the settings-fixture merge
--        (setting_overrides -> ctx.settings):
--          curse_mode_elements     { warlock_curse_mode = "elements" }
--          curse_mode_recklessness { warlock_curse_mode = "recklessness" }
--          curse_mode_weakness     { warlock_curse_mode = "weakness" }
--          low_self_healthstone    { hp = 25, healthstone_hp = 40 }
--        The curse lanes are gated on select_curse() which only returns
--        elements/recklessness/weakness when the matching warlock_curse_mode
--        is set (auto mode resolves to agony/doom). The shared
--        warlock_healthstone helper gates on healthstone_hp > 0 AND
--        hp <= threshold (default 0 -> never).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing or fires in the wrong scenario.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local function build_scenario(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

-- Each cleared lane fires ONLY in its intended scenario (probe-verified):
--   curse lane -> its own curse_mode_* scenario
--   Healthstone -> low_self_healthstone
local WANT = {
    CurseOfElements = "curse_mode_elements",
    CurseOfRecklessness = "curse_mode_recklessness",
    CurseOfWeakness = "curse_mode_weakness",
    Healthstone = "low_self_healthstone",
}

-- ============================================================================
-- End-to-end: run the real battery for each warlock spec and assert every lane
-- (a) is not never-firing, (b) fires in its intended scenario, and (c) fires
-- ONLY there (single-scenario exclusivity).
-- ============================================================================
for _, spec in ipairs({ "affliction", "demonology", "destruction" }) do
    local report = aud.run_spec("warlock", spec)
    assert_true(report ~= nil, "battery run for warlock/" .. spec .. " failed")
    assert_true(#report.dispatch_errors == 0,
        "warlock/" .. spec .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
    for lane, want in pairs(WANT) do
        local is_never = false
        for _, name in ipairs(report.never) do
            if name == lane then is_never = true end
        end
        assert_true(not is_never, "battery still reports warlock/" .. spec .. " " .. lane .. " as never-firing")
        local fi = report.fires_in[lane]
        assert_true(type(fi) == "table" and fi[want] == true,
            "warlock/" .. spec .. " " .. lane .. " must fire in the " .. want .. " scenario")
        local count = 0
        for _ in pairs(fi) do count = count + 1 end
        assert_true(count == 1,
            "warlock/" .. spec .. " " .. lane .. " must fire ONLY in " .. want .. ", got " .. count .. " scenarios")
    end
end
print("PASS: end-to-end battery check (12 lanes, scenario exclusivity)")

-- ============================================================================
-- Mechanism pins: the settings fixture drives the same gates the live engine
-- reads — direct matcher evaluation on the scenario contexts.
-- ============================================================================
local function load_and_match(spec, scenario_name, lane)
    local result, load_err, ns = aud.load_spec("warlock", spec)
    assert_true(result ~= nil, "load warlock/" .. spec .. " failed: " .. tostring(load_err))
    local ctx = aud.build_context_for("warlock", build_scenario(scenario_name))
    aud.apply_battery_state(ns, ctx, "warlock")
    local state = result.build_state and result.build_state(ctx) or ctx
    for _, s in ipairs(result.strategies or result) do
        if s.name == lane and s.matches then
            local ok, m = pcall(s.matches, ctx, state)
            assert_true(ok, "warlock/" .. spec .. " " .. lane .. " matcher crashed: " .. tostring(m))
            return m
        end
    end
    error("warlock/" .. spec .. " " .. lane .. " strategy missing", 2)
end

for _, spec in ipairs({ "affliction", "demonology", "destruction" }) do
    -- curse lanes: each matches in its own mode scenario
    assert_true(load_and_match(spec, "curse_mode_elements", "CurseOfElements"),
        "warlock/" .. spec .. " CurseOfElements must match with warlock_curse_mode = elements")
    assert_true(load_and_match(spec, "curse_mode_recklessness", "CurseOfRecklessness"),
        "warlock/" .. spec .. " CurseOfRecklessness must match with warlock_curse_mode = recklessness")
    assert_true(load_and_match(spec, "curse_mode_weakness", "CurseOfWeakness"),
        "warlock/" .. spec .. " CurseOfWeakness must match with warlock_curse_mode = weakness")
    -- healthstone: matches at hp 25 with threshold 40
    assert_true(load_and_match(spec, "low_self_healthstone", "Healthstone"),
        "warlock/" .. spec .. " Healthstone must match with hp 25 + healthstone_hp 40")
end
print("PASS: mechanism pins (9 curse lanes + 3 Healthstone via settings fixture)")
print("ALL PASS: ranked #11 warlock opt-in regression")
