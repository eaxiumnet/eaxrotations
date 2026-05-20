-- unit tests for destruction_sylvanas Shadowburn execute logic.
-- Verifies Shadowburn fires only when target is in execute range and soul shard is available.

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
    WarlockSpells = {
        Shadowburn = 17877,
        Immolate = 348,
        Conflagrate = 17962,
        Incinerate = 29722,
        ShadowBolt = 27209,
        Corruption = 172,
        CurseOfAgony = 27218,
        CurseOfDoom = 27214,
        SearingPain = 27215,
        SoulFire = 29858,
        DeathCoil = 2894,
        Fear = 6215,
        RainOfFire = 27211,
        Hellfire = 27213,
        SeedOfCorruption = 27243,
        DrainLife = 27217,
        LifeTap = 1454,
        DarkPact = 27220,
        HealthFunnel = 30656,
        FelArmor = 28176,
        DemonArmor = 27299,
        ShadowWard = 28648,
        CreateHealthstone = 6201,
        SummonImp = 688,
        SummonVoidwalker = 697,
        SummonSuccubus = 712,
        SummonFelhunter = 691,
        SummonFelguard = 30146,
        FelDomination = 19028,
    },
    has_item = function(item_id)
        action_calls[#action_calls + 1] = { fn = "has_item", item_id = item_id }
        return true  -- Has soul shard by default
    end,
    is_execute_phase = function(target_hp, pct)
        action_calls[#action_calls + 1] = { fn = "is_execute_phase", target_hp = target_hp, pct = pct }
        return target_hp <= pct
    end,
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_action = function(spell_ids, name)
        return { spell = spell_ids, name = name }
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warlock/destruction_sylvanas.lua")
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries")

-- Helper to find strategy by name
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Shadowburn: only when soul shard available AND target in execute range (<=20%)
-- ============================================================================

local shadowburn = find_strategy("Shadowburn")

-- Target in execute range (HP <= 20%), has soul shard -> should match
action_calls = {}
local ctx_execute = {
    target = {},
    target_hp = 15,
    state = { hp = 100, mana_pct = 80 },
}
assert_true(shadowburn.matches(ctx_execute), "Shadowburn should match when target in execute range and has soul shard")

-- Target NOT in execute range (HP > 20%) -> should NOT match
action_calls = {}
local ctx_no_execute = {
    target = {},
    target_hp = 50,
    state = { hp = 100, mana_pct = 80 },
}
assert_false(shadowburn.matches(ctx_no_execute), "Shadowburn should not match when target HP > 20%")

-- No target -> should return false (no context.target means can't fire)
local ctx_no_target = {
    target_hp = 999,
    state = { hp = 100, mana_pct = 80 },
}
assert_false(shadowburn.matches(ctx_no_target), "Shadowburn should not match when no target")

-- Boundary: target_hp exactly 20% -> should match
action_calls = {}
local ctx_boundary = {
    target = {},
    target_hp = 20,
    state = { hp = 100, mana_pct = 80 },
}
assert_true(shadowburn.matches(ctx_boundary), "Shadowburn should match when target_hp == 20 (boundary)")

print("PASS test_destruction_shadowburn")
