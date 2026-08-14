-- test_fury_wotlk_dsl_priority.lua — WotLK Fury warrior DSL priority order tests.
-- WHAT:  Validates that the 8 fury_wotlk strategies are compiled correctly by the DSL
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

-- Build action-object mocks matching fury_wotlk.lua's ACTION table shape.
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

-- Make a DeathWish action that starts on cooldown (for gate testing)
local function make_action_cd(ids, label, cd_remaining)
    local a = make_action(ids, label)
    a.cooldown_remaining = function() return cd_remaining or 99 end
    return a
end

_G.EaxRotations = {
    WarriorSpells = {
        Bloodthirst = make_action(30335, "Bloodthirst"),
        Whirlwind = make_action(1680, "Whirlwind"),
        Slam = make_action(47475, "Slam"),
        Execute = make_action(47498, "Execute"),
        DeathWish = make_action_cd(12292, "DeathWish", 0),
        BattleShout = make_action(47436, "BattleShout"),
        Pummel = make_action(6554, "Pummel"),
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {
        get_class = function() return 1 end,
        get_power = function(self, p) return 50 end, -- W3.4: real member (me:get_rage is mock-only)
        get_health_percentage = function() return 80 end,
        get_stance = function() return 3 end,
    } end,
    me = {
        get_power = function(self, p) return 50 end, -- W3.4: real member (me:get_rage is mock-only)
        get_health_percentage = function() return 80 end,
        get_stance = function() return 3 end,
    },
    spell_action = make_action,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function(unit, ids)
        -- By default, BattleShout is not up
        return false
    end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    debuff_stacks = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_interruptible = function() return true end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return true end,
    gate_cooldown_boss_only = function() return false end,
    broken_api_throttled = function() return false end,
    time_now = function() return 0 end,
    should_use_long_cd = function(ctx, cd) return true end,
    log = function() end,
    log_warning = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_fury = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

package.loaded["shared/aoe_hit_volume_sylvanas"] = nil

print("=== test_fury_wotlk_dsl_priority ===")

local fury = dofile("EaxRotations/classes/warrior/fury_wotlk.lua")
assert_true(type(fury) == "table", "fury_wotlk should return a table")
assert_true(type(fury.strategies) == "table", "fury_wotlk should expose strategies")
assert_true(#fury.strategies == 8, "fury_wotlk should have 8 strategies")

local registered = _G.EaxRotations._registered_fury
assert_true(registered ~= nil, "fury_wotlk should register under 'fury'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Pummel",
    "BattleShout",
    "DeathWish",
    "Execute",
    "Bloodthirst",
    "Whirlwind",
    "Slam",
    "BerserkerStance",
}

test("priority order: 7 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(fury.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], fury.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }
local cast_ctx = { in_combat = true, target = { is_casting = function() return true end }, settings = {} }

-- Pummel (1): matches when in combat and target is casting (baseline interrupt)
test("Pummel: matches when target is casting", function()
    local state = fury.build_state(cast_ctx)
    assert_true(fury.strategies[1].matches(cast_ctx, state), "Pummel should match when target is casting")
end)

-- Pummel: should NOT match when target is not casting
test("Pummel: does not match when target is not casting", function()
    local state = fury.build_state(ctx)
    assert_false(fury.strategies[1].matches(ctx, state), "Pummel should not match when target is not casting")
end)

-- Pummel: should NOT match out of combat
test("Pummel: does not match when out of combat", function()
    local state = fury.build_state({ in_combat = false, target = { is_casting = function() return true end }, settings = {} })
    assert_false(fury.strategies[1].matches({ in_combat = false, target = { is_casting = function() return true end }, settings = {} }, state),
        "Pummel should not match when out of combat")
end)

-- BattleShout (2): should match when buff is down
test("BattleShout: matches when buff is down", function()
    local state = fury.build_state(ctx)
    local s = fury.strategies[2]
    assert_true(s.name == "BattleShout", "strategy[2] is BattleShout")
    assert_true(s.matches(ctx, state), "BattleShout should match when buff is down")
end)

-- BattleShout: should NOT match when buff is up
test("BattleShout: does not match when buff is up", function()
    local orig_buff_up = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end
    local state = fury.build_state(ctx)
    local ok = fury.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff_up
    assert_false(ok, "BattleShout should not match when buff is up")
end)

-- DeathWish (3): should match when in combat and ready
test("DeathWish: matches when in combat and ready", function()
    local state = fury.build_state(ctx)
    assert_true(fury.strategies[3].matches(ctx, state), "DeathWish should match when ready")
end)

-- DeathWish: should NOT match when should_use_long_cd returns false
test("DeathWish: does not match when long CD blocked", function()
    local orig_long_cd = _G.EaxRotations.should_use_long_cd
    _G.EaxRotations.should_use_long_cd = function(ctx, cd) return false end
    local state = fury.build_state(ctx)
    local ok = fury.strategies[3].matches(ctx, state)
    _G.EaxRotations.should_use_long_cd = orig_long_cd
    assert_false(ok, "DeathWish should not match when long CD blocked")
end)

-- Execute (4): should match when target HP < 20% and rage >= 10
test("Execute: matches when target HP < 20% and rage >= 10", function()
    local state = fury.build_state({ in_combat = true, target = { get_health_percentage = function() return 15 end }, settings = {} })
    assert_true(fury.strategies[4].matches({ in_combat = true, target = {}, settings = {} }, state),
        "Execute should match when target HP < 20% and rage >= 10")
end)

-- Execute: should NOT match when target HP >= 20%
test("Execute: does not match when target HP >= 20%", function()
    local state = fury.build_state({ in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {} })
    assert_false(fury.strategies[4].matches({ in_combat = true, target = {}, settings = {} }, state),
        "Execute should not match when target HP >= 20%")
end)

-- Bloodthirst (5): should match when rage >= 30
test("Bloodthirst: matches when rage >= 30", function()
    local state = fury.build_state(ctx)
    assert_true(fury.strategies[5].matches(ctx, state), "Bloodthirst should match when rage >= 30")
end)

-- Bloodthirst: should NOT match when rage < 30
test("Bloodthirst: does not match when rage < 30", function()
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.me.get_power = function() return 20 end
    local state = fury.build_state(ctx)
    local ok = fury.strategies[5].matches(ctx, state)
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "Bloodthirst should not match when rage < 30")
end)

-- Whirlwind (6): should match when rage >= 25
test("Whirlwind: matches when rage >= 25", function()
    local state = fury.build_state(ctx)
    assert_true(fury.strategies[6].matches(ctx, state), "Whirlwind should match when rage >= 25")
end)

-- Slam (7): Bloodsurge-proc-gated (wowsims fury APL: auraIsActive 46916/70847);
-- should match when rage >= 15 AND the proc is up
test("Slam: matches when rage >= 15 with Bloodsurge proc", function()
    local orig_buff_up = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end -- Bloodsurge proc up
    local state = fury.build_state(ctx)
    local ok = fury.strategies[7].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff_up
    assert_true(ok, "Slam should match when rage >= 15 and Bloodsurge is up")
end)

-- Slam: should NOT match when the Bloodsurge proc is down (no free-cast spam)
test("Slam: does not match without Bloodsurge proc", function()
    local state = fury.build_state(ctx)
    assert_false(fury.strategies[7].matches(ctx, state), "Slam must not fire without Bloodsurge (proc gate)")
end)

-- Slam: should NOT match when rage < 15 even with the proc
test("Slam: does not match when rage < 15", function()
    local orig_buff_up = _G.EaxRotations.buff_up
    local orig_rage = _G.EaxRotations.me.get_power
    _G.EaxRotations.buff_up = function(unit, ids) return true end
    _G.EaxRotations.me.get_power = function() return 10 end
    local state = fury.build_state(ctx)
    local ok = fury.strategies[7].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff_up
    _G.EaxRotations.me.get_power = orig_rage
    assert_false(ok, "Slam should not match when rage < 15")
end)

-- BerserkerStance (8): the APL's final lane — dance when not in Berserker
test("BerserkerStance: matches when not in Berserker stance", function()
    local orig_stance = _G.EaxRotations.me.get_stance
    _G.EaxRotations.me.get_stance = function() return 1 end
    local state = fury.build_state(ctx)
    local ok = fury.strategies[8].matches(ctx, state)
    _G.EaxRotations.me.get_stance = orig_stance
    assert_true(ok, "BerserkerStance should match from Battle stance in combat")
end)

test("BerserkerStance: does not match when already in Berserker", function()
    local state = fury.build_state(ctx)
    assert_false(fury.strategies[8].matches(ctx, state), "BerserkerStance should not match when already Berserker")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
