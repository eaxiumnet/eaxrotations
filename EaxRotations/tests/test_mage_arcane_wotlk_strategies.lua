-- test_mage_arcane_wotlk_strategies.lua — Arcane mage WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL arcane_wotlk.lua through its real build_state read
--        path (NS.buff_stacks for the 36032 Arcane Blast stack aura,
--        NS.buff_up for Missile Barrage 44401 / Arcane Power / Icy Veins /
--        Mage Armor, NS.spell_ready for Presence of Mind, target:is_casting
--        for Counterspell, ctx.mana_pct), pinning both sides of every lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): mage arcane had only sparse
--        live-fix pins; every gate here is pinned through the real read path.
-- SAFETY: Pure unit tests with a mocked NS; the real arcane_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local combat = true
local casting = false
local stack_buffs = {}    -- id -> stacks (NS.buff_stacks)
local buffs = {}          -- id -> true (NS.buff_up)
local not_ready = {}      -- spell id on CD (NS.spell_ready false)
local long_cd_refused = {}  -- seconds refused by NS.should_use_long_cd

local function ab_stacks(n) stack_buffs[36032] = n end
local function set_buff(id, up) buffs[id] = up or nil end
local function proc_ab(n) set_buff(44401, n) end

local function reset_env()
    mana, combat, casting = 100, true, false
    stack_buffs, buffs, not_ready, long_cd_refused = {}, {}, {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    buff_stacks = function(unit, ids)
        for _, id in ipairs(ids) do
            local n = stack_buffs[id]
            if n and n > 0 then return n end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    spell_ready = function(spell, target, opts)
        local id = type(spell) == "number" and spell
            or (spell and (spell.id or (type(spell) == "table" and (spell[1] or (spell._meta and spell._meta.max_rank))) or 0))
        if not_ready[id] then return false end
        return true
    end,
    should_use_long_cd = function(context, seconds)
        if long_cd_refused[seconds] then return false end
        return true
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/mage/arcane_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "arcane_wotlk strategies should load")

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
        enemy_count = 1,
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
assert_lane("Counterspell blocked out of combat", "Counterspell",
    function() combat = false; casting = true end, false)

-- ============================================================================
-- Mage Armor: buff upkeep — no combat gate (prepull legal).
-- ============================================================================
assert_lane("MageArmor fires when the armor buff is down (even OOC)", "MageArmor",
    function() combat = false end, true)
assert_lane("MageArmor blocked while the buff is up", "MageArmor",
    function() set_buff(43024, true) end, false)

-- ============================================================================
-- Evocation: mana below 20 — OOC legal, boundary at 20.
-- ============================================================================
assert_lane("Evocation fires at 19 mana", "Evocation", function() mana = 19 end, true)
assert_lane("Evocation fires out of combat", "Evocation",
    function() combat = false; mana = 5 end, true)
assert_lane("Evocation blocked at 20 mana", "Evocation", function() mana = 20 end, false)

-- ============================================================================
-- Mana Gem: 20 <= mana < 40 window.
-- ============================================================================
assert_lane("ManaGem fires at 39 mana", "ManaGem", function() mana = 39 end, true)
assert_lane("ManaGem fires at 20 mana", "ManaGem", function() mana = 20 end, true)
assert_lane("ManaGem blocked at 40 mana", "ManaGem", function() mana = 40 end, false)
assert_lane("ManaGem blocked at 19 mana (Evocation zone)", "ManaGem", function() mana = 19 end, false)

-- ============================================================================
-- Arcane Power: combat + not up + long-CD (120s) permitted.
-- ============================================================================
assert_lane("ArcanePower fires in combat with the buff down", "ArcanePower", function() end, true)
assert_lane("ArcanePower blocked while already up", "ArcanePower",
    function() set_buff(12042, true) end, false)
assert_lane("ArcanePower blocked out of combat", "ArcanePower",
    function() combat = false end, false)
assert_lane("ArcanePower blocked when long CDs are refused", "ArcanePower",
    function() long_cd_refused[120] = true end, false)

-- ============================================================================
-- Icy Veins: combat + not up + long-CD (180s) permitted.
-- ============================================================================
assert_lane("IcyVeins fires in combat with the buff down", "IcyVeins", function() end, true)
assert_lane("IcyVeins blocked while already up", "IcyVeins",
    function() set_buff(12472, true) end, false)
assert_lane("IcyVeins blocked out of combat", "IcyVeins",
    function() combat = false end, false)
assert_lane("IcyVeins blocked when long CDs are refused", "IcyVeins",
    function() long_cd_refused[180] = true end, false)

-- ============================================================================
-- Mirror Image: combat only.
-- ============================================================================
assert_lane("MirrorImage fires in combat", "MirrorImage", function() end, true)
assert_lane("MirrorImage blocked out of combat", "MirrorImage", function() combat = false end, false)

-- ============================================================================
-- Presence of Mind: combat + real spell_ready (12043) + long-CD (180s).
-- ============================================================================
assert_lane("PresenceOfMind fires ready in combat", "PresenceOfMind", function() end, true)
assert_lane("PresenceOfMind blocked on cooldown", "PresenceOfMind",
    function() not_ready[12043] = true end, false)
assert_lane("PresenceOfMind blocked out of combat", "PresenceOfMind",
    function() combat = false end, false)
assert_lane("PresenceOfMind blocked when long CDs are refused", "PresenceOfMind",
    function() long_cd_refused[180] = true end, false)

-- ============================================================================
-- Arcane Missiles: Missile Barrage proc consumer (44401).
-- ============================================================================
assert_lane("ArcaneMissiles fires on the Missile Barrage proc", "ArcaneMissiles",
    function() proc_ab(true) end, true)
assert_lane("ArcaneMissiles blocked without the proc", "ArcaneMissiles", function() end, false)

-- ============================================================================
-- Arcane Barrage: 4-stack dump (>= 4).
-- ============================================================================
assert_lane("ArcaneBarrage fires at the 4-stack cap", "ArcaneBarrage",
    function() ab_stacks(4) end, true)
assert_lane("ArcaneBarrage blocked at 3 stacks", "ArcaneBarrage",
    function() ab_stacks(3) end, false)
assert_lane("ArcaneBarrage blocked at 0 stacks", "ArcaneBarrage", function() end, false)

-- ============================================================================
-- Arcane Blast: mana >= 20 and stacks < 4 (stacking zone).
-- ============================================================================
assert_lane("ArcaneBlast fires at 20 mana on 0 stacks", "ArcaneBlast",
    function() mana = 20 end, true)
assert_lane("ArcaneBlast fires at 3 stacks", "ArcaneBlast",
    function() mana = 100; ab_stacks(3) end, true)
assert_lane("ArcaneBlast blocked at the 4-stack cap", "ArcaneBlast",
    function() mana = 100; ab_stacks(4) end, false)
assert_lane("ArcaneBlast blocked below 20 mana", "ArcaneBlast",
    function() mana = 19 end, false)

print("PASS test_mage_arcane_wotlk_strategies")
