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

-- 2026-09-10 fire guide pass: make the scenario's mana_pct controllable for
-- the Evocation window pins, and is_moving for the Dragon's Breath gate.
local mana = 100
local moving = false

local enemies, aoe_ok = 1, false

local function reset_env()
    combat, casting, ttd, scorch_cast_time = true, false, 999, nil
    debuffs, buffs, not_ready, long_cd_refused = {}, {}, {}, {}
    enemies, aoe_ok = 1, false
    mana = 100
    moving = false
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    aoe_target_meets = function(n) return aoe_ok and enemies >= (n or 1) end,
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

local cast_remaining = nil
local cast_lead = nil
local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        is_moving = moving,
        enemy_count = enemies,
        ttd = ttd,
        scorch_cast_time = scorch_cast_time,
        target = { is_casting = function() return casting end },
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

-- ============================================================================
-- BlastWaveAoE: 3+ enemies in the 10y self radius (guide cleave slot).
-- ============================================================================
assert_lane("BlastWaveAoE fires into a 3-enemy pack", "BlastWaveAoE",
    function() enemies = 3; aoe_ok = true end, true)
assert_lane("BlastWaveAoE blocked at 2 enemies", "BlastWaveAoE",
    function() enemies = 2; aoe_ok = true end, false)
assert_lane("BlastWaveAoE fail-closed without the AoE module", "BlastWaveAoE",
    function() enemies = 4; aoe_ok = false end, false)
assert_lane("BlastWaveAoE blocked out of combat", "BlastWaveAoE",
    function() enemies = 4; aoe_ok = true; combat = false end, false)

-- ============================================================================
-- MirrorImage (55342): burst-CD lane behind the long-CD budget gate, mirroring
-- the Combustion pin shape.
-- ============================================================================
assert_lane("MirrorImage fires with the long-CD budget open", "MirrorImage",
    function() end, true)
assert_lane("MirrorImage held when the long-CD budget refuses 180s", "MirrorImage",
    function() long_cd_refused[180] = true end, false)
assert_lane("MirrorImage blocked out of combat", "MirrorImage",
    function() combat = false end, false)

-- ============================================================================
-- Evocation (12051): mana-recovery window at < 20% mana (arcane-pass gate).
-- ============================================================================
assert_lane("Evocation fires at 15% mana", "Evocation",
    function() mana = 15 end, true)
assert_lane("Evocation held at healthy mana", "Evocation",
    function() mana = 60 end, false)

-- ============================================================================
-- DragonsBreathAoE (42949 WotLK R5): instant cone cleave at 3+ stationary.
-- ============================================================================
assert_lane("DragonsBreathAoE fires into a stationary 3-pack", "DragonsBreathAoE",
    function() enemies = 3; aoe_ok = true end, true)
assert_lane("DragonsBreathAoE blocked at 2 enemies", "DragonsBreathAoE",
    function() enemies = 2; aoe_ok = true end, false)
assert_lane("DragonsBreathAoE blocked while moving", "DragonsBreathAoE",
    function() enemies = 3; aoe_ok = true; moving = true end, false)


-- ============================================================================
-- Engine cast/channel end-time gate (2026-09-12, shared/cast_timing_sylvanas).
-- Counterspell must HOLD when the target's cast is about to land (the interrupt
-- would arrive too late and burn its cooldown) and FIRE on a normal cast.
-- Unknown remaining (nil) keeps the pre-signal fail-open behavior.
-- ============================================================================
assert_lane("Counterspell fires with 1.0s left on the enemy cast", "Counterspell",
    function() casting = true; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("Counterspell holds when only 0.05s of the cast remains", "Counterspell",
    function() casting = true; cast_remaining = 0.05; cast_lead = nil end, false)
assert_lane("Counterspell holds ON the 0.30s lead floor", "Counterspell",
    function() casting = true; cast_remaining = 0.30; cast_lead = nil end, false)
assert_lane("Counterspell fires above the 0.30s lead floor", "Counterspell",
    function() casting = true; cast_remaining = 0.31; cast_lead = nil end, true)
assert_lane("Counterspell honours a raised interrupt_lead_sec setting", "Counterspell",
    function() casting = true; cast_remaining = 0.9; cast_lead = 1.2 end, false)

print("PASS test_mage_fire_wotlk_strategies")
