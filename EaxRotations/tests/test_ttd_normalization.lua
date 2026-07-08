-- test_ttd_normalization.lua -- time-to-death tests.
-- WHAT:  time-to-death tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates time-to-death gating to avoid clipping DoTs on short-lived targets.
-- SAFETY: Uses synthetic TTD values.

-- Phase 3 test: TTD normalization patterns across specs.
-- Tests the acceptance criteria from the Phase 3 plan:
--   1. DoT skipped when known TTD is below DoT value window
--   2. Execute still works when ttd_known is false but HP threshold is met
--   3. Cooldown held on very short TTD target
--   4. Cooldown allowed on boss/high-TTD target
--   5. nil TTD treated as 999 (unknown), not zero (safe)

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Pattern 1: TTD nil → 999 normalization (used by fury, arms, enhancement)
-- ============================================================================

print("--- TTD: nil → 999 normalization ---")

-- Test 1: nil TTD → normalized to 999 (safe unknown)
local function normalize_ttd(context)
    return context.ttd or 999
end
assert_eq(normalize_ttd({ ttd = nil }), 999, "nil TTD should normalize to 999")
assert_eq(normalize_ttd({ ttd = 30 }), 30, "known TTD should pass through unchanged")
assert_eq(normalize_ttd({ ttd = 0 }), 0, "zero TTD should pass through unchanged (target truly dying)")

-- ============================================================================
-- Pattern 2: DoT skipped when known TTD < threshold (used by shaman enhancement, hunter BM)
-- ============================================================================

print("--- TTD: DoT skipped when TTD below threshold ---")

-- Test 2: DoT should be skipped when TTD is known and below threshold
-- Pattern: if ctx.ttd_known and ctx.ttd < DOT_TTD_MIN then return false end
local DOT_TTD_MIN = 6
local function should_cast_dot(ctx)
    if ctx.ttd_known and ctx.ttd < DOT_TTD_MIN then return false end
    return true  -- otherwise allowed
end

-- TTD known = 4s, DoT needs 6s → skip
assert_false(should_cast_dot({ ttd_known = true, ttd = 4 }),
    "DoT should be skipped when TTD (4s) < DoT window (6s)")

-- TTD known = 10s, DoT needs 6s → allow
assert_true(should_cast_dot({ ttd_known = true, ttd = 10 }),
    "DoT should be allowed when TTD (10s) >= DoT window (6s)")

-- TTD known = 6s exactly at threshold → allow (uses < not <=)
assert_true(should_cast_dot({ ttd_known = true, ttd = 6 }),
    "DoT should be allowed at exact threshold (6s >= 6s)")

-- ============================================================================
-- Pattern 3: Execute still works when ttd_known is false but HP threshold met
-- ============================================================================

print("--- TTD: Execute with unknown TTD ---")

-- Test 3: Execute should work when HP is low, even if TTD unknown
-- Pattern: only use TTD as an extra gate, never as the sole block
local EXECUTE_HP = 20
local function should_execute(ctx, state)
    -- Primary gate: HP threshold
    if (state.hp_pct or 100) > EXECUTE_HP then return false end
    -- TTD is a bonus optimization, not a block when unknown
    -- (no ttd gate blocks execute when ttd_known is false)
    return true
end

-- HP at 15% (below 20% execute) → execute allowed regardless of TTD
assert_true(should_execute({ ttd_known = false, ttd = nil }, { hp_pct = 15 }),
    "Execute should work when HP <= 20%%, even with ttd_known=false")

assert_true(should_execute({ ttd_known = true, ttd = 3 }, { hp_pct = 15 }),
    "Execute should work when HP <= 20%% and TTD known low")

assert_false(should_execute({ ttd_known = true, ttd = 60 }, { hp_pct = 35 }),
    "Execute should NOT fire when HP > 20%%")

-- ============================================================================
-- Pattern 4: Cooldown held on very short TTD target
-- ============================================================================

print("--- TTD: Cooldown held on short TTD ---")

-- Test 4: Long cooldown should be held when TTD is very short
-- Pattern: if ctx.ttd_known and ctx.ttd < CD_TTD_MIN then return false end
local CD_TTD_MIN = 8
local function should_use_cooldown(ctx, state)
    if not state.cooldown_ready then return false end
    if ctx.ttd_known and ctx.ttd < CD_TTD_MIN then return false end
    return true
end

-- TTD 3s, cooldown needs 8s minimum → hold
assert_false(should_use_cooldown({ ttd_known = true, ttd = 3 }, { cooldown_ready = true }),
    "Cooldown should be held when TTD (3s) < minimum (8s)")

-- TTD 15s → use it
assert_true(should_use_cooldown({ ttd_known = true, ttd = 15 }, { cooldown_ready = true }),
    "Cooldown should fire when TTD (15s) >= minimum (8s)")

-- TTD unknown → don't block (safe: unknown means "could be long")
assert_true(should_use_cooldown({ ttd_known = false, ttd = nil }, { cooldown_ready = true }),
    "Cooldown should NOT be blocked when ttd_known is false")

-- ============================================================================
-- Pattern 5: Cooldown allowed on boss/high-TTD target
-- ============================================================================

print("--- TTD: Boss target cooldown usage ---")

-- Test 5: Boss targets should allow cooldowns (high TTD assumed)
local BOSS_TTD = 60
local function boss_cooldown_allowed(ctx, state)
    if not state.cooldown_ready then return false end
    if state.is_boss then
        -- Boss: always allow cooldown regardless of exact TTD
        return true
    end
    -- Non-boss: check TTD window
    if ctx.ttd_known and ctx.ttd < CD_TTD_MIN then return false end
    return true
end

-- Boss target, cooldown ready → should fire
assert_true(boss_cooldown_allowed({ ttd_known = true, ttd = 5 }, { cooldown_ready = true, is_boss = true }),
    "Boss target: cooldown should fire even with short TTD (boss fights are long)")

-- Trash target, very short TTD → hold
assert_false(boss_cooldown_allowed({ ttd_known = true, ttd = 5 }, { cooldown_ready = true, is_boss = false }),
    "Trash target with short TTD: cooldown should be held")

-- Trash target, long TTD → fire
assert_true(boss_cooldown_allowed({ ttd_known = true, ttd = 20 }, { cooldown_ready = true, is_boss = false }),
    "Trash target with long TTD: cooldown should fire")

-- ============================================================================
-- Pattern 6: BM hunter specific — kill command/beastial wrath TTD gates
-- ============================================================================

print("--- TTD: Hunter BM kill command / beastial wrath TTD gates ---")

-- Test 6: Kill Command should skip when TTD < 15s
-- Pattern from beast_mastery_sylvanas.lua: if context.ttd_known and context.ttd < 15 then return false end
local KILL_CMD_TTD = 15
local function should_kill_command(ctx)
    if ctx.ttd_known and ctx.ttd < KILL_CMD_TTD then return false end
    return true
end

assert_false(should_kill_command({ ttd_known = true, ttd = 10 }),
    "Kill Command should skip when TTD 10s < 15s")

assert_true(should_kill_command({ ttd_known = true, ttd = 20 }),
    "Kill Command should fire when TTD 20s >= 15s")

assert_true(should_kill_command({ ttd_known = false, ttd = nil }),
    "Kill Command should fire when TTD unknown (safe pass-through)")

-- ============================================================================
-- Pattern 7: Enhancement shaman — instant vs DoT TTD preference
-- ============================================================================

print("--- TTD: Enhancement shaman instant vs DoT preference ---")

-- Test 7: When TTD is short (< 6s), prefer Earth Shock (instant) over Flame Shock (DoT)
-- Pattern from enhancement_sylvanas.lua:
--   Flame Shock: if ctx.ttd_known and ctx.ttd < 6 then return false end
--   Earth Shock: if ctx.ttd_known and ttd and ttd < 6 then return true end (prefer)

local function should_flame_shock(ctx)
    if ctx.ttd_known and ctx.ttd < 6 then return false end
    return true
end

local function should_earth_shock_ttd_gate(ctx)
    -- Earth Shock prefers when TTD is short (instant damage)
    if ctx.ttd_known and ctx.ttd and ctx.ttd < 6 then return true end
    return false  -- normal priority logic
end

-- TTD = 3s → skip Flame Shock (DoT won't tick enough)
assert_false(should_flame_shock({ ttd_known = true, ttd = 3 }),
    "Flame Shock should be skipped when TTD 3s < 6s")

-- TTD = 3s → Earth Shock prefer (instant damage)
assert_true(should_earth_shock_ttd_gate({ ttd_known = true, ttd = 3 }),
    "Earth Shock should prefer when TTD 3s < 6s (instant damage > DoT)")

-- TTD = 10s → Flame Shock allowed, Earth Shock no preference
assert_true(should_flame_shock({ ttd_known = true, ttd = 10 }),
    "Flame Shock should be allowed when TTD 10s >= 6s")
assert_false(should_earth_shock_ttd_gate({ ttd_known = true, ttd = 10 }),
    "Earth Shock should NOT prefer when TTD 10s >= 6s")

-- ============================================================================
-- Pattern 8: Self-defense — Shamanistic Rage TTD gate
-- ============================================================================

print("--- TTD: Shamanistic Rage cooldown TTD gate ---")

-- Test 8: Shamanistic Rage (2min CD) should skip on short TTD target
-- Pattern: if ctx.ttd_known and ctx.ttd < 8 then return false end
local SR_TTD_MIN = 8
local function should_shamanistic_rage(ctx, state)
    if not state.sr_ready then return false end
    if ctx.ttd_known and ctx.ttd < SR_TTD_MIN then return false end
    if (state.mana_pct or 100) > 40 and (state.hp_pct or 100) > 40 then return false end
    return true
end

-- TTD 5s with low mana → hold (waste of CD)
assert_false(should_shamanistic_rage({ ttd_known = true, ttd = 5 }, { sr_ready = true, mana_pct = 20, hp_pct = 60 }),
    "Shamanistic Rage should be held when TTD 5s < 8s (even with low mana)")

-- TTD 12s with low mana → fire
assert_true(should_shamanistic_rage({ ttd_known = true, ttd = 12 }, { sr_ready = true, mana_pct = 20, hp_pct = 60 }),
    "Shamanistic Rage should fire when TTD 12s >= 8s and mana is low")

-- TTD unknown with low mana → fire (safe pass-through)
assert_true(should_shamanistic_rage({ ttd_known = false, ttd = nil }, { sr_ready = true, mana_pct = 20, hp_pct = 60 }),
    "Shamanistic Rage should fire when TTD unknown (safe) and mana is low")

-- ============================================================================
-- Pattern 9: action_matches min_ttd gate (core_sylvanas.lua lines 4872-4889)
-- Replicates the central action-level min_ttd/require_ttd gating logic.
-- ============================================================================

print("--- TTD: action_matches min_ttd gate ---")

-- Pattern: the action_matches function's min_ttd gate after the Phase 3 fix
--   if action.min_ttd then
--       if action.require_ttd and not context.ttd_known then
--           return false  -- block: TTD explicitly required but unknown
--       end
--       if context.ttd_known and (context.ttd or 999) < action.min_ttd then
--           return false  -- block: TTD known but too short
--       end
--   end

local function action_min_ttd_gate(context, action)
    if not action.min_ttd then return true end  -- no gate → pass
    -- require_ttd: action explicitly needs known TTD (conservative block when unknown)
    if action.require_ttd and not context.ttd_known then
        return false
    end
    -- min_ttd: only gates when TTD is actually known (Phase 3 fix: was or 0)
    if context.ttd_known and (context.ttd or 999) < action.min_ttd then
        return false
    end
    return true
end

-- Test 12: No min_ttd on action → always passes (no gate)
assert_true(action_min_ttd_gate(
    { ttd_known = true, ttd = 3 },
    { min_ttd = nil }
), "no min_ttd → always pass regardless of TTD")

-- Test 13: require_ttd=true + ttd_known=false → blocked (conservative)
assert_false(action_min_ttd_gate(
    { ttd_known = false, ttd = nil },
    { min_ttd = 10, require_ttd = true }
), "require_ttd + unknown TTD → block (action explicitly needs known TTD)")

-- Test 14: require_ttd=false + ttd_known=false → pass (safe, liberal)
-- This is the 'or 0' bug fix: old code blocked here; new code allows
assert_true(action_min_ttd_gate(
    { ttd_known = false, ttd = nil },
    { min_ttd = 10 }
), "no require_ttd + unknown TTD → pass (unknown is NOT dying)")

-- Test 15: require_ttd=true + ttd_known=true + ttd < min_ttd → blocked
assert_false(action_min_ttd_gate(
    { ttd_known = true, ttd = 5 },
    { min_ttd = 10, require_ttd = true }
), "require_ttd + known TTD (5) < min_ttd (10) → block")

-- Test 16: require_ttd=true + ttd_known=true + ttd >= min_ttd → pass
assert_true(action_min_ttd_gate(
    { ttd_known = true, ttd = 15 },
    { min_ttd = 10, require_ttd = true }
), "require_ttd + known TTD (15) >= min_ttd (10) → pass")

-- Test 17: require_ttd not set + ttd_known=true + ttd < min_ttd → blocked
assert_false(action_min_ttd_gate(
    { ttd_known = true, ttd = 2 },
    { min_ttd = 6 }
), "known TTD (2) < min_ttd (6) → block (even without require_ttd)")

-- Test 18: require_ttd not set + ttd_known=true + ttd >= min_ttd → pass
assert_true(action_min_ttd_gate(
    { ttd_known = true, ttd = 20 },
    { min_ttd = 6 }
), "known TTD (20) >= min_ttd (6) → pass")

-- Test 19: Exact boundary: ttd == min_ttd → pass (uses < not <=)
assert_true(action_min_ttd_gate(
    { ttd_known = true, ttd = 10 },
    { min_ttd = 10, require_ttd = true }
), "TTD exactly at min_ttd (10 == 10) → pass (< test, not <=)")

-- Test 20: ttd_known=true but ttd=nil (contradictory) → allowed via or 999
-- Should never happen in practice, but the or 999 fallback errs on the side of allowing
assert_true(action_min_ttd_gate(
    { ttd_known = true, ttd = nil },
    { min_ttd = 10 }
), "contradictory state (ttd_known=true but ttd=nil) → pass via or 999 safety")

-- ============================================================================
-- Boundary tests: ttd at exactly 0, ttd_known edge cases
-- ============================================================================

print("--- TTD: Boundary cases ---")

-- Test 21: TTD = 0 should still block DoTs (target is literally dying now)
local ttd_zero = normalize_ttd({ ttd = 0 })
assert_eq(ttd_zero, 0, "TTD = 0 should stay 0 (not normalized to 999)")
assert_false(should_cast_dot({ ttd_known = true, ttd = 0 }),
    "DoT should be skipped when TTD = 0 (target dying now)")

-- Test 22: nil TTD from context should default to 999 via normalization pattern
-- The real pattern is: local my_ttd = context.ttd or 999
-- This test verifies the correct field access pattern (not accidental table indexing)
local ctx = { ttd = nil, ttd_known = false }
local safe_ttd = ctx.ttd or 999
assert_eq(safe_ttd, 999, "nil TTD (context.ttd or 999) should default to 999, not 0 or nil")

-- Test 23: Large TTD (boss fight, 300s) → all gates pass
assert_true(should_cast_dot({ ttd_known = true, ttd = 300 }),
    "DoT should be allowed on boss with 300s TTD")
assert_true(should_use_cooldown({ ttd_known = true, ttd = 300 }, { cooldown_ready = true }),
    "Cooldown should fire on boss with 300s TTD")
assert_true(should_kill_command({ ttd_known = true, ttd = 300 }),
    "Kill Command should fire on boss with 300s TTD")

print("PASS test_ttd_normalization")
