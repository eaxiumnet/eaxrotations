-- test_frost_wotlk_dsl_priority.lua — WotLK Frost mage DSL priority order tests.
-- WHAT:  Validates that the 5 frost_wotlk strategies are compiled correctly by the DSL
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
    MageSpells = {
        Frostbolt = make_action(27072, "Frostbolt"),
        FrostfireBolt = make_action(47610, "FrostfireBolt"),
        IceLance = make_action(30455, "IceLance"),
        DeepFreeze = make_action(44572, "DeepFreeze"),
        ColdSnap = make_action(12472, "ColdSnap"),
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
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function(unit, ids)
        -- By default, FrostfireBolt debuff is not present (remains = 0)
        -- Frostbolt debuff is not present either
        return 0
    end,
    debuff_stacks = function() return 0 end,
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
            _G.EaxRotations._registered_frost = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_frost_wotlk_dsl_priority ===")

local frost = dofile("EaxRotations/classes/mage/frost_wotlk.lua")
assert_true(type(frost) == "table", "frost_wotlk should return a table")
assert_true(type(frost.strategies) == "table", "frost_wotlk should expose strategies")
assert_true(#frost.strategies == 5, "frost_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_frost
assert_true(registered ~= nil, "frost_wotlk should register under 'frost'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "ColdSnap",
    "DeepFreeze",
    "FrostfireBolt",
    "IceLance",
    "Frostbolt",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(frost.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], frost.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- ColdSnap: should match when HP < 50
test("ColdSnap: matches when HP < 50", function()
    local orig_hp = _G.EaxRotations.me.get_health_percentage
    _G.EaxRotations.me.get_health_percentage = function() return 40 end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[1].matches(ctx, state)
    _G.EaxRotations.me.get_health_percentage = orig_hp
    assert_true(ok, "ColdSnap should match when HP < 50")
end)

-- ColdSnap: should NOT match when HP >= 50
test("ColdSnap: does not match when HP >= 50", function()
    local state = frost.build_state(ctx)
    assert_false(frost.strategies[1].matches(ctx, state), "ColdSnap should not match when HP >= 50")
end)

-- DeepFreeze: should match when target is frozen
test("DeepFreeze: matches when target is frozen", function()
    local orig_debuff = _G.EaxRotations.debuff_up
    _G.EaxRotations.debuff_up = function(unit, ids) return true end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[2].matches(ctx, state)
    _G.EaxRotations.debuff_up = orig_debuff
    assert_true(ok, "DeepFreeze should match when target is frozen")
end)

-- DeepFreeze: should NOT match when target is not frozen
test("DeepFreeze: does not match when target is not frozen", function()
    local state = frost.build_state(ctx)
    assert_false(frost.strategies[2].matches(ctx, state), "DeepFreeze should not match when target is not frozen")
end)

-- FrostfireBolt: should match when debuff remains < 3 and mana >= 20
test("FrostfireBolt: matches when debuff remains < 3 and mana >= 20", function()
    local state = frost.build_state({
        in_combat = true,
        target = { get_health_percentage = function() return 100 end },
        settings = {},
    })
    -- frostfire_remains defaults to 0 (debuff_remains returns 0)
    -- mana_pct defaults to 80 from mock
    assert_true(frost.strategies[3].matches({ in_combat = true, target = {}, settings = {} }, state),
        "FrostfireBolt should match when debuff remains < 3 and mana >= 20")
end)

-- FrostfireBolt: should NOT match when debuff remains >= 3
test("FrostfireBolt: does not match when debuff remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[3].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "FrostfireBolt should not match when debuff remains >= 3")
end)

-- FrostfireBolt: should NOT match when mana < 20
test("FrostfireBolt: does not match when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 15 end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "FrostfireBolt should not match when mana < 20")
end)

-- IceLance: should match when target is frozen
test("IceLance: matches when target is frozen", function()
    local orig_debuff = _G.EaxRotations.debuff_up
    _G.EaxRotations.debuff_up = function(unit, ids) return true end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[4].matches(ctx, state)
    _G.EaxRotations.debuff_up = orig_debuff
    assert_true(ok, "IceLance should match when target is frozen")
end)

-- IceLance: should NOT match when target is not frozen
test("IceLance: does not match when target is not frozen", function()
    local state = frost.build_state(ctx)
    assert_false(frost.strategies[4].matches(ctx, state), "IceLance should not match when target is not frozen")
end)

-- Frostbolt: should match when mana >= 15
test("Frostbolt: matches when mana >= 15", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[5].matches(ctx, state), "Frostbolt should match when mana >= 15")
end)

-- Frostbolt: should NOT match when mana < 15
test("Frostbolt: does not match when mana < 15", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 10 end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "Frostbolt should not match when mana < 15")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
