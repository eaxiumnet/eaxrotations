-- test_multidot_lane_regression.lua — pins the 11 multi-DoT spread lanes
-- unblocked by the ranked-#1 battery upgrade (2026-08-07).
-- WHAT:  behavioral_audit.lua now (a) preloads a state-bank-backed
--        `shared/ts_helper_sylvanas` stub whose get_dps_targets returns the
--        scenario's ctx.enemies (populated for 2+ enemy scenarios), and
--        (b) makes ns.debuff_up/ns.debuff_remains unit-aware: the
--        `debuff_remains_map` override ({ [debuff_id] = seconds }) marks the
--        PRIMARY target as carrying those debuffs while peers stay clean —
--        previously buffs_up marked EVERY target dotted, deadlocking the
--        spreads (primary-dot gate passes but find_dot_target sees the peer
--        as already-dotted). New scenarios (95 total): multidot (2 enemies,
--        primary carries the warlock/balance DoTs, ttd 30 → auto-agony),
--        shadow_multidot (shadow_multidot_mode = 2), shadow_cleave
--        (shadow_combat_mode = "cleave", 3 enemies). balance's spreads also
--        needed NS.DruidSpells.Moonfire/InsectSwarm seeded (the spread
--        matchers gate on SPELLS.Moonfire existing).
--        Lanes pinned here (all previously never-firing):
--          warlock/affliction CorruptionSpread / ImmolateSpread /
--            SiphonLifeSpread / UnstableAfflictionSpread / CurseOfAgonySpread
--                                                            (multidot)
--          priest/shadow MultiDotSWP / MultiDotVT        (shadow_multidot)
--          priest/shadow SWPSpread / VTSpread  (shadow_cleave — also fires in
--            target_melee: shadow's combat_mode AUTO-DETECTS cleave at 3+
--            enemies, which is realistic, not a leak)
--          druid/balance InsectSwarmSpread / MoonfireSpread (multidot)
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
-- Mechanism pins: TSHelper stub + unit-aware debuff model (warlock/affliction
-- in the multidot scenario).
-- ============================================================================
local affl, affl_err, affl_ns = aud.load_spec("warlock", "affliction")
assert_true(affl ~= nil, "warlock/affliction load failed: " .. tostring(affl_err))
_G.EaxRotations = affl_ns

local a_ctx, a_state = make_state(affl, affl_ns, "warlock", "multidot")
assert_true(type(a_ctx.enemies) == "table" and #a_ctx.enemies == 2,
    "warlock: multidot scenario must present 2 enemies, got " .. tostring(#(a_ctx.enemies or {})))
assert_true(a_ctx.enemies[1] == a_ctx.target,
    "warlock: ctx.enemies[1] must be the primary target (TSHelper stub skips it)")
assert_true(affl_ns.debuff_up(a_ctx.enemies[1], { 27216 }) == true,
    "warlock: debuff_remains_map must mark the PRIMARY as carrying Corruption")
assert_true(affl_ns.debuff_up(a_ctx.enemies[2], { 27216 }) == false,
    "warlock: the peer enemy must stay CLEAN (unit-aware debuff_up)")
assert_true(affl_ns.debuff_remains(a_ctx.enemies[1], { 27216 }) == 8,
    "warlock: debuff_remains(primary, Corruption) must return the map value 8")
assert_true(affl_ns.debuff_remains(a_ctx.enemies[2], { 27216 }) == 0,
    "warlock: debuff_remains(peer) must be 0")
assert_true(a_state.corruption_remains == 8,
    "warlock: build_state must consume the map for corruption_remains, got "
    .. tostring(a_state.corruption_remains))
-- TSHelper stub: the bank holds ctx.enemies and the spec's find_dot_target
-- must pick the peer (primary is dotted).
assert_true(type(affl_ns._bstate("enemies")) == "table" and #affl_ns._bstate("enemies") == 2,
    "warlock: TSHelper stub must be backed by the state-bank enemies list")

-- ============================================================================
-- Warlock spreads (multidot)
-- ============================================================================
assert_lane_matches(affl, affl_ns, "warlock", "multidot", "CorruptionSpread",
    "warlock/affl CorruptionSpread must match in multidot (primary dotted, peer clean)")
assert_lane_matches(affl, affl_ns, "warlock", "multidot", "ImmolateSpread",
    "warlock/affl ImmolateSpread must match in multidot")
assert_lane_matches(affl, affl_ns, "warlock", "multidot", "SiphonLifeSpread",
    "warlock/affl SiphonLifeSpread must match in multidot")
assert_lane_matches(affl, affl_ns, "warlock", "multidot", "UnstableAfflictionSpread",
    "warlock/affl UnstableAfflictionSpread must match in multidot")
assert_lane_matches(affl, affl_ns, "warlock", "multidot", "CurseOfAgonySpread",
    "warlock/affl CurseOfAgonySpread must match in multidot (ttd 30 → auto-agony)")
assert_never(affl, affl_ns, "warlock", "standard", "CorruptionSpread",
    "warlock/affl CorruptionSpread must NOT match in standard (1 enemy, no dot map)")
assert_never(affl, affl_ns, "warlock", "standard", "CurseOfAgonySpread",
    "warlock/affl CurseOfAgonySpread must NOT match in standard")
-- Deadlock guard: with buffs_up (no dot map) the primary's dots are "up" but
-- so is the peer's, so find_dot_target finds nothing — the lanes must stay
-- silent rather than mis-fire.
local deadlock = { name = "custom_deadlock", overrides = { enemy_count = 2, enemies_count = 2, target_hp = 60, ttd = 30, buffs_up = true } }
local d_ctx = aud.build_context_for("warlock", deadlock)
aud.apply_battery_state(affl_ns, d_ctx, "warlock")
local d_state = affl.build_state(d_ctx)
for _, lane in ipairs({ "CorruptionSpread", "ImmolateSpread", "SiphonLifeSpread", "UnstableAfflictionSpread", "CurseOfAgonySpread" }) do
    local s = find_strategy(affl.strategies, lane)
    local ok, m = pcall(s.matches, d_ctx, d_state)
    assert_true(ok and m ~= true, "warlock/affl " .. lane .. " must stay silent under buffs_up deadlock (peer would be dotted)")
end
print("PASS: warlock/affliction 5 spread lanes + TSHelper/debuff-map mechanism")

-- ============================================================================
-- Shadow MultiDot (shadow_multidot) + SWP/VT Spread (shadow_cleave)
-- ============================================================================
local shd, shd_err, shd_ns = aud.load_spec("priest", "shadow")
assert_true(shd ~= nil, "priest/shadow load failed: " .. tostring(shd_err))
_G.EaxRotations = shd_ns

local sm_ctx, sm_state = assert_lane_matches(shd, shd_ns, "priest", "shadow_multidot", "MultiDotSWP",
    "priest/shadow MultiDotSWP must match in shadow_multidot (shadow_multidot_mode=2)")
assert_true(sm_state.multidot_mode == 2,
    "priest/shadow: fixture must set multidot_mode=2, got " .. tostring(sm_state.multidot_mode))
assert_lane_matches(shd, shd_ns, "priest", "shadow_multidot", "MultiDotVT",
    "priest/shadow MultiDotVT must match in shadow_multidot")
local sc_ctx, sc_state = assert_lane_matches(shd, shd_ns, "priest", "shadow_cleave", "SWPSpread",
    "priest/shadow SWPSpread must match in shadow_cleave (3 enemies, cleave mode)")
assert_true(sc_state.combat_mode == "cleave",
    "priest/shadow: shadow_combat_mode=cleave must drive combat_mode, got "
    .. tostring(sc_state.combat_mode))
assert_lane_matches(shd, shd_ns, "priest", "shadow_cleave", "VTSpread",
    "priest/shadow VTSpread must match in shadow_cleave")
-- combat_mode auto-detect: 3+ enemies → cleave even without the setting, so
-- SWPSpread also fires in target_melee (realistic). But NOT in a 2-enemy
-- scenario (shadow_multidot auto-detects "st").
assert_lane_matches(shd, shd_ns, "priest", "target_melee", "SWPSpread",
    "priest/shadow SWPSpread must also fire in target_melee (auto-detect cleave at 3 enemies)")
assert_never(shd, shd_ns, "priest", "shadow_multidot", "SWPSpread",
    "priest/shadow SWPSpread must NOT match in shadow_multidot (2 enemies → auto 'st')")
assert_never(shd, shd_ns, "priest", "standard", "MultiDotSWP",
    "priest/shadow MultiDotSWP must NOT match in standard (multidot_mode off)")
print("PASS: priest/shadow MultiDotSWP/VT + SWPSpread/VTSpread")

-- ============================================================================
-- Balance spreads (multidot) — DruidSpells.Moonfire/InsectSwarm seed + the
-- same TSHelper/debuff-map mechanism; balance_multidot_enabled opt-in.
-- ============================================================================
local bal, bal_err, bal_ns = aud.load_spec("druid", "balance")
assert_true(bal ~= nil, "druid/balance load failed: " .. tostring(bal_err))
_G.EaxRotations = bal_ns
assert_true(bal_ns.DruidSpells and bal_ns.DruidSpells.Moonfire ~= nil and bal_ns.DruidSpells.InsectSwarm ~= nil,
    "druid/balance: battery must seed DruidSpells.Moonfire/InsectSwarm (spread matchers gate on SPELLS.*)")
local mb_ctx, mb_state = assert_lane_matches(bal, bal_ns, "druid", "multidot", "MoonfireSpread",
    "druid/balance MoonfireSpread must match in multidot (balance_multidot_enabled + dot map)")
assert_true(mb_ctx.settings.balance_multidot_enabled == true,
    "druid/balance: fixture must merge balance_multidot_enabled=true")
assert_lane_matches(bal, bal_ns, "druid", "multidot", "InsectSwarmSpread",
    "druid/balance InsectSwarmSpread must match in multidot")
assert_never(bal, bal_ns, "druid", "standard", "MoonfireSpread",
    "druid/balance MoonfireSpread must NOT match in standard (opt-in off)")
assert_never(bal, bal_ns, "druid", "shadow_multidot", "MoonfireSpread",
    "druid/balance MoonfireSpread must NOT match in shadow_multidot (no Moonfire in its dot map)")
print("PASS: druid/balance InsectSwarmSpread + MoonfireSpread")

-- ============================================================================
-- End-to-end: the battery must report each cleared lane as firing — and only
-- in its intended scenario(s). SWPSpread/VTSpread fire in shadow_cleave AND
-- target_melee (3+ enemies auto-detects cleave) — assert the intended one is
-- present and 2-enemy scenarios are absent, rather than single-scenario
-- exclusivity.
-- ============================================================================
local end_to_end = {
    { "warlock", "affliction", { "CorruptionSpread", "ImmolateSpread", "SiphonLifeSpread", "UnstableAfflictionSpread", "CurseOfAgonySpread" }, "multidot", true },
    { "priest", "shadow", { "MultiDotSWP", "MultiDotVT" }, "shadow_multidot", true },
    { "priest", "shadow", { "SWPSpread", "VTSpread" }, "shadow_cleave", false },
    { "druid", "balance", { "InsectSwarmSpread", "MoonfireSpread" }, "multidot", true },
}
local done = {}
for _, kv in ipairs(end_to_end) do
    local class_key, spec_key, lanes, want, exclusive = kv[1], kv[2], kv[3], kv[4], kv[5]
    local key = class_key .. "/" .. spec_key
    if not done[key] then
        local report = aud.run_spec(class_key, spec_key)
        assert_true(report ~= nil, "battery run for " .. key .. " failed")
        assert_true(#report.dispatch_errors == 0,
            key .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))
        done[key] = report
    end
    local report = done[key]
    for _, lane in ipairs(lanes) do
        local is_never = false
        for _, name in ipairs(report.never) do
            if name == lane then is_never = true end
        end
        assert_true(not is_never, "battery still reports " .. key .. " " .. lane .. " as never-firing")
        local fi = report.fires_in[lane]
        assert_true(type(fi) == "table" and fi[want] == true,
            key .. " " .. lane .. " must fire in the " .. want .. " scenario")
        if exclusive then
            local count = 0
            for _ in pairs(fi) do count = count + 1 end
            assert_true(count == 1,
                key .. " " .. lane .. " must fire ONLY in " .. want .. ", got " .. count .. " scenarios")
        else
            assert_true(fi["shadow_multidot"] ~= true,
                key .. " " .. lane .. " must NOT fire in a 2-enemy scenario (shadow_multidot)")
        end
    end
end
print("PASS: end-to-end battery check (11 lanes, scenario exclusivity)")
