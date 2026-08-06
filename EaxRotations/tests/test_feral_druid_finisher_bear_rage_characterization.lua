-- test_feral_druid_finisher_bear_rage_characterization.lua -- Feral resource-path characterization.
-- WHAT:  verifies cat finishers consume resolved combo points and bear spenders consume dispatcher rage.
-- WHEN:  run by the rotation suite or directly with lua.
-- WHY:   covers the reported Rip/Ferocious Bite and Maul/Swipe resource-gating paths end-to-end at spec level.
-- SAFETY: fully mocked player and target objects; no product state or live API is changed.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(value, message)
    if not value then error(message or "assert_true failed", 2) end
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function base_namespace()
    return {
        DruidSpells = {},
        POWER_COMBO = 4,
        POWER_RAGE = 1,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        is_spell_learned = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_remains = function(target) return target and target._debuff_remains or 0 end,
        get_debuff_stacks = function(target) return target and target._debuff_stacks or 0 end,
        has_form = function(form) return form == "cat" or form == "bear" end,
        is_behind_target = function() return true end,
        GetPlayer = function() return nil end,
        log = function() end,
        rotation_registry = { register = function() end },
    }
end

local cat_namespace = base_namespace()
_G.EaxRotations = cat_namespace
local cat = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
local rip = find_strategy(cat.strategies, "Rip")
local bite = find_strategy(cat.strategies, "FerociousBite")

local cat_player = {
    combo_points_current = function() return 0 end,
    get_power = function(_, power_type)
        if power_type == 4 then return 5 end
        if power_type == 3 then return 100 end
        return 0
    end,
    get_max_power = function() return 100 end,
    get_health_percentage = function() return 100 end,
}

local function cat_context(remains)
    return {
        me = cat_player,
        target = { _debuff_remains = remains },
        has_valid_enemy_target = true,
        in_combat = true,
        is_cat = true,
        is_behind = true,
        energy = 100,
        combo_points = 0,
        ttd = 60,
        target_ttd = 60,
        level = 70,
        settings = { cat_rip_cp = 5, cat_use_rip = true },
    }
end

assert_true(rip.matches(cat_context(0)),
    "Rip must use get_power(POWER_COMBO)=5 when combo_points_current() incorrectly reports 0")
assert_true(bite.matches(cat_context(10)),
    "Ferocious Bite must use get_power(POWER_COMBO)=5 when combo_points_current() incorrectly reports 0")

local bear_namespace = base_namespace()
bear_namespace.has_form = function(form) return form == "bear" end
_G.EaxRotations = bear_namespace
local bear = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
local maul = find_strategy(bear.strategies, "Maul")
local swipe = find_strategy(bear.strategies, "SwipeAoE")

local bear_context = {
    me = {},
    target = { _debuff_stacks = 5, _debuff_remains = 10 },
    has_valid_enemy_target = true,
    in_combat = true,
    rage = 50,
    enemy_count = 3,
    target_ttd = 60,
    target_range = 5,
    settings = { bear_maul_rage = 50, bear_swing_timer = false },
}

assert_true(maul.matches(bear_context),
    "Maul must match when the dispatcher supplies rage=50 at the configured threshold")
assert_true(swipe.matches(bear_context),
    "SwipeAoE must match when the dispatcher supplies rage=50 for a three-target pack")

print("PASS test_feral_druid_finisher_bear_rage_characterization")
