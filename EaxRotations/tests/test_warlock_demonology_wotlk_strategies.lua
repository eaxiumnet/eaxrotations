-- test_warlock_demonology_wotlk_strategies.lua — Demonology warlock WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL demonology_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for Corruption 47813 / Immolate 47811,
--        NS.buff_up for the 47241 Metamorphosis aura, ctx.mana_pct / ctx.hp for
--        SoulFire/ShadowBolt/LifeTap, ctx.in_combat and NS.should_use_long_cd
--        for the Metamorphosis long-CD gate), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): demonology had only static DSL
--        coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real demonology_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local mana = 100
local debuffs = {}
local buffs = {}
local long_cd_refused = {}
local meta_cd = 0   -- Metamorphosis cooldown (3 min in WotLK)
local ia_cd = 0     -- Immolation Aura cooldown (30s in WotLK)

local boss, enemies, aoe_ok = false, 1, false

local function corr(secs) debuffs[47813] = secs end
local function immo(secs) debuffs[47811] = secs end
local function cod(secs) debuffs[47867] = secs end
local function agony(secs) debuffs[47864] = secs end
local function meta(up) buffs[47241] = up or nil end
local function molten_core(up) buffs[71165] = up or nil end  -- MC proc (71165/47246/47245)
local function decimation(up) buffs[63165] = up or nil end

local function reset_env()
    combat, hp, mana = true, 100, 100
    boss, enemies, aoe_ok = false, 1, false
    debuffs, buffs, long_cd_refused = {}, {}, {}
    meta_cd, ia_cd = 0, 0
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
    should_use_long_cd = function(context, seconds)
        if long_cd_refused[seconds] then return false end
        return true
    end,
    -- Real cooldown reads for the demon-form pair (Metamorphosis 47241 3 min,
    -- Immolation Aura 50589 30s). Every other action reports ready.
    cooldown_remains = function(spell)
        local id = type(spell) == "number" and spell or (spell and spell.ids and spell.ids[1]) or 0
        if id == 47241 then return meta_cd end
        if id == 50589 then return ia_cd end
        return 0
    end,
    aoe_target_meets = function(n) return aoe_ok and enemies >= (n or 1) end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warlock/demonology_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "demonology_wotlk strategies should load")

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
        target_is_boss = boss,
        enemy_count = enemies,
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
-- Metamorphosis: in combat + aura down + long-CD (180s) permitted.
-- ============================================================================
assert_lane("Metamorphosis fires in combat when down", "Metamorphosis", function() end, true)
assert_lane("Metamorphosis blocked while transformed", "Metamorphosis", function() meta(true) end, false)
assert_lane("Metamorphosis blocked out of combat", "Metamorphosis", function() combat = false end, false)
assert_lane("Metamorphosis blocked when long CDs are refused", "Metamorphosis",
    function() long_cd_refused[180] = true end, false)

-- ============================================================================
-- Corruption: refresh at/below 3s (no combat gate in this file).
-- ============================================================================
assert_lane("Corruption refreshes when the debuff is down", "Corruption", function() end, true)
assert_lane("Corruption refreshes at 2.9s remaining", "Corruption", function() corr(2.9) end, true)
assert_lane("Corruption blocked at the 3.0s boundary", "Corruption", function() corr(3) end, false)
assert_lane("Corruption blocked while the debuff is healthy", "Corruption", function() corr(3.1) end, false)

-- ============================================================================
-- Immolate: refresh at/below 3s.
-- ============================================================================
assert_lane("Immolate refreshes when the debuff is down", "Immolate", function() end, true)
assert_lane("Immolate refreshes at 2.9s remaining", "Immolate", function() immo(2.9) end, true)
assert_lane("Immolate blocked at the 3.0s boundary", "Immolate", function() immo(3) end, false)
assert_lane("Immolate blocked while the debuff is healthy", "Immolate", function() immo(3.1) end, false)

-- ============================================================================
-- SoulFire: >= 30% mana.
-- ============================================================================
assert_lane("SoulFire fires at 30% mana", "SoulFire", function() mana = 30 end, true)
assert_lane("SoulFire blocked below 30% mana", "SoulFire", function() mana = 29 end, false)

-- ============================================================================
-- ShadowBolt: filler at >= 20% mana.
-- ============================================================================
assert_lane("ShadowBolt fires at 20% mana", "ShadowBolt", function() mana = 20 end, true)
assert_lane("ShadowBolt blocked below 20% mana", "ShadowBolt", function() mana = 19 end, false)

-- ============================================================================
-- LifeTap: in combat + mana < 65 + hp > 55 (sustain, appended after fillers).
-- ============================================================================
assert_lane("LifeTap fires when mana drops below 65 with hp healthy", "LifeTap",
    function() mana = 64 end, true)
assert_lane("LifeTap blocked at 65% mana", "LifeTap", function() mana = 65 end, false)
assert_lane("LifeTap blocked when hp is at the 55 floor", "LifeTap",
    function() mana = 50; hp = 55 end, false)
assert_lane("LifeTap blocked below the hp floor", "LifeTap",
    function() mana = 50; hp = 54 end, false)
assert_lane("LifeTap blocked out of combat", "LifeTap",
    function() mana = 50; combat = false end, false)

-- ============================================================================
-- IncinerateProc: Molten Core window (buff 71165) — spend before resuming
-- Shadow Bolt; the shadow filler is NOT held while the buff is down.
-- ============================================================================
assert_lane("IncinerateProc fires with Molten Core up", "IncinerateProc",
    function() molten_core(true) end, true)
assert_lane("IncinerateProc blocked without Molten Core", "IncinerateProc",
    function() end, false)
assert_lane("IncinerateProc blocked below 30% mana", "IncinerateProc",
    function() molten_core(true); mana = 29 end, false)

-- ============================================================================
-- SoulFireDecimation: Decimation window (buff 63165, sub-35% target proc).
-- ============================================================================
assert_lane("SoulFireDecimation fires with Decimation up", "SoulFireDecimation",
    function() decimation(true) end, true)
assert_lane("SoulFireDecimation blocked without Decimation", "SoulFireDecimation",
    function() end, false)
assert_lane("SoulFireDecimation blocked below 30% mana", "SoulFireDecimation",
    function() decimation(true); mana = 29 end, false)

-- Plain SoulFire filler still gated at 30% mana.
assert_lane("SoulFire blocked at 29% mana", "SoulFire",
    function() mana = 29 end, false)

-- ============================================================================
-- 2026-09-12 guide-pass lanes: the curse pair (Curse of Doom on a long boss
-- fight, Curse of Agony otherwise), the Metamorphosis-form Immolation Aura
-- and the Seed of Corruption AoE dump. Fire + hold on both sides.
-- ============================================================================
assert_lane("CurseOfDoom fires on a boss with the curse down", "CurseOfDoom",
    function() boss = true end, true)
assert_lane("CurseOfDoom refreshes at 2.9s remaining on a boss", "CurseOfDoom",
    function() boss = true; cod(2.9) end, true)
assert_lane("CurseOfDoom blocked at the 3.0s boundary", "CurseOfDoom",
    function() boss = true; cod(3) end, false)
assert_lane("CurseOfDoom blocked on a non-boss target", "CurseOfDoom",
    function() end, false)
assert_lane("CurseOfDoom blocked out of combat", "CurseOfDoom",
    function() boss = true; combat = false end, false)

assert_lane("CurseOfAgony fires with the curse down", "CurseOfAgony", function() end, true)
assert_lane("CurseOfAgony refreshes at 2.9s remaining", "CurseOfAgony",
    function() agony(2.9) end, true)
assert_lane("CurseOfAgony blocked at the 3.0s boundary", "CurseOfAgony",
    function() agony(3) end, false)
assert_lane("CurseOfAgony blocked out of combat", "CurseOfAgony",
    function() combat = false end, false)

assert_lane("ImmolationAura fires inside the Metamorphosis window", "ImmolationAura",
    function() meta(true) end, true)
assert_lane("ImmolationAura blocked outside Metamorphosis", "ImmolationAura",
    function() end, false)
assert_lane("ImmolationAura blocked out of combat", "ImmolationAura",
    function() meta(true); combat = false end, false)
-- ============================================================================
-- Demon-form availability (2026-09-13 cooldown audit): the form window is NOT
-- availability. Metamorphosis is 3 min with a 30s duration (47241) and
-- Immolation Aura is 30s (50589), so both lanes matched for the whole span
-- their real cooldown was still running.
-- ============================================================================
assert_lane("Metamorphosis held while the 3-min cooldown is running", "Metamorphosis",
    function() meta(false); meta_cd = 150 end, false)
assert_lane("Metamorphosis fires at the cooldown-ready boundary", "Metamorphosis",
    function() meta(false); meta_cd = 0 end, true)
assert_lane("Metamorphosis held on cooldown even with the form down", "Metamorphosis",
    function() meta(false); meta_cd = 0.1 end, false)
assert_lane("Metamorphosis held out of combat with the cooldown ready", "Metamorphosis",
    function() meta(false); combat = false end, false)
assert_lane("ImmolationAura held while its 30s cooldown is running", "ImmolationAura",
    function() meta(true); ia_cd = 29.9 end, false)
assert_lane("ImmolationAura fires at the cooldown-ready boundary in form", "ImmolationAura",
    function() meta(true); ia_cd = 0 end, true)
assert_lane("ImmolationAura held on cooldown inside the form window", "ImmolationAura",
    function() meta(true); ia_cd = 0.1 end, false)

assert_lane("SeedOfCorruptionAoE fires into a 4-enemy pack", "SeedOfCorruptionAoE",
    function() enemies = 4; aoe_ok = true end, true)
assert_lane("SeedOfCorruptionAoE blocked at 3 enemies", "SeedOfCorruptionAoE",
    function() enemies = 3; aoe_ok = true end, false)
assert_lane("SeedOfCorruptionAoE fail-closed without the AoE module", "SeedOfCorruptionAoE",
    function() enemies = 5; aoe_ok = false end, false)

print("PASS test_warlock_demonology_wotlk_strategies")
