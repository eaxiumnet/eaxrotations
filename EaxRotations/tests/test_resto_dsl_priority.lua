-- test_resto_dsl_priority.lua â Restoration Druid DSL priority + equivalence test.
-- WHAT:  Verifies that the 6 DSL-converted strategies preserve priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 27th strategy DSL adopter (restoration druid healer).
-- SAFETY: Pure unit tests with mocked API context; mocks are restored after loading.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end
local function assert_false(cond, msg)
    if not cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end

-- ============================================================================
-- Mock NS
-- ============================================================================
local NS = {}
_G.EaxRotations = NS

NS.DruidSpells = {}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.has_player_buff = function() return false end
NS.has_player_debuff = function() return false end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return true end
NS.unit_health_pct = function() return 100 end
NS.mana_pct = function() return 100 end
NS.power_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_overheal = function() return false end
NS.same_unit = function(a, b) return a == b end
NS.is_in_party = function() return false end
NS.is_in_raid = function() return false end
-- Rebirth requires a dead ally (find_dead_party_ally, 2026-08-14): provide
-- one for the positive cases — the negative cases gate on in_combat/party.
local dead_ally_unit = { is_player = function() return true end, get_health = function() return 0 end }
NS.find_dead_party_ally = function() return dead_ally_unit end
NS.has_dispel_type_debuff = function() return false end
NS.healing_get_tank = function(entries, count)
    for i = 1, count do
        if entries[i].is_tank then return entries[i] end
    end
    return nil
end
NS.healing_get_lowest_hp = function(entries, count, threshold)
    for i = 1, count do
        if (entries[i].effective_hp or 100) <= threshold then return entries[i] end
    end
    return nil
end
NS.rotation_registry = { register = function() end }
NS.log = function() end

-- Mock shared modules
local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then
        return context.settings[key]
    end
    return default
end
local mock_spec_kit = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    define_action_for_class = function(SPELLS)
        return function(field, rank_ids, label)
            if SPELLS and SPELLS[field] then return SPELLS[field] end
            return rank_ids and rank_ids[1] or field
        end
    end,
    safe_state = function(raw, schema)
        return setmetatable({}, {
            __index = function(t, k)
                if raw[k] ~= nil then return raw[k] end
                if schema and schema[k] ~= nil then return schema[k] end
                return nil
            end,
        })
    end,
    setting = _setting,
    setting_bool = function(context, key, default)
        local v = _setting(context, key, nil)
        if v == nil then return default end
        return v ~= false
    end,
    setting_number = function(context, key, default)
        local v = _setting(context, key, nil)
        if type(v) == "number" then return v end
        return default
    end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
local scan_entries = {}
package.loaded["classes/druid/healing_sylvanas"] = {
    scan_healing_targets = function() return scan_entries, #scan_entries end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    MANA_POTION_IDS = { 28100 },
    try_use_potion = function(ctx, ids) return true end,
}
package.loaded["shared/tbc_data_sylvanas"] = { ITEMS = { potions = {} } }
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 50,
    match = function() return false end,
    execute = function() return true end,
    get_penalty_adjusted_heal = function(spell_id, heal_size) return spell_id, 1 end,
}

-- Load the real DSL engine so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the restoration druid spec
local resto = dofile("EaxRotations/classes/druid/resto_sylvanas.lua")
local strategies = resto.strategies

-- Restore package.loaded for spec_kit so later tests load real module
package.loaded["shared/spec_kit_sylvanas"] = nil

-- ============================================================================
-- Helpers
-- ============================================================================
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name)
end

local function index_of(name)
    local _, idx = find_strategy(name)
    return idx
end

local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        in_combat = false,
        is_pvp = false,
        hp = 100,
        stance = 0, -- STANCE_CASTER
        mana_pct = 100,
        settings = {},
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        mana_pct = 100,
        hp_pct = 100,
        melee_pressure_count = 0,
        innervate_target = nil,
        in_combat = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

scan_entries = {}
local move_state = resto.build_state(make_ctx({
    is_moving = true,
    in_combat = false,
    target_distance = 30,
}))
assert_true(move_state.should_move_form,
    "Repositioning frame requests a movement form")

local settled_state = resto.build_state(make_ctx({
    is_moving = false,
    in_combat = true,
    target_distance = 0,
}))
assert_false(settled_state.should_move_form,
    "Movement-form request resets when the next frame no longer needs repositioning")

local tree_emergency = { unit = {}, effective_hp = 20, is_tank = false }
scan_entries = { tree_emergency }
local tree_state = resto.build_state(make_ctx({
    in_combat = true,
    stance = 5,
}))
assert_true(tree_state.should_dance_caster,
    "Tree emergency frame requests caster-form dancing")

scan_entries = {}
local caster_state = resto.build_state(make_ctx({
    in_combat = true,
    stance = 0,
}))
assert_false(caster_state.should_dance_caster,
    "Caster frame clears the prior Tree emergency dance request")

-- ============================================================================
-- Priority order sanity check
-- ============================================================================
local bs = index_of("BarkskinSelfPreservation")
local bf = index_of("BearFormFocusedByMelee")
local ng = index_of("NaturesGraspMelee")
local inn_self = index_of("InnervateSelf")
local inn_heal = index_of("InnervateHealer")
local rebirth = index_of("RebirthBattleRez")

assert_true(bs < bf, "Barkskin before BearForm")
assert_true(bf < ng, "BearForm before NaturesGrasp")
assert_true(ng < inn_self, "NaturesGrasp before InnervateSelf")
assert_true(inn_self < inn_heal, "InnervateSelf before InnervateHealer")
assert_true(inn_heal < rebirth, "InnervateHealer before Rebirth")

-- ============================================================================
-- BarkskinSelfPreservation equivalence
-- ============================================================================
local barkskin = find_strategy("BarkskinSelfPreservation")
assert_true(barkskin.matches(make_ctx({ hp = 50 }), make_state()),
    "Barkskin matches at low HP")
assert_false(barkskin.matches(make_ctx({ hp = 80 }), make_state()),
    "Barkskin skips at high HP")
assert_false(barkskin.matches(make_ctx({ hp = 50, settings = { barkskin_hp = 40 } }), make_state()),
    "Barkskin skips when setting threshold is lower")

-- ============================================================================
-- BearFormFocusedByMelee equivalence
-- ============================================================================
local bear = find_strategy("BearFormFocusedByMelee")
assert_true(bear.matches(make_ctx({ is_pvp = true, hp = 30, stance = 0 }), make_state({ melee_pressure_count = 1 })),
    "BearForm matches in PvP with low HP and melee pressure")
assert_false(bear.matches(make_ctx({ is_pvp = true, hp = 30, stance = 0 }), make_state({ melee_pressure_count = 0 })),
    "BearForm skips with no melee pressure")
assert_false(bear.matches(make_ctx({ is_pvp = true, hp = 60, stance = 0 }), make_state({ melee_pressure_count = 1 })),
    "BearForm skips at high HP")
assert_false(bear.matches(make_ctx({ is_pvp = true, hp = 30, stance = 1 }), make_state({ melee_pressure_count = 1 })),
    "BearForm skips when already in bear form")

-- ============================================================================
-- NaturesGraspMelee equivalence
-- ============================================================================
local grasp = find_strategy("NaturesGraspMelee")
assert_true(grasp.matches(make_ctx({ is_pvp = true }), make_state({ melee_pressure_count = 1 })),
    "NaturesGrasp matches in PvP with melee pressure and no buff")
assert_false(grasp.matches(make_ctx({ is_pvp = true }), make_state({ melee_pressure_count = 0 })),
    "NaturesGrasp skips with no melee pressure")
assert_false(grasp.matches(make_ctx({ is_pvp = false }), make_state({ melee_pressure_count = 1 })),
    "NaturesGrasp skips outside PvP")

-- Mock the buff present case by overriding has_player_buff
local original_has_buff = NS.has_player_buff
NS.has_player_buff = function() return true end
local ok_has_buff, err_has_buff = pcall(function()
    assert_false(grasp.matches(make_ctx({ is_pvp = true }), make_state({ melee_pressure_count = 1 })),
        "NaturesGrasp skips when buff already active")
end)
NS.has_player_buff = original_has_buff
if not ok_has_buff then error(err_has_buff) end

-- ============================================================================
-- InnervateSelf / InnervateHealer equivalence
-- ============================================================================
local other_unit = { get_health = function() return 100 end }
local inn_self_strat = find_strategy("InnervateSelf")
local inn_heal_strat = find_strategy("InnervateHealer")

assert_true(inn_self_strat.matches(make_ctx(), make_state({ innervate_target = NS.PLAYER_UNIT })),
    "InnervateSelf matches when target is self")
assert_false(inn_self_strat.matches(make_ctx(), make_state({ innervate_target = other_unit })),
    "InnervateSelf skips when target is another unit")

assert_true(inn_heal_strat.matches(make_ctx(), make_state({ innervate_target = other_unit })),
    "InnervateHealer matches when target is another unit")
assert_false(inn_heal_strat.matches(make_ctx(), make_state({ innervate_target = NS.PLAYER_UNIT })),
    "InnervateHealer skips when target is self")

-- ============================================================================
-- RebirthBattleRez equivalence
-- ============================================================================
local reb = find_strategy("RebirthBattleRez")

-- Simulate in party for the positive case
local old_is_party = NS.is_in_party
NS.is_in_party = function() return true end
local ok_party, err_party = pcall(function()
    assert_true(reb.matches(make_ctx({ in_combat = true }), make_state({ in_combat = true })),
        "Rebirth matches in combat when in party/raid")
end)
NS.is_in_party = old_is_party
if not ok_party then error(err_party) end

assert_false(reb.matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "Rebirth skips out of combat")
assert_false(reb.matches(make_ctx({ in_combat = true }), make_state({ in_combat = true })),
    "Rebirth skips when not in party or raid")

-- Simulate in party again for explicit in-party check
local old_is_party_2 = NS.is_in_party
NS.is_in_party = function() return true end
local ok_party_2, err_party_2 = pcall(function()
    assert_true(reb.matches(make_ctx({ in_combat = true }), make_state({ in_combat = true })),
        "Rebirth matches in combat while in party")
end)
NS.is_in_party = old_is_party_2
if not ok_party_2 then error(err_party_2) end

local function assert_same(actual, expected, msg)
    assert_true(actual == expected, msg)
end

local full_health = { unit = {}, effective_hp = 100, is_tank = true,
    lifebloom_stacks = 3, lifebloom_remains = 5,
    has_rejuvenation = true, has_regrowth = true }
scan_entries = { full_health }
local full_state = resto.build_state(make_ctx({ in_combat = true }))
assert_true(full_state.ht_target == nil and full_state.regrowth_target == nil
        and full_state.rejuv_target == nil and full_state.lifebloom_tank == nil,
    "Full-health tank with maintained HoTs does not trigger healing spam")

local injured_party = { unit = {}, effective_hp = 80, is_tank = false,
    lifebloom_stacks = 1, lifebloom_remains = 5,
    has_rejuvenation = false, has_regrowth = true }
scan_entries = { injured_party }
local injured_state = resto.build_state(make_ctx({ in_combat = true }))
assert_same(injured_state.rejuv_target, injured_party,
    "Injured authoritative party entry receives Rejuvenation maintenance")

local missing_hot_tank = { unit = {}, effective_hp = 80, is_tank = true,
    lifebloom_stacks = 0, lifebloom_remains = 0,
    has_rejuvenation = true, has_regrowth = true }
scan_entries = { missing_hot_tank }
local missing_hot_state = resto.build_state(make_ctx({ in_combat = true }))
assert_same(missing_hot_state.lifebloom_tank, missing_hot_tank,
    "Tank missing Lifebloom is selected for triple-stack maintenance")

local nearby_non_party = { unit = {}, effective_hp = 10, is_tank = false,
    lifebloom_stacks = 0, lifebloom_remains = 0,
    has_rejuvenation = false, has_regrowth = false }
scan_entries = { injured_party }
local boundary_state = resto.build_state(make_ctx({ in_combat = true }))
assert_false(boundary_state.lowest and boundary_state.lowest.unit == nearby_non_party.unit,
    "Non-party unit omitted by the authoritative healing scanner is never selected")

local ns_healing_touch = find_strategy("NaturesSwiftnessHealingTouch")
local tranquility = find_strategy("TranquilityEmergency")
local leave_tree = find_strategy("LeaveTreeForDirectHeal")
local emergency_target = { unit = {}, effective_hp = 20, time_to_die = 2 }
local tree_emergency_state = make_state({
    in_tree = true,
    should_dance_caster = true,
    has_natures_swiftness = true,
    ns_target = emergency_target,
    tranquility_count = 3,
})
local first_tree_emergency
for i = 1, #strategies do
    local strategy = strategies[i]
    if strategy.matches(make_ctx({ in_combat = true, stance = 5 }), tree_emergency_state) then
        first_tree_emergency = strategy.name
        break
    end
end
assert_same(first_tree_emergency, "LeaveTreeForDirectHeal",
    "Tree emergency leaves form before Healing Touch or Tranquility")
assert_true(ns_healing_touch.matches(make_ctx({ in_combat = true, stance = 0 }),
        make_state({ has_natures_swiftness = true, ns_target = emergency_target })),
    "Nature's Swiftness Healing Touch remains available in caster form")
assert_true(tranquility.matches(make_ctx({ in_combat = true, stance = 0 }),
        make_state({ tranquility_count = 3 })),
    "Tranquility remains available in caster form for raid emergencies")
assert_true(leave_tree.matches(make_ctx({ in_combat = true, stance = 5 }), tree_emergency_state),
    "LeaveTreeForDirectHeal matches the Tree emergency transition")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_resto_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_resto_dsl_priority")
