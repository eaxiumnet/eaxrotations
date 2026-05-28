-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_cat_custom_matches.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
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
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
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
    target = { _debuff_remains = 10 },
    ttd = 60,
}
assert_false(rip.matches(ctx_rip_fresh), "Rip should not match when debuff is fresh")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff expiring -> should match
action_calls = {}
local ctx_rip_refresh = {
    target = { _debuff_remains = 1 },
    ttd = 60,
}
assert_true(rip.matches(ctx_rip_refresh), "Rip should match when debuff needs refresh")

-- No target -> should return false
assert_false(rip.matches({}), "Rip should not match when target is nil")

-- ============================================================================
-- Rake: only refresh via should_refresh_dot
-- ============================================================================

local rake = find_strategy("Rake")

-- Debuff fresh -> should NOT match
action_calls = {}
local ctx_rake_fresh = {
    target = { _debuff_remains = 8 },
    ttd = 60,
}
assert_false(rake.matches(ctx_rake_fresh), "Rake should not match when debuff is fresh")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff expiring -> should match
action_calls = {}
local ctx_rake_refresh = {
    target = { _debuff_remains = 1 },
    ttd = 60,
}
assert_true(rake.matches(ctx_rake_refresh), "Rake should match when debuff needs refresh")

-- ============================================================================
-- Faerie Fire Feral: only when debuff absent/expiring and target lives long enough
-- ============================================================================

local faerie_fire = find_strategy("FaerieFireFeral")

-- Debuff fresh -> should NOT match
action_calls = {}
local ctx_ff_fresh = {
    target = { _debuff_remains = 10 },
    ttd = 60,
}
assert_false(faerie_fire.matches(ctx_ff_fresh), "FaerieFireFeral should not match when debuff > 3 sec")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff low but target dies soon -> should NOT match
action_calls = {}
local ctx_ff_low_ttd = {
    target = { _debuff_remains = 1 },
    ttd = 5,
}
assert_false(faerie_fire.matches(ctx_ff_low_ttd), "FaerieFireFeral should not match when ttd < 10")
assert_eq(#action_calls, 0, "action_matches should not be called when ttd < 10")

-- Debuff low, target lives long -> should match
action_calls = {}
local ctx_ff_ok = {
    target = { _debuff_remains = 1 },
    ttd = 30,
}
assert_true(faerie_fire.matches(ctx_ff_ok), "FaerieFireFeral should match when debuff low and ttd >= 10")

-- No target -> should return false
assert_false(faerie_fire.matches({}), "FaerieFireFeral should not match when target is nil")

-- ============================================================================
-- Tiger's Fury: only when energy won't cap and target lives long enough
-- ============================================================================

local tigers_fury = find_strategy("TigersFury")

-- Energy would cap -> should NOT match
action_calls = {}
local ctx_tf_cap = {
    me = {
        get_power = function(pt) return 60 end,
        get_max_power = function(pt) return 100 end,
    },
    ttd = 60,
}
assert_false(tigers_fury.matches(ctx_tf_cap), "TigersFury should not match when energy + 60 > max")
assert_eq(#action_calls, 0, "action_matches should not be called when energy would cap")

-- Target dies soon -> should NOT match
action_calls = {}
local ctx_tf_low_ttd = {
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
    ttd = 5,
}
assert_false(tigers_fury.matches(ctx_tf_low_ttd), "TigersFury should not match when ttd < 8")
assert_eq(#action_calls, 0, "action_matches should not be called when ttd < 8")

-- Energy low, target lives -> should match
action_calls = {}
local ctx_tf_ok = {
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
    ttd = 30,
}
assert_true(tigers_fury.matches(ctx_tf_ok), "TigersFury should match when energy low and ttd >= 8")

-- No me -> should return false
assert_false(tigers_fury.matches({}), "TigersFury should not match when me is nil")

-- ============================================================================
-- Omen of Clarity: only when buff is up and action is Shred
-- ============================================================================

local shred_omen = find_strategy("ShredOmen")

-- No Omen buff -> should NOT match
action_calls = {}
local ctx_omen_none = {
    me = { _buff_up = false },
}
assert_false(shred_omen.matches(ctx_omen_none), "ShredOmen should not match without Omen buff")
assert_eq(#action_calls, 0, "action_matches should not be called without Omen buff")

-- With Omen buff -> should match
action_calls = {}
local ctx_omen_up = {
    me = { _buff_up = true },
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
    settings = { pvp_mode = false },
    me = {},
}
assert_false(dash.matches(ctx_dash_pve), "Dash should not match in PvE")
assert_eq(#action_calls, 0, "action_matches should not be called in PvE")

-- PvP but target close -> should NOT match
action_calls = {}
local ctx_dash_close = {
    is_pvp = true,
    me = {
        get_distance = function() return 5 end,
    },
    target = {},
}
assert_false(dash.matches(ctx_dash_close), "Dash should not match when target < 10 yards")
assert_eq(#action_calls, 0, "action_matches should not be called when target close")

-- PvP, target far -> should match
action_calls = {}
local ctx_dash_far = {
    is_pvp = true,
    me = {
        get_distance = function() return 15 end,
    },
    target = {},
}
assert_true(dash.matches(ctx_dash_far), "Dash should match in PvP when target > 10 yards")

print("PASS test_cat_custom_matches")
