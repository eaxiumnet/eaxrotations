-- test_mage_fire_wotlk_strategies.lua — Fire mage WotLK behavioral strategy
-- match-gate scenarios.
-- WHAT:  Drives the REAL fire_wotlk.lua through its real build_state read path
--        (NS.debuff_remains for the 55360 Living Bomb debuff and the 22959
--        Fire Vulnerability Scorch debuff, NS.buff_up for the 44448 Hot Streak
--        proc, target:is_casting for Counterspell, ctx.ttd and the resolved
--        Scorch cast time for the FireBlast anticipation lane), pinning both
--        sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): fire had sparse live-fix pins;
--        every gate here is pinned through the real read path.
-- SAFETY: Pure unit tests with a mocked NS; the real fire_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local casting = false
local ttd = 999
local scorch_cast_time = nil
local debuffs = {}
local buffs = {}
local not_ready = {}
local long_cd_refused = {}

local function lb(secs) debuffs[55360] = secs end
local function scorch(secs) debuffs[22959] = secs end
local function hot_streak(up) buffs[44448] = up or nil end

local function reset_env()
    combat, casting, ttd, scorch_cast_time = true, false, 999, nil
    debuffs, buffs, not_ready, long_cd_refused = {}, {}, {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
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
    spell_ready = function(spell, target)
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

local result = dofile("EaxRotations/classes/mage/fire_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "fire_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = 100,
        enemy_count = 1,
        ttd = ttd,
        scorch_cast_time = scorch_cast_time,
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
-- Combustion: combat + target + long-CD (180s) permitted.
-- ============================================================================
assert_lane("Combustion fires in combat", "Combustion", function() end, true)
assert_lane("Combustion blocked out of combat", "Combustion", function() combat = false end, false)
assert_lane("Combustion blocked when long CDs are refused", "Combustion",
    function() long_cd_refused[180] = true end, false)

-- ============================================================================
-- Scorch (Improved Scorch upkeep): debuff at/below 4s.
-- ============================================================================
assert_lane("Scorch refreshes at 4s remaining", "Scorch", function() scorch(4) end, true)
assert_lane("Scorch refreshes when the debuff is down", "Scorch", function() end, true)
assert_lane("Scorch blocked while the debuff is healthy", "Scorch", function() scorch(5) end, false)
assert_lane("Scorch blocked out of combat", "Scorch",
    function() combat = false end, false)

-- ============================================================================
-- Pyroblast: Hot Streak proc consumer (44448) — proc-up lane.
-- ============================================================================
assert_lane("Pyroblast fires during Hot Streak", "Pyroblast",
    function() hot_streak(true) end, true)
assert_lane("Pyroblast blocked without Hot Streak", "Pyroblast", function() end, false)
assert_lane("Pyroblast blocked out of combat even with the proc", "Pyroblast",
    function() combat = false; hot_streak(true) end, false)

-- ============================================================================
-- Living Bomb: refresh on expiry (<= 0) with TTD > 12.
-- ============================================================================
assert_lane("LivingBomb drops when the debuff is down and TTD is long", "LivingBomb",
    function() ttd = 13 end, true)
assert_lane("LivingBomb blocked while the debuff is live", "LivingBomb",
    function() lb(1); ttd = 999 end, false)
assert_lane("LivingBomb blocked when TTD is 12 (bomb would not pay)", "LivingBomb",
    function() ttd = 12 end, false)
assert_lane("LivingBomb blocked when TTD is under 12", "LivingBomb",
    function() ttd = 6 end, false)

-- ============================================================================
-- FireBlast: TTD anticipation — cast must not finish before the target dies.
-- ============================================================================
assert_lane("FireBlast fires when TTD fits inside the Scorch cast", "FireBlast",
    function() scorch_cast_time = 1.5; ttd = 1.5 end, true)
assert_lane("FireBlast blocked when TTD exceeds the cast time", "FireBlast",
    function() scorch_cast_time = 1.5; ttd = 1.6 end, false)
assert_lane("FireBlast blocked without a resolvable cast time", "FireBlast",
    function() scorch_cast_time = nil; ttd = 1.5 end, false)

-- ============================================================================
-- ScorchFinal: execute-speed filler when TTD <= 4 (even with debuff up).
-- ============================================================================
assert_lane("ScorchFinal fires at TTD 4", "ScorchFinal", function() ttd = 4 end, true)
assert_lane("ScorchFinal blocked at TTD above 4", "ScorchFinal", function() ttd = 5 end, false)

-- ============================================================================
-- Fireball: unconditional in-combat filler.
-- ============================================================================
assert_lane("Fireball fires in combat", "Fireball", function() end, true)
assert_lane("Fireball blocked out of combat", "Fireball", function() combat = false end, false)

print("PASS test_mage_fire_wotlk_strategies")
