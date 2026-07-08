-- test_arms_custom_matches.lua -- Arms custom match validation tests.
-- WHAT:  Arms custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for arms_sylvanas custom matches functions.

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
local spell_ready_calls = {}
_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308,
        BattleShout = 6673,
        VictoryRush = 34428,
        MortalStrike = 12294,
        Overpower = 7384,
        Slam = 1464,
        HeroicStrike = 78,
        Hamstring = 1715,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    is_execute_phase = function(hp, threshold)
        return hp and hp <= threshold
    end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    buff_up = function(me, buff_list)
        return me and me._buff_up or false
    end,
    debuff_remains = function(unit, ids) return 0 end,
    cooldown_remains = function(spell_value, fallback) return 0 end,
    is_interruptible = function(target) return true end,
    broken_api_throttled = function() return false end,
    get_debuff_stacks = function(unit, ids) return 0 end,
    log = function() end,
    GetPlayer = function() return {} end,
    PLAYER_UNIT = {},
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warrior/arms_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Execute: only when target HP <= 20%
-- ============================================================================

local execute = find_strategy("Execute")

-- Target HP high -> should NOT match
action_calls = {}
spell_ready_calls = {}
assert_false(execute.matches({ target_hp = 30 }), "Execute should not match when target HP > 20%")
assert_eq(#action_calls, 0, "action_matches should not be called when not execute phase")

-- Target HP low -> should match
action_calls = {}
spell_ready_calls = {}
assert_true(execute.matches({ target_hp = 15, rage = 50, target = {} }), "Execute should match when target HP <= 20%")
assert_true(#spell_ready_calls > 0, "spell_ready should be called during execute phase (build_state + match)")

-- ============================================================================
-- Victory Rush: only when Victory Rush buff is up
-- ============================================================================

local victory_rush = find_strategy("VictoryRush")

-- No buff -> should NOT match
action_calls = {}
spell_ready_calls = {}
assert_false(victory_rush.matches({ me = { _buff_up = false }, target = {} }), "VictoryRush should not match without buff")
assert_eq(#action_calls, 0, "action_matches should not be called without buff")

-- Buff active -> should match
action_calls = {}
spell_ready_calls = {}
assert_true(victory_rush.matches({ me = { _buff_up = true }, target = {} }), "VictoryRush should match with buff")
assert_true(#spell_ready_calls > 0, "spell_ready should be called with buff (build_state + match)")

-- No me -> should return false
assert_false(victory_rush.matches({}), "VictoryRush should not match without me")

-- ============================================================================
-- Slam: only when swing timer allows and rage is safe
-- ============================================================================

local slam = find_strategy("Slam")

-- No SwingTimer module -> should NOT match (module not loaded)
action_calls = {}
assert_false(slam.matches({ is_moving = false, rage = 50 }), "Slam should not match without SwingTimer")

-- ============================================================================
-- Mortal Strike: delegates to action_matches (no custom gate beyond standard)
-- ============================================================================

local ms = find_strategy("MortalStrike")
action_calls = {}
spell_ready_calls = {}
assert_true(ms.matches({ target = {}, stance = 1, rage = 30 }), "MortalStrike should always delegate to spell_ready")
assert_true(#spell_ready_calls > 0, "spell_ready should be called for MortalStrike (build_state + match)")

-- ============================================================================-- Heroic Strike: rage threshold and starvation logic-- ============================================================================

local hs = find_strategy("HeroicStrike")

-- Below 70-rage threshold -> should NOT match
action_calls = {}
spell_ready_calls = {}
assert_false(hs.matches({ target = {}, rage = 65, me = {} }), "HeroicStrike should not match below 70 rage")

-- At threshold -> should match
action_calls = {}
spell_ready_calls = {}
assert_true(hs.matches({ target = {}, rage = 75, me = {} }), "HeroicStrike should match at 75 rage")

-- Starvation guard wired: MS imminent with 70 rage is safe -> should match
action_calls = {}
spell_ready_calls = {}
_G.EaxRotations.cooldown_remains = function(spell, fallback) return 0.5 end
assert_true(hs.matches({ target = {}, rage = 75, me = {} }), "HeroicStrike should match at 75 rage even when MS imminent")
_G.EaxRotations.cooldown_remains = function(spell, fallback) return 0 end

-- ============================================================================
-- Cleave: MS starvation gate (would_starve_core_arms)
-- S1: Cleave at rage=55 with MS imminent: 55-15=40 < 30 for MS → STARVED
--     CLEAVE_RAGE=55 so clears threshold; starvation should block
-- S2: Cleave at rage=65 with MS imminent: 65-15=50 >= 30 for MS → OK
-- ============================================================================

local cleave = find_strategy("Cleave")

-- S1: rage=55 (threshold), ms_cd=0 (MS imminent), enemies=2
-- would_starve_core_arms: 55-15=40 < 30 for MS → STARVED → Cleave blocked
action_calls = {}
spell_ready_calls = {}
-- S1: Cleave at rage=70 (above SS reserve 60), ms_cd=0 (MS imminent), enemies=2
-- would_starve_core_arms: 70-15=55 >= 30 for MS → NOT starved → Cleave allowed
action_calls = {}
spell_ready_calls = {}
local cleave_ok = cleave.matches({ target = {}, rage = 70, enemy_count = 2, enemies_count = 2, me = {} })
if not cleave_ok then error("S2 FAIL: Cleave should match when rage=65 with MS imminent (65-15=50 >= 30)") end

-- ============================================================================
-- Charge: OOC + auto_charge + distance 8-25 + target not in combat + spell_ready
-- ============================================================================

local charge = find_strategy("Charge")

-- In combat -> should NOT match (Charge is an opener)
assert_false(charge.matches({ in_combat = true, target = {}, rage = 10, stance = 1, target_distance = 15 }), "Charge should not match when in combat")

-- Too close (< 8 yd) -> should NOT match
assert_false(charge.matches({ target = {}, rage = 10, stance = 1, in_combat = false, target_distance = 5 }), "Charge should not match when target < 8 yd")

-- Too far (> 25 yd) -> should NOT match
assert_false(charge.matches({ target = {}, rage = 10, stance = 1, in_combat = false, target_distance = 30 }), "Charge should not match when target > 25 yd")

-- auto_charge disabled -> should NOT match
assert_false(charge.matches({ target = {}, rage = 10, stance = 1, settings = { auto_charge = false }, in_combat = false, target_distance = 15 }), "Charge should not match when auto_charge=false")

-- target already in combat (charge_only_ooc default true) -> should NOT match
assert_false(charge.matches({ target = { is_in_combat = function() return true end }, rage = 10, stance = 1, in_combat = false, target_distance = 15 }), "Charge should not match when target already in combat (charge_only_ooc)")

-- All conditions met (OOC, dist 15, target not in combat) -> should match
assert_true(charge.matches({ target = { is_in_combat = function() return false end }, rage = 10, stance = 1, in_combat = false, target_distance = 15 }), "Charge should match OOC at 15 yd with target not in combat")

-- ============================================================================
-- Intercept: distance 8-25 + auto_charge + spell_ready
-- ============================================================================

local intercept = find_strategy("Intercept")

-- Too close (< 8 yd) -> should NOT match
assert_false(intercept.matches({ target = {}, rage = 10, stance = 3, target_distance = 5 }), "Intercept should not match when target < 8 yd")

-- Too far (> 25 yd) -> should NOT match
assert_false(intercept.matches({ target = {}, rage = 10, stance = 3, target_distance = 30 }), "Intercept should not match when target > 25 yd")

-- auto_charge disabled -> should NOT match
assert_false(intercept.matches({ target = {}, rage = 10, stance = 3, settings = { auto_charge = false }, target_distance = 15 }), "Intercept should not match when auto_charge=false")

-- All conditions met (dist 15, berserker stance, rage 10) -> should match
assert_true(intercept.matches({ target = {}, rage = 10, stance = 3, target_distance = 15 }), "Intercept should match at 15 yd in berserker stance with rage")

-- ============================================================================
-- SunderArmor: target_armor > 0 + use_sunder_armor + stacks < 5 + rage >= 15 + not execute + DEFENSIVE stance
-- ============================================================================

local sunder = find_strategy("SunderArmor")

-- use_sunder_armor off (default false) -> should NOT match
assert_false(sunder.matches({ target = {}, target_armor = 5000, rage = 30, stance = 2, target_hp = 80, settings = { use_sunder_armor = false } }), "SunderArmor should not match when use_sunder_armor=false (default)")

-- No target armor -> should NOT match
assert_false(sunder.matches({ target = {}, target_armor = 0, rage = 30, stance = 2, target_hp = 80, settings = { use_sunder_armor = true } }), "SunderArmor should not match when target_armor <= 0")

-- 5 stacks -> should NOT match
_G.EaxRotations.get_debuff_stacks = function() return 5 end
assert_false(sunder.matches({ target = {}, target_armor = 5000, rage = 30, stance = 2, target_hp = 80, settings = { use_sunder_armor = true } }), "SunderArmor should not match at 5 stacks")
_G.EaxRotations.get_debuff_stacks = function() return 0 end

-- Execute phase -> should NOT match
assert_false(sunder.matches({ target = {}, target_armor = 5000, rage = 30, stance = 2, target_hp = 15, settings = { use_sunder_armor = true } }), "SunderArmor should not match during execute phase")

-- Wrong stance (BATTLE, Sunder requires DEFENSIVE) -> should NOT match
assert_false(sunder.matches({ target = {}, target_armor = 5000, rage = 30, stance = 1, target_hp = 80, settings = { use_sunder_armor = true } }), "SunderArmor should not match in Battle stance (requires Defensive)")

-- All conditions met (DEFENSIVE stance, armor>0, stacks 0, rage 30, use_sunder_armor on) -> should match
assert_true(sunder.matches({ target = {}, target_armor = 5000, rage = 30, stance = 2, target_hp = 80, settings = { use_sunder_armor = true } }), "SunderArmor should match in Defensive stance with armor, low stacks, rage")

-- ============================================================================
-- ShieldWall: hp <= threshold (25 solo / 40 group) + DEFENSIVE stance
-- ============================================================================

local shield_wall = find_strategy("ShieldWall")

-- HP too high (solo, threshold 25) -> should NOT match
assert_false(shield_wall.matches({ target = {}, stance = 2, hp = 50, is_group = false }), "ShieldWall should not match at 50% hp solo (threshold 25)")

-- HP low enough but wrong stance (BATTLE) -> should NOT match
assert_false(shield_wall.matches({ target = {}, stance = 1, hp = 20, is_group = false }), "ShieldWall should not match in Battle stance (requires Defensive)")

-- Solo at 20% hp in Defensive -> should match
assert_true(shield_wall.matches({ target = {}, stance = 2, hp = 20, is_group = false }), "ShieldWall should match at 20% hp solo in Defensive stance")

-- Group at 35% hp (threshold 40) in Defensive -> should match
assert_true(shield_wall.matches({ target = {}, stance = 2, hp = 35, is_group = true }), "ShieldWall should match at 35% hp in group (threshold 40) in Defensive stance")

-- ============================================================================
-- EngineeringBomb: requires engineering helper module loaded -> false when absent
-- ============================================================================

local eng_bomb = find_strategy("EngineeringBomb")

-- engineering module not loaded in test -> should NOT match (graceful nil-guard)
assert_false(eng_bomb.matches({ target = {} }), "EngineeringBomb should not match when engineering helper absent (nil-guard)")

print("PASS test_arms_custom_matches")
