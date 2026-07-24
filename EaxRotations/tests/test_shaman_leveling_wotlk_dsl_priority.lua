-- test_shaman_leveling_wotlk_dsl_priority.lua — WotLK Shaman leveling DSL priority tests.
-- WHAT:  Validates that the 12 shaman leveling_wotlk strategies are compiled by the DSL
--        and that their match gates fire in the expected priority order.
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

-- core.time stub so time_now() throttles resolve deterministically.
_G.core = _G.core or {}
_G.core.time = function() return 100000 end

package.loaded["shared/leveling_helpers_sylvanas"] = {
    should_interrupt = function(target) return false end,
}

_G.EaxRotations = {
    ShamanSpells = {
        LightningBolt = make_action(403, "LightningBolt"),
        EarthShock = make_action(8042, "EarthShock"),
        FlameShock = make_action(8050, "FlameShock"),
        LavaBurst = make_action(51505, "LavaBurst"),
        Stormstrike = make_action(17364, "Stormstrike"),
        HealingWave = make_action(331, "HealingWave"),
        WindShear = make_action(57994, "WindShear"),
        LightningShield = make_action(324, "LightningShield"),
        FlametongueWeapon = make_action(8024, "FlametongueWeapon"),
        SearingTotem = make_action(3599, "SearingTotem"),
        ChainLightning = make_action(421, "ChainLightning"),
        MagmaTotem = make_action(8190, "MagmaTotem"),
    },
    GetPlayer = function() return {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
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
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_leveling = { name = name, strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_shaman_leveling_wotlk_dsl_priority ===")

local lv = dofile("EaxRotations/classes/shaman/leveling_wotlk.lua")
assert_true(type(lv) == "table", "leveling_wotlk should return a table")
assert_true(type(lv.strategies) == "table", "leveling_wotlk should expose strategies")
assert_true(#lv.strategies == 12, "leveling_wotlk should have 12 strategies")

local registered = _G.EaxRotations._registered_leveling
assert_true(registered ~= nil and registered.name == "leveling", "leveling_wotlk should register under 'leveling'")

-- ============================================================================
-- Priority order test
-- ============================================================================
local expected_order = {
    "WindShear",
    "HealingWave",
    "LightningShield",
    "FlametongueWeapon",
    "SearingTotem",
    "MagmaTotem",
    "ChainLightning",
    "FlameShock",
    "LavaBurst",
    "Stormstrike",
    "EarthShock",
    "LightningBolt",
}

test("priority order: 12 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(lv.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], lv.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- WindShear (1): in_combat and target_casting
test("WindShear: matches when target casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = true
    assert_true(lv.strategies[1].matches(ctx, state), "WindShear should match when target casting")
end)

test("WindShear: does not match when target not casting", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.target_casting = false
    assert_false(lv.strategies[1].matches(ctx, state), "WindShear should not match when not casting")
end)

-- HealingWave (2): in_combat and hp < 50 and mana >= 25
test("HealingWave: matches when hurt", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 40
    state.mana_pct = 25
    assert_true(lv.strategies[2].matches(ctx, state), "HealingWave should match when hurt")
end)

test("HealingWave: does not match at full HP", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.hp = 100
    state.mana_pct = 100
    assert_false(lv.strategies[2].matches(ctx, state), "HealingWave should not match at full HP")
end)

-- LightningShield (3): not lightning_shield_up and mana >= 5
test("LightningShield: matches when buff absent", function()
    local state = lv.build_state(ctx)
    state.lightning_shield_up = false
    state.mana_pct = 5
    assert_true(lv.strategies[3].matches(ctx, state), "LightningShield should match when absent")
end)

test("LightningShield: does not match when buff present", function()
    local state = lv.build_state(ctx)
    state.lightning_shield_up = true
    state.mana_pct = 100
    assert_false(lv.strategies[3].matches(ctx, state), "LightningShield should not match when present")
end)

-- FlametongueWeapon (4): OOC and throttle elapsed and mana >= 5
test("FlametongueWeapon: matches OOC on fresh throttle", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.mana_pct = 5
    assert_true(lv.strategies[4].matches(ctx, state), "Flametongue should match OOC fresh throttle")
end)

test("FlametongueWeapon: does not match in combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 100
    assert_false(lv.strategies[4].matches(ctx, state), "Flametongue should not match in combat")
end)

-- SearingTotem (5): in_combat and enemy_count >= 1 and throttle and mana >= 10
test("SearingTotem: matches in combat fresh throttle", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 1
    state.mana_pct = 10
    assert_true(lv.strategies[5].matches(ctx, state), "SearingTotem should match in combat")
end)

-- MagmaTotem (6): in_combat and enemy_count >= 3 and throttle and mana >= 20
test("MagmaTotem: matches with 3+ enemies", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 3
    state.mana_pct = 20
    assert_true(lv.strategies[6].matches(ctx, state), "MagmaTotem should match with 3+ enemies")
end)

test("MagmaTotem: does not match with 2 enemies", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 2
    state.mana_pct = 100
    assert_false(lv.strategies[6].matches(ctx, state), "MagmaTotem should not match with 2 enemies")
end)

-- ChainLightning (7): in_combat and enemy_count >= 2 and mana >= 20
test("ChainLightning: matches with 2+ enemies", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.enemy_count = 2
    state.mana_pct = 20
    assert_true(lv.strategies[7].matches(ctx, state), "ChainLightning should match with 2+ enemies")
end)

-- FlameShock (8): in_combat and flame_shock_remains < 3 and mana >= 15
test("FlameShock: matches when dot expiring", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.flame_shock_remains = 0
    state.mana_pct = 15
    assert_true(lv.strategies[8].matches(ctx, state), "FlameShock should match when expiring")
end)

-- LavaBurst (9): in_combat and flame_shock_remains > 0 and mana >= 20
test("LavaBurst: matches when flame shock up", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.flame_shock_remains = 5
    state.mana_pct = 20
    assert_true(lv.strategies[9].matches(ctx, state), "LavaBurst should match when flame shock up")
end)

test("LavaBurst: does not match without flame shock", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.flame_shock_remains = 0
    state.mana_pct = 100
    assert_false(lv.strategies[9].matches(ctx, state), "LavaBurst should not match without flame shock")
end)

-- Stormstrike (10): in_combat and mana >= 10
test("Stormstrike: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 10
    assert_true(lv.strategies[10].matches(ctx, state), "Stormstrike should match with mana >= 10")
end)

-- LightningBolt (12): in_combat and mana >= 15
test("LightningBolt: matches with mana", function()
    local state = lv.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 15
    assert_true(lv.strategies[12].matches(ctx, state), "LightningBolt should match with mana >= 15")
end)

test("LightningBolt: does not match out of combat", function()
    local state = lv.build_state(ctx)
    state.in_combat = false
    state.mana_pct = 100
    assert_false(lv.strategies[12].matches(ctx, state), "LightningBolt should not match OOC")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
