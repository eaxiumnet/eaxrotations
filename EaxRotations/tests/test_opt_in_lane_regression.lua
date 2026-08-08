-- test_opt_in_lane_regression.lua — pins the 5 pre-classified (a) opt-in
-- lanes unblocked by the settings-fixture scenarios (2026-08-08, warrior/rogue
-- focused triage follow-up).
-- WHAT:  behavioral_audit.lua gained five scenarios, one per previously
--        never-firing opt-in lane. Each lane is gated on a spec setting
--        (default false) AND a state the default battery context can't
--        express — so flipping the setting alone was never enough:
--          warrior/fury `Overpower`     — `fury_overpower_weave` + BT/WW
--            on CD (matcher delays when state.bt_cd/ww_cd < 1.5; default
--            cooldown_remains = 0 blocked it). fury_overpower =
--            { setting_overrides = { fury_overpower_weave = true },
--              on_cd = { [30335] = 6, [1680] = 10 } } (Battle stance +
--            rage 70 are the defaults).
--          warrior/fury `SwingDesync`   — `fury_swing_desync` + swing_until
--            >= DESYNC_SLAM_WINDOW (1.6); default swing 0.5 < 1.6 blocked.
--            fury_swing_desync = { setting_overrides = { fury_swing_desync =
--            true }, swing_until = 2.0 }.
--          warrior/kebab `SunderMaintain` — `sunder_armor_mode` (read
--            DIRECTLY from ctx.settings by kebab's settings_for) + DEFENSIVE
--            stance (matcher: context.stance == DEFENSIVE; default battle 1
--            blocked). kebab_sunder = { setting_overrides = {
--            sunder_armor_mode = "maintain" }, stance = 2 }.
--          rogue/assassination `ColdBloodEnvenom` — `assassin_cold_blood_auto`
--            + SnD up + Cold Blood NOT up (matcher returns false if
--            state.has_cold_blood) + 5 deadly-poison stacks + combo 5.
--            cold_blood = { setting_overrides = { assassin_cold_blood_auto =
--            true }, buff_remains_map = { [6774] = 20, [5171] = 20 },
--            debuff_stacks = 5, debuff_aura_ids = { poison ids },
--            combo_points = 5, energy = 60 }. NB: buffs_up=true would make
--            has_cold_blood true too (COLD_BLOOD_BUFF 14177 via the map-aware
--            buff path falls back to buffs_up) and block the lane — the map
--            must carry ONLY the SnD ids.
--          rogue/assassination `ThistleTea` — `assassin_thistle_tea` +
--            energy <= 40 + combo <= 3. thistle_tea = { setting_overrides =
--            { assassin_thistle_tea = true }, energy = 30, combo_points = 0 }.
--        All five fire EXCLUSIVELY in their scenario (each scenario carries
--        exactly one spec-scoped setting key no other lane reads), so they are
--        pinned with fires-in(1) exclusivity + matcher asserts with sharp
--        negatives + end-to-end never-list checks.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping a scenario, its setting override, or
--        the supporting state) could silently re-hide these 5 lanes; this test
--        fails if any stops firing or leaks into another scenario.
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

local function build_scenario(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

local function make_state(spec_mod, ns, class_key, scenario_name)
    local ctx = aud.build_context_for(class_key, build_scenario(scenario_name))
    aud.apply_battery_state(ns, ctx, class_key)
    if spec_mod.build_state then
        local ok, st = pcall(spec_mod.build_state, ctx)
        assert_true(ok, class_key .. "/" .. scenario_name .. " build_state crashed: " .. tostring(st))
        if type(st) == "table" then return ctx, st end
    end
    return ctx, ctx
end

local function assert_lane(spec_mod, ns, class_key, scenario_name, lane, want, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed: " .. tostring(m))
    assert_true(m == want, label)
    return ctx, state
end

-- ============================================================================
-- warrior/fury: Overpower + SwingDesync
-- ============================================================================
local fury, fury_err, fury_ns = aud.load_spec("warrior", "fury")
assert_true(fury ~= nil, "warrior/fury load failed: " .. tostring(fury_err))
_G.EaxRotations = fury_ns

local op_ctx, op_state = assert_lane(fury, fury_ns, "warrior", "fury_overpower", "Overpower", true,
    "fury Overpower must match in fury_overpower (setting + BT/WW on CD)")
assert_true((op_state.bt_cd or 99) >= 1.5 and (op_state.ww_cd or 99) >= 1.5,
    "fury Overpower delay gate needs bt_cd/ww_cd >= 1.5, got bt_cd=" .. tostring(op_state.bt_cd)
    .. " ww_cd=" .. tostring(op_state.ww_cd))
-- Negative: standard scenario has the setting unset — the (a) gate blocks it.
assert_lane(fury, fury_ns, "warrior", "standard", "Overpower", false,
    "fury Overpower must NOT match in standard (fury_overpower_weave unset)")
print("PASS: warrior/fury Overpower regression (setting + CD window)")

assert_lane(fury, fury_ns, "warrior", "fury_swing_desync", "SwingDesync", true,
    "fury SwingDesync must match in fury_swing_desync (setting + swing window)")
-- Negative: the swing_window scenario has swing_until 1.0 but no setting.
assert_lane(fury, fury_ns, "warrior", "swing_window", "SwingDesync", false,
    "fury SwingDesync must NOT match in swing_window (fury_swing_desync unset)")
-- Negative: the battle_ready scenario has a buff map but no setting either.
assert_lane(fury, fury_ns, "warrior", "battle_ready", "SwingDesync", false,
    "fury SwingDesync must NOT match in battle_ready (setting unset)")
print("PASS: warrior/fury SwingDesync regression (setting + swing window)")

-- ============================================================================
-- warrior/kebab: SunderMaintain
-- ============================================================================
local kebab, kebab_err, kebab_ns = aud.load_spec("warrior", "kebab")
assert_true(kebab ~= nil, "warrior/kebab load failed: " .. tostring(kebab_err))
_G.EaxRotations = kebab_ns

local ks_ctx = aud.build_context_for("warrior", build_scenario("kebab_sunder"))
assert_true(ks_ctx.settings and ks_ctx.settings.sunder_armor_mode == "maintain",
    "kebab_sunder must merge sunder_armor_mode into ctx.settings")
assert_lane(kebab, kebab_ns, "warrior", "kebab_sunder", "SunderMaintain", true,
    "kebab SunderMaintain must match in kebab_sunder (mode maintain + defensive stance)")
-- Negative: defensive_stance has stance 2 but mode defaults to "none".
assert_lane(kebab, kebab_ns, "warrior", "defensive_stance", "SunderMaintain", false,
    "kebab SunderMaintain must NOT match in defensive_stance (sunder_armor_mode none)")
-- Negative: standard is battle stance even if the fixture merged the setting
-- elsewhere — the mode gate is what flips it.
assert_lane(kebab, kebab_ns, "warrior", "standard", "SunderMaintain", false,
    "kebab SunderMaintain must NOT match in standard (battle stance + mode none)")
print("PASS: warrior/kebab SunderMaintain regression (mode + stance)")

-- ============================================================================
-- rogue/assassination: ColdBloodEnvenom + ThistleTea
-- ============================================================================
local assn, assn_err, assn_ns = aud.load_spec("rogue", "assassination")
assert_true(assn ~= nil, "rogue/assassination load failed: " .. tostring(assn_err))
_G.EaxRotations = assn_ns

local cb_ctx, cb_state = assert_lane(assn, assn_ns, "rogue", "cold_blood", "ColdBloodEnvenom", true,
    "assassination ColdBloodEnvenom must match in cold_blood (auto setting + SnD up + poison stacks)")
assert_true(cb_state.slice_dice_active == true and cb_state.has_cold_blood == false
    and cb_state.snd_needs_refresh == false,
    "cold_blood scenario needs SnD up (remains > 3) and Cold Blood down, got slice_dice_active="
    .. tostring(cb_state.slice_dice_active) .. " has_cold_blood=" .. tostring(cb_state.has_cold_blood)
    .. " snd_needs_refresh=" .. tostring(cb_state.snd_needs_refresh))
assert_true((cb_state.dp_stacks or 0) >= 3,
    "cold_blood scenario needs dp_stacks >= 3, got " .. tostring(cb_state.dp_stacks))
-- Negative: poison_stacks has the poison stacks + SnD via buffs_up but no
-- assassin_cold_blood_auto setting — and buffs_up makes has_cold_blood true.
assert_lane(assn, assn_ns, "rogue", "poison_stacks", "ColdBloodEnvenom", false,
    "assassination ColdBloodEnvenom must NOT match in poison_stacks (setting unset + Cold Blood up)")
print("PASS: rogue/assassination ColdBloodEnvenom regression (auto + SnD + poison)")

assert_lane(assn, assn_ns, "rogue", "thistle_tea", "ThistleTea", true,
    "assassination ThistleTea must match in thistle_tea (setting + low energy + low combo)")
-- Negative: energy_low has the resource shape but no assassin_thistle_tea.
assert_lane(assn, assn_ns, "rogue", "energy_low", "ThistleTea", false,
    "assassination ThistleTea must NOT match in energy_low (assassin_thistle_tea unset)")
print("PASS: rogue/assassination ThistleTea regression (setting + resource shape)")

-- ============================================================================
-- Exclusivity: all five fire ONLY in their scenario.
-- ============================================================================
local function assert_exclusive(class_key, spec, lane, only_in)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    local fi = report.fires_in[lane]
    assert_true(fi ~= nil, class_key .. "/" .. spec .. " " .. lane .. " missing from fires_in")
    local n = 0
    for k in pairs(fi) do n = n + 1 end
    assert_true(n == 1 and fi[only_in] == true,
        class_key .. "/" .. spec .. " " .. lane .. " must fire ONLY in " .. only_in
        .. ", fired in " .. tostring(n) .. " scenarios")
end
assert_exclusive("warrior", "fury", "Overpower", "fury_overpower")
assert_exclusive("warrior", "fury", "SwingDesync", "fury_swing_desync")
assert_exclusive("warrior", "kebab", "SunderMaintain", "kebab_sunder")
assert_exclusive("rogue", "assassination", "ColdBloodEnvenom", "cold_blood")
assert_exclusive("rogue", "assassination", "ThistleTea", "thistle_tea")
print("PASS: exclusivity — all 5 opt-in lanes fire only in their scenario")

-- ============================================================================
-- End-to-end: the battery must report none of the 5 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("warrior", "fury", "Overpower")
assert_lane_fires("warrior", "fury", "SwingDesync")
assert_lane_fires("warrior", "kebab", "SunderMaintain")
assert_lane_fires("rogue", "assassination", "ColdBloodEnvenom")
assert_lane_fires("rogue", "assassination", "ThistleTea")
print("PASS: battery reports none of the 5 opt-in lanes as never-firing")
print("ALL PASS: test_opt_in_lane_regression")
