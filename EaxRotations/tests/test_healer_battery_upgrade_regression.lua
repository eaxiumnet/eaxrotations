-- test_healer_battery_upgrade_regression.lua — pins the 11 lanes unblocked by
-- the healer battery upgrades (2026-08-07, non-DPS triage follow-up).
-- WHAT:  two behavioral_audit.lua upgrades made previously-invisible lanes
--        observable:
--          * NS.PLAYER_UNIT gained get_health_percentage reading the state
--            bank (-> ctx.hp) — holy/smite build_state derive
--            context.hp = health_pct(NS.PLAYER_UNIT), which used to clobber
--            the low_self override back to 100.
--          * a `mana_critical` scenario (mana_pct = 4) — the shaman
--            mana_emergency gates are strict `< 5` and holy's ManaBelow5Wand
--            blocks at `>= 5`, so 4 (not 5) is required.
--        Lanes pinned here (all previously never-firing):
--          holy Healthstone / DesperatePrayer / BindingHeal / ManaBelow5Wand
--          smite Healthstone / SoloPowerWordShield
--          shaman ManaEmergencyWand x3 (elemental/enhancement/restoration)
--          hunter AspectOfTheViper x2 (marksmanship/survival)
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any of the 11 stops firing (state + matcher + end-to-end).
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
-- priest/holy: PLAYER_UNIT hp flow + mana_critical wand lane
-- ============================================================================
local holy, holy_err, holy_ns = aud.load_spec("priest", "holy")
assert_true(holy ~= nil, "priest/holy load failed: " .. tostring(holy_err))
-- Re-assert the current spec's ns: DSL condition evaluators (spell_ready /
-- buff) read _G.EaxRotations dynamically, so keep it pointed at holy_ns
-- regardless of assertion order.
_G.EaxRotations = holy_ns

local hctx, hstate = assert_lane_matches(holy, holy_ns, "priest", "low_self", "Healthstone",
    "holy Healthstone must match at low self HP (PLAYER_UNIT hp flow)")
assert_true((hctx.hp or 100) <= 30,
    "holy context.hp must reflect low_self override, got " .. tostring(hctx.hp))
assert_lane_matches(holy, holy_ns, "priest", "low_self", "DesperatePrayer",
    "holy DesperatePrayer must match at low self HP")
assert_lane_matches(holy, holy_ns, "priest", "low_self", "BindingHeal",
    "holy BindingHeal must match when self HP is low and an ally needs healing")
local _, mc_state = assert_lane_matches(holy, holy_ns, "priest", "mana_critical", "ManaBelow5Wand",
    "holy ManaBelow5Wand must match below 5% mana")
-- NOTE: capture the state from the mana_critical call itself — holy_state is a
-- module-level table mutated in place by each build_state, so a reference held
-- from the earlier low_self call would alias to these (mana_critical) values
-- and make the assert pass for the wrong reason.
assert_true((mc_state.mana_pct or 100) < 5,
    "holy state.mana_pct must reflect mana_critical, got " .. tostring(mc_state.mana_pct))
print("PASS: priest/holy battery-upgrade regression (Healthstone/DesperatePrayer/BindingHeal/ManaBelow5Wand)")

-- ============================================================================
-- priest/smite: PLAYER_UNIT hp flow
-- ============================================================================
local smite, smite_err, smite_ns = aud.load_spec("priest", "smite")
assert_true(smite ~= nil, "priest/smite load failed: " .. tostring(smite_err))
_G.EaxRotations = smite_ns

local sctx, _ = assert_lane_matches(smite, smite_ns, "priest", "low_self", "Healthstone",
    "smite Healthstone must match at low self HP (PLAYER_UNIT hp flow)")
assert_true((sctx.hp or 100) <= 30,
    "smite context.hp must reflect low_self override, got " .. tostring(sctx.hp))
assert_lane_matches(smite, smite_ns, "priest", "low_self", "SoloPowerWordShield",
    "smite SoloPowerWordShield must match at low self HP")
print("PASS: priest/smite battery-upgrade regression (Healthstone/SoloPowerWordShield)")

-- ============================================================================
-- shaman: mana_critical -> ManaEmergencyWand x3
-- ============================================================================
local function assert_shaman_wand(spec_key)
    local mod, err, ns = aud.load_spec("shaman", spec_key)
    assert_true(mod ~= nil, "shaman/" .. spec_key .. " load failed: " .. tostring(err))
    _G.EaxRotations = ns
    local ctx, state = assert_lane_matches(mod, ns, "shaman", "mana_critical", "ManaEmergencyWand",
        "shaman/" .. spec_key .. " ManaEmergencyWand must match in mana_critical")
    assert_true(state.mana_emergency == true,
        "shaman/" .. spec_key .. " state.mana_emergency must be set below the floor")
    assert_true(ctx.has_valid_enemy_target == true,
        "shaman/" .. spec_key .. " ManaEmergencyWand needs a valid target")
end
assert_shaman_wand("elemental")
assert_shaman_wand("enhancement")
assert_shaman_wand("restoration")
print("PASS: shaman battery-upgrade regression (ManaEmergencyWand x3)")

-- ============================================================================
-- hunter: mana_critical -> AspectOfTheViper x2
-- ============================================================================
local function assert_hunter_viper(spec_key)
    local mod, err, ns = aud.load_spec("hunter", spec_key)
    assert_true(mod ~= nil, "hunter/" .. spec_key .. " load failed: " .. tostring(err))
    _G.EaxRotations = ns
    assert_lane_matches(mod, ns, "hunter", "mana_critical", "AspectOfTheViper",
        "hunter/" .. spec_key .. " AspectOfTheViper must match in mana_critical")
end
assert_hunter_viper("marksmanship")
assert_hunter_viper("survival")
print("PASS: hunter battery-upgrade regression (AspectOfTheViper x2)")

-- ============================================================================
-- End-to-end: the battery must report none of the 11 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("priest", "holy", "Healthstone")
assert_lane_fires("priest", "holy", "DesperatePrayer")
assert_lane_fires("priest", "holy", "BindingHeal")
assert_lane_fires("priest", "holy", "ManaBelow5Wand")
assert_lane_fires("priest", "smite", "Healthstone")
assert_lane_fires("priest", "smite", "SoloPowerWordShield")
assert_lane_fires("shaman", "elemental", "ManaEmergencyWand")
assert_lane_fires("shaman", "enhancement", "ManaEmergencyWand")
assert_lane_fires("shaman", "restoration", "ManaEmergencyWand")
assert_lane_fires("hunter", "marksmanship", "AspectOfTheViper")
assert_lane_fires("hunter", "survival", "AspectOfTheViper")
print("PASS: battery reports none of the 11 healer-upgrade lanes as never-firing")
