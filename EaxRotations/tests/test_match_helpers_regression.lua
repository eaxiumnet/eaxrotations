-- test_match_helpers_regression.lua — pins shared/match_helpers_sylvanas.lua.
-- WHAT:  Exercises the ttd_gate predicate (the highest-ROI gate: 43 call sites
--        across 16 spec files) and the module's NS registration behavior.
--        ttd_gate is the canonical replacement for
--        `if context.ttd_known and context.ttd > 0 and context.ttd < N then
--        return false end` — unknown TTD, non-positive TTD, and TTD at or above
--        the threshold all pass; only a known positive TTD below the threshold
--        fails. The module previously had ZERO test references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the gate's boundary handling could silently skip or
--        fire DoTs/spells for dying targets across 16 spec files; this test
--        fails on regressions in the predicate.
-- SAFETY: Pure unit test. The module reads _G.EaxRotations at load only for
--        registration; it is loaded once without NS (early-return path) and
--        once with a mock NS (registration path). No SDK calls; the real SDK
--        is never touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

-- ---------------------------------------------------------------------------
-- 1. Load WITHOUT NS: module returns M, nothing registered, ttd_gate works
-- ---------------------------------------------------------------------------
_G.EaxRotations = nil
local mh = dofile("EaxRotations/shared/match_helpers_sylvanas.lua")
assert_true(type(mh) == "table", "module loads with no NS")
assert_true(type(mh.ttd_gate) == "function", "ttd_gate exported regardless of NS")

-- ---------------------------------------------------------------------------
-- 2. Load WITH NS: module registers itself as NS.match_helpers
-- ---------------------------------------------------------------------------
local mock_ns = {}
_G.EaxRotations = mock_ns
local mh2 = dofile("EaxRotations/shared/match_helpers_sylvanas.lua")
assert_eq(mock_ns.match_helpers, mh2, "module registers itself as NS.match_helpers")
assert_true(type(mh2.ttd_gate) == "function", "second load also exposes ttd_gate (no-NS path returns a fully-formed module)")

-- ---------------------------------------------------------------------------
-- 3. ttd_gate semantics (unknown / non-positive / boundary / thresholds)
-- ---------------------------------------------------------------------------
-- Unknown TTD -> pass.
assert_eq(mh.ttd_gate({ ttd_known = false, ttd = 5 }, 10), true, "unknown TTD passes")
assert_eq(mh.ttd_gate({ ttd_known = false }, 10), true, "unknown TTD with no ttd field passes")

-- Known TTD, nil value -> treated as unknown/high (999 default) -> pass.
assert_eq(mh.ttd_gate({ ttd_known = true }, 10), true, "known flag with nil ttd passes (999 default)")

-- Non-positive TTD -> pass (never skip on non-positive).
assert_eq(mh.ttd_gate({ ttd_known = true, ttd = 0 }, 10), true, "zero TTD passes")
assert_eq(mh.ttd_gate({ ttd_known = true, ttd = -3 }, 10), true, "negative TTD passes")

-- Positive TTD below the threshold -> fail (target dying too soon).
assert_eq(mh.ttd_gate({ ttd_known = true, ttd = 5 }, 10), false, "TTD below threshold fails")

-- Boundary: TTD exactly at the threshold -> pass (strictly-less-than gate).
assert_eq(mh.ttd_gate({ ttd_known = true, ttd = 10 }, 10), true, "TTD == threshold passes (boundary)")

-- TTD above the threshold -> pass.
assert_eq(mh.ttd_gate({ ttd_known = true, ttd = 15 }, 10), true, "TTD above threshold passes")

-- Multiple thresholds on the same context are independent (pure function).
local ctx = { ttd_known = true, ttd = 7 }
assert_eq(mh.ttd_gate(ctx, 5), true, "TTD 7 >= min 5 passes")
assert_eq(mh.ttd_gate(ctx, 10), false, "TTD 7 < min 10 fails")

print("PASS test_match_helpers_regression")
