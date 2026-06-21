-- ============================================================================
-- Test: Hunter Pet Manager Wiring (HU5)
-- ----------------------------------------------------------------------------
-- Verifies that main_sylvanas.lua calls pet_manager.on_update() every frame
-- when the active class is "hunter". This is the fix for the bug where
-- pet_manager.on_update() was defined in shared/pet_manager_sylvanas.lua but
-- never invoked — pet attack target following and pet spell casting were
-- completely broken.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Spy: capture pet_manager.on_update() calls
-- ============================================================================
local pet_update_calls = {}

local mock_pet_manager = {
    on_update = function(me, target, spec)
        pet_update_calls[#pet_update_calls + 1] = { me = me, target = target, spec = spec }
    end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
    set_defensive = function() return true end,
}

-- ============================================================================
-- Mock player object
-- ============================================================================
local mock_player = {
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power_current = function() return 100 end,
    get_power_max = function() return 100 end,
    get_power_type = function() return 0 end,
    is_alive = function() return true end,
    is_casting = function() return false end,
    is_channeling = function() return false end,
    gcd = function() return 0 end,
    get_distance = function() return 30 end,
    get_distance_sq = function() return 900 end,
    is_in_combat = function() return true end,
    has_buff = function() return false end,
    get_buffs = function() return {} end,
    get_pet = function() return nil end,
    get_guid = function() return "player-guid" end,
    get_class = function() return 3 end,
    get_level = function() return 70 end,
    get_enemies_in_range = function() return {} end,
    get_enemies_in_range_count = function() return 1 end,
    affecting_combat = function() return true end,
    is_moving = function() return false end,
}

local mock_target = {
    get_health_percentage = function() return 100 end,
    get_distance = function() return 30 end,
    get_distance_sq = function() return 900 end,
    is_alive = function() return true end,
    is_casting = function() return false end,
    get_guid = function() return "target-guid" end,
    get_reaction = function() return 2 end,
    is_player = function() return false end,
    get_power_type = function() return 0 end,
}

-- ============================================================================
-- Mock core API (must exist before main_sylvanas.lua loads)
-- ============================================================================
_G.core = {
    time = function() return 1000 end,
    spell_book = {
        get_spell_cooldown = function() return 0, 0 end,
        is_spell_learned = function() return true end,
        get_pet_happiness = function() return { happiness = 3 } end,
    },
    object_manager = {
        get_local_player = function() return mock_player end,
        get_target = function() return mock_target end,
    },
    menu = {
        checkbox = function() return { get = function() return true end } end,
        slider_int = function() return { get = function() return 50 end } end,
        combobox = function() return { get = function() return 1 end } end,
    },
    input = {},
    graphics = {},
}

-- ============================================================================
-- Mock NS namespace (must exist before main_sylvanas.lua loads)
-- ============================================================================
_G.EaxRotations = {
    GetPlayer = function() return mock_player end,
    GetTarget = function() return mock_target end,
    GetPartyMembers = function() return {} end,
    GetFocus = function() return nil end,
    GetPet = function() return nil end,
    mana_pct = function() return 100 end,
    power_current = function() return 100 end,
    get_player_stance = function() return 0 end,
    is_hostile_unit = function() return true end,
    is_pvp_zone = function() return false end,
    is_in_party = function() return false end,
    player_control_locked = function() return false end,
    has_breakable_cc_nearby = function() return false end,
    get_debuff_stacks = function() return 0 end,
    gcd_remains = function() return 0 end,
    get_expansion_max_level = function() return 70 end,
    game_time_ms = function() return 1000000 end,
    rotation_registry = {
        class_config = { class_key = "hunter", default_playstyle = "beast_mastery" },
        playstyles = { beast_mastery = {}, marksmanship = {}, survival = {}, leveling = {} },
        options = {},
    },
    class_middleware = { hunter = {} },
    get_setting = function(key, default)
        if key == "playstyle" then return "beast_mastery" end
        if key == "active_playstyle" then return default end
        return default
    end,
    set_setting = function() end,
    log = function() end,
    log_warning = function() end,
    time_now = function() return 1000 end,
    PLAYER_UNIT = "player",
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    spell_ready = function() return true end,
    try_cast = function() return false end,
    unit_alive = function() return true end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    same_unit = function(a, b) return a == b end,
    not_same_unit = function(a, b) return a ~= b end,
    get_class = function() return "hunter" end,
    get_spec = function() return "beast_mastery" end,
    is_tap_denied = function() return false end,
    is_execute_phase = function() return false end,
    should_refresh_dot = function() return false end,
    broken_api_throttled = function() return false end,
    InterruptManager = nil,
    TalentInference = nil,
    TrinketManager = nil,
    AoEHeal = nil,
    Triage = nil,
    gate_cooldown_boss_only = function() return true end,
    get_pet_hp = function() return 100 end,
    has_pet = function() return false end,
    get_pet = function() return nil end,
    run_unified_strategies = function() return false end,
    safe_field = function(obj, field)
        if obj and type(obj[field]) == "function" then return obj[field] end
        return nil
    end,
}

-- ============================================================================
-- Override require to inject mock pet_manager (before loading main_sylvanas.lua)
-- ============================================================================
local _orig_require = require
function require(name)
    if name == "shared/pet_manager_sylvanas" then
        return mock_pet_manager
    end
    if name == "shared/tick_profiler_sylvanas" then return nil end
    if name == "shared/ooc_manager_sylvanas" then return nil end
    if name == "shared/burst_logic_sylvanas" then return { should_auto_burst = function() return nil end } end
    if name == "shared/combat_forecast_gate_sylvanas" then return {} end
    if name == "common/modules/combat_forecast" then return nil end
    if name == "common/modules/target_selector" then return nil end
    if name == "common/modules/health_prediction" then return nil end
    if name == "common/utility/inventory_helper" then return nil end
    if name == "shared/ttd_tracker_sylvanas" then return nil end
    if name == "shared/ttd_ema_tracker_sylvanas" then return nil end
    if name == "common/buff_db" then return {} end
    if name == "common/utility/pet_handler" then return nil end
    return _orig_require(name)
end

-- ============================================================================
-- Load main_sylvanas.lua (NS.GetPlayer must be set before this)
-- ============================================================================
dofile("EaxRotations/main_sylvanas.lua")

-- ============================================================================
-- Contract 1: on_rotation_update() calls pet_manager.on_update() for hunters
-- ============================================================================
pet_update_calls = {}
_G.EaxRotations.rotation_registry.class_config = { class_key = "hunter", default_playstyle = "beast_mastery" }
local result = _G.EaxRotations.on_rotation_update()
assert_eq(#pet_update_calls, 1, "on_rotation_update: pet_manager.on_update should be called once for hunter")
assert_eq(pet_update_calls[1].spec, "beast_mastery", "on_rotation_update: spec should be 'beast_mastery'")
assert_true(pet_update_calls[1].me ~= nil, "on_rotation_update: me should not be nil")
assert_true(pet_update_calls[1].target ~= nil, "on_rotation_update: target should not be nil")
print("  [ PASS ] on_rotation_update: pet_manager.on_update called for hunter")

-- ============================================================================
-- Contract 2: on_rotation_update_unified() calls pet_manager.on_update() for hunters
-- ============================================================================
pet_update_calls = {}
local result2 = _G.EaxRotations.on_rotation_update_unified()
assert_eq(#pet_update_calls, 1, "on_rotation_update_unified: pet_manager.on_update should be called once for hunter")
assert_eq(pet_update_calls[1].spec, "beast_mastery", "on_rotation_update_unified: spec should be 'beast_mastery'")
print("  [ PASS ] on_rotation_update_unified: pet_manager.on_update called for hunter")

-- ============================================================================
-- Contract 3: Non-hunter class does NOT call pet_manager.on_update()
-- ============================================================================
pet_update_calls = {}
_G.EaxRotations.rotation_registry.class_config = { class_key = "warrior", default_playstyle = "arms" }
_G.EaxRotations.rotation_registry.playstyles.arms = {}
_G.EaxRotations.class_middleware.warrior = {}
local result3 = _G.EaxRotations.on_rotation_update()
assert_eq(#pet_update_calls, 0, "on_rotation_update: pet_manager.on_update should NOT be called for warrior")
print("  [ PASS ] on_rotation_update: pet_manager.on_update NOT called for warrior")

-- ============================================================================
-- Contract 4: Non-hunter class does NOT call pet_manager.on_update() (unified)
-- ============================================================================
pet_update_calls = {}
local result4 = _G.EaxRotations.on_rotation_update_unified()
assert_eq(#pet_update_calls, 0, "on_rotation_update_unified: pet_manager.on_update should NOT be called for warrior")
print("  [ PASS ] on_rotation_update_unified: pet_manager.on_update NOT called for warrior")

print("PASS test_hunter_pet_manager_wiring")
