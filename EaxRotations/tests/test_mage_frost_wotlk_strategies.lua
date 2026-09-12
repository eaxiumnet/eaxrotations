-- test_mage_frost_wotlk_strategies.lua — Frost mage WotLK behavioral strategy
-- match-gate scenarios.
-- WHAT:  Drives the REAL frost_wotlk.lua through its real build_state read path
--        (NS.debuff_remains for the 44549 Frostfire debuff, NS.debuff_up for
--        the Frost Nova root family incl. 42917, NS.buff_up for the 44545
--        Fingers of Frost proc, target:is_casting for Counterspell,
--        ctx.mana_pct and ctx.hp), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): frost had sparse live-fix pins;
--        every gate here is pinned through the real read path.
-- SAFETY: Pure unit tests with a mocked NS; the real frost_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local hp = 100
local mana = 100
local combat = true
local casting = false
local debuffs = {}
local buffs = {}
local cds = {}
local has_pet = false
local longcd = true
-- Engine school lockout mask (ctx.school_lockout) — 16 = frost, 4 = fire.
local lockout = 0

local function ffb(secs) debuffs[44549] = secs end
local function root(secs) debuffs[42917] = secs end
local function fof(up) buffs[44545] = up or nil end

local function reset_env()
    hp, mana, combat, casting = 100, 100, true, false
    debuffs, buffs, cds = {}, {}, {}
    has_pet, longcd, lockout = false, true, 0
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
    debuff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return true end
        end
        return false
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    cooldown_remains = function(action, unit)
        local id = type(action) == "number" and action or (action and action.id)
        return cds[id] or 0
    end,
    -- Real readiness channel for the shield/mana/burst lanes (mirrors the
    -- engine contract: NS.spell_ready(spell, unit, opts) -> boolean).
    spell_ready = function(spell, unit, opts)
        local id = type(spell) == "number" and spell or (spell and spell.id)
        return (cds[id] or 0) <= 0
    end,
    has_pet = function() return has_pet end,
    should_use_long_cd = function(context, cd) return longcd end,
    PLAYER_UNIT = {},
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/mage/frost_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "frost_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        hp = hp,
        mana_pct = mana,
        enemy_count = 1,
        school_lockout = lockout,
        me = _G.EaxRotations.me,
        target = { is_casting = function() return casting end },
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
-- Counterspell: in combat + the target is casting.
-- ============================================================================
assert_lane("Counterspell fires on an enemy cast", "Counterspell", function() casting = true end, true)
assert_lane("Counterspell blocked when nothing is casting", "Counterspell", function() end, false)

-- ============================================================================
-- Cold Snap: panic reset below 50% hp — no combat gate.
-- ============================================================================
assert_lane("ColdSnap fires at 49% hp", "ColdSnap", function() hp = 49 end, true)
assert_lane("ColdSnap fires out of combat", "ColdSnap",
    function() combat = false; hp = 30 end, true)
assert_lane("ColdSnap blocked at 50% hp", "ColdSnap", function() hp = 50 end, false)

-- ============================================================================
-- Deep Freeze: frozen target = Nova root OR Fingers of Frost.
-- ============================================================================
assert_lane("DeepFreeze fires on a Frost Nova root", "DeepFreeze", function() root(2) end, true)
assert_lane("DeepFreeze fires on Fingers of Frost", "DeepFreeze", function() fof(true) end, true)
assert_lane("DeepFreeze blocked on an unfrozen target", "DeepFreeze", function() end, false)

-- ============================================================================
-- Frostfire Bolt: 44549 debuff refresh (< 3) with mana >= 20.
-- ============================================================================
assert_lane("FrostfireBolt refreshes at 2s remaining", "FrostfireBolt",
    function() ffb(2) end, true)
assert_lane("FrostfireBolt drops when the debuff is down", "FrostfireBolt", function() end, true)
assert_lane("FrostfireBolt blocked while the debuff is healthy", "FrostfireBolt",
    function() ffb(3) end, false)
assert_lane("FrostfireBolt blocked below 20 mana", "FrostfireBolt",
    function() mana = 19 end, false)

-- ============================================================================
-- Ice Lance: frozen/FoF shatter consumer.
-- ============================================================================
assert_lane("IceLance fires on a Frost Nova root", "IceLance", function() root(2) end, true)
assert_lane("IceLance fires on Fingers of Frost", "IceLance", function() fof(true) end, true)
assert_lane("IceLance blocked on an unfrozen target", "IceLance", function() end, false)

-- ============================================================================
-- Frostbolt: filler at mana >= 15.
-- ============================================================================
assert_lane("Frostbolt fires at 15 mana", "Frostbolt", function() mana = 15 end, true)
assert_lane("Frostbolt blocked below 15 mana", "Frostbolt", function() mana = 14 end, false)

-- ============================================================================
-- Icy Veins + Summon Water Elemental: guide-pass burst lanes (2026-09-09).
-- In combat, real cooldown_remains read, long-CD consent; the elemental also
-- holds while the pet is alive.
-- ============================================================================
assert_lane("IcyVeins fires off cooldown in combat", "IcyVeins", function() end, true)
assert_lane("IcyVeins blocked while on cooldown", "IcyVeins",
    function() cds[12472] = 120 end, false)
assert_lane("IcyVeins blocked out of combat", "IcyVeins",
    function() combat = false end, false)
assert_lane("IcyVeins blocked when long-CD gate refuses", "IcyVeins",
    function() longcd = false end, false)
assert_lane("SummonWaterElemental fires with no pet off cooldown", "SummonWaterElemental",
    function() end, true)
assert_lane("SummonWaterElemental held while the pet is alive", "SummonWaterElemental",
    function() has_pet = true end, false)
assert_lane("SummonWaterElemental blocked while on cooldown", "SummonWaterElemental",
    function() cds[31687] = 180 end, false)
assert_lane("SummonWaterElemental blocked out of combat", "SummonWaterElemental",
    function() combat = false end, false)
assert_lane("SummonWaterElemental blocked when long-CD gate refuses", "SummonWaterElemental",
    function() longcd = false end, false)

-- ============================================================================
-- School lockout wave (2026-09-11): the engine's loss-of-control mask
-- (ctx.school_lockout) drives the off-school fallback. Fire Blast fires ONLY
-- while the frost school is interrupted; every frost cast holds in that window.
-- ============================================================================
assert_lane("FireBlast fires while the frost school is locked", "FireBlast",
    function() lockout = 16 end, true)
assert_lane("FireBlast blocked with no lockout", "FireBlast", function() end, false)
assert_lane("FireBlast blocked when fire is locked too", "FireBlast",
    function() lockout = 16 + 4 end, false)
assert_lane("FireBlast blocked out of combat", "FireBlast",
    function() lockout = 16; combat = false end, false)
assert_lane("Frostbolt holds while the frost school is locked", "Frostbolt",
    function() lockout = 16 end, false)
assert_lane("Frostbolt fires with no lockout", "Frostbolt", function() end, true)
assert_lane("IceLance holds on a frozen target under a frost lock", "IceLance",
    function() root(2); lockout = 16 end, false)
assert_lane("DeepFreeze holds on a frozen target under a frost lock", "DeepFreeze",
    function() root(2); lockout = 16 end, false)
assert_lane("FrostfireBolt holds under a frost lock", "FrostfireBolt",
    function() lockout = 16 end, false)

-- ============================================================================
-- Guide-pass lanes (2026-09-11): Mirror Image burst, Evocation mana refill and
-- the Ice Barrier shield band. All read real NS.spell_ready.
-- ============================================================================
assert_lane("MirrorImage fires off cooldown in combat", "MirrorImage", function() end, true)
assert_lane("MirrorImage blocked while on cooldown", "MirrorImage",
    function() cds[55342] = 180 end, false)
assert_lane("MirrorImage blocked out of combat", "MirrorImage",
    function() combat = false end, false)
assert_lane("MirrorImage blocked when long-CD gate refuses", "MirrorImage",
    function() longcd = false end, false)
assert_lane("Evocation fires below 40 mana", "Evocation",
    function() mana = 39 end, true)
assert_lane("Evocation blocked at 40 mana", "Evocation",
    function() mana = 40 end, false)
assert_lane("Evocation blocked while on cooldown", "Evocation",
    function() mana = 20; cds[12051] = 120 end, false)
assert_lane("Evocation blocked out of combat", "Evocation",
    function() mana = 20; combat = false end, false)
assert_lane("IceBarrier fires below 70% hp with no shield up", "IceBarrier",
    function() hp = 60 end, true)
assert_lane("IceBarrier blocked at 70% hp", "IceBarrier",
    function() hp = 70 end, false)
assert_lane("IceBarrier held while the shield is already up", "IceBarrier",
    function() hp = 60; buffs[43039] = true end, false)
assert_lane("IceBarrier blocked while on cooldown", "IceBarrier",
    function() hp = 60; cds[43039] = 30 end, false)

print("PASS test_mage_frost_wotlk_strategies")
