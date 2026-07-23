-- test_affliction_dsl_priority.lua — Affliction Warlock DSL priority + equivalence test.
-- WHAT:  Verifies that the 6 DSL-converted strategies preserve their priority order
--        and behave equivalently to the original imperative match functions.
-- WHEN:  Run by the rotation test suite.
-- WHY:   Regression guard for the 21st strategy DSL adopter (affliction warlock).
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

-- Mock AoE hit volume helper
local restore_aoe = install_mock("shared/aoe_hit_volume_sylvanas", function()
    return { install = function() end }
end)

-- Mock potion helper
local restore_potion = install_mock("shared/potion_helper_sylvanas", function()
    return {
        try_use_potion = function() return true end,
        DAMAGE_POTION_IDS = {},
    }
end)

-- Mock DoT TTD gating
local restore_dotttd = install_mock("shared/dot_ttd_gating_sylvanas", function()
    return {
        should_skip_dot = function() return false end,
        DOT_DURATIONS = {},
    }
end)

-- Mock buff manager helper
local restore_buffhelper = install_mock("shared/buff_manager_helper_sylvanas", function()
    return { get_all_debuffs = function() return {} end }
end)

-- Mock profiler helper
local restore_profiler = install_mock("shared/profiler_helper_sylvanas", function()
    return { start = function() end, stop = function() end }
end)

-- Mock target selector helper (optional)
local restore_ts = install_mock("shared/ts_helper_sylvanas", function()
    return nil
end)

-- Mock cooldown planner (optional)
local restore_planner = install_mock("shared/cooldown_planner_sylvanas", function()
    return {}
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
        local v = s[key]
        if v == nil then return default end
        return v
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
    has_player_buff = function(ids) return false end,
    log = function() end,
    log_warning = function() end,
    time_now = function() return 1000 end,
    GetPlayer = function() return "player" end,
    rotation_registry = { register = function() end },
    is_item_ready = function(id) return true end,
    use_item_by_id = function(id) return true end,
    has_item = function(id) return false end,
}

local result = dofile("EaxRotations/classes/warlock/affliction_sylvanas.lua")
assert_true(result, "affliction module should load")
local strategies = result.strategies
assert_true(strategies and #strategies > 0, "strategies table should load")

-- Restore require state so later tests in the same runner process load the real modules.
restore_pet()
restore_aoe()
restore_potion()
restore_dotttd()
restore_buffhelper()
restore_profiler()
restore_ts()
restore_planner()
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
local petdef_idx = index_of("PetDefensive")
local petpass_idx = index_of("PetPassive")
local petagg_idx = index_of("PetAggressive")
local deathcoil_idx = index_of("DeathCoilSurvival")
local healthstone_idx = index_of("Healthstone")
local nightfall_idx = index_of("NightfallProc")

assert_true(petdef_idx < petpass_idx, "PetDefensive should remain before PetPassive")
assert_true(petpass_idx < petagg_idx, "PetPassive should remain before PetAggressive")
assert_true(petagg_idx < deathcoil_idx, "PetAggressive should remain before DeathCoilSurvival")
assert_true(deathcoil_idx < healthstone_idx, "DeathCoilSurvival should remain before Healthstone")
assert_true(healthstone_idx < nightfall_idx, "Healthstone should remain before NightfallProc")

-- ============================================================================
-- PetDefensive equivalence
-- ============================================================================
local petdef = find_strategy("PetDefensive")
local ctx_pet = { in_combat = true }
local st_petdef = { pet_alive = true, pet_health = 20 }
local st_petdef_high = { pet_alive = true, pet_health = 50 }
assert_true(petdef.matches(ctx_pet, st_petdef), "PetDefensive matches when pet HP low and in combat")
assert_false(petdef.matches(ctx_pet, st_petdef_high), "PetDefensive does not match when pet HP high")

-- ============================================================================
-- PetPassive equivalence
-- ============================================================================
local petpass = find_strategy("PetPassive")
local ctx_pass = { in_combat = true, hp = 20 }
local ctx_pass_high = { in_combat = true, hp = 80 }
local st_petalive = { pet_alive = true }
assert_true(petpass.matches(ctx_pass, st_petalive), "PetPassive matches when player HP low, pet alive, and in combat")
assert_false(petpass.matches(ctx_pass_high, st_petalive), "PetPassive does not match when player HP high")

-- ============================================================================
-- PetAggressive equivalence
-- ============================================================================
local petagg = find_strategy("PetAggressive")
local st_petagg = { pet_alive = true, pet_health = 80 }
local st_petagg_low = { pet_alive = true, pet_health = 40 }
assert_true(petagg.matches(ctx_pet, st_petagg), "PetAggressive matches when pet HP healthy and in combat")
assert_false(petagg.matches(ctx_pet, st_petagg_low), "PetAggressive does not match when pet HP low")

-- ============================================================================
-- DeathCoilSurvival equivalence
-- ============================================================================
local deathcoil = find_strategy("DeathCoilSurvival")
local ctx_target = { has_valid_enemy_target = true, target = {} }
local st_dc = { hp_pct = 25 }
local st_dc_high = { hp_pct = 80 }
assert_true(deathcoil.matches(ctx_target, st_dc), "DeathCoilSurvival matches when HP low and target valid")
assert_false(deathcoil.matches(ctx_target, st_dc_high), "DeathCoilSurvival does not match when HP high")

-- ============================================================================
-- Healthstone equivalence
-- ============================================================================
local healthstone = find_strategy("Healthstone")
local ctx_hs = { hp = 30, is_casting = false, settings = { use_auto_consumables = true, use_healthstones = true, healthstone_hp = 40 } }
local st_hs = { healthstone_ready = true, healthstone_id = 123 }
local ctx_hs_disabled = { hp = 30, is_casting = false, settings = { use_auto_consumables = false, use_healthstones = true, healthstone_hp = 40 } }
local ctx_hs_casting = { hp = 30, is_casting = true, settings = { use_auto_consumables = true, use_healthstones = true, healthstone_hp = 40 } }
assert_true(healthstone.matches(ctx_hs, st_hs), "Healthstone matches when enabled, HP below threshold, not casting, and ready")
assert_false(healthstone.matches(ctx_hs_disabled, st_hs), "Healthstone does not match when auto consumables disabled")
assert_false(healthstone.matches(ctx_hs_casting, st_hs), "Healthstone does not match while casting")

-- ============================================================================
-- NightfallProc equivalence
-- ============================================================================
local nightfall = find_strategy("NightfallProc")
local ctx_nf = { has_valid_enemy_target = true, target = {} }
local st_nf = { nightfall_active = true }
local st_nf_inactive = { nightfall_active = false }
assert_true(nightfall.matches(ctx_nf, st_nf), "NightfallProc matches when Nightfall active and target valid")
assert_false(nightfall.matches(ctx_nf, st_nf_inactive), "NightfallProc does not match when Nightfall inactive")

print("PASS test_affliction_dsl_priority")
