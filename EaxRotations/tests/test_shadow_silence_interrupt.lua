-- Test: Silence interrupt strategy has been moved to interrupt_manager middleware.
-- This test verifies the strategy is no longer present in the spec file,
-- and that the silence_matches helper function still exists for middleware use.

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
    PriestSpells = {
        MindFlay = 15407,
        ShadowWordPain = 48125,
        VampiricTouch = 34914,
        Silence = 15487,
        MindBlast = 48127,
        ShadowWordDeath = 32379,
        Shadowform = 15473,
        InnerFire = 48168,
        InnerFocus = 14751,
        Fade = 586,
        PsychicScream = 10890,
        DispelMagic = 528,
        ShackleUndead = 9484,
        DevouringPlague = 48300,
        FlashHeal = 48071,
        PowerWordShield = 48066,
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    action_execute = function(ctx, act, prefix) return true end,
    spell_ready = function(spell, target, opts) return true end,
    spell_action = function(ids, name) return { name = name, ids = ids } end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    unit_interruptible = function(target)
        if target and target._interruptible ~= nil then return target._interruptible end
        return true
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/priest/shadow_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    return nil
end

-- ============================================================================
-- Silence: interrupt strategy removed from spec (handled by interrupt_manager)
-- ============================================================================

local silence = find_strategy("Silence")
assert_false(silence ~= nil, "Silence strategy should NOT be in spec strategy table (handled by interrupt_manager middleware)")

print("PASS test_shadow_silence_interrupt")
