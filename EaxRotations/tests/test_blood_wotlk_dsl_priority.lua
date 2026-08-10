-- test_blood_wotlk_dsl_priority.lua — WotLK Blood death knight DSL priority order tests.
-- WHAT:  Validates that the 11 blood_wotlk strategies + interrupt strategy are compiled
--        correctly by the DSL and that their match gates fire in expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   Regression guard for DSL-based strategy definitions.
-- SAFETY: Standalone; mocks all NS and shared module dependencies.

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

-- Stub shared modules that have complex external dependencies
package.loaded["shared/rune_manager_sylvanas"] = {
    get_runic_power = function(unit) return 50 end,
    get_rune_state = function() return { blood = { ready = true }, frost = { ready = true }, unholy = { ready = true } } end,
    has_rune = function() return true end,
}

package.loaded["shared/presence_manager_sylvanas"] = {
    get_optimal_presence = function() return nil end,
    should_switch_presence = function() return false end,
    presence_id = function(name) return name end,
}

package.loaded["shared/interrupt_manager_sylvanas"] = {
    register_interrupt_spell = function(class, spell, spells)
        return { name = "MindFreeze", matches = function() return false end, execute = function() return false end }
    end,
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch          = make_action(49909, "IcyTouch"),
        PlagueStrike      = make_action(49922, "PlagueStrike"),
        HeartStrike       = make_action(55263, "HeartStrike"),
        DeathStrike       = make_action(49940, "DeathStrike"),
        DeathCoil         = make_action(47541, "DeathCoil"),
        Pestilence        = make_action(50842, "Pestilence"),
        DancingRuneWeapon = make_action(49028, "DancingRuneWeapon"),
        HornOfWinter      = make_action(57330, "HornOfWinter"),
        VampiricBlood     = make_action(55233, "VampiricBlood"),
        IceboundFortitude = make_action(48792, "IceboundFortitude"),
        BloodPresence     = make_action(48266, "BloodPresence"),
    },
    DeathKnightConstants = {
        FROST_FEVER_DEBUFF  = { 55095 },
        BLOOD_PLAGUE_DEBUFF = { 55078 },
        HORN_OF_WINTER_BUFF = { 57330, 57623 },
    },
    me = {
        get_health_percentage = function() return 80 end,
        get_runic_power = function() return 50 end,
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
    is_wotlk = function() return true end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_blood = { strategies = strategies, options = options }
        end,
    },
}

print("=== test_blood_wotlk_dsl_priority ===")

local blood = dofile("EaxRotations/classes/deathknight/blood_wotlk.lua")
assert_true(type(blood) == "table", "blood_wotlk should return a table")
assert_true(type(blood.strategies) == "table", "blood_wotlk should expose strategies")

-- 11 DSL strategies + 1 interrupt strategy = 12 total
assert_true(#blood.strategies == 12, "blood_wotlk should have 12 strategies (11 DSL + 1 interrupt)")

local registered = _G.EaxRotations._registered_blood
assert_true(registered ~= nil, "blood_wotlk should register under 'blood'")

-- ============================================================================
-- Priority order: verify the first strategy is the interrupt, then 11 DSL
-- ============================================================================
local expected_order = {
    "MindFreeze",      -- interrupt_strategy (injected by interrupt_manager)
    "Presence",
    "IceboundFortitude",
    "VampiricBlood",
    "HornOfWinter",
    "DancingRuneWeapon",
    "PlagueStrike",
    "DeathStrike",
    "Pestilence",
    "IcyTouch",
    "HeartStrike",
    "DeathCoil",
}

test("priority order: 12 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(blood.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], blood.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- IceboundFortitude: matches when HP < 40
test("IceboundFortitude: matches when HP < 40", function()
    local orig_hp = _G.EaxRotations.me.get_health_percentage
    _G.EaxRotations.me.get_health_percentage = function() return 30 end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.get_health_percentage = orig_hp
    assert_true(ok, "IceboundFortitude should match when HP < 40")
end)

-- IceboundFortitude: does NOT match when HP >= 40
test("IceboundFortitude: does not match when HP >= 40", function()
    local state = blood.build_state(ctx)
    assert_false(blood.strategies[3].matches(ctx, state), "IceboundFortitude should not match when HP >= 40")
end)

-- VampiricBlood: matches when HP < 50
test("VampiricBlood: matches when HP < 50", function()
    local orig_hp = _G.EaxRotations.me.get_health_percentage
    _G.EaxRotations.me.get_health_percentage = function() return 45 end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[4].matches(ctx, state)
    _G.EaxRotations.me.get_health_percentage = orig_hp
    assert_true(ok, "VampiricBlood should match when HP < 50")
end)

-- VampiricBlood: does NOT match when HP >= 50
test("VampiricBlood: does not match when HP >= 50", function()
    local state = blood.build_state(ctx)
    assert_false(blood.strategies[4].matches(ctx, state), "VampiricBlood should not match when HP >= 50")
end)

-- HornOfWinter: matches when buff is down
test("HornOfWinter: matches when horn_of_winter is down", function()
    local state = blood.build_state(ctx)
    assert_true(blood.strategies[5].matches(ctx, state), "HornOfWinter should match when buff is down")
end)

-- HornOfWinter: does NOT match when buff is up
test("HornOfWinter: does not match when horn_of_winter is up", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[5].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "HornOfWinter should not match when buff is up")
end)

-- IcyTouch: matches when frost_fever_remains < 3
test("IcyTouch: matches when frost fever remains < 3", function()
    local state = blood.build_state(ctx)
    assert_true(blood.strategies[10].matches(ctx, state), "IcyTouch should match when frost fever < 3")
end)

-- IcyTouch: does NOT match when frost_fever_remains >= 3
test("IcyTouch: does not match when frost fever remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[10].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "IcyTouch should not match when frost fever >= 3")
end)

-- PlagueStrike: matches when blood_plague_remains < 3
test("PlagueStrike: matches when blood plague remains < 3", function()
    local state = blood.build_state(ctx)
    assert_true(blood.strategies[7].matches(ctx, state), "PlagueStrike should match when blood plague < 3")
end)

-- PlagueStrike: does NOT match when blood_plague_remains >= 3
test("PlagueStrike: does not match when blood plague remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[7].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "PlagueStrike should not match when blood plague >= 3")
end)

-- DeathStrike: matches when HP < 80
test("DeathStrike: matches when HP < 80", function()
    local orig_hp = _G.EaxRotations.me.get_health_percentage
    _G.EaxRotations.me.get_health_percentage = function() return 70 end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[8].matches(ctx, state)
    _G.EaxRotations.me.get_health_percentage = orig_hp
    assert_true(ok, "DeathStrike should match when HP < 80")
end)

-- DeathStrike: does NOT match when HP >= 80
test("DeathStrike: does not match when HP >= 80", function()
    local state = blood.build_state(ctx)
    assert_false(blood.strategies[8].matches(ctx, state), "DeathStrike should not match when HP >= 80")
end)

-- HeartStrike: always matches (filler, no conditions)
test("HeartStrike: always matches as filler", function()
    local state = blood.build_state(ctx)
    assert_true(blood.strategies[11].matches(ctx, state), "HeartStrike should always match")
end)

-- DeathCoil: matches when runic_power >= 40
test("DeathCoil: matches when runic_power >= 40", function()
    local state = blood.build_state(ctx)
    assert_true(blood.strategies[12].matches(ctx, state), "DeathCoil should match when runic_power >= 40")
end)

-- DeathCoil: does NOT match when runic_power < 40
test("DeathCoil: does not match when runic_power < 40", function()
    local orig_rp = package.loaded["shared/rune_manager_sylvanas"].get_runic_power
    package.loaded["shared/rune_manager_sylvanas"].get_runic_power = function() return 30 end
    local state = blood.build_state(ctx)
    local ok = blood.strategies[12].matches(ctx, state)
    package.loaded["shared/rune_manager_sylvanas"].get_runic_power = orig_rp
    assert_false(ok, "DeathCoil should not match when runic_power < 40")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
