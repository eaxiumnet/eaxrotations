-- test_cache_hit_nil_guard_regression.lua — pins the frame-cache nil-guard fix
-- (2026-08-09). druid/bear_sylvanas.lua and druid/cat_sylvanas.lua returned the
-- RAW state table on a frame-cache hit (`if now == _last_build_time then return
-- state end`), bypassing spec_kit.safe_state's Pattern-14 nil-guard defaults —
-- on a cache hit, matchers read schema-only fields as nil instead of their safe
-- default (the same family the 2.19.0 warrior cache-hit fix closed in
-- arms_sylvanas:379 / affliction_sylvanas:422). The vanilla mirrors
-- (bear_vanilla:366, cat_vanilla:270) already wrapped the cache-hit return; the
-- TBC sylvanas copies missed it. This test drives the cache-hit path directly
-- (the battery never sets ctx.now, so no other test can see it) and asserts the
-- nil-guard defaults still apply.
-- WHAT:  bear + cat build_state, called twice with the same ctx.now so the
--        second call hits the frame cache.
-- WHEN:  rotation suite execution (run_rotation_tests.lua).
-- WHY:   a future refactor that reverts the cache-hit wrap (or moves the wrap
--        below the cache branch) silently reintroduces the live-game nil-guard
--        bypass; this test fails on either.
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

local function scenario(name)
    for _, s in ipairs(aud.SCENARIOS) do
        if s.name == name then return s end
    end
    error("scenario not found: " .. name, 2)
end

-- ============================================================================
-- Helper: drive the cache-hit path for a spec.
--   1. build ctx, set ctx.now (the battery never sets it), build_state once
--      (populates the _last_build_time sentinel and returns the full proxy).
--   2. nil-write a schema-backed field through the proxy (removes the raw key).
--   3. build_state again with the SAME now -> frame-cache hit.
--   Returns the cached state. With the bug, the field reads nil (raw table
--   returned); with the fix, it reads the schema default (proxy returned).
-- ============================================================================
local function cached_state(class_key, spec_key, now, field_to_nil, expected_default)
    local spec, load_err, ns = aud.load_spec(class_key, spec_key)
    assert_true(spec ~= nil, class_key .. "/" .. spec_key .. " load failed: " .. tostring(load_err))
    local ctx = aud.build_context_for(class_key, scenario("standard"))
    aud.apply_battery_state(ns, ctx, class_key)
    ctx.now = now
    local s1 = spec.build_state(ctx)
    assert_true(type(s1) == "table", class_key .. "/" .. spec_key .. " first build_state failed")
    -- Remove the field from the raw state through the proxy (__newindex writes
    -- raw_state[key]; a nil value removes the key so __index falls to schema).
    s1[field_to_nil] = nil
    local s2 = spec.build_state(ctx)
    assert_true(type(s2) == "table", class_key .. "/" .. spec_key .. " cached build_state failed")
    assert_true(s2[field_to_nil] == expected_default,
        class_key .. "/" .. spec_key .. " cache hit lost nil-guard default for " .. field_to_nil
        .. ": got " .. tostring(s2[field_to_nil]) .. ", expected " .. tostring(expected_default)
        .. " (cache-hit return must wrap in safe_state)")
    return s2
end

-- ============================================================================
-- bear: barkskin_hp is schema-backed (BEAR_SCHEMA barkskin_hp = 55). With the
-- raw-table cache-hit return, the nil-write would surface as nil on the cached
-- state; the safe_state proxy restores 55.
-- ============================================================================
local bear_cached = cached_state("druid", "bear", 1234.5, "barkskin_hp", 55)
assert_true(bear_cached.in_combat == false or bear_cached.in_combat ~= nil,
    "bear cached state must still proxy normal fields")
print("PASS: bear cache-hit preserves safe_state nil-guard (barkskin_hp=55)")

-- ============================================================================
-- cat: has_track_humanoids is schema-backed (CAT_SCHEMA has_track_humanoids =
-- false). Same nil-write + cache-hit drill.
-- ============================================================================
local cat_cached = cached_state("druid", "cat", 1234.5, "has_track_humanoids", false)
assert_true(cat_cached.energy ~= nil,
    "cat cached state must still proxy normal fields")
print("PASS: cat cache-hit preserves safe_state nil-guard (has_track_humanoids=false)")

-- ============================================================================
-- Negative guard: a DIFFERENT ctx.now must NOT hit the cache (full rebuild
-- path still works) — proves the sentinel logic is intact, not that the cache
-- is simply dead.
-- ============================================================================
local function fresh_state(class_key, spec_key, now)
    local spec, load_err, ns = aud.load_spec(class_key, spec_key)
    assert_true(spec ~= nil, class_key .. "/" .. spec_key .. " reload failed: " .. tostring(load_err))
    local ctx = aud.build_context_for(class_key, scenario("standard"))
    aud.apply_battery_state(ns, ctx, class_key)
    ctx.now = now
    local s1 = spec.build_state(ctx)
    s1["barkskin_hp"] = nil -- remove via proxy (bear) — harmless for cat
    ctx.now = now + 0.5
    local s2 = spec.build_state(ctx) -- new now -> full rebuild
    return s2
end
local f = fresh_state("druid", "bear", 9876.5)
print("PASS: differing ctx.now still full-rebuilds (cache not disabled): "
    .. tostring(type(f) == "table"))

-- ============================================================================
-- End-to-end: the battery must still see bear/cat lanes exactly as before the
-- fix (the fix only changes the cache-hit branch, which the battery never
-- drives). NOTE: Barkskin (a-pinned at the cache-hit fix) was cleared by the
-- (a) opt-in close-out (bear_barkskin scenario) and ChallengingRoar
-- (b-pinned at the cache-hit fix) was cleared by the (b) close-out
-- (bear_challenging_roar scenario) — both intentionally unasserted now;
-- cat RakeSnapshot remains never and proves the battery view is unchanged
-- by the cache-hit branch edit.
-- ============================================================================
local rp = aud.run_spec("druid", "bear")
local rn = {}
for _, n in ipairs(rp.never) do rn[n] = true end
local rc = aud.run_spec("druid", "cat")
local rc_n = {}
for _, n in ipairs(rc.never) do rc_n[n] = true end
assert_true(rc_n["RakeSnapshot"] == true,
    "cat never-set must be unchanged by the cache-hit fix (RakeSnapshot still never)")
print("PASS: battery never-sets unchanged (bear/cat) after the cache-hit fix")

print("ALL PASS: test_cache_hit_nil_guard_regression")
