-- test_kebab_vanilla_strategies.lua — Kebab Vanilla strategy match coverage.
-- WHAT:  Exercises Execute / SweepingStrikes gates on kebab_vanilla.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for warrior kebab vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

package.loaded["common/enums"] = { class_id = { WARRIOR = 1 } }

_G.EaxRotations = {
    CLASS_ID = { WARRIOR = 1 },
    PLAYER_UNIT = {},
    WarriorSpells = {
        Execute = 5308, BerserkerStance = 2458, BattleStance = 2457,
        SweepingStrikes = 12292, MortalStrike = 12294, Whirlwind = 1680,
        Overpower = 7384, BattleShout = 6673, HeroicStrike = 78, Cleave = 845,
        SunderArmor = 7386, ThunderClap = 6343, DemoralizingShout = 1160,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        BUFF_ID = { SWEEPING_STRIKES = 12292 },
        SUNDER_DEBUFF = {},
        THUNDER_CLAP_DEBUFF = {},
        DEMO_SHOUT_DEBUFF = {},
        BATTLE_SHOUT_IDS = { 11551, 11550, 11549, 6192, 5242, 6673 },
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
    buff_remains = function() return 0 end,
    aoe_target_meets = function() return false end,
    AOE_RADIUS = { TARGET_8 = 8 },
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

local strategies = dofile("EaxRotations/classes/warrior/kebab_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "kebab_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local execute = find("Execute")
local ss = find("SweepingStrikes")

local base = {
    settings = {},
    target = {},
    rage = 50,
    enemy_count = 1,
    stance = 3, -- Berserker
    target_hp = 15,
}

-- Execute: needs target_below_20 and rage
assert_false(execute.matches(base, { target_below_20 = false, general_use = true, ww_cd = 99, ms_cd = 99 }),
    "Kebab Execute must not match when target not below 20%")
assert_false(execute.matches({
    settings = {}, target = {}, rage = 10, enemy_count = 1, stance = 3, target_hp = 15,
}, { target_below_20 = true, general_use = true, ww_cd = 99, ms_cd = 99 }),
    "Kebab Execute must not match with rage < 15")
assert_true(execute.matches(base, { target_below_20 = true, general_use = true, ww_cd = 99, ms_cd = 99 }),
    "Kebab Execute matches below 20% with rage in Berserker")

-- Sweeping Strikes: needs 2+ enemies
assert_false(ss.matches({
    settings = {}, target = {}, rage = 50, enemy_count = 1, stance = 1,
}), "SweepingStrikes must not match single target")
assert_true(ss.matches({
    settings = {}, target = {}, rage = 50, enemy_count = 2, stance = 1,
}), "SweepingStrikes matches with 2+ enemies in Battle stance")

print("PASS test_kebab_vanilla_strategies")
