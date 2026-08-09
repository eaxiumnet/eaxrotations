-- test_defensive_casting_regression.lua — pins the lanes unblocked by the
-- defensive-casting battery upgrade (2026-08-08, warrior/rogue focused
-- triage, ranked top item).
-- WHAT:  behavioral_audit.lua gained (1) a scenario-target `is_casting_spell`
--        method wired to ctx.target_is_casting (ctx-aware, mirroring the
--        existing is_casting/is_channeling wiring — reads ctx directly, no
--        state-bank indirection) and (2) the `defensive_casting`
--        scenario { stance = 2, target_is_casting = true, hp = 15,
--        player_hp = 15, is_pvp = true }. Protection's build_state derives
--        state.target_is_casting from target:is_casting_spell()
--        (protection_sylvanas.lua:310) — arms reads ctx.target_is_casting —
--        so prot Pummel/SpellReflection could never fire even in the existing
--        casting scenarios. is_pvp is REQUIRED for prot SpellReflection
--        (ACTIONS metadata requires_pvp = true) and for the arms Disarm /
--        SpellReflection matchers (is_pvp + defensive-stance build_action);
--        stance 2 (defensive) + low hp mirrors a tank under spell pressure.
--        Lanes pinned here (all previously never-firing):
--          warrior/protection: Pummel, SpellReflection      (the targets)
--          warrior/arms:       Disarm, SpellReflection      (is_pvp +
--                              defensive-stance scenario combo)
--          rogue/combat:       Blind                        (is_pvp + hp <= 40)
--          rogue/subtlety:     Blind                        (is_pvp + hp <= 35)
--        The arms/rogue lanes fire EXCLUSIVELY in defensive_casting (the only
--        scenario combining is_pvp with the other required state), so they are
--        pinned with fires-in(1) exclusivity; prot Pummel legitimately fires in
--        every casting scenario (its gate is just ready + casting), so it is
--        pinned with matcher + end-to-end never-list checks instead.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping is_casting_spell, is_pvp, or the
--        scenario) could silently re-hide these 6 lanes; this test fails if
--        any stops firing or the exclusive ones leak into other scenarios.
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

-- Assert the lane's matcher returns `want` in `scenario_name` (default true);
-- returns ctx+state from THAT call so state-fidelity asserts are scoped to the
-- right scenario (module-level state tables are mutated by later build_state).
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
-- Mechanism pin: the scenario target's is_casting_spell follows the scenario.
-- ============================================================================
local dc_ctx = aud.build_context_for("warrior", build_scenario("defensive_casting"))
assert_true(dc_ctx.target.is_casting_spell and dc_ctx.target:is_casting_spell() == true,
    "scenario target is_casting_spell must be true in defensive_casting")
local std_ctx = aud.build_context_for("warrior", build_scenario("standard"))
assert_true(std_ctx.target.is_casting_spell and std_ctx.target:is_casting_spell() == false,
    "scenario target is_casting_spell must be false in standard")
print("PASS: mechanism — scenario target is_casting_spell is bank-aware")

-- ============================================================================
-- warrior/protection: Pummel + SpellReflection (the ranked upgrade targets)
-- ============================================================================
local prot, prot_err, prot_ns = aud.load_spec("warrior", "protection")
assert_true(prot ~= nil, "warrior/protection load failed: " .. tostring(prot_err))
_G.EaxRotations = prot_ns

local pm_ctx, pm_state = assert_lane(prot, prot_ns, "warrior", "defensive_casting", "Pummel", true,
    "prot Pummel must match in defensive_casting (ready + casting target)")
assert_true(pm_state.target_is_casting == true,
    "prot state.target_is_casting must be true in defensive_casting, got "
    .. tostring(pm_state.target_is_casting))
assert_lane(prot, prot_ns, "warrior", "defensive_casting", "SpellReflection", true,
    "prot SpellReflection must match in defensive_casting (pvp + casting target)")
-- Negatives: Pummel needs a casting target; SpellReflection needs is_pvp too
-- (ACTIONS metadata requires_pvp — the target_casting scenario has casting but
-- no pvp, so the metadata guard is exactly what blocks it).
assert_lane(prot, prot_ns, "warrior", "standard", "Pummel", false,
    "prot Pummel must NOT match in standard (no casting target)")
assert_lane(prot, prot_ns, "warrior", "target_casting", "SpellReflection", false,
    "prot SpellReflection must NOT match in target_casting (requires_pvp metadata gate)")
print("PASS: warrior/protection defensive-casting regression (Pummel + SpellReflection)")

-- ============================================================================
-- warrior/arms: Disarm + SpellReflection (is_pvp + defensive-stance combo)
-- ============================================================================
local arms, arms_err, arms_ns = aud.load_spec("warrior", "arms")
assert_true(arms ~= nil, "warrior/arms load failed: " .. tostring(arms_err))
_G.EaxRotations = arms_ns

assert_lane(arms, arms_ns, "warrior", "defensive_casting", "Disarm", true,
    "arms Disarm must match in defensive_casting (is_pvp + defensive stance + player target)")
assert_lane(arms, arms_ns, "warrior", "defensive_casting", "SpellReflection", true,
    "arms SpellReflection must match in defensive_casting (is_pvp + casting + defensive stance)")
-- Negative: the pvp scenario has is_pvp but battle stance (1) — the
-- build_action required_stance = DEFENSIVE gate is what blocks it there.
assert_lane(arms, arms_ns, "warrior", "pvp", "Disarm", false,
    "arms Disarm must NOT match in pvp (battle stance — requires defensive)")
assert_lane(arms, arms_ns, "warrior", "pvp", "SpellReflection", false,
    "arms SpellReflection must NOT match in pvp (battle stance — requires defensive)")
print("PASS: warrior/arms defensive-casting regression (Disarm + SpellReflection)")

-- ============================================================================
-- rogue combat/subtlety: Blind (the pvp_low_hp combo from the triage)
-- ============================================================================
local combat, combat_err, combat_ns = aud.load_spec("rogue", "combat")
assert_true(combat ~= nil, "rogue/combat load failed: " .. tostring(combat_err))
_G.EaxRotations = combat_ns

assert_lane(combat, combat_ns, "rogue", "defensive_casting", "Blind", true,
    "combat Blind must match in defensive_casting (is_pvp + hp <= combat_blind_hp 40)")
assert_lane(combat, combat_ns, "rogue", "pvp", "Blind", false,
    "combat Blind must NOT match in pvp (hp 100 > 40 — hp gate)")
assert_lane(combat, combat_ns, "rogue", "low_self", "Blind", false,
    "combat Blind must NOT match in low_self (not pvp — is_pvp gate)")
print("PASS: rogue/combat Blind regression")

local sub, sub_err, sub_ns = aud.load_spec("rogue", "subtlety")
assert_true(sub ~= nil, "rogue/subtlety load failed: " .. tostring(sub_err))
_G.EaxRotations = sub_ns

assert_lane(sub, sub_ns, "rogue", "defensive_casting", "Blind", true,
    "subtlety Blind must match in defensive_casting (is_pvp + hp <= 35)")
assert_lane(sub, sub_ns, "rogue", "pvp", "Blind", false,
    "subtlety Blind must NOT match in pvp (hp 100 > 35 — hp gate)")
print("PASS: rogue/subtlety Blind regression")

-- ============================================================================
-- Exclusivity: the arms/rogue lanes fire ONLY in defensive_casting.
-- ============================================================================
local function assert_exclusive(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    local fi = report.fires_in[lane]
    assert_true(fi ~= nil, class_key .. "/" .. spec .. " " .. lane .. " missing from fires_in")
    local n = 0
    for k in pairs(fi) do n = n + 1 end
    assert_true(n == 1 and fi.defensive_casting == true,
        class_key .. "/" .. spec .. " " .. lane .. " must fire ONLY in defensive_casting, fired in "
        .. tostring(n) .. " scenarios")
end
assert_exclusive("warrior", "arms", "Disarm")
assert_exclusive("warrior", "arms", "SpellReflection")
-- (b) close-out (2026-08-10): the rogue Blind lanes are is_pvp + hp<=40
-- gated (combat_sylvanas:568-579) and legitimately fire in ANY low-hp PvP
-- scenario — the pvp_pressure_resto scenario (hp 30) added by the (b)
-- campaign is a second such context, so strict single-scenario exclusivity no
-- longer holds by design. Relax to the meaningful contract: fires in
-- defensive_casting and NOT in the plain pvp scenario (hp 100 > 40 — the hp
-- gate), which the per-spec subtlety assertions above already pin.
local function assert_blind_contract(class_key, spec)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    local fi = report.fires_in["Blind"]
    assert_true(fi ~= nil and fi.defensive_casting == true,
        class_key .. "/" .. spec .. " Blind must fire in defensive_casting")
    assert_true(fi.pvp == nil,
        class_key .. "/" .. spec .. " Blind must NOT fire in plain pvp (hp 100 > 40)")
end
assert_blind_contract("rogue", "combat")
assert_blind_contract("rogue", "subtlety")
print("PASS: exclusivity — arms Disarm/SpellReflection only in defensive_casting; Blind fires in defensive_casting + low-hp pvp contexts only")

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
assert_lane_fires("warrior", "protection", "Pummel")
assert_lane_fires("warrior", "protection", "SpellReflection")
assert_lane_fires("warrior", "arms", "Disarm")
assert_lane_fires("warrior", "arms", "SpellReflection")
assert_lane_fires("rogue", "combat", "Blind")
assert_lane_fires("rogue", "subtlety", "Blind")
print("PASS: battery reports none of the 6 defensive-casting lanes as never-firing")
print("ALL PASS: test_defensive_casting_regression")
