-- test_warrior_stance_detector.lua -- unified warrior stance truth.
-- WHAT:  pins shared/warrior_stance_sylvanas.lua and its fury/arms consumers.
-- WHY:   three disagreeing stance sources caused the live Battle/Berserker
--        ping-pong (2026-09-14 logs). The aura NAMES the stance (the source
--        the druid form wave proved truthful); the number only corroborates.
-- SAFETY: pure unit tests, mocked namespace.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local pass_count, test_count = 0, 0
local function assert_true(v, label)
    test_count = test_count + 1
    if not v then error("FAIL: " .. (label or "assert_true"), 2) end
    pass_count = pass_count + 1
end
local function assert_false(v, label)
    test_count = test_count + 1
    if v then error("FAIL: " .. (label or "assert_false"), 2) end
    pass_count = pass_count + 1
end
local function assert_eq(a, b, label)
    test_count = test_count + 1
    if a ~= b then error("FAIL: " .. (label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
    pass_count = pass_count + 1
end

-- ============================================================================
-- Module-level contract (detector in isolation)
-- ============================================================================

local _G_meta = _G
local aura_state = { battle = false, defensive = false, berserker = false }
local engine_stance = 0

_G.EaxRotations = {
    WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } },
    log = function() end,
    has_form = function(name)
        if name == "battle" then return aura_state.battle end
        if name == "defensive" then return aura_state.defensive end
        if name == "berserker" then return aura_state.berserker end
        return false
    end,
    get_player_stance = function() return engine_stance end,
}

local sm = require("shared/warrior_stance_sylvanas")

-- S1: no sources at all -> nil (unknown), never a guess
aura_state.battle, aura_state.defensive, aura_state.berserker = false, false, false
engine_stance = 0
assert_eq(sm.current({}), nil, "no aura + no number -> nil")
assert_eq(sm.current_id({}), nil, "no sources -> no id")
assert_false(sm.is_stance({}, "berserker"), "unknown is not berserker")

-- S2: aura names berserker, engine number disagrees (the live failure shape)
aura_state.berserker = true
engine_stance = 1  -- engine claims Battle while the aura says Berserker
assert_eq(sm.current({}), "berserker", "aura WINS over a disagreeing number")
assert_eq(sm.current_id({}), 3, "aura answer maps to berserker id")

-- S3: aura silent, number present -> number corroborated through constants
aura_state.berserker = false
engine_stance = 2
assert_eq(sm.current({}), "defensive", "number-only answer names through constants")
assert_eq(sm.current_id({}), 2, "number-only id")

-- S4: number is garbage/unknown scale -> generic "stance", no wrong name
engine_stance = 9
assert_eq(sm.current({}), "stance", "unknown number -> generic, never a guessed name")
assert_eq(sm.current_id({}), nil, "generic answer has no id")

-- S5: aura present + number 0 (known dead-read on live builds) -> aura trusted
engine_stance = 0
aura_state.battle = true
assert_eq(sm.current({}), "battle", "aura trusted while number reads 0")
aura_state.battle = false

-- S6: context.stance fast path beats re-querying
engine_stance = 3
assert_eq(sm.current({ stance = 1 }), "battle", "context.stance fast path honoured")
engine_stance = 0

-- ============================================================================
-- Fury consumer: berserker/battle lanes must hold on named aura and fire on
-- the aura answer even when the engine number is wrong or zero
-- ============================================================================

-- Fury spec load requires its full NS surface; reuse the existing DSL mock shape
local clock = 100  -- mutated by tests; time_now closes over this upvalue
local mock_shout_remains = 0
local mock_rampage_remains = 0
_G.EaxRotations = {
    WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } },
    log = function() end,
    log_warning = function() end,
    GetPlayer = function() return {} end,
    get_setting = function(_, default) return default end,
    -- stance_lockout reads the clock; without it the mock lockout is
    -- permanently active (0 < 0+2.0) and every stance lane holds
    time_now = function() return clock end,
    buff_remains = function(unit, ids)
        if type(ids) == "table" and ids[1] == 25289 then return mock_shout_remains end
        return mock_rampage_remains
    end,
    buff_up = function() return false end,
    debuff_stacks = function() return 0 end,
    debuff_remains = function() return 0 end,
    cooldown_remains = function() return 99 end,
    -- must be true: stance lanes end in action() -> spell_ready, so a false
    -- here would mask the detector verdict the suite is pinning
    spell_ready = function() return true end,
    rotation_registry = { register = function() end },
    -- engine stance source (context.stance absent paths)
    get_player_stance = function() return engine_stance end,
    has_form = function(name)
        if name == "battle" then return aura_state.battle end
        if name == "defensive" then return aura_state.defensive end
        if name == "berserker" then return aura_state.berserker end
        return false
    end,
}
sm = require("shared/warrior_stance_sylvanas")  -- rebind to the fresh NS
package.loaded["shared/warrior_stance_sylvanas"] = nil
sm = require("shared/warrior_stance_sylvanas")
aura_state = { battle = false, defensive = false, berserker = false }

local fury = require("classes/warrior/fury_sylvanas")

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local berserker_lane = find_strategy(fury.strategies, "BerserkerStance")
local battle_lane = find_strategy(fury.strategies, "BattleStance")

-- F1: in berserker (by AURA, number wrong) -> the berserker lane must hold.
--     The old code trusted the number OR the aura; the unified detector must
--     hold on the aura alone. state.stance is what build_state would have
--     corrected it to (the aura answer) -- but the lane also reads context via
--     the detector, so drive the disagreement directly.
aura_state.berserker = true
engine_stance = 0  -- dead read, the live shape
local ctx = {}
assert_false(berserker_lane.matches(ctx, { rage = 50, bt_ready = true }),
    "berserker lane holds while the aura names Berserker (even with number 0)")

-- F2: not in berserker by any source -> lane may fire
aura_state.berserker = false
engine_stance = 0
clock = 200  -- past the 2s stance lockout of the last mocked stance cast
assert_true(berserker_lane.matches({ rage = 50 }, { rage = 50, bt_ready = true, stance = 2 }),
    "berserker lane fires with no aura (number 2 = defensive preserved rage)")

-- F3: in battle by aura -> battle lane holds, berserker lane free to swap
aura_state.battle = true
engine_stance = 0
assert_false(battle_lane.matches(ctx, { rage = 50, overpower_ready = true }),
    "battle lane holds while the aura names Battle")
assert_true(berserker_lane.matches({ rage = 50 }, { rage = 50, bt_ready = true, stance = 1 }),
    "berserker swap allowed while in battle stance")
aura_state.battle = false

-- F4: stance_lockout still honoured (guard order preserved)
-- (lockout is time-based via WH; the lockout path is pinned by the pre-module
--  suite -- here we pin that the aura check comes before lockout can be bypassed)
aura_state.berserker = true
assert_false(berserker_lane.matches(ctx, { rage = 50, bt_ready = true }),
    "aura hold is unconditional")
aura_state.berserker = false

print(string.format("PASS test_warrior_stance_detector (%d/%d assertions)", pass_count, test_count))
