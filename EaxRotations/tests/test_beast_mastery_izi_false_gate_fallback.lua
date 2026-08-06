-- test_beast_mastery_izi_false_gate_fallback.lua — IZI false-gate regression.
-- WHAT:  BM's local spell_ready must NOT hard-block an enemy-target spell when
--        IZI is_castable_to_unit returns false but NS.spell_ready (the engine
--        readiness API every working spec runs on) says ready. Reproduces the
--        live shape: IZI true for self-casts (Rapid Fire fires), false for
--        enemy casts (Steady/Arcane/Kill Command/Hunter's Mark never fire).
-- WHEN:  run as part of the rotation test suite.
-- WHY:   regression guard for the live "BM only auto-attacks" report.
-- SAFETY: fully mocked NS/izi; no game API calls.

local _pass, _fail = 0, 0
local function assert_true(cond, msg)
    if cond then _pass = _pass + 1 else _fail = _fail + 1 print("  FAIL: " .. msg) end
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
NS.cooldown_remains = function() return 0 end
NS.is_spell_learned = function() return true end
NS.try_cast = function() return true end
NS.unit_mana_pct = function() return 100 end
NS.unit_health_pct = function() return 100 end
NS.time_now = function() return 0 end
NS.game_time_ms = function() return 0 end
NS.broken_api_throttled = function() return false end
NS.gate_cooldown_boss_only = function() return true end
NS.has_buff = function() return false end
NS.use_item_by_id = function() return true end
NS.aoe_target_meets = function() return true end
NS.aoe_self_meets = function() return true end
NS.log = function() end
NS.log_warning = function() end
NS.rotation_registry = { register = function() end }

-- Engine readiness verdict (the repo-standard API used by working specs).
-- Controlled per-case: true = engine says ready, false = engine also refuses.
local _engine_ready = true
NS.spell_ready = function() return _engine_ready end

-- IZI SDK: self-casts are castable, enemy casts follow the live-failure shape
-- (_izi_enemy_ok false = IZI false-gates enemy targets while engine says ready).
local _izi_enemy_ok = false
NS.izi = {
    spell = function(ids)
        return {
            is_castable_to_unit = function(_, target, opts)
                if target == NS.PLAYER_UNIT then return true end
                return _izi_enemy_ok
            end,
        }
    end,
}

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

-- Mock hunter shared modules (pet present + alive so pet-gated strategies can
-- reach their readiness gates; pet_alive() itself is covered by
-- test_hunter_core_pet_alive_fallback.lua)
local mock_pet = { get_health_percentage = function() return 100 end, is_valid = function() return true end }
package.loaded["shared/hunter_core_sylvanas"] = {
    get_pet = function() return mock_pet end,
    pet_alive = function() return true end,
    pet_hp_pct = function() return 100 end,
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

-- ============================================================================
-- Context (dispatcher-shaped: me = PLAYER_UNIT, target = enemy)
-- ============================================================================
local ctx = {
    me = NS.PLAYER_UNIT,
    target = {
        is_valid = function() return true end,
        is_dead = function() return false end,
        is_casting = function() return false end,
        get_health_percentage = function() return 100 end,
    },
    in_combat = true,
    combat_time = 50,
    ttd = 999,
    ttd_known = false,
    hp = 100,
    mana_pct = 80,
    enemy_count = 1,
    is_pvp = false,
    is_moving = false,
    distance = 30,
    distance_sq = 900,
    settings = { use_cooldowns = true, use_readiness = true },
    has_valid_enemy_target = true,
    lowest = { unit = nil, hp = 100 },
}

local function rebuild_state()
    local ok, state = pcall(bm.build_state, ctx)
    if not ok then
        print("  FAIL: build_state threw: " .. tostring(state))
        return nil
    end
    return state
end

-- ============================================================================
-- Case A (REGRESSION): live shape — IZI false-gates enemy casts, engine says
-- ready. Enemy-target readiness MUST fall back to NS.spell_ready → ready.
-- ============================================================================
_izi_enemy_ok = false
_engine_ready = true
local state = rebuild_state()
assert_true(state ~= nil, "build_state runs under live shape")
if state then
    assert_true(state.kill_command_ready == true, "kill_command_ready true via engine fallback (live shape)")
    assert_true(state.steady_shot_ready == true, "steady_shot_ready true via engine fallback (live shape)")
    assert_true(state.hunters_mark_ready == true, "hunters_mark_ready true via engine fallback (live shape)")
    assert_true(state.rapid_fire_ready == true, "rapid_fire_ready true via IZI self-cast (live shape)")
    assert_true(state.bestial_wrath_ready == true, "bestial_wrath_ready true via IZI self-cast (live shape)")
    assert_true(state.serpent_sting_ready == true, "serpent_sting_ready true via engine fallback (live shape)")
end

-- KillCommand strategy must now match and reach try_cast (pet alive + ready)
local kc = nil
for i = 1, #bm.strategies do
    if bm.strategies[i].name == "KillCommand" then kc = bm.strategies[i] break end
end
assert_true(kc ~= nil, "KillCommand strategy present")
if kc then
    local ok, m = pcall(kc.matches, ctx, state)
    assert_true(ok and m == true, "KillCommand matches under live shape")
end

-- ============================================================================
-- Case B: both APIs refuse — must stay NOT ready (no fake readiness)
-- ============================================================================
_izi_enemy_ok = false
_engine_ready = false
state = rebuild_state()
assert_true(state ~= nil, "build_state runs when both APIs refuse")
if state then
    assert_true(state.kill_command_ready == false, "kill_command_ready false when both APIs refuse")
    assert_true(state.steady_shot_ready == false, "steady_shot_ready false when both APIs refuse")
end

-- ============================================================================
-- Case C (control): IZI says ready for enemies too — unchanged direct path
-- ============================================================================
_izi_enemy_ok = true
_engine_ready = true
state = rebuild_state()
assert_true(state ~= nil, "build_state runs when IZI says ready")
if state then
    assert_true(state.kill_command_ready == true, "kill_command_ready true via IZI direct (control)")
    assert_true(state.steady_shot_ready == true, "steady_shot_ready true via IZI direct (control)")
end

-- ============================================================================
-- Summary
-- ============================================================================
print(string.format("test_beast_mastery_izi_false_gate_fallback: %d passed, %d failed", _pass, _fail))
if _fail > 0 then
    os.exit(1)
end
print("PASS test_beast_mastery_izi_false_gate_fallback")
