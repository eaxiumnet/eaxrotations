-- test_destruction_wotlk_dsl_priority.lua � WotLK Destruction DSL priority order validation.
-- WHAT:  Asserts the declarative DSL strategies appear in the correct priority order
--        and that key match/no-match gates behave correctly under mocked combat state.
-- WHEN:  Runs as part of the WotLK rotation test suite.
-- WHY:   Regression guard for the WotLK DSL adoption � ensures declarative conditions
--        produce the same behavior as the original imperative match functions.
-- SAFETY: Uses synthetic context/state; no live game data required.

-- Validates that the 5 DSL-compiled strategies match in the correct priority order
-- and that match/no-match gates work for each strategy.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local engine_immolate_cast = nil  -- core.spell_book.get_spell_cast_time verdict

_G.EaxRotations = {
    core = { spell_book = { get_spell_cast_time = function() return engine_immolate_cast end } },
    WarlockSpells = {},
    spell_action = function(ids, label)
        local action_ids = type(ids) == "table" and ids or { ids }
        return {
            _meta = {
                id = action_ids[1],
                ids = action_ids,
                label = label,
            },
        }
    end,
    debuff_remains = function() return 0 end,
    rotation_registry = { register = function() end },
    log = function() end,
}
package.loaded["classes/warlock/destruction_wotlk"] = nil
local NS = _G.EaxRotations

local function assert_equal(a, b, label)
    if a ~= b then
        error(label .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end

local function assert_true(v, label)
    if not v then
        error(label or "assert_true failed", 2)
    end
end

local function assert_false(v, label)
    if v then
        error(label or "assert_false failed", 2)
    end
end

-- Build a minimal context for testing
local function make_context(overrides)
    local c = {
        now = 1000,
        in_combat = true,
        target = { get_health_percentage = function() return 100 end, is_valid = function() return true end },
        me = {
            get_health_percentage = function() return 100 end,
            get_mana_percentage = function() return 100 end,
        },
    }
    for k, v in pairs(overrides or {}) do c[k] = v end
    return c
end

-- Load the spec module to get compiled strategies + build_state
local ok, mod = pcall(require, "classes/warlock/destruction_wotlk")
if not ok or not mod then
    error("Failed to load destruction_wotlk.lua: " .. tostring(ok))
end

local strategies = mod.strategies
local build_state = mod.build_state

-- Helper: run through strategies, find first match
local function find_first_match(context, state)
    state = state or build_state(context)
    for _, s in ipairs(strategies) do
        if s.matches(context, state) then
            return s.name
        end
    end
    return nil
end

-- Helper: test whether a specific strategy matches under given conditions
local function strategy_matches(name, context, state)
    state = state or build_state(context)
    for _, s in ipairs(strategies) do
        if s.name == name then
            return s.matches(context, state)
        end
    end
    return false
end

-- ============================================================================
-- Tests
-- ============================================================================
local tests = {}

-- Priority order: the 2026-09-11 guide pass added CurseOfElements (APL entry
-- 2) and Shadowburn (execute) above the old core; CoE's amp goes up before the
-- damage cycle, so it is the top lane when the debuff is down.
tests.priority_order = function()
    local ctx = make_context({})
    local first = find_first_match(ctx)
    assert_equal("CurseOfElements", first, "CurseOfElements (amp upkeep) should be top when the curse is down")
    -- Core damage cycle still resolves to Immolate when the amp is up.
    local state = build_state(ctx)
    state.elements_remains = 60
    assert_equal("Immolate", find_first_match(ctx, state), "Immolate should be highest damage-priority when debuff is expiring")
end

-- Immolate: matches when debuff is expiring
tests.test_Immolate_matches_when_expiring = function()
    local ctx = make_context({})
    local ok = strategy_matches("Immolate", ctx)
    assert_true(ok, "Immolate should match when immolate_remains < 2.5")
end

-- Immolate: the refresh window is the engine's real cast time
-- (core.spell_book.get_spell_cast_time — wl_destro_wotlk fixture entry 4:
-- dotRemainingTime(47811) < spellCastTime(47811)), with the WotLK base 2.0s
-- fallback when the read is absent. The old _meta.cast_time read is gone:
-- define_action builds array-style actions, so it could never resolve.
tests.test_Immolate_uses_engine_cast_time = function()
    local ctx = make_context({})
    engine_immolate_cast = 2.5
    local state = build_state(ctx)
    state.immolate_remains = 2.25
    assert_true(strategy_matches("Immolate", ctx, state),
        "Immolate should refresh inside the engine's 2.5s cast window")
    engine_immolate_cast = nil
    assert_false(strategy_matches("Immolate", ctx, state),
        "Immolate should fall back to the 2.0s base window without an engine read")
    state.immolate_remains = 1.9
    assert_true(strategy_matches("Immolate", ctx, state),
        "Immolate should refresh inside the 2.0s fallback window")
end

-- Immolate: the custom window condition must still carry its live state into
-- the cast trace (node.watch -> strategy._dsl_watch).
tests.test_Immolate_watch_fields_survive_custom_condition = function()
    local watched = {}
    for _, s in ipairs(strategies) do
        if s.name == "Immolate" then watched = s._dsl_watch or {} break end
    end
    local found = false
    for i = 1, #watched do
        if watched[i].field == "immolate_remains" and watched[i].src == "state" then found = true end
    end
    assert_true(found, "Immolate lane should watch immolate_remains in the cast trace")
end

-- Immolate: does not match when debuff is fresh
tests.test_Immolate_does_not_match_when_fresh = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.immolate_remains = 5
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "Immolate" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_false(ok, "Immolate should not match when immolate_remains >= 2.5")
end

-- Conflagrate: matches whenever Immolate is still active
tests.test_Conflagrate_matches_when_immolate_active = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.immolate_remains = 1
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "Conflagrate" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_true(ok, "Conflagrate should match while immolate_remains is positive")
end

-- Pinned destro APL orders Conflagrate before the Immolate refresh window.
tests.test_Conflagrate_wins_before_Immolate_refresh = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.elements_remains = 60 -- curse up: the amp upkeep lane is out of the way
    state.immolate_remains = 1.5
    assert_equal("Conflagrate", find_first_match(ctx, state),
        "Conflagrate should precede the Immolate refresh at 1.5s remaining")
end

-- ChaosBolt: matches when mana >= 20
tests.test_ChaosBolt_matches_when_high_mana = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.elements_remains = 60
    state.immolate_remains = 5
    local first = find_first_match(ctx, state)
    assert_equal("Conflagrate", first, "Conflagrate should win over ChaosBolt when Immolate active")
    -- Now block Conflagrate by setting immolate low
    state.immolate_remains = 1
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "ChaosBolt" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_true(ok, "ChaosBolt should match when mana_pct >= 20")
end

-- ChaosBolt: does not match when OOM
tests.test_ChaosBolt_does_not_match_when_oom = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.mana_pct = 10
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "ChaosBolt" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_false(ok, "ChaosBolt should not match when mana_pct < 20")
end

-- Incinerate: matches when mana >= 20 (filler)
tests.test_Incinerate_matches_as_filler = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.immolate_remains = 5
    -- Block Immolate/Conflagrate by setting immolate high; ChaosBolt should match first at mana 100
    -- Verify Incinerate also matches at this point (both ChaosBolt and Incinerate have same condition)
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "Incinerate" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_true(ok, "Incinerate should match when mana_pct >= 20")
end

-- SoulFire: matches when mana >= 30
tests.test_SoulFire_matches_when_high_mana = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.immolate_remains = 5
    state.mana_pct = 50
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "SoulFire" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_true(ok, "SoulFire should match when mana_pct >= 30")
end

-- SoulFire: does not match when mana < 30
tests.test_SoulFire_does_not_match_when_low_mana = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.mana_pct = 20
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "SoulFire" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_false(ok, "SoulFire should not match when mana_pct < 30")
end

-- Run all tests
local pass, fail = 0, 0
local test_count = 0
for name, fn in pairs(tests) do
    test_count = test_count + 1
    local ok_test, err = pcall(fn)
    if ok_test then
        pass = pass + 1
    else
        fail = fail + 1
        io.write("  [ FAIL ] test_destruction_wotlk_dsl_priority.lua: " .. name .. " — " .. tostring(err) .. "\n")
    end
end

io.write(string.format("\n  [ RESULTS ] destruction_wotlk DSL priority: %d/%d passed, %d failed\n", pass, test_count, fail))
if fail > 0 then
    io.write("  [ FAIL ] test_destruction_wotlk_dsl_priority.lua\n")
    os.exit(1)
else
    io.write("  [ PASS ] test_destruction_wotlk_dsl_priority.lua\n")
    os.exit(0)
end
