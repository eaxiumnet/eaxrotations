-- Unit tests for shadow_sylvanas Silence interrupt custom matches.
-- Tests: combat gating, interruptible target detection, mind flay clipping, no target fallback

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
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Silence: interrupt ability
-- ============================================================================

local silence = find_strategy("Silence")

-- Case 1: In combat, target casting, silence ready -> should match
action_calls = {}
local ctx_combat_casting = {
    in_combat = true,
    target = { _interruptible = true },
    target_is_casting = true,
    me = { get_health_percentage = function() return 100 end, get_mana_percentage = function() return 100 end },
    mana_pct = 100,
    hp = 100,
    settings = {},
}
local state_ready = {
    silence_ready = true,
    mf_channeling = false,
    should_clip_mf = false,
    in_combat = true,
}
assert_true(silence.matches(ctx_combat_casting, state_ready), "Silence should match when in combat and target is interruptible")

-- Case 2: Out of combat -> should NOT match
action_calls = {}
local ctx_ooc = {
    in_combat = false,
    target = { _interruptible = true },
    target_is_casting = true,
    me = {},
    settings = {},
}
local state_ooc = {
    silence_ready = true,
    mf_channeling = false,
    should_clip_mf = false,
    in_combat = false,
}
assert_false(silence.matches(ctx_ooc, state_ooc), "Silence should not match when out of combat")
assert_eq(#action_calls, 0, "action_matches should not be called when OOC")

-- Case 3: Silence on cooldown -> should NOT match
action_calls = {}
local state_cd = {
    silence_ready = false,
    mf_channeling = false,
    should_clip_mf = false,
    in_combat = true,
}
assert_false(silence.matches(ctx_combat_casting, state_cd), "Silence should not match when on cooldown")
assert_eq(#action_calls, 0, "action_matches should not be called when silence on CD")

-- Case 4: No target -> should NOT match (fallback to target_is_casting)
action_calls = {}
local state_no_target = {
    silence_ready = true,
    mf_channeling = false,
    should_clip_mf = false,
    in_combat = true,
}
local ctx_no_target_casting = {
    in_combat = true,
    target = nil,
    target_is_casting = false,
    me = {},
    settings = {},
}
assert_false(silence.matches(ctx_no_target_casting, state_no_target), "Silence should not match without target and not casting")
assert_eq(#action_calls, 0, "action_matches should not be called without target")

-- Case 5: NS.unit_interruptible missing and target not casting -> should NOT match
-- (The implementation checks if the function EXISTS, not its return value)
action_calls = {}
local ctx_no_interrupt_api = {
    in_combat = true,
    target = {},
    target_is_casting = false,
    me = {},
    settings = {},
}
_G.EaxRotations.unit_interruptible = nil  -- Remove the API to test fallback path
assert_false(silence.matches(ctx_no_interrupt_api, state_ready), "Silence should not match when unit_interruptible unavailable and target not casting")
assert_eq(#action_calls, 0, "action_matches should not be called when no interrupt API and target not casting")
_G.EaxRotations.unit_interruptible = function(target)  -- Restore
    if target and target._interruptible ~= nil then return target._interruptible end
    return true
end

-- Case 6: Channeling mind flay, can't clip -> should NOT match
action_calls = {}
local state_mf_channeling = {
    silence_ready = true,
    mf_channeling = true,
    should_clip_mf = false,
    in_combat = true,
}
assert_false(silence.matches(ctx_combat_casting, state_mf_channeling), "Silence should not match when channeling mind flay and can't clip")
assert_eq(#action_calls, 0, "action_matches should not be called during mind flay channel")

-- Case 7: Channeling mind flay but should clip -> should match
action_calls = {}
local state_mf_clip = {
    silence_ready = true,
    mf_channeling = true,
    should_clip_mf = true,
    in_combat = true,
}
assert_true(silence.matches(ctx_combat_casting, state_mf_clip), "Silence should match when channeling mind flay and should clip")

-- Case 8: Fallback path — no NS.unit_interruptible but target_is_casting -> should match
action_calls = {}
_G.EaxRotations.unit_interruptible = nil  -- Remove the API
local ctx_no_interrupt_api = {
    in_combat = true,
    target = {},
    target_is_casting = true,
    me = {},
    settings = {},
}
assert_true(silence.matches(ctx_no_interrupt_api, state_ready), "Silence should match via target_is_casting fallback when unit_interruptible unavailable")
_G.EaxRotations.unit_interruptible = function(target)  -- Restore
    if target and target._interruptible ~= nil then return target._interruptible end
    return true
end

print("PASS test_shadow_silence_interrupt")
