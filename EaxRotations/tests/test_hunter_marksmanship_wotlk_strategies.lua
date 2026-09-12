-- test_hunter_marksmanship_wotlk_strategies.lua — Marksmanship hunter WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL marksmanship_wotlk.lua through its real build_state
--        read path (NS.debuff_remains for Serpent Sting / Hunters Mark /
--        Explosive Trap, NS.buff_up for the aspect buffs, ctx.mana_pct,
--        target hp), pinning both sides of every lane: aspect/mana upkeep,
--        Hunters Mark, Kill Shot execute band, Serpent Sting refresh (no
--        target-remaining-time gate in MM), Explosive Trap, the Chimera Shot /
--        Aimed Shot / Steady Shot core, MultiShot 2-target, Arcane Shot
--        mana gate, and the Silencing Shot interrupt-use lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite mutates
--        build_state output post-hoc, so no suite exercised the real read
--        plumbing for the MM lanes.
-- SAFETY: Pure unit tests with a mocked NS; the real marksmanship_wotlk.lua
--         and real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local thp = 100
local enemy_count = 1
local combat = true
local debuffs = {}
local buffs = {}
-- Engine cast END TIME (ctx.target_cast_remaining, seconds): the interrupt
-- floor. nil = unknown = fail-open (the pre-signal behavior).
local casting = false

local function serpent(secs) debuffs[49001] = secs end
local function mark(secs) debuffs[14325] = secs end
local function trap(secs) debuffs[49067] = secs end
local function set_buff(id, up) buffs[id] = up or nil end

local function reset_env()
    mana, thp, enemy_count, combat = 100, 100, 1, true
    debuffs, buffs = {}, {}
    casting = false
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

local result = dofile("EaxRotations/classes/hunter/marksmanship_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "marksmanship_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local cast_remaining = nil
local cast_lead = nil
local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        enemy_count = enemy_count,
        target_casting = casting,
        target = { get_health_percentage = function() return thp end,
                   is_casting = function() return casting end },
        settings = { interrupt_lead_sec = cast_lead }, target_cast_remaining = cast_remaining,
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
-- Silencing Shot: interrupt lane. 2026-09-12 correctness pass — the lane
-- previously had NO target-casting gate at all (only in_combat), so it fired
-- Silencing Shot on cooldown against a target that was not casting. It now
-- requires a casting target plus a real interrupt window, matching its
-- leveling sibling and the shared engine cast-timing gate.
-- ============================================================================
assert_lane("SilencingShot fires on a casting target in combat", "SilencingShot",
    function() casting = true end, true)
assert_lane("SilencingShot blocked out of combat", "SilencingShot",
    function() combat = false; casting = true end, false)
assert_lane("SilencingShot blocked when the target is not casting", "SilencingShot",
    function() end, false)
assert_lane("SilencingShot fires with 1.0s left on the enemy cast", "SilencingShot",
    function() casting = true; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("SilencingShot holds when only 0.05s of the cast remains", "SilencingShot",
    function() casting = true; cast_remaining = 0.05; cast_lead = nil end, false)
assert_lane("SilencingShot holds ON the 0.30s lead floor", "SilencingShot",
    function() casting = true; cast_remaining = 0.30; cast_lead = nil end, false)
assert_lane("SilencingShot fires above the 0.30s lead floor", "SilencingShot",
    function() casting = true; cast_remaining = 0.31; cast_lead = nil end, true)
assert_lane("SilencingShot honours a raised interrupt_lead_sec setting", "SilencingShot",
    function() casting = true; cast_remaining = 0.9; cast_lead = 1.2 end, false)

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
-- Serpent Sting: refresh under 3s (MM has NO target-remaining-time gate).
-- ============================================================================
assert_lane("SerpentSting fires when the sting is down", "SerpentSting", function() end, true)
assert_lane("SerpentSting fires when the sting is about to expire", "SerpentSting",
    function() serpent(2) end, true)
assert_lane("SerpentSting blocked while the sting is healthy", "SerpentSting",
    function() serpent(3) end, false)
assert_lane("SerpentSting fires even on a short-lived target (no TTD gate)",
    "SerpentSting", function() serpent(0) end, true)

-- ============================================================================
-- Explosive Trap upkeep (< 1s remains).
-- ============================================================================
assert_lane("ExplosiveTrap fires with the trap debuff down", "ExplosiveTrap", function() end, true)
assert_lane("ExplosiveTrap blocked while the trap debuff is up", "ExplosiveTrap",
    function() trap(1) end, false)

-- ============================================================================
-- Shot core: Chimera/Aimed/Steady in combat; MultiShot 2+; ArcaneShot mana.
-- ============================================================================
assert_lane("ChimeraShot fires in combat", "ChimeraShot", function() end, true)
assert_lane("ChimeraShot blocked out of combat", "ChimeraShot",
    function() combat = false end, false)
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

print("PASS test_hunter_marksmanship_wotlk_strategies")
