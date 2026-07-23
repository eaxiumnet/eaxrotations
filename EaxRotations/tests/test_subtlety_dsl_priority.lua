-- test_subtlety_dsl_priority.lua — Subtlety Rogue DSL priority + equivalence test.
-- WHAT:  Verifies that the 6 DSL-converted strategies preserve their priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 25th strategy DSL adopter (subtlety rogue).
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
    end
    return M
end)

-- Mock leveling helpers
local restore_leveling = install_mock("shared/leveling_helpers_sylvanas", function()
    return { is_low_level = function(level) return false end, level_from_context = function(ctx, def) return 70 end }
end)

-- Mock potion helper
local restore_potion = install_mock("shared/potion_helper_sylvanas", function()
    return {
        HEALTH_POTION_IDS = { 22851 },
        DAMAGE_POTION_IDS = { 12450 },
        try_use_potion = function(ctx, ids) return true end,
    }
end)

-- Mock inventory helper
local restore_inventory = install_mock("common/utility/inventory_helper", function()
    return { has_item = function(id) return true end }
end)

-- Mock offensive dispel
local restore_dispel = install_mock("shared/offensive_dispel_sylvanas", function()
    return { find_best_dispel_target = function() return nil, nil, nil end }
end)

-- Mock NS namespace
local cast_log = {}
local current_time = 1000
local mock_spell_ready = true
local mock_is_item_ready = {}
local function set_item_ready(id, ready)
    mock_is_item_ready[id] = ready
end

_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return "player" end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return current_time end
NS.spell_ready = function(spell, target, opts) return mock_spell_ready end
NS.try_cast = function(spell, target, label, opts)
    cast_log[#cast_log + 1] = { spell = spell, target = target, label = label, opts = opts }
    return true
end
NS.debuff_remains = function(target, debuff_list) return 0 end
NS.get_debuff_stacks = function(target, debuff_list) return 0 end
NS.buff_up = function(unit, buff_list) return false end
NS.buff_remains = function(unit, buff_list) return 0 end
NS.has_player_buff = function(buff_list) return false end
NS.has_target_debuff = function(target, debuff_list) return false end
NS.is_item_ready = function(id) return mock_is_item_ready[id] or false end
NS.use_item_by_id = function(id, target) return true end
NS.is_spell_learned = function(id) return true end
NS.spell_exists = function(spell) return true end
NS.rotation_registry = { register = function() end }
NS.RogueSpells = {}
NS.spell_action = function(ids, name) return { ids = ids, name = name } end
NS.try_interrupt = function(target) return true end
NS.InterruptManager = {
    cast_has_interrupt_window = function(target, settings) return true end,
    humanize_interrupt_elapsed = function(target, settings) return true end,
}

-- Load the subtlety spec
local result = dofile("EaxRotations/classes/rogue/subtlety_sylvanas.lua")
assert_true(result, "subtlety module should load")
local strategies = result.strategies
assert_true(strategies and #strategies > 0, "strategies table should load")

-- Restore require state
restore_spec()
restore_leveling()
restore_potion()
restore_inventory()
restore_dispel()

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
local healthpot_idx = index_of("HealthPotion")
local damagepot_idx = index_of("DamagePotion")
local healthstone_idx = index_of("Healthstone")
local kick_idx = index_of("Kick")
local shiv_idx = index_of("ShivPurge")
local clos_idx = index_of("CloakOfShadows")

assert_true(healthpot_idx < damagepot_idx, "HealthPotion should remain before DamagePotion")
assert_true(damagepot_idx < healthstone_idx, "DamagePotion should remain before Healthstone")
assert_true(healthstone_idx < kick_idx, "Healthstone should remain before Kick")
assert_true(kick_idx < shiv_idx, "Kick should remain before ShivPurge")
assert_true(shiv_idx < clos_idx, "ShivPurge should remain before CloakOfShadows")

-- ============================================================================
-- HealthPotion equivalence
-- ============================================================================
local healthpot = find_strategy("HealthPotion")
local ctx = { in_combat = true, has_health_potion = true, hp = 30, settings = { use_auto_potions = true } }
local st = { hp_pct = 30 }
assert_true(healthpot.matches(ctx, st), "HealthPotion matches in combat with low HP")
ctx.in_combat = false
assert_false(healthpot.matches(ctx, st), "HealthPotion skips out of combat")
ctx.in_combat = true
ctx.has_health_potion = false
assert_false(healthpot.matches(ctx, st), "HealthPotion skips without potion")
ctx.has_health_potion = true
ctx.hp = 80
assert_false(healthpot.matches(ctx, st), "HealthPotion skips at high HP")

-- ============================================================================
-- DamagePotion equivalence
-- ============================================================================
local damagepot = find_strategy("DamagePotion")
ctx = { in_combat = true, has_damage_potion = true, should_burst = true, settings = { use_auto_potions = true } }
st = { hp_pct = 100 }
assert_true(damagepot.matches(ctx, st), "DamagePotion matches in combat burst with potion")
ctx.in_combat = false
assert_false(damagepot.matches(ctx, st), "DamagePotion skips out of combat")
ctx.in_combat = true
ctx.should_burst = false
assert_false(damagepot.matches(ctx, st), "DamagePotion skips without burst")
ctx.should_burst = true
ctx.has_damage_potion = false
assert_false(damagepot.matches(ctx, st), "DamagePotion skips without potion")

-- ============================================================================
-- Healthstone equivalence
-- ============================================================================
local healthstone = find_strategy("Healthstone")
ctx = { in_combat = true, settings = {} }
st = { hp = 20, healthstone_ready = 1 }
assert_true(healthstone.matches(ctx, st), "Healthstone matches in combat with low HP and ready")
ctx.in_combat = false
assert_false(healthstone.matches(ctx, st), "Healthstone skips out of combat")
ctx.in_combat = true
st.healthstone_ready = 0
assert_false(healthstone.matches(ctx, st), "Healthstone skips when not ready")
st.healthstone_ready = 1
st.hp = 80
assert_false(healthstone.matches(ctx, st), "Healthstone skips at high HP")

-- ============================================================================
-- Kick equivalence
-- ============================================================================
local kick = find_strategy("Kick")
ctx = { in_combat = true, target = "target", target_distance = 5, settings = { use_interrupts = true } }
st = { energy = 100, target_distance = 5 }
assert_true(kick.matches(ctx, st), "Kick matches when interrupt conditions are met")
ctx.settings.use_interrupts = false
assert_false(kick.matches(ctx, st), "Kick skips when interrupts disabled")
ctx.settings.use_interrupts = true
st.energy = 0
assert_false(kick.matches(ctx, st), "Kick skips without enough energy")

-- ============================================================================
-- CloakOfShadows equivalence
-- ============================================================================
local clos = find_strategy("CloakOfShadows")
ctx = { settings = { rogue_use_cloak = true, rogue_cloak_hp = 45 } }
st = { hp = 30, is_caster_target = false }
assert_true(clos.matches(ctx, st), "CloakOfShadows matches at low HP")
st.hp = 80
assert_false(clos.matches(ctx, st), "CloakOfShadows skips at high HP")

print("PASS test_subtlety_dsl_priority")
