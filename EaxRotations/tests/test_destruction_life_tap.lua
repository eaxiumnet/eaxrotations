-- test_destruction_life_tap.lua -- Destruction Life Tap tests.
-- WHAT:  Destruction Life Tap anti-spam and threshold tests.
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against Life Tap double-casting in destruction spec.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

local action_calls = {}
local cast_count = 0
local current_time = 1000
_G.EaxRotations = {
    WarlockSpells = {},
    spell_action = function(spell_ids, name) return { spell = spell_ids, name = name } end,
    is_spell_learned = function(id) return true end,
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, label, opts) cast_count = cast_count + 1 return true end,
    log = function() end,
    time_now = function() return current_time end,
    rotation_registry = { register = function() end },
}

local orig_require = _G.require
_G.require = function(path)
    if type(path) == "string" and path:find("spec_kit_sylvanas") then
        return {
            define_action_for_class = function(_)
                return function(_, ids, name) return { ids = ids, name = name } end
            end,
            setting = function(ctx, key, default)
                local s = (ctx and ctx.settings) or {}
                return s[key] or default
            end,
            setting_number = function(ctx, key, default)
                local s = (ctx and ctx.settings) or {}
                return s[key] or default
            end,
            setting_bool = function(ctx, key, default)
                local s = (ctx and ctx.settings) or {}
                local v = s[key]
                if v == nil then return default end
                return v
            end,
            safe_state = function(raw, schema) return raw end,
        }
    end
    return orig_require(path)
end

local result = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(result, "destruction module should load")
local strategies = result.strategies
assert_true(strategies, "strategies table should load")

_G.require = orig_require

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local life_tap = find_strategy("LifeTap")

local ctx = {
    target = {},
    settings = {},
    me = "player",
}
local st = { mana_pct = 20, hp = 80 }

-- The spec loaded the batching engine; fetch the same instance it uses.
local lt_batch = require("shared/life_tap_batch_sylvanas")

-- First cast at t=1000 opens a batch.
cast_count = 0
action_calls = {}
current_time = 1000
assert_true(life_tap.matches(ctx, st), "LifeTap should match when mana is low and HP is safe")
assert_true(life_tap.execute(ctx, st) == true, "LifeTap first tap returns true")
assert_true(cast_count == 1, "LifeTap first tap casts exactly once")
assert_true(lt_batch.is_active(), "LifeTap first tap opens a batch")

-- Inside the batch the lane keeps claiming the tick so no filler can slot a
-- cast between two taps -- but it must HOLD, not cast, while the tap GCD runs.
cast_count = 0
action_calls = {}
current_time = 1001
assert_true(life_tap.matches(ctx, st), "LifeTap claims the tick inside the batch (hold)")
assert_true(life_tap.execute(ctx, st) == true, "LifeTap hold returns true")
assert_true(cast_count == 0, "LifeTap hold does NOT cast (no tap/cast ping-pong)")

-- Next GCD: still under the recover target -> a consecutive tap.
cast_count = 0
action_calls = {}
current_time = 1002
assert_true(life_tap.matches(ctx, st), "LifeTap should match after the tap GCD expires")
assert_true(life_tap.execute(ctx, st) == true, "LifeTap consecutive tap returns true")
assert_true(cast_count == 1, "LifeTap taps again on the next GCD (consecutive batch)")
assert_true(lt_batch.taps() >= 2, "LifeTap batch recorded two consecutive taps")

-- Batch exit: mana reaches the recover target -> the lane stops matching and
-- the once-per-tick housekeeping clears the batch so the entry threshold is
-- armed again (no hysteresis leak).
current_time = 3000
local st_full = { mana_pct = 50, hp = 80 }
assert_false(life_tap.matches(ctx, st_full), "LifeTap stops at the recover target")
lt_batch.observe(current_time, 50, 80, 20, 40, 50)
assert_false(lt_batch.is_active(), "LifeTap batch ends at the recover target")
assert_false(life_tap.matches(ctx, { mana_pct = 30, hp = 80 }),
    "LifeTap does not re-enter above the entry threshold after the batch ends")

-- Batch abort: HP falls below the safety gate mid-batch -> the lane holds off
-- and housekeeping drops the batch instead of stalling the rotation.
lt_batch.start(current_time, 40)
assert_false(life_tap.matches(ctx, { mana_pct = 20, hp = 30 }),
    "LifeTap holds off when HP is unsafe mid-batch")
lt_batch.observe(current_time, 20, 30, 20, 40, 50)
assert_false(lt_batch.is_active(), "LifeTap batch aborts when HP drops below the safety gate")

-- Stall self-heal: a batch that never lands a tap is treated as dead by the
-- read-only gate after the stall window, so the rotation can never stick.
lt_batch.reset()
current_time = 4000
lt_batch.start(current_time, 40)
assert_true(life_tap.matches(ctx, { mana_pct = 20, hp = 80 }),
    "LifeTap batch is live inside the stall window")
current_time = 4004
assert_false(life_tap.matches(ctx, { mana_pct = 20, hp = 80 }),
    "LifeTap batch self-heals after the stall window (no permanent hold)")
lt_batch.reset()

-- Should NOT match while casting
action_calls = {}
current_time = 2000
local ctx_casting = {
    target = {},
    settings = {},
    me = "player",
    is_casting = true,
}
assert_false(life_tap.matches(ctx_casting, st), "LifeTap should not match while casting")

-- Should NOT match while channeling
action_calls = {}
local ctx_channeling = {
    target = {},
    settings = {},
    me = "player",
    is_channeling = true,
}
assert_false(life_tap.matches(ctx_channeling, st), "LifeTap should not match while channeling")

print("PASS test_destruction_life_tap")
