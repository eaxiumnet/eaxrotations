-- test_frost_deathknight_wotlk_dsl_priority.lua — WotLK Frost death knight DSL priority order tests.
-- WHAT:  Validates that the 10 frost_wotlk DSL strategies + interrupt + FrostPresence are
--        compiled correctly and that their match gates fire in expected priority order.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   Regression guard for the WotLK Frost DK DSL adoption.
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
    get_blood_runes_ready = function() return 1 end,
    get_frost_runes_ready = function() return 1 end,
    get_unholy_runes_ready = function() return 1 end,
    get_death_runes_ready = function() return 0 end,
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
        Obliterate        = make_action(51425, "Obliterate"),
        HowlingBlast      = make_action(51411, "HowlingBlast"),
        FrostStrike       = make_action(51419, "FrostStrike"),
        BloodStrike       = make_action(49930, "BloodStrike"),
        HornOfWinter      = make_action(57330, "HornOfWinter"),
        UnbreakableArmor  = make_action(51271, "UnbreakableArmor"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
        MindFreeze        = make_action(47528, "MindFreeze"),
        FrostPresence     = make_action(48263, "FrostPresence"),
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
            _G.EaxRotations._registered_frost = { strategies = strategies, options = options }
        end,
    },
}

print("=== test_frost_deathknight_wotlk_dsl_priority ===")

local frost = dofile("EaxRotations/classes/deathknight/frost_wotlk.lua")
assert_true(type(frost) == "table", "frost_wotlk should return a table")
assert_true(type(frost.strategies) == "table", "frost_wotlk should expose strategies")

-- 10 DSL strategies + FrostPresence (manual) + interrupt = 12 total
assert_true(#frost.strategies == 12, "frost_wotlk should have 12 strategies (10 DSL + FrostPresence + interrupt)")

local registered = _G.EaxRotations._registered_frost
assert_true(registered ~= nil, "frost_wotlk should register under 'frost'")

-- ============================================================================
-- Priority order: verify the first strategy is the interrupt, then expected order
-- ============================================================================
local expected_order = {
    "MindFreeze",      -- interrupt_strategy (injected by interrupt_manager)
    "HornOfWinter",
    "FrostPresence",   -- kept manual (complex presence logic)
    "UnbreakableArmor",
    "EmpowerRuneWeapon",
    "IcyTouch",
    "PlagueStrike",
    "HowlingBlast",
    "FrostStrikeKM",
    "Obliterate",
    "FrostStrike",
    "BloodStrike",
}

test("priority order: 12 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(frost.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], frost.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- HornOfWinter: matches when buff is down
test("HornOfWinter: matches when horn_of_winter is down", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[2].matches(ctx, state), "HornOfWinter should match when buff is down")
end)

-- HornOfWinter: does NOT match when buff is up
test("HornOfWinter: does not match when horn_of_winter is up", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "HornOfWinter should not match when buff is up")
end)

-- UnbreakableArmor: matches when in combat, not up, and ready
test("UnbreakableArmor: matches when in combat, not up, and ready", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[4].matches(ctx, state), "UnbreakableArmor should match in combat when not up and ready")
end)

-- UnbreakableArmor: does NOT match when out of combat
test("UnbreakableArmor: does not match when out of combat", function()
    local state = frost.build_state({ target = {}, in_combat = false })
    assert_false(frost.strategies[4].matches(ctx, state), "UnbreakableArmor should not match out of combat")
end)

-- EmpowerRuneWeapon: matches when in combat, ready, and no runes
test("EmpowerRuneWeapon: matches when in combat, ready, and no runes", function()
    local orig_blood = package.loaded["shared/rune_manager_sylvanas"].get_blood_runes_ready
    local orig_frost = package.loaded["shared/rune_manager_sylvanas"].get_frost_runes_ready
    local orig_unholy = package.loaded["shared/rune_manager_sylvanas"].get_unholy_runes_ready
    local orig_death = package.loaded["shared/rune_manager_sylvanas"].get_death_runes_ready
    package.loaded["shared/rune_manager_sylvanas"].get_blood_runes_ready = function() return 0 end
    package.loaded["shared/rune_manager_sylvanas"].get_frost_runes_ready = function() return 0 end
    package.loaded["shared/rune_manager_sylvanas"].get_unholy_runes_ready = function() return 0 end
    package.loaded["shared/rune_manager_sylvanas"].get_death_runes_ready = function() return 0 end
    local ok, matched = pcall(function()
        local state = frost.build_state(ctx)
        return frost.strategies[5].matches(ctx, state)
    end)
    package.loaded["shared/rune_manager_sylvanas"].get_blood_runes_ready = orig_blood
    package.loaded["shared/rune_manager_sylvanas"].get_frost_runes_ready = orig_frost
    package.loaded["shared/rune_manager_sylvanas"].get_unholy_runes_ready = orig_unholy
    package.loaded["shared/rune_manager_sylvanas"].get_death_runes_ready = orig_death
    assert_true(ok and matched, "EmpowerRuneWeapon should match when no runes are ready" .. (ok and "" or ": " .. tostring(matched)))
end)

-- IcyTouch: matches when frost_fever_remains < 3
test("IcyTouch: matches when frost fever remains < 3", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[6].matches(ctx, state), "IcyTouch should match when frost fever < 3")
end)

-- IcyTouch: does NOT match when frost_fever_remains >= 3
test("IcyTouch: does not match when frost fever remains >= 3", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[6].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "IcyTouch should not match when frost fever >= 3")
end)

-- PlagueStrike: matches when blood_plague_remains < 3
test("PlagueStrike: matches when blood plague remains < 3", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[7].matches(ctx, state), "PlagueStrike should match when blood plague < 3")
end)

-- FrostStrikeKM: matches when Killing Machine proc and runic_power >= 40
test("FrostStrikeKM: matches when Killing Machine proc and RP >= 40", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids)
        -- Killing Machine buff id is 51124; ids table contains that id
        if type(ids) == "table" and ids[1] == 51124 then return true end
        return false
    end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[9].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "FrostStrikeKM should match with Killing Machine proc and RP >= 40")
end)

-- FrostStrikeKM: does NOT match without Killing Machine
test("FrostStrikeKM: does not match without Killing Machine", function()
    local state = frost.build_state(ctx)
    assert_false(frost.strategies[9].matches(ctx, state), "FrostStrikeKM should not match without Killing Machine")
end)

-- FrostStrike: matches when runic_power >= 40
test("FrostStrike: matches when runic_power >= 40", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[11].matches(ctx, state), "FrostStrike should match when runic_power >= 40")
end)

-- BloodStrike: matches when blood/death runes available
test("BloodStrike: matches when blood/death runes available", function()
    local state = frost.build_state(ctx)
    assert_true(frost.strategies[12].matches(ctx, state), "BloodStrike should match when blood/death runes available")
end)

-- HowlingBlast: matches when Rime proc is active
test("HowlingBlast: matches when Rime proc is active", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids)
        if type(ids) == "table" and ids[1] == 59052 then return true end
        return false
    end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[8].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "HowlingBlast should match when Rime proc is active")
end)

-- HowlingBlast: does NOT match without Rime proc or AoE
test("HowlingBlast: does not match without Rime proc or AoE", function()
    _G.EaxRotations.aoe_target_meets = function() return false end
    local state = frost.build_state(ctx)
    assert_false(frost.strategies[8].matches(ctx, state), "HowlingBlast should not match without Rime proc or AoE")
end)

-- Obliterate: matches when both diseases are up and runes available
test("Obliterate: matches when both diseases are up and runes available", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = frost.build_state(ctx)
    local ok = frost.strategies[10].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_true(ok, "Obliterate should match when both diseases are up and runes available")
end)

-- Obliterate: does NOT match when diseases are down
test("Obliterate: does not match when diseases are down", function()
    local state = frost.build_state(ctx)
    assert_false(frost.strategies[10].matches(ctx, state), "Obliterate should not match when diseases are down")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
