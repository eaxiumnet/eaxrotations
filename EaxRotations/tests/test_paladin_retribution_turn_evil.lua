-- test_paladin_retribution_turn_evil.lua — Retribution Paladin TurnEvil auto-CC strategy tests.
-- WHAT:  Verifies the TurnEvil strategy matches only when all conditions are met.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for auto-CC on undead/demon targets in retribution spec.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Start from a clean global namespace
_G.EaxRotations = nil
_G.core = nil

-- Ensure fresh loads
package.loaded["classes/paladin/retribution_sylvanas"] = nil
package.loaded["shared/spec_kit_sylvanas"] = nil
package.loaded["shared/strategy_dsl_sylvanas"] = nil
package.loaded["shared/hit_cap_tracker_sylvanas"] = nil
package.loaded["shared/cooldown_planner_sylvanas"] = nil
package.loaded["shared/tbc_data_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = nil

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
-- Mock NS (mirrors test_retribution_dsl_priority.lua)
-- ============================================================================
local mock_hp_pct = 100
local mock_target_hp_pct = 100
local mock_mana_pct = 100
local mock_spell_ready_result = true

_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return 100 end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return 0 end
NS.spell_ready = function() return mock_spell_ready_result end
NS.try_cast = function() return true end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.has_player_buff = function() return false end
NS.has_player_debuff = function() return false end
NS.use_item_by_id = function(id) return id ~= nil end
NS.broken_api_throttled = function() return false end
NS.unit_health_pct = function() return mock_hp_pct end
NS.unit_mana_pct = function() return mock_mana_pct end
NS.get_any_setting = function(ctx, key, alt, default) return default end
NS.is_valid_target = function(unit) return unit ~= nil and (unit.is_valid == nil or unit:is_valid()) and not (unit.is_dead and unit:is_dead()) end
NS.rotation_registry = { register = function() end }
NS.PaladinSpells = {
    AvengingWrath = 31884, BlessingOfFreedom = 1044, BlessingOfKings = 20217,
    BlessingOfMight = 27140, BlessingOfProtection = 10278, Cleanse = 4987,
    Consecration = 27173, CrusaderStrike = 35395, DivineProtection = 498,
    DivineShield = 642, Exorcism = 879, HammerOfJustice = 853,
    HammerOfWrath = 24275, HolyWrath = 2812, Judgement = 20271,
    LayOnHands = 633, Purify = 1152, Repentance = 20066, SanctityAura = 20218,
    SealBlood = 31892, SealCommand = 20375, SealCrusader = 21082,
    SealOfTheMartyr = 348700, SealOfWisdom = 20166, SealRighteousness = 20154,
    TurnEvil = 10326,
}
NS.PaladinConstants = {}

-- Mock shared modules
package.loaded["shared/spec_kit_sylvanas"] = {
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
            if SPELLS and type(SPELLS) == "table" and SPELLS[spell_field] ~= nil then
                return SPELLS[spell_field]
            end
            return rank_ids and rank_ids[1] or spell_field
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
    merge_state = function(build_state, context, state_override)
        local s = build_state(context)
        if not state_override or next(state_override) == nil then return s end
        local merged = {}
        for k, v in pairs(s) do merged[k] = v end
        for k, v in pairs(state_override) do merged[k] = v end
        local mt = getmetatable(s)
        if mt then
            local mt_copy = {}
            for k, v in pairs(mt) do mt_copy[k] = v end
            mt_copy.__newindex = nil
            setmetatable(merged, mt_copy)
        end
        return merged
    end,
}
package.loaded["shared/hit_cap_tracker_sylvanas"] = {
    get_hit_cap = function() return nil end,
    get_expertise_cap = function() return nil end,
}
package.loaded["shared/tbc_data_sylvanas"] = nil
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

-- ============================================================================
-- Load the retribution spec
-- ============================================================================
local ret = dofile("EaxRotations/classes/paladin/retribution_sylvanas.lua")
local strategies = ret.strategies

-- ============================================================================
-- Helpers
-- ============================================================================
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name)
end

local turn_evil = find_strategy("TurnEvil")

local function make_ctx(overrides)
    local ctx = {
        me = { get_health = function() return 100 end, is_valid = function() return true end, is_dead = function() return false end },
        target = { get_health = function() return 50 end, is_valid = function() return true end, is_dead = function() return false end },
        in_combat = true,
        hp = mock_hp_pct,
        mana_pct = mock_mana_pct,
        settings = {},
        has_valid_enemy_target = true,
        enemy_count = 1,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        hp_pct = mock_hp_pct,
        target_hp_pct = mock_target_hp_pct,
        mana_pct = mock_mana_pct,
        target_creature_type = 6,  -- undead
        turn_evil_ready = true,
        mana_emergency = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Test 1: Strategy "TurnEvil" is registered
-- ============================================================================
assert_true(turn_evil ~= nil, "TurnEvil strategy should be registered")
assert_eq(turn_evil.name, "TurnEvil", "strategy name should be TurnEvil")

-- ============================================================================
-- Test 2: Match TRUE — undead target, setting enabled, spell ready, no debuff
-- ============================================================================
assert_true(turn_evil.matches(make_ctx(), make_state()), "should match undead target with all conditions met")

-- ============================================================================
-- Test 3: Match TRUE — demon target (creature_type=3)
-- ============================================================================
assert_true(turn_evil.matches(make_ctx(), make_state({ target_creature_type = 3 })), "should match demon target (creature_type=3)")

-- ============================================================================
-- Test 4: Match FALSE — setting disabled
-- ============================================================================
assert_false(turn_evil.matches(make_ctx({ settings = { retri_auto_turn_evil = false } }), make_state()), "should not match when retri_auto_turn_evil is false")

-- ============================================================================
-- Test 5: Match FALSE — creature_type not undead/demon
-- ============================================================================
assert_false(turn_evil.matches(make_ctx(), make_state({ target_creature_type = 1 })), "should not match human target (creature_type=1)")

-- ============================================================================
-- Test 6: Match FALSE — spell not ready
-- ============================================================================
assert_false(turn_evil.matches(make_ctx(), make_state({ turn_evil_ready = false })), "should not match when turn_evil_ready is false")

-- ============================================================================
-- Test 7: Match FALSE — target already has Turn Evil debuff
-- ============================================================================
NS.debuff_up = function(target, ids) return true end
assert_false(turn_evil.matches(make_ctx(), make_state()), "should not match when target already has Turn Evil debuff")
NS.debuff_up = function() return false end  -- reset

-- ============================================================================
-- Test 8: Match FALSE — no valid enemy target
-- ============================================================================
assert_false(turn_evil.matches(make_ctx({ has_valid_enemy_target = false }), make_state()), "should not match when no valid enemy target")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_paladin_retribution_turn_evil: %d passed, %d failed", _pass, _fail))
if _fail > 0 then os.exit(1) end
print("PASS test_paladin_retribution_turn_evil")
