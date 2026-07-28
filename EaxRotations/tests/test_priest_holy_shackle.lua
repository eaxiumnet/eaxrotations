-- test_priest_holy_shackle.lua — Holy Priest ShackleUndead auto-CC strategy tests.
-- WHAT:  Verifies the ShackleUndead strategy matches only when all conditions are met.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for auto-CC on undead/demon targets.
-- SAFETY: Pure unit tests with mocked API context.

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
-- Mock NS (mirrors test_holy_priest_dsl_priority.lua)
-- ============================================================================
local NS = {}
_G.EaxRotations = NS

NS.PriestSpells = {
    AbolishDisease = 552, BindingHeal = 32546, CircleofHealing = 34866,
    CureDisease = 528, DesperatePrayer = 25437, DispelMagic = 988,
    FearWard = 6346, Fade = 25429, FlashHeal = 25235, GreaterHeal = 25213,
    HolyFire = 25384, InnerFocus = 14751, Lightwell = 28275, MassDispel = 32375,
    PowerWordShield = 25218, PrayerofMending = 33076, PrayerOfHealing = 25308,
    Renew = 25222, ShadowWordPain = 25368, Shadowfiend = 34433, Smite = 25364,
    SymbolOfHope = 32548, ShackleUndead = 10955,
}
NS.PriestHealing = {
    scan_healing_targets = function() return {}, 0 end,
    count_subgroup_below_hp = function() return 0 end,
    has_dangerous_dispel = function() return false end,
    has_disease = function() return false end,
}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end, get_class = function() return "PRIEST" end, is_mounted = function() return false end, is_moving = function() return false end, mana_pct = function() return 80 end }
NS.CLASS_ID = { PRIEST = "PRIEST" }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.has_buff = function() return false end
NS.has_player_buff = function() return false end
NS.has_player_debuff = function() return false end
NS.buff_remains = function() return 0 end
NS.buff_stacks = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.import_helpers = function(...)
    local helpers = {}
    for i = 1, select("#", ...) do helpers[select(i, ...)] = function() return true end end
    helpers["health_pct"] = function() return 100 end
    helpers["player_control_locked"] = function() return false end
    return helpers["try_cast"], helpers["spell_exists"], helpers["spell_ready"],
           helpers["debuff_remains"], helpers["health_pct"],
           helpers["player_control_locked"], helpers["has_player_buff"]
end
NS.is_item_ready = function() return false end
NS.use_item_by_id = function() return true end
NS.ConsumableManager = { use_mana_potion = function() return true end }
NS.unit_health_pct = function() return 100 end
NS.unit_mana_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_overheal = function() return false end
NS.GetEnemiesInRange = function() return {} end
NS.get_friendly_target_entry = function() return nil end
NS.is_pvp_zone = function() return false end
NS.log = function() end
NS.rotation_registry = { register = function() end }
NS.StopCast = { update = function() end }
NS.core = { get_map_id = function() return 0 end }

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
package.loaded["classes/priest/healing_sylvanas"] = NS.PriestHealing
package.loaded["shared/preemptive_heal_sylvanas"] = {
    DEFAULT_THRESHOLD = 40,
    match = function() return false end,
    execute = function() return false end,
    get_penalty_adjusted_heal = function(id, ct) return id, 1 end,
}
package.loaded["shared/fsr_manager_sylvanas"] = {
    is_inside_fsr = function() return false end,
    seconds_until_fsr = function() return 0 end,
    get_regen_delta = function() return 0 end,
    should_pause_for_fsr = function() return false end,
}
package.loaded["shared/profiler_helper_sylvanas"] = {
    start = function() end,
    stop = function() end,
}
package.loaded["shared/health_pred_helper_sylvanas"] = nil
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the holy priest spec
local holy = dofile("EaxRotations/classes/priest/holy_sylvanas.lua")
local strategies = holy.strategies

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

local shackle = find_strategy("ShackleUndead")

local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, get_creature_type = function() return 6 end },
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
-- Test 3: Match TRUE — demon target (creature_type=3)
-- ============================================================================
assert_true(shackle.matches(make_ctx(), make_state({ target_creature_type = 3 })), "should match demon target (creature_type=3)")

-- ============================================================================
-- Test 4: Match FALSE — setting disabled
-- ============================================================================
assert_false(shackle.matches(make_ctx({ settings = { holy_auto_shackle = false } }), make_state()), "should not match when holy_auto_shackle is false")

-- ============================================================================
-- Test 5: Match FALSE — creature_type not undead/demon (e.g., type=1 human)
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
print(string.format("test_priest_holy_shackle: %d passed, %d failed", _pass, _fail))
if _fail > 0 then os.exit(1) end
print("PASS test_priest_holy_shackle")
