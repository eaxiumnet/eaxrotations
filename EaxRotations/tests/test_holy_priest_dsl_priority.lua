-- test_holy_priest_dsl_priority.lua â Holy Priest DSL priority + equivalence test.
-- WHAT:  Verifies that 6 DSL-converted strategies preserve priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 28th strategy DSL adopter (holy priest healer).
-- SAFETY: Pure unit tests with mocked API context; mocks are restored after loading.

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

NS.PriestSpells = {
    AbolishDisease = 552, BindingHeal = 32546, CircleofHealing = 34866,
    CureDisease = 528, DesperatePrayer = 25437, DispelMagic = 988,
    FearWard = 6346, Fade = 25429, FlashHeal = 25235, GreaterHeal = 25213,
    HolyFire = 25384, InnerFocus = 14751, Lightwell = 28275, MassDispel = 32375,
    PowerWordShield = 25218, PrayerofMending = 33076, PrayerOfHealing = 25308,
    Renew = 25222, ShadowWordPain = 25368, Shadowfiend = 34433, Smite = 25364,
    SymbolOfHope = 32548,
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
    -- Return a function for every requested helper name.
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

-- Load the real DSL engine so the spec file's require() picks it up
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

local function index_of(name)
    local _, idx = find_strategy(name)
    return idx
end

local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = {},
        is_moving = false,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        mana_pct = 80,
        hp_pct = 100,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- Priority order sanity check
-- ============================================================================
local dp = index_of("DesperatePrayer")
local sf = index_of("Shadowfiend")
local mp = index_of("ManaPotion")
local hs = index_of("Healthstone")
local soh = index_of("SymbolOfHope")
local fw = index_of("FearWard")

assert_true(dp < sf, "DesperatePrayer before Shadowfiend")
assert_true(sf < mp, "Shadowfiend before ManaPotion")
assert_true(mp < hs, "ManaPotion before Healthstone")
assert_true(soh < hs, "SymbolOfHope before Healthstone")
assert_true(fw < hs, "FearWard before Healthstone")

-- ============================================================================
-- DesperatePrayer equivalence
-- ============================================================================
local desperate_prayer = find_strategy("DesperatePrayer")
assert_true(desperate_prayer.matches(make_ctx({ hp = 20 }), make_state()),
    "DesperatePrayer matches at low HP in combat")
assert_false(desperate_prayer.matches(make_ctx({ hp = 50 }), make_state()),
    "DesperatePrayer skips at high HP")
assert_false(desperate_prayer.matches(make_ctx({ hp = 20, in_combat = false }), make_state()),
    "DesperatePrayer skips out of combat")
assert_false(desperate_prayer.matches(make_ctx({ hp = 20, player_control_locked = true }), make_state()),
    "DesperatePrayer skips when player_control_locked")

-- ============================================================================
-- Shadowfiend equivalence
-- ============================================================================
local shadowfiend = find_strategy("Shadowfiend")
assert_true(shadowfiend.matches(make_ctx({ mana_pct = 20 }), make_state({ shadowfiend_ready = true })),
    "Shadowfiend matches at low mana in combat")
assert_false(shadowfiend.matches(make_ctx({ mana_pct = 80 }), make_state({ shadowfiend_ready = true })),
    "Shadowfiend skips at high mana")
assert_false(shadowfiend.matches(make_ctx({ mana_pct = 20 }), make_state({ shadowfiend_ready = false })),
    "Shadowfiend skips when not ready")

-- ============================================================================
-- ManaPotion equivalence
-- ============================================================================
local mana_potion = find_strategy("ManaPotion")
assert_true(mana_potion.matches(make_ctx({ mana_pct = 15 }), make_state({ mana_pct = 15 })),
    "ManaPotion matches at low mana in combat")
assert_false(mana_potion.matches(make_ctx({ mana_pct = 80 }), make_state()),
    "ManaPotion skips at high mana")
assert_false(mana_potion.matches(make_ctx({ mana_pct = 15, in_combat = false }), make_state()),
    "ManaPotion skips out of combat")

-- ============================================================================
-- Healthstone equivalence
-- ============================================================================
local healthstone = find_strategy("Healthstone")
assert_true(healthstone.matches(make_ctx({ hp = 20 }), make_state({ healthstone_ready = true, healthstone_id = 12345 })),
    "Healthstone matches at low HP with item ready")
assert_false(healthstone.matches(make_ctx({ hp = 80 }), make_state({ healthstone_ready = true, healthstone_id = 12345 })),
    "Healthstone skips at high HP")
assert_false(healthstone.matches(make_ctx({ hp = 20 }), make_state({ healthstone_ready = false })),
    "Healthstone skips when item not ready")
assert_true(healthstone.matches(make_ctx({ hp = 20, in_combat = false }), make_state({ healthstone_ready = true, healthstone_id = 12345 })),
    "Healthstone matches out of combat (original behavior)")

-- ============================================================================
-- SymbolOfHope equivalence
-- ============================================================================
local symbol_of_hope = find_strategy("SymbolOfHope")
assert_true(symbol_of_hope.matches(make_ctx({ is_group = true }), make_state({ symbol_of_hope_ready = true })),
    "SymbolOfHope matches in group with spell ready")
assert_false(symbol_of_hope.matches(make_ctx({ is_group = true }), make_state({ symbol_of_hope_ready = false })),
    "SymbolOfHope skips when not ready")
assert_false(symbol_of_hope.matches(make_ctx({ is_group = false }), make_state({ symbol_of_hope_ready = true })),
    "SymbolOfHope skips when not in group")

-- ============================================================================
-- FearWard equivalence
-- ============================================================================
local fear_ward = find_strategy("FearWard")
assert_true(fear_ward.matches(make_ctx(), make_state({ fear_ward_ready = true, has_fear_ward = false })),
    "FearWard matches when ready and not already active")
assert_false(fear_ward.matches(make_ctx(), make_state({ fear_ward_ready = true, has_fear_ward = true })),
    "FearWard skips when already active")
assert_false(fear_ward.matches(make_ctx(), make_state({ fear_ward_ready = false, has_fear_ward = false })),
    "FearWard skips when not ready")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_holy_priest_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_holy_priest_dsl_priority")
