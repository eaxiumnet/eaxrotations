-- test_restoration_wotlk_dsl_priority.lua — WotLK Restoration shaman DSL priority tests.
-- WHAT:  Validates that the 4 restoration_wotlk strategies are compiled correctly by
--        the DSL and that their match gates fire in the expected priority order.
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
        Riptide = make_action(61295, "Riptide"),
        ChainHeal = make_action(25423, "ChainHeal"),
        HealingWave = make_action(25396, "HealingWave"),
        EarthShield = make_action(32594, "EarthShield"),
    },
    spell_action = make_action,
    GetPlayer = function() return {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 100 end,
    } end,
    me = {
        get_health_percentage = function() return 80 end,
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
            _G.EaxRotations._registered_restoration = { strategies = strategies, options = options }
        end,
    },
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }
package.loaded["shared/strategy_dsl_sylvanas"] = package.loaded["shared/strategy_dsl_sylvanas"]
    or require("shared/strategy_dsl_sylvanas")

print("=== test_restoration_wotlk_dsl_priority ===")

local resto = dofile("EaxRotations/classes/shaman/restoration_wotlk.lua")
assert_true(type(resto) == "table", "restoration_wotlk should return a table")
assert_true(type(resto.strategies) == "table", "restoration_wotlk should expose strategies")
    assert_true(#resto.strategies == 12, "restoration_wotlk should have 12 strategies")

-- Name-resolved lane lookup (2026-09-12): Cleanse Spirit + Earthliving
-- Weapon were inserted and positional indices drift on insertion.
local function lane(name)
    for i = 1, #resto.strategies do
        if resto.strategies[i].name == name then return resto.strategies[i] end
    end
    error("lane not found: " .. name)
end

local registered = _G.EaxRotations._registered_restoration
assert_true(registered ~= nil, "restoration_wotlk should register under 'restoration'")

-- ============================================================================
-- Priority order test
-- ============================================================================
-- Healer wave (2026-09-09): NS+HW emergency pair leads the guide priority;
-- TidalWavesHealingWave consumes 2 TW stacks before the slow HW base lane.
local expected_order = {
    "NaturesSwiftness", "NaturesSwiftnessHealingWave", "CleanseSpirit",
    "ManaTideTotem", "EarthShield", "Riptide", "ChainHeal", "TidalWavesHealingWave",
    "HealingWave", "LesserHealingWave", "WaterShield", "EarthlivingWeapon",
}

test("priority order: 12 strategies match expected order", function()
    for i = 1, #expected_order do
        assert_true(resto.strategies[i].name == expected_order[i],
            string.format("Strategy %d should be %s, got %s", i, expected_order[i], resto.strategies[i].name))
    end
end)

-- ============================================================================
-- Match gate tests
-- ============================================================================
local ctx = { in_combat = true, target = {}, settings = {} }

-- EarthShield (1): matches when buff down; charge-aware refresh when up with
-- <= 1 charge (Pattern 12 via NS.buff_points)
test("EarthShield: matches when buff down", function()
    local state = resto.build_state(ctx)
    state.earth_shield_up = false
    assert_true(lane("EarthShield").matches(ctx, state), "EarthShield should match when buff down")
end)

test("EarthShield: does not match when buff up with full charges", function()
    local state = resto.build_state(ctx)
    state.earth_shield_up = true
    state.earth_shield_charges = 5
    assert_false(lane("EarthShield").matches(ctx, state), "EarthShield should not match when buff up with charges")
end)

test("EarthShield: matches when buff up with 1 charge", function()
    local state = resto.build_state(ctx)
    state.earth_shield_up = true
    state.earth_shield_charges = 1
    assert_true(lane("EarthShield").matches(ctx, state), "EarthShield should refresh at 1 charge")
end)

-- Riptide (2): riptide_remains < 3
test("Riptide: matches when buff expiring", function()
    local state = resto.build_state(ctx)
    state.riptide_remains = 1
    assert_true(lane("Riptide").matches(ctx, state), "Riptide should match when remains < 3")
end)

test("Riptide: does not match when buff fresh", function()
    local state = resto.build_state(ctx)
    state.riptide_remains = 10
    assert_false(lane("Riptide").matches(ctx, state), "Riptide should not match when remains >= 3")
end)

-- ChainHeal (3): party_injured_count >= 2 and mana_pct >= 25 (engine field)
test("ChainHeal: matches with 2+ injured and mana >= 25", function()
    local state = resto.build_state(ctx)
    state.party_injured_count = 2
    state.lowest_hp = 80
    state.mana_pct = 25
    assert_true(lane("ChainHeal").matches(ctx, state), "ChainHeal should match with 2+ injured allies and mana >= 25")
end)

test("ChainHeal: does not match single target", function()
    local state = resto.build_state(ctx)
    state.party_injured_count = 1
    state.lowest_hp = 80
    state.mana_pct = 100
    assert_false(lane("ChainHeal").matches(ctx, state), "ChainHeal should not match one injured ally")
end)

test("ChainHeal: does not match when mana < 25", function()
    local state = resto.build_state(ctx)
    state.party_injured_count = 3
    state.lowest_hp = 80
    state.mana_pct = 20
    assert_false(lane("ChainHeal").matches(ctx, state), "ChainHeal should not match when mana < 25")
end)

-- HealingWave (4): target_hp < 70 and mana_pct >= 20
test("HealingWave: matches when target < 70 and mana >= 20", function()
    local state = resto.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 20
    assert_true(lane("HealingWave").matches(ctx, state), "HealingWave should match with target < 70 and mana >= 20")
end)

test("HealingWave: does not match when target >= 70", function()
    local state = resto.build_state(ctx)
    state.target_hp = 75
    state.mana_pct = 100
    assert_false(lane("HealingWave").matches(ctx, state), "HealingWave should not match when target >= 70")
end)

test("HealingWave: does not match when mana < 20", function()
    local state = resto.build_state(ctx)
    state.target_hp = 60
    state.mana_pct = 10
    assert_false(lane("HealingWave").matches(ctx, state), "HealingWave should not match when mana < 20")
end)

-- WaterShield (W3.3, appended): in combat + shield down + mana < 50 + ready
test("WaterShield: matches at low mana with shield down", function()
    local state = resto.build_state(ctx)
    state.in_combat = true
    state.water_shield_up = false
    state.mana_pct = 30
    state.water_shield_ready = true
    assert_true(lane("WaterShield").matches(ctx, state), "WaterShield should match at low mana")
end)

test("WaterShield: does not match when shield up", function()
    local state = resto.build_state(ctx)
    state.in_combat = true
    state.water_shield_up = true
    state.mana_pct = 30
    state.water_shield_ready = true
    assert_false(lane("WaterShield").matches(ctx, state), "WaterShield should not match when shield up")
end)

test("WaterShield: does not match at full mana", function()
    local state = resto.build_state(ctx)
    state.in_combat = true
    state.water_shield_up = false
    state.mana_pct = 90
    state.water_shield_ready = true
    assert_false(lane("WaterShield").matches(ctx, state), "WaterShield should not match at full mana")
end)

-- ============================================================================
-- Deficit-fit pins (2026-09-16): live NS lookup over the file-local WotLK
-- HW/LHW ladders, level-80 divisor threaded, fail-closed to the legacy
-- max-rank casts (HW 49273 / LHW 49276). Conditions above are untouched --
-- the fit changes WHICH rank casts, never whether the lane fires. The mock's
-- spell_action lets the real heal-value module build the ladders.
-- ============================================================================
local FIT_HW = { id = 25396, name = "HW_FIT" }
local FIT_LHW = { id = 25420, name = "LHW_FIT" }
local hook_log = {}
local FIT_HOOK = function(ranks, target, context, label, opts)
    hook_log[#hook_log + 1] = { ranks = ranks, target = target, label = label, opts = opts }
    if label == "[RESTO] LesserHealingWave" then return FIT_LHW, "LesserHealingWave R8" end
    if label == "[RESTO] HealingWave" or label == "[RESTO] TidalWavesHealingWave" then return FIT_HW, "HealingWave R10" end
    return nil
end
_G.EaxRotations.cast_best_heal_rank = FIT_HOOK
local cast_log = {}
_G.EaxRotations.try_cast = function(spell, target, reason, opts)
    cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
    return true
end

local function fit_ctx(hp)
    local unit = { get_health_percentage = function() return hp end }
    local c = { in_combat = true, target = {}, settings = {}, lowest = { unit = unit, hp = hp } }
    return c, unit
end

test("HealingWave fit: hook rank replaces max, level-80 divisor threaded", function()
    local c, unit = fit_ctx(60)
    local state = resto.build_state(c)
    assert_true(lane("HealingWave").matches(c, state), "HealingWave should match at hp 60")
    hook_log, cast_log = {}, {}
    assert_true(lane("HealingWave").execute(c, state), "HealingWave should execute")
    assert_true(cast_log[1] ~= nil and cast_log[1].spell == FIT_HW,
        "deficit-fit rank replaces the 49273 max")
    assert_true(cast_log[1].target == unit, "fit cast targets the lowest friendly")
    assert_true(cast_log[1].reason == "HealingWave R10", "fit label threads through")
    assert_true(type(hook_log[1].ranks) == "table" and hook_log[1].ranks[1].id == 49273,
        "fit receives the built WotLK HW ladder headed by 49273")
    assert_true(hook_log[1].opts and hook_log[1].opts.player_level == 80, "level-80 wrath divisor threaded")
end)

test("HealingWave fallback: hook miss casts the legacy 49273 max", function()
    local c = fit_ctx(60)
    local state = resto.build_state(c)
    _G.EaxRotations.cast_best_heal_rank = function() return nil end
    hook_log, cast_log = {}, {}
    assert_true(lane("HealingWave").execute(c, state), "HealingWave should execute on fit miss")
    assert_true(cast_log[1] ~= nil and cast_log[1].spell.id == 49273,
        "fit miss falls back to the legacy max-rank action (49273)")
    _G.EaxRotations.cast_best_heal_rank = FIT_HOOK
end)

test("HealingWave fallback: absent hook casts the legacy max (guard load-bearing)", function()
    local c = fit_ctx(60)
    local state = resto.build_state(c)
    _G.EaxRotations.cast_best_heal_rank = nil
    hook_log, cast_log = {}, {}
    assert_true(lane("HealingWave").execute(c, state), "HealingWave should execute without a hook")
    assert_true(cast_log[1] ~= nil and cast_log[1].spell.id == 49273,
        "absent hook falls back to the legacy max-rank action (49273)")
    _G.EaxRotations.cast_best_heal_rank = FIT_HOOK
end)

test("LesserHealingWave fit: hook rank replaces max", function()
    local c, unit = fit_ctx(80)
    local state = resto.build_state(c)
    hook_log, cast_log = {}, {}
    assert_true(lane("LesserHealingWave").execute(c, state), "LesserHealingWave should execute")
    assert_true(cast_log[1] ~= nil and cast_log[1].spell == FIT_LHW,
        "deficit-fit rank replaces the 49276 max")
    assert_true(cast_log[1].target == unit, "fit cast targets the lowest friendly")
    assert_true(hook_log[1].opts and hook_log[1].opts.player_level == 80, "level-80 wrath divisor threaded")
end)

test("LesserHealingWave fallback: hook miss casts the legacy 49276 max", function()
    local c = fit_ctx(80)
    local state = resto.build_state(c)
    _G.EaxRotations.cast_best_heal_rank = function() return nil end
    hook_log, cast_log = {}, {}
    assert_true(lane("LesserHealingWave").execute(c, state), "LesserHealingWave should execute on fit miss")
    assert_true(cast_log[1] ~= nil and cast_log[1].spell.id == 49276,
        "fit miss falls back to the legacy max-rank action (49276)")
    _G.EaxRotations.cast_best_heal_rank = FIT_HOOK
end)

test("TidalWavesHealingWave draws from the same HW ladder", function()
    local c = fit_ctx(60)
    local state = resto.build_state(c)
    state.tidal_waves_stacks = 2
    hook_log, cast_log = {}, {}
    assert_true(lane("TidalWavesHealingWave").execute(c, state), "TW lane should execute")
    assert_true(cast_log[1] ~= nil and cast_log[1].spell == FIT_HW, "TW lane casts the fitted HW rank")
    assert_true(hook_log[1].label == "[RESTO] TidalWavesHealingWave", "TW lane keeps its own label")
    assert_true(type(hook_log[1].ranks) == "table" and hook_log[1].ranks[1].id == 49273,
        "TW lane draws the built WotLK HW ladder")
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
