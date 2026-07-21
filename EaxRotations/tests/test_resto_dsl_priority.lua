-- test_resto_dsl_priority.lua — Restoration Druid DSL priority + equivalence test.
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
NS.has_dispel_type_debuff = function() return false end
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
package.loaded["classes/druid/healing_sylvanas"] = {
    scan_healing_targets = function() return {}, 0 end,
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
assert_false(grasp.matches(make_ctx({ is_pvp = true }), make_state({ melee_pressure_count = 1 })),
    "NaturesGrasp skips when buff already active")
NS.has_player_buff = original_has_buff

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
assert_true(reb.matches(make_ctx({ in_combat = true }), make_state({ in_combat = true })),
    "Rebirth matches in combat when in party/raid")
NS.is_in_party = old_is_party

assert_false(reb.matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "Rebirth skips out of combat")
assert_false(reb.matches(make_ctx({ in_combat = true }), make_state({ in_combat = true })),
    "Rebirth skips when not in party or raid")

-- Simulate in party again for explicit in-party check
NS.is_in_party = function() return true end
assert_true(reb.matches(make_ctx({ in_combat = true }), make_state({ in_combat = true })),
    "Rebirth matches in combat while in party")
NS.is_in_party = old_is_party

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_resto_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_resto_dsl_priority")
