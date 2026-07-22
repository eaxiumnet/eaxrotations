-- test_destruction_wotlk_dsl_priority.lua — DSL priority order tests for Warlock Destruction WotLK
-- Validates that the 5 DSL-compiled strategies match in the correct priority order
-- and that match/no-match gates work for each strategy.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local NS = _G.EaxRotations
if not NS then return nil end

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

-- Priority order: Immolate > Conflagrate > ChaosBolt > Incinerate > SoulFire
tests.priority_order = function()
    local ctx = make_context({})
    local first = find_first_match(ctx)
    assert_equal("Immolate", first, "Immolate should be highest priority when debuff is expiring")
end

-- Immolate: matches when debuff is expiring
tests.test_Immolate_matches_when_expiring = function()
    local ctx = make_context({})
    local ok = strategy_matches("Immolate", ctx)
    assert_true(ok, "Immolate should match when immolate_remains < 3")
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
    assert_false(ok, "Immolate should not match when immolate_remains >= 3")
end

-- Conflagrate: matches when Immolate is active
tests.test_Conflagrate_matches_when_immolate_active = function()
    local ctx = make_context({})
    local state = build_state(ctx)
    state.immolate_remains = 5
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "Conflagrate" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_true(ok, "Conflagrate should match when immolate_remains > 3")
end

-- Conflagrate: does not match when Immolate is expiring
tests.test_Conflagrate_does_not_match_when_immolate_expiring = function()
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
    assert_false(ok, "Conflagrate should not match when immolate_remains <= 3")
end

-- ChaosBolt: matches when mana >= 20
tests.test_ChaosBolt_matches_when_high_mana = function()
    local ctx = make_context({})
    local state = build_state(ctx)
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
