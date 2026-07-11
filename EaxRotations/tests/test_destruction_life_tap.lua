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
local current_time = 1000
_G.EaxRotations = {
    WarlockSpells = {},
    spell_action = function(spell_ids, name) return { spell = spell_ids, name = name } end,
    is_spell_learned = function(id) return true end,
    spell_ready = function(spell, target, opts) return true end,
    try_cast = function(spell, target, label, opts) return true end,
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

-- First cast at t=1000
action_calls = {}
current_time = 1000
assert_true(life_tap.matches(ctx, st), "LifeTap should match when mana is low and HP is safe")
life_tap.execute(ctx)

-- Immediately after cast, should NOT match again
action_calls = {}
current_time = 1001
assert_false(life_tap.matches(ctx, st), "LifeTap should not match immediately after cast")

-- After throttle window expires, should match again
action_calls = {}
current_time = 1002
assert_true(life_tap.matches(ctx, st), "LifeTap should match after throttle window expires")

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
