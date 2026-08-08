-- test_seal_twist_lane_regression.lua — pins the lanes unblocked by the
-- seal-state scenario (2026-08-07, ranked #5 from the focused triage).
-- WHAT:  behavioral_audit.lua gained a scenario-aware `setting_overrides`
--        override ({ [setting_key] = value }) honored by the ns.get_any_setting
--        stub (unconfigured keys return nil, so retri can_twist stays false
--        everywhere else — the real module's `true` default is NOT mimicked
--        battery-wide, or SealTwistPrepCommand would fire in every scenario at
--        the default 0.5s swing), plus two scenarios:
--          seal_twist_blood: setting_overrides = { seal_twisting_enabled = true },
--                            buff_remains_map = { [27170] = 5 } (Command seal),
--                            swing_until = 0.4 (<= twist window 0.45)
--          seal_twist_prep:  setting_overrides = { seal_twisting_enabled = true },
--                            buff_remains_map = { [31892] = 5 } (Blood seal),
--                            swing_until = 0.9 (in (0.45, 1.2] prep window),
--                            on_cd = { [20271] = 2.0 } (Judgement > 1.5s)
--        paladin retribution gates (retribution_sylvanas.lua):
--          SealTwistBlood       (:674): can_twist && has_command && !has_blood
--                                    && swing_remains <= twist_window
--          SealTwistPrepCommand (:704): can_twist && can_use_blood
--                                    && !has_command_rank1
--                                    && swing in (twist_window, twist_window+0.75]
--                                    && judge_cd > 1.5 (Judgement id 20271)
--        Lanes pinned here (were never-firing):
--          paladin/retribution: SealTwistBlood, SealTwistPrepCommand
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if either stops firing (state + matcher + negative + end-to-end).
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

local function lane_matches(spec_mod, ns, class_key, scenario_name, lane)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    return ctx, state, m
end

-- ============================================================================
-- paladin/retribution: seal-twist lanes.
-- ============================================================================
local ret, ret_err, ret_ns = aud.load_spec("paladin", "retribution")
assert_true(ret ~= nil, "paladin/retribution load failed: " .. tostring(ret_err))
_G.EaxRotations = ret_ns

-- SealTwistBlood fires in seal_twist_blood: Command seal up, no Blood seal,
-- swing (0.4) inside the 0.45s twist window.
local _, blood_state, blood_m = lane_matches(ret, ret_ns, "paladin", "seal_twist_blood", "SealTwistBlood")
assert_true(blood_m == true,
    "paladin/retribution SealTwistBlood must match in seal_twist_blood (Command up, swing 0.4)")
-- State-fidelity: can_twist flips on ONLY via setting_overrides; the seal and
-- swing fields must land exactly as the scenario intends.
assert_true(blood_state.can_twist == true,
    "seal_twist_blood must set can_twist (get_any_setting -> setting_overrides), got "
    .. tostring(blood_state.can_twist))
assert_true(blood_state.has_command == true,
    "seal_twist_blood must set has_command (buff 27170), got " .. tostring(blood_state.has_command))
assert_true(blood_state.has_blood ~= true,
    "seal_twist_blood must NOT set has_blood (no 31892), got " .. tostring(blood_state.has_blood))
assert_true(type(blood_state.swing_remains) == "number"
    and blood_state.swing_remains > 0 and blood_state.swing_remains <= (blood_state.twist_window or 0.45),
    "SealTwistBlood needs swing_remains in (0, twist_window], got "
    .. tostring(blood_state.swing_remains) .. " / " .. tostring(blood_state.twist_window))

-- SealTwistPrepCommand fires in seal_twist_prep: Blood seal up, Judgement on
-- CD (2.0s > 1.5s), swing (0.9) inside the (0.45, 1.2] prep window.
local _, prep_state, prep_m = lane_matches(ret, ret_ns, "paladin", "seal_twist_prep", "SealTwistPrepCommand")
assert_true(prep_m == true,
    "paladin/retribution SealTwistPrepCommand must match in seal_twist_prep (Blood up, Judgement on CD, swing 0.9)")
assert_true(prep_state.can_twist == true and prep_state.can_use_blood == true,
    "seal_twist_prep must set can_twist and can_use_blood, got "
    .. tostring(prep_state.can_twist) .. "/" .. tostring(prep_state.can_use_blood))
assert_true(prep_state.has_blood == true,
    "seal_twist_prep must set has_blood (buff 31892), got " .. tostring(prep_state.has_blood))
assert_true(prep_state.has_command_rank1 ~= true,
    "seal_twist_prep must NOT set has_command_rank1 (20375 absent), got "
    .. tostring(prep_state.has_command_rank1))
local tw = prep_state.twist_window or 0.45
assert_true(type(prep_state.swing_remains) == "number"
    and prep_state.swing_remains > tw and prep_state.swing_remains <= tw + 0.75,
    "SealTwistPrepCommand needs swing_remains in (twist_window, twist_window+0.75], got "
    .. tostring(prep_state.swing_remains))
-- Judge gate: Judgement (20271) must be on CD > 1.5s — the scenario's on_cd
-- override is the mechanism (real cooldown_remains reads spell.ids[1]).
assert_true(ret_ns.cooldown_remains({ ids = { 20271 } }) > 1.5,
    "seal_twist_prep must put Judgement (20271) on cooldown > 1.5s for SealTwistPrepCommand")

-- Negative asserts: the swing bands are disjoint, so each lane must stay silent
-- in the OTHER seal scenario; and without setting_overrides (standard) can_twist
-- is false, so neither may fire.
local _, _, cross_m = lane_matches(ret, ret_ns, "paladin", "seal_twist_prep", "SealTwistBlood")
assert_true(cross_m ~= true,
    "SealTwistBlood must not match in seal_twist_prep (has_command false) — band/gate regression")
local _, _, cross2_m = lane_matches(ret, ret_ns, "paladin", "seal_twist_blood", "SealTwistPrepCommand")
assert_true(cross2_m ~= true,
    "SealTwistPrepCommand must not match in seal_twist_blood (swing 0.4 <= twist_window, judge_cd 0) — band/gate regression")
local _, std_state, std_m1 = lane_matches(ret, ret_ns, "paladin", "standard", "SealTwistBlood")
local _, _, std_m2 = lane_matches(ret, ret_ns, "paladin", "standard", "SealTwistPrepCommand")
assert_true(std_state.can_twist ~= true and std_m1 ~= true and std_m2 ~= true,
    "seal-twist lanes must stay silent in standard (can_twist off without setting_overrides) — scoping regression")
print("PASS: paladin/retribution SealTwistBlood + SealTwistPrepCommand regression (2 lanes)")

-- ============================================================================
-- End-to-end: the battery must not report the cleared lanes as never-firing.
-- ============================================================================
local report = aud.run_spec("paladin", "retribution")
assert_true(report ~= nil, "battery run for paladin/retribution failed")
for _, name in ipairs(report.never) do
    assert_true(name ~= "SealTwistBlood" and name ~= "SealTwistPrepCommand",
        "battery still reports paladin/retribution " .. name .. " as never-firing")
end
print("PASS: battery reports SealTwistBlood/SealTwistPrepCommand as firing")
