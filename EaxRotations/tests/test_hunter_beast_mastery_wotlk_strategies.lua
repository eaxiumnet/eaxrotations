-- test_hunter_beast_mastery_wotlk_strategies.lua — Beast Mastery hunter WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL beast_mastery_wotlk.lua through its real build_state
--        read path (NS.debuff_remains for Serpent Sting / Hunters Mark /
--        Explosive Trap, NS.buff_up for the aspect buffs, ctx.mana_pct,
--        target hp / remaining time, and real NS.cooldown_remains for
--        Bestial Wrath), pinning both sides of every lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite mutates
--        build_state output post-hoc, so no suite exercised the real read
--        plumbing for the aspect/mana, debuff-upkeep, or trap lanes.
-- SAFETY: Pure unit tests with a mocked NS; the real beast_mastery_wotlk.lua
--         and real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local thp = 100
local enemy_count = 1
local combat = true
local ttd = 100
local debuffs = {}   -- spell id -> seconds remaining on target
local buffs = {}     -- spell id -> true (player buff up)
local cds = {}       -- spell id -> cooldown seconds

local function serpent(secs) debuffs[49001] = secs end
local function mark(secs) debuffs[14325] = secs end
local function trap(secs) debuffs[49067] = secs end
local function set_buff(id, up) buffs[id] = up or nil end

local function reset_env()
    mana, thp, enemy_count, combat, ttd = 100, 100, 1, true, 100
    debuffs, buffs, cds = {}, {}, {}
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
    cooldown_remains = function(action)
        if type(action) == "number" then return cds[action] or 0 end
        if action and action.id then return cds[action.id] or 0 end
        return 0
    end,
    get_spell_cooldown = function(action) return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/hunter/beast_mastery_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "beast_mastery_wotlk strategies should load")

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
-- Aspects: Viper below 10% mana, Dragonhawk at/above 30% (buff-down upkeep).
-- ============================================================================
assert_lane("AspectOfTheViper fires below 10% mana", "AspectOfTheViper",
    function() mana = 9 end, true)
assert_lane("AspectOfTheViper blocked at/above 10% mana", "AspectOfTheViper",
    function() mana = 10 end, false)
assert_lane("AspectOfTheViper blocked while Viper is already up", "AspectOfTheViper",
    function() mana = 5; set_buff(34074, true) end, false)
assert_lane("AspectOfTheDragonhawk fires at 30% mana", "AspectOfTheDragonhawk",
    function() mana = 30 end, true)
assert_lane("AspectOfTheDragonhawk blocked below 30% mana", "AspectOfTheDragonhawk",
    function() mana = 29 end, false)
assert_lane("AspectOfTheDragonhawk blocked while Dragonhawk is already up", "AspectOfTheDragonhawk",
    function() mana = 100; set_buff(61847, true) end, false)

-- ============================================================================
-- Hunters Mark: upkeep when the mark is about to fall (< 3s).
-- ============================================================================
assert_lane("HuntersMark fires with the mark down", "HuntersMark", function() end, true)
assert_lane("HuntersMark fires just before the 3s boundary", "HuntersMark",
    function() mark(2.9) end, true)
assert_lane("HuntersMark blocked while the mark is healthy", "HuntersMark",
    function() mark(3) end, false)

-- ============================================================================
-- Bestial Wrath: in combat + cooldown ready (real cooldown_remains on 19574).
-- ============================================================================
assert_lane("BestialWrath fires in combat with the cooldown ready", "BestialWrath",
    function() end, true)
assert_lane("BestialWrath blocked while on cooldown", "BestialWrath",
    function() cds[19574] = 120 end, false)
assert_lane("BestialWrath blocked out of combat", "BestialWrath",
    function() combat = false end, false)

-- ============================================================================
-- Kill Shot: execute band below 20% target hp.
-- ============================================================================
assert_lane("KillShot fires below 20% target hp", "KillShot",
    function() thp = 19 end, true)
assert_lane("KillShot blocked at/above 20% target hp", "KillShot",
    function() thp = 20 end, false)
assert_lane("KillShot blocked out of combat", "KillShot",
    function() thp = 10; combat = false end, false)

-- ============================================================================
-- Explosive Trap: re-drop when the trap debuff is down (< 1s).
-- ============================================================================
assert_lane("ExplosiveTrap fires with the trap debuff down", "ExplosiveTrap", function() end, true)
assert_lane("ExplosiveTrap blocked while the trap debuff is up", "ExplosiveTrap",
    function() trap(1) end, false)

-- ============================================================================
-- Kill Command: in-combat pet command.
-- ============================================================================
assert_lane("KillCommand fires in combat", "KillCommand", function() end, true)
assert_lane("KillCommand blocked out of combat", "KillCommand",
    function() combat = false end, false)

-- ============================================================================
-- Serpent Sting: refresh under 3s only on long-lived targets (TTD > 6s).
-- ============================================================================
assert_lane("SerpentSting fires when the sting is down", "SerpentSting",
    function() serpent(0); ttd = 10 end, true)
assert_lane("SerpentSting fires when the sting is about to expire", "SerpentSting",
    function() serpent(2); ttd = 10 end, true)
assert_lane("SerpentSting blocked while the sting is healthy", "SerpentSting",
    function() serpent(3); ttd = 10 end, false)
assert_lane("SerpentSting blocked on a short-lived target", "SerpentSting",
    function() serpent(0); ttd = 6 end, false)

-- ============================================================================
-- Shot core: Aimed/Steady in combat; MultiShot needs 2+ enemies; ArcaneShot
-- needs >= 20% mana.
-- ============================================================================
assert_lane("AimedShot fires in combat", "AimedShot", function() end, true)
assert_lane("AimedShot blocked out of combat", "AimedShot",
    function() combat = false end, false)
assert_lane("MultiShot fires on 2 enemies", "MultiShot",
    function() enemy_count = 2 end, true)
assert_lane("MultiShot blocked single-target", "MultiShot",
    function() enemy_count = 1 end, false)
assert_lane("ArcaneShot fires at 20% mana", "ArcaneShot",
    function() mana = 20 end, true)
assert_lane("ArcaneShot blocked below 20% mana", "ArcaneShot",
    function() mana = 19 end, false)
assert_lane("SteadyShot fires in combat", "SteadyShot", function() end, true)
assert_lane("SteadyShot blocked out of combat", "SteadyShot",
    function() combat = false end, false)

print("PASS test_hunter_beast_mastery_wotlk_strategies")
