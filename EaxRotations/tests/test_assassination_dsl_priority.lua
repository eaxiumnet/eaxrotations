-- test_assassination_dsl_priority.lua — Assassination Rogue DSL priority + equivalence test.
-- WHAT:  Verifies that the 8 DSL-converted strategies preserve their priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 24th strategy DSL adopter (assassination rogue).
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

-- Load the assassination spec
local result = dofile("EaxRotations/classes/rogue/assassination_sylvanas.lua")
assert_true(result, "assassination module should load")
local strategies = result.strategies
assert_true(strategies and #strategies > 0, "strategies table should load")

-- Restore require state
restore_spec()
restore_leveling()
restore_potion()
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
local evasion_idx = index_of("EvasionDefense")
local clos_idx = index_of("CloakOfShadows")
local healing_idx = index_of("HealingItem")
local vanish_idx = index_of("VanishReopen")

assert_true(healthpot_idx < damagepot_idx, "HealthPotion should remain before DamagePotion")
assert_true(damagepot_idx < evasion_idx, "DamagePotion should remain before EvasionDefense")
assert_true(evasion_idx < clos_idx, "EvasionDefense should remain before CloakOfShadows")
assert_true(clos_idx < healing_idx, "CloakOfShadows should remain before HealingItem")
assert_true(healing_idx < vanish_idx, "HealingItem should remain before VanishReopen")

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
-- EvasionDefense equivalence
-- ============================================================================
local evasion = find_strategy("EvasionDefense")
ctx = { settings = { assassin_evasion_hp = 25 } }
st = { hp_pct = 20 }
assert_true(evasion.matches(ctx, st), "EvasionDefense matches at low HP")
st.hp_pct = 80
assert_false(evasion.matches(ctx, st), "EvasionDefense skips at high HP")

-- ============================================================================
-- CloakOfShadows equivalence
-- ============================================================================
local clos = find_strategy("CloakOfShadows")
ctx = { settings = { assassin_clos_hp = 30 } }
st = { hp_pct = 20 }
assert_true(clos.matches(ctx, st), "CloakOfShadows matches at low HP")
st.hp_pct = 80
assert_false(clos.matches(ctx, st), "CloakOfShadows skips at high HP")

-- ============================================================================
-- HealingItem equivalence
-- ============================================================================
local healingitem = find_strategy("HealingItem")
ctx = {}
st = { hp_pct = 30, healing_item_id = 12345 }
assert_true(healingitem.matches(ctx, st), "HealingItem matches at low HP with item")
st.healing_item_id = nil
assert_false(healingitem.matches(ctx, st), "HealingItem skips without item")
st.healing_item_id = 12345
st.hp_pct = 80
assert_false(healingitem.matches(ctx, st), "HealingItem skips at high HP")

-- ============================================================================
-- VanishReopen equivalence
-- ============================================================================
local vanish = find_strategy("VanishReopen")
ctx = { in_combat = true, threat_pct = 95 }
st = { hp_pct = 100 }
assert_true(vanish.matches(ctx, st), "VanishReopen matches in combat with high threat")
ctx.in_combat = false
assert_false(vanish.matches(ctx, st), "VanishReopen skips out of combat")
ctx.in_combat = true
ctx.threat_pct = 50
assert_false(vanish.matches(ctx, st), "VanishReopen skips with low threat")

-- ============================================================================
-- AssassinationShivPurge equivalence
-- ============================================================================
local shivpurge = find_strategy("AssassinationShivPurge")
ctx = {
    in_combat = true,
    is_pvp = true,
    in_melee_range = true,
    target = { is_player = function() return true end },
    settings = { use_shiv_purge = true, shiv_purge_pvp_only = false },
}
st = { shiv_ready = true, shiv_purge_name = "Power Word: Shield" }
assert_true(shivpurge.matches(ctx, st), "AssassinationShivPurge matches in PvP melee with purge target")
ctx.in_combat = false
assert_false(shivpurge.matches(ctx, st), "AssassinationShivPurge skips out of combat")
ctx.in_combat = true
ctx.is_pvp = false
assert_false(shivpurge.matches(ctx, st), "AssassinationShivPurge skips non-PvP")
ctx.is_pvp = true
ctx.in_melee_range = false
assert_false(shivpurge.matches(ctx, st), "AssassinationShivPurge skips outside melee")
ctx.in_melee_range = true
st.shiv_purge_name = nil
assert_false(shivpurge.matches(ctx, st), "AssassinationShivPurge skips without purge target")
ctx.shiv_purge_name = "Power Word: Shield"
st.shiv_purge_name = "Power Word: Shield"
ctx.settings = { use_shiv_purge = true, shiv_purge_pvp_only = true }
ctx.target = { is_player = function() return false end }
assert_false(shivpurge.matches(ctx, st), "AssassinationShivPurge skips PvP-only on non-player target")
ctx.target = { is_player = function() return true end }
assert_true(shivpurge.matches(ctx, st), "AssassinationShivPurge matches PvP-only on player target")

-- ============================================================================
-- LevelingSinisterStrike equivalence
-- ============================================================================
local levelingss = find_strategy("LevelingSinisterStrike")
ctx = { target = {}, settings = {} }
st = { energy = 50, has_daggers = false }
assert_true(levelingss.matches(ctx, st), "LevelingSinisterStrike matches with energy and no daggers")
st.energy = 40
assert_false(levelingss.matches(ctx, st), "LevelingSinisterStrike skips with low energy")
st.energy = 50
st.has_daggers = true
assert_false(levelingss.matches(ctx, st), "LevelingSinisterStrike skips when Mutilate/daggers available")

print("PASS test_assassination_dsl_priority")
