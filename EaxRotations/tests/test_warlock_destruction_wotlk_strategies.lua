-- test_warlock_destruction_wotlk_strategies.lua — Destruction warlock WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL destruction_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for the Immolate 47811 debuff, NS.buff_up for
--        the Backdraft haste auras 54274/54276/54277, ctx.mana_pct / ctx.hp /
--        ctx.in_combat), pinning both sides of every gate — including the
--        Backdraft implementation: the proc-up SoulFireBackdraft lane fires
--        through the real aura read and the no-proc lane is held.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): destruction had only static DSL
--        coverage, and the Conflagrate->Backdraft haste mechanic was untracked.
--        These are real-read behavioral pins on the implemented mechanic.
-- SAFETY: Pure unit tests with a mocked NS; the real destruction_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local mana = 100
local debuffs = {}
local buffs = {}

local function immo(secs) debuffs[47811] = secs end
local function backdraft(up) buffs[54277] = up or nil end

local function reset_env()
    combat, hp, mana = true, 100, 100
    debuffs, buffs = {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return hp end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warlock/destruction_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "destruction_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        hp = hp,
        enemy_count = 1,
        target = { is_casting = function() return false end },
        settings = {},
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, strategy_name, setup, expect)
    reset_env()
    setup()
    scenario(label, strategy_name, expect)
end

-- ============================================================================
-- Conflagrate: only while Immolate is live (remains > 0).
-- ============================================================================
assert_lane("Conflagrate fires while Immolate is live", "Conflagrate",
    function() immo(12) end, true)
assert_lane("Conflagrate fires with a sliver of Immolate left", "Conflagrate",
    function() immo(0.1) end, true)
assert_lane("Conflagrate blocked when Immolate is down", "Conflagrate", function() end, false)

-- ============================================================================
-- Immolate: refresh below the cast-time window (2.0s default here).
-- ============================================================================
assert_lane("Immolate refreshes when the debuff is down", "Immolate", function() end, true)
assert_lane("Immolate refreshes at 1.9s remaining", "Immolate", function() immo(1.9) end, true)
assert_lane("Immolate blocked at the 2.0s refresh boundary", "Immolate", function() immo(2.0) end, false)
assert_lane("Immolate blocked while the debuff is healthy", "Immolate", function() immo(12) end, false)

-- ============================================================================
-- ChaosBolt: >= 20% mana.
-- ============================================================================
assert_lane("ChaosBolt fires at 20% mana", "ChaosBolt", function() mana = 20 end, true)
assert_lane("ChaosBolt blocked below 20% mana", "ChaosBolt", function() mana = 19 end, false)

-- ============================================================================
-- SoulFireBackdraft (Backdraft implementation): in combat + aura up + >= 30%
-- mana. The real buff read covers all three talent-rank aura ids; 54277 is the
-- max-rank (-30%) aura.
-- ============================================================================
assert_lane("Backdraft Soul Fire fires inside the window (max-rank aura)",
    "SoulFireBackdraft", function() backdraft(true) end, true)
assert_lane("Backdraft Soul Fire fires at 30% mana in-window",
    "SoulFireBackdraft", function() backdraft(true); mana = 30 end, true)
assert_lane("Backdraft Soul Fire held at 29% mana in-window",
    "SoulFireBackdraft", function() backdraft(true); mana = 29 end, false)
assert_lane("Backdraft Soul Fire held without the proc", "SoulFireBackdraft",
    function() end, false)
assert_lane("Backdraft Soul Fire held out of combat even with the proc",
    "SoulFireBackdraft", function() backdraft(true); combat = false end, false)

-- ============================================================================
-- SoulFire (plain): the non-proc consumer must stay available out-of-window —
-- the proc lane consumes the aura above Incinerate, so with no aura the plain
-- lane still fires.
-- ============================================================================
assert_lane("Plain Soul Fire fires without the proc at 30% mana", "SoulFire",
    function() mana = 30 end, true)
assert_lane("Plain Soul Fire blocked below 30% mana", "SoulFire",
    function() mana = 29 end, false)

-- ============================================================================
-- Incinerate: filler at >= 20% mana.
-- ============================================================================
assert_lane("Incinerate fires at 20% mana", "Incinerate", function() mana = 20 end, true)
assert_lane("Incinerate blocked below 20% mana", "Incinerate", function() mana = 19 end, false)

-- ============================================================================
-- LifeTap: in combat + mana < 30 + hp > 50 (sustain, tail).
-- ============================================================================
assert_lane("LifeTap fires below 30% mana with hp healthy", "LifeTap",
    function() mana = 29 end, true)
assert_lane("LifeTap blocked at 30% mana", "LifeTap", function() mana = 30 end, false)
assert_lane("LifeTap blocked when hp is at the 50 floor", "LifeTap",
    function() mana = 20; hp = 50 end, false)
assert_lane("LifeTap blocked out of combat", "LifeTap",
    function() mana = 20; combat = false end, false)

print("PASS test_warlock_destruction_wotlk_strategies")
