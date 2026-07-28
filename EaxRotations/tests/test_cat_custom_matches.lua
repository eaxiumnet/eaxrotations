-- test_cat_custom_matches.lua -- Feral Cat custom match validation tests.
-- WHAT:  Feral Cat custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for cat_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local runner = require("EaxRotations/tests/test_runner_lib")
local Mock = runner.Mock

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
    try_cast = function(spell, target, label, opts) return true end,
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
local ctx_rip_fresh = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 35,
    target = { _debuff_remains = 10 },
    ttd = 60,
})
assert_false(rip.matches(ctx_rip_fresh), "Rip should not match when debuff is fresh")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff expiring -> should match
action_calls = {}
local ctx_rip_refresh = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 35,
    target = { _debuff_remains = 1 },
    ttd = 60,
})
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
local ctx_tf_combat = Mock.DefaultMeleeContext({
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
})
assert_true(tigers_fury.matches(ctx_tf_combat), "TigersFury should match in combat with low energy")
assert_eq(#action_calls, 0, "action_matches should not be called in combat")

-- In combat with 5cp and enough energy for Rip -> should NOT match (save for Rip)
action_calls = {}
local ctx_tf_rip_ready = Mock.DefaultMeleeContext({
    me = {
        get_power = function(pt) return 30 end,
        get_max_power = function(pt) return 100 end,
    },
    combo_points = 5,
})
assert_false(tigers_fury.matches(ctx_tf_rip_ready), "TigersFury should not match when Rip is ready")

-- Energy low, OOC -> should NOT match (prevents stealth break / wasted TF)
action_calls = {}
local ctx_tf_ooc = Mock.DefaultMeleeContext({
    in_combat = false,
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
})
assert_false(tigers_fury.matches(ctx_tf_ooc), "TigersFury should not match out of combat")

-- Energy low, in combat, but stealthed -> should NOT match
action_calls = {}
local ctx_tf_stealth = Mock.DefaultMeleeContext({
    in_combat = true,
    is_stealthed = true,
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
})
assert_false(tigers_fury.matches(ctx_tf_stealth), "TigersFury should not match while stealthed")

-- Energy low, in combat, not stealthed -> should match
action_calls = {}
local ctx_tf_ok = Mock.DefaultMeleeContext({
    in_combat = true,
    is_stealthed = false,
    me = {
        get_power = function(pt) return 20 end,
        get_max_power = function(pt) return 100 end,
    },
})
assert_true(tigers_fury.matches(ctx_tf_ok), "TigersFury should match in combat with low energy")

-- No me -> should return false
assert_false(tigers_fury.matches({}), "TigersFury should not match when me is nil")

-- ============================================================================
-- Omen of Clarity: only when buff is up and action is Shred
-- ============================================================================

local shred_omen = find_strategy("ShredOmen")

-- No Omen buff -> should NOT match
action_calls = {}
local ctx_omen_none = Mock.DefaultMeleeContext({
    me = { _buff_up = false },
})
assert_false(shred_omen.matches(ctx_omen_none), "ShredOmen should not match without Omen buff")
assert_eq(#action_calls, 0, "action_matches should not be called without Omen buff")

-- With Omen buff -> should match
action_calls = {}
local ctx_omen_up = Mock.DefaultMeleeContext({
    me = { _buff_up = true },
})
assert_true(shred_omen.matches(ctx_omen_up), "ShredOmen should match with Omen buff")

-- ============================================================================
-- Dash: only in PvP when target is far and not already dashing
-- ============================================================================

local dash = find_strategy("Dash")

-- Not PvP -> should NOT match
action_calls = {}
local ctx_dash_pve = Mock.DefaultMeleeContext({
    is_pvp = false,
    settings = { pvp_mode = false },
    me = {},
})
assert_false(dash.matches(ctx_dash_pve), "Dash should not match in PvE")
assert_eq(#action_calls, 0, "action_matches should not be called in PvE")

-- PvP but target close -> should NOT match
action_calls = {}
local ctx_dash_close = Mock.DefaultMeleeContext({
    is_pvp = true,
    me = {
        get_distance = function() return 5 end,
    },
})
assert_false(dash.matches(ctx_dash_close), "Dash should not match when target < 10 yards")
assert_eq(#action_calls, 0, "action_matches should not be called when target close")

-- PvP, target far -> should match
action_calls = {}
local ctx_dash_far = Mock.DefaultMeleeContext({
    is_pvp = true,
    me = {
        get_distance = function() return 15 end,
    },
})
assert_true(dash.matches(ctx_dash_far), "Dash should match in PvP when target > 10 yards")

-- ============================================================================
-- Pounce opener: should work in PvE when stealthed and OOC
-- ============================================================================

local pounce = find_strategy("PounceOpener")

-- OOC + stealthed + enough energy -> should match
action_calls = {}
local ctx_pounce_ok = Mock.DefaultMeleeContext({
    in_combat = false,
    is_stealthed = true,
})
assert_true(pounce.matches(ctx_pounce_ok), "PounceOpener should match when OOC, stealthed, and energy >= 50")

-- In combat -> should NOT match
action_calls = {}
local ctx_pounce_combat = Mock.DefaultMeleeContext({
    in_combat = true,
    is_stealthed = true,
})
assert_false(pounce.matches(ctx_pounce_combat), "PounceOpener should not match in combat")

-- Not stealthed -> should NOT match
action_calls = {}
local ctx_pounce_visible = Mock.DefaultMeleeContext({
    in_combat = false,
    is_stealthed = false,
})
assert_false(pounce.matches(ctx_pounce_visible), "PounceOpener should not match when not stealthed")

-- ============================================================================
-- Faerie Fire (Feral): should NOT match while stealthed
-- ============================================================================

local faerie_fire = find_strategy("FaerieFireFeral")

-- Not stealthed, debuff expired, target has armor -> should match
action_calls = {}
local ctx_ff_ok = Mock.DefaultMeleeContext({
    target = { _debuff_remains = 0 },
    target_armor = 100,
    is_stealthed = false,
})
assert_true(faerie_fire.matches(ctx_ff_ok), "FaerieFireFeral should match when not stealthed and debuff expired")

-- Stealthed -> should NOT match
action_calls = {}
local ctx_ff_stealth = Mock.DefaultMeleeContext({
    target = { _debuff_remains = 0 },
    target_armor = 100,
    is_stealthed = true,
})
assert_false(faerie_fire.matches(ctx_ff_stealth), "FaerieFireFeral should not match while stealthed")

-- ============================================================================
-- Faerie Fire (Stealth Lock): should ONLY match while stealthed in PvP
-- ============================================================================

local faerie_fire_stealth = find_strategy("FaerieFireStealthLock")

-- Stealthed, PvP target, debuff expired, target has armor -> should match
action_calls = {}
local ctx_ffs_ok = Mock.DefaultMeleeContext({
    is_pvp = true,
    is_stealthed = true,
    target = { _debuff_remains = 0 },
    target_armor = 100,
})
assert_true(faerie_fire_stealth.matches(ctx_ffs_ok), "FaerieFireStealthLock should match when stealthed in PvP")

-- Not stealthed -> should NOT match
action_calls = {}
local ctx_ffs_visible = Mock.DefaultMeleeContext({
    is_pvp = true,
    is_stealthed = false,
    target = { _debuff_remains = 0 },
    target_armor = 100,
})
assert_false(faerie_fire_stealth.matches(ctx_ffs_visible), "FaerieFireStealthLock should not match when not stealthed")

-- ============================================================================
-- Ferocious Bite (execute): should fire at full CP while Rip is up
-- ============================================================================

local bite = find_strategy("FerociousBite")

-- Full CP, Rip up, long TTD -> should match
action_calls = {}
local ctx_bite_ok = Mock.DefaultMeleeContext({
    combo_points = 5,
    target = { _debuff_remains = 10 },
    target_ttd = 60,
})
assert_true(bite.matches(ctx_bite_ok), "FerociousBite should match at full CP while Rip is up")

-- Low CP -> should NOT match
action_calls = {}
local ctx_bite_low_cp = Mock.DefaultMeleeContext({
    combo_points = 2,
    target = { _debuff_remains = 10 },
    target_ttd = 60,
})
assert_false(bite.matches(ctx_bite_low_cp), "FerociousBite should not match with low CP")

-- Full CP, Rip down, normal mob with cat_rip_elites_only enabled -> should bite
action_calls = {}
local ctx_bite_elite_only = Mock.DefaultMeleeContext({
    combo_points = 5,
    settings = { cat_rip_elites_only = true, cat_use_rip = true },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
    target_is_boss = false,
    target_classification = 0,
})
assert_true(bite.matches(ctx_bite_elite_only), "FerociousBite should bite non-elites when Rip is elite-only")

-- ============================================================================
-- Rip: respect cat_rip_elites_only setting
-- ============================================================================

-- Elite/boss target with cat_rip_elites_only enabled -> Rip should match
action_calls = {}
local ctx_rip_elite = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 35,
    settings = { cat_rip_elites_only = true, cat_use_rip = true },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
    target_is_boss = true,
    target_classification = 3,
})
assert_true(rip.matches(ctx_rip_elite), "Rip should match elite/boss when cat_rip_elites_only is enabled")

-- Normal mob with cat_rip_elites_only enabled -> Rip should NOT match
action_calls = {}
local ctx_rip_normal = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 35,
    settings = { cat_rip_elites_only = true, cat_use_rip = true },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
    target_is_boss = false,
    target_classification = 0,
})
assert_false(rip.matches(ctx_rip_normal), "Rip should not match normal mob when cat_rip_elites_only is enabled")

-- cat_use_rip disabled -> Rip should NOT match
action_calls = {}
local ctx_rip_disabled = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 35,
    settings = { cat_use_rip = false },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
})
assert_false(rip.matches(ctx_rip_disabled), "Rip should not match when cat_use_rip is disabled")

-- ============================================================================
-- Rake / Rip post-cast grace: don't recast while debuff is still applying
-- ============================================================================

local rake = find_strategy("Rake")

-- Cast Rake at t=0, then at t=0.5 debuff remains is still 0 (latency) -> should NOT match
local ctx_rake_cast = Mock.DefaultMeleeContext({
    now = 0,
    energy = 100,
    target = { _debuff_remains = 0 },
    target_ttd = 60,
})
rake.execute(ctx_rake_cast)

action_calls = {}
local ctx_rake_latent = Mock.DefaultMeleeContext({
    now = 0.5,
    energy = 100,
    target = { _debuff_remains = 0 },
    target_ttd = 60,
})
assert_false(rake.matches(ctx_rake_latent), "Rake should not match within the post-cast grace window when debuff is not yet visible")

-- After the grace window, debuff still not visible -> should match again
action_calls = {}
local ctx_rake_after_grace = Mock.DefaultMeleeContext({
    now = 2.0,
    energy = 100,
    target = { _debuff_remains = 0 },
    target_ttd = 60,
})
assert_true(rake.matches(ctx_rake_after_grace), "Rake should match again after the post-cast grace window if debuff is still missing")

-- Same for Rip: cast at t=0, then at t=0.5 debuff remains is still 0 -> should NOT match
local ctx_rip_cast = Mock.DefaultMeleeContext({
    now = 0,
    combo_points = 5,
    energy = 100,
    settings = { cat_use_rip = true },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
    target_is_boss = true,
    target_classification = 3,
})
rip.execute(ctx_rip_cast)

action_calls = {}
local ctx_rip_latent = Mock.DefaultMeleeContext({
    now = 0.5,
    combo_points = 5,
    energy = 100,
    settings = { cat_use_rip = true },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
    target_is_boss = true,
    target_classification = 3,
})
assert_false(rip.matches(ctx_rip_latent), "Rip should not match within the post-cast grace window when debuff is not yet visible")

-- After the grace window -> should match again
action_calls = {}
local ctx_rip_after_grace = Mock.DefaultMeleeContext({
    now = 2.0,
    combo_points = 5,
    energy = 100,
    settings = { cat_use_rip = true },
    target = { _debuff_remains = 0 },
    target_ttd = 60,
    target_is_boss = true,
    target_classification = 3,
})
assert_true(rip.matches(ctx_rip_after_grace), "Rip should match again after the post-cast grace window if debuff is still missing")

-- ============================================================================
-- Combo-point fallback path coverage
-- The original bug: finishers never fired when the only available combo-point
-- source was an API method instead of context.combo_points.  get_combo_points()
-- now falls back through context.cp, NS.combo_points, NS.get_combo_points,
-- me.combo_points_current, me.get_combo_points, and me.get_power(4).
-- ============================================================================

local _test_now = 2.0
local function next_now()
    _test_now = _test_now + 0.1
    return _test_now
end

local function ctx_with_cp(cp_overrides)
    local ctx = Mock.DefaultMeleeContext({
        combo_points = nil, -- nil here is ignored by pairs; cleared below
        energy = 100,
        now = next_now(), -- unique timestamp so build_state isn't cached from a previous context
        target = { _debuff_remains = 0 },
        me = cp_overrides.me,
    })
    ctx.combo_points = nil -- clear the default 0 so the fallback path is exercised
    return ctx
end

local shred_strategy = find_strategy("Shred")

local function assert_5cp_finisher(source, ctx)
    action_calls = {}
    assert_true(rip.matches(ctx), "Rip should match at 5 CP via " .. source)
    action_calls = {}
    assert_false(shred_strategy.matches(ctx), "Shred should not waste CP at 5 CP via " .. source)
end

-- 1. context.combo_points (primary, already covered elsewhere, used as sanity check)
local ctx_cp_primary = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 100,
    now = next_now(),
    target = { _debuff_remains = 0 },
})
assert_5cp_finisher("context.combo_points", ctx_cp_primary)

-- 2. context.cp alternate field
local ctx_cp_alt = Mock.DefaultMeleeContext({
    cp = 5,
    energy = 100,
    now = next_now(),
    target = { _debuff_remains = 0 },
})
ctx_cp_alt.combo_points = nil -- clear the default 0 so the cp fallback is exercised
assert_5cp_finisher("context.cp", ctx_cp_alt)

-- 3. me.combo_points_current fallback
local ctx_me_combo_points_current = ctx_with_cp({
    me = {
        combo_points_current = function(self) return 5 end,
        get_power = function(self, pt) return nil end,
        get_max_power = function() return 100 end,
        get_health_percentage = function() return 100 end,
    },
})
assert_5cp_finisher("me.combo_points_current", ctx_me_combo_points_current)

-- 4. me.get_combo_points fallback
local ctx_me_get_combo_points = ctx_with_cp({
    me = {
        get_combo_points = function(self, target) return 5 end,
        get_power = function(self, pt) return nil end,
        get_max_power = function() return 100 end,
        get_health_percentage = function() return 100 end,
    },
})
assert_5cp_finisher("me.get_combo_points", ctx_me_get_combo_points)

-- 5. me.get_power(4) fallback (power type 4 == combo points)
local ctx_me_get_power = ctx_with_cp({
    me = {
        get_power = function(self, pt)
            if pt == 4 then return 5 end
            return 0
        end,
        get_max_power = function() return 100 end,
        get_health_percentage = function() return 100 end,
    },
})
assert_5cp_finisher("me.get_power(4)", ctx_me_get_power)

-- ============================================================================
-- Bite energy cap: default of 100 lets Bite fire; old default of 39 blocked it.
-- ============================================================================

local bite_trick = find_strategy("BiteTrick")

-- Rip already up (so Rip defers), 5 CP, plenty of energy, default cap
local ctx_bite_default_cap = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 80,
    now = next_now(),
    target = { _debuff_remains = 12 },
})
action_calls = {}
assert_true(bite_trick.matches(ctx_bite_default_cap), "BiteTrick should fire with default cap 100 at 80 energy")

-- Same context but with the old 39 cap should block BiteTrick
local ctx_bite_old_cap = Mock.DefaultMeleeContext({
    combo_points = 5,
    energy = 80,
    now = next_now(),
    target = { _debuff_remains = 12 },
    settings = { cat_bite_max_energy = 39 },
})
action_calls = {}
assert_false(bite_trick.matches(ctx_bite_old_cap), "BiteTrick should be blocked with old cap 39")

print("PASS test_cat_custom_matches")
