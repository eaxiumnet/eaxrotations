-- test_fire_wotlk_dsl_priority.lua — WotLK Fire mage DSL priority order tests.
-- WHAT:  Validates that the 5 fire_wotlk strategies are compiled correctly by the DSL
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
        Pyroblast = make_action(11366, "Pyroblast"),
        LivingBomb = make_action(44457, "LivingBomb"),
        Scorch = make_action(27073, "Scorch"),
        Fireball = make_action(42833, "Fireball"),
        Combustion = make_action(11129, "Combustion"),
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
    buff_remains = function() return 0 end,
    debuff_up = function(unit, ids) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    should_use_long_cd = function(ctx, cd) return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_fire = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_fire_wotlk_dsl_priority ===")

local fire = dofile("EaxRotations/classes/mage/fire_wotlk.lua")
assert_true(type(fire) == "table", "fire_wotlk should return a table")
assert_true(type(fire.strategies) == "table", "fire_wotlk should expose strategies")
assert_true(#fire.strategies == 5, "fire_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_fire
assert_true(registered ~= nil, "fire_wotlk should register under 'fire'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Combustion",
    "Pyroblast",
    "LivingBomb",
    "Scorch",
    "Fireball",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(fire.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], fire.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- Pyroblast: matches when hot_streak_proc is true
test("Pyroblast: matches when hot streak procs", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "Pyroblast should match when hot streak is proc'd")
end)

-- Pyroblast: does NOT match when hot_streak_proc is false
test("Pyroblast: does not match without hot streak", function()
    local state = fire.build_state(ctx)
    assert_false(fire.strategies[2].matches(ctx, state), "Pyroblast should not match without hot streak")
end)

-- LivingBomb: matches when remains < 3
test("LivingBomb: matches when debuff remains < 3", function()
    local state = fire.build_state(ctx)
    assert_true(fire.strategies[3].matches(ctx, state), "LivingBomb should match when remains < 3")
end)

-- LivingBomb: does NOT match when remains >= 3
test("LivingBomb: does not match when debuff remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[3].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "LivingBomb should not match when remains >= 3")
end)

-- Scorch: matches when remains < 3 and mana >= 15
test("Scorch: matches when debuff remains < 3 and mana >= 15", function()
    local state = fire.build_state(ctx)
    assert_true(fire.strategies[4].matches(ctx, state), "Scorch should match when remains < 3 and mana >= 15")
end)

-- Scorch: does NOT match when remains >= 3
test("Scorch: does not match when debuff remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[4].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "Scorch should not match when remains >= 3")
end)

-- Scorch: does NOT match when mana < 15
test("Scorch: does not match when mana < 15", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 10 end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "Scorch should not match when mana < 15")
end)

-- Fireball: matches when mana >= 20
test("Fireball: matches when mana >= 20", function()
    local state = fire.build_state(ctx)
    assert_true(fire.strategies[5].matches(ctx, state), "Fireball should match when mana >= 20")
end)

-- Fireball: does NOT match when mana < 20
test("Fireball: does not match when mana < 20", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 15 end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "Fireball should not match when mana < 20")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
