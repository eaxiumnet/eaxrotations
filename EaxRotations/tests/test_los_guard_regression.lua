-- test_los_guard_regression.lua — pins shared/los_guard_sylvanas.lua.
-- WHAT:  Exercises the line-of-sight guard: the same_unit nil-guard (the
--        NS.same_unit field is NEVER assigned in this repo — every other call
--        site guards it, and los_guard:101 called it unguarded, crashing
--        every non-self try_cast via core_sylvanas:2301-2303), the 100ms
--        cache TTL, the 64-entry FIFO eviction, the los_to / graphics LOS
--        fallback chain, non-boolean and throwing API handling, the
--        core.object_manager caster fallback, the no-caster assume-LOS path,
--        and M.clear(). The module is wired into every non-self try_cast and
--        previously had ZERO test references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the cache TTL / FIFO eviction / fallback chain could
--        silently block or unblock casts per frame; this test fails on
--        regressions — and pins that check() never raises on an absent
--        same_unit (the 2026-08-10 crash fix).
-- SAFETY: Pure unit test. The module caches NS and core at load (table
--        references, not copies), so the mock NS/core tables are installed
--        BEFORE dofile and mutated in place; the real SDK is never touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local now = 0.0
local player_los_calls = 0
local player_unit = {
    name = "Me",
    los_to = function()
        player_los_calls = player_los_calls + 1
        return false
    end,
}

-- Mock NS: same_unit intentionally ABSENT at load (matches the repo's own
-- dependency graph — the crash the fix removes). core is a table reference so
-- fields can be mutated in place after dofile (the module caches _core).
local core_tbl = {}
_G.core = core_tbl

local NS = {
    time_now = function() return now end,
    GetPlayer = function() return player_unit end,
}
_G.EaxRotations = NS

local lg = dofile("EaxRotations/shared/los_guard_sylvanas.lua")
assert_true(type(lg) == "table", "los_guard must load under mock NS")
assert_eq(NS.LosGuard, lg, "module registers itself as NS.LosGuard")

-- ---------------------------------------------------------------------------
-- 1. Nil target -> trivially in LOS, no caster resolution
-- ---------------------------------------------------------------------------
assert_eq(lg.check(nil), true, "nil target is trivially in LOS")

-- ---------------------------------------------------------------------------
-- 2. THE CRASH REGRESSION: same_unit absent + no LOS APIs -> true, no crash.
--    (Before the fix this raised "attempt to call a nil value (field
--    'same_unit')" — reproduced at los_guard:101 under this exact graph.)
-- ---------------------------------------------------------------------------
assert_eq(lg.check({}), true, "same_unit absent: no crash, assume LOS when no API")

-- ---------------------------------------------------------------------------
-- 3. same_unit absent -> check falls through to los_to (observable result)
-- ---------------------------------------------------------------------------
local los_a_calls = 0
local los_a_result = false
local target_a = {
    los_to = function()
        los_a_calls = los_a_calls + 1
        return los_a_result
    end,
}
assert_eq(lg.check(target_a), false, "same_unit absent: falls through to los_to (LOS fail)")
assert_eq(los_a_calls, 1, "los_to consulted exactly once")

-- ---------------------------------------------------------------------------
-- 4. Cache TTL (100ms): same pair within TTL reuses the cached result
-- ---------------------------------------------------------------------------
assert_eq(lg.check(target_a), false, "cache hit within TTL returns cached result")
assert_eq(los_a_calls, 1, "los_to NOT re-called on cache hit")

-- ---------------------------------------------------------------------------
-- 5. Cache expiry: advance the clock past TTL -> re-evaluates
-- ---------------------------------------------------------------------------
now = 0.2
los_a_result = true
assert_eq(lg.check(target_a), true, "expired cache re-evaluates (result now true)")
assert_eq(los_a_calls, 2, "los_to re-called after TTL expiry")

-- ---------------------------------------------------------------------------
-- 6. same_unit PRESENT: the self-cast shortcut returns true WITHOUT calling
--    any LOS API. player_unit carries a los_to counter so this assertion is
--    non-vacuous: if the shortcut were removed, check(player_unit) would fall
--    through to los_to (counter -> 1) and the assert would fail.
-- ---------------------------------------------------------------------------
NS.same_unit = function(a, b) return a == b end
assert_eq(lg.check(player_unit), true, "self-cast shortcut returns true")
assert_eq(player_los_calls, 0, "los_to NOT consulted for a self-cast")

-- ---------------------------------------------------------------------------
-- 7. same_unit PRESENT but not same -> falls through to los_to (consulted)
-- ---------------------------------------------------------------------------
local target_b_calls = 0
local target_b = {
    los_to = function()
        target_b_calls = target_b_calls + 1
        return false
    end,
}
assert_eq(lg.check(target_b), false, "same_unit false falls through to los_to")
assert_eq(target_b_calls, 1, "los_to consulted for a non-self target")

-- ---------------------------------------------------------------------------
-- 8. Non-boolean los_to result -> treated as unavailable -> graphics fallback
-- ---------------------------------------------------------------------------
local graphics_calls = 0
core_tbl.graphics = {
    is_line_of_sight = function()
        graphics_calls = graphics_calls + 1
        return true
    end,
}
local target_c = { los_to = function() return 42 end }  -- non-boolean
assert_eq(lg.check(target_c), true, "non-boolean los_to falls back to graphics")
assert_eq(graphics_calls, 1, "graphics consulted once for non-boolean los_to")

-- ---------------------------------------------------------------------------
-- 9. Throwing los_to -> pcall-isolated -> graphics fallback
-- ---------------------------------------------------------------------------
local target_d = { los_to = function() error("boom") end }
assert_eq(lg.check(target_d), true, "throwing los_to falls back to graphics (no raise)")
assert_eq(graphics_calls, 2, "graphics consulted after throwing los_to")

-- ---------------------------------------------------------------------------
-- 10. Unit without los_to -> graphics fallback directly
-- ---------------------------------------------------------------------------
local target_e = {}
assert_eq(lg.check(target_e), true, "unit without los_to uses graphics fallback")
assert_eq(graphics_calls, 3, "graphics consulted for los_to-less unit")

-- ---------------------------------------------------------------------------
-- 11. Neither API -> assume LOS (do not block the cast)
-- ---------------------------------------------------------------------------
core_tbl.graphics = nil
local target_f = {}
assert_eq(lg.check(target_f), true, "no API at all -> assume LOS (do not block)")

-- ---------------------------------------------------------------------------
-- 12. Caster resolution: NS.GetPlayer absent -> core.object_manager fallback
-- ---------------------------------------------------------------------------
NS.GetPlayer = nil
local fallback_calls = 0
core_tbl.object_manager = {
    get_local_player = function()
        fallback_calls = fallback_calls + 1
        return player_unit
    end,
}
local target_g = { los_to = function() return true end }
assert_eq(lg.check(target_g), true, "caster resolved via core.object_manager fallback")
assert_eq(fallback_calls, 1, "fallback consulted exactly once")

-- ---------------------------------------------------------------------------
-- 13. No caster at all -> assume LOS
-- ---------------------------------------------------------------------------
core_tbl.object_manager = nil
assert_eq(lg.check({}), true, "no caster resolvable -> assume LOS")
NS.GetPlayer = function() return player_unit end  -- restore

-- ---------------------------------------------------------------------------
-- 14. FIFO eviction at MAX_LOS_CACHE_ENTRIES (64): the oldest key is dropped
--     and re-evaluated on the next lookup (bounded cache, no unbounded growth)
-- ---------------------------------------------------------------------------
local los_count = {}
local targets = {}
for i = 1, 70 do
    local idx = i  -- fresh upvalue per iteration (Lua 5.1 loop-var capture)
    local t = {
        los_to = function()
            los_count[idx] = (los_count[idx] or 0) + 1
            return false
        end,
    }
    targets[i] = t
    lg.check(t)
end
-- The first-inserted key is the oldest: after 70 inserts (6 evictions) it is
-- gone from the cache, so a re-check must re-evaluate (los_to called again).
assert_eq(los_count[1], 1, "oldest entry evaluated once when first inserted")
lg.check(targets[1])
assert_eq(los_count[1], 2, "evicted entry re-evaluates on the next lookup (bounded at 64)")

-- ---------------------------------------------------------------------------
-- 15. M.clear() flushes the cache -> next lookup re-evaluates even within TTL
-- ---------------------------------------------------------------------------
local t_clear = { los_to = function() return false end }
assert_eq(lg.check(t_clear), false, "baseline result cached")
lg.clear()
local re_calls = 0
local t_clear2 = {
    los_to = function()
        re_calls = re_calls + 1
        return true
    end,
}
assert_eq(lg.check(t_clear2), true, "post-clear lookup evaluates fresh")
assert_eq(re_calls, 1, "post-clear lookup consults the API")

print("PASS test_los_guard_regression")
