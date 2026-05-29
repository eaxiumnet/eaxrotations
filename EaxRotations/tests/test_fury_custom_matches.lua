-- unit tests for fury_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()	-- Preload SwingTimer module so fury module's require() gets our mock
	package.preload["shared/swing_timer_sylvanas"] = function()
	    return { get_mh_time_until = function() return 1.0 end, get_mh_progress = function() return 0 end }
	end
	
	-- Mock NS namespace
	local action_calls = {}
	local spell_ready_calls = {}

_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308,
        Slam = 1464,
        HeroicStrike = 78,
        DeathWish = 12292,
        Hamstring = 1715,
        Intercept = 20252,
        Pummel = 6552,
        Bloodthirst = 23881,
        Whirlwind = 1680,
        BerserkerStance = 2457,
        BattleShout = 6673,
        CommandingShout = 469,
        BerserkerRage = 1849,
        Rampage = 29801,
        SweepingStrikes = 12292,
        Cleave = 845,
        BattleStance = 2458,
        Overpower = 7384,
        Rend = 772,
        SunderArmor = 7386,
        DemoralizingShout = 1160,
        ThunderClap = 6343,
        Charge = 100,
        VictoryRush = 34428,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    PLAYER_UNIT = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    buff_up = function(unit, buff_list) return false end,
    has_player_buff = function(buff_list)
        return false
    end,
    buff_remains = function(unit, buff_list) return 0 end,
    debuff_remains = function(target, debuff_list)
        return 0
    end,
    debuff_stacks = function(unit, ids) return 0 end,
    buff_stacks = function(unit, ids) return 0 end,
    cooldown_remains = function(spell, duration)
        return 99
    end,
    is_execute_phase = function(hp, threshold) return hp and hp <= (threshold or 20) end,
    log = function() end,
    time = function() return 1000 end,
    GetPlayer = function() return {} end,
    get_tactical_mastery_cap = function() return 25 end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warrior/fury_sylvanas.lua")
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

local execute = find_strategy("Execute")-- Target HP high -> should NOT match
spell_ready_calls = {}
assert_false(execute.matches({ target_hp = 30, rage = 50, target = {} }), "Execute should not match when target HP > 20%")

-- Target HP low -> should match
spell_ready_calls = {}
assert_true(execute.matches({ target_hp = 15, rage = 50, target = {} }), "Execute should match when target HP <= 20%")

-- ============================================================================
-- Slam: only when not moving and rage-safe for upcoming core abilities
-- ============================================================================

local slam = find_strategy("Slam")	-- Moving -> should NOT match
	spell_ready_calls = {}
	assert_false(slam.matches({ is_moving = true, rage = 50 }, { rage = 50, bt_cd = 99, ww_cd = 99 }), "Slam should not match when moving")

-- Low rage (would starve BT/WW) -> should NOT match
spell_ready_calls = {}
assert_false(slam.matches({ is_moving = false, rage = 10 }, { rage = 10, bt_cd = 99, ww_cd = 99 }), "Slam should not match when rage too low")

-- Rage OK but BT/WW about to come off cooldown -> should NOT match
spell_ready_calls = {}
_G.EaxRotations.cooldown_remains = function(spell, duration) return 1 end
assert_false(slam.matches({ is_moving = false, rage = 50 }, { rage = 50, bt_cd = 1, ww_cd = 1 }), "Slam should not match when BT/WW coming up soon")
_G.EaxRotations.cooldown_remains = function(spell, duration) return 99 end	-- Rage OK, BT/WW far from ready -> should match
		action_calls = {}
		spell_ready_calls = {}
		assert_true(slam.matches({ is_moving = false, rage = 50, target = {}, me = {} }, { rage = 50, bt_cd = 99, ww_cd = 99, mh_until = 1.0 }), "Slam should match when rage safe and BT/WW far")

-- ============================================================================
-- Heroic Strike: only when rage >= 50 and core abilities not ready
-- ============================================================================

local heroic_strike = find_strategy("HeroicStrike")	-- Low rage -> should NOT match
	spell_ready_calls = {}
	assert_false(heroic_strike.matches({ rage = 30 }, { rage = 30 }), "HeroicStrike should not match when rage < 50")-- ============================================================================
-- Death Wish: requires cooldowns enabled, HP >= 45, not in execute starvation
-- ============================================================================

local death_wish = find_strategy("DeathWish")	-- Cooldowns disabled -> should NOT match
		spell_ready_calls = {}
		assert_false(death_wish.matches({ settings = { use_cooldowns = false } }), "DeathWish should not match when cooldowns disabled")

-- In combat, cooldowns enabled -> should match
action_calls = {}
assert_true(death_wish.matches({ in_combat = true, should_burst = true }), "DeathWish should match in combat")

-- ============================================================================
-- Hamstring: only in PvP
-- ============================================================================

local hamstring = find_strategy("Hamstring")	-- Not PvP -> should NOT match
	spell_ready_calls = {}
	assert_false(hamstring.matches({ is_pvp = false, target = {} }), "Hamstring should not match when not PvP")

-- PvP with debuff fresh -> should NOT match
spell_ready_calls = {}
_G.EaxRotations.debuff_remains = function(target, debuff_list) return 5 end
assert_false(hamstring.matches({ is_pvp = true, target = {} }), "Hamstring should not match when debuff fresh")
_G.EaxRotations.debuff_remains = function(target, debuff_list) return 0 end

-- ============================================================================
-- Intercept: only in PvP at 8-25 yards
-- ============================================================================

local intercept = find_strategy("Intercept")	-- Not PvP -> should NOT match
	spell_ready_calls = {}
	assert_false(intercept.matches({ is_pvp = false, target_distance = 15 }), "Intercept should not match when not PvP")

-- Too close -> should NOT match
spell_ready_calls = {}
assert_false(intercept.matches({ is_pvp = true, target_distance = 5 }), "Intercept should not match when target < 8 yards")

-- Too far -> should NOT match
spell_ready_calls = {}
assert_false(intercept.matches({ is_pvp = true, target_distance = 30 }), "Intercept should not match when target > 25 yards")-- Range OK -> should match
	spell_ready_calls = {}		
	assert_true(intercept.matches({ is_pvp = true, target_distance = 15, in_combat = true, target = {}, me = {} }), "Intercept should match at 8-25 yards")

-- ============================================================================
-- Pummel: only when target is casting
-- ============================================================================

local pummel = find_strategy("Pummel")

-- No target -> should NOT match
spell_ready_calls = {}
assert_false(pummel.matches({ target = nil }), "Pummel should not match without target")-- Target not casting -> should NOT match
    spell_ready_calls = {}
    assert_false(pummel.matches({ target = { is_casting = function() return false end } }), "Pummel should not match when target not casting")	-- Target casting -> should match
    spell_ready_calls = {}
    assert_true(pummel.matches({ target = { is_casting = function() return true end } }), "Pummel should match when target casting")

-- ============================================================================
-- Sweeping Strikes: only when 2+ enemies
-- ============================================================================

local sweeping_strikes = find_strategy("SweepingStrikes")	-- Too few enemies -> should NOT match
	spell_ready_calls = {}
	assert_false(sweeping_strikes.matches({ enemy_count = 1 }), "SweepingStrikes should not match with < 2 enemies")	-- 2+ enemies -> should match
	spell_ready_calls = {}
	assert_true(sweeping_strikes.matches({ enemy_count = 3, stance = 1, me = {} }), "SweepingStrikes should match with >= 2 enemies in Battle Stance")

-- ============================================================================
-- Cleave: only when 2+ enemies and rage >= 60
-- ============================================================================

local cleave = find_strategy("Cleave")	-- Too few enemies -> should NOT match
	spell_ready_calls = {}
	assert_false(cleave.matches({ enemy_count = 1, rage = 70 }, { rage = 70 }), "Cleave should not match with < 2 enemies")

-- Low rage -> should NOT match
spell_ready_calls = {}
assert_false(cleave.matches({ enemy_count = 3, rage = 50 }, { rage = 50 }), "Cleave should not match when rage < 60")	-- 2+ enemies, rage OK -> should match
	spell_ready_calls = {}
	assert_true(cleave.matches({ enemy_count = 3, rage = 70, target = {}, me = {} }, { rage = 70 }), "Cleave should match with >= 2 enemies and rage >= 60")

print("PASS test_fury_custom_matches")
