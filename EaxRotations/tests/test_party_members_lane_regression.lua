-- test_party_members_lane_regression.lua — pins the lane unblocked by the
-- party_members wiring (2026-08-07, ranked #3 from the focused triage).
-- WHAT:  holy MassDispel (holy_sylvanas.lua:1019-1042) scans
--        `context.party_members` for dangerous magic via
--        `Healing.has_dangerous_dispel(u)` — but the battery never populated
--        context.party_members, so the scan was empty and the lane could never
--        fire. behavioral_audit.lua now populates `ctx.party_members` from the
--        heal-scan friend units when the group is afflicted (friends_afflicted
--        scenario, which also sets the magic affliction flag the
--        has_dangerous_dispel stub reads). The matcher's other gates
--        (in_combat, use_party_dispel default true, mass_dispel_ready,
--        mana >= 30, is_group) all pass in that scenario.
--        Lane pinned here (was never-firing):
--          priest/holy: MassDispel
--        All other specs are byte-identical (216 total, 0 dispatch errors) —
--        paladin ally-scan lanes did NOT clear, so the party_members change is
--        scoped exactly to the afflicted scenario.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide this lane; this test
--        fails if it stops firing (state + matcher + negative + end-to-end).
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local function find_strategy(strategies, name)
    for _, s in ipairs(strategies) do
        if s.name == name then return s end
    end
    return nil
end

local function build_scenario(class_key, name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(class_key, scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane_matches(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- ============================================================================
-- priest/holy: MassDispel — gated on the party_members dangerous-magic scan.
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local md_ctx, md_state = assert_lane_matches(holy, holy_ns, "priest", "friends_afflicted", "MassDispel",
    "holy MassDispel must match in friends_afflicted (party scan finds dangerous magic)")
-- State-fidelity: this is the (party_members-fix) mechanism — the scan needs a
-- non-empty party plus the ready flag.
assert_true(type(md_ctx.party_members) == "table" and #md_ctx.party_members >= 1,
    "holy MassDispel needs context.party_members populated (the fix), got "
    .. tostring(md_ctx.party_members and #md_ctx.party_members))
assert_true(md_state.mass_dispel_ready == true,
    "holy MassDispel needs state.mass_dispel_ready, got " .. tostring(md_state.mass_dispel_ready))
-- Negative assert: without the afflicted group the dangerous-magic scan finds
-- nothing, so the lane must stay silent in a plain injured-group scenario.
local calm_ctx, calm_state = make_state(holy, holy_ns, "priest", "group_critical")
local md = find_strategy(holy.strategies, "MassDispel")
local ok_calm, m_calm = pcall(md.matches, calm_ctx, calm_state)
assert_true(ok_calm and m_calm ~= true,
    "holy MassDispel must not match in group_critical (no afflicted magic) — party-scan gating regression")
print("PASS: priest/holy MassDispel regression (1 lane)")

-- ============================================================================
-- End-to-end: the battery must not report the cleared lane as never-firing.
-- ============================================================================
local report = aud.run_spec("priest", "holy")
assert_true(report ~= nil, "battery run for priest/holy failed")
for _, name in ipairs(report.never) do
    assert_true(name ~= "MassDispel",
        "battery still reports priest/holy MassDispel as never-firing")
end
print("PASS: battery reports MassDispel as firing")
