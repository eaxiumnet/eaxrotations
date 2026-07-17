-- test_warlock_affliction_wotlk.lua — WotLK Affliction warlock rotation logic tests.
-- WHAT:  Verifies DoT maintenance and Drain Soul execute logic.
-- WHEN:  During WotLK test suite execution.
-- WHY:   Regression guard for Affliction warlock rotation decisions.
-- SAFETY: Uses synthetic context; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

_G.EaxRotations = {
    WarlockSpells = {
        UnstableAffliction = make_action(30405, "UnstableAffliction"),
        Haunt = make_action(48181, "Haunt"),
        Corruption = make_action(27216, "Corruption"),
        CurseOfAgony = make_action(27218, "CurseOfAgony"),
        DrainSoul = make_action(27217, "DrainSoul"),
        ShadowBolt = make_action(27209, "ShadowBolt"),
    },
    me = {
        get_health_percentage = function() return 80 end,
        get_mana_percentage = function() return 80 end,
    },
    debuff_remains = function(unit, ids) return 0 end,
    rotation_registry = {
        register = function(self, name, strategies, options)
        end,
    },
    log = function() end,
}

package.loaded["shared/potion_helper_sylvanas"] =
    { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {} }

print("=== test_warlock_affliction_wotlk ===")

local affliction = dofile("EaxRotations/classes/warlock/affliction_wotlk.lua")
assert_true(type(affliction) == "table", "affliction_wotlk should return a table")
assert_true(type(affliction.strategies) == "table", "affliction_wotlk should expose strategies")
assert_true(type(affliction.build_state) == "function", "affliction_wotlk should expose build_state")

local function find_strategy(strats, name)
    for i = 1, #strats do
        if strats[i].name == name then return strats[i] end
    end
    error("strategy not found: " .. name, 2)
end

local haunt = find_strategy(affliction.strategies, "Haunt")
local unstable = find_strategy(affliction.strategies, "UnstableAffliction")
local corruption = find_strategy(affliction.strategies, "Corruption")
local curse_of_agony = find_strategy(affliction.strategies, "CurseOfAgony")
local drain_soul = find_strategy(affliction.strategies, "DrainSoul")
local shadow_bolt = find_strategy(affliction.strategies, "ShadowBolt")

local ctx = { in_combat = true, target = { get_health_percentage = function() return 80 end }, settings = {} }

-- All DoTs missing -> every DoT strategy should match
_G.EaxRotations.debuff_remains = function(unit, ids) return 0 end
local state_dots_missing = affliction.build_state(ctx)

assert_true(haunt.matches(ctx, state_dots_missing), "Haunt should match when Haunt debuff is missing")
assert_true(unstable.matches(ctx, state_dots_missing), "UnstableAffliction should match when debuff is missing")
assert_true(corruption.matches(ctx, state_dots_missing), "Corruption should match when debuff is missing")
assert_true(curse_of_agony.matches(ctx, state_dots_missing), "CurseOfAgony should match when debuff is missing")

-- All DoTs healthy -> no DoT strategy should match
_G.EaxRotations.debuff_remains = function(unit, ids) return 10 end
local state_dots_healthy = affliction.build_state(ctx)

assert_false(haunt.matches(ctx, state_dots_healthy), "Haunt should not match when debuff is healthy")
assert_false(unstable.matches(ctx, state_dots_healthy), "UnstableAffliction should not match when debuff is healthy")
assert_false(corruption.matches(ctx, state_dots_healthy), "Corruption should not match when debuff is healthy")
assert_false(curse_of_agony.matches(ctx, state_dots_healthy), "CurseOfAgony should not match when debuff is healthy")

-- DoTs about to expire (<3s) -> every DoT strategy should match
_G.EaxRotations.debuff_remains = function(unit, ids) return 2 end
local state_dots_refresh = affliction.build_state(ctx)

assert_true(haunt.matches(ctx, state_dots_refresh), "Haunt should match when debuff is about to expire")
assert_true(unstable.matches(ctx, state_dots_refresh), "UnstableAffliction should match when debuff is about to expire")
assert_true(corruption.matches(ctx, state_dots_refresh), "Corruption should match when debuff is about to expire")
assert_true(curse_of_agony.matches(ctx, state_dots_refresh), "CurseOfAgony should match when debuff is about to expire")

-- Drain Soul execute: target HP < 25%
local state_execute = affliction.build_state({ in_combat = true, target = { get_health_percentage = function() return 15 end }, settings = {} })
assert_true(drain_soul.matches(ctx, state_execute), "DrainSoul should match when target HP < 25%")

local state_no_execute = affliction.build_state({ in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {} })
assert_false(drain_soul.matches(ctx, state_no_execute), "DrainSoul should not match when target HP >= 25%")

-- ShadowBolt filler: mana >= 20%
local state_mana_ok = affliction.build_state({ in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {} })
assert_true(shadow_bolt.matches(ctx, state_mana_ok), "ShadowBolt should match when mana >= 20%")

local state_low_mana = affliction.build_state({ in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {} })
state_low_mana.mana_pct = 15
assert_false(shadow_bolt.matches(ctx, state_low_mana), "ShadowBolt should not match when mana < 20%")

print("PASS test_warlock_affliction_wotlk")
