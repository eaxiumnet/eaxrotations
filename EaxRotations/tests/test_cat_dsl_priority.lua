-- test_cat_dsl_priority.lua — Feral Cat DSL priority + equivalence test.
-- WHAT:  Verifies that the 8 DSL-converted strategies preserve their priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 23rd strategy DSL adopter (feral cat druid).
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

-- Mock leveling_helpers
local restore_leveling = install_mock("shared/leveling_helpers_sylvanas", function()
    return { is_low_level = function(level) return false end }
end)

-- Mock energy tick tracker
local restore_energy = install_mock("shared/energy_tick_tracker_sylvanas", function()
    return {
        new_state = function() return {} end,
        estimate_next_tick = function(state, now) return 2.0 end,
        predicted_energy = function(state, energy, interval) return math.min(100, (energy or 0) + 20) end,
    }
end)

-- Mock potion helper
local last_potion_args = nil
local restore_potion = install_mock("shared/potion_helper_sylvanas", function()
    return {
        HEALTH_POTION_IDS = { 22851 },
        MANA_POTION_IDS = { 28100 },
        try_use_potion = function(ctx, ids)
            last_potion_args = { ctx = ctx, ids = ids }
            return true
        end,
    }
end)

-- Mock engineering / combat_mode / snapshot (optional)
local restore_engineering = install_mock("shared/engineering_helper_sylvanas", function() return nil end)
local restore_combat_mode = install_mock("shared/combat_mode_sylvanas", function() return nil end)
local restore_snapshot = install_mock("shared/snapshot_sylvanas", function()
    return {
        should_upgrade = function(current_ap, snapshotted_ap, remains, refresh_window, ratio, opts)
            if remains <= 0 then return true end
            if remains <= refresh_window then return true end
            if snapshotted_ap <= 0 then return false end
            return current_ap >= snapshotted_ap * ratio and remains <= refresh_window + 1.5
        end,
    }
end)

-- Mock NS namespace
local cast_log = {}
local current_time = 1000
local mock_has_form = nil
local mock_buff_up = nil
local mock_debuff_remains = 0
local mock_spell_ready = true
_G.EaxRotations = _G.EaxRotations or {}
local NS = _G.EaxRotations
NS.log = function() end
NS.log_warning = function() end
NS.GetPlayer = function() return { get_health = function() return 100 end } end
NS.PLAYER_UNIT = "player"
NS.time_now = function() return current_time end
NS.spell_ready = function(spell, target, opts) return mock_spell_ready end
NS.try_cast = function(spell, target, label, opts)
    cast_log[#cast_log + 1] = { spell = spell, target = target, label = label, opts = opts }
    return true
end
NS.debuff_remains = function(target, debuff_list) return mock_debuff_remains end
NS.get_debuff_stacks = function(target, debuff_list) return 0 end
NS.buff_up = function(unit, buff_list)
    if mock_buff_up then return mock_buff_up(unit, buff_list) end
    return false
end
NS.buff_remains = function(unit, buff_list) return 0 end
NS.has_form = function(form) return mock_has_form == form end
NS.get_combo_points = function(target) return 0 end
NS.power_current = function(ptype) return 100 end
NS.power_pct = function(ptype) return 100 end
NS.health_pct = function(unit) return 100 end
NS.energy = function() return 100 end
NS.spell_exists = function(spell) return true end
NS.is_behind_target = function(target) return false end
NS.rotation_registry = { register = function() end }
NS.aoe_target_meets = function(threshold, radius, target, context, state) return threshold <= (state and state.enemy_count or 1) end
NS.DruidSpells = {}
NS.spell_action = function(ids, name) return { ids = ids, name = name } end

-- Load the cat spec
local result = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
assert_true(result, "cat module should load")
local strategies = result.strategies
assert_true(strategies and #strategies > 0, "strategies table should load")

-- Restore require state so later tests in the same runner process load the real modules.
restore_spec()
restore_leveling()
restore_energy()
restore_potion()
restore_engineering()
restore_combat_mode()
restore_snapshot()

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
local manapot_idx = index_of("ManaPotion")
local removecurse_idx = index_of("RemoveCurse")
local barkskin_idx = index_of("Barkskin")
local dash_idx = index_of("Dash")
local tigersfury_idx = index_of("TigersFury")

assert_true(healthpot_idx < manapot_idx, "HealthPotion should remain before ManaPotion")
assert_true(manapot_idx < removecurse_idx, "ManaPotion should remain before RemoveCurse")
assert_true(removecurse_idx < barkskin_idx, "RemoveCurse should remain before Barkskin")
assert_true(barkskin_idx < dash_idx, "Barkskin should remain before Dash")
assert_true(dash_idx < tigersfury_idx, "Dash should remain before TigersFury")

-- ============================================================================
-- Prowl equivalence
-- ============================================================================
local prowl = find_strategy("Prowl")
local ctx_prowl = { settings = {} }
local st_prowl = { in_combat = false, is_stealthed = false, target = {}, target_range = 10, energy = 100, combo_points = 0, enemy_count = 1, target_hp = 100, target_ttd = 999 }
assert_true(prowl.matches(ctx_prowl, st_prowl), "Prowl matches out of combat, not stealthed, close target")
st_prowl.in_combat = true
assert_false(prowl.matches(ctx_prowl, st_prowl), "Prowl skips in combat")
st_prowl.in_combat = false
st_prowl.is_stealthed = true
assert_false(prowl.matches(ctx_prowl, st_prowl), "Prowl skips when already stealthed")
st_prowl.is_stealthed = false
st_prowl.target_range = 25
assert_false(prowl.matches(ctx_prowl, st_prowl), "Prowl skips when target is far away")
st_prowl.target_range = 10
assert_true(prowl.matches(ctx_prowl, st_prowl), "Prowl matches again after reset")
st_prowl.target = nil
assert_true(prowl.matches(ctx_prowl, st_prowl), "Prowl matches when no target is present")

-- ============================================================================
-- HealthPotion equivalence
-- ============================================================================
local healthpot = find_strategy("HealthPotion")
local ctx_hp = { in_combat = true, has_health_potion = true, hp = 30, settings = { use_auto_potions = true } }
local st_hp = { mana_pct = 100, energy = 100, combo_points = 0, enemy_count = 1, target_hp = 100, target_ttd = 999, target_range = 5, hp = 30 }
assert_true(healthpot.matches(ctx_hp, st_hp), "HealthPotion matches in combat with low HP")
ctx_hp.in_combat = false
assert_false(healthpot.matches(ctx_hp, st_hp), "HealthPotion skips out of combat")
ctx_hp.in_combat = true
ctx_hp.has_health_potion = false
assert_false(healthpot.matches(ctx_hp, st_hp), "HealthPotion skips without potion")
ctx_hp.has_health_potion = true
st_hp.hp = 80
assert_false(healthpot.matches(ctx_hp, st_hp), "HealthPotion skips at high HP")

-- ============================================================================
-- ManaPotion equivalence
-- ============================================================================
local manapot = find_strategy("ManaPotion")
local ctx_mp = { in_combat = true, has_mana_potion = true, settings = { use_auto_potions = true } }
local st_mp = { mana_pct = 15, hp = 100, energy = 100, combo_points = 0, enemy_count = 1, target_hp = 100, target_ttd = 999, target_range = 5 }
assert_true(manapot.matches(ctx_mp, st_mp), "ManaPotion matches in combat with low mana")
ctx_mp.in_combat = false
assert_false(manapot.matches(ctx_mp, st_mp), "ManaPotion skips out of combat")
ctx_mp.in_combat = true
ctx_mp.has_mana_potion = false
assert_false(manapot.matches(ctx_mp, st_mp), "ManaPotion skips without potion")
ctx_mp.has_mana_potion = true
st_mp.mana_pct = 80
assert_false(manapot.matches(ctx_mp, st_mp), "ManaPotion skips at high mana")

-- ============================================================================
-- RemoveCurse equivalence
-- ============================================================================
local removecurse = find_strategy("RemoveCurse")
local ctx_rc = { settings = { cat_auto_dispel = true } }
local st_rc = { hp = 100, energy = 100, combo_points = 0, enemy_count = 1, target_hp = 100, target_ttd = 999, target_range = 5 }
assert_true(removecurse.matches(ctx_rc, st_rc), "RemoveCurse matches when enabled and spell ready")
ctx_rc.settings.cat_auto_dispel = false
assert_false(removecurse.matches(ctx_rc, st_rc), "RemoveCurse skips when disabled")
ctx_rc.settings.cat_auto_dispel = true
mock_spell_ready = false
assert_false(removecurse.matches(ctx_rc, st_rc), "RemoveCurse skips when spell not ready")
mock_spell_ready = true

-- ============================================================================
-- Barkskin equivalence
-- ============================================================================
local barkskin = find_strategy("Barkskin")
local ctx_bs = { settings = { cat_barkskin_hp = 85 } }
local st_bs = { hp = 50, has_barkskin = false, energy = 100, combo_points = 0, enemy_count = 1, target_hp = 100, target_ttd = 999, target_range = 5 }
assert_true(barkskin.matches(ctx_bs, st_bs), "Barkskin matches at low HP without buff")
st_bs.has_barkskin = true
assert_false(barkskin.matches(ctx_bs, st_bs), "Barkskin skips when already active")
st_bs.has_barkskin = false
st_bs.hp = 90
assert_false(barkskin.matches(ctx_bs, st_bs), "Barkskin skips at high HP")

-- ============================================================================
-- Dash equivalence
-- ============================================================================
local dash = find_strategy("Dash")
local ctx_dash = { settings = {} }
local st_dash = { target = {}, has_dash = false, target_range = 15, is_pvp = true, energy = 100, combo_points = 0, enemy_count = 1, target_hp = 100, target_ttd = 999 }
assert_true(dash.matches(ctx_dash, st_dash), "Dash matches when missing and target at mid range in PvP")
st_dash.has_dash = true
assert_false(dash.matches(ctx_dash, st_dash), "Dash skips when already active")
st_dash.has_dash = false
st_dash.target_range = 3
assert_false(dash.matches(ctx_dash, st_dash), "Dash skips when target within melee range")
st_dash.target_range = 30
assert_false(dash.matches(ctx_dash, st_dash), "Dash skips when target too far")
st_dash.target_range = 15
st_dash.is_pvp = false
assert_false(dash.matches(ctx_dash, st_dash), "Dash skips in PvE when target closer than travel form range")

-- ============================================================================
-- TigersFury equivalence
-- ============================================================================
local tigersfury = find_strategy("TigersFury")
local ctx_tf = { settings = {} }
local st_tf = { has_tigers_fury = false, target_ttd = 20, energy = 30, combo_points = 0, next_tick_in = 1.0, energy = 30 }
assert_true(tigersfury.matches(ctx_tf, st_tf), "TigersFury matches when energy can be gained")
st_tf.has_tigers_fury = true
assert_false(tigersfury.matches(ctx_tf, st_tf), "TigersFury skips when already active")
st_tf.has_tigers_fury = false
st_tf.target_ttd = 3
assert_false(tigersfury.matches(ctx_tf, st_tf), "TigersFury skips when target dies soon")
st_tf.target_ttd = 20
st_tf.energy = 100
st_tf.combo_points = 5
assert_false(tigersfury.matches(ctx_tf, st_tf), "TigersFury skips when energy capped with Rip available")

print("PASS test_cat_dsl_priority")
