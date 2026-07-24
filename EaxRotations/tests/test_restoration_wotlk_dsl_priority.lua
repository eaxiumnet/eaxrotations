-- test_restoration_wotlk_dsl_priority.lua — WotLK Restoration shaman DSL priority tests.
-- WHAT:  Validates that the 4 restoration_wotlk strategies are compiled correctly by
--        the DSL and that their match gates fire in the expected priority order.
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
    ShamanSpells = {
        Riptide = make_action(61295, "Riptide"),
        ChainHeal = make_action(25423, "ChainHeal"),
        HealingWave = make_action(25396, "HealingWave"),
        EarthShield = make_action(32594, "EarthShield"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 100 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function(unit, ids) return false end,
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
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_restoration = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_restoration_wotlk_dsl_priority ===")

local resto = dofile("EaxRotations/classes/shaman/restoration_wotlk.lua")
assert_true(type(resto) == "table", "restoration_wotlk should return a table")
assert_true(type(resto.strategies) == "table", "restoration_wotlk should expose strategies")
assert_true(#resto.strategies == 4, "restoration_wotlk should have 4 strategies")

local registered = _G.EaxRotations._registered_restoration
assert_true(registered ~= nil, "restoration_wotlk should register under 'restoration'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "EarthShield",
    "Riptide",
    "ChainHeal",
    "HealingWave",
}

test("priority order: 4 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(resto.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], resto.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- EarthShield (1): matches when earth_shield_up falsy
test("EarthShield: matches when buff down", function()
    local state = resto.build_state(ctx)
    state.earth_shield_up = false
    assert_true(resto.strategies[1].matches(ctx, state), "EarthShield should match when buff down")
end)

test("EarthShield: does not match when buff up", function()
    local state = resto.build_state(ctx)
    state.earth_shield_up = true
    assert_false(resto.strategies[1].matches(ctx, state), "EarthShield should not match when buff up")
end)

-- Riptide (2): riptide_remains < 3
test("Riptide: matches when buff expiring", function()
    local state = resto.build_state(ctx)
    state.riptide_remains = 1
    assert_true(resto.strategies[2].matches(ctx, state), "Riptide should match when remains < 3")
end)

test("Riptide: does not match when buff fresh", function()
    local state = resto.build_state(ctx)
    state.riptide_remains = 10
    assert_false(resto.strategies[2].matches(ctx, state), "Riptide should not match when remains >= 3")
end)

-- ChainHeal (3): enemy_count >= 2 and mana_pct >= 25
test("ChainHeal: matches with 2+ enemies and mana >= 25", function()
    local state = resto.build_state(ctx)
    state.enemy_count = 2
    state.mana_pct = 25
    assert_true(resto.strategies[3].matches(ctx, state), "ChainHeal should match with 2+ targets and mana >= 25")
end)

test("ChainHeal: does not match single target", function()
    local state = resto.build_state(ctx)
    state.enemy_count = 1
    state.mana_pct = 100
    assert_false(resto.strategies[3].matches(ctx, state), "ChainHeal should not match single target")
end)

test("ChainHeal: does not match when mana < 25", function()
    local state = resto.build_state(ctx)
    state.enemy_count = 3
    state.mana_pct = 20
    assert_false(resto.strategies[3].matches(ctx, state), "ChainHeal should not match when mana < 25")
end)

-- HealingWave (4): target_hp < 70 and mana_pct >= 20
test("HealingWave: matches when target < 70 and mana >= 20", function()
    local state = resto.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 20
    assert_true(resto.strategies[4].matches(ctx, state), "HealingWave should match with target < 70 and mana >= 20")
end)

test("HealingWave: does not match when target >= 70", function()
    local state = resto.build_state(ctx)
    state.target_hp = 75
    state.mana_pct = 100
    assert_false(resto.strategies[4].matches(ctx, state), "HealingWave should not match when target >= 70")
end)

test("HealingWave: does not match when mana < 20", function()
    local state = resto.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 10
    assert_false(resto.strategies[4].matches(ctx, state), "HealingWave should not match when mana < 20")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
