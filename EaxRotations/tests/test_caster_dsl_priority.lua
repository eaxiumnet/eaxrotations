-- test_caster_dsl_priority.lua â Druid Caster DSL priority + equivalence test.
-- WHAT:  Verifies that the 6 DSL-converted strategies preserve priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the final DSL adopter (caster druid).
-- SAFETY: Pure unit tests with mocked API context.

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
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return true end
NS.unit_health_pct = function() return 100 end
NS.mana_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.rotation_registry = { register = function() end }
NS.log = function() end

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

-- Load the real DSL engine
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the caster druid spec
local caster = dofile("EaxRotations/classes/druid/caster_sylvanas.lua")
local strategies = caster.strategies

-- Restore package.loaded for spec_kit
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
        in_combat = true,
        hp = 100,
        mana_pct = 100,
        settings = {},
        target_armor = 2000,
        target = { get_health = function() return 100 end, is_valid = function() return true end },
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        hp_pct = 100,
        mana_pct = 100,
        moonfire_remains = 0,
        ff_remains = 0,
        innervate_ready = false,
        in_combat = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Priority order sanity check
-- ============================================================================
local barkskin_idx = index_of("Barkskin")
local thorns_idx = index_of("Thorns")
local innervate_idx = index_of("Innervate")
local faeriefire_idx = index_of("FaerieFire")
local moonfire_idx = index_of("Moonfire")
local wrath_idx = index_of("Wrath")

assert_true(barkskin_idx < thorns_idx, "Barkskin before Thorns")
assert_true(thorns_idx < innervate_idx, "Thorns before Innervate")
assert_true(innervate_idx < faeriefire_idx, "Innervate before FaerieFire")
assert_true(faeriefire_idx < moonfire_idx, "FaerieFire before Moonfire")
assert_true(moonfire_idx < wrath_idx, "Moonfire before Wrath")

-- ============================================================================
-- Barkskin equivalence
-- ============================================================================
local barkskin = find_strategy("Barkskin")
assert_true(barkskin.matches(make_ctx({ hp = 40 }), make_state()),
    "Barkskin matches at low HP")
assert_false(barkskin.matches(make_ctx({ hp = 90 }), make_state()),
    "Barkskin skips at high HP")
-- caster_context_allowed defaults to true when none of solo/leveling/pvp/raid are set
assert_true(barkskin.matches(make_ctx({ hp = 40 }), make_state()),
    "Barkskin matches at low HP in default context")

-- ============================================================================
-- Innervate equivalence
-- ============================================================================
local innervate = find_strategy("Innervate")
assert_true(innervate.matches(make_ctx({ mana_pct = 20 }), make_state({ innervate_ready = true })),
    "Innervate matches at low mana with spell ready")
assert_false(innervate.matches(make_ctx({ mana_pct = 50 }), make_state({ innervate_ready = true })),
    "Innervate skips at high mana")
assert_false(innervate.matches(make_ctx({ mana_pct = 20 }), make_state({ innervate_ready = false })),
    "Innervate skips when spell not ready")
assert_false(innervate.matches(make_ctx({ mana_pct = 20, in_combat = false }), make_state({ innervate_ready = true })),
    "Innervate skips out of combat")

-- ============================================================================
-- FaerieFire equivalence
-- ============================================================================
local faeriefire = find_strategy("FaerieFire")
assert_true(faeriefire.matches(make_ctx({ target_armor = 5000 }), make_state({ ff_remains = 0 })),
    "FaerieFire matches when target has armor and debuff expired")
assert_false(faeriefire.matches(make_ctx({ target_armor = 0 }), make_state({ ff_remains = 0 })),
    "FaerieFire skips when target has no armor")
assert_false(faeriefire.matches(make_ctx({ target_armor = 5000 }), make_state({ ff_remains = 10 })),
    "FaerieFire skips when debuff is still fresh")

-- ============================================================================
-- Moonfire equivalence
-- ============================================================================
local moonfire = find_strategy("Moonfire")
assert_true(moonfire.matches(make_ctx(), make_state({ moonfire_remains = 0 })),
    "Moonfire matches when debuff expired")
assert_false(moonfire.matches(make_ctx(), make_state({ moonfire_remains = 8 })),
    "Moonfire skips when debuff is still fresh")

-- ============================================================================
-- Wrath equivalence
-- ============================================================================
local wrath = find_strategy("Wrath")
assert_true(wrath.matches(make_ctx({ is_moving = false }), make_state()),
    "Wrath matches when not moving")
assert_false(wrath.matches(make_ctx({ is_moving = true }), make_state()),
    "Wrath skips when moving")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_caster_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_caster_dsl_priority")
