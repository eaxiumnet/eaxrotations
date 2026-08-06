-- test_feral_druid_finisher_bear_rage_review.lua -- Feral Cat finisher resource regressions.
-- WHAT:  reproduces Rip/Bite being gated by a stale dispatcher combo-point zero.
-- WHEN:  run directly from C:\newbot\scripts with the focused Lua command.
-- WHY:   preserves authoritative player CP without relaxing Cat finisher gates.
-- SAFETY: mocked Cat objects only; no bear behavior is exercised or changed.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local failures = 0

local function expect_true(name, actual)
    if actual then
        print("PASS " .. name .. " actual=true")
    else
        failures = failures + 1
        print("FAIL " .. name .. " expected=true actual=false")
    end
end

local function expect_false(name, actual)
    expect_true(name, not actual)
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function base_namespace()
    return {
        DruidSpells = {},
        POWER_COMBO = 4,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        is_spell_learned = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_remains = function(target) return target and target._debuff_remains or 0 end,
        get_debuff_stacks = function(target) return target and target._debuff_stacks or 0 end,
        has_form = function(form) return form == "cat" or form == "bear" end,
        is_behind_target = function() return true end,
        GetPlayer = function() return nil end,
        log = function() end,
        rotation_registry = { register = function() end },
    }
end

-- Reported cat state: the dispatcher supplies numeric combo_points=0, which
-- short-circuits the player fallback even though get_power(4) reports 5.
local cat_namespace = base_namespace()
_G.EaxRotations = cat_namespace
local cat = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
local rip = find_strategy(cat.strategies, "Rip")
local bite = find_strategy(cat.strategies, "FerociousBite")
local cat_player = {
    combo_points_current = function() return 0 end,
    get_power = function(_, power_type)
        if power_type == 4 then return 5 end
        if power_type == 3 then return 100 end
        return 0
    end,
    get_max_power = function() return 100 end,
    get_health_percentage = function() return 100 end,
}
local function cat_context(remains, overrides)
    local context = {
        me = cat_player,
        target = { _debuff_remains = remains },
        has_valid_enemy_target = true,
        in_combat = true,
        is_cat = true,
        is_behind = true,
        target_range = 5,
        energy = 100,
        combo_points = 0,
        ttd = 60,
        target_ttd = 60,
        level = 70,
        settings = { cat_rip_cp = 5, cat_ferocious_bite_cp = 5, cat_use_rip = true },
    }
    for key, value in pairs(overrides or {}) do context[key] = value end
    return context
end

expect_true("cat Rip at player-reported 5 combo points", rip.matches(cat_context(0)))
expect_true("cat Ferocious Bite at player-reported 5 combo points", bite.matches(cat_context(10)))

local has_form = cat_namespace.has_form
cat_namespace.has_form = function() return false end
expect_false("Rip Cat form gate remains enforced", rip.matches(cat_context(0, { is_cat = false })))
cat_namespace.has_form = has_form

local zero_player = {
    combo_points_current = function() return 0 end,
    get_power = function(_, power_type)
        if power_type == 3 then return 100 end
        return 0
    end,
    get_max_power = function() return 100 end,
    get_health_percentage = function() return 100 end,
}
expect_false("real zero combo points still blocks Rip", rip.matches(cat_context(0, { me = zero_player })))
expect_false("Rip energy gate remains enforced", rip.matches(cat_context(0, { energy = 0 })))
expect_false("Ferocious Bite energy gate remains enforced", bite.matches(cat_context(10, { energy = 0 })))
expect_false("Rip TTD gate remains enforced", rip.matches(cat_context(0, { ttd = 9, target_ttd = 9 })))
expect_false("Rip setting gate remains enforced", rip.matches(cat_context(0, {
    settings = { cat_rip_cp = 5, cat_ferocious_bite_cp = 5, cat_use_rip = false },
})))
local rip_snapshot = find_strategy(cat.strategies, "RipSnapshot")
expect_false("Rip snapshot gate still needs an upgrade", rip_snapshot.matches(cat_context(10)))

if failures > 0 then
    error("failing-first reproduction: " .. tostring(failures) .. " assertion(s) failed", 0)
end

print("PASS test_feral_druid_finisher_bear_rage_review")
