-- test_warrior_defensive_threshold_wiring.lua -- Warrior tests.
-- WHAT:  Warrior tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Warrior Protection Defensive Threshold Wiring (TK2)
-- ----------------------------------------------------------------------------
-- Verifies that shield_wall_matches_fn and last_stand_matches_fn in
-- protection_sylvanas.lua respect settings.defensive_hp_threshold and
-- settings.use_shield_wall / settings.use_last_stand toggles.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- ============================================================================
-- Mock NS
-- ============================================================================
local _broken_api = false
_G.EaxRotations = {
    spell_ready = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    try_cast = function() return true end,
    is_spell_learned = function() return true end,
    get_spell_cooldown = function() return 0 end,
    gate_cooldown_boss_only = function() return true end,
    broken_api_throttled = function(spell, seconds) return _broken_api end,
    log = function() end,
    time_now = function() return 1000 end,
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    unit_alive = function() return false end,
    unit_mana_pct = function() return 100 end,
    unit_power_pct = function() return 100 end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            _G.captured_strategies = strategies
        end,
    },
    WarriorSpells = {
        ShieldSlam = 23922, Revenge = 11601, SunderArmor = 11597,
        Devastate = 30022, HeroicStrike = 29707, ThunderClap = 25264,
        ShieldBlock = 2565, ShieldBash = 72, Disarm = 676,
        Taunt = 355, MockingBlow = 25266, ChallengingShout = 1161,
        LastStand = 12975, ShieldWall = 871, SpellReflection = 23920,
        Bloodthirst = 23881, Rampage = 30033, Intervene = 3411,
        CommandingShout = 469, BattleShout = 2048, DemoralizingShout = 25203,
        VictoryRush = 34428, Whirlwind = 1680, Execute = 5308,
        Pummel = 6552, Hamstring = 1715, Rend = 25208,
    },
}

-- ============================================================================
-- Mock shared modules
-- ============================================================================
package.loaded["shared/pet_manager_sylvanas"] = {
    on_update = function() end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
    set_defensive = function() return true end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {},
    DAMAGE_POTION_IDS = {},
}

-- ============================================================================
-- Load spec
-- ============================================================================
dofile("EaxRotations/classes/warrior/protection_sylvanas.lua")
local strategies = _G.captured_strategies
assert_true(strategies, "strategies table should be captured")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local shield_wall = find_strategy("ShieldWall")
local last_stand = find_strategy("LastStand")
assert_true(shield_wall, "ShieldWall strategy should exist")
assert_true(last_stand, "LastStand strategy should exist")

local function make_state(hp, has_buff)
    return {
        hp = hp or 100,
        has_shield_wall = has_buff or false,
        has_last_stand = has_buff or false,
    }
end

local function make_context(settings)
    return {
        settings = settings or {},
        in_combat = true,
        target = {},
        me = {},
    }
end

-- ============================================================================
-- ShieldWall contracts
-- ============================================================================

-- C1: HP above threshold → no match
assert_false(shield_wall.matches(make_context({ defensive_hp_threshold = 30 }), make_state(50)),
    "C1: ShieldWall — HP 50 > threshold 30 → should NOT match")
print("  [ PASS ] C1: ShieldWall — HP above threshold → no match")

-- C2: HP at threshold → match
assert_true(shield_wall.matches(make_context({ defensive_hp_threshold = 30 }), make_state(30)),
    "C2: ShieldWall — HP 30 == threshold 30 → should match")
print("  [ PASS ] C2: ShieldWall — HP at threshold → match")

-- C3: HP below threshold → match
assert_true(shield_wall.matches(make_context({ defensive_hp_threshold = 30 }), make_state(20)),
    "C3: ShieldWall — HP 20 < threshold 30 → should match")
print("  [ PASS ] C3: ShieldWall — HP below threshold → match")

-- C4: use_shield_wall=false → no match
assert_false(shield_wall.matches(make_context({ use_shield_wall = false, defensive_hp_threshold = 30 }), make_state(20)),
    "C4: ShieldWall — use_shield_wall=false → should NOT match")
print("  [ PASS ] C4: ShieldWall — disabled in settings → no match")

-- C5: Already has buff → no match
assert_false(shield_wall.matches(make_context({ defensive_hp_threshold = 30 }), make_state(20, true)),
    "C5: ShieldWall — already has buff → should NOT match")
print("  [ PASS ] C5: ShieldWall — already buffed → no match")

-- C6: Default threshold (nil settings) → HP 35 should not match, HP 30 should match
assert_false(shield_wall.matches(make_context({}), make_state(40)),
    "C6: ShieldWall — default threshold, HP 40 → should NOT match")
assert_true(shield_wall.matches(make_context({}), make_state(30)),
    "C6: ShieldWall — default threshold, HP 30 → should match")
print("  [ PASS ] C6: ShieldWall — default threshold → correct")

-- ============================================================================
-- LastStand contracts
-- ============================================================================

-- C7: HP above threshold → no match
assert_false(last_stand.matches(make_context({ defensive_hp_threshold = 30 }), make_state(50)),
    "C7: LastStand — HP 50 > threshold 30 → should NOT match")
print("  [ PASS ] C7: LastStand — HP above threshold → no match")

-- C8: HP below threshold → match
assert_true(last_stand.matches(make_context({ defensive_hp_threshold = 30 }), make_state(20)),
    "C8: LastStand — HP 20 < threshold 30 → should match")
print("  [ PASS ] C8: LastStand — HP below threshold → match")

-- C9: use_last_stand=false → no match
assert_false(last_stand.matches(make_context({ use_last_stand = false, defensive_hp_threshold = 30 }), make_state(20)),
    "C9: LastStand — use_last_stand=false → should NOT match")
print("  [ PASS ] C9: LastStand — disabled in settings → no match")

-- C10: Already has buff → no match
assert_false(last_stand.matches(make_context({ defensive_hp_threshold = 30 }), make_state(20, true)),
    "C10: LastStand — already has buff → should NOT match")
print("  [ PASS ] C10: LastStand — already buffed → no match")

print("PASS test_warrior_defensive_threshold_wiring")
