-- test_warrior_protection_dsl_priority.lua — Warrior Protection DSL priority order + condition equivalence.
-- WHAT:  regression gate verifying the DSL in-place substitution preserves the priority
--        order and that DSL-compiled match functions are behaviorally equivalent to the
--        original imperative functions for the converted strategies.
-- WHEN:  runs as part of run_rotation_tests.lua.
-- WHY:   22nd DSL adopter (first warrior tank) — must prove generality across rage-based
--        tank defensives, buff upkeep, and CC-break utility.
-- SAFETY: mock NS; no real game API calls.

local _pass, _fail = 0, 0
local function assert_true(v, label)
    if v then _pass = _pass + 1 else _fail = _fail + 1; print("  FAIL: " .. label) end
end
local function assert_false(v, label)
    if not v then _pass = _pass + 1 else _fail = _fail + 1; print("  FAIL: " .. label .. " (expected false)") end
end
local function assert_eq(a, b, label)
    if a == b then _pass = _pass + 1 else _fail = _fail + 1; print("  FAIL: " .. label .. " (got " .. tostring(a) .. " expected " .. tostring(b) .. ")") end
end

-- ============================================================================
-- Shared test helpers
-- ============================================================================
local runner = dofile("EaxRotations/tests/test_runner_lib.lua")

-- ============================================================================
-- Mock NS for protection_sylvanas.lua
-- ============================================================================
local mock_hp = 100
local mock_in_combat = false
local mock_is_group = false
local mock_has_battle_shout = false
local mock_has_commanding_shout = false
local mock_has_last_stand = false
local mock_has_shield_wall = false
local mock_berserker_rage_ready = false
local mock_commanding_ready = false
local mock_healthstone_ready = 0
local mock_broken_api_throttled = false
local mock_berserker_rage_buff = false
local mock_time = 0

_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return mock_hp end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return mock_time end
NS.spell_ready = function(spell, target, opts) return true end
NS.try_cast = function() return true end
NS.action_matches = function() return true end
NS.action_execute = function() return true end
NS.buff_up = function(unit, buff_list)
    -- Simplified: only check known buff tables by first id
    if not buff_list then return false end
    local id = buff_list[1]
    if id == 2048 or id == 25289 then return mock_has_battle_shout end
    if id == 469 then return mock_has_commanding_shout end
    if id == 12975 then return mock_has_last_stand end
    if id == 871 then return mock_has_shield_wall end
    return false
end
NS.buff_remains = function() return 0 end
NS.debuff_remains = function() return 0 end
NS.debuff_up = function() return false end
NS.get_debuff_stacks = function() return 0 end
NS.aoe_target_meets = function() return false end
NS.aoe_self_meets = function() return false end
NS.use_item_by_id = function(id, target) return true end
NS.broken_api_throttled = function(spell, throttle)
    return mock_broken_api_throttled
end
NS.should_use_long_cd = function(context, cd) return true end
NS.unit_health_pct = function() return mock_hp end
NS.rotation_registry = { register = function() end }
NS.WarriorSpells = {}
NS.WarriorConstants = {
    STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    SUNDER_DEBUFF = { 25225 },
    DEMO_SHOUT_DEBUFF = { 25203 },
    THUNDER_CLAP_DEBUFF = { 25264 },
    BATTLE_SHOUT_IDS = { 2048, 25289 },
    COMMANDING_SHOUT_BUFF = { 469 },
    DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true },
}
NS.OffensiveDispelDB = { find_best_dispel_target = function() return nil, nil, nil end }

-- Mock shared modules
package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    safe_state = function(raw, schema)
        local proxy = {}
        setmetatable(proxy, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
        for k, v in pairs(raw) do proxy[k] = v end
        return proxy
    end,
    define_action_for_class = function(SPELLS)
        return function(spell_field, rank_ids, label)
            if type(rank_ids) == "table" then return rank_ids[1] or spell_field end
            return rank_ids or spell_field
        end
    end,
    setting = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    setting_bool = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
    setting_number = function(ctx, key, default)
        if ctx and ctx.settings and ctx.settings[key] ~= nil then return ctx.settings[key] end
        return default
    end,
}
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = { 28100 },
    HEALTH_POTION_IDS = { 22851 },
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["shared/offensive_dispel_sylvanas"] = {
    find_best_dispel_target = function() return nil, nil, nil end,
}

-- Save original debuff function for restoration after CC test
local _orig_debuff_up = NS.debuff_up

-- ============================================================================
-- Load the protection spec
-- ============================================================================
local prot = dofile("EaxRotations/classes/warrior/protection_sylvanas.lua")
local strategies = prot.strategies

-- ============================================================================
-- Test 1: Strategy count
-- ============================================================================
assert_true(#strategies > 0, "strategies table should not be empty")

-- ============================================================================
-- Test 2: DSL strategies present and have compiled matches/execute
-- ============================================================================
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    return nil, nil
end

local dsl_names = { "LastStand", "ShieldWall", "Healthstone", "BattleShout", "CommandingShout", "BerserkerRage" }
for _, name in ipairs(dsl_names) do
    local s, idx = find_strategy(name)
    assert_true(s ~= nil, name .. " strategy exists")
    assert_true(type(s.matches) == "function", name .. " has matches function")
    assert_true(type(s.execute) == "function", name .. " has execute function")
end

-- ============================================================================
-- Test 3: Priority order for DSL strategies
-- ============================================================================
local function index_of(name)
    local _, idx = find_strategy(name)
    return idx
end

local last_idx = index_of("LastStand")
local shield_idx = index_of("ShieldWall")
local hs_idx = index_of("Healthstone")
local bs_idx = index_of("BattleShout")
local cs_idx = index_of("CommandingShout")
local br_idx = index_of("BerserkerRage")

assert_true(hs_idx > 0, "Healthstone has a position")
assert_true(last_idx > hs_idx, "LastStand after Healthstone")
assert_true(shield_idx > last_idx, "ShieldWall after LastStand")
assert_true(bs_idx > shield_idx, "BattleShout after ShieldWall")
assert_true(cs_idx > bs_idx, "CommandingShout after BattleShout")
assert_true(br_idx > cs_idx, "BerserkerRage after CommandingShout")

-- ============================================================================
-- Test 4: DSL condition equivalence
-- ============================================================================
local function make_ctx(overrides)
    local ctx = runner.Mock.DefaultProtectionContext({
        in_combat = mock_in_combat,
        hp = mock_hp,
        is_group = mock_is_group,
        settings = {},
    })
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        hp = mock_hp,
        in_combat = mock_in_combat,
        is_group = mock_is_group,
        has_battle_shout = mock_has_battle_shout,
        has_commanding_shout = mock_has_commanding_shout,
        has_last_stand = mock_has_last_stand,
        has_shield_wall = mock_has_shield_wall,
        berserker_rage_ready = mock_berserker_rage_ready,
        commanding_ready = mock_commanding_ready,
        healthstone_ready = mock_healthstone_ready,
        rage = 10,
        stance = 2,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- LastStand: in combat, low HP, not already active, setting enabled
mock_in_combat = true
mock_hp = 20
mock_has_last_stand = false
assert_true(strategies[last_idx].matches(make_ctx(), make_state()), "LastStand matches at low HP in combat")
mock_hp = 80
assert_false(strategies[last_idx].matches(make_ctx(), make_state()), "LastStand skips at high HP")
mock_hp = 20
mock_has_last_stand = true
assert_false(strategies[last_idx].matches(make_ctx(), make_state()), "LastStand skips when already active")
mock_has_last_stand = false
assert_false(strategies[last_idx].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })), "LastStand skips out of combat")
assert_false(strategies[last_idx].matches(make_ctx({ settings = { use_last_stand = false } }), make_state()), "LastStand skips when disabled")

-- ShieldWall: in combat, low HP, not already active, setting enabled, long CD allowed
mock_hp = 20
mock_has_shield_wall = false
assert_true(strategies[shield_idx].matches(make_ctx(), make_state()), "ShieldWall matches at low HP in combat")
mock_hp = 80
assert_false(strategies[shield_idx].matches(make_ctx(), make_state()), "ShieldWall skips at high HP")
mock_hp = 20
mock_has_shield_wall = true
assert_false(strategies[shield_idx].matches(make_ctx(), make_state()), "ShieldWall skips when already active")
mock_has_shield_wall = false
assert_false(strategies[shield_idx].matches(make_ctx({ settings = { use_shield_wall = false } }), make_state()), "ShieldWall skips when disabled")

-- Healthstone: in combat, low HP, healthstone ready
mock_hp = 20
mock_healthstone_ready = 22104
assert_true(strategies[hs_idx].matches(make_ctx(), make_state()), "Healthstone matches when ready and low HP")
mock_healthstone_ready = 0
assert_false(strategies[hs_idx].matches(make_ctx(), make_state()), "Healthstone skips when not ready")
mock_healthstone_ready = 22104
mock_hp = 80
assert_false(strategies[hs_idx].matches(make_ctx(), make_state()), "Healthstone skips at high HP")
mock_hp = 20
assert_false(strategies[hs_idx].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })), "Healthstone skips out of combat")

-- BattleShout: not already active, no commanding shout
mock_has_battle_shout = false
mock_has_commanding_shout = false
mock_broken_api_throttled = false
assert_true(strategies[bs_idx].matches(make_ctx(), make_state()), "BattleShout matches when missing")
mock_has_battle_shout = true
assert_false(strategies[bs_idx].matches(make_ctx(), make_state()), "BattleShout skips when already active")
mock_has_battle_shout = false
mock_has_commanding_shout = true
assert_false(strategies[bs_idx].matches(make_ctx(), make_state()), "BattleShout skips when commanding shout active")
mock_has_commanding_shout = false

-- CommandingShout: setting enabled, ready, missing both battle and commanding shout
mock_has_battle_shout = false
mock_has_commanding_shout = false
mock_commanding_ready = true
assert_true(strategies[cs_idx].matches(make_ctx({ settings = { use_commanding_shout = true } }), make_state()), "CommandingShout matches when enabled and ready")
assert_false(strategies[cs_idx].matches(make_ctx(), make_state()), "CommandingShout skips when disabled by default")
mock_commanding_ready = false
assert_false(strategies[cs_idx].matches(make_ctx({ settings = { use_commanding_shout = true } }), make_state()), "CommandingShout skips when not ready")
mock_commanding_ready = true

-- Verify broken_api_throttled path for BattleShout/CommandingShout
mock_broken_api_throttled = true
assert_false(strategies[bs_idx].matches(make_ctx(), make_state()), "BattleShout skips when broken_api_throttled")
assert_false(strategies[cs_idx].matches(make_ctx({ settings = { use_commanding_shout = true } }), make_state()), "CommandingShout skips when broken_api_throttled")
mock_broken_api_throttled = false

-- BerserkerRage: ready and under fear/sap/incapacitate
mock_berserker_rage_ready = true
_G.EaxRotations.debuff_up = function(unit, id)
    -- Simulate fear debuff present
    if id == 5782 then return true end
    return false
end
assert_true(strategies[br_idx].matches(make_ctx(), make_state()), "BerserkerRage matches under fear")
_G.EaxRotations.debuff_up = function() return false end
assert_false(strategies[br_idx].matches(make_ctx(), make_state()), "BerserkerRage skips when no CC")
mock_berserker_rage_ready = false
assert_false(strategies[br_idx].matches(make_ctx(), make_state()), "BerserkerRage skips when not ready")

-- Restore original debuff function
NS.debuff_up = _orig_debuff_up

-- Dynamic threshold for LastStand/ShieldWall based on is_group
mock_hp = 40
mock_in_combat = true
mock_has_last_stand = false
mock_has_shield_wall = false
assert_false(strategies[last_idx].matches(make_ctx({ is_group = false }), make_state({ is_group = false })), "LastStand skips at hp=40 solo (threshold 35)")
assert_true(strategies[last_idx].matches(make_ctx({ is_group = true }), make_state({ is_group = true })), "LastStand matches at hp=40 in group (threshold 50)")
assert_false(strategies[shield_idx].matches(make_ctx({ is_group = false }), make_state({ is_group = false })), "ShieldWall skips at hp=40 solo (threshold 35)")
assert_true(strategies[shield_idx].matches(make_ctx({ is_group = true }), make_state({ is_group = true })), "ShieldWall matches at hp=40 in group (threshold 50)")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_warrior_protection_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_warrior_protection_dsl_priority")
