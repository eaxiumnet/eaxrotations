-- test_protection_paladin_wotlk_dsl_priority.lua — WotLK Protection Paladin DSL priority order tests.
-- WHAT:  Validates that the 5 protection_paladin_wotlk strategies are compiled correctly
--        by the DSL and that their match gates fire in the expected priority order.
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
    PaladinSpells = {
        AvengersShield = make_action(48827, "AvengersShield"),
        HammerOfTheRighteous = make_action(53595, "HammerOfTheRighteous"),
        ShieldOfRighteousness = make_action(53600, "ShieldOfRighteousness"),
        Consecration = make_action(48819, "Consecration"),
        Judgement = make_action(20271, "Judgement"),
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {
        get_class = function() return 2 end,
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
    debuff_remains = function(unit, ids) return 0 end,
    debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_protection = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_protection_paladin_wotlk_dsl_priority ===")

local prot = dofile("EaxRotations/classes/paladin/protection_wotlk.lua")
assert_true(type(prot) == "table", "protection_paladin_wotlk should return a table")
assert_true(type(prot.strategies) == "table", "protection_paladin_wotlk should expose strategies")
assert_true(#prot.strategies == 5, "protection_paladin_wotlk should have 5 strategies")

local registered = _G.EaxRotations._registered_protection
assert_true(registered ~= nil, "protection_paladin_wotlk should register under 'protection'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "AvengersShield",
    "ShieldOfRighteousness",
    "HammerOfTheRighteous",
    "Consecration",
    "Judgement",
}

test("priority order: 5 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(prot.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], prot.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- AvengersShield: should match when in combat
test("AvengersShield: matches when in combat", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[1].matches(ctx, state), "AvengersShield should match when in combat")
end)

-- AvengersShield: should NOT match when out of combat
test("AvengersShield: does not match when out of combat", function()
    local state = prot.build_state({ in_combat = false, target = {}, settings = {} })
    assert_false(prot.strategies[1].matches({ in_combat = false, target = {}, settings = {} }, state),
        "AvengersShield should not match when out of combat")
end)

-- HammerOfTheRighteous: should match when in combat
test("HammerOfTheRighteous: matches when in combat", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[2].matches(ctx, state), "HammerOfTheRighteous should match when in combat")
end)

-- ShieldOfRighteousness: should match when in combat
test("ShieldOfRighteousness: matches when in combat", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[3].matches(ctx, state), "ShieldOfRighteousness should match when in combat")
end)

-- Consecration: should match when debuff remains < 3 and mana >= 25
test("Consecration: matches when debuff remains < 3 and mana >= 25", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[4].matches(ctx, state), "Consecration should match when debuff remains < 3 and mana >= 25")
end)

-- Consecration: should NOT match when debuff remains >= 3
test("Consecration: does not match when debuff remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = prot.build_state({ in_combat = true, target = {}, settings = {} })
    local ok = prot.strategies[4].matches({ in_combat = true, target = {}, settings = {} }, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "Consecration should not match when debuff remains >= 3")
end)

-- Consecration: should NOT match when mana < 25
test("Consecration: does not match when mana < 25", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    _G.EaxRotations.me.get_mana_percentage = function() return 20 end
    local state = prot.build_state({ in_combat = true, target = {}, settings = {} })
    local ok = prot.strategies[4].matches({ in_combat = true, target = {}, settings = {} }, state)
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    assert_false(ok, "Consecration should not match when mana < 25")
end)

-- Judgement: should match when in combat
test("Judgement: matches when in combat", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[5].matches(ctx, state), "Judgement should match when in combat")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
