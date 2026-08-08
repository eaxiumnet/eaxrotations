-- test_shadowward_lane_regression.lua — pins the lanes unblocked by the
-- campaign ranked-(b) #1 battery upgrade (2026-08-08):
--   warlock/affliction + warlock/demonology  ShadowWard  (shadow_caster scenario)
-- WHAT:  behavioral_audit.lua adds the shadow_caster scenario
--        ({ is_pvp = true, target_class = 9, hp = 50, player_hp = 50 }),
--        REUSING the pvp_disarm `target_class` -> `target:get_class()`
--        mechanism. The shared matcher
--        (shared/warlock_shadow_ward_sylvanas.lua:19-51) requires
--        in_combat + hp <= shadow_ward_hp (default 70) + a shadow-caster
--        target class in SHADOW_CASTER_CLASS_IDS {5,9} (pcall
--        target:get_class() when enemy_shadow_caster unset) + is_pvp for
--        affliction's use_group_aware gate (demo skips that gate). Class 9
--        is NOT in prot DISARM_CLASS_IDS {1,2,4,7}, so Disarm stays blocked;
--        hunter ViperSting's string-class guard skips numeric ids.
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if ShadowWard stops firing in shadow_caster or leaks into
--        another scenario.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- End-to-end: ShadowWard must not be never-firing in EITHER warlock spec, and
-- must fire ONLY in shadow_caster in both.
-- ============================================================================
for _, spec in ipairs({ { "warlock", "affliction" }, { "warlock", "demonology" } }) do
    local report = aud.run_spec(spec[1], spec[2])
    assert_true(report ~= nil, "battery run for " .. spec[1] .. "/" .. spec[2] .. " failed")
    assert_true(#report.dispatch_errors == 0,
        spec[1] .. "/" .. spec[2] .. " battery dispatch errors: " .. table.concat(report.dispatch_errors, "; "))

    local is_never = false
    for _, name in ipairs(report.never) do
        if name == "ShadowWard" then is_never = true end
    end
    assert_true(not is_never, "battery still reports " .. spec[1] .. "/" .. spec[2] .. " ShadowWard as never-firing")

    local fi = report.fires_in["ShadowWard"]
    assert_true(type(fi) == "table" and fi["shadow_caster"] == true,
        spec[1] .. "/" .. spec[2] .. " ShadowWard must fire in the shadow_caster scenario")
    local count = 0
    for _ in pairs(fi) do count = count + 1 end
    assert_true(count == 1,
        spec[1] .. "/" .. spec[2] .. " ShadowWard must fire ONLY in shadow_caster, got " .. count .. " scenarios")
    print("PASS: end-to-end battery check (" .. spec[1] .. " ShadowWard exclusive to shadow_caster)")
end

-- ============================================================================
-- Cross-scenario negatives: is_pvp alone, or a non-shadow-caster class, must
-- block everywhere else.
-- ============================================================================
local rp = aud.run_spec("warlock", "affliction")
assert_true(not rp.fires_in["ShadowWard"]["pvp_disarm"],
    "ShadowWard must NOT fire in pvp_disarm (target_class 1 -> not in {5,9})")
assert_true(not rp.fires_in["ShadowWard"]["purge_buffed"],
    "ShadowWard must NOT fire in purge_buffed (is_pvp but no target_class -> get_class nil)")
assert_true(not rp.fires_in["ShadowWard"]["defensive_casting"],
    "ShadowWard must NOT fire in defensive_casting (is_pvp + hp 15 but no shadow-caster class)")
assert_true(not rp.fires_in["ShadowWard"]["threat_high"],
    "ShadowWard must NOT fire in threat_high (no is_pvp/class)")
print("PASS: cross-scenario negatives (class/is_pvp gates block)")

-- ============================================================================
-- Mechanism pins — shadow_caster context drives ShadowWard:
--   1. ctx.is_pvp true -> affliction's use_group_aware gate passes (demo skips).
--   2. ctx.target_class 9 -> target:get_class() = 9 in SHADOW_CASTER_CLASS_IDS.
--   3. ctx.hp 50 <= shadow_ward_hp (70) threshold.
-- ============================================================================
local result, load_err, ns = aud.load_spec("warlock", "affliction")
assert_true(result ~= nil, "load warlock/affliction failed: " .. tostring(load_err))
local function scenario_by_name(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
end
local function strategy_by_name(strats, name)
    for _, s in ipairs(strats) do
        if s.name == name then return s end
    end
end

local scen = scenario_by_name("shadow_caster")
assert_true(scen ~= nil, "shadow_caster scenario missing")
local ctx = aud.build_context_for("warlock", scen)
aud.apply_battery_state(ns, ctx, "warlock")
assert_true(ctx.is_pvp == true, "ctx.is_pvp must be true in shadow_caster")
assert_true(ctx.target_class == 9, "ctx.target_class must be 9 in shadow_caster")
assert_true(ctx.hp == 50, "ctx.hp must be 50 in shadow_caster")

-- get_class mechanism: the SAME context the matcher receives exposes
-- get_class = 9 (pvp_disarm mechanism reuse).
local class_id
pcall(function() class_id = ctx.target.get_class and ctx.target:get_class() end)
assert_true(class_id == 9, "scenario target:get_class() must be 9 (pvp_disarm mechanism reuse)")

local strat = strategy_by_name(result.strategies or result, "ShadowWard")
assert_true(strat ~= nil, "affliction ShadowWard strategy not found")
local ok_m, m = pcall(strat.matches, ctx, {})
assert_true(ok_m and m, "warlock/affliction ShadowWard must match in shadow_caster context")

-- Sharp negatives: (a) same is_pvp + hp but target_class absent -> get_class
-- nil -> blocked; (b) target_class = 1 (warrior) -> blocked.
local ctxA = aud.build_context_for("warlock", {
    name = "no_class", overrides = { is_pvp = true, hp = 50, player_hp = 50 },
})
aud.apply_battery_state(ns, ctxA, "warlock")
local okA, mA = pcall(strat.matches, ctxA, {})
assert_true(okA and not mA, "ShadowWard must NOT match without a shadow-caster class")

local ctxB = aud.build_context_for("warlock", scenario_by_name("pvp_disarm"))
aud.apply_battery_state(ns, ctxB, "warlock")
local okB, mB = pcall(strat.matches, ctxB, {})
assert_true(okB and not mB, "ShadowWard must NOT match with target_class 1 (warrior)")
print("PASS: mechanism pins (is_pvp + target_class 9 + hp 50 -> match; no class / class 1 block)")

-- ============================================================================
-- Collateral: lanes that must NOT fire in shadow_caster.
-- ============================================================================
assert_true(not rp.fires_in["Soulshatter"]["shadow_caster"],
    "Soulshatter must NOT fire in shadow_caster (no threat_pct/has_aggro)")
local rprot = aud.run_spec("warrior", "protection")
assert_true(not rprot.fires_in["Disarm"]["shadow_caster"],
    "prot Disarm must NOT fire in shadow_caster (class 9 not in DISARM_CLASS_IDS)")
local rcomb = aud.run_spec("rogue", "combat")
assert_true(not rcomb.fires_in["Blind"]["shadow_caster"],
    "combat Blind must NOT fire in shadow_caster (hp 50 above its low-hp gate)")
local rpriest = aud.run_spec("priest", "shadow")
assert_true(not rpriest.fires_in["Fade"]["shadow_caster"],
    "shadow Fade must NOT fire in shadow_caster (no threat_pct/has_aggro)")
print("PASS: collateral negatives (Soulshatter/Disarm/Blind/Fade stay silent)")

print("ALL PASS: test_shadowward_lane_regression")
