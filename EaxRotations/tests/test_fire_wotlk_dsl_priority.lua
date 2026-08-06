-- test_fire_wotlk_dsl_priority.lua — WotLK Fire mage DSL priority order tests.
-- WHAT:  Validates that the 7 fire_wotlk strategies are compiled correctly by the DSL
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

local runtime_scorch_cast_time = 1.75

_G.EaxRotations = {
    MageSpells = {
        Pyroblast = make_action(42891, "Pyroblast"),
        LivingBomb = make_action(55360, "LivingBomb"),
        Scorch = make_action(42859, "Scorch"),
        FireBlast = make_action(42873, "FireBlast"),
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
    core = {
        spell_book = {
            get_spell_cast_time = function() return runtime_scorch_cast_time end,
        },
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
assert_true(#fire.strategies == 7, "fire_wotlk should have 7 strategies")

local registered = _G.EaxRotations._registered_fire
assert_true(registered ~= nil, "fire_wotlk should register under 'fire'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "Combustion",
    "Scorch",
    "Pyroblast",
    "LivingBomb",
    "FireBlast",
    "ScorchFinal",
    "Fireball",
}

test("priority order: 7 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(fire.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], fire.strategies[i].name))
    end
end)

test("Scorch maintenance outranks Hot Streak Pyroblast", function()
    local orig_cd = _G.EaxRotations.should_use_long_cd
    local orig_buff = _G.EaxRotations.buff_up
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.should_use_long_cd = function() return false end
    _G.EaxRotations.buff_up = function() return true end
    _G.EaxRotations.debuff_remains = function() return 4 end
    local priority_ctx = { in_combat = true, target = {}, ttd = 20, settings = {} }
    local state = fire.build_state(priority_ctx)
    local first_match
    for i = 1, #fire.strategies do
        if fire.strategies[i].matches(priority_ctx, state) then
            first_match = fire.strategies[i].name
            break
        end
    end
    _G.EaxRotations.should_use_long_cd = orig_cd
    _G.EaxRotations.buff_up = orig_buff
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_true(first_match == "Scorch", "expiring Scorch must be selected before Hot Streak Pyroblast")
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

test("WotLK action IDs use the pinned simulator spells", function()
    assert_true(_G.EaxRotations.MageSpells.Pyroblast.id == 42891, "Pyroblast should use 42891")
    assert_true(_G.EaxRotations.MageSpells.LivingBomb.id == 55360, "Living Bomb should use 55360")
    assert_true(_G.EaxRotations.MageSpells.Scorch.id == 42859, "Scorch should use 42859")
    assert_true(_G.EaxRotations.MageSpells.FireBlast.id == 42873, "Fire Blast should use 42873")
end)

test("invalid targets and unknown TTD use safe fallbacks", function()
    local no_target = { in_combat = true, settings = {} }
    local state = fire.build_state(no_target)
    assert_true(state.ttd == 999, "unknown TTD should use the long-lived fallback")
    for i = 1, #fire.strategies do
        assert_false(fire.strategies[i].matches(no_target, state), "strategy " .. i .. " must reject a missing target")
    end
    local zero_ttd = { in_combat = true, target = {}, ttd = 0, settings = {} }
    state = fire.build_state(zero_ttd)
    assert_true(state.ttd == 999, "zero TTD should be treated as unknown")
    assert_false(fire.strategies[5].matches(zero_ttd, state), "unknown TTD must not trigger late Fire Blast")
end)

-- Pyroblast: matches when hot_streak_proc is true
test("Pyroblast: matches when hot streak procs", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[3].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "Pyroblast should match when hot streak is proc'd")
end)

-- Pyroblast: does NOT match when hot_streak_proc is false
test("Pyroblast: does not match without hot streak", function()
    local state = fire.build_state(ctx)
    assert_false(fire.strategies[3].matches(ctx, state), "Pyroblast should not match without hot streak")
end)

test("LivingBomb: matches when the debuff is absent and target TTD is safe", function()
    ctx.ttd = 20
    local state = fire.build_state(ctx)
    ctx.ttd = nil
    assert_true(fire.strategies[4].matches(ctx, state), "LivingBomb should match when absent and TTD is safe")
end)

test("LivingBomb: does not clip an active debuff", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 2 end
    ctx.ttd = 20
    local state = fire.build_state(ctx)
    local ok = fire.strategies[4].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    ctx.ttd = nil
    assert_false(ok, "LivingBomb should not refresh before expiry")
end)

test("LivingBomb: does not apply when target TTD is 12s or less", function()
    ctx.ttd = 12
    local state = fire.build_state(ctx)
    ctx.ttd = nil
    assert_false(fire.strategies[4].matches(ctx, state), "LivingBomb should not start inside its 12s TTD gate")
end)

test("FireBlast: uses runtime Scorch cast time at the late cast boundary", function()
    ctx.ttd = runtime_scorch_cast_time
    local state = fire.build_state(ctx)
    assert_true(fire.strategies[5].matches(ctx, state), "FireBlast should match at the runtime Scorch cast-time boundary")
    ctx.ttd = runtime_scorch_cast_time + 0.01
    state = fire.build_state(ctx)
    assert_false(fire.strategies[5].matches(ctx, state), "FireBlast should not match after the Scorch cast-time boundary")
    ctx.scorch_cast_time = 2
    ctx.ttd = 2
    state = fire.build_state(ctx)
    assert_true(fire.strategies[5].matches(ctx, state), "FireBlast should accept the explicit cast-time test seam")
    ctx.scorch_cast_time = nil
    runtime_scorch_cast_time = 0
    ctx.ttd = 1.5
    state = fire.build_state(ctx)
    ctx.ttd = nil
    assert_false(fire.strategies[5].matches(ctx, state), "FireBlast should fail closed without cast-time data")
end)

test("ScorchFinal: follows FireBlast and only matches at TTD <= 4s", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end

    ctx.ttd = 4
    local state = fire.build_state(ctx)
    assert_true(fire.strategies[5].name == "FireBlast", "FireBlast must precede the final Scorch")
    assert_true(fire.strategies[6].name == "ScorchFinal", "final Scorch must be its own post-FireBlast strategy")
    assert_false(fire.strategies[2].matches(ctx, state), "a non-expiring Scorch aura must disable early Scorch")
    assert_true(fire.strategies[6].matches(ctx, state), "final Scorch should match at 4s TTD")

    ctx.ttd = 5
    state = fire.build_state(ctx)
    assert_false(fire.strategies[6].matches(ctx, state), "final Scorch must not be unconditional above 4s TTD")

    _G.EaxRotations.debuff_remains = orig_debuff
    ctx.ttd = nil
end)

test("Scorch: matches at the 4s boundary without a mana gate", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 4 end
    local state = fire.build_state(ctx)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_true(fire.strategies[2].matches(ctx, state), "Scorch should match at the 4s overlap boundary")
end)

-- Scorch: does NOT match when remains is above 4
test("Scorch: does not match when debuff remains is above 4", function()
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.debuff_remains = function(unit, ids) return 5 end
    local state = fire.build_state(ctx)
    local ok = fire.strategies[2].matches(ctx, state)
    _G.EaxRotations.debuff_remains = orig_debuff
    assert_false(ok, "Scorch should not match when remains is above 4s")
end)

test("LivingBomb, Scorch, and Fireball ignore unsupported mana thresholds", function()
    local orig_mana = _G.EaxRotations.me.get_mana_percentage
    local orig_debuff = _G.EaxRotations.debuff_remains
    _G.EaxRotations.me.get_mana_percentage = function() return 1 end
    _G.EaxRotations.debuff_remains = function() return 0 end
    ctx.ttd = 20
    local state = fire.build_state(ctx)
    assert_true(fire.strategies[4].matches(ctx, state), "LivingBomb should not have a mana threshold")

    _G.EaxRotations.debuff_remains = function() return 4 end
    state = fire.build_state(ctx)
    assert_true(fire.strategies[2].matches(ctx, state), "Scorch should not have a mana threshold")
    ctx.ttd = nil
    state = fire.build_state(ctx)
    assert_true(fire.strategies[7].matches(ctx, state), "Fireball should not have a mana threshold")
    _G.EaxRotations.me.get_mana_percentage = orig_mana
    _G.EaxRotations.debuff_remains = orig_debuff
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
