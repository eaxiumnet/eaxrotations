-- unit tests for fire_sylvanas custom matches functions.

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
local has_buff_calls = {}
_G.EaxRotations = {
    MageSpells = {
        Scorch = 2948,
        Fireball = 133,
        FireBlast = 2136,
        Flamestrike = 2120,
        FlamestrikeRank6 = 2121,
        Blizzard = 10,
        IceBarrier = 11426,
        ManaShield = 1463,
        Evocation = 12051,
        Counterspell = 2139,
        BlastWave = 11113,
        DragonsBreath = 31661,
        Polymorph = 118,
        Pyroblast = 11366,
        PresenceOfMind = 12043,
        Combustion = 11129,
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
    has_player_buff = function(buff_list)
        has_buff_calls[#has_buff_calls + 1] = { buff = buff_list }
        return false
    end,
    log = function() end,
    should_use_long_cd = function() return false end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/mage/fire_sylvanas.lua")
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
-- Combustion: only in combat and during burst or long CD window
-- ============================================================================

local combustion = find_strategy("Combustion")

-- Not in combat -> should NOT match
action_calls = {}
assert_false(combustion.matches({ in_combat = false, should_burst = true }, { combustion_ready = true }), "Combustion should not match when OOC")

-- In combat, not burst, no long CD -> should NOT match (spell_ready returns true but should_use_long_cd may be false)
-- Combustion delegates to NS.should_use_long_cd which is nil in our mock, so it returns nil -> false in Lua
action_calls = {}
assert_false(combustion.matches({ in_combat = true, should_burst = false }, { combustion_ready = true }), "Combustion should not match without burst or long CD")

-- In combat, should_burst -> should match
action_calls = {}
assert_true(combustion.matches({ in_combat = true, should_burst = true }, { combustion_ready = true }), "Combustion should match during burst")

-- ============================================================================
-- Scorch: only when not moving, has target, and stacks < 5 or about to drop
-- ============================================================================

local scorch = find_strategy("Scorch")

-- Moving -> should NOT match
action_calls = {}
assert_false(scorch.matches({ is_moving = true, target = {} }), "Scorch should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- No target -> should NOT match
assert_false(scorch.matches({ is_moving = false }), "Scorch should not match without target")

-- Not moving, target, stacks < 5 -> should match
action_calls = {}
assert_true(scorch.matches({ is_moving = false, target = {}, scorch_stacks = 3, scorch_remains = 10 }), "Scorch should match when stacks < 5")

-- Not moving, target, stacks >= 5 but remains <= 4 -> should match
action_calls = {}
assert_true(scorch.matches({ is_moving = false, target = {}, scorch_stacks = 5, scorch_remains = 2 }), "Scorch should match when about to drop")

-- Not moving, target, stacks >= 5, remains > 4 -> should NOT match
action_calls = {}
assert_false(scorch.matches({ is_moving = false, target = {}, scorch_stacks = 5, scorch_remains = 10 }), "Scorch should not match when maintained")

-- ============================================================================
-- Fireball: only when not moving and scorch stacks >= 5
-- ============================================================================

local fireball = find_strategy("Fireball")

-- Moving -> should NOT match
action_calls = {}
assert_false(fireball.matches({ is_moving = true, target = {}, scorch_stacks = 5 }), "Fireball should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Stacks < 5 -> should NOT match
action_calls = {}
assert_false(fireball.matches({ is_moving = false, target = {}, scorch_stacks = 3 }), "Fireball should not match when stacks < 5")
assert_eq(#action_calls, 0, "action_matches should not be called when stacks < 5")

-- Not moving, stacks >= 5 -> should match
action_calls = {}
assert_true(fireball.matches({ is_moving = false, target = {}, scorch_stacks = 5 }), "Fireball should match when stacks >= 5")

-- ============================================================================
-- Pyroblast: only when not moving and (opener with PoM or Presence of Mind buff)
-- ============================================================================

local pyroblast = find_strategy("Pyroblast")

-- Moving -> should NOT match
action_calls = {}
assert_false(pyroblast.matches({ is_moving = true, target = {}, in_combat = false, settings = { use_pyro_opener = true } }), "Pyroblast should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Not in combat but no opener setting -> should NOT match
action_calls = {}
assert_false(pyroblast.matches({ is_moving = false, target = {}, in_combat = false, settings = { use_pyro_opener = false } }), "Pyroblast should not match without opener setting")

-- Presence of Mind buff active -> should match (has_player_buff returns false in mock, so this should NOT match)
-- We override has_player_buff for this test
action_calls = {}
local orig_has_buff = _G.EaxRotations.has_player_buff
_G.EaxRotations.has_player_buff = function(buff_list)
    has_buff_calls[#has_buff_calls + 1] = { buff = buff_list }
    return true  -- simulate PoM buff
end
assert_true(pyroblast.matches({ is_moving = false, target = {}, in_combat = true }), "Pyroblast should match with PoM buff")
_G.EaxRotations.has_player_buff = orig_has_buff

-- ============================================================================
-- Presence of Mind: only in combat, during burst, and not already buffed
-- ============================================================================

local pom = find_strategy("PresenceOfMind")

-- Not in combat -> should NOT match
action_calls = {}
assert_false(pom.matches({ in_combat = false, should_burst = true }), "PoM should not match when OOC")

-- No burst -> should NOT match
action_calls = {}
assert_false(pom.matches({ in_combat = true, should_burst = false }), "PoM should not match without burst")

-- Already has buff -> should NOT match
action_calls = {}
local orig_has_buff2 = _G.EaxRotations.has_player_buff
_G.EaxRotations.has_player_buff = function(buff_list) return true end
assert_false(pom.matches({ in_combat = true, should_burst = true }), "PoM should not match when already buffed")
_G.EaxRotations.has_player_buff = orig_has_buff2

-- In combat, burst, no buff -> should match
action_calls = {}
assert_true(pom.matches({ in_combat = true, should_burst = true }), "PoM should match during burst")

-- ============================================================================
-- Counterspell removed — handled by interrupt_manager middleware
-- ============================================================================
-- Evocation: only in combat and mana <= 20%
-- ============================================================================

local evocation = find_strategy("Evocation")

-- Not in combat -> should NOT match
action_calls = {}
assert_false(evocation.matches({ in_combat = false, mana_pct = 10 }), "Evocation should not match when OOC")

-- High mana -> should NOT match
action_calls = {}
assert_false(evocation.matches({ in_combat = true, mana_pct = 50 }), "Evocation should not match when mana > 20%")

-- Low mana, in combat -> should match
action_calls = {}
assert_true(evocation.matches({ in_combat = true, mana_pct = 15 }), "Evocation should match when mana <= 20% and in combat")

-- ============================================================================
-- Ice Barrier: only when HP <= 60 and not already buffed
-- ============================================================================

local ice_barrier = find_strategy("IceBarrier")

-- High HP -> should NOT match
action_calls = {}
assert_false(ice_barrier.matches({ hp = 70 }), "IceBarrier should not match when HP > 60")

-- Low HP, already buffed -> should NOT match
action_calls = {}
local orig_has_buff3 = _G.EaxRotations.has_player_buff
_G.EaxRotations.has_player_buff = function(buff_list) return true end
assert_false(ice_barrier.matches({ hp = 40 }), "IceBarrier should not match when already buffed")
_G.EaxRotations.has_player_buff = orig_has_buff3

-- Low HP, no buff -> should match
action_calls = {}
assert_true(ice_barrier.matches({ hp = 40 }), "IceBarrier should match when HP <= 60 and no buff")

-- ============================================================================
-- Mana Shield: only when HP <= 40
-- ============================================================================

local mana_shield = find_strategy("ManaShield")

-- High HP -> should NOT match
action_calls = {}
assert_false(mana_shield.matches({ hp = 50 }), "ManaShield should not match when HP > 40")

-- Low HP -> should match
action_calls = {}
assert_true(mana_shield.matches({ hp = 30 }), "ManaShield should match when HP <= 40")

-- ============================================================================
-- Flamestrike: only when not moving and 3+ enemies
-- ============================================================================

local flamestrike = find_strategy("Flamestrike")

-- Moving -> should NOT match
action_calls = {}
assert_false(flamestrike.matches({ is_moving = true, enemy_count = 5, target = {} }), "Flamestrike should not match when moving")
assert_eq(#action_calls, 0, "action_matches should not be called when moving")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(flamestrike.matches({ is_moving = false, enemy_count = 2, target = {} }), "Flamestrike should not match with < 3 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 3 enemies")

-- Not moving, 3+ enemies -> should match
action_calls = {}
assert_true(flamestrike.matches({ is_moving = false, enemy_count = 4, target = {} }), "Flamestrike should match when not moving and >= 3 enemies")

-- ============================================================================
-- Blizzard: only when not moving and 4+ enemies
-- ============================================================================

local blizzard = find_strategy("Blizzard")

-- Moving -> should NOT match
action_calls = {}
assert_false(blizzard.matches({ is_moving = true, enemy_count = 5, target = {} }), "Blizzard should not match when moving")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(blizzard.matches({ is_moving = false, enemy_count = 3, target = {} }), "Blizzard should not match with < 4 enemies")

-- Not moving, 4+ enemies -> should match
action_calls = {}
assert_true(blizzard.matches({ is_moving = false, enemy_count = 5, target = {} }), "Blizzard should match when not moving and >= 4 enemies")

-- ============================================================================
-- Blast Wave: only when 2+ enemies
-- ============================================================================

local blast_wave = find_strategy("BlastWave")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(blast_wave.matches({ enemy_count = 1, target = {} }), "BlastWave should not match with < 2 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 2 enemies")

-- 2+ enemies -> should match
action_calls = {}
assert_true(blast_wave.matches({ enemy_count = 3, target = {} }), "BlastWave should match with >= 2 enemies")

-- ============================================================================
-- Dragon's Breath: only when 2+ enemies
-- ============================================================================

local dragons_breath = find_strategy("DragonsBreath")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(dragons_breath.matches({ enemy_count = 1, target = {} }), "DragonsBreath should not match with < 2 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 2 enemies")

-- 2+ enemies -> should match
action_calls = {}
assert_true(dragons_breath.matches({ enemy_count = 2, target = {} }), "DragonsBreath should match with >= 2 enemies")

-- ============================================================================
-- Polymorph: only in PvP with cc_target
-- ============================================================================

local polymorph = find_strategy("Polymorph")

-- Not PvP -> should NOT match
action_calls = {}
assert_false(polymorph.matches({ is_pvp = false, cc_target = {} }), "Polymorph should not match when not PvP")
assert_eq(#action_calls, 0, "action_matches should not be called when not PvP")

-- No cc_target -> should NOT match
action_calls = {}
assert_false(polymorph.matches({ is_pvp = true, cc_target = nil }), "Polymorph should not match without cc_target")

-- PvP with cc_target -> should match
action_calls = {}
assert_true(polymorph.matches({ is_pvp = true, cc_target = {} }), "Polymorph should match in PvP with cc_target")

print("PASS test_fire_custom_matches")
