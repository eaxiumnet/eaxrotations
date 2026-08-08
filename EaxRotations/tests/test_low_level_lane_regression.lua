-- test_low_level_lane_regression.lua — pins the lanes unblocked by the
-- ranked #9 battery upgrade (2026-08-07): a `low_level` scenario plus a
-- scenario-aware learned/exists mock.
-- WHAT:  behavioral_audit.lua now (a) makes ns.spell_exists and
--        ns.is_spell_learned read a `not_learned` state-bank map (default:
--        everything learned, byte-identical to before) and (b) adds a
--        `low_level` scenario (level 20, is_leveling, OOC, no pet,
--        not_learned = { ArcaneBlast 30451, MageArmor 27125/6117,
--        SummonFelguard 30146 }). That makes the pre-level fallbacks
--        observable:
--          mage/arcane    FireballLeveling  (is_leveling + spell_exists(AB) false)
--          mage/arcane    FrostboltLeveling (same shared matcher)
--          mage/frost     FrostArmor        (MageArmor not learned — pre-34)
--          warlock/demo   SummonImp         (Felguard not learned + Imp learned,
--                                           OOC, no pet)
--        These were invisible because the learned/exists mocks were always
--        true; each lane fires ONLY in low_level (probe-verified).
-- WHEN:  rotation suite execution.
-- WHY:   a future battery edit could silently re-hide these lanes; this test
--        fails if any stops firing in low_level or leaks into other scenarios.
-- SAFETY: Pure unit test with the behavioral_audit mock; no game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local aud = require("tests.behavioral_audit")

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

local CLEARED = {
    { "mage",     "arcane",     "FireballLeveling" },
    { "mage",     "arcane",     "FrostboltLeveling" },
    { "mage",     "frost",      "FrostArmor" },
    { "warlock",  "demonology", "SummonImp" },
}

-- ============================================================================
-- End-to-end: run the real battery per affected spec; every cleared lane must
-- (a) not be never-firing, (b) fire in low_level, and (c) fire in exactly ONE
-- scenario (exclusivity — the leveling fallbacks must not light up elsewhere).
-- ============================================================================
local done = {}
for _, c in ipairs(CLEARED) do
    local class_key, spec, lane = c[1], c[2], c[3]
    local key = class_key .. "/" .. spec
    if not done[key] then
        local report = aud.run_spec(class_key, spec)
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
    assert_true(type(fi) == "table" and fi.low_level == true,
        key .. " " .. lane .. " must fire in the low_level scenario")
    local count = 0
    for _ in pairs(fi) do count = count + 1 end
    assert_true(count == 1,
        key .. " " .. lane .. " must fire ONLY in low_level, got " .. count .. " scenarios")
end
print("PASS: end-to-end battery check (4 low-level lanes, exclusive firing)")

-- ============================================================================
-- Mechanism pin: the not_learned map flows into ctx and the learned/exists
-- mocks respect it; the low_level context then satisfies each matcher.
-- ============================================================================
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

local low = scenario_by_name("low_level")
assert_true(low ~= nil, "low_level scenario missing")
local ctx = aud.build_context_for("mage", low)
assert_true(ctx.is_leveling == true, "low_level must set is_leveling")
assert_true(type(ctx.not_learned) == "table" and ctx.not_learned[30451] == true,
    "low_level must mark ArcaneBlast (30451) not learned")

local result, load_err, ns = aud.load_spec("mage", "arcane")
assert_true(result ~= nil, "load mage/arcane failed: " .. tostring(load_err))
aud.apply_battery_state(ns, ctx, "mage")
assert_true(ns.is_spell_learned({ ids = { 30451 } }) == false,
    "is_spell_learned must be false for ArcaneBlast in low_level")
assert_true(ns.spell_exists({ ids = { 30451 } }) == false,
    "spell_exists must be false for ArcaneBlast in low_level")
assert_true(ns.is_spell_learned({ ids = { 27125 } }) == false,
    "is_spell_learned must be false for MageArmor in low_level")
assert_true(ns.is_spell_learned({ ids = { 688 } }) == true,
    "is_spell_learned must still be true for SummonImp in low_level")
assert_true(ns.is_spell_learned({ ids = { 133 } }) == true,
    "is_spell_learned must be true for unlisted spells (default learned)")
local st = result.build_state(ctx)
local fbl = strategy_by_name(result.strategies or result, "FireballLeveling")
local ok_f, mf = pcall(fbl.matches, ctx, st)
assert_true(ok_f and mf, "mage/arcane FireballLeveling must match in low_level context")
print("PASS: mechanism pin (not_learned map reaches learned/exists + FireballLeveling)")

-- Frost: FrostArmor fires when MageArmor is not learned.
local f_ctx = aud.build_context_for("mage", low)
local f_result, f_err, f_ns = aud.load_spec("mage", "frost")
assert_true(f_result ~= nil, "load mage/frost failed: " .. tostring(f_err))
aud.apply_battery_state(f_ns, f_ctx, "mage")
local f_st = f_result.build_state(f_ctx)
assert_true(f_st.has_any_armor == false, "low_level must have no armor buff active")
local fa = strategy_by_name(f_result.strategies or f_result, "FrostArmor")
local ok_a, ma = pcall(fa.matches, f_ctx, f_st)
assert_true(ok_a and ma, "mage/frost FrostArmor must match in low_level context")
print("PASS: mechanism pin (FrostArmor fallback with MageArmor unlearned)")

-- Warlock: SummonImp fallback when Felguard is not learned, OOC, no pet.
local w_ctx = aud.build_context_for("warlock", low)
local w_result, w_err, w_ns = aud.load_spec("warlock", "demonology")
assert_true(w_result ~= nil, "load warlock/demonology failed: " .. tostring(w_err))
aud.apply_battery_state(w_ns, w_ctx, "warlock")
assert_true(w_ctx.in_combat == false, "low_level must be out of combat")
local si = strategy_by_name(w_result.strategies or w_result, "SummonImp")
local ok_s, ms = pcall(si.matches, w_ctx, w_ctx)
assert_true(ok_s and ms, "warlock/demonology SummonImp must match in low_level context")
print("PASS: mechanism pin (SummonImp fallback, OOC, no pet)")

print("ALL PASS: ranked #9 low-level lanes regression")
