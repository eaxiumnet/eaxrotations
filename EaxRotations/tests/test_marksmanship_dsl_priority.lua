-- test_marksmanship_dsl_priority.lua â Marksmanship Hunter DSL priority + equivalence test.
-- WHAT:  verifies that 6 DSL-converted strategies are present, preserve priority
--        order, and behave equivalently to the original imperative logic.
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the 20th DSL adopter (marksmanship hunter/ranged-DPS spec).
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

NS.HunterSpells = {}
NS.PLAYER_UNIT = { get_health = function() return 100 end, is_valid = function() return true end }
NS.GetPlayer = function() return NS.PLAYER_UNIT end
NS.GetPet = function() return nil end
NS.buff_up = function() return false end
NS.debuff_up = function() return false end
NS.debuff_remains = function() return 0 end
NS.has_buff = function() return false end
NS.buff_stacks = function() return 0 end
NS.buff_remains = function() return 0 end
NS.spell_ready = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.unit_distance = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.not_same_unit = function() return true end
NS.same_unit = function(a, b) return a == b end
NS.is_tank_unit = function() return false end
NS.GetPartyMembers = function() return {} end
NS.GetEnemiesCount = function() return 0 end
NS.GetEnemiesInRange = function() return {} end
NS.cooldown_remains = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.log = function() end
NS.rotation_registry = { register = function() end }

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
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}
package.loaded["shared/shot_timer_sylvanas"] = {
    can_cast_steady = function() return true end,
    ms_until_auto = function() return 9999 end,
    should_delay_cast = function() return false end,
    get_auto_shot_buffer_ms = function() return 150 end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {},
    MANA_POTION_IDS = {},
}
package.loaded["shared/spell_queue_helper_sylvanas"] = {
    queue_spell_target = function() return false end,
}
package.loaded["common/utility/inventory_helper"] = { has_item = function() return nil end }

-- Load the real DSL engine so the spec file's require() picks it up
package.loaded["shared/strategy_dsl_sylvanas"] = dofile("EaxRotations/shared/strategy_dsl_sylvanas.lua")

-- Load the marksmanship spec
local mm = dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua")
local strategies = mm.strategies

-- ============================================================================
-- Priority order verification
-- ============================================================================
local dsl_names = { MendPet = true, HuntersMark = true, RapidFire = true,
                    KillCommand = true, FeignDeath = true, FreezingTrap = true }
local found = {}
for i = 1, #strategies do
    if dsl_names[strategies[i].name] then
        found[strategies[i].name] = i
    end
end
for name, _ in pairs(dsl_names) do
    assert_true(found[name] ~= nil, name .. " is present in strategies")
end

-- Verify expected priority positions
assert_true(found.MendPet == 4, "MendPet at priority index 4")
assert_true(found.FreezingTrap == 13, "FreezingTrap at priority index 13")
assert_true(found.HuntersMark == 14, "HuntersMark at priority index 14")
assert_true(found.RapidFire == 15, "RapidFire at priority index 15")
assert_true(found.KillCommand == 21, "KillCommand at priority index 21")
assert_true(found.FeignDeath == 22, "FeignDeath at priority index 22")

-- ============================================================================
-- Mock context + state helpers
-- ============================================================================
local function make_ctx(overrides)
    local ctx = {
        me = NS.PLAYER_UNIT,
        target = { is_valid = function() return true end, is_dead = function() return false end,
                   is_casting = function() return false end, get_creature_type = function() return nil end },
        in_combat = true,
        hp = 100,
        mana_pct = 80,
        settings = {},
        has_valid_enemy_target = true,
        is_moving = false,
        enemies_count = 1,
    }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function make_state(overrides)
    local s = {
        pet_alive = true,
        pet_hp_pct = 100,
        mend_pet_ready = true,
        has_hunters_mark = false,
        hunters_mark_ready = true,
        rapid_fire_ready = true,
        kill_command_ready = true,
        feign_death_ready = true,
        freezing_trap_ready = true,
        in_combat = true,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- ============================================================================
-- MendPet: pet alive and HP low
-- ============================================================================
local idx_mend = found.MendPet
assert_true(strategies[idx_mend].matches(make_ctx(), make_state({ pet_hp_pct = 30 })),
    "MendPet matches when pet HP low and spell ready")
assert_false(strategies[idx_mend].matches(make_ctx(), make_state({ pet_hp_pct = 80 })),
    "MendPet skips when pet HP high")
assert_false(strategies[idx_mend].matches(make_ctx(), make_state({ pet_alive = false })),
    "MendPet skips when pet not alive")
assert_false(strategies[idx_mend].matches(make_ctx(), make_state({ mend_pet_ready = false })),
    "MendPet skips when spell not ready")

-- ============================================================================
-- HuntersMark: mark missing and ready
-- ============================================================================
local idx_hm = found.HuntersMark
assert_true(strategies[idx_hm].matches(make_ctx(), make_state()),
    "HuntersMark matches when mark missing and ready")
assert_false(strategies[idx_hm].matches(make_ctx(), make_state({ has_hunters_mark = true })),
    "HuntersMark skips when already marked")
assert_false(strategies[idx_hm].matches(make_ctx(), make_state({ hunters_mark_ready = false })),
    "HuntersMark skips when spell not ready")

-- ============================================================================
-- RapidFire: cooldown setting, in combat, ready, TTD gate
-- ============================================================================
local idx_rf = found.RapidFire
assert_true(strategies[idx_rf].matches(make_ctx(), make_state()),
    "RapidFire matches when cooldowns on + in combat + ready")
assert_false(strategies[idx_rf].matches(make_ctx({ settings = { use_cooldowns = false } }), make_state()),
    "RapidFire skips when cooldowns disabled")
assert_false(strategies[idx_rf].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "RapidFire skips when not in combat")
assert_false(strategies[idx_rf].matches(make_ctx(), make_state({ rapid_fire_ready = false })),
    "RapidFire skips when spell not ready")
assert_false(strategies[idx_rf].matches(make_ctx({ ttd = 10, ttd_known = true }), make_state()),
    "RapidFire skips when TTD < 15")

-- ============================================================================
-- KillCommand: in combat, pet alive, ready
-- ============================================================================
local idx_kc = found.KillCommand
assert_true(strategies[idx_kc].matches(make_ctx(), make_state()),
    "KillCommand matches when in combat with pet and ready")
assert_false(strategies[idx_kc].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "KillCommand skips when not in combat")
assert_false(strategies[idx_kc].matches(make_ctx(), make_state({ pet_alive = false })),
    "KillCommand skips when pet not alive")
assert_false(strategies[idx_kc].matches(make_ctx(), make_state({ kill_command_ready = false })),
    "KillCommand skips when spell not ready")

-- ============================================================================
-- FeignDeath: in combat, ready
-- ============================================================================
local idx_feign = found.FeignDeath
assert_true(strategies[idx_feign].matches(make_ctx(), make_state()),
    "FeignDeath matches when in combat and ready")
assert_false(strategies[idx_feign].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "FeignDeath skips when not in combat")
assert_false(strategies[idx_feign].matches(make_ctx(), make_state({ feign_death_ready = false })),
    "FeignDeath skips when spell not ready")

-- ============================================================================
-- FreezingTrap: out of combat, ready
-- ============================================================================
local idx_freeze = found.FreezingTrap
assert_true(strategies[idx_freeze].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false })),
    "FreezingTrap matches when out of combat and ready")
assert_false(strategies[idx_freeze].matches(make_ctx(), make_state({ in_combat = true })),
    "FreezingTrap skips when in combat")
assert_false(strategies[idx_freeze].matches(make_ctx({ in_combat = false }), make_state({ in_combat = false, freezing_trap_ready = false })),
    "FreezingTrap skips when spell not ready")

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_marksmanship_dsl_priority: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_marksmanship_dsl_priority")
