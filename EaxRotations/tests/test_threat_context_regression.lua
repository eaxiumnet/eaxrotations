-- test_threat_context_regression.lua — pins the lanes unblocked by the
-- ranked #12 battery upgrade (2026-08-07): a `threat_high` scenario
-- (threat_pct 95, threat_status 3, has_aggro true) plus the
-- threat_pct/has_aggro/threat_status/threat_level override passthrough.
-- WHAT:  behavioral_audit.lua now (a) adds the threat keys to the known
--        override list in build_context_for and (b) adds a `threat_high`
--        scenario. That makes the threat-drop / high-aggro lane family
--        observable:
--          warlock/affliction  Soulshatter   (threat_pct >= 80 or has_aggro)
--          warlock/demonology  Soulshatter   (same shared helper)
--          priest/disc+holy+shadow Fade      (threat_pct >= 80, default threshold)
--          rogue/combat+subtlety Feint       (threat_pct >= 90 default)
--          rogue/assassination VanishReopen  (threat_pct >= 90)
--          rogue/assassination FeintAoE      (threat_pct > 90)
--        These were invisible because the battery never set threat state;
--        the scenario fires them all realistically (high-aggro combat).
--        hunter FeignDeath deliberately does NOT clear — it reads
--        state.threat_level via hunter_core.should_feign_death, not ctx
--        threat_pct (verified: beast_mastery still never-fires FeignDeath).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing in threat_high.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local CLEARED = {
    { "warlock", "affliction",  "Soulshatter" },
    { "warlock", "demonology",  "Soulshatter" },
    { "priest",  "discipline",  "Fade" },
    { "priest",  "holy",        "Fade" },
    { "priest",  "shadow",      "Fade" },
    { "rogue",   "combat",      "Feint" },
    { "rogue",   "subtlety",    "Feint" },
    { "rogue",   "assassination", "VanishReopen" },
    { "rogue",   "assassination", "FeintAoE" },
}

-- ============================================================================
-- End-to-end: run the real battery for each affected spec; every cleared lane
-- must (a) not be never-firing and (b) fire in the threat_high scenario.
-- Soulshatter additionally must be single-scenario exclusive (fires ONLY in
-- threat_high — the other lanes legitimately also fire in low_self/aoe etc.
-- where their secondary branches match, so only Soulshatter gets the
-- exclusivity assert).
-- ============================================================================
local done = {}
for _, c in ipairs(CLEARED) do
    local class_key, spec, lane = c[1], c[2], c[3]
    local key = class_key .. "/" .. spec
    if not done[key] then
        local report = aud.run_spec(class_key, spec)
        assert_true(report ~= nil, "battery run for " .. key .. " failed")
        assert_true(#report.dispatch_errors == 0,
            key .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
        done[key] = report
    end
    local report = done[key]
    local is_never = false
    for _, name in ipairs(report.never) do
        if name == lane then is_never = true end
    end
    assert_true(not is_never, "battery still reports " .. key .. " " .. lane .. " as never-firing")
    local fi = report.fires_in[lane]
    assert_true(type(fi) == "table" and fi.threat_high == true,
        key .. " " .. lane .. " must fire in the threat_high scenario")
    if lane == "Soulshatter" then
        local count = 0
        for _ in pairs(fi) do count = count + 1 end
        assert_true(count == 1,
            key .. " Soulshatter must fire ONLY in threat_high, got " .. count .. " scenarios")
    end
end
print("PASS: end-to-end battery check (9 threat lanes, threat_high firing)")

-- ============================================================================
-- Negative: hunter FeignDeath must stay never-firing (threat_level path, not
-- ctx threat_pct) — proves the scenario doesn't leak into a different gate.
-- ============================================================================
local hunter = aud.run_spec("hunter", "beast_mastery")
assert_true(hunter ~= nil, "battery run for hunter/beast_mastery failed")
local fd_never = false
for _, name in ipairs(hunter.never) do
    if name == "FeignDeath" then fd_never = true end
end
assert_true(fd_never,
    "hunter/beast_mastery FeignDeath must remain never-firing (it reads state.threat_level via hunter_core, not ctx threat_pct)")
print("PASS: hunter FeignDeath negative (different threat gate untouched)")

-- ============================================================================
-- Mechanism pin: threat_pct passthrough flows into ctx and Soulshatter matches.
-- ============================================================================
local result, load_err, ns = aud.load_spec("warlock", "affliction")
assert_true(result ~= nil, "load warlock/affliction failed: " .. tostring(load_err))
local scenario
for _, s in ipairs(aud.SCENARIOS) do
    if s.name == "threat_high" then scenario = s end
end
assert_true(scenario ~= nil, "threat_high scenario missing")
local ctx = aud.build_context_for("warlock", scenario)
aud.apply_battery_state(ns, ctx, "warlock")
assert_true(ctx.threat_pct == 95, "ctx.threat_pct must be 95 in threat_high, got " .. tostring(ctx.threat_pct))
assert_true(ctx.has_aggro == true, "ctx.has_aggro must be true in threat_high")
local state = result.build_state and result.build_state(ctx) or ctx
local ss = nil
for _, s in ipairs(result.strategies or result) do
    if s.name == "Soulshatter" then ss = s end
end
assert_true(ss ~= nil, "Soulshatter strategy missing")
local ok_m, m = pcall(ss.matches, ctx, state)
assert_true(ok_m and m, "warlock/affliction Soulshatter must match in threat_high context")
print("PASS: mechanism pin (threat_pct 95 + has_aggro true reach Soulshatter)")
print("ALL PASS: ranked #12 threat-context regression")
