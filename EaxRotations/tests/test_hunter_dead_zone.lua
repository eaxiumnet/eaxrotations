--[[
test_hunter_dead_zone.lua — Hunter dead-zone awareness tests

Scenarios:
  (a) Target at 3yd with ranged min_range=5, no in_dead_zone → ranged shot matches normally
  (b) Target at 3yd with in_dead_zone=true → ranged shot SKIPPED, melee ability matches
  (c) Target at 30yd with in_dead_zone=false → ranged shot matches normally
  (d) in_dead_zone=nil (API unavailable) → ranged shot matches normally (backward compat)
]]

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
_G.EaxRotations = {
    HunterSpells = {
        AspectOfTheHawk = 13165,
        AspectOfTheViper = 34074,
        ArcaneShot = 3044,
        SerpentSting = 1978,
        MendPet = 136,
        CallPet = 883,
        RevivePet = 0,
        KillCommand = 34026,
        SteadyShot = 34120,
        MultiShot = 25294,
        HuntersMark = 14325,
        BestialWrath = 19574,
        RapidFire = 3045,
        Readiness = 23989,
        FeignDeath = 5384,
        FreezingTrap = 1499,
        ExplosiveTrap = 13812,
        ViperSting = 3034,
        ScorpidSting = 14595,
    },
    spell_ready = function(spell, target, opts) return true end,
    spell_action = function(ids, name) return { name = name, ids = ids } end,
    buff_up = function(unit, buff_list) return false end,
    debuff_up = function(unit, debuff_list) return false end,
    try_cast = function(spell_id, target, prefix, opts) return true end,
    has_buff = function(unit, buff_id) return false end,
    is_spell_learned = function(spell_id) return true end,
    use_item_by_id = function(item_id, target) return true end,
    unit_mana_pct = function(unit) return 100 end,
    get_spell_range = function(spell_id)
        if spell_id == 75 then return { min = 5, max = 35 } end  -- Auto Shot
        return nil
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
    GetPlayer = function() return {} end,
    GetFocus = function() return nil end,
}

-- Mock shared modules
package.preload["shared/hunter_core_sylvanas"] = function()
    return {
        get_pet = function() return { is_alive = function() return true end, get_health_percentage = function() return 100 end } end,
        pet_alive = function() return true end,
        pet_hp_pct = function() return 100 end,
        should_viper = function(mana_pct) return mana_pct < 20 end,
        should_hawk = function(mana_pct) return mana_pct >= 20 end,
        can_cast_instant = function(safety, buffer) return true end,
        can_cast_steady = function(buffer) return true end,
        should_feign_death = function(threat, mode) return false end,
        sting_remains = function(target, sting_type) return 0 end,
        record_mend = function() end,
        record_instant_shot = function() end,
        record_steady_start = function() end,
    }
end
package.preload["shared/targeting_sylvanas"] = function()
    return {}
end

local strategies = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- Helper to create base context
local function make_context(overrides)
    local ctx = {
        me = {
            get_health_percentage = function() return 100 end,
            get_mana_percentage = function() return 100 end,
            get_item_cooldown = function(self, item_id) return 0, 0 end,
        },
        target = { get_health_percentage = function() return 100 end },
        in_combat = true,
        is_mounted = false,
        is_moving = false,
        distance = 20,
        target_distance = 20,
        enemy_count = 1,
        mana_pct = 100,
        settings = {
            use_melee = true,
            use_volley = true,
            use_explosive_trap = true,
            aoe_threshold = 3,
            trinket_mode = "off",
            use_cooldowns = true,
        },
    }
    if overrides then
        for k, v in pairs(overrides) do
            if type(k) == "string" then
                ctx[k] = v
            end
        end
    end
    return ctx
end

-- ============================================================================
-- Scenario (a): Target at 3yd with ranged min_range=5, no in_dead_zone flag
-- → Arcane Shot should match (old behavior preserved)
-- ============================================================================

local arcane = find_strategy("ArcaneShot")

local ctx_a = make_context({ distance = 3, target_distance = 3 })
local s_a = {
    in_combat = true,
    arcane_shot_ready = true,
    mana_pct = 100,
    is_mounted = false,
    -- No in_dead_zone field (old code path)
}
assert_true(arcane.matches(ctx_a, s_a), "Scenario (a): Arcane Shot should match without in_dead_zone flag")

-- ============================================================================
-- Scenario (b): Target at 3yd with in_dead_zone=true
-- → Arcane Shot SKIPPED, Raptor Strike matches
-- ============================================================================

-- (b1) Arcane Shot should not match when in_dead_zone is true
local ctx_b = make_context({ distance = 3, target_distance = 3 })
local s_b_dead = {
    in_combat = true,
    arcane_shot_ready = true,
    mana_pct = 100,
    is_mounted = false,
    in_dead_zone = true,
}
assert_false(arcane.matches(ctx_b, s_b_dead), "Scenario (b1): Arcane Shot should NOT match in dead zone")

-- (b2) Raptor Strike should match when in_dead_zone is true (at melee distance)
local raptor = find_strategy("RaptorStrike")
local ctx_b2 = make_context({ distance = 3, target_distance = 3 })
local s_b2_dead = {
    in_combat = true,
    use_melee = true,
    raptor_strike_ready = true,
    is_mounted = false,
    in_dead_zone = true,
    distance_sq = 9,  -- 3yd squared
}
assert_true(raptor.matches(ctx_b2, s_b2_dead), "Scenario (b2): Raptor Strike should match in dead zone")

-- ============================================================================
-- Scenario (c): Target at 30yd with in_dead_zone=false
-- → Arcane Shot matches normally
-- ============================================================================

local ctx_c = make_context({ distance = 30, target_distance = 30 })
local s_c = {
    in_combat = true,
    arcane_shot_ready = true,
    mana_pct = 100,
    is_mounted = false,
    in_dead_zone = false,
}
assert_true(arcane.matches(ctx_c, s_c), "Scenario (c): Arcane Shot should match at normal range")

-- ============================================================================
-- Scenario (d): in_dead_zone=nil (API unavailable, backward compat)
-- → Arcane Shot matches normally
-- ============================================================================

local ctx_d = make_context({ distance = 10, target_distance = 10 })
local s_d = {
    in_combat = true,
    arcane_shot_ready = true,
    mana_pct = 100,
    is_mounted = false,
    in_dead_zone = nil,  -- API unavailable
}
assert_true(arcane.matches(ctx_d, s_d), "Scenario (d): Arcane Shot should match when in_dead_zone is nil (backward compat)")

-- ============================================================================
-- Additional: Multi-Shot also should not match in dead zone
-- ============================================================================

local multi = find_strategy("MultiShot")
local ctx_extra = make_context({ distance = 3, target_distance = 3, enemy_count = 4 })
local s_extra_dead = {
    in_combat = true,
    multi_shot_ready = true,
    multishot_mode = 2,
    enemy_count = 4,
    mana_pct = 100,
    has_breakable_cc_nearby = false,
    is_mounted = false,
    in_dead_zone = true,
}
assert_false(multi.matches(ctx_extra, s_extra_dead), "Multi-Shot should NOT match in dead zone")

-- Additional: Steady Shot also should not match in dead zone
local steady = find_strategy("SteadyShot")
local s_steady_dead = {
    in_combat = true,
    steady_shot_ready = true,
    is_mounted = false,
    is_moving = false,
    in_dead_zone = true,
}
assert_false(steady.matches(ctx_extra, s_steady_dead), "Steady Shot should NOT match in dead zone")

print("PASS test_hunter_dead_zone")
