-- test_fury_wotlk_strategies.lua — Fury WotLK strategy match-gate scenarios.
-- WHAT:  Exercises the fury_wotlk.lua DSL lanes under era-appropriate state:
--        Berserker-stance enforcement, execute thresholds, Bloodsurge-gated
--        Slam, CD/rage gates, Death Wish long-CD policy, interrupt lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): fury_wotlk had only static
--        priority-order coverage; this mirrors the TBC/vanilla strategy suites
--        by pinning WHICH lane fires under WHICH state, era-correctly.
-- SAFETY: Pure unit tests with a mocked NS; the real fury_wotlk.lua file loads.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- ---------------------------------------------------------------------------
-- Mutable scenario state (read by the mock NS closures at build_state time).
-- ---------------------------------------------------------------------------
local stance = STANCE.BERSERKER
local ctx_rage = 0
local target_hp = 100
local cds = {}               -- spell id -> seconds remaining (0 = ready)
local buffs = {}             -- buff id -> true
local target_casting = false
local interruptible = true
local long_cd_ok = true

local me = {
    get_power = function() return 0 end,
    get_health_percentage = function() return 100 end,
    get_stance = function() return stance end,
}

local function mk_target()
    return {
        get_health_percentage = function() return target_hp end,
        is_casting = function() return target_casting end,
    }
end

_G.EaxRotations = {
    WarriorSpells = {},
    WarriorConstants = { STANCE = STANCE },
    POWER_RAGE = 1,
    PLAYER_UNIT = {},
    me = me,
    GetPlayer = function() return me end,
    spell_action = function(rank_ids, label)
        local id = type(rank_ids) == "table" and rank_ids[1] or rank_ids
        return {
            id = id,
            ids = type(rank_ids) == "table" and rank_ids or { rank_ids },
            name = label or tostring(id),
        }
    end,
    buff_up = function(_, ids)
        for _, i in ipairs(ids) do if buffs[i] then return true end end
        return false
    end,
    cooldown_remains = function(action) return cds[action and action.id] or 0 end,
    is_interruptible = function() return interruptible end,
    should_use_long_cd = function() return long_cd_ok end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warrior/fury_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "fury_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- Apply a state mutation, evaluate ONE lane on an in-combat single-target ctx,
-- assert the expected match, then restore the mutable scenario state.
local cast_remaining = nil
local cast_lead = nil
local function scenario(label, strategy_name, mutations, expect_match, in_combat)
    local save = { stance, ctx_rage, target_hp, target_casting, interruptible, long_cd_ok }
    for k in pairs(cds) do cds[k] = nil end
    for k in pairs(buffs) do buffs[k] = nil end
    mutations()
    local combat = in_combat ~= false
    local ctx = { in_combat = combat, target = mk_target(), settings = { interrupt_lead_sec = cast_lead }, target_cast_remaining = cast_remaining, enemy_count = 1, rage = ctx_rage }
    local state = result.build_state(ctx)
    local s = find_strategy(strategy_name)
    local matched = s.matches(ctx, state)
    if expect_match then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
    stance, ctx_rage, target_hp, target_casting, interruptible, long_cd_ok =
        save[1], save[2], save[3], save[4], save[5], save[6]
end

-- ============================================================================
-- BerserkerStance dance-back (APL final lane): in combat and NOT already
-- Berserker -> dance; already Berserker -> no-op; OOC -> no-op.
-- ============================================================================
scenario("fury dances to Berserker from Battle in combat", "BerserkerStance",
    function() stance = STANCE.BATTLE end, true)
scenario("fury stays in Berserker (no dance needed)", "BerserkerStance",
    function() stance = STANCE.BERSERKER end, false)
scenario("fury does not stance-dance out of combat", "BerserkerStance",
    function() stance = STANCE.BATTLE end, false, false)

-- ============================================================================
-- Execute: target < 20% and rage >= 15 (WotLK cost).
-- ============================================================================
scenario("Execute fires in execute range", "Execute",
    function() ctx_rage = 25; target_hp = 12 end, true)
scenario("Execute blocked above 20%", "Execute",
    function() ctx_rage = 100; target_hp = 45 end, false)
scenario("Execute blocked below 15 rage", "Execute",
    function() ctx_rage = 10; target_hp = 8 end, false)

-- ============================================================================
-- Bloodthirst: rage >= 30, cooldown ready.
-- ============================================================================
scenario("Bloodthirst fires at 30+ rage off cooldown", "Bloodthirst",
    function() ctx_rage = 35 end, true)
scenario("Bloodthirst blocked while on cooldown", "Bloodthirst",
    function() ctx_rage = 100; cds[30335] = 4 end, false)
scenario("Bloodthirst blocked below 30 rage", "Bloodthirst",
    function() ctx_rage = 25 end, false)

-- ============================================================================
-- Whirlwind: Berserker-only, rage >= 25, cooldown ready.
-- ============================================================================
scenario("Whirlwind fires in Berserker with rage", "Whirlwind",
    function() ctx_rage = 30; stance = STANCE.BERSERKER end, true)
scenario("Whirlwind blocked in Battle stance (WotLK)", "Whirlwind",
    function() ctx_rage = 100; stance = STANCE.BATTLE end, false)
scenario("Whirlwind blocked while on cooldown", "Whirlwind",
    function() ctx_rage = 100; stance = STANCE.BERSERKER; cds[1680] = 6 end, false)

-- ============================================================================
-- Slam: Bloodsurge-proc-gated (instant + free) — never a hard-cast filler.
-- ============================================================================
scenario("Slam fires on a Bloodsurge proc", "Slam",
    function() ctx_rage = 20; buffs[46916] = true end, true)
scenario("Slam blocked without Bloodsurge (no filler spam)", "Slam",
    function() ctx_rage = 100 end, false)

-- ============================================================================
-- Pummel: Berserker-only interrupt lane, rage >= 10.
-- ============================================================================
scenario("Pummel fires when interrupting in Berserker", "Pummel",
    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = true end, true)
scenario("Pummel blocked when target is not casting", "Pummel",
    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = false end, false)
scenario("Pummel blocked in Battle stance", "Pummel",
    function() ctx_rage = 15; stance = STANCE.BATTLE; target_casting = true end, false)

-- ============================================================================
-- Death Wish: cooldown ready + long-CD policy (suppressed on trash).
-- ============================================================================
scenario("Death Wish fires when policy allows", "DeathWish",
    function() ctx_rage = 0; long_cd_ok = true end, true)
scenario("Death Wish suppressed when long-CD policy declines", "DeathWish",
    function() ctx_rage = 0; long_cd_ok = false end, false)
scenario("Death Wish blocked while on cooldown", "DeathWish",
    function() ctx_rage = 0; cds[12292] = 30; long_cd_ok = true end, false)

-- ============================================================================
-- Battle Shout maintenance (buff-down only; no rage cost gate).
-- ============================================================================
local bs_ctx = { in_combat = true, target = mk_target(), settings = {}, rage = 0 }
buffs[47436] = nil
assert_true(find_strategy("BattleShout").matches(bs_ctx, result.build_state(bs_ctx)),
    "BattleShout should fire when the buff is down")
buffs[47436] = true
assert_false(find_strategy("BattleShout").matches(bs_ctx, result.build_state(bs_ctx)),
    "BattleShout should not fire when the buff is up")

-- ============================================================================
-- Pummel end-time gate (2026-09-12, shared/cast_timing_sylvanas). An
-- interrupt whose lead is at or below 0.30s is refused -- the cast lands
-- first and the cooldown is wasted. Unknown remaining stays fail-open.
-- ============================================================================
scenario("Pummel fires with 1.0s left on the enemy cast", "Pummel",    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = true; cast_remaining = 1.0; cast_lead = nil end, true)scenario("Pummel holds when only 0.05s of the cast remains", "Pummel",    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = true; cast_remaining = 0.05; cast_lead = nil end, false)scenario("Pummel holds ON the 0.30s lead floor", "Pummel",    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = true; cast_remaining = 0.30; cast_lead = nil end, false)scenario("Pummel fires above the 0.30s lead floor", "Pummel",    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = true; cast_remaining = 0.31; cast_lead = nil end, true)scenario("Pummel honours a raised interrupt_lead_sec setting", "Pummel",    function() ctx_rage = 15; stance = STANCE.BERSERKER; target_casting = true; cast_remaining = 0.9; cast_lead = 1.2 end, false)print("PASS test_fury_wotlk_strategies")
