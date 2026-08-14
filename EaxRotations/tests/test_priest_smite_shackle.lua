-- test_priest_smite_shackle.lua — Smite Priest ShackleUndead auto-CC strategy tests.
-- WHAT:  Verifies the ShackleUndead strategy matches only when all conditions are met.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for auto-CC on undead/demon targets in smite spec.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
end
local function assert_false(cond, msg)
    if not cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg .. " (expected false)") end
end
local function assert_eq(a, b, msg)
    if a == b then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg .. " (got " .. tostring(a) .. " expected " .. tostring(b) .. ")") end
end

-- ============================================================================
-- Mock NS (mirrors test_smite_dsl_priority.lua)
-- ============================================================================
local NS = {}
_G.EaxRotations = NS

NS.CLASS_ID = { PRIEST = 5 }
NS.PriestSpells = { ShackleUndead = 10955 }
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end, get_class = function() return 5 end, get_race_id = function() return 1 end }
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
NS.import_helpers = function(...)
    local t = {}
    for _, key in ipairs({...}) do t[key] = function() return true end end
    return t.try_cast or function() return true end, t.spell_exists or function() return true end,
           t.spell_ready or function() return true end, t.debuff_remains or function() return 0 end,
           t.buff_up or function() return false end, t.buff_remains or function() return 0 end,
           t.health_pct or function() return 100 end, t.player_control_locked or function() return false end
end

package.loaded["common/utility/inventory_helper"] = { has_item = function() return false end }
package.loaded["common/enums"] = { class_id = { PRIEST = 5 } }

local _setting = function(context, key, default)
    if context and context.settings and context.settings[key] ~= nil then return context.settings[key] end
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
        return setmetatable({}, { __index = function(t, k) if raw[k] ~= nil then return raw[k] end if schema and schema[k] ~= nil then return schema[k] end return nil end })
    end,
    setting = _setting,
    setting_bool = function(context, key, default) local v = _setting(context, key, nil); if v == nil then return default end return v ~= false end,
    setting_number = function(context, key, default) local v = _setting(context, key, nil); if type(v) == "number" then return v end return default end,
}
package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

local smite = dofile("EaxRotations/classes/priest/smite_sylvanas.lua")
local strategies = smite.strategies
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

local shackle = find_strategy("ShackleUndead")

local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end },
        in_combat = true,
        hp = 100,
        mana_pct = 100,
        settings = {},
        has_valid_enemy_target = true,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        shackle_undead_ready = true,
        target_creature_type = 6,  -- undead
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Test 1: Strategy "ShackleUndead" is registered
-- ============================================================================
assert_true(shackle ~= nil, "ShackleUndead strategy should be registered")
assert_eq(shackle.name, "ShackleUndead", "strategy name should be ShackleUndead")

-- ============================================================================
-- Test 2: Match TRUE — undead target, setting enabled, spell ready, no debuff
-- ============================================================================
assert_true(shackle.matches(make_ctx(), make_state()), "should match undead target with all conditions met")

-- ============================================================================
-- Test 3: Match FALSE — demon target (creature_type=3)
-- Shackle Undead affects Undead only (creature type 6); demons are not
-- shackleable. Restricted 2026-08-12 to mirror shadow/discipline (the old
-- demon allowance was a live bug — the cast silently did nothing).
-- ============================================================================
assert_false(shackle.matches(make_ctx(), make_state({ target_creature_type = 3 })), "should NOT match demon target (creature_type=3)")

-- ============================================================================
-- Test 4: Match FALSE — setting disabled
-- ============================================================================
assert_false(shackle.matches(make_ctx({ settings = { smite_auto_shackle = false } }), make_state()), "should not match when smite_auto_shackle is false")

-- ============================================================================
-- Test 5: Match FALSE — creature_type not undead (e.g., type=1 human)
-- ============================================================================
assert_false(shackle.matches(make_ctx(), make_state({ target_creature_type = 1 })), "should not match human target (creature_type=1)")

-- ============================================================================
-- Test 6: Match FALSE — spell not ready
-- ============================================================================
assert_false(shackle.matches(make_ctx(), make_state({ shackle_undead_ready = false })), "should not match when shackle_undead_ready is false")

-- ============================================================================
-- Test 7: Match FALSE — target already has shackle debuff
-- ============================================================================
NS.debuff_up = function(target, ids) return true end
assert_false(shackle.matches(make_ctx(), make_state()), "should not match when target already has shackle debuff")
NS.debuff_up = function() return false end  -- reset

-- ============================================================================
-- Test 8: Match FALSE — no valid enemy target
-- ============================================================================
assert_false(shackle.matches(make_ctx({ has_valid_enemy_target = false }), make_state()), "should not match when no valid enemy target")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_priest_smite_shackle: %d passed, %d failed", _pass, _fail))
if _fail > 0 then os.exit(1) end
print("PASS test_priest_smite_shackle")
