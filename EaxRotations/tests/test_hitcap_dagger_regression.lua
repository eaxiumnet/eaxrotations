-- test_hitcap_dagger_regression.lua — pins the stat/weapon-mock lanes
-- unblocked by the hit_rating ctx key + equipped_daggers mock (2026-08-08,
-- warrior/rogue focused triage, (c) stat cluster).
-- WHAT:  behavioral_audit.lua gained two scenario keys and two scenarios:
--          hit_rating      (ctx key) — the HitCapPriority matchers
--            (combat/arms/fury, plus the identical shared-matcher copies in
--            hunter/BM, mage/fire, paladin/retri) read context.hit_rating and
--            fire when deficit = state.hit_cap_rating_needed - hit_rating
--            exceeds 30. The cap is 142 (shared/hit_cap_tracker HIT_CAPS
--            warrior_melee/rogue_melee; hunter/mage/paladin read their own
--            caster/melee tables but all equal 142) and the default context
--            had NO rating — so every HitCapPriority lane was never-firing.
--            hit_cap_deficit = { hit_rating = 50 } → deficit 92 > 30.
--          equipped_daggers (ctx key → state bank) — the get_equipped_item_id
--            stub now returns dagger item id 776 (from shared/dagger_set
--            DAGGER_IDS) for MAIN_HAND/OFF_HAND when the flag is set, so assn
--            build_state (assn:234-240 — reads both hands + is_dagger map)
--            derives state.has_daggers = true. Mutilate also needs energy_low
--            false (energy 90 default) + should_spend_energy true (default).
--            mutilate_daggers = { equipped_daggers = true }.
--        All cleared lanes fire EXCLUSIVELY in their scenario (each carries
--        exactly one new key), so they are pinned with fires-in(1) exclusivity
--        + matcher asserts with sharp negatives + end-to-end never-list checks.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit (dropping the keys, the dagger mock, or the
--        scenarios) could silently re-hide these 7 lanes; this test fails if
--        any stops firing or leaks into another scenario.
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
-- Mechanism pin: the hit_rating ctx key + equipped_daggers state-bank flag.
-- ============================================================================
local hd_ctx = aud.build_context_for("warrior", build_scenario("hit_cap_deficit"))
assert_true(hd_ctx.hit_rating == 50,
    "hit_cap_deficit must set ctx.hit_rating 50, got " .. tostring(hd_ctx.hit_rating))
local md_ctx = aud.build_context_for("rogue", build_scenario("mutilate_daggers"))
assert_true(md_ctx.equipped_daggers == true, "mutilate_daggers must set equipped_daggers")
print("PASS: mechanism — hit_rating ctx key + equipped_daggers flag wired")

-- ============================================================================
-- HitCapPriority x3 (the requested lanes): combat / arms / fury
-- ============================================================================
local combat, combat_err, combat_ns = aud.load_spec("rogue", "combat")
assert_true(combat ~= nil, "rogue/combat load failed: " .. tostring(combat_err))
_G.EaxRotations = combat_ns

local hc_ctx, hc_state = assert_lane(combat, combat_ns, "rogue", "hit_cap_deficit", "HitCapPriority", true,
    "combat HitCapPriority must match in hit_cap_deficit (rating 50, deficit 92)")
assert_true((hc_state.hit_cap_rating_needed or 0) >= 100,
    "combat state.hit_cap_rating_needed must be the ~142 cap, got "
    .. tostring(hc_state.hit_cap_rating_needed))
-- Negative: default context has no hit_rating — the stat gate blocks it.
assert_lane(combat, combat_ns, "rogue", "standard", "HitCapPriority", false,
    "combat HitCapPriority must NOT match in standard (no hit_rating)")
-- Deficit boundary: rating 120 → deficit 22 <= 30 — the second matcher branch.
local bd_ctx, bd_state = make_state(combat, combat_ns, "rogue", "standard")
bd_ctx.hit_rating = 120
local bc_s = find_strategy(combat.strategies, "HitCapPriority")
local bc_ok, bc_m = pcall(bc_s.matches, bd_ctx, bd_state)
assert_true(bc_ok and bc_m == false,
    "combat HitCapPriority must NOT match at hit_rating 120 (deficit 22 <= 30)")
print("PASS: rogue/combat HitCapPriority regression")

local arms, arms_err, arms_ns = aud.load_spec("warrior", "arms")
assert_true(arms ~= nil, "warrior/arms load failed: " .. tostring(arms_err))
_G.EaxRotations = arms_ns
assert_lane(arms, arms_ns, "warrior", "hit_cap_deficit", "HitCapPriority", true,
    "arms HitCapPriority must match in hit_cap_deficit")
assert_lane(arms, arms_ns, "warrior", "standard", "HitCapPriority", false,
    "arms HitCapPriority must NOT match in standard (no hit_rating)")
print("PASS: warrior/arms HitCapPriority regression")

local fury, fury_err, fury_ns = aud.load_spec("warrior", "fury")
assert_true(fury ~= nil, "warrior/fury load failed: " .. tostring(fury_err))
_G.EaxRotations = fury_ns
assert_lane(fury, fury_ns, "warrior", "hit_cap_deficit", "HitCapPriority", true,
    "fury HitCapPriority must match in hit_cap_deficit")
assert_lane(fury, fury_ns, "warrior", "standard", "HitCapPriority", false,
    "fury HitCapPriority must NOT match in standard (no hit_rating)")
print("PASS: warrior/fury HitCapPriority regression")

-- ============================================================================
-- rogue/assassination: Mutilate (dagger mock)
-- ============================================================================
local assn, assn_err, assn_ns = aud.load_spec("rogue", "assassination")
assert_true(assn ~= nil, "rogue/assassination load failed: " .. tostring(assn_err))
_G.EaxRotations = assn_ns

local mt_ctx, mt_state = assert_lane(assn, assn_ns, "rogue", "mutilate_daggers", "Mutilate", true,
    "assassination Mutilate must match in mutilate_daggers (daggers equipped + energy 90)")
assert_true(mt_state.has_daggers == true,
    "mutilate_daggers must derive state.has_daggers true, got " .. tostring(mt_state.has_daggers))
assert_true(mt_state.energy_low == false,
    "mutilate_daggers must keep energy_low false (energy 90), got " .. tostring(mt_state.energy_low))
-- Negative: standard context has no daggers (get_equipped_item_id returns 0).
assert_lane(assn, assn_ns, "rogue", "standard", "Mutilate", false,
    "assassination Mutilate must NOT match in standard (no daggers)")
print("PASS: rogue/assassination Mutilate regression (dagger mock)")

-- ============================================================================
-- Exclusivity: HitCapPriority (all 6 shared-matcher lanes) fire ONLY in
-- hit_cap_deficit; Mutilate ONLY in mutilate_daggers.
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
assert_exclusive("rogue", "combat", "HitCapPriority", "hit_cap_deficit")
assert_exclusive("warrior", "arms", "HitCapPriority", "hit_cap_deficit")
assert_exclusive("warrior", "fury", "HitCapPriority", "hit_cap_deficit")
assert_exclusive("rogue", "assassination", "Mutilate", "mutilate_daggers")
-- Bonus lanes sharing the same matcher math (142 cap, rating 50 → deficit 92).
assert_exclusive("hunter", "beast_mastery", "HitCapPriority", "hit_cap_deficit")
assert_exclusive("mage", "fire", "HitCapPriority", "hit_cap_deficit")
assert_exclusive("paladin", "retribution", "HitCapPriority", "hit_cap_deficit")
print("PASS: exclusivity — HitCapPriority x6 + Mutilate fire only in their scenario")

-- ============================================================================
-- End-to-end: the battery must report none of the 7 lanes as never-firing.
-- ============================================================================
local function assert_lane_fires(class_key, spec, lane)
    local report = aud.run_spec(class_key, spec)
    assert_true(report ~= nil, "battery run for " .. class_key .. "/" .. spec .. " failed")
    for _, name in ipairs(report.never) do
        assert_true(name ~= lane,
            "battery still reports " .. class_key .. "/" .. spec .. " " .. lane .. " as never-firing")
    end
end
assert_lane_fires("rogue", "combat", "HitCapPriority")
assert_lane_fires("warrior", "arms", "HitCapPriority")
assert_lane_fires("warrior", "fury", "HitCapPriority")
assert_lane_fires("rogue", "assassination", "Mutilate")
assert_lane_fires("hunter", "beast_mastery", "HitCapPriority")
assert_lane_fires("mage", "fire", "HitCapPriority")
assert_lane_fires("paladin", "retribution", "HitCapPriority")
print("PASS: battery reports none of the 7 hit-cap/dagger lanes as never-firing")
print("ALL PASS: test_hitcap_dagger_regression")
