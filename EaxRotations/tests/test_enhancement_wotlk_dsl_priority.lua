-- test_enhancement_wotlk_dsl_priority.lua — WotLK Enhancement shaman DSL priority tests.
-- WHAT:  Validates that the 4 enhancement_wotlk strategies are compiled correctly by the
--        DSL and that their match gates fire in the expected priority order.
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
    ShamanSpells = {
        Stormstrike = make_action(17364, "Stormstrike"),
        LavaLash = make_action(60103, "LavaLash"),
        FeralSpirit = make_action(51533, "FeralSpirit"),
        ShamanisticRage = make_action(30823, "ShamanisticRage"),
    },
    spell_action = make_action,
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
    buff_stacks = function(unit, ids) return 0 end,
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
    rotation_registry = {
        register = function(self, name, strategies, options)
            _G.EaxRotations._registered_enhancement = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_enhancement_wotlk_dsl_priority ===")

local enh = dofile("EaxRotations/classes/shaman/enhancement_wotlk.lua")
assert_true(type(enh) == "table", "enhancement_wotlk should return a table")
assert_true(type(enh.strategies) == "table", "enhancement_wotlk should expose strategies")
    assert_true(#enh.strategies == 14, "enhancement_wotlk should have 14 strategies")

local registered = _G.EaxRotations._registered_enhancement
assert_true(registered ~= nil, "enhancement_wotlk should register under 'enhancement'")

-- ============================================================================
-- Priority order test
-- ============================================================================
-- The 11 pinned wowsims APL lanes keep their exact order; the W3.3 lanes
-- (ShamanisticRage + WindfuryWeapon/FlametongueWeapon imbue upkeep) append
-- at the end (pin-safe).
local expected_order = {
    "FeralSpirit", "Bloodlust", "LightningBolt", "Stormstrike", "FlameShock",
    "EarthShock", "CallOfTheElements", "MagmaTotem", "FireNova", "LightningShield", "LavaLash",
    "ShamanisticRage", "WindfuryWeapon", "FlametongueWeapon",
}

test("priority order: 4 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(enh.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], enh.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================

local ctx = { in_combat = true, target = {}, settings = {} }

-- FeralSpirit: matches when in_combat and ready
test("FeralSpirit: matches when all conditions met", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.feral_spirit_ready = true
    assert_true(enh.strategies[1].matches(ctx, state), "FeralSpirit should match when all conditions met")
end)

test("FeralSpirit: does not match when out of combat", function()
    local state = enh.build_state(ctx)
    state.in_combat = false
    state.feral_spirit_ready = true
    assert_false(enh.strategies[1].matches(ctx, state), "FeralSpirit should not match when out of combat")
end)

test("FeralSpirit: does not match when not ready", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.feral_spirit_ready = false
    assert_false(enh.strategies[1].matches(ctx, state), "FeralSpirit should not match when not ready")
end)

-- Bloodlust: matches when in combat and ready
test("Bloodlust: matches when all conditions met", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.bloodlust_ready = true
    assert_true(enh.strategies[2].matches(ctx, state), "Bloodlust should match when all conditions met")
end)

test("Bloodlust: does not match when out of combat", function()
    local state = enh.build_state(ctx)
    state.in_combat = false
    state.bloodlust_ready = true
    assert_false(enh.strategies[2].matches(ctx, state), "Bloodlust should not match when out of combat")
end)

test("Bloodlust: does not match when not ready", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.bloodlust_ready = false
    assert_false(enh.strategies[2].matches(ctx, state), "Bloodlust should not match when not ready")
end)

-- Stormstrike: always matches
test("Stormstrike: always matches", function()
    local state = enh.build_state(ctx)
    assert_true(enh.strategies[4].matches(ctx, state), "Stormstrike should always match")
end)

-- LavaLash: always matches
test("LavaLash: always matches", function()
    local state = enh.build_state(ctx)
    assert_true(enh.strategies[11].matches(ctx, state), "LavaLash should always match")
end)

-- ShamanisticRage (W3.3): in combat + mana < 40 + ready
test("ShamanisticRage: matches at low mana in combat", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 30
    state.shamanistic_rage_ready = true
    assert_true(enh.strategies[12].matches(ctx, state), "ShamanisticRage should match at low mana")
end)

test("ShamanisticRage: does not match at full mana", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 100
    state.shamanistic_rage_ready = true
    assert_false(enh.strategies[12].matches(ctx, state), "ShamanisticRage should not match at full mana")
end)

test("ShamanisticRage: does not match when not ready", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.mana_pct = 30
    state.shamanistic_rage_ready = false
    assert_false(enh.strategies[12].matches(ctx, state), "ShamanisticRage should not match when not ready")
end)

-- Weapon-imbue upkeep (W3.3): OOC + imbue window stale (fresh window is 29.8 min)
test("WindfuryWeapon: matches OOC when imbue stale", function()
    local state = enh.build_state(ctx)
    state.in_combat = false
    state.has_windfury = false
    state.mana_pct = 100
    assert_true(enh.strategies[13].matches(ctx, state), "WindfuryWeapon should match OOC when stale")
end)

test("WindfuryWeapon: does not match in combat", function()
    local state = enh.build_state(ctx)
    state.in_combat = true
    state.has_windfury = false
    assert_false(enh.strategies[13].matches(ctx, state), "WindfuryWeapon should not match in combat")
end)

test("FlametongueWeapon: matches OOC when imbue stale", function()
    local state = enh.build_state(ctx)
    state.in_combat = false
    state.has_flametongue = false
    state.mana_pct = 100
    assert_true(enh.strategies[14].matches(ctx, state), "FlametongueWeapon should match OOC when stale")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
