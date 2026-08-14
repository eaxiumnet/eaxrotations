-- test_retribution_wotlk_dsl_priority.lua — WotLK Retribution Paladin DSL priority order tests.
-- WHAT:  Validates that the 11 retribution_wotlk strategies are compiled correctly by the DSL
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
    PaladinSpells = {
        Judgement       = make_action(53407, "Judgement"),
        CrusaderStrike  = make_action(35395, "CrusaderStrike"),
        DivineStorm     = make_action(53385, "DivineStorm"),
        Consecration    = make_action(48819, "Consecration"),
        Exorcism        = make_action(48801, "Exorcism"),
        HammerOfWrath   = make_action(48807, "HammerOfWrath"),
        AvengingWrath   = make_action(31884, "AvengingWrath"),
        SealOfVengeance = make_action(31801, "SealOfVengeance"),
        SealOfCommand   = make_action(20375, "SealOfCommand"),
        DivinePlea      = make_action(54428, "DivinePlea"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        mana_pct = function() return 80 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
        mana_pct = function() return 80 end,
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
    is_wotlk = function() return true end,
    should_use_long_cd = function(ctx, cd) return true end,
    aoe_self_meets = function(min_count, radius, context, state) return true end,
    AOE_RADIUS = { SELF_8 = 8 },
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_ret = { strategies = strategies, options = options }
        end,
    },
}

-- Stub aoe_hit_volume_sylvanas so the install block at module load doesn't crash
package.loaded["shared/aoe_hit_volume_sylvanas"] = {
    install = function(ns) end,
}

-- Stub shared modules that the spec may try to load
package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_retribution_wotlk_dsl_priority ===")

local ret = dofile("EaxRotations/classes/paladin/retribution_wotlk.lua")
assert_true(type(ret) == "table", "retribution_wotlk should return a table")
assert_true(type(ret.strategies) == "table", "retribution_wotlk should expose strategies")
assert_true(#ret.strategies == 11, "retribution_wotlk should have 11 strategies")

local registered = _G.EaxRotations._registered_ret
assert_true(registered ~= nil, "retribution_wotlk should register under 'retribution'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "SealOfVengeance",
    "SealOfCommand",
    "DivinePlea",
    "AvengingWrath",
    "HammerOfWrath",
    "Judgement",
    "CrusaderStrike",
    "DivineStorm",
    "Exorcism",
    "Consecration",
    "SealSwitch",
}

test("priority order: 11 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(ret.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], ret.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- SealOfVengeance: matches when seal_not_up AND enemy_count < 2
test("SealOfVengeance: matches when seal down and 1 enemy", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return false end  -- seal not up
    local state = ret.build_state(ctx)
    state.enemy_count = 1
    local ok = ret.strategies[1].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "SealOfVengeance should match when seal down and 1 enemy")
end)

test("SealOfVengeance: does not match when seal already up", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- seal up
    local state = ret.build_state(ctx)
    local ok = ret.strategies[1].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealOfVengeance should not match when seal already up")
end)

test("SealOfVengeance: does not match with 2+ enemies", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return false end  -- seal not up
    local state = ret.build_state(ctx)
    state.enemy_count = 3
    local ok = ret.strategies[1].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealOfVengeance should not match with 3 enemies")
end)

-- SealOfCommand: matches when seal_not_up AND enemy_count >= 2
test("SealOfCommand: matches when seal down and 2 enemies", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return false end  -- seal not up
    local state = ret.build_state(ctx)
    state.enemy_count = 2
    local ok = ret.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "SealOfCommand should match when seal down and 2 enemies")
end)

test("SealOfCommand: does not match when seal already up", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- seal up
    local state = ret.build_state(ctx)
    local ok = ret.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealOfCommand should not match when seal already up")
end)

test("SealOfCommand: does not match with 1 enemy", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return false end  -- seal not up
    local state = ret.build_state(ctx)
    state.enemy_count = 1
    local ok = ret.strategies[2].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealOfCommand should not match with 1 enemy")
end)

-- DivinePlea: matches when mana < 40, plea not up, cd ready
test("DivinePlea: matches when mana < 40 and cd ready", function()
    local orig_buff = _G.EaxRotations.buff_up
    local orig_mana = _G.EaxRotations.me.mana_pct
    _G.EaxRotations.me.mana_pct = function() return 30 end
    _G.EaxRotations.buff_up = function(unit, ids) return false end  -- plea not up
    local state = ret.build_state(ctx)
    -- DivinePlea checks mana_pct < 40, divine_plea_up falsy, divine_plea_cd <= 0
    state.divine_plea_cd = 0
    local ok = ret.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.mana_pct = orig_mana
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "DivinePlea should match when mana < 40 and cd ready")
end)

test("DivinePlea: does not match when mana >= 40", function()
    -- Default mana is 80, so this tests the gate
    local state = ret.build_state(ctx)
    state.divine_plea_cd = 0
    assert_false(ret.strategies[3].matches(ctx, state), "DivinePlea should not match when mana >= 40")
end)

test("DivinePlea: does not match when already active", function()
    local orig_buff = _G.EaxRotations.buff_up
    local orig_mana = _G.EaxRotations.me.mana_pct
    _G.EaxRotations.me.mana_pct = function() return 30 end
    _G.EaxRotations.buff_up = function(unit, ids)
        -- ids = DIVINE_PLEA_BUFF = { 54428 }
        if ids[1] == 54428 then return true end
        return false
    end
    local state = ret.build_state(ctx)
    state.divine_plea_cd = 0
    local ok = ret.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.mana_pct = orig_mana
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "DivinePlea should not match when already active")
end)

test("DivinePlea: does not match when on cooldown", function()
    local orig_buff = _G.EaxRotations.buff_up
    local orig_mana = _G.EaxRotations.me.mana_pct
    _G.EaxRotations.me.mana_pct = function() return 30 end
    _G.EaxRotations.buff_up = function(unit, ids) return false end
    local state = ret.build_state(ctx)
    state.divine_plea_cd = 10  -- on cooldown
    local ok = ret.strategies[3].matches(ctx, state)
    _G.EaxRotations.me.mana_pct = orig_mana
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "DivinePlea should not match when on cooldown")
end)

-- AvengingWrath: matches when in_combat, ready, setting on, long_cd allowed
test("AvengingWrath: matches when all conditions met", function()
    local orig_long_cd = _G.EaxRotations.should_use_long_cd
    _G.EaxRotations.should_use_long_cd = function(ctx, cd) return true end
    local state = ret.build_state(ctx)
    state.in_combat = true
    state.avenging_wrath_ready = true
    local ok = ret.strategies[4].matches(ctx, state)
    _G.EaxRotations.should_use_long_cd = orig_long_cd
    assert_true(ok, "AvengingWrath should match when all conditions met")
end)

test("AvengingWrath: does not match when out of combat", function()
    local state = ret.build_state(ctx)
    state.in_combat = false
    state.avenging_wrath_ready = true
    assert_false(ret.strategies[4].matches(ctx, state), "AvengingWrath should not match when out of combat")
end)

test("AvengingWrath: does not match when not ready", function()
    local state = ret.build_state(ctx)
    state.in_combat = true
    state.avenging_wrath_ready = false
    assert_false(ret.strategies[4].matches(ctx, state), "AvengingWrath should not match when not ready")
end)

-- HammerOfWrath: matches when target_hp < 20 and cd ready
test("HammerOfWrath: matches when target_hp < 20 and cd ready", function()
    local state = ret.build_state(ctx)
    state.target_hp = 15
    state.hammer_of_wrath_cd = 0
    assert_true(ret.strategies[5].matches(ctx, state), "HammerOfWrath should match when target_hp < 20 and cd ready")
end)

test("HammerOfWrath: does not match when target_hp >= 20", function()
    local state = ret.build_state(ctx)
    state.target_hp = 50
    state.hammer_of_wrath_cd = 0
    assert_false(ret.strategies[5].matches(ctx, state), "HammerOfWrath should not match when target_hp >= 20")
end)

test("HammerOfWrath: does not match when on cooldown", function()
    local state = ret.build_state(ctx)
    state.target_hp = 15
    state.hammer_of_wrath_cd = 6
    assert_false(ret.strategies[5].matches(ctx, state), "HammerOfWrath should not match when on cooldown")
end)

-- Judgement: matches when cd ready
test("Judgement: matches when cd ready", function()
    local state = ret.build_state(ctx)
    state.judgement_cd = 0
    assert_true(ret.strategies[6].matches(ctx, state), "Judgement should match when cd ready")
end)

test("Judgement: does not match when on cooldown", function()
    local state = ret.build_state(ctx)
    state.judgement_cd = 8
    assert_false(ret.strategies[6].matches(ctx, state), "Judgement should not match when on cooldown")
end)

-- CrusaderStrike: matches when cd ready
test("CrusaderStrike: matches when cd ready", function()
    local state = ret.build_state(ctx)
    state.crusader_strike_cd = 0
    assert_true(ret.strategies[7].matches(ctx, state), "CrusaderStrike should match when cd ready")
end)

test("CrusaderStrike: does not match when on cooldown", function()
    local state = ret.build_state(ctx)
    state.crusader_strike_cd = 4
    assert_false(ret.strategies[7].matches(ctx, state), "CrusaderStrike should not match when on cooldown")
end)

-- DivineStorm: matches when cd ready
test("DivineStorm: matches when cd ready", function()
    local state = ret.build_state(ctx)
    state.divine_storm_cd = 0
    assert_true(ret.strategies[8].matches(ctx, state), "DivineStorm should match when cd ready")
end)

test("DivineStorm: does not match when on cooldown", function()
    local state = ret.build_state(ctx)
    state.divine_storm_cd = 10
    assert_false(ret.strategies[8].matches(ctx, state), "DivineStorm should not match when on cooldown")
end)

-- Exorcism: matches when art_of_war_proc and cd ready
test("Exorcism: matches when proc active and cd ready", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- art_of_war proc up
    local state = ret.build_state(ctx)
    state.exorcism_cd = 0
    local ok = ret.strategies[9].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "Exorcism should match when proc active and cd ready")
end)

test("Exorcism: does not match when no proc", function()
    local state = ret.build_state(ctx)
    state.exorcism_cd = 0
    assert_false(ret.strategies[9].matches(ctx, state), "Exorcism should not match when no proc")
end)

test("Exorcism: does not match when on cooldown", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = function(unit, ids) return true end  -- art_of_war proc up
    local state = ret.build_state(ctx)
    state.exorcism_cd = 15
    local ok = ret.strategies[9].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "Exorcism should not match when on cooldown")
end)

-- Consecration: matches when mana >= 30, cd ready, aoe_self_meets
test("Consecration: matches when all conditions met", function()
    local state = ret.build_state(ctx)
    state.mana_pct = 50  -- default 80, but set explicitly
    state.consecration_cd = 0
    assert_true(ret.strategies[10].matches(ctx, state), "Consecration should match when all conditions met")
end)

test("Consecration: does not match when mana < 30", function()
    local orig_mana = _G.EaxRotations.me.mana_pct
    _G.EaxRotations.me.mana_pct = function() return 20 end
    local state = ret.build_state(ctx)
    state.consecration_cd = 0
    local ok = ret.strategies[10].matches(ctx, state)
    _G.EaxRotations.me.mana_pct = orig_mana
    assert_false(ok, "Consecration should not match when mana < 30")
end)

test("Consecration: does not match when on cooldown", function()
    local state = ret.build_state(ctx)
    state.mana_pct = 50
    state.consecration_cd = 8
    assert_false(ret.strategies[10].matches(ctx, state), "Consecration should not match when on cooldown")
end)

test("Consecration: does not match when aoe_self_meets returns false", function()
    local orig_aoe = _G.EaxRotations.aoe_self_meets
    _G.EaxRotations.aoe_self_meets = function() return false end
    local state = ret.build_state(ctx)
    state.mana_pct = 50
    state.consecration_cd = 0
    local ok = ret.strategies[10].matches(ctx, state)
    _G.EaxRotations.aoe_self_meets = orig_aoe
    assert_false(ok, "Consecration should not match when aoe_self_meets is false")
end)

-- SealSwitch (11): seal ST/AoE switching. SoV up + 2+ enemies cancels SoV (so
-- SealOfCommand applies on the next GCD); SoC up + 1 enemy cancels SoC (so
-- SealOfVengeance re-applies). The anti-loop stamp is module-local and shared
-- across tests, so the throttle test runs immediately after the first match.
local seal_switch_clock = 0
local orig_time_now = _G.EaxRotations.time_now
_G.EaxRotations.time_now = function() return seal_switch_clock end

local function buff_only_for(ids_when_up)
    local up = {}
    for _, id in ipairs(ids_when_up) do up[id] = true end
    return function(unit, ids)
        for _, id in ipairs(ids or {}) do
            if up[id] then return true end
        end
        return false
    end
end

test("SealSwitch: matches when SoV up and 2+ enemies (adds arrived)", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = buff_only_for({ 31801 })
    seal_switch_clock = 0
    local state = ret.build_state(ctx)
    state.enemy_count = 3
    local ok = ret.strategies[11].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "SealSwitch should match when SoV up and 2+ enemies")
end)

test("SealSwitch: 3s throttle blocks immediate re-match", function()
    -- clock still 0; the module stamp was set by the previous match
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = buff_only_for({ 31801 })
    local state = ret.build_state(ctx)
    state.enemy_count = 3
    local ok = ret.strategies[11].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealSwitch should throttle re-match within 3s")
end)

test("SealSwitch: matches again after the 3s window", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = buff_only_for({ 31801 })
    seal_switch_clock = 10
    local state = ret.build_state(ctx)
    state.enemy_count = 3
    local ok = ret.strategies[11].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_true(ok, "SealSwitch should match after the throttle window")
end)

test("SealSwitch: does not match when SoC up with 2+ enemies", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = buff_only_for({ 27170, 20920, 20919, 20918, 20915, 20375 })
    seal_switch_clock = 20
    local state = ret.build_state(ctx)
    state.enemy_count = 3
    local ok = ret.strategies[11].matches(ctx, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealSwitch should not match when SoC up with 2+ enemies")
end)

test("SealSwitch: does not match when the setting is off", function()
    local orig_buff = _G.EaxRotations.buff_up
    _G.EaxRotations.buff_up = buff_only_for({ 31801 })
    seal_switch_clock = 30
    local ctx_off = { in_combat = true, target = {}, settings = { ret_seal_switch = false } }
    local state = ret.build_state(ctx_off)
    state.enemy_count = 3
    local ok = ret.strategies[11].matches(ctx_off, state)
    _G.EaxRotations.buff_up = orig_buff
    assert_false(ok, "SealSwitch should not match when ret_seal_switch is false")
end)

_G.EaxRotations.time_now = orig_time_now

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
