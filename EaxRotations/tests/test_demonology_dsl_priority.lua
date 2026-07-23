-- test_demonology_dsl_priority.lua — Demonology Warlock DSL priority + equivalence test.
-- WHAT:  Verifies that the 6 DSL-converted strategies preserve their priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 14th strategy DSL adopter (demonology warlock).
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

-- Mock pet_manager
local restore_pet = install_mock("shared/pet_manager_sylvanas", function()
    return {
        set_defensive = function() return true end,
        set_passive = function() return true end,
        set_aggressive = function() return true end,
    }
end)

-- Mock spec_kit
local restore_spec = install_mock("shared/spec_kit_sylvanas", function()
    local M = {}
    M.merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state
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

-- Mock curse helper
local restore_curse = install_mock("shared/warlock_curse_helper_sylvanas", function()
    return {
        CURSE_REFRESH_WINDOW = 3,
        CURSE_OF_AGONY_DEBUFF = { 27218, 11713, 11712, 11711, 6217, 1014, 980 },
        CURSE_OF_ELEMENTS_DEBUFF = { 27228, 11722, 11721, 1490 },
        CURSE_OF_RECKLESSNESS_DEBUFF = { 27226, 11717, 7659, 7658, 704 },
        CURSE_OF_WEAKNESS_DEBUFF = { 30909, 27224, 11708, 11707, 7646, 6205, 1108, 702 },
        other_curse_active = function(s, curse) return false end,
    }
end)

-- Mock NS
local current_time = 1000
local cast_log = {}
_G.EaxRotations = {
    WarlockSpells = {},
    spell_action = function(ids, name) return { ids = ids, name = name } end,
    is_spell_learned = function(id) return true end,
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, label, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, label = label }
        return true
    end,
    debuff_remains = function(target, ids) return 0 end,
    buff_up = function(unit, ids) return false end,
    log = function() end,
    log_warning = function() end,
    time_now = function() return current_time end,
    GetPlayer = function() return "player" end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warlock/demonology_sylvanas.lua")
assert_true(result, "demonology module should load")
local strategies = result.strategies
assert_true(strategies and #strategies > 0, "strategies table should load")

-- Restore require state so later tests in the same runner process load the real modules.
restore_pet()
restore_spec()
restore_curse()

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
local felarmor_idx = index_of("FelArmor")
local soullink_idx = index_of("SoulLink")
local corruption_idx = index_of("Corruption")
local shadowbolt_idx = index_of("ShadowBolt")
local petdef_idx = index_of("PetDefensive")
local lifetap_idx = index_of("LifeTap")

assert_true(felarmor_idx < soullink_idx, "FelArmor should remain before SoulLink")
assert_true(soullink_idx < corruption_idx, "SoulLink should remain before Corruption")
assert_true(corruption_idx < shadowbolt_idx, "Corruption should remain before ShadowBolt")
assert_true(petdef_idx > 0 and petdef_idx <= #strategies, "PetDefensive index is sane")

-- ============================================================================
-- FelArmor equivalence
-- ============================================================================
local felarmor = find_strategy("FelArmor")
local ctx = { target = {}, me = "player" }
local st_felarmor = { has_fel_armor = false, fel_armor_ready = true }
local st_felarmor_active = { has_fel_armor = true, fel_armor_ready = true }
assert_true(felarmor.matches(ctx, st_felarmor), "FelArmor matches when buff missing and ready")
assert_false(felarmor.matches(ctx, st_felarmor_active), "FelArmor does not match when already active")

-- ============================================================================
-- SoulLink equivalence
-- ============================================================================
local soullink = find_strategy("SoulLink")
local st_soullink = { has_pet = true, has_soul_link = false, soul_link_ready = true }
local st_soullink_active = { has_pet = true, has_soul_link = true, soul_link_ready = true }
assert_true(soullink.matches(ctx, st_soullink), "SoulLink matches when pet exists and buff missing")
assert_false(soullink.matches(ctx, st_soullink_active), "SoulLink does not match when already active")

-- ============================================================================
-- Corruption equivalence
-- ============================================================================
local corruption = find_strategy("Corruption")
local st_corrupt = { corruption_ready = true }
local ctx_corrupt = { target = {}, ttd_known = true, ttd = 10 }
assert_true(corruption.matches(ctx_corrupt, st_corrupt), "Corruption matches when debuff missing, ready, and TTD long")

local ctx_corrupt_short = { target = {}, ttd_known = true, ttd = 2 }
assert_false(corruption.matches(ctx_corrupt_short, st_corrupt), "Corruption does not match when TTD too short")

-- ============================================================================
-- ShadowBolt equivalence
-- ============================================================================
local shadowbolt = find_strategy("ShadowBolt")
local ctx_bolt = { target = {}, is_moving = false }
local st_bolt = { shadow_bolt_ready = true }
local ctx_bolt_moving = { target = {}, is_moving = true }
assert_true(shadowbolt.matches(ctx_bolt, st_bolt), "ShadowBolt matches when stationary and ready")
assert_false(shadowbolt.matches(ctx_bolt_moving, st_bolt), "ShadowBolt does not match while moving")

-- ============================================================================
-- PetDefensive equivalence
-- ============================================================================
local petdef = find_strategy("PetDefensive")
local ctx_petdef = { in_combat = true }
local st_petdef = { has_pet = true, pet_hp_pct = 20, in_combat = true }
local st_petdef_high = { has_pet = true, pet_hp_pct = 50, in_combat = true }
assert_true(petdef.matches(ctx_petdef, st_petdef), "PetDefensive matches when pet HP low and in combat")
assert_false(petdef.matches(ctx_petdef, st_petdef_high), "PetDefensive does not match when pet HP high")

-- ============================================================================
-- LifeTap equivalence (anti-spam preserved)
-- ============================================================================
local lifetap = find_strategy("LifeTap")
local ctx_lt = { target = {}, me = "player", settings = {} }
local st_lt = { hp_pct = 80, mana_pct = 20, life_tap_ready = true }
current_time = 1000
assert_true(lifetap.matches(ctx_lt, st_lt), "LifeTap matches when mana low, HP safe, and not throttled")

-- Simulate recent cast
_G.EaxRotations.time_now = function() return current_time end
lifetap.execute(ctx_lt, st_lt)
current_time = 1001
assert_false(lifetap.matches(ctx_lt, st_lt), "LifeTap does not match within throttle window")

current_time = 1002
assert_true(lifetap.matches(ctx_lt, st_lt), "LifeTap matches after throttle window expires")

print("PASS test_demonology_dsl_priority")
