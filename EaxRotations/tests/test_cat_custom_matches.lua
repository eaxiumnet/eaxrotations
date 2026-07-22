-- test_cat_custom_matches.lua -- Feral Cat custom match validation tests.
-- WHAT:  Feral Cat custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for cat_sylvanas custom matches functions.

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
    DruidSpells = {
        Shred = 5221,
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    debuff_remains = function(target, debuff_list)
        return target and target._debuff_remains or 0
    end,
    buff_up = function(me, buff_list)
        return me and me._buff_up or false
    end,
    should_refresh_dot = function(remains, refresh, ttd, duration)
        -- Simple logic: refresh if remains < refresh and ttd > duration * 0.5
        if remains < refresh then
            if ttd and ttd > duration * 0.5 then return true end
            if not ttd then return true end
        end
        return false
    end,
    is_spell_learned = function(spell_id)
        return true
    end,
    setting_number = function(settings, key, default)
        return type(settings) == "table" and type(settings[key]) == "number" and settings[key] or default
    end,
    setting_bool = function(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local result = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
local strategies = result.strategies or result
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
-- Rip: only refresh via should_refresh_dot
-- ============================================================================

local rip = find_strategy("Rip")

-- Debuff fresh -> should NOT match
action_calls = {}
local ctx_rip_fresh = {
    combo_points = 5,
    energy = 35,
    is_cat = true,
    target = { _debuff_remains = 10 },
    ttd = 60,
}
assert_false(rip.matches(ctx_rip_fresh), "Rip should not match when debuff is fresh")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff expiring -> should match
action_calls = {}
local ctx_rip_refresh = {
    combo_points = 5,
    energy = 35,
    is_cat = true,
    target = { _debuff_remains = 1 },
    ttd = 60,
}
assert_true(rip.matches(ctx_rip_refresh), "Rip should match when debuff needs refresh")

-- No target -> should return false
assert_false(rip.matches({}), "Rip should not match when target is nil")

-- ============================================================================
-- Tiger's Fury: only when energy won't cap and target lives long enough
-- ============================================================================

local tigers_fury = find_strategy("TigersFury")

-- Energy would cap -> should NOT match
action_calls = {}
local ctx_tf_cap = {
    is_cat = true,
    me = {
        get_power = function(pt) return 60 end,
        get_max_power = function(pt) return 100 end,
    },
}
assert_false(tigers_fury.matches(ctx_tf_cap), "TigersFury should not match when energy + 60 > max")
assert_eq(#action_calls, 0, "action_matches should not be called when energy would cap")

-- In combat with low energy -> should match (mid-combat use enabled)
action_calls = {}
local ctx_tf_combat = {
    is_cat = true,
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
    in_combat = true,
}
assert_true(tigers_fury.matches(ctx_tf_combat), "TigersFury should match in combat with low energy")
assert_eq(#action_calls, 0, "action_matches should not be called in combat")

-- In combat with 5cp and enough energy for Rip -> should NOT match (save for Rip)
action_calls = {}
local ctx_tf_rip_ready = {
    is_cat = true,
    me = {
        get_power = function(pt) return 30 end,
        get_max_power = function(pt) return 100 end,
    },
    in_combat = true,
    combo_points = 5,
}
assert_false(tigers_fury.matches(ctx_tf_rip_ready), "TigersFury should not match when Rip is ready")

-- Energy low, OOC -> should match (pre-cast opener)
action_calls = {}
local ctx_tf_ok = {
    is_cat = true,
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
    in_combat = true,
}
assert_true(tigers_fury.matches(ctx_tf_ok), "TigersFury should match in combat with low energy")

-- No me -> should return false
assert_false(tigers_fury.matches({}), "TigersFury should not match when me is nil")

-- ============================================================================
-- Omen of Clarity: only when buff is up and action is Shred
-- ============================================================================

local shred_omen = find_strategy("ShredOmen")

-- No Omen buff -> should NOT match
action_calls = {}
local ctx_omen_none = {
    is_cat = true,
    is_behind = true,
    me = { _buff_up = false },
    target = {},
    in_combat = true,
}
assert_false(shred_omen.matches(ctx_omen_none), "ShredOmen should not match without Omen buff")
assert_eq(#action_calls, 0, "action_matches should not be called without Omen buff")

-- With Omen buff -> should match
action_calls = {}
local ctx_omen_up = {
    is_cat = true,
    is_behind = true,
    me = { _buff_up = true },
    target = {},
    in_combat = true,
}
assert_true(shred_omen.matches(ctx_omen_up), "ShredOmen should match with Omen buff")

-- ============================================================================
-- Dash: only in PvP when target is far and not already dashing
-- ============================================================================

local dash = find_strategy("Dash")

-- Not PvP -> should NOT match
action_calls = {}
local ctx_dash_pve = {
    is_pvp = false,
    is_cat = true,
    settings = { pvp_mode = false },
    me = {},
    in_combat = true,
}
assert_false(dash.matches(ctx_dash_pve), "Dash should not match in PvE")
assert_eq(#action_calls, 0, "action_matches should not be called in PvE")

-- PvP but target close -> should NOT match
action_calls = {}
local ctx_dash_close = {
    is_pvp = true,
    is_cat = true,
    me = {
        get_distance = function() return 5 end,
    },
    target = {},
    in_combat = true,
}
assert_false(dash.matches(ctx_dash_close), "Dash should not match when target < 10 yards")
assert_eq(#action_calls, 0, "action_matches should not be called when target close")

-- PvP, target far -> should match
action_calls = {}
local ctx_dash_far = {
    is_pvp = true,
    is_cat = true,
    me = {
        get_distance = function() return 15 end,
    },
    target = {},
    in_combat = true,
}
assert_true(dash.matches(ctx_dash_far), "Dash should match in PvP when target > 10 yards")

print("PASS test_cat_custom_matches")
