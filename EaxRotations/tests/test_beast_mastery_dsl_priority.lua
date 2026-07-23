-- test_beast_mastery_dsl_priority.lua â Beast Mastery Hunter DSL priority + equivalence test.
-- WHAT:  verifies full strategy priority order, DSL position checks, and condition
--        equivalence for 6 DSL-converted strategies (KillCommand, BestialWrath,
--        RapidFire, Readiness, MendPet, HuntersMark).
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the seventh DSL adopter (first hunter/pet-management spec).
-- SAFETY: standalone â mocks NS, spec_kit, and shared modules; no game API calls.

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

NS.HunterSpells = {
    ArcaneShot = 3044, AspectOfTheHawk = 13165, AspectOfTheViper = 34074,
    BestialWrath = 19574, CallPet = 883, ExplosiveTrap = 13813,
    FeignDeath = 5384, FreezingTrap = 1499, HuntersMark = 1130,
    Intimidation = 19577, KillCommand = 34026, MendPet = 136,
    MultiShot = 2643, RapidFire = 3045, Readiness = 23989,
    RevivePet = 982, ScorpidSting = 3043, SerpentSting = 1978,
    SteadyShot = 34120, ViperSting = 3034,
}
NS.PLAYER_UNIT = {
    get_health = function() return 100 end,
    get_health_percentage = function() return 100 end,
    is_valid = function() return true end,
    is_dead = function() return false end,
    is_casting = function() return false end,
    get_item_cooldown = function() return nil end,
}
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.cooldown_remains = function() return 0 end
NS.is_spell_learned = function() return true end
NS.has_buff = function() return false end
NS.use_item_by_id = function() return true end
NS.aoe_target_meets = function() return true end
NS.aoe_self_meets = function() return true end
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }

-- Mock spec_kit (uses _setting local to avoid self-reference issues)
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

-- Mock hunter shared modules
local mock_pet = { get_health_percentage = function() return 50 end, is_valid = function() return true end }
package.loaded["shared/hunter_core_sylvanas"] = {
    get_pet = function() return mock_pet end,
    pet_alive = function() return true end,
    pet_hp_pct = function() return 50 end,
    can_cast_instant = function() return true end,
    can_cast_steady = function() return true end,
    should_feign_death = function() return false end,
    sting_remains = function() return 10 end,
    record_mend = function() end,
    record_instant_shot = function() end,
    record_steady_start = function() end,
    get_auto_shot_buffer_ms = function() return 150 end,
}
package.loaded["shared/shot_timer_sylvanas"] = {
    should_delay_cast = function() return false end,
}
package.loaded["shared/targeting_sylvanas"] = {}
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {},
    MANA_POTION_IDS = {},
}
package.loaded["shared/leveling_helpers_sylvanas"] = {
    level_from_context = function(context, default) return default or 70 end,
}
package.loaded["shared/hit_cap_tracker_sylvanas"] = {
    get_hit_cap = function() return { pct_needed = 9, rating_needed = 142 } end,
}
package.loaded["shared/cooldown_planner_sylvanas"] = {
    is_major_offensive_cd_active = function() return false end,
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }
package.loaded["common/utility/inventory_helper"] = { has_item = function() return nil end }

-- Load the real DSL engine and cache it so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the beast mastery spec
local bm = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
local strategies = bm.strategies

-- ============================================================================
-- Priority order verification (35 strategies)
-- ============================================================================
local expected_order = {
    "HealthPotion", "ManaPotion", "Healthstone", "Deterrence",
    "CallPet", "RevivePet", "AspectOfTheHawk_OOC", "AutoAspect",
    "Misdirection", "PetDefensive", "PetPassive", "PetAggressive",
    "MendPet", "HuntersMark", "FreezingTrap", "KillCommand",
    "BestialWrath", "Intimidation", "RapidFire", "Readiness",
    "FeignDeath", "AdaptiveRotation", "MultiShot", "SerpentSting",
    "SerpentStingRefresh", "LevelingArcaneShot", "LevelingSting",
    "ArcaneShot", "SteadyShot", "Trinket", "ConcussiveShot",
    "Volley", "ExplosiveTrap", "RaptorStrike", "HitCapPriority",
}
assert_true(#strategies == #expected_order, "strategy count matches (" .. #strategies .. " vs " .. #expected_order .. ")")
for i = 1, math.min(#strategies, #expected_order) do
    assert_true(strategies[i].name == expected_order[i],
        string.format("priority[%d] = %s (expected %s)", i, strategies[i].name or "?", expected_order[i]))
end

-- DSL position checks â verify the 6 DSL-converted strategies are at expected indices
local dsl_indices = {}
for i = 1, #strategies do dsl_indices[strategies[i].name] = i end
assert_true(dsl_indices["KillCommand"] == 16, "KillCommand at index 16")
assert_true(dsl_indices["BestialWrath"] == 17, "BestialWrath at index 17")
assert_true(dsl_indices["RapidFire"] == 19, "RapidFire at index 19")
assert_true(dsl_indices["Readiness"] == 20, "Readiness at index 20")
assert_true(dsl_indices["MendPet"] == 13, "MendPet at index 13")
assert_true(dsl_indices["HuntersMark"] == 14, "HuntersMark at index 14")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_health_percentage = function() return 100 end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = { use_cooldowns = true, use_readiness = true },
        has_valid_enemy_target = true,
        is_pvp = false,
        is_moving = false,
        combat_time = 50,
        ttd = 999,
        ttd_known = false,
        distance = 30,
        distance_sq = 900,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        is_mounted = false,
        in_combat = true,
        pet_alive = true,
        pet_hp = 100,
        mana_pct = 80,
        hp_pct = 100,
        enemy_count = 1,
        use_cooldowns = true,
        kill_command_ready = true,
        bestial_wrath_ready = true,
        rapid_fire_ready = true,
        rapid_fire_cd = 0,
        readiness_ready = true,
        mend_pet_ready = true,
        hunters_mark_ready = true,
        has_hunters_mark = false,
        major_cd_window = false,
        distance_sq = 900,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- KillCommand: not mounted, in combat, pet alive, spell ready
-- ============================================================================
local idx_kc = 16
-- Positive: all conditions met
assert_true(strategies[idx_kc].matches(make_ctx(), make_state()),
    "KillCommand matches when in combat + pet alive + ready")
-- Negative: mounted
assert_false(strategies[idx_kc].matches(make_ctx(), make_state({ is_mounted = true })),
    "KillCommand skips when mounted")
-- Negative: not in combat
assert_false(strategies[idx_kc].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "KillCommand skips when not in combat")
-- Negative: pet dead
assert_false(strategies[idx_kc].matches(make_ctx(), make_state({ pet_alive = false })),
    "KillCommand skips when pet dead")
-- Negative: not ready
assert_false(strategies[idx_kc].matches(make_ctx(), make_state({ kill_command_ready = false })),
    "KillCommand skips when not ready")

-- ============================================================================
-- BestialWrath: not mounted, cooldowns allowed, boss gate, pet alive,
--               spell ready, TTD gate, CD alignment
-- ============================================================================
local idx_bw = 17
-- Positive: all conditions met (combat_time >= 45)
assert_true(strategies[idx_bw].matches(make_ctx(), make_state()),
    "BestialWrath matches when cooldowns on + boss + pet alive + ready + combat_time >= 45")
-- Positive: with major CD window active
assert_true(strategies[idx_bw].matches(make_ctx(), make_state({ major_cd_window = true })),
    "BestialWrath matches when major CD window active")
-- Negative: cooldowns disabled
assert_false(strategies[idx_bw].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state({ use_cooldowns = false })),
    "BestialWrath skips when cooldowns disabled")
-- Negative: pet dead
assert_false(strategies[idx_bw].matches(make_ctx(), make_state({ pet_alive = false })),
    "BestialWrath skips when pet dead")
-- Negative: not ready
assert_false(strategies[idx_bw].matches(make_ctx(), make_state({ bestial_wrath_ready = false })),
    "BestialWrath skips when not ready")
-- Negative: TTD < 15 (target dying)
assert_false(strategies[idx_bw].matches(make_ctx({ ttd = 10, ttd_known = true }), make_state()),
    "BestialWrath skips when TTD < 15")
-- Negative: no alignment + combat_time < 45
assert_false(strategies[idx_bw].matches(make_ctx({ combat_time = 20 }), make_state({ major_cd_window = false })),
    "BestialWrath skips when no alignment + combat_time < 45")

-- ============================================================================
-- RapidFire: not mounted, cooldowns allowed, spell ready
-- ============================================================================
local idx_rf = 19
-- Positive: all conditions met
assert_true(strategies[idx_rf].matches(make_ctx(), make_state()),
    "RapidFire matches when cooldowns on + in combat + ready")
-- Negative: cooldowns disabled
assert_false(strategies[idx_rf].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state({ use_cooldowns = false })),
    "RapidFire skips when cooldowns disabled")
-- Negative: not in combat
assert_false(strategies[idx_rf].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "RapidFire skips when not in combat")
-- Negative: not ready
assert_false(strategies[idx_rf].matches(make_ctx(), make_state({ rapid_fire_ready = false })),
    "RapidFire skips when not ready")
-- Negative: mounted
assert_false(strategies[idx_rf].matches(make_ctx(), make_state({ is_mounted = true })),
    "RapidFire skips when mounted")

-- ============================================================================
-- Readiness: not mounted, cooldowns allowed, use_readiness setting,
--             spell ready, Rapid Fire CD >= 60s
-- ============================================================================
local idx_rd = 20
-- Positive: Rapid Fire on long cooldown
assert_true(strategies[idx_rd].matches(make_ctx(), make_state({ rapid_fire_cd = 90 })),
    "Readiness matches when cooldowns on + use_readiness + ready + RF CD >= 60")
-- Negative: Rapid Fire CD too short
assert_false(strategies[idx_rd].matches(make_ctx(), make_state({ rapid_fire_cd = 30 })),
    "Readiness skips when Rapid Fire CD < 60")
-- Negative: use_readiness disabled
assert_false(strategies[idx_rd].matches(make_ctx({ settings = { use_cooldowns = true, use_readiness = false } }), make_state()),
    "Readiness skips when use_readiness setting is false")
-- Negative: cooldowns disabled
assert_false(strategies[idx_rd].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state({ use_cooldowns = false })),
    "Readiness skips when cooldowns disabled")
-- Negative: not ready
assert_false(strategies[idx_rd].matches(make_ctx(), make_state({ readiness_ready = false })),
    "Readiness skips when not ready")

-- ============================================================================
-- MendPet: not mounted, in combat, pet alive, pet_hp <= 45, spell ready
-- ============================================================================
local idx_mp = 13
-- Positive: pet HP low
assert_true(strategies[idx_mp].matches(make_ctx(), make_state({ pet_hp = 30 })),
    "MendPet matches when pet_hp <= 45 + in combat + ready")
-- Negative: pet HP too high
assert_false(strategies[idx_mp].matches(make_ctx(), make_state({ pet_hp = 80 })),
    "MendPet skips when pet_hp > 45")
-- Negative: not in combat
assert_false(strategies[idx_mp].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "MendPet skips when not in combat")
-- Negative: pet dead
assert_false(strategies[idx_mp].matches(make_ctx(), make_state({ pet_alive = false })),
    "MendPet skips when pet dead")
-- Negative: not ready
assert_false(strategies[idx_mp].matches(make_ctx(), make_state({ mend_pet_ready = false })),
    "MendPet skips when not ready")
-- Negative: mounted
assert_false(strategies[idx_mp].matches(make_ctx(), make_state({ is_mounted = true })),
    "MendPet skips when mounted")

-- ============================================================================
-- HuntersMark: not broken_api, not mounted, in combat, target exists,
--              debuff not applied, spell ready
-- ============================================================================
local idx_hm = 14
-- Positive: no hunter's mark, in combat, target exists
assert_true(strategies[idx_hm].matches(make_ctx(), make_state()),
    "HuntersMark matches when no mark + in combat + target + ready")
-- Negative: already has hunter's mark
assert_false(strategies[idx_hm].matches(make_ctx(), make_state({ has_hunters_mark = true })),
    "HuntersMark skips when debuff already applied")
-- Negative: not in combat
assert_false(strategies[idx_hm].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "HuntersMark skips when not in combat")
-- Negative: no target (must set nil explicitly â { target = nil } is empty in Lua)
local ctx_no_target = make_ctx()
ctx_no_target.target = nil
assert_false(strategies[idx_hm].matches(ctx_no_target, make_state()),
    "HuntersMark skips without target")
-- Negative: not ready
assert_false(strategies[idx_hm].matches(make_ctx(), make_state({ hunters_mark_ready = false })),
    "HuntersMark skips when not ready")
-- Negative: mounted
assert_false(strategies[idx_hm].matches(make_ctx(), make_state({ is_mounted = true })),
    "HuntersMark skips when mounted")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_beast_mastery_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_beast_mastery_dsl_priority")
