-- test_deathknight_leveling_wotlk_dsl_priority.lua — WotLK Death Knight leveling DSL priority tests.
-- WHAT:  Validates that the 17 death knight leveling_wotlk strategies are compiled by the DSL
--        and that their match gates (incl. AoE, disease, and long-CD gates) fire in order.
-- WHEN:  run_wotlk_tests.lua, run_rotation_tests.lua, run_leveling_tests.lua.
-- WHY:   Regression guard for DSL-based leveling strategy definitions.
-- SAFETY: Standalone; mocks all NS dependencies and shared modules.

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

package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function(NS) end }
package.loaded["shared/leveling_helpers_sylvanas"] = { should_interrupt = function(target) return false end }

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch = make_action(49909, "IcyTouch"),
        PlagueStrike = make_action(49922, "PlagueStrike"),
        BloodStrike = make_action(49930, "BloodStrike"),
        DeathStrike = make_action(49998, "DeathStrike"),
        HeartStrike = make_action(55263, "HeartStrike"),
        Obliterate = make_action(51425, "Obliterate"),
        HowlingBlast = make_action(51411, "HowlingBlast"),
        ScourgeStrike = make_action(55271, "ScourgeStrike"),
        DeathCoil = make_action(47541, "DeathCoil"),
        HornOfWinter = make_action(57623, "HornOfWinter"),
        MindFreeze = make_action(47528, "MindFreeze"),
        BloodPresence = make_action(48266, "BloodPresence"),
        Pestilence = make_action(50842, "Pestilence"),
        DeathAndDecay = make_action(43265, "DeathAndDecay"),
        BloodBoil = make_action(48721, "BloodBoil"),
        RuneStrike = make_action(56815, "RuneStrike"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_runic_power = function() return 0 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_runic_power = function() return 0 end,
    },
    AOE_RADIUS = { SELF_10 = 10, TARGET_10 = 10, GROUND_10 = 10 },
    aoe_self_meets = function(count, radius, context, state) return true end,
    aoe_target_meets = function(count, radius, target, context, state) return true end,
    should_use_long_cd = function(context, cd) return true end,
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
            _G.EaxRotations._registered_leveling = { name = name, strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_deathknight_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/deathknight/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 17, "leveling_wotlk should have 17 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "MindFreeze",
    "BloodPresence",
    "HornOfWinter",
    "IcyTouch",
    "PlagueStrike",
    "Pestilence",
    "DeathAndDecay",
    "BloodBoil",
    "DeathStrike",
    "Obliterate",
    "ScourgeStrike",
    "HeartStrike",
    "HowlingBlast",
    "BloodStrike",
    "RuneStrike",
    "DeathCoil",
    "EmpowerRuneWeapon",
}

test("priority order: 17 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- MindFreeze (1): in_combat and target_casting == true
test("MindFreeze: matches when target casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    assert_true(lv.strategies[1].matches(ctx, state), "MindFreeze should match when target casting")
end)

test("MindFreeze: does not match when not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    assert_false(lv.strategies[1].matches(ctx, state), "MindFreeze should not match when not casting")
end)

-- BloodPresence (2): not blood_presence_up (fires in or out of combat)
test("BloodPresence: matches when presence down", function()
    local state = lv.build_state(ctx)
    state.blood_presence_up = false
    assert_true(lv.strategies[2].matches(ctx, state), "BloodPresence should match when presence down")
end)

test("BloodPresence: does not match when presence up", function()
    local state = lv.build_state(ctx)
    state.blood_presence_up = true
    assert_false(lv.strategies[2].matches(ctx, state), "BloodPresence should not match when presence up")
end)

-- HornOfWinter (3): not horn_of_winter_up
test("HornOfWinter: matches when horn down", function()
    local state = lv.build_state(ctx)
    state.horn_of_winter_up = false
    assert_true(lv.strategies[3].matches(ctx, state), "HornOfWinter should match when horn down")
end)

-- IcyTouch (4): in_combat and frost_fever_remains < 3
test("IcyTouch: matches when frost fever missing", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.frost_fever_remains = 0
    assert_true(lv.strategies[4].matches(ctx, state), "IcyTouch should match when frost fever missing")
end)

test("IcyTouch: does not match when frost fever fresh", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.frost_fever_remains = 10
    assert_false(lv.strategies[4].matches(ctx, state), "IcyTouch should not match when frost fever fresh")
end)

-- PlagueStrike (5): in_combat and blood_plague_remains < 3
test("PlagueStrike: matches when blood plague missing", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.blood_plague_remains = 0
    assert_true(lv.strategies[5].matches(ctx, state), "PlagueStrike should match when blood plague missing")
end)

-- Pestilence (6): in_combat and diseases_up == true and AoE gate
test("Pestilence: matches with diseases up and AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.diseases_up = true
    assert_true(lv.strategies[6].matches(ctx, state), "Pestilence should match with diseases up")
end)

test("Pestilence: does not match without diseases", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.diseases_up = false
    assert_false(lv.strategies[6].matches(ctx, state), "Pestilence should not match without diseases")
end)

-- DeathAndDecay (7): in_combat and AoE gate
test("DeathAndDecay: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    assert_true(lv.strategies[7].matches(ctx, state), "DeathAndDecay should match when AoE meets")
end)

-- BloodBoil (8): in_combat and self AoE gate
test("BloodBoil: matches when AoE meets", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    assert_true(lv.strategies[8].matches(ctx, state), "BloodBoil should match when AoE meets")
end)

-- DeathStrike (9): in_combat and hp < 80
test("DeathStrike: matches when hurt", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 50
    assert_true(lv.strategies[9].matches(ctx, state), "DeathStrike should match when hurt")
end)

test("DeathStrike: does not match at full hp", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 100
    assert_false(lv.strategies[9].matches(ctx, state), "DeathStrike should not match at full hp")
end)

-- Obliterate (10): in_combat
test("Obliterate: matches in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    assert_true(lv.strategies[10].matches(ctx, state), "Obliterate should match in combat")
end)

test("Obliterate: does not match out of combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    assert_false(lv.strategies[10].matches(ctx, state), "Obliterate should not match out of combat")
end)

-- RuneStrike (15): in_combat and runic_power >= 30
test("RuneStrike: matches with runic power", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.runic_power = 30
    assert_true(lv.strategies[15].matches(ctx, state), "RuneStrike should match with 30 runic power")
end)

test("RuneStrike: does not match below threshold", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.runic_power = 20
    assert_false(lv.strategies[15].matches(ctx, state), "RuneStrike should not match below 30 runic power")
end)

-- DeathCoil (16): in_combat and runic_power >= 40
test("DeathCoil: matches with high runic power", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.runic_power = 40
    assert_true(lv.strategies[16].matches(ctx, state), "DeathCoil should match with 40 runic power")
end)

-- EmpowerRuneWeapon (17): in_combat and ready and long-CD gate
test("EmpowerRuneWeapon: matches when ready", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.empower_rune_weapon_ready = true
    assert_true(lv.strategies[17].matches(ctx, state), "EmpowerRuneWeapon should match when ready")
end)

test("EmpowerRuneWeapon: does not match when not ready", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.empower_rune_weapon_ready = false
    assert_false(lv.strategies[17].matches(ctx, state), "EmpowerRuneWeapon should not match when not ready")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
