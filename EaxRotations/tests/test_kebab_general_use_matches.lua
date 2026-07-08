-- test_kebab_general_use_matches.lua -- match validation tests.
-- WHAT:  match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- behavior tests for Warrior Kebab general-use decisions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

package.loaded["common/enums"] = { class_id = { WARRIOR = 1 } }

_G.EaxRotations = {
    CLASS_ID = { WARRIOR = 1 },
    PLAYER_UNIT = {},
    WarriorSpells = {
        Execute = 5308,
        BerserkerStance = 2458,
        SweepingStrikes = 12328,
        MortalStrike = 12294,
        Whirlwind = 1680,
        Overpower = 7384,
        BattleShout = 6673,
        CommandingShout = 469,
        HeroicStrike = 78,
        Cleave = 845,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        BUFF_ID = { SWEEPING_STRIKES = 12328 },
        SUNDER_DEBUFF = {},
        THUNDER_CLAP_DEBUFF = {},
        DEMO_SHOUT_DEBUFF = {},
        BATTLE_SHOUT_IDS = {},
    },
    GetPlayer = function()
        return { get_class = function() return 1 end }
    end,
    import_helpers = function()
        return function() return true end,  -- try_cast
            function() return true end,     -- spell_exists
            function() return true end,     -- spell_ready
            function() return 0 end,        -- debuff_remains
            function() return 0 end,        -- debuff_stacks
            function() return 0 end,        -- buff_remains
            function() return 100 end,      -- health_pct
            function() return false end,    -- player_control_locked
            function() return false end,    -- has_player_buff
            function() return false end,    -- has_breakable_cc_nearby
            function() return true end      -- can_attack_target
    end,
    is_execute_phase = function(hp, threshold) return (hp or 100) <= (threshold or 20) end,
    cooldown_remains = function() return 0 end,
    get_spell_id = function(spell) return spell end,
    is_current_spell = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warrior/kebab_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "kebab strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local ms_general = find_strategy("MortalStrikeGeneralUse")
local whirlwind = find_strategy("Whirlwind")
local heroic = find_strategy("HeroicStrike")

local base_context = {
    settings = {},
    target = {},
    rage = 50,
    enemy_count = 1,
    stance = 3,
    in_melee_range = true,
    has_breakable_cc_nearby = false,
}

assert_true(ms_general.matches(base_context, { general_use = true, target_below_20 = false }), "General-use Kebab should favor Mortal Strike")
assert_false(ms_general.matches(base_context, { general_use = false, target_below_20 = false }), "MortalStrikeGeneralUse should not run in DW priority mode")
assert_false(whirlwind.matches(base_context, { general_use = true, target_below_20 = false, ww_cd = 0 }), "General-use Kebab should not WW single target")
assert_true(whirlwind.matches({ settings = { kebab_use_sweeping_strikes = false }, target = {}, rage = 50, enemy_count = 2, stance = 3, has_breakable_cc_nearby = false }, { general_use = true, target_below_20 = false, ww_cd = 0 }), "General-use Kebab may WW cleave when not pooling for Sweeping Strikes")
assert_false(heroic.matches({ settings = {}, target = {}, rage = 45, enemy_count = 1, has_offhand = false, has_breakable_cc_nearby = false }, { general_use = true, target_below_20 = false, ms_cd = 99, ww_cd = 99 }), "General-use Kebab should raise HS rage dump floor")
assert_true(heroic.matches({ settings = {}, target = {}, rage = 60, enemy_count = 1, has_offhand = false, has_breakable_cc_nearby = false }, { general_use = true, target_below_20 = false, ms_cd = 99, ww_cd = 99 }), "General-use Kebab should allow HS once rage is high")

print("PASS test_kebab_general_use_matches")
