-- test_balance_wotlk_dsl_priority.lua — WotLK Balance druid DSL priority order tests.
-- WHAT:  Validates that the 6 balance_wotlk strategies are compiled correctly by the DSL
--        and that their match gates fire in the expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   Regression guard for DSL-based strategy definitions.
-- SAFETY: Standalone; mocks all NS dependencies.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function test(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

_G.EaxRotations = {
    DruidSpells = {
        MoonkinForm = make_action(24858, "MoonkinForm"),
        InsectSwarm = make_action(27013, "InsectSwarm"),
        Moonfire = make_action(26988, "Moonfire"),
        Starfall = make_action(48505, "Starfall"),
        Wrath = make_action(26985, "Wrath"),
        Starfire = make_action(26986, "Starfire"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function(unit, ids) return false end,
    buff_stacks = function(unit, ids) return 0 end,
    buff_remains = function() return 0 end,
    debuff_up = function(unit, ids) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    is_wotlk = function() return true end,
    should_use_long_cd = function(ctx, cd) return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_balance = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_balance_wotlk_dsl_priority ===")

local balance = dofile("EaxRotations/classes/druid/balance_wotlk.lua")
assert_true(type(balance) == "table", "balance_wotlk should return a table")
assert_true(type(balance.strategies) == "table", "balance_wotlk should expose strategies")
assert_true(#balance.strategies == 6, "balance_wotlk should have 6 strategies")

local registered = _G.EaxRotations._registered_balance
assert_true(registered ~= nil, "balance_wotlk should register under 'balance'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "MoonkinForm",
    "Starfall",
    "Moonfire",
    "Starfire",
    "Wrath",
    "InsectSwarm",
}

test("priority order: 6 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(balance.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], balance.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- MoonkinForm: matches when not already up
test("MoonkinForm: matches when not up", function()
    local state = balance.build_state(ctx)
    state.moonkin_up = false
    assert_true(balance.strategies[1].matches(ctx, state), "MoonkinForm should match when not up")
end)

test("MoonkinForm: does not match when already up", function()
    local state = balance.build_state(ctx)
    state.moonkin_up = true
    assert_false(balance.strategies[1].matches(ctx, state), "MoonkinForm should not match when already up")
end)

-- Starfall: matches in combat, enemy_count >= 2, long cd allowed
test("Starfall: matches when in combat, 2+ enemies, long cd allowed", function()
    local state = balance.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 2
    assert_true(balance.strategies[2].matches(ctx, state), "Starfall should match in AoE combat")
end)

test("Starfall: does not match out of combat", function()
    local state = balance.build_state(ctx)
    state.in_combat = false
    state.enemy_count = 2
    assert_false(balance.strategies[2].matches(ctx, state), "Starfall should not match out of combat")
end)

test("Starfall: does not match with fewer than 2 enemies", function()
    local state = balance.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 1
    assert_false(balance.strategies[2].matches(ctx, state), "Starfall should not match with < 2 enemies")
end)

test("Starfall: does not match when long cd blocked", function()
    local orig = _G.EaxRotations.should_use_long_cd
    _G.EaxRotations.should_use_long_cd = function(ctx, cd) return false end
    local state = balance.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 2
    local ok = balance.strategies[2].matches(ctx, state)
    _G.EaxRotations.should_use_long_cd = orig
    assert_false(ok, "Starfall should not match when long cd blocked")
end)

-- InsectSwarm: matches when debuff remains < 3
test("InsectSwarm: matches when debuff remains < 3", function()
    local state = balance.build_state(ctx)
    state.insect_swarm_remains = 1
    assert_true(balance.strategies[6].matches(ctx, state), "InsectSwarm should match when debuff < 3")
end)

test("InsectSwarm: does not match when debuff remains >= 3", function()
    local state = balance.build_state(ctx)
    state.insect_swarm_remains = 5
    assert_false(balance.strategies[6].matches(ctx, state), "InsectSwarm should not match when debuff >= 3")
end)

-- Moonfire: matches when debuff remains < 3
test("Moonfire: matches when debuff remains < 3", function()
    local state = balance.build_state(ctx)
    state.moonfire_remains = 1
    assert_true(balance.strategies[3].matches(ctx, state), "Moonfire should match when debuff < 3")
end)

test("Moonfire: does not match when debuff remains >= 3", function()
    local state = balance.build_state(ctx)
    state.moonfire_remains = 5
    assert_false(balance.strategies[3].matches(ctx, state), "Moonfire should not match when debuff >= 3")
end)

-- Wrath: matches when mana >= 15
test("Wrath: matches when mana >= 15", function()
    local state = balance.build_state(ctx)
    state.mana_pct = 80
    assert_true(balance.strategies[5].matches(ctx, state), "Wrath should match when mana >= 15")
end)

test("Wrath: does not match when mana < 15", function()
    local state = balance.build_state(ctx)
    state.mana_pct = 10
    assert_false(balance.strategies[5].matches(ctx, state), "Wrath should not match when mana < 15")
end)

-- Starfire: matches when mana >= 15 (same condition, lower priority)
test("Starfire: matches when mana >= 15", function()
    local state = balance.build_state(ctx)
    state.mana_pct = 80
    assert_true(balance.strategies[4].matches(ctx, state), "Starfire should match when mana >= 15")
end)

test("Starfire: does not match when mana < 15", function()
    local state = balance.build_state(ctx)
    state.mana_pct = 10
    assert_false(balance.strategies[4].matches(ctx, state), "Starfire should not match when mana < 15")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
