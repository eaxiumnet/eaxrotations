-- test_arms_critical_fixes -- regression tests for 3 critical Arms Warrior bugs.
-- WHAT: verifies the fixes for stance_swap_safe typo, ARMS_SCHEMA ordering, and
--       the mortal_strike_matches dead rage-cap bypass.
-- WHEN: run via `lua EaxRotations/tests/test_arms_critical_fixes.lua` or the runner.
-- WHY:  these bugs silently skipped strategies or crashed; lock the fix in place.
-- SAFETY: self-contained mocks; no engine required; never edits spec files.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- ----------------------------------------------------------------------------
-- Assert helpers
-- ----------------------------------------------------------------------------
local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_false(v, label)
    if v then error(label or "assert_false failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then
        error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
    end
end

-- ----------------------------------------------------------------------------
-- Mock NS namespace (EaxRotations)
-- ----------------------------------------------------------------------------
local _registry_opts     -- captured by rotation_registry:register()
local spell_ready_calls  -- tracked for spell_ready invocations

local function make_mock_ns()
    spell_ready_calls = 0
    return {
        WarriorSpells = {
            Execute = 5308,
            BattleShout = 6673,
            VictoryRush = 34428,
            MortalStrike = 12294,
            Overpower = 7384,
            Slam = 1464,
            HeroicStrike = 78,
            Hamstring = 1715,
            Whirlwind = 1680,
            SweepingStrikes = 12328,
            DeathWish = 12292,
        },
        WarriorConstants = {
            STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        },
        is_execute_phase = function(hp, threshold)
            return hp ~= nil and hp <= threshold
        end,
        spell_ready = function(spell, target, opts)
            spell_ready_calls = spell_ready_calls + 1
            return true
        end,
        buff_up = function(me, buff_list)
            return me and me._buff_up or false
        end,
        debuff_remains = function(unit, ids) return 0 end,
        cooldown_remains = function(spell_value, fallback) return 0 end,
        log = function() end,
        GetPlayer = function() return { _buff_up = false } end,
        PLAYER_UNIT = {},
        rotation_registry = {
            register = function(self, spec, strats, opts)
                _registry_opts = opts
            end,
        },
    }
end

-- ============================================================================
-- TEST 1 & 2: stance_swap_safe (typo fix: preserved_rage_after_swap(state.rage or 0))
--
-- The original bug indexed `preserved_rage_after_swapstate.rage` (a typo'd nil
-- global), which crashed at runtime. The fix calls preserved_rage_after_swap()
-- with a nil-guarded rage. We exercise the shared helper that arms_sylvanas.lua
-- actually binds (`local stance_swap_safe = WH.stance_swap_safe or function...`).
--
-- NOTE: shared_helpers_sylvanas.lua returns early when _G.EaxRotations is nil,
-- so the mock NS must be installed BEFORE the require.
-- ============================================================================

_G.EaxRotations = make_mock_ns()

local WH = require("classes/warrior/shared_helpers_sylvanas")
assert_true(type(WH.stance_swap_safe) == "function", "WH.stance_swap_safe should be a function")
assert_true(type(WH.preserved_rage_after_swap) == "function", "WH.preserved_rage_after_swap should be a function")

-- Test 1: valid state -> returns a boolean, no error (the typo would have errored).
local ok1, res1 = pcall(WH.stance_swap_safe, { stance = 1, rage = 30 }, 15)
assert_true(ok1, "stance_swap_safe must not error on a valid state table")
assert_true(type(res1) == "boolean", "stance_swap_safe must return a boolean, got: " .. type(res1))
-- rage=30, tactical mastery cap=25 -> preserved=25 >= cost 15 -> true
assert_true(res1, "stance_swap_safe(stance=1, rage=30, cost=15) should be true")

-- Low rage below cost -> false (still a boolean, no crash).
local ok1b, res1b = pcall(WH.stance_swap_safe, { stance = 1, rage = 5 }, 15)
assert_true(ok1b, "stance_swap_safe must not error with low rage")
assert_true(type(res1b) == "boolean", "stance_swap_safe must return a boolean for low rage")
assert_false(res1b, "stance_swap_safe(stance=1, rage=5, cost=15) should be false")

-- Test 2: nil stance -> true (stance == nil means "allow swap" short-circuit).
local ok2, res2 = pcall(WH.stance_swap_safe, { stance = nil, rage = 0 }, 15)
assert_true(ok2, "stance_swap_safe must not error with nil stance")
assert_true(res2, "stance_swap_safe with nil stance should return true")

-- Also exercise the arms-local fallback path by hiding WH.stance_swap_safe:
-- arms_sylvanas.lua does `WH.stance_swap_safe or function(state, cost) ... end`,
-- so with the helper hidden the in-file fallback runs. It must also use the
-- fixed preserved_rage_after_swap(state.rage or 0) call and not crash.
local WH_real_swap = WH.stance_swap_safe
WH.stance_swap_safe = nil  -- force the arms-local fallback

-- ============================================================================
-- Load arms_sylvanas.lua (captures WH.action / stance_swap_safe now).
-- We install a spy on WH.action to capture the row passed to mortal_strike.
-- ============================================================================
local spy_rows = {}
WH.action = function(context, row)
    spy_rows[#spy_rows + 1] = row
    return true
end

-- shared_helpers captured its NS upvalue at require time (the same mock table);
-- arms_sylvanas.lua reads _G.EaxRotations at dofile time (same table). One mock.

local result = dofile("EaxRotations/classes/warrior/arms_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "arms strategies table should load")
assert_true(_registry_opts and type(_registry_opts.get_state) == "function",
    "rotation_registry should capture get_state (build_state) from arms")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- TEST 3: mortal_strike_matches rage-cap bypass (dead-branch fix)
--
-- Bug: both branches returned identical rows (both had min_rage), so the
-- rage-cap "bypass" was dead code. Fix: the rage-cap branch OMITS min_rage.
-- We capture the row via the WH.action spy and assert the two branches differ.
-- ============================================================================

local ms = find_strategy("MortalStrike")
assert_true(ms and type(ms.matches) == "function", "MortalStrike strategy should expose matches")

-- Normal branch: rage below RAGE_CAP (90) -> row should carry min_rage.
spy_rows = {}
spell_ready_calls = 0
local normal_ok, normal_res = pcall(ms.matches, { target = {}, stance = 1, rage = 50 })
assert_true(normal_ok, "MortalStrike.matches must not error on normal rage")
assert_true(normal_res, "MortalStrike should match at rage=50 (battle stance, spell_ready mock=true)")
assert_eq(#spy_rows, 1, "exactly one action row should be captured for normal-rage MS")
local normal_row = spy_rows[1]
assert_true(normal_row.min_rage ~= nil,
    "normal-rage MS branch should set min_rage (got nil = dead-bypass regression)")

-- Rage-cap branch: rage >= RAGE_CAP (90) -> row should OMIT min_rage.
spy_rows = {}
spell_ready_calls = 0
local cap_ok, cap_res = pcall(ms.matches, { target = {}, stance = 1, rage = 95 })
assert_true(cap_ok, "MortalStrike.matches must not error at rage cap")
assert_true(cap_res, "MortalStrike should match at rage=95 (rage-cap bypass)")
assert_eq(#spy_rows, 1, "exactly one action row should be captured for rage-cap MS")
local cap_row = spy_rows[1]
assert_true(cap_row.min_rage == nil,
    "rage-cap MS branch should OMIT min_rage (got: " .. tostring(cap_row.min_rage) .. ")")

-- The decisive regression assertion: the two branches must DIFFER on min_rage.
assert_true(normal_row.min_rage ~= cap_row.min_rage,
    "rage-cap and normal MS branches must differ on min_rage (dead-bypass regression)")
-- Both branches keep required_stance + cooldown (only min_rage is bypassed).
assert_eq(normal_row.required_stance, cap_row.required_stance,
    "both MS branches should share required_stance")
assert_eq(normal_row.cooldown, cap_row.cooldown,
    "both MS branches should share cooldown")

-- ============================================================================
-- TEST 4: ARMS_SCHEMA is accessible (declaration-ordering fix)
--
-- Bug: ARMS_SCHEMA was declared AFTER build_state, so safe_state received nil
-- and fell back to spec_kit.SAFE_STATE_DEFAULTS only (losing custom defaults
-- like mh_until=999, enemy_count=1). Fix: schema is declared before build_state.
--
-- Note: when a schema is passed, spec_kit.safe_state uses it INSTEAD of
-- SAFE_STATE_DEFAULTS (no merge). So every fallback comes from ARMS_SCHEMA.
-- We prove the schema is wired (not nil) with two discriminating fields:
--   * mh_until    -> in ARMS_SCHEMA (=999), NOT in SAFE_STATE_DEFAULTS.
--                   If schema were nil -> nil. Fix -> 999.
--   * enemy_count -> ARMS_SCHEMA=1 vs SAFE_STATE_DEFAULTS=0.
--                   If schema were nil -> 0. Fix -> 1.
-- ============================================================================

local get_state = _registry_opts.get_state
local state = get_state({ me = { _buff_up = false }, target = {} })
assert_true(type(state) == "table", "build_state should return a state table (safe_state proxy)")

-- Sanity: the proxy is write-through (writes land on the underlying arms_state).
state.rage = 42
assert_eq(state.rage, 42, "safe_state proxy should be write-through")

-- Schema-only field: mh_until is in ARMS_SCHEMA (=999) but NOT in
-- SAFE_STATE_DEFAULTS. If the schema were nil (the bug), this read would
-- return nil instead of 999.
state.mh_until = nil  -- write-through clears the raw value
assert_eq(state.mh_until, 999,
    "nil mh_until should fall back to ARMS_SCHEMA (999), not nil -- proves schema is wired")

-- Schema overrides SAFE_STATE_DEFAULTS: enemy_count is schema=1 vs defaults=0.
-- If ARMS_SCHEMA were nil (the bug), the fallback would be 0, not 1.
state.enemy_count = nil
assert_eq(state.enemy_count, 1,
    "nil enemy_count should fall back to ARMS_SCHEMA (1), not SAFE_STATE_DEFAULTS (0)")

-- A field absent from ARMS_SCHEMA reads as nil (the schema fully replaces
-- SAFE_STATE_DEFAULTS, so absent keys get no phantom default). is_group is set
-- by build_state but is NOT listed in ARMS_SCHEMA.
state.is_group = nil
assert_true(state.is_group == nil,
    "field absent from ARMS_SCHEMA should read nil (no phantom default)")

-- Restore WH for cleanliness (other tests in the process may reuse the module).
WH.stance_swap_safe = WH_real_swap

print("PASS test_arms_critical_fixes")
