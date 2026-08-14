-- test_warrior_dps_live_fixes.lua -- Warrior DPS live-correctness regression tests.
-- WHAT:  Pins the 2026-08-12 live-correctness fixes for arms / fury / kebab:
--        arms Sunder requires BATTLE stance (was DEFENSIVE -> unreachable),
--        arms DSL Execute requires Battle-or-Berserker (was stance-agnostic),
--        arms BattleStance swaps OOC when Charge is ready, arms Pummel gets an
--        interrupt-driven stance swap, fury Overpower proc no longer requires
--        Battle stance (was a circular dependency -> weave unreachable from
--        Berserker), fury Charge stance guard is no longer dead, kebab
--        Healthstone gates on real hp_pct (was always-true -> stone burned at
--        full HP), kebab ThunderClap / SunderMaintain stance-cast from any
--        stance, kebab context.stance reads are nil-safe.
-- WHEN:  Run standalone: lua EaxRotations/tests/test_warrior_dps_live_fixes.lua
-- WHY:   These bugs were verified live (audit campaign 2026-08-12); lock the
--        fixed behavior in so they cannot silently regress.
-- SAFETY: Pure unit tests with mocked _G.EaxRotations + mocked helpers; no
--         engine, no io writes, no shared-module edits. Not registered in any
--         runner (standalone only).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- ============================================================================
-- Shared mock primitives
-- ============================================================================
local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

local WARRIOR_SPELLS = {
    BattleShout = 6673, BattleStance = 2457, BerserkerRage = 18499,
    BerserkerStance = 2458, Bloodrage = 2687, Charge = 100,
    Cleave = 845, CommandingShout = 469, DeathWish = 12292,
    DefensiveStance = 71, DemoralizingShout = 1160, Disarm = 676,
    Execute = 5308, Hamstring = 1715, HeroicStrike = 78,
    Intercept = 20252, IntimidatingShout = 5246, MortalStrike = 12294,
    Overpower = 7384, PiercingHowl = 12323, Pummel = 6554,
    Recklessness = 1719, Rend = 772, Retaliation = 20230,
    ShieldWall = 871, Slam = 1464, SpellReflection = 23920,
    SunderArmor = 7386, SweepingStrikes = 12328, ThunderClap = 6343,
    VictoryRush = 34428, Whirlwind = 1680, Devastate = 30022,
    Rampage = 29801,
}

-- spell_ready spy: controllable per-spell-id; default true.
local ready_overrides = {}
local function spell_ready_spy(spell, target, opts)
    local id = type(spell) == "table" and (spell.ids and spell.ids[1]) or spell
    if ready_overrides[id] ~= nil then return ready_overrides[id] end
    return true
end

local function make_warrior_ns()
    local ns = {
        CLASS_ID = { WARRIOR = 1 },
        WarriorSpells = WARRIOR_SPELLS,
        WarriorConstants = {
            STANCE = STANCE,
            SUNDER_DEBUFF = { 7386 }, THUNDER_CLAP_DEBUFF = { 6343 },
            DEMO_SHOUT_DEBUFF = { 1160 }, BATTLE_SHOUT_IDS = { 6673 },
            COMMANDING_SHOUT_BUFF = { 469 },
            BUFF_ID = { SWEEPING_STRIKES = 12328 },
            SUNDER_MAX_STACKS = 5, SUNDER_REFRESH_WINDOW = 3,
            TC_REFRESH_WINDOW = 2,
        },
        PLAYER_UNIT = { get_class = function() return 1 end },
        GetPlayer = function() return { get_class = function() return 1 end } end,
        time_now = function() return 1000 end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        get_debuff_stacks = function() return 0 end,
        cooldown_remains = function() return 99 end,
        spell_ready = spell_ready_spy,
        is_interruptible = function() return true end,
        is_execute_phase = function(hp, t) return (hp or 100) <= (t or 20) end,
        get_tactical_mastery_cap = function() return 25 end,
        is_item_ready = function() return false end,
        has_form = function() return false end,
        aoe_target_meets = function() return false end,
        aoe_self_meets = function() return false end,
        AOE_RADIUS = { TARGET_8 = 8, SELF_8 = 8, SELF_10 = 10 },
        try_interrupt = function() return false end,
        is_current_spell = function() return false end,
        get_spell_id = function(spell) return type(spell) == "table" and spell.ids and spell.ids[1] or spell end,
        get_time_until_swing = function() return nil end,
        get_time_until_oh_swing = function() return nil end,
        get_equipped_item_id = function() return nil end,
        use_item_by_id = function() return true end,
        log = function() end,
        rotation_registry = { register = function() end },
    }
    -- kebab-style helper import surface
    ns.import_helpers = function(...)
        local out = {}
        for _, key in ipairs({ ... }) do
            if key == "health_pct" then out[key] = function() return 100 end
            elseif key == "debuff_remains" or key == "debuff_stacks" or key == "buff_remains" then out[key] = function() return 0 end
            elseif key == "player_control_locked" or key == "has_player_buff" or key == "has_breakable_cc_nearby" then out[key] = function() return false end
            else out[key] = function() return true end
            end
        end
        return out.try_cast or function() return true end,
            out.spell_exists or function() return true end,
            out.spell_ready or function() return true end,
            out.debuff_remains or function() return 0 end,
            out.debuff_stacks or function() return 0 end,
            out.buff_remains or function() return 0 end,
            out.health_pct or function() return 100 end,
            out.player_control_locked or function() return false end,
            out.has_player_buff or function() return false end,
            out.has_breakable_cc_nearby or function() return false end,
            out.can_attack_target or function() return true end
    end
    return ns
end

package.loaded["common/enums"] = { class_id = { WARRIOR = 1 } }
package.loaded["common/utility/inventory_helper"] = { has_item = function(id) return true end }

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- ARMS
-- ============================================================================
local function load_arms()
    ready_overrides = {}
    _G.EaxRotations = make_warrior_ns()
    local result = dofile("EaxRotations/classes/warrior/arms_sylvanas.lua")
    return result.strategies, result.build_state
end

-- Fix 1: Sunder requires BATTLE stance (was DEFENSIVE -> unreachable in arms)
do
    local strategies = load_arms()
    local sunder = find_strategy(strategies, "SunderArmor")
    local ctx = { target = {}, target_armor = 5000, rage = 30, target_hp = 80,
                  settings = { use_sunder_armor = true } }
    ctx.stance = STANCE.BATTLE
    assert_true(sunder.matches(ctx), "arms SunderArmor should match in Battle stance (fix: BATTLE, was DEFENSIVE)")
    ctx.stance = STANCE.DEFENSIVE
    assert_false(sunder.matches(ctx), "arms SunderArmor should NOT match in Defensive stance (requires Battle)")
    ctx.stance = STANCE.BERSERKER
    assert_false(sunder.matches(ctx), "arms SunderArmor should NOT match in Berserker stance (requires Battle)")
end

-- Fix 2: DSL Execute requires Battle-or-Berserker (was stance-agnostic)
do
    local strategies = load_arms()
    local execute = find_strategy(strategies, "Execute")
    local ctx = { target = {}, target_hp = 15, rage = 50, settings = {} }
    ctx.stance = STANCE.BATTLE
    assert_true(execute.matches(ctx), "arms Execute should match in Battle stance")
    ctx.stance = STANCE.BERSERKER
    assert_true(execute.matches(ctx), "arms Execute should match in Berserker stance (TBC Execute allows both)")
    ctx.stance = STANCE.DEFENSIVE
    assert_false(execute.matches(ctx), "arms Execute should NOT match in Defensive stance (TBC requires Battle/Berserker)")
end

-- Fix 3: BattleStance swaps OOC when Charge is ready (so the next pull's
-- Charge isn't blocked from a non-Battle stance)
do
    local strategies = load_arms()
    ready_overrides = { [WARRIOR_SPELLS.Overpower] = false }  -- isolate the charge branch
    local battle_stance = find_strategy(strategies, "BattleStance")
    local ctx = { target = {}, stance = STANCE.BERSERKER, in_combat = false, rage = 30,
                  target_distance = 15, settings = {} }
    assert_true(battle_stance.matches(ctx), "arms BattleStance should swap OOC when Charge is ready (fix: OOC charge branch)")
    ctx.in_combat = true
    assert_false(battle_stance.matches(ctx), "arms BattleStance should NOT swap via charge branch while in combat")
end

-- Fix 4: Pummel gets an interrupt-driven stance swap (BerserkerStance swaps in
-- so Pummel is reachable in PvE interrupt windows)
do
    local strategies = load_arms()
    local berserker_stance = find_strategy(strategies, "BerserkerStance")
    local pummel = find_strategy(strategies, "Pummel")
    local ctx = { target = {}, stance = STANCE.BATTLE, rage = 30, target_is_casting = true,
                  settings = {} }
    assert_true(berserker_stance.matches(ctx), "arms BerserkerStance should swap in for an interruptible cast (fix: interrupt branch)")
    -- Pummel itself still requires Berserker stance
    assert_false(pummel.matches(ctx), "arms Pummel should not match from Battle stance")
    ctx.stance = STANCE.BERSERKER
    assert_true(pummel.matches(ctx), "arms Pummel should match from Berserker stance when target casts")
end

-- ============================================================================
-- FURY
-- ============================================================================
local function load_fury()
    ready_overrides = {}
    _G.EaxRotations = make_warrior_ns()
    local result = dofile("EaxRotations/classes/warrior/fury_sylvanas.lua")
    return result.strategies, result.build_state
end

-- Fix 1: Overpower weave cycle break — overpower_ready must NOT require Battle
-- stance (the old gate made the weave unreachable from Berserker)
do
    local strategies, build_state = load_fury()
    ready_overrides = { [WARRIOR_SPELLS.Overpower] = true }
    local state = build_state({ target = {}, stance = STANCE.BERSERKER, in_combat = true, rage = 50, settings = {} })
    assert_true(state.overpower_ready == true,
        "fury overpower_ready should be true in Berserker stance when Overpower is ready (fix: stance gate removed)")
    -- And the BattleStance strategy should now swap in from Berserker for the weave
    local battle_stance = find_strategy(strategies, "BattleStance")
    local ctx = { target = {}, stance = STANCE.BERSERKER, in_combat = true, rage = 50, settings = {} }
    assert_true(battle_stance.matches(ctx), "fury BattleStance should swap to Battle when Overpower proc is ready (cycle fixed)")
end

-- Fix 2: charge stance guard is meaningful (not the dead stance_swap_safe(0))
do
    local strategies = load_fury()
    local charge = find_strategy(strategies, "Charge")
    local ctx = { target = { is_in_combat = function() return false end }, in_combat = false,
                  stance = STANCE.BATTLE, rage = 30, target_distance = 15, settings = {} }
    assert_true(charge.matches(ctx), "fury Charge should match OOC in Battle stance")
    ctx.stance = STANCE.BERSERKER
    assert_false(charge.matches(ctx), "fury Charge should not match from Berserker stance (meaningful stance gate)")
end

-- ============================================================================
-- KEBAB
-- ============================================================================
local function load_kebab()
    ready_overrides = {}
    _G.EaxRotations = make_warrior_ns()
    local result = dofile("EaxRotations/classes/warrior/kebab_sylvanas.lua")
    return result.strategies, result.build_state
end

-- Fix 1: Healthstone gates on real hp_pct (was never populated -> always true)
do
    local strategies = load_kebab()
    local hs = find_strategy(strategies, "Healthstone")
    local ctx = { target = {}, in_combat = true, rage = 30, settings = {}, stance = STANCE.BATTLE }
    ctx.hp = 100
    assert_false(hs.matches(ctx), "kebab Healthstone should NOT fire at full HP (fix: hp_pct populated, was always-true)")
    ctx.hp = 25
    assert_true(hs.matches(ctx), "kebab Healthstone should fire at 25% HP")
end

-- Fix 2: ThunderClap stance-casts into Battle from any stance
do
    local strategies = load_kebab()
    local tc = find_strategy(strategies, "ThunderClap")
    local ctx = { target = {}, in_combat = true, rage = 40, settings = {}, stance = STANCE.BERSERKER }
    assert_true(tc.matches(ctx), "kebab ThunderClap should match from Berserker stance via BattleStance cast (fix: stance-cast)")
    ctx.stance = STANCE.BATTLE
    assert_true(tc.matches(ctx), "kebab ThunderClap should still match in Battle stance")
end

-- Fix 3: SunderMaintain stance-casts into Defensive from DW-Arms stances
do
    local strategies = load_kebab()
    local sunder = find_strategy(strategies, "SunderMaintain")
    local ctx = { target = {}, in_combat = true, rage = 40, target_armor = 5000,
                  settings = { sunder_armor_mode = "maintain" }, stance = STANCE.BATTLE }
    assert_true(sunder.matches(ctx), "kebab SunderMaintain should match from Battle stance via DefensiveStance cast (fix: stance-cast)")
    ctx.stance = STANCE.DEFENSIVE
    assert_true(sunder.matches(ctx), "kebab SunderMaintain should still match in Defensive stance")
end

-- Fix 4: nil context.stance must not produce wrong stance-cast decisions
do
    local strategies = load_kebab()
    local execute = find_strategy(strategies, "Execute")
    local ctx = { target = {}, in_combat = true, rage = 40, target_hp = 15, settings = {} }
    -- stance omitted -> nil-safe (defaults to "not wrong-stance", no crash)
    local ok = pcall(function() return execute.matches(ctx) end)
    assert_true(ok, "kebab Execute should not crash with nil context.stance (fix: nil-safe stance reads)")
end

print("PASS test_warrior_dps_live_fixes")
