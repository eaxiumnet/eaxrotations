-- test_deathknight_blood_wotlk.lua — WotLK Blood death knight rotation logic tests.
-- WHAT:  Verifies disease maintenance and strike priority logic.
-- WHEN:  During WotLK test suite execution.
-- WHY:   Regression guard for Blood DK rotation decisions.
-- SAFETY: Uses synthetic context; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch = make_action(49909, "IcyTouch"),
        PlagueStrike = make_action(49922, "PlagueStrike"),
        HeartStrike = make_action(55263, "HeartStrike"),
        DeathStrike = make_action(49940, "DeathStrike"),
        DeathCoil = make_action(47541, "DeathCoil"),
        Pestilence = make_action(50842, "Pestilence"),
        DancingRuneWeapon = make_action(49028, "DancingRuneWeapon"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
        HornOfWinter = make_action(57330, "HornOfWinter"),
        BloodStrike = make_action(45902, "BloodStrike"),
    },
    me = {
        get_health_percentage = function() return 80 end,
        get_runic_power = function() return 50 end,
    },
    debuff_remains = function(unit, ids) return 0 end,
    buff_up = function(unit, ids) return false end,
    rotation_registry = {
        register = function(self, name, strategies, options)
        end,
    },
    log = function() end,
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_deathknight_blood_wotlk ===")

local blood = dofile("EaxRotations/classes/deathknight/blood_wotlk.lua")
assert_true(type(blood) == "table", "blood_wotlk should return a table")
assert_true(type(blood.strategies) == "table", "blood_wotlk should expose strategies")
assert_true(type(blood.build_state) == "function", "blood_wotlk should expose build_state")

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name, 2)
end

local icy_touch = find_strategy(blood.strategies, "IcyTouch")
local plague_strike = find_strategy(blood.strategies, "PlagueStrike")
local death_strike = find_strategy(blood.strategies, "DeathStrike")
local heart_strike = find_strategy(blood.strategies, "HeartStrike")

-- Mock debuff durations: both diseases missing
_G.EaxRotations.debuff_remains = function(unit, ids)
    return 0
end

local ctx = { in_combat = true, target = { get_health_percentage = function() return 80 end }, settings = {} }
local state_no_diseases = blood.build_state(ctx)

-- Disease maintenance: IcyTouch and PlagueStrike should match when diseases are missing
assert_true(icy_touch.matches(ctx, state_no_diseases), "IcyTouch should match when Frost Fever is missing")
assert_true(plague_strike.matches(ctx, state_no_diseases), "PlagueStrike should match when Blood Plague is missing")

-- Mock debuff durations: diseases healthy
_G.EaxRotations.debuff_remains = function(unit, ids)
    return 10
end
local state_healthy = blood.build_state(ctx)

assert_false(icy_touch.matches(ctx, state_healthy), "IcyTouch should not match when Frost Fever is healthy")
assert_false(plague_strike.matches(ctx, state_healthy), "PlagueStrike should not match when Blood Plague is healthy")

-- Mock debuff durations: diseases about to expire (<3s)
_G.EaxRotations.debuff_remains = function(unit, ids)
    return 2
end
local state_refresh = blood.build_state(ctx)

assert_true(icy_touch.matches(ctx, state_refresh), "IcyTouch should match when Frost Fever is about to expire")
assert_true(plague_strike.matches(ctx, state_refresh), "PlagueStrike should match when Blood Plague is about to expire")

-- Strike priority: DeathStrike only when HP < 80%
local state_high_hp = blood.build_state({ in_combat = true, target = { get_health_percentage = function() return 80 end }, settings = {} })
state_high_hp.hp = 90
assert_false(death_strike.matches(ctx, state_high_hp), "DeathStrike should not match when HP >= 80%")

local state_low_hp = blood.build_state({ in_combat = true, target = { get_health_percentage = function() return 80 end }, settings = {} })
state_low_hp.hp = 70
assert_true(death_strike.matches(ctx, state_low_hp), "DeathStrike should match when HP < 80%")

-- HeartStrike is the default filler and should always match
local state_filler = blood.build_state(ctx)
assert_true(heart_strike.matches(ctx, state_filler), "HeartStrike should always match as filler")

print("PASS test_deathknight_blood_wotlk")
