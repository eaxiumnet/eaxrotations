-- test_settings_fixture_lane_regression.lua — pins the 13 opt-in lanes
-- unblocked by the settings-modeling fixture (2026-08-07, ranked #7).
-- WHAT:  behavioral_audit.lua now merges `setting_overrides` into ctx.settings
--        in build_context_for, so ALL settings read channels see them: direct
--        `ctx.settings[key]` reads (balance RemoveCurse, hunter AdaptiveRotation
--        via NS.setting_bool), spec_kit.setting/setting_bool (context.settings
--        is first in the resolution chain), and the DSL `{ type = "setting" }`
--        evaluator. Also: multi-enemy scenarios now populate ctx.enemies (retri
--        find_secondary_enemy), and the battery dispatch counts any TRUTHY
--        matcher return (mirrors the real engine — MM/survival AdaptiveRotation
--        return `c.target`, a table, which `m == true` previously ignored).
--        New scenarios (92 total): auto_dispel, blessings, seal_command_apply,
--        seal_command_active, hunter_toggles; undead_target gained
--        use_exorcism = true.
--        Lanes pinned here (all previously never-firing):
--          druid balance/cat RemoveCurse              (auto_dispel)
--          paladin/retri Ret_BlessingKings_Self/Party (blessings)
--          paladin/retri Ret_SealCommand_Primary + Ret_HotC_Opener_Judge
--                                                      (seal_command_apply)
--          paladin/retri Ret_JudgeSecondary_CommandCleave (seal_command_active)
--          paladin/retri Exorcism                      (undead_target)
--          hunter BM Volley + ExplosiveTrap + AdaptiveRotation x3
--                                                      (hunter_toggles)
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing (state + matcher + negative + end-to-end).
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
    -- Truthy check mirrors the battery dispatch (MM/survival AdaptiveRotation
    -- matchers return `c.target`, a table, which still counts as fired).
    assert_true(m, label)
    return ctx, state
end

local function assert_never(spec_mod, ns, class_key, scenario_name, lane, label)
    local ctx, state = make_state(spec_mod, ns, class_key, scenario_name)
    local s = find_strategy(spec_mod.strategies, lane)
    assert_true(s ~= nil, class_key .. " " .. lane .. " strategy missing")
    local ok, m = pcall(s.matches, ctx, state)
    assert_true(ok, class_key .. " " .. lane .. " matcher crashed in negative: " .. tostring(m))
    assert_true(m ~= true, label)
end

-- ============================================================================
-- auto_dispel: druid balance/cat RemoveCurse. balance reads
-- ctx.settings.balance_auto_dispel DIRECTLY (the fixture's mechanism);
-- cat reads cat_auto_dispel via spec_kit.
-- ============================================================================
local bal, bal_err, bal_ns = aud.load_spec("druid", "balance")
assert_true(bal ~= nil, "druid/balance load failed: " .. tostring(bal_err))
_G.EaxRotations = bal_ns
local b_ctx, b_state = assert_lane_matches(bal, bal_ns, "druid", "auto_dispel", "RemoveCurse",
    "druid/balance RemoveCurse must match in auto_dispel (balance_auto_dispel setting)")
assert_true(b_ctx.settings.balance_auto_dispel == true,
    "druid/balance: fixture must merge balance_auto_dispel into ctx.settings, got "
    .. tostring(b_ctx.settings.balance_auto_dispel))
assert_never(bal, bal_ns, "druid", "standard", "RemoveCurse",
    "druid/balance RemoveCurse must not match in standard (opt-in off)")
print("PASS: druid/balance RemoveCurse regression")

local cat, cat_err, cat_ns = aud.load_spec("druid", "cat")
assert_true(cat ~= nil, "druid/cat load failed: " .. tostring(cat_err))
_G.EaxRotations = cat_ns
local c_ctx, c_state = assert_lane_matches(cat, cat_ns, "druid", "auto_dispel", "RemoveCurse",
    "druid/cat RemoveCurse must match in auto_dispel (cat_auto_dispel setting)")
assert_true(c_ctx.settings.cat_auto_dispel == true,
    "druid/cat: fixture must merge cat_auto_dispel into ctx.settings")
assert_never(cat, cat_ns, "druid", "standard", "RemoveCurse",
    "druid/cat RemoveCurse must not match in standard (opt-in off)")
print("PASS: druid/cat RemoveCurse regression")

-- ============================================================================
-- blessings: retri Ret_BlessingKings_Self/Party. The party lane's find_ally
-- falls back to self in the battery (candidate_members returns a number).
-- ============================================================================
local retri, retri_err, retri_ns = aud.load_spec("paladin", "retribution")
assert_true(retri ~= nil, "paladin/retribution load failed: " .. tostring(retri_err))
_G.EaxRotations = retri_ns
local k_ctx, k_state = assert_lane_matches(retri, retri_ns, "paladin", "blessings", "Ret_BlessingKings_Self",
    "paladin/retri Ret_BlessingKings_Self must match in blessings")
assert_lane_matches(retri, retri_ns, "paladin", "blessings", "Ret_BlessingKings_Party",
    "paladin/retri Ret_BlessingKings_Party must match in blessings (find_ally falls back to self)")
assert_true(k_ctx.settings.blessing_of_kings_self == true and k_ctx.settings.blessing_of_kings_party == true,
    "paladin/retri: fixture must merge blessing_of_kings_* into ctx.settings")
assert_never(retri, retri_ns, "paladin", "standard", "Ret_BlessingKings_Self",
    "paladin/retri Ret_BlessingKings_Self must not match in standard (opt-in off)")
print("PASS: paladin/retri Ret_BlessingKings_Self/Party regression")

-- ============================================================================
-- seal_command_apply: Ret_SealCommand_Primary (preferred = command, no seal up)
-- + Ret_HotC_Opener_Judge (Crusader seal up via map, combat_time < 8).
-- ============================================================================
local s_ctx, s_state = assert_lane_matches(retri, retri_ns, "paladin", "seal_command_apply", "Ret_SealCommand_Primary",
    "paladin/retri Ret_SealCommand_Primary must match in seal_command_apply (seal_preference=command)")
assert_true(s_state.preferred_damage_seal == "command",
    "paladin/retri: seal_preference=command must drive preferred_damage_seal, got "
    .. tostring(s_state.preferred_damage_seal))
assert_true(s_state.has_command == false,
    "paladin/retri: Ret_SealCommand_Primary needs no Command seal up, got has_command=" .. tostring(s_state.has_command))
local hotc_ctx, hotc_state = assert_lane_matches(retri, retri_ns, "paladin", "seal_command_apply", "Ret_HotC_Opener_Judge",
    "paladin/retri Ret_HotC_Opener_Judge must match in seal_command_apply (Crusader seal up, combat_time 3)")
assert_true(hotc_state.has_crusader == true,
    "paladin/retri: Crusader seal map must drive has_crusader, got " .. tostring(hotc_state.has_crusader))
assert_true(hotc_state.target_has_crusader == false,
    "paladin/retri: HotC needs no Crusader debuff on target, got " .. tostring(hotc_state.target_has_crusader))
assert_never(retri, retri_ns, "paladin", "standard", "Ret_SealCommand_Primary",
    "paladin/retri Ret_SealCommand_Primary must not match in standard (blood preference)")
print("PASS: paladin/retri Ret_SealCommand_Primary + Ret_HotC_Opener_Judge regression")

-- ============================================================================
-- seal_command_active: Ret_JudgeSecondary_CommandCleave — Command seal UP + a
-- second melee enemy (context.enemies fixture) + swing band + mana >= 30.
-- ============================================================================
local jc_ctx, jc_state = assert_lane_matches(retri, retri_ns, "paladin", "seal_command_active", "Ret_JudgeSecondary_CommandCleave",
    "paladin/retri Ret_JudgeSecondary_CommandCleave must match in seal_command_active")
assert_true(jc_state.has_command == true,
    "paladin/retri: Command seal map must drive has_command, got " .. tostring(jc_state.has_command))
assert_true(jc_state.secondary_target ~= nil,
    "paladin/retri: context.enemies fixture must produce secondary_target, got nil")
assert_true(type(jc_ctx.enemies) == "table" and #jc_ctx.enemies >= 2,
    "paladin/retri: seal_command_active must populate ctx.enemies (2 enemies), got " .. tostring(#jc_ctx.enemies))
assert_true((jc_state.mana_pct or 0) >= 30,
    "paladin/retri: JudgeSecondary needs mana >= 30, got " .. tostring(jc_state.mana_pct))
assert_never(retri, retri_ns, "paladin", "seal_command_apply", "Ret_JudgeSecondary_CommandCleave",
    "paladin/retri JudgeSecondary must not match with the Command seal absent (seal_command_apply)")
print("PASS: paladin/retri Ret_JudgeSecondary_CommandCleave regression")

-- ============================================================================
-- Exorcism: retri opt-in use_exorcism + undead target (undead_target scenario).
-- ============================================================================
local ex_ctx, ex_state = assert_lane_matches(retri, retri_ns, "paladin", "undead_target", "Exorcism",
    "paladin/retri Exorcism must match in undead_target (use_exorcism opt-in)")
assert_true(ex_ctx.settings.use_exorcism == true,
    "paladin/retri: fixture must merge use_exorcism into ctx.settings")
assert_never(retri, retri_ns, "paladin", "standard", "Exorcism",
    "paladin/retri Exorcism must not match in standard (opt-in off)")
print("PASS: paladin/retri Exorcism regression")

-- ============================================================================
-- hunter_toggles: AdaptiveRotation x3 (needs the truthy-dispatch fix — MM/surv
-- matchers return c.target), Volley + ExplosiveTrap (use_volley /
-- use_explosive_trap, 4 enemies for the AoE gates).
-- ============================================================================
local bm, bm_err, bm_ns = aud.load_spec("hunter", "beast_mastery")
assert_true(bm ~= nil, "hunter/beast_mastery load failed: " .. tostring(bm_err))
_G.EaxRotations = bm_ns
local h_ctx, h_state = assert_lane_matches(bm, bm_ns, "hunter", "hunter_toggles", "Volley",
    "hunter/BM Volley must match in hunter_toggles (use_volley)")
assert_lane_matches(bm, bm_ns, "hunter", "hunter_toggles", "ExplosiveTrap",
    "hunter/BM ExplosiveTrap must match in hunter_toggles (use_explosive_trap)")
assert_true(h_ctx.settings.use_volley == true and h_ctx.settings.use_explosive_trap == true
    and h_ctx.settings.use_adaptive_rotation == true,
    "hunter/BM: fixture must merge hunter toggles into ctx.settings")
assert_never(bm, bm_ns, "hunter", "standard", "Volley",
    "hunter/BM Volley must not match in standard (opt-in off)")
print("PASS: hunter/BM Volley + ExplosiveTrap regression")

local mm, mm_err, mm_ns = aud.load_spec("hunter", "marksmanship")
assert_true(mm ~= nil, "hunter/marksmanship load failed: " .. tostring(mm_err))
_G.EaxRotations = mm_ns
local mm_ctx = assert_lane_matches(mm, mm_ns, "hunter", "hunter_toggles", "AdaptiveRotation",
    "hunter/MM AdaptiveRotation must match in hunter_toggles (truthy matcher return counts)")
assert_true(mm_ctx.settings.use_adaptive_rotation == true,
    "hunter/MM: fixture must merge use_adaptive_rotation into ctx.settings")
print("PASS: hunter/MM AdaptiveRotation regression")

local sv, sv_err, sv_ns = aud.load_spec("hunter", "survival")
assert_true(sv ~= nil, "hunter/survival load failed: " .. tostring(sv_err))
_G.EaxRotations = sv_ns
assert_lane_matches(sv, sv_ns, "hunter", "hunter_toggles", "AdaptiveRotation",
    "hunter/survival AdaptiveRotation must match in hunter_toggles")
print("PASS: hunter/survival AdaptiveRotation regression")

local bm2, _, bm2_ns = aud.load_spec("hunter", "beast_mastery")
_G.EaxRotations = bm2_ns
assert_lane_matches(bm2, bm2_ns, "hunter", "hunter_toggles", "AdaptiveRotation",
    "hunter/BM AdaptiveRotation must match in hunter_toggles")
print("PASS: hunter/BM AdaptiveRotation regression")

-- ============================================================================
-- End-to-end: the battery must report each cleared lane as firing — and only
-- in its intended scenario.
-- ============================================================================
local end_to_end = {
    { "druid", "balance", "RemoveCurse", "auto_dispel" },
    { "druid", "cat", "RemoveCurse", "auto_dispel" },
    { "paladin", "retribution", "Ret_BlessingKings_Self", "blessings" },
    { "paladin", "retribution", "Ret_BlessingKings_Party", "blessings" },
    { "paladin", "retribution", "Ret_SealCommand_Primary", "seal_command_apply" },
    { "paladin", "retribution", "Ret_HotC_Opener_Judge", "seal_command_apply" },
    { "paladin", "retribution", "Ret_JudgeSecondary_CommandCleave", "seal_command_active" },
    { "paladin", "retribution", "Exorcism", "undead_target" },
    { "hunter", "beast_mastery", "Volley", "hunter_toggles" },
    { "hunter", "beast_mastery", "ExplosiveTrap", "hunter_toggles" },
    { "hunter", "beast_mastery", "AdaptiveRotation", "hunter_toggles" },
    { "hunter", "marksmanship", "AdaptiveRotation", "hunter_toggles" },
    { "hunter", "survival", "AdaptiveRotation", "hunter_toggles" },
}
local done = {}
for _, kv in ipairs(end_to_end) do
    local class_key, spec_key, lane, want = kv[1], kv[2], kv[3], kv[4]
    local key = class_key .. "/" .. spec_key
    if not done[key] then
        local report = aud.run_spec(class_key, spec_key)
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
    assert_true(type(fi) == "table" and fi[want] == true,
        key .. " " .. lane .. " must fire in the " .. want .. " scenario")
    local count = 0
    for _ in pairs(fi) do count = count + 1 end
    assert_true(count == 1,
        key .. " " .. lane .. " must fire ONLY in " .. want .. ", got " .. count .. " scenarios")
end
print("PASS: end-to-end battery check (13 lanes, exclusive scenario firing)")
