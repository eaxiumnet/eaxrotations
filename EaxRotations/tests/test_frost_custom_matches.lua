-- test_frost_custom_matches.lua -- Frost custom match validation tests.
-- WHAT:  Frost custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for frost_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
_G.EaxRotations = {
    MageSpells = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_ready = function(spell, me)
        return false  -- Ice Block is on cooldown for Cold Snap tests
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
    debuff_up = function(unit, ids)
        if unit and unit.has_debuff then
            for _, id in ipairs(ids or {}) do
                if type(id) ~= "number" then
                    error("debuff_up expects flat id list, got nested table")
                end
                local ok, has = pcall(function() return unit:has_debuff(id) end)
                if ok and has then return true end
            end
        end
        return false
    end,
}

local result = dofile("EaxRotations/classes/mage/frost_sylvanas.lua")
local strategies = result.strategies
assert_true(strategies, "strategies table should load")

-- Helper to find strategy by name
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Ice Block: only when HP <= 20
-- ============================================================================

local ice_block = find_strategy("IceBlock")

-- High HP -> should NOT match
action_calls = {}
local ctx_high_hp = {
    me = {
        get_health_percentage = function() return 80 end,
    },
}
assert_false(ice_block.matches(ctx_high_hp), "IceBlock should not match when HP > 20")
assert_eq(#action_calls, 0, "action_matches should not be called when HP > 20")

-- Low HP -> should match
action_calls = {}
local ctx_low_hp = {
    me = {
        get_health_percentage = function() return 15 end,
    },
}
assert_true(ice_block.matches(ctx_low_hp), "IceBlock should match when HP <= 20")

-- No me -> should return false
assert_false(ice_block.matches({}), "IceBlock should not match when me is nil")

-- ============================================================================
-- Cold Snap: only when Ice Block is on cooldown AND HP <= 35
-- ============================================================================

local cold_snap = find_strategy("ColdSnap")

-- High HP -> should NOT match
action_calls = {}
local ctx_cs_high_hp = {
    me = {
        get_health_percentage = function() return 50 end,
    },
}
assert_false(cold_snap.matches(ctx_cs_high_hp), "ColdSnap should not match when HP > 35")
assert_eq(#action_calls, 0, "action_matches should not be called when HP > 35")

-- Low HP, Ice Block not ready -> should match
action_calls = {}
local ctx_cs_low_hp = {
    me = {
        get_health_percentage = function() return 25 end,
    },
}
assert_true(cold_snap.matches(ctx_cs_low_hp), "ColdSnap should match when HP <= 35 and Ice Block not ready")

-- No me -> should return false
assert_false(cold_snap.matches({}), "ColdSnap should not match when me is nil")

-- ============================================================================
-- Water Elemental: should NOT match when pet already active
-- ============================================================================

local water_ele = find_strategy("WaterElemental")

-- Pet already active -> should NOT match
action_calls = {}
assert_false(water_ele.matches({
    in_combat = true, ttd_known = true, ttd = 60, settings = { use_cooldowns = true },
}, {
    has_water_elemental = true, water_elemental_ready = true, in_combat = true,
}), "WaterElemental should not match when pet already active")

-- No pet, in combat, TTD sufficient -> should match
action_calls = {}
assert_true(water_ele.matches({
    in_combat = true, ttd_known = true, ttd = 60, settings = { use_cooldowns = true },
}, {
    has_water_elemental = false, water_elemental_ready = true, in_combat = true,
}), "WaterElemental should match when no pet and in combat")

-- ============================================================================
-- Cold Snap: DPS path (double-pet / double-IV)
-- ============================================================================

-- DPS: no pet, WE on CD -> should match (even with high HP)
action_calls = {}
local ctx_cs_dps_pet = {
    me = { get_health_percentage = function() return 80 end },
}
assert_true(cold_snap.matches(ctx_cs_dps_pet, {
    in_combat = true, has_water_elemental = false, water_elemental_ready = false, icy_veins_ready = true,
}), "ColdSnap should match for DPS double-pet even at high HP")

-- DPS: IV on CD -> should match (even with high HP)
action_calls = {}
local ctx_cs_dps_iv = {
    me = { get_health_percentage = function() return 80 end },
}
assert_true(cold_snap.matches(ctx_cs_dps_iv, {
    in_combat = true, has_water_elemental = true, water_elemental_ready = true, icy_veins_ready = false,
}), "ColdSnap should match for DPS double-IV even at high HP")

-- DPS: not in combat -> should NOT match
action_calls = {}
assert_false(cold_snap.matches(ctx_cs_dps_pet, {
    in_combat = false, has_water_elemental = false, water_elemental_ready = false, icy_veins_ready = true,
}), "ColdSnap should not match DPS path when not in combat")

-- ============================================================================
-- Frost Nova: only when target is not rooted and within 10 yards
-- ============================================================================

local frost_nova = find_strategy("FrostNova")

-- Target rooted -> should NOT match
action_calls = {}
local ctx_rooted = {
    target = {
        has_debuff = function() return true end,
    },
    me = {
        get_distance = function() return 5 end,
    },
}
assert_false(frost_nova.matches(ctx_rooted), "FrostNova should not match when target is rooted")
assert_eq(#action_calls, 0, "action_matches should not be called when target rooted")

-- Target far away -> should NOT match
action_calls = {}
local ctx_far = {
    target = {
        has_debuff = function() return false end,
    },
    me = {
        get_distance = function() return 15 end,
    },
}
assert_false(frost_nova.matches(ctx_far), "FrostNova should not match when target > 10 yards")
assert_eq(#action_calls, 0, "action_matches should not be called when target far away")

-- Target close and not rooted -> should match
action_calls = {}
local ctx_close = {
    target = {
        has_debuff = function() return false end,
    },
    me = {
        get_distance = function() return 5 end,
    },
}
assert_true(frost_nova.matches(ctx_close), "FrostNova should match when target is close and not rooted")

-- No target -> should return false
assert_false(frost_nova.matches({}), "FrostNova should not match when target is nil")

-- ============================================================================
-- Cone of Cold: only within 10 yards AND at least 2 nearby enemies
-- ============================================================================

local cone_of_cold = find_strategy("ConeOfCold")

-- Target far away -> should NOT match
action_calls = {}
local ctx_coc_far = {
    target = {},
    me = {
        get_distance = function(t) return 15 end,
    },
}
assert_false(cone_of_cold.matches(ctx_coc_far), "ConeOfCold should not match when target > 10 yards")
assert_eq(#action_calls, 0, "action_matches should not be called when target far away")

-- Target close but only 1 enemy -> should NOT match
action_calls = {}
local ctx_coc_single = {
    target = {},
    me = {
        get_distance = function(t) return 5 end,
    },
    enemies = {},
}
assert_false(cone_of_cold.matches(ctx_coc_single), "ConeOfCold should not match with < 2 nearby enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 2 nearby enemies")

-- Target close with 2+ nearby enemies -> should match
action_calls = {}
local enemy1 = { is_valid = function() return true end }
local enemy2 = { is_valid = function() return true end }
local ctx_coc_multi = {
    target = {},
    me = {
        get_distance = function(t) return 5 end,
    },
    enemies = { enemy1, enemy2 },
}
assert_true(cone_of_cold.matches(ctx_coc_multi), "ConeOfCold should match with >= 2 nearby enemies")

print("PASS test_frost_custom_matches")
