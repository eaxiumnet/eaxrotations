-- test_arcane_burn_regression.lua — pins the 4 lanes unblocked by the
-- ranked #2 battery upgrade (2026-08-07): the arcane burn-phase model.
-- WHAT:  behavioral_audit.lua now (a) makes `_scenario_me.get_max_power`
--        bank-driven (default 15000 via `max_mana`; previously hardwired 100,
--        so mage/arcane s.max_mana = 100 → mtte_burn ≈ 0.3 < 5 →
--        should_conserve always true → phase could never become "burn"),
--        and (b) adds `burn_ready` (player_mana 45000, ttd 60, AP 12042 on
--        cd) + `burn_coldsnap` (+ IV 12472 on cd) scenarios. With the 15000
--        pool, mtte_burn ≈ 50 ≥ 5; can_burn additionally needs
--        available_mana ≥ 760·ttd/1.5 = 30400 at ttd 60 — available =
--        current_mana + 49·ttd/2 = 45000 + 1470, driven by player_mana 45000
--        (base ctx player_mana 100 → available 1570 < 30400 → can_burn stays
--        false and phase stays conserve in every other scenario).
--        Lanes pinned here (all previously never-firing):
--          ArcanePower    (burn_ready / burn_coldsnap — phase burn, mana 100)
--          PresenceOfMind (burn_ready / burn_coldsnap — AP on cd passes the
--                          ap_on_cd sync gate)
--          IcyVeins       (burn_ready only — burn_coldsnap puts IV on cd, its
--                          own matcher self-blocks on icy_veins_remains > 0)
--          ColdSnapIVReset (burn_coldsnap only — needs IV on cd > 3s + ColdSnap
--                          ready; burn_ready has IV off cd so it stays silent)
--        NOTE on phase stickiness: arcane's build_state keeps a module-level
--        phase (real-engine state machine — once in burn, stay in burn until
--        mana drops), so WITHIN one battery run the burn phase carries into
--        scenarios listed after the first burn-reaching scenario (e.g. burst's
--        buffs_up → bloodlust → can_burn). That is faithful engine behavior,
--        not a mock bug; it only widens fires_in (never shrinks the never-list).
--        The per-lane asserts below therefore use a FRESH module load per
--        section (phase starts conserve) for deterministic match/negative
--        checks, and the end-to-end check asserts intended-scenario firing +
--        IV/ColdSnapIVReset scenario exclusivity (on_cd-driven, leak-proof).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing (mechanism + matcher + negative +
--        end-to-end).
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

local BURN_LANES = { "ArcanePower", "PresenceOfMind", "IcyVeins", "ColdSnapIVReset" }

-- ============================================================================
-- Negatives FIRST (fresh module: phase starts conserve; deterministic — no
-- burn-phase carryover contaminates these).
-- ============================================================================
local neg, neg_err, neg_ns = aud.load_spec("mage", "arcane")
assert_true(neg ~= nil, "mage/arcane load failed: " .. tostring(neg_err))
_G.EaxRotations = neg_ns
-- Fresh module must start in conserve: pin the mechanism before the negatives.
local n_ctx, n_state = make_state(neg, neg_ns, "mage", "standard")
assert_true(n_state.max_mana == 15000,
    "mage/arcane: battery get_max_power must be bank-driven (15000 default), got " .. tostring(n_state.max_mana))
assert_true(n_state.phase == "conserve",
    "mage/arcane: standard must stay conserve with max_mana 15000 + player_mana 100 (available 1570 < 30400), got " .. tostring(n_state.phase))
assert_true(n_state.can_burn == false,
    "mage/arcane: standard can_burn must be false (player_mana 100 too small), got " .. tostring(n_state.can_burn))
for _, lane in ipairs(BURN_LANES) do
    assert_never(neg, neg_ns, "mage", "standard", lane,
        "mage/arcane " .. lane .. " must NOT match in standard (conserve, can_burn false)")
    assert_never(neg, neg_ns, "mage", "low_mana", lane,
        "mage/arcane " .. lane .. " must NOT match in low_mana (mana 10 -> emergency)")
    assert_never(neg, neg_ns, "mage", "ab_stack_conserve", lane,
        "mage/arcane " .. lane .. " must NOT match in ab_stack_conserve (mana 15, conserve phase)")
end
print("PASS: negatives (standard/low_mana/ab_stack_conserve stay conserve; max_mana 15000 mechanism)")

-- ============================================================================
-- Burn mechanism + burn_ready / burn_coldsnap positives (fresh module again so
-- the phase transition is observed from a clean conserve start).
-- ============================================================================
local arc, arc_err, arc_ns = aud.load_spec("mage", "arcane")
assert_true(arc ~= nil, "mage/arcane reload failed: " .. tostring(arc_err))
_G.EaxRotations = arc_ns

local br_ctx, br_state = assert_lane_matches(arc, arc_ns, "mage", "burn_ready", "ArcanePower",
    "mage/arcane ArcanePower must match in burn_ready (phase burn, mana 100)")
assert_true(br_state.phase == "burn",
    "mage/arcane: burn_ready must reach burn phase, got " .. tostring(br_state.phase))
assert_true(br_state.can_burn == true,
    "mage/arcane: burn_ready must have can_burn=true (player_mana 45000 -> available 46470 >= 30400), got " .. tostring(br_state.can_burn))
assert_true(br_state.max_mana == 15000,
    "mage/arcane: burn_ready max_mana must be 15000, got " .. tostring(br_state.max_mana))
assert_true(arc_ns.get_power and arc_ns.get_power(0) == 45000,
    "mage/arcane: burn_ready must drive current_mana via player_mana 45000, got " .. tostring(arc_ns.get_power and arc_ns.get_power(0)))
-- AP on cd (12042) makes PoM's ap_on_cd sync gate pass.
assert_true(arc_ns.cooldown_remains(12042) > 0,
    "mage/arcane: burn_ready must put ArcanePower (12042) on cd for PoM's sync gate")
assert_lane_matches(arc, arc_ns, "mage", "burn_ready", "PresenceOfMind",
    "mage/arcane PresenceOfMind must match in burn_ready (burn + AP on cd)")
assert_lane_matches(arc, arc_ns, "mage", "burn_ready", "IcyVeins",
    "mage/arcane IcyVeins must match in burn_ready (burn, IV off cd)")
assert_never(arc, arc_ns, "mage", "burn_ready", "ColdSnapIVReset",
    "mage/arcane ColdSnapIVReset must NOT match in burn_ready (IV off cd -> icy_veins_remains 0)")

-- burn_coldsnap: IV on cd > 3s + ColdSnap ready -> ColdSnapIVReset fires; the
-- IV lane itself self-blocks (its matcher needs IV not on cd).
local bc_ctx, bc_state = assert_lane_matches(arc, arc_ns, "mage", "burn_coldsnap", "ColdSnapIVReset",
    "mage/arcane ColdSnapIVReset must match in burn_coldsnap (IV on cd 180 > 3, ColdSnap ready)")
assert_true(bc_state.phase == "burn",
    "mage/arcane: burn_coldsnap must reach burn phase, got " .. tostring(bc_state.phase))
assert_true((bc_state.icy_veins_remains or 0) > 3,
    "mage/arcane: burn_coldsnap must set icy_veins_remains > 3 (IV 12472 on cd), got " .. tostring(bc_state.icy_veins_remains))
assert_lane_matches(arc, arc_ns, "mage", "burn_coldsnap", "ArcanePower",
    "mage/arcane ArcanePower must still match in burn_coldsnap (burn phase)")
assert_never(arc, arc_ns, "mage", "burn_coldsnap", "IcyVeins",
    "mage/arcane IcyVeins must NOT match in burn_coldsnap (IV on cd self-block)")
print("PASS: burn_ready + burn_coldsnap (ArcanePower/PoM/IcyVeins/ColdSnapIVReset)")

-- ============================================================================
-- End-to-end battery check: none of the 4 lanes may appear in the never-list;
-- IV and ColdSnapIVReset must be scenario-exclusive (on_cd-driven and
-- leak-proof). ArcanePower/PoM also fire in burn_coldsnap (and in later
-- scenarios after the sticky burn phase — engine-faithful, so no strict
-- exclusivity is asserted for them; their burn-scenario firing is).
-- ============================================================================
local report = aud.run_spec("mage", "arcane")
assert_true(report ~= nil, "battery run for mage/arcane failed")
assert_true(#report.dispatch_errors == 0,
    "mage/arcane battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
for _, lane in ipairs(BURN_LANES) do
    local is_never = false
    for _, name in ipairs(report.never) do
        if name == lane then is_never = true end
    end
    assert_true(not is_never, "battery still reports mage/arcane " .. lane .. " as never-firing")
end
-- Intended-scenario firing (burn_ready for AP/PoM/IV, burn_coldsnap for CSIVR).
assert_true(report.fires_in["ArcanePower"] and report.fires_in["ArcanePower"]["burn_ready"],
    "ArcanePower must fire in burn_ready")
assert_true(report.fires_in["PresenceOfMind"] and report.fires_in["PresenceOfMind"]["burn_ready"],
    "PresenceOfMind must fire in burn_ready")
assert_true(report.fires_in["IcyVeins"] and report.fires_in["IcyVeins"]["burn_ready"],
    "IcyVeins must fire in burn_ready")
assert_true(report.fires_in["ColdSnapIVReset"] and report.fires_in["ColdSnapIVReset"]["burn_coldsnap"],
    "ColdSnapIVReset must fire in burn_coldsnap")
-- On-cd-driven exclusivity: IV not in burn_coldsnap, CSIVR not in burn_ready.
assert_true(report.fires_in["IcyVeins"]["burn_coldsnap"] ~= true,
    "IcyVeins must NOT fire in burn_coldsnap (IV on cd self-block)")
assert_true(report.fires_in["ColdSnapIVReset"]["burn_ready"] ~= true,
    "ColdSnapIVReset must NOT fire in burn_ready (IV off cd)")
print("PASS: end-to-end battery check (4 burn lanes not never-firing; IV/CSIVR scenario-exclusive)")
print("ALL PASS: ranked #2 arcane burn-phase regression")
