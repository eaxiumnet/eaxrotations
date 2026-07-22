-- test_protection_wotlk_dsl_priority.lua — WotLK Protection warrior DSL priority order tests.
-- WHAT:  Validates that the 6 protection_wotlk strategies are compiled correctly by the DSL
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
    WarriorSpells = {
        ShieldSlam = make_action(30356, "ShieldSlam"),
        Revenge = make_action(30357, "Revenge"),
        Devastate = make_action(30022, "Devastate"),
        HeroicStrike = make_action(47497, "HeroicStrike"),
        ThunderClap = make_action(47502, "ThunderClap"),
        ShieldBlock = make_action(2565, "ShieldBlock"),
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {
        get_class = function() return 1 end,
        get_rage = function() return 50 end,
        get_health_percentage = function() return 80 end,
        get_stance = function() return 2 end,
    } end,
    me = {
        get_rage = function() return 50 end,
        get_health_percentage = function() return 80 end,
        get_stance = function() return 2 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function(unit, ids)
        -- By default, ThunderClap debuff is not present (remains = 0)
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
    should_use_long_cd = function(ctx, cd) return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_protection = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_protection_wotlk_dsl_priority ===")

local prot = dofile("EaxRotations/classes/warrior/protection_wotlk.lua")
assert_true(type(prot) == "table", "protection_wotlk should return a table")
assert_true(type(prot.strategies) == "table", "protection_wotlk should expose strategies")
assert_true(#prot.strategies == 6, "protection_wotlk should have 6 strategies")

local registered = _G.EaxRotations._registered_protection
assert_true(registered ~= nil, "protection_wotlk should register under 'protection'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "ShieldBlock",
    "ShieldSlam",
    "Revenge",
    "ThunderClap",
    "Devastate",
    "HeroicStrike",
}

test("priority order: 6 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(prot.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], prot.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- ShieldBlock: should match when ready (cooldown <= 0)
test("ShieldBlock: matches when ready", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[1].matches(ctx, state), "ShieldBlock should match when ready")
end)

-- ShieldBlock: should NOT match when not in combat
test("ShieldBlock: does not match when out of combat", function()
    local state = prot.build_state({ in_combat = false, target = {}, settings = {} })
    assert_false(prot.strategies[1].matches({ in_combat = false, target = {}, settings = {} }, state),
        "ShieldBlock should not match when out of combat")
end)

-- ShieldSlam: should match when rage >= 20
test("ShieldSlam: matches when rage >= 20", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[2].matches(ctx, state), "ShieldSlam should match when rage >= 20")
end)

-- ShieldSlam: should NOT match when rage < 20
test("ShieldSlam: does not match when rage < 20", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 15 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[2].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "ShieldSlam should not match when rage < 20")
end)

-- Revenge: should match when rage >= 5
test("Revenge: matches when rage >= 5", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[3].matches(ctx, state), "Revenge should match when rage >= 5")
end)

-- Revenge: should NOT match when rage < 5
test("Revenge: does not match when rage < 5", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 3 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "Revenge should not match when rage < 5")
end)

-- ThunderClap: should match when debuff remains < 3 and rage >= 20
test("ThunderClap: matches when debuff remains < 3 and rage >= 20", function()
    local state = prot.build_state({
        in_combat = true,
        target = { get_health_percentage = function() return 100 end },
        settings = {},
        enemy_count = 2,
    })
    -- tclap_remains defaults to 0 (since debuff_remains returns 0)
    assert_true(prot.strategies[4].matches({ in_combat = true, target = {}, settings = {} }, state),
        "ThunderClap should match when debuff remains 0 and rage >= 20")
end)

-- ThunderClap: should NOT match when debuff remains >= 3
test("ThunderClap: does not match when debuff remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = prot.build_state({ in_combat = true, target = {}, settings = {} })
    local ok = prot.strategies[4].matches({ in_combat = true, target = {}, settings = {} }, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "ThunderClap should not match when debuff remains >= 3")
end)

-- Devastate: should match when rage >= 15
test("Devastate: matches when rage >= 15", function()
    local state = prot.build_state(ctx)
    assert_true(prot.strategies[5].matches(ctx, state), "Devastate should match when rage >= 15")
end)

-- Devastate: should NOT match when rage < 15
test("Devastate: does not match when rage < 15", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 10 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_false(ok, "Devastate should not match when rage < 15")
end)

-- HeroicStrike: should match when rage >= 60
test("HeroicStrike: matches when rage >= 60", function()
    local orig_rage = _G.EaxRotations.me.get_rage
    _G.EaxRotations.me.get_rage = function() return 65 end
    local state = prot.build_state(ctx)
    local ok = prot.strategies[6].matches(ctx, state)
    _G.EaxRotations.me.get_rage = orig_rage
    assert_true(ok, "HeroicStrike should match when rage >= 60")
end)

-- HeroicStrike: should NOT match when rage < 60
test("HeroicStrike: does not match when rage < 60", function()
    local state = prot.build_state(ctx)
    assert_false(prot.strategies[6].matches(ctx, state), "HeroicStrike should not match when rage < 60")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
