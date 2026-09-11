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
local aoe_ok = false   -- NS.aoe_target_meets verdict
local spell_ok = true  -- NS.spell_ready verdict (Hellfire channel)
local debuffs = {}
local buffs = {}

local function immo(secs) debuffs[47811] = secs end
local function coe(secs) debuffs[47865] = secs end
local function backdraft(up) buffs[54277] = up or nil end

local function reset_env()
    combat, hp, mana, thp, enemies = true, 100, 100, 100, 1
    sb_cd, aoe_ok, spell_ok = 0, false, true
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
        return 0
    end,
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

print("PASS test_warlock_destruction_wotlk_strategies")
