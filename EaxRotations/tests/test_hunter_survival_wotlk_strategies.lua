-- test_hunter_survival_wotlk_strategies.lua — Survival hunter WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL survival_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for Serpent Sting / Hunters Mark / Explosive
--        Trap / Black Arrow, NS.buff_up for the aspect buffs AND the Lock and
--        Load proc, ctx.mana_pct, target hp / remaining time), pinning both
--        sides of every lane — including the Explosive Shot proc-window split
--        (proc lane fires during Lock and Load, plain lane fires outside it).
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite mutates
--        build_state output post-hoc, so no suite exercised the real read
--        plumbing (Lock and Load via buff_up, Black Arrow / trap debuffs).
-- SAFETY: Pure unit tests with a mocked NS; the real survival_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local thp = 100
local enemy_count = 1
local combat = true
local ttd = 100
local debuffs = {}
local buffs = {}

local function serpent(secs) debuffs[49001] = secs end
local function mark(secs) debuffs[14325] = secs end
local function trap(secs) debuffs[49067] = secs end
local function blackarrow(secs) debuffs[63672] = secs end
local function set_buff(id, up) buffs[id] = up or nil end
local function lock_and_load(up) set_buff(56344, up) end

local function reset_env()
    mana, thp, enemy_count, combat, ttd = 100, 100, 1, true, 100
    debuffs, buffs = {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    unit_mana_pct = function() return mana end,
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

local result = dofile("EaxRotations/classes/hunter/survival_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "survival_wotlk strategies should load")

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
        target_remaining_time = ttd,
        enemy_count = enemy_count,
        target = { get_health_percentage = function() return thp end },
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
-- Aspects: Viper below 10% mana, Dragonhawk at/above 30%.
-- ============================================================================
assert_lane("AspectOfTheViper fires below 10% mana", "AspectOfTheViper",
    function() mana = 9 end, true)
assert_lane("AspectOfTheViper blocked at/above 10% mana", "AspectOfTheViper",
    function() mana = 10 end, false)
assert_lane("AspectOfTheViper blocked while Viper is up", "AspectOfTheViper",
    function() mana = 5; set_buff(34074, true) end, false)
assert_lane("AspectOfTheDragonhawk fires at 30% mana", "AspectOfTheDragonhawk",
    function() mana = 30 end, true)
assert_lane("AspectOfTheDragonhawk blocked below 30% mana", "AspectOfTheDragonhawk",
    function() mana = 29 end, false)
assert_lane("AspectOfTheDragonhawk blocked while Dragonhawk is up", "AspectOfTheDragonhawk",
    function() mana = 100; set_buff(61847, true) end, false)

-- ============================================================================
-- Hunters Mark upkeep.
-- ============================================================================
assert_lane("HuntersMark fires with the mark down", "HuntersMark", function() end, true)
assert_lane("HuntersMark blocked while the mark is healthy", "HuntersMark",
    function() mark(5) end, false)

-- ============================================================================
-- Kill Shot execute band (< 20% target hp).
-- ============================================================================
assert_lane("KillShot fires below 20% target hp", "KillShot",
    function() thp = 19 end, true)
assert_lane("KillShot blocked at/above 20% target hp", "KillShot",
    function() thp = 20 end, false)
assert_lane("KillShot blocked out of combat", "KillShot",
    function() thp = 10; combat = false end, false)

-- ============================================================================
-- Lock and Load / Explosive Shot window split: the proc lane owns the window
-- (instant/free max-rank shot), the plain lane is excluded during it.
-- ============================================================================
assert_lane("ExplosiveShotProc fires during a Lock and Load window", "ExplosiveShotProc",
    function() lock_and_load(true) end, true)
assert_lane("ExplosiveShotProc blocked outside the window", "ExplosiveShotProc",
    function() lock_and_load(false) end, false)
assert_lane("ExplosiveShotProc blocked out of combat in a window", "ExplosiveShotProc",
    function() lock_and_load(true); combat = false end, false)
assert_lane("ExplosiveShot fires outside the proc window", "ExplosiveShot",
    function() lock_and_load(false) end, true)
assert_lane("ExplosiveShot blocked during the proc window (proc lane owns it)",
    "ExplosiveShot", function() lock_and_load(true) end, false)
assert_lane("ExplosiveShot blocked out of combat", "ExplosiveShot",
    function() lock_and_load(false); combat = false end, false)

-- ============================================================================
-- Explosive Trap upkeep (< 1s remains).
-- ============================================================================
assert_lane("ExplosiveTrap fires with the trap debuff down", "ExplosiveTrap", function() end, true)
assert_lane("ExplosiveTrap blocked while the trap debuff is up", "ExplosiveTrap",
    function() trap(1) end, false)

-- ============================================================================
-- Serpent Sting: refresh under 3s on long-lived targets (TTD > 6s).
-- ============================================================================
assert_lane("SerpentSting fires when the sting is down", "SerpentSting",
    function() serpent(0); ttd = 10 end, true)
assert_lane("SerpentSting blocked while the sting is healthy", "SerpentSting",
    function() serpent(3); ttd = 10 end, false)
assert_lane("SerpentSting blocked on a short-lived target", "SerpentSting",
    function() serpent(0); ttd = 6 end, false)

-- ============================================================================
-- Black Arrow: upkeep under 3s.
-- ============================================================================
assert_lane("BlackArrow fires with the debuff down", "BlackArrow", function() end, true)
assert_lane("BlackArrow fires when about to expire", "BlackArrow",
    function() blackarrow(2) end, true)
assert_lane("BlackArrow blocked while the debuff is healthy", "BlackArrow",
    function() blackarrow(3) end, false)

-- ============================================================================
-- Shot core: Aimed/Steady in combat; MultiShot 2+ enemies.
-- ============================================================================
assert_lane("AimedShot fires in combat", "AimedShot", function() end, true)
assert_lane("AimedShot blocked out of combat", "AimedShot",
    function() combat = false end, false)
assert_lane("MultiShot fires on 2 enemies", "MultiShot",
    function() enemy_count = 2 end, true)
assert_lane("MultiShot blocked single-target", "MultiShot",
    function() enemy_count = 1 end, false)
assert_lane("SteadyShot fires in combat", "SteadyShot", function() end, true)
assert_lane("SteadyShot blocked out of combat", "SteadyShot",
    function() combat = false end, false)

print("PASS test_hunter_survival_wotlk_strategies")
