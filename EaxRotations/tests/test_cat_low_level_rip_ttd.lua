-- test_cat_low_level_rip_ttd.lua -- Feral Cat low-level Rip TTD gate regression.
-- WHAT:  Verifies Rip's time-to-death floor scales down below level 32, where Rip is
--         the only learned finisher (Ferocious Bite rank 1 is level 32).
-- WHEN:  During rotation test suite execution.
-- WHY:   MIN_RIP_TTD=10 suppressed Rip on fast-dying leveling mobs, so combo points
--         built to 3-5 and were never spent. Endgame gating must stay unchanged.
-- SAFETY: Pure unit tests with mocked API context; no live API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    DruidSpells = {},
    PLAYER_UNIT = {},
    POWER_COMBO = 4,
    POWER_ENERGY = 3,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    is_spell_learned = function() return true end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    debuff_up = function() return false end,
    buff_points = function() return nil end,
    try_cast = function() return true end,
    has_form = function(form) return form == "cat" end,
    is_behind_target = function() return true end,
    GetPlayer = function() return {} end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
local strategies = result.strategies or result
local build_state = result.build_state
assert_true(strategies, "strategies table should load")
assert_true(build_state, "build_state should be exported")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local rip = find_strategy("Rip")

local function ctx(level, ttd, cp)
    return {
        me = {},
        level = level,
        target = {},
        has_valid_enemy_target = true,
        in_combat = true,
        is_cat = true,
        combo_points = cp,
        energy = 100,
        ttd = ttd,
        attack_power = 500,
        settings = { cat_rip_cp = 3, cat_use_rip = true, cat_rip_elites_only = false },
    }
end

-- A level-25 druid on a mob dying in 6s: Rip is the only learned finisher
-- (Ferocious Bite is level 32), so it must still fire rather than banking CP forever.
assert_true(rip.matches(ctx(25, 6.0, 3)),
    "Rip should fire at level 25 with ttd=6 (below the endgame 10s floor)")

-- Level 70 on the same 6s target keeps the strict floor: a 12s DoT on a mob dying
-- in 6s wastes energy when Ferocious Bite is available as the dump instead.
assert_false(rip.matches(ctx(70, 6.0, 3)),
    "Rip should NOT fire at level 70 with ttd=6 (endgame floor stays 10s)")

-- Long-lived target: both levels fire.
assert_true(rip.matches(ctx(25, 30.0, 3)), "Rip should fire at level 25 with ttd=30")
assert_true(rip.matches(ctx(70, 30.0, 3)), "Rip should fire at level 70 with ttd=30")

-- Unknown TTD (0/nil) is treated as long-lived at every level.
assert_true(rip.matches(ctx(25, 0, 3)), "Rip should fire at level 25 with unknown ttd")
assert_true(rip.matches(ctx(70, 0, 3)), "Rip should fire at level 70 with unknown ttd")

-- Even low level refuses a target dying faster than one Rip tick.
assert_false(rip.matches(ctx(25, 1.0, 3)),
    "Rip should NOT fire at level 25 with ttd=1 (dies before a single tick lands)")

print("test_cat_low_level_rip_ttd.lua ok")
