-- test_undead_lane_regression.lua — pins the 9 creature-type lanes unblocked
-- by the `undead_target` battery scenario (2026-08-07, healer triage).
-- WHAT:  behavioral_audit.lua gained an `undead_target` scenario
--        ({ target_creature_type = 6, enemy_count = 2, enemies_count = 2 }),
--        and build_scenario_target / ns.unit_creature_type were bound to
--        ctx.target_creature_type. Before that, the mock target reported
--        creature type 7 (humanoid), so undead/demon-gated lanes could never
--        fire. (Undead is creature-type 6 in the WoW enum — 3 is DEMON; the
--        specs' DEMON_OR_UNDEAD / UNDEAD_OR_DEMON tables accept {3, 6}.)
--        Lanes pinned here (all previously never-firing):
--          ShackleUndead x4 (priest discipline/holy/shadow/smite)
--          TurnEvil x2 (paladin protection/retribution)
--          Exorcism (paladin protection)
--          HolyWrath (paladin protection) + Ret_HolyWrath_AoE (retribution)
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any of the 9 stops firing (state + matcher + end-to-end).
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

local function assert_lane_matches(spec_mod, ns, class_key, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, "undead_target")
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == true, label)
    return ctx, state
end

-- ============================================================================
-- priest: ShackleUndead x4 — all gate on state.target_creature_type (undead 6)
-- ============================================================================
local function assert_priest_shackle(spec_key)
    local mod, err, ns = aud.load_spec("priest", spec_key)
    assert_true(mod ~= nil, "priest/" .. spec_key .. " load failed: " .. tostring(err))
    -- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
    -- buff) read _G.EaxRotations dynamically, so keep it pointed at this ns.
    _G.EaxRotations = ns
    local ctx, state = assert_lane_matches(mod, ns, "priest", "ShackleUndead",
        "priest/" .. spec_key .. " ShackleUndead must match in undead_target")
    assert_true(state.target_creature_type == 6,
        "priest/" .. spec_key .. " state.target_creature_type must be 6 (undead), got "
        .. tostring(state.target_creature_type))
    assert_true(ctx.target ~= nil and ctx.has_valid_enemy_target == true,
        "priest/" .. spec_key .. " ShackleUndead needs a valid enemy target")
end
assert_priest_shackle("discipline")
assert_priest_shackle("holy")
assert_priest_shackle("shadow")
assert_priest_shackle("smite")
print("PASS: priest ShackleUndead x4 regression (undead_target creature type 6)")

-- ============================================================================
-- paladin/protection: TurnEvil + Exorcism + HolyWrath (undead/demon-gated)
-- ============================================================================
local prot, prot_err, prot_ns = aud.load_spec("paladin", "protection")
assert_true(prot ~= nil, "paladin/protection load failed: " .. tostring(prot_err))
_G.EaxRotations = prot_ns

local pctx, pstate = assert_lane_matches(prot, prot_ns, "paladin", "TurnEvil",
    "protection TurnEvil must match in undead_target")
assert_lane_matches(prot, prot_ns, "paladin", "Exorcism",
    "protection Exorcism must match in undead_target")
assert_lane_matches(prot, prot_ns, "paladin", "HolyWrath",
    "protection HolyWrath must match in undead_target (undead + enemy_count >= 2)")
assert_true(pstate.target_creature_type == 6,
    "protection state.target_creature_type must be 6, got " .. tostring(pstate.target_creature_type))
assert_true((pctx.enemy_count or 0) >= 2,
    "protection HolyWrath needs enemy_count >= 2, got " .. tostring(pctx.enemy_count))
print("PASS: paladin/protection TurnEvil + Exorcism + HolyWrath regression")

-- ============================================================================
-- paladin/retribution: TurnEvil + Ret_HolyWrath_AoE
-- ============================================================================
local ret, ret_err, ret_ns = aud.load_spec("paladin", "retribution")
assert_true(ret ~= nil, "paladin/retribution load failed: " .. tostring(ret_err))
_G.EaxRotations = ret_ns

local rctx, rstate = assert_lane_matches(ret, ret_ns, "paladin", "TurnEvil",
    "retribution TurnEvil must match in undead_target")
assert_lane_matches(ret, ret_ns, "paladin", "Ret_HolyWrath_AoE",
    "retribution Ret_HolyWrath_AoE must match in undead_target (undead + enemy_count >= 2)")
assert_true(rstate.target_creature_type == 6,
    "retribution state.target_creature_type must be 6, got " .. tostring(rstate.target_creature_type))
assert_true((rctx.enemy_count or 0) >= 2,
    "retribution Ret_HolyWrath_AoE needs enemy_count >= 2, got " .. tostring(rctx.enemy_count))
print("PASS: paladin/retribution TurnEvil + Ret_HolyWrath_AoE regression")

-- ============================================================================
-- End-to-end: the battery must report none of the 9 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("priest", "discipline", "ShackleUndead")
assert_lane_fires("priest", "holy", "ShackleUndead")
assert_lane_fires("priest", "shadow", "ShackleUndead")
assert_lane_fires("priest", "smite", "ShackleUndead")
assert_lane_fires("paladin", "protection", "TurnEvil")
assert_lane_fires("paladin", "protection", "Exorcism")
assert_lane_fires("paladin", "protection", "HolyWrath")
assert_lane_fires("paladin", "retribution", "TurnEvil")
assert_lane_fires("paladin", "retribution", "Ret_HolyWrath_AoE")
print("PASS: battery reports none of the 9 creature-type lanes as never-firing")
