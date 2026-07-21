-- test_bear_dsl_priority.lua — Bear Druid DSL priority + equivalence test.
-- WHAT:  Verifies that the 7 DSL-converted strategies preserve their priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 15th strategy DSL adopter (bear druid).
-- SAFETY: Pure unit tests with mocked API context; mocks are restored after loading.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false, assert_eq

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
end
setup_asserts()

-- Helper to install a require mock and return a restore function.
local function install_mock(module_name, factory)
    local orig_preload = package.preload[module_name]
    local orig_loaded = package.loaded[module_name]
    package.preload[module_name] = factory
    package.loaded[module_name] = nil
    return function()
        package.preload[module_name] = orig_preload
        package.loaded[module_name] = orig_loaded
    end
end

-- Mock spec_kit
local restore_spec = install_mock("shared/spec_kit_sylvanas", function()
    local M = {}
    function M.define_action_for_class(_)
        return function(_, ids, name) return { ids = ids, name = name } end
    end
    function M.setting(ctx, key, default)
        local s = (ctx and ctx.settings) or {}
        return s[key] or default
    end
    function M.setting_number(ctx, key, default)
        local s = (ctx and ctx.settings) or {}
        return s[key] or default
    end
    function M.setting_bool(ctx, key, default)
        local s = (ctx and ctx.settings) or {}
        local v = s[key]
        if v == nil then return default end
        return v
    end
    function M.safe_state(raw, schema)
        local mt = {}
        function mt.__index(t, k)
            local default = (schema and schema[k]) or nil
            if type(default) == "number" then return 0 end
            return default
        end
        setmetatable(raw, mt)
        return raw
    end
    return M
end)

-- Mock health_pred_helper
local predicted_hp_value = 30
local restore_hp = install_mock("shared/health_pred_helper_sylvanas", function()
    return {
        predicted_hp_pct = function(me, seconds) return predicted_hp_value end,
    }
end)

-- Mock AoE hit volume
local restore_aoe = install_mock("shared/aoe_hit_volume_sylvanas", function()
    return { install = function() end }
end)

-- Mock ranked buff families
local restore_rbf = install_mock("shared/ranked_buff_families_sylvanas", function()
    return { detect = function(name) return nil end }
end)

-- Mock NS namespace
local cast_log = {}
local is_current_spell_map = {}
local current_time = 1000
_G.EaxRotations = {
    DruidSpells = {},
    spell_action = function(ids, name) return { ids = ids, name = name } end,
    is_spell_learned = function(id) return true end,
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, label, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, label = label, opts = opts }
        return true
    end,
    debuff_remains = function(target, debuff_list) return 0 end,
    get_debuff_stacks = function(target, debuff_list) return 0 end,
    buff_up = function(unit, buff_list) return false end,
    buff_remains = function(unit, buff_list) return 0 end,
    log = function() end,
    log_warning = function() end,
    time_now = function() return current_time end,
    GetPlayer = function() return "player" end,
    rotation_registry = { register = function() end },
    has_form = function(form) return false end,
    is_current_spell = function(spell_id) return is_current_spell_map[spell_id] or false end,
    get_spell_id = function(spell) return spell and spell.ids and spell.ids[1] or nil end,
    spell_exists = function(spell) return true end,
    aoe_target_meets = function(threshold, radius, target, context, state) return threshold <= (state and state.enemy_count or 1) end,
}

local result = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
assert_true(result, "bear module should load")
local strategies = result.strategies
assert_true(strategies and #strategies > 0, "strategies table should load")

-- Restore require state so later tests in the same runner process load the real modules.
restore_spec()
restore_hp()
restore_aoe()
restore_rbf()

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

-- ============================================================================
-- Priority order sanity check
-- ============================================================================
local bearform_idx = index_of("BearForm")
local frenzied_idx = index_of("FrenziedRegeneration")
local demo_idx = index_of("DemoralizingRoar")
local ff_idx = index_of("FaerieFireFeral")
local mangle_idx = index_of("MangleBear")
local lacerate_idx = index_of("Lacerate")
local maul_idx = index_of("Maul")

assert_true(bearform_idx < frenzied_idx, "BearForm should remain before FrenziedRegeneration")
assert_true(frenzied_idx < demo_idx, "FrenziedRegeneration should remain before DemoralizingRoar")
assert_true(demo_idx < ff_idx, "DemoralizingRoar should remain before FaerieFireFeral")
assert_true(ff_idx < mangle_idx, "FaerieFireFeral should remain before MangleBear")
assert_true(mangle_idx < lacerate_idx, "MangleBear should remain before Lacerate")
assert_true(lacerate_idx < maul_idx, "Lacerate should remain before Maul")

-- ============================================================================
-- BearForm equivalence
-- ============================================================================
local bearform = find_strategy("BearForm")
local ctx_bear = { target = {}, me = "player", now = 10, in_combat = true, settings = { auto_bear_form_ooc = true } }
local st_bear = { is_bear = false, auto_bear_form = true, now = 10 }
assert_true(bearform.matches(ctx_bear, st_bear), "BearForm matches when not in bear form and auto enabled")

local st_bear_already = { is_bear = true, auto_bear_form = true, now = 10 }
assert_false(bearform.matches(ctx_bear, st_bear_already), "BearForm does not match when already in bear form")

-- ============================================================================
-- FrenziedRegeneration equivalence
-- ============================================================================
local frenzied = find_strategy("FrenziedRegeneration")
local ctx_fr = { target = {}, me = "player", settings = {} }
local st_fr = { is_bear = true, in_combat = true, use_cooldowns = true, has_frenzied_regen = false, rage = 30, hp = 30, frenzied_regen_hp = 35 }
assert_true(frenzied.matches(ctx_fr, st_fr), "FrenziedRegeneration matches when HP below threshold and rage available")

local st_fr_high_hp = { is_bear = true, in_combat = true, use_cooldowns = true, has_frenzied_regen = false, rage = 30, hp = 80, frenzied_regen_hp = 35 }
predicted_hp_value = 80
assert_false(frenzied.matches(ctx_fr, st_fr_high_hp), "FrenziedRegeneration does not match when HP and predicted HP are above threshold")
predicted_hp_value = 30

-- ============================================================================
-- DemoralizingRoar equivalence
-- ============================================================================
local demo_roar = find_strategy("DemoralizingRoar")
local ctx_demo = { target = {}, me = "player", settings = { bear_demo_roar = true } }
local st_demo = { is_bear = true, in_combat = true, demo_roar_enabled = true, target_range = 8, enemy_count = 1, demo_remains = 0, target_ttd = 30, target_hp = 50 }
assert_true(demo_roar.matches(ctx_demo, st_demo), "DemoralizingRoar matches within range with debuff expired")

local st_demo_far = { is_bear = true, in_combat = true, demo_roar_enabled = true, target_range = 15, enemy_count = 1, demo_remains = 0, target_ttd = 30, target_hp = 50 }
assert_false(demo_roar.matches(ctx_demo, st_demo_far), "DemoralizingRoar does not match beyond 10 yards")

-- ============================================================================
-- FaerieFireFeral equivalence
-- ============================================================================
local ff = find_strategy("FaerieFireFeral")
local ctx_ff = { target = {}, target_armor = 5000, me = "player", settings = {} }
local st_ff = { is_bear = true, in_combat = true, has_valid_target = true, target_range = 5, faerie_remains = 0 }
assert_true(ff.matches(ctx_ff, st_ff), "FaerieFireFeral matches when debuff expired and in range")

local st_ff_fresh = { is_bear = true, in_combat = true, has_valid_target = true, target_range = 5, faerie_remains = 10 }
assert_false(ff.matches(ctx_ff, st_ff_fresh), "FaerieFireFeral does not match when debuff fresh")

-- ============================================================================
-- MangleBear equivalence
-- ============================================================================
local mangle = find_strategy("MangleBear")
local ctx_mangle = { target = {}, me = "player", settings = {} }
local st_mangle = { is_bear = true, has_valid_target = true }
assert_true(mangle.matches(ctx_mangle, st_mangle), "MangleBear matches when in bear form with valid target")

local st_mangle_no_bear = { is_bear = false, has_valid_target = true }
assert_false(mangle.matches(ctx_mangle, st_mangle_no_bear), "MangleBear does not match when not in bear form")

-- ============================================================================
-- Lacerate equivalence
-- ============================================================================
local lacerate = find_strategy("Lacerate")
local ctx_lac = { target = {}, me = "player", settings = {} }
local st_lac = { is_bear = true, has_valid_target = true, target = {}, aoe_threshold = 3, enemy_count = 1, lacerate_stacks = 3, lacerate_remains = 0 }
assert_true(lacerate.matches(ctx_lac, st_lac), "Lacerate matches when stacks < 5")

local st_lac_maintain = { is_bear = true, has_valid_target = true, target = {}, aoe_threshold = 3, enemy_count = 1, lacerate_stacks = 5, lacerate_remains = 2 }
assert_true(lacerate.matches(ctx_lac, st_lac_maintain), "Lacerate matches when 5-stack about to drop")

local st_lac_fresh = { is_bear = true, has_valid_target = true, target = {}, aoe_threshold = 3, enemy_count = 1, lacerate_stacks = 5, lacerate_remains = 10 }
assert_false(lacerate.matches(ctx_lac, st_lac_fresh), "Lacerate does not match when 5-stack fresh")

-- ============================================================================
-- Maul equivalence
-- ============================================================================
local maul = find_strategy("Maul")
local ctx_maul = { target = {}, me = "player", settings = { bear_maul_rage = 50 } }
local st_maul = { is_bear = true, has_valid_target = true, target = {}, aoe_threshold = 3, enemy_count = 1, rage = 50, maul_rage = 50, level = 70, target_ttd = 10, is_target_boss = false, swing_remains = 1.0 }
assert_true(maul.matches(ctx_maul, st_maul), "Maul matches when rage >= threshold and not queued")

local st_maul_low_rage = { is_bear = true, has_valid_target = true, target = {}, aoe_threshold = 3, enemy_count = 1, rage = 30, maul_rage = 50, level = 70, target_ttd = 10, is_target_boss = false, swing_remains = 1.0 }
assert_false(maul.matches(ctx_maul, st_maul_low_rage), "Maul does not match when rage below threshold")

print("PASS test_bear_dsl_priority")
