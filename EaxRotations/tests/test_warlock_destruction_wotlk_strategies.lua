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
local thp = 100        -- target HP (Shadowburn execute band)
local enemies = 1      -- AoE volume (Hellfire wave)
local sb_cd = 0        -- Shadowburn cooldown
local conf_cd = 0      -- Conflagrate cooldown (10s in WotLK)
local cb_cd = 0        -- Chaos Bolt cooldown (12s in WotLK)
local immo_cast = nil  -- core.spell_book.get_spell_cast_time verdict
local aoe_ok = false   -- NS.aoe_target_meets verdict
local spell_ok = true  -- NS.spell_ready verdict (Hellfire channel)
local debuffs = {}
local buffs = {}

local function immo(secs) debuffs[47811] = secs end
local function coe(secs) debuffs[47865] = secs end
local function backdraft(up) buffs[54277] = up or nil end
local function doom(secs) debuffs[47867] = secs end
local function agony(secs) debuffs[47864] = secs end
local boss = false  -- context.target_is_boss (dispatcher-produced)

local function reset_env()
    combat, hp, mana, thp, enemies = true, 100, 100, 100, 1
    sb_cd, aoe_ok, spell_ok = 0, false, true
    cb_cd = 0
    conf_cd, immo_cast = 0, nil
    boss = false
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
    -- Single-rank actions resolve to a bare spell id (combat-suite comment
    -- convention): Shadowburn arrives as 47827.
    cooldown_remains = function(action)
        if action == 47827 then return sb_cd end
        if action == 30912 then return conf_cd end  -- Conflagrate ladder head
        if action == 59172 then return cb_cd end    -- Chaos Bolt ladder head
        return 0
    end,
    -- Engine spell-book cast time (core.spell_book.get_spell_cast_time): the
    -- real refresh-window source, mirroring test_fire_wotlk_dsl_priority.
    core = { spell_book = { get_spell_cast_time = function() return immo_cast end } },
    spell_ready = function(action, unit) return spell_ok end,
    aoe_target_meets = function(n, radius, target, ctx) return aoe_ok end,
    AOE_RADIUS = { SELF_10 = 10 },
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
        enemy_count = enemies,
        target = {
            is_casting = function() return false end,
            get_health_percentage = function() return thp end,
        },
        settings = {},
        target_is_boss = boss,
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
-- Conflagrate: only while Immolate is live (remains > 0) AND the real 10s
-- cooldown is ready (state.conflagrate_cd via NS.cooldown_remains) — the
-- wowsims fixture gates entry 2 on availability implicitly; without the
-- cooldown read the lane held the top of the race every GCD it was down.
-- ============================================================================
assert_lane("Conflagrate fires while Immolate is live", "Conflagrate",
    function() immo(12) end, true)
assert_lane("Conflagrate fires with a sliver of Immolate left", "Conflagrate",
    function() immo(0.1) end, true)
assert_lane("Conflagrate blocked when Immolate is down", "Conflagrate", function() end, false)
assert_lane("Conflagrate held while the 10s cooldown is running", "Conflagrate",
    function() immo(12); conf_cd = 4 end, false)
assert_lane("Conflagrate fires at the cooldown-ready boundary", "Conflagrate",
    function() immo(12); conf_cd = 0 end, true)
assert_lane("Conflagrate held on cooldown even with a sliver of Immolate", "Conflagrate",
    function() immo(0.1); conf_cd = 9.9 end, false)

-- ============================================================================
-- Immolate: refresh inside the cast-time window — the fixture's entry 4
-- expression dotRemainingTime(47811) < spellCastTime(47811). The window is
-- the engine's real cast time when available, and the WotLK base 2.0s when
-- the read is absent or nonsense (fail-open: never a zero-width window).
-- ============================================================================
assert_lane("Immolate refreshes when the debuff is down", "Immolate", function() end, true)
assert_lane("Immolate refreshes at 1.9s remaining (2.0s fallback window)", "Immolate",
    function() immo(1.9) end, true)
assert_lane("Immolate blocked at the 2.0s fallback boundary", "Immolate",
    function() immo(2.0) end, false)
assert_lane("Immolate blocked while the debuff is healthy", "Immolate", function() immo(12) end, false)
assert_lane("Immolate window follows the engine cast time (1.5s hasted)", "Immolate",
    function() immo_cast = 1.5; immo(1.4) end, true)
assert_lane("Immolate held at 1.9s once the engine window is 1.5s", "Immolate",
    function() immo_cast = 1.5; immo(1.9) end, false)
assert_lane("Immolate keeps the fallback window on a zero engine read", "Immolate",
    function() immo_cast = 0; immo(1.9) end, true)
assert_lane("Immolate keeps the fallback window on an absurd engine read", "Immolate",
    function() immo_cast = 99; immo(1.9) end, true)

-- ============================================================================
-- ChaosBolt: >= 20% mana AND the real 12s cooldown ready (state.chaos_bolt_cd
-- via NS.cooldown_remains on 59172, Wowhead 3.3.5 "Cooldown 12 seconds").
-- Without the cooldown read the lane matched on mana alone while its cooldown
-- ran, and it sits above the fallback curse and every filler.
-- ============================================================================
assert_lane("ChaosBolt fires at 20% mana", "ChaosBolt", function() mana = 20 end, true)
assert_lane("ChaosBolt blocked below 20% mana", "ChaosBolt", function() mana = 19 end, false)
assert_lane("ChaosBolt held while the 12s cooldown is running", "ChaosBolt",
    function() mana = 100; cb_cd = 11.9 end, false)
assert_lane("ChaosBolt fires at the cooldown-ready boundary", "ChaosBolt",
    function() mana = 100; cb_cd = 0 end, true)
assert_lane("ChaosBolt held on cooldown even with full mana", "ChaosBolt",
    function() mana = 100; cb_cd = 0.1 end, false)

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

-- ============================================================================
-- CurseOfElements (2026-09-11 guide pass): amp upkeep — cast when < 30s left
-- (the real debuff_remains read on the single WotLK-rank 47865).
-- ============================================================================
assert_lane("CurseOfElements fires when the amp is down", "CurseOfElements", function() end, true)
assert_lane("CurseOfElements fires inside the 30s refresh window", "CurseOfElements",
    function() coe(29) end, true)
assert_lane("CurseOfElements blocked while the amp is healthy", "CurseOfElements",
    function() coe(31) end, false)

-- ============================================================================
-- Shadowburn (guide pass): execute-band finisher — target HP < 35 + cooldown
-- ready (real get_health_percentage + cooldown_remains reads on 47827).
-- ============================================================================
assert_lane("Shadowburn fires in the execute band", "Shadowburn",
    function() thp = 34 end, true)
assert_lane("Shadowburn blocked above the execute band", "Shadowburn",
    function() thp = 35 end, false)
assert_lane("Shadowburn blocked while on cooldown", "Shadowburn",
    function() thp = 20; sb_cd = 15 end, false)

-- ============================================================================
-- HellfireAoE (guide pass): channeled AoE wave — in combat + 3+ enemies in
-- the 10y self radius + channel ready (Hurricane idiom; real spell_ready).
-- ============================================================================
assert_lane("HellfireAoE fires on a 4-enemy wave", "HellfireAoE",
    function() combat = true; enemies = 4; aoe_ok = true end, true)
assert_lane("HellfireAoE blocked below the 3-enemy volume floor", "HellfireAoE",
    function() combat = true; enemies = 4; aoe_ok = true; enemies = 2 end, false)
assert_lane("HellfireAoE blocked when the AoE volume read fails", "HellfireAoE",
    function() combat = true; enemies = 4; aoe_ok = false end, false)
assert_lane("HellfireAoE blocked when the channel is not ready", "HellfireAoE",
    function() combat = true; enemies = 4; aoe_ok = true; spell_ok = false end, false)

assert_lane("Curse of Doom fires on a boss with Doom down", "CurseOfDoom",
    function() boss = true end, true)
assert_lane("Curse of Doom held on a non-boss target", "CurseOfDoom",
    function() boss = false end, false)
assert_lane("Curse of Doom held while the DoT is already ticking", "CurseOfDoom",
    function() boss = true; doom(30) end, false)
assert_lane("Curse of Doom held out of combat", "CurseOfDoom",
    function() boss = true; combat = false end, false)
assert_lane("Curse of Agony fires on a non-boss with the curse down", "CurseOfAgony",
    function() boss = false end, true)
assert_lane("Curse of Agony refreshes at 2.9s remaining", "CurseOfAgony",
    function() boss = false; agony(2.9) end, true)
assert_lane("Curse of Agony held at the 3.0s boundary", "CurseOfAgony",
    function() boss = false; agony(3) end, false)
assert_lane("Curse of Agony held on a boss (Doom owns the slot)", "CurseOfAgony",
    function() boss = true end, false)
assert_lane("Curse of Agony held out of combat", "CurseOfAgony",
    function() boss = false; combat = false end, false)

print("PASS test_warlock_destruction_wotlk_strategies")
