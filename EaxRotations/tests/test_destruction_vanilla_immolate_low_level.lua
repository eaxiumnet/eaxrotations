-- test_destruction_vanilla_immolate_low_level.lua -- Destruction Vanilla Immolate low-level regression.
-- WHAT:  Verifies Immolate is not silently gated by spell-damage threshold at low level.
-- WHEN:  During rotation test suite execution.
-- WHY:   Low-level warlocks have <400 spell damage, so the SP gate would block Immolate entirely.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

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
    should_refresh_dot = function(remains, window, ttd, max) return true end,
    broken_api_throttled = function() return false end,
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

local result = dofile("EaxRotations/classes/warlock/destruction_vanilla.lua")
assert_true(result, "destruction vanilla module should load")
local strategies = result.strategies or result
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local immolate = find_strategy("Immolate")

-- Low level, low spell damage: Immolate should still match
local ctx_low = {
    target = {},
    settings = {},
    me = "player",
    level = 20,
    player_level = 20,
}
local state_low = { spell_damage = 50, immolate_remains = 0, level = 20 }
assert_true(immolate.matches(ctx_low, state_low), "Immolate should match at low level with low spell damage")

-- High level, low spell damage: Immolate should be gated by SP threshold
local ctx_high = {
    target = {},
    settings = {},
    me = "player",
    level = 70,
    player_level = 70,
}
local state_high = { spell_damage = 50, immolate_remains = 0, level = 70 }
assert_false(immolate.matches(ctx_high, state_high), "Immolate should be gated by spell damage at high level")

-- High level, sufficient spell damage: Immolate should match
local state_high_sp = { spell_damage = 500, immolate_remains = 0, level = 70 }
assert_true(immolate.matches(ctx_high, state_high_sp), "Immolate should match at high level with sufficient spell damage")

print("PASS test_destruction_vanilla_immolate_low_level")
