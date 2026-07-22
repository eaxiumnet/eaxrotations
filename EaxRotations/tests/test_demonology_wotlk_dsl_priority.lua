-- test_demonology_wotlk_dsl_priority.lua — DSL priority order tests for Warlock Demonology WotLK
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
            has_buff = function() return false end,
            has_debuff = function() return false end,
        },
    }
    for k, v in pairs(overrides or {}) do c[k] = v end
    return c
end

-- Load the spec module to get compiled strategies + build_state
local ok, mod = pcall(require, "classes/warlock/demonology_wotlk")
if not ok or not mod then
    error("Failed to load demonology_wotlk.lua: " .. tostring(ok))
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

-- Priority order: Metamorphosis > Immolate > Corruption > SoulFire > ShadowBolt
tests.priority_order = function()
    -- All conditions met for highest-priority (Metamorphosis)
    local ctx = make_context({
        in_combat = true,
    })
    -- Mock should_use_long_cd to return true
    local orig_should = NS.should_use_long_cd
    NS.should_use_long_cd = function(_, _) return true end
    local first = find_first_match(ctx)
    NS.should_use_long_cd = orig_should
    assert_equal("Metamorphosis", first, "Metamorphosis should be highest priority when all conditions met")
end

-- Metamorphosis: does not match when OOC
tests.test_Metamorphosis_does_not_match_when_ooc = function()
    local ctx = make_context({ in_combat = false })
    local ok = strategy_matches("Metamorphosis", ctx)
    assert_false(ok, "Metamorphosis should not match when OOC")
end

-- Metamorphosis: does not match when already up
tests.test_Metamorphosis_does_not_match_when_up = function()
    NS.buff_up = function(_, ids)
        for _, id in ipairs(ids) do
            if id == 47241 then return true end
        end
        return false
    end
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.metamorphosis_up = true
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "Metamorphosis" then
            ok = s.matches(ctx, state)
            break
        end
    end
    NS.buff_up = nil
    assert_false(ok, "Metamorphosis should not match when already active")
end

-- Immolate: matches when debuff is expiring
tests.test_Immolate_matches_when_expiring = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.immolate_remains = 0
    state.corruption_remains = 100  -- block Corruption
    -- Metamorphosis should be blocked (should_use_long_cd false)
    local orig_should = NS.should_use_long_cd
    NS.should_use_long_cd = function(_, _) return false end
    local first = find_first_match(ctx, state)
    NS.should_use_long_cd = orig_should
    assert_equal("Immolate", first, "Immolate should match when immolate_remains < 3 and higher prio blocked")
end

-- Immolate: does not match when debuff is fresh
tests.test_Immolate_does_not_match_when_fresh = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.immolate_remains = 10
    local ok = strategy_matches("Immolate", ctx, state)
    local ok2 = false
    for _, s in ipairs(strategies) do
        if s.name == "Immolate" then
            ok2 = s.matches(ctx, state)
            break
        end
    end
    assert_false(ok2, "Immolate should not match when immolate_remains >= 3")
end

-- Corruption: matches when debuff is expiring
tests.test_Corruption_matches_when_expiring = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.immolate_remains = 100  -- block Immolate
    state.corruption_remains = 0
    local orig_should = NS.should_use_long_cd
    NS.should_use_long_cd = function(_, _) return false end
    local first = find_first_match(ctx, state)
    NS.should_use_long_cd = orig_should
    assert_equal("Corruption", first, "Corruption should match when corruption_remains < 3")
end

-- Corruption: does not match when debuff is fresh
tests.test_Corruption_does_not_match_when_fresh = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.corruption_remains = 10
    state.immolate_remains = 100
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "Corruption" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_false(ok, "Corruption should not match when corruption_remains >= 3")
end

-- SoulFire: matches when mana >= 30
tests.test_SoulFire_matches_when_high_mana = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.immolate_remains = 100
    state.corruption_remains = 100
    state.mana_pct = 50
    local orig_should = NS.should_use_long_cd
    NS.should_use_long_cd = function(_, _) return false end
    local first = find_first_match(ctx, state)
    NS.should_use_long_cd = orig_should
    assert_equal("SoulFire", first, "SoulFire should match when mana_pct >= 30")
end

-- SoulFire: does not match when mana < 30
tests.test_SoulFire_does_not_match_when_low_mana = function()
    local ctx = make_context({ in_combat = true })
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

-- ShadowBolt: matches when mana >= 20 (filler)
tests.test_ShadowBolt_matches_as_filler = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.immolate_remains = 100
    state.corruption_remains = 100
    state.mana_pct = 25
    local orig_should = NS.should_use_long_cd
    NS.should_use_long_cd = function(_, _) return false end
    local first = find_first_match(ctx, state)
    NS.should_use_long_cd = orig_should
    assert_equal("ShadowBolt", first, "ShadowBolt should match as filler when mana_pct >= 20")
end

-- ShadowBolt: does not match when mana < 20
tests.test_ShadowBolt_does_not_match_when_oom = function()
    local ctx = make_context({ in_combat = true })
    local state = build_state(ctx)
    state.mana_pct = 10
    local ok = false
    for _, s in ipairs(strategies) do
        if s.name == "ShadowBolt" then
            ok = s.matches(ctx, state)
            break
        end
    end
    assert_false(ok, "ShadowBolt should not match when mana_pct < 20")
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
        io.write("  [ FAIL ] test_demonology_wotlk_dsl_priority.lua: " .. name .. " — " .. tostring(err) .. "\n")
    end
end

io.write(string.format("\n  [ RESULTS ] demonology_wotlk DSL priority: %d/%d passed, %d failed\n", pass, test_count, fail))
if fail > 0 then
    io.write("  [ FAIL ] test_demonology_wotlk_dsl_priority.lua\n")
    os.exit(1)
else
    io.write("  [ PASS ] test_demonology_wotlk_dsl_priority.lua\n")
    os.exit(0)
end
