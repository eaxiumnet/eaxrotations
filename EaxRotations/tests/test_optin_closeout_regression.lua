-- test_optin_closeout_regression.lua — pins the final (a) opt-in lanes
-- unblocked by the close-out scenarios (2026-08-08, warrior/rogue focused
-- triage, remaining (a) cluster).
-- WHAT:  behavioral_audit.lua gained four scenarios clearing the last 6
--        opt-in lanes. Keys are spec-scoped (arms reads use_sunder_armor;
--        fury reads sunder_mode; arms+prot read use_commanding_shout; combat
--        reads combat_expose_assigned; subtlety reads subtlety_expose_assigned):
--          warrior/arms `SunderArmor`   — `use_sunder_armor` + BATTLE stance
--            (2026-08-12 live-correctness fix: its build_action now has
--            required_stance = STANCE.BATTLE — arms plays in Battle and no
--            strategy swaps to Defensive, so the old DEFENSIVE gate made the
--            lane unreachable in live play).
--            arms_sunder = { setting_overrides = { use_sunder_armor = true },
--            stance = 1 }.
--          warrior/fury `SunderArmor`   — `sunder_mode \"maintain\"` (default
--            \"off\" blocks; rage 70 default clears the min_rage 15 gate).
--            fury_sunder = { setting_overrides = { sunder_mode = \"maintain\" } }.
--          warrior/arms + prot `CommandingShout` — shared `use_commanding_shout`
--            setting: arms matcher (setting + rage >= 10, battle-stance fine);
--            prot DSL `{ type = \"setting\" }` condition (evaluated via
--            spec_kit.setting → ctx.settings first; has_commanding_shout /
--            has_battle_shout falsy defaults + commanding_ready true all pass).
--            commanding_shout = { setting_overrides = {
--            use_commanding_shout = true } }.
--          rogue/combat + subtlety `ExposeArmor` — combat (expose_armor_ready
--            true via spell_ready + expose_assigned from combat_expose_assigned)
--            and subtlety (setting + combo 5 >= 4 + ttd 60 >= 20 + no sunder).
--            expose_armor = { setting_overrides = { combat_expose_assigned =
--            true, subtlety_expose_assigned = true } }.
--        All six fire EXCLUSIVELY in their scenario (each scenario carries
--        exactly one spec-scoped setting key), so they are pinned with
--        fires-in(1) exclusivity + matcher asserts with sharp negatives +
--        end-to-end never-list checks.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping a scenario or its setting override)
--        could silently re-hide these 6 lanes; this test fails if any stops
--        firing or leaks into another scenario.
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
-- warrior/arms: SunderArmor (setting + battle stance) + CommandingShout
-- ============================================================================
local arms, arms_err, arms_ns = aud.load_spec("warrior", "arms")
assert_true(arms ~= nil, "warrior/arms load failed: " .. tostring(arms_err))
_G.EaxRotations = arms_ns

local sa_ctx, sa_state = assert_lane(arms, arms_ns, "warrior", "arms_sunder", "SunderArmor", true,
    "arms SunderArmor must match in arms_sunder (setting + battle stance)")
assert_true(sa_state.stance == 1,
    "arms_sunder must be battle stance, got stance=" .. tostring(sa_state.stance))
-- Negative: battle_stance has stance 1 but no setting — the setting gate blocks.
assert_lane(arms, arms_ns, "warrior", "battle_stance", "SunderArmor", false,
    "arms SunderArmor must NOT match in battle_stance (use_sunder_armor unset)")
-- Negative: standard has no setting either.
assert_lane(arms, arms_ns, "warrior", "standard", "SunderArmor", false,
    "arms SunderArmor must NOT match in standard (setting unset)")
print("PASS: warrior/arms SunderArmor regression (setting + stance)")

assert_lane(arms, arms_ns, "warrior", "commanding_shout", "CommandingShout", true,
    "arms CommandingShout must match in commanding_shout (setting + rage >= 10)")
assert_lane(arms, arms_ns, "warrior", "standard", "CommandingShout", false,
    "arms CommandingShout must NOT match in standard (use_commanding_shout unset)")
print("PASS: warrior/arms CommandingShout regression")

-- ============================================================================
-- warrior/fury: SunderArmor (sunder_mode maintain)
-- ============================================================================
local fury, fury_err, fury_ns = aud.load_spec("warrior", "fury")
assert_true(fury ~= nil, "warrior/fury load failed: " .. tostring(fury_err))
_G.EaxRotations = fury_ns

assert_lane(fury, fury_ns, "warrior", "fury_sunder", "SunderArmor", true,
    "fury SunderArmor must match in fury_sunder (sunder_mode maintain)")
assert_lane(fury, fury_ns, "warrior", "standard", "SunderArmor", false,
    "fury SunderArmor must NOT match in standard (sunder_mode off)")
print("PASS: warrior/fury SunderArmor regression")

-- ============================================================================
-- warrior/protection: CommandingShout (shared setting, DSL condition)
-- ============================================================================
local prot, prot_err, prot_ns = aud.load_spec("warrior", "protection")
assert_true(prot ~= nil, "warrior/protection load failed: " .. tostring(prot_err))
_G.EaxRotations = prot_ns

local cs_ctx = aud.build_context_for("warrior", build_scenario("commanding_shout"))
assert_true(cs_ctx.settings and cs_ctx.settings.use_commanding_shout == true,
    "commanding_shout must merge use_commanding_shout into ctx.settings")
assert_lane(prot, prot_ns, "warrior", "commanding_shout", "CommandingShout", true,
    "prot CommandingShout must match in commanding_shout (DSL setting truthy + ready)")
assert_lane(prot, prot_ns, "warrior", "standard", "CommandingShout", false,
    "prot CommandingShout must NOT match in standard (use_commanding_shout unset)")
print("PASS: warrior/protection CommandingShout regression (DSL setting)")

-- ============================================================================
-- rogue: ExposeArmor x2 (combat + subtlety)
-- ============================================================================
local combat, combat_err, combat_ns = aud.load_spec("rogue", "combat")
assert_true(combat ~= nil, "rogue/combat load failed: " .. tostring(combat_err))
_G.EaxRotations = combat_ns

local ea_ctx = aud.build_context_for("rogue", build_scenario("expose_armor"))
assert_true(ea_ctx.settings and ea_ctx.settings.combat_expose_assigned == true,
    "expose_armor must merge combat_expose_assigned into ctx.settings")
local cmb_ctx, cmb_state = assert_lane(combat, combat_ns, "rogue", "expose_armor", "ExposeArmor", true,
    "combat ExposeArmor must match in expose_armor (assigned + ready + armor)")
assert_true(cmb_state.expose_armor_ready == true,
    "combat expose_armor_ready must be true, got " .. tostring(cmb_state.expose_armor_ready))
assert_lane(combat, combat_ns, "rogue", "standard", "ExposeArmor", false,
    "combat ExposeArmor must NOT match in standard (combat_expose_assigned unset)")
print("PASS: rogue/combat ExposeArmor regression")

local sub, sub_err, sub_ns = aud.load_spec("rogue", "subtlety")
assert_true(sub ~= nil, "rogue/subtlety load failed: " .. tostring(sub_err))
_G.EaxRotations = sub_ns

assert_lane(sub, sub_ns, "rogue", "expose_armor", "ExposeArmor", true,
    "subtlety ExposeArmor must match in expose_armor (assigned + combo 5 + ttd 60)")
assert_lane(sub, sub_ns, "rogue", "standard", "ExposeArmor", false,
    "subtlety ExposeArmor must NOT match in standard (subtlety_expose_assigned unset)")
print("PASS: rogue/subtlety ExposeArmor regression")

-- ============================================================================
-- Exclusivity: all six fire ONLY in their scenario.
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
assert_exclusive("warrior", "arms", "SunderArmor", "arms_sunder")
assert_exclusive("warrior", "arms", "CommandingShout", "commanding_shout")
assert_exclusive("warrior", "fury", "SunderArmor", "fury_sunder")
assert_exclusive("warrior", "protection", "CommandingShout", "commanding_shout")
assert_exclusive("rogue", "combat", "ExposeArmor", "expose_armor")
assert_exclusive("rogue", "subtlety", "ExposeArmor", "expose_armor")
print("PASS: exclusivity — all 6 close-out opt-in lanes fire only in their scenario")

-- ============================================================================
-- End-to-end: the battery must report none of the 6 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("warrior", "arms", "SunderArmor")
assert_lane_fires("warrior", "arms", "CommandingShout")
assert_lane_fires("warrior", "fury", "SunderArmor")
assert_lane_fires("warrior", "protection", "CommandingShout")
assert_lane_fires("rogue", "combat", "ExposeArmor")
assert_lane_fires("rogue", "subtlety", "ExposeArmor")
print("PASS: battery reports none of the 6 close-out opt-in lanes as never-firing")
print("ALL PASS: test_optin_closeout_regression")
