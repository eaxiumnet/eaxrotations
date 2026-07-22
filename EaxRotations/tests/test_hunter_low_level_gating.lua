-- test_hunter_low_level_gating.lua -- Hunter pre-Steady / low-level silent-gate regression.
-- WHAT:  Ensures BM/MM/SV/leveling do not go silent at levels 20-50 when Steady Shot
--         (lvl 62) and Kill Command (lvl 66) are unavailable.
-- WHEN:  During rotation test suite execution.
-- WHY:   Mirrors the Druid Feral Mangle low-level fix: endgame gates must not silence
--         the rotation before key abilities are learned.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local runner_lib = require("tests/test_runner_lib")

local passed, failed, assertions = 0, 0, 0

local function assert_true(v, label)
    assertions = assertions + 1
    if not v then error(label or "assert_true failed", 2) end
end

local function assert_false(v, label)
    assertions = assertions + 1
    if v then error(label or "assert_false failed", 2) end
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        failed = failed + 1
        print("  FAIL: " .. name .. " -- " .. tostring(err))
    end
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

-- ============================================================================
-- Mock environment for BM (needs hunter_core)
-- ============================================================================
_G.core = { object_manager = { get_local_player = function() return {} end } }
_G.EaxRotations = {
    HunterSpells = {
        AspectOfTheHawk = 13165, AspectOfTheViper = 34074,
        ArcaneShot = 3044, SerpentSting = 1978, SteadyShot = 34120,
        MultiShot = 25294, HuntersMark = 14325, KillCommand = 34026,
        BestialWrath = 19574, RapidFire = 3045, Readiness = 23989,
        FeignDeath = 5384, FreezingTrap = 1499, ExplosiveTrap = 13812,
        MendPet = 136, CallPet = 883, RevivePet = 982, Intimidation = 19577,
        ViperSting = 3034, ScorpidSting = 3043, WingClip = 2974,
        RaptorStrike = 2973, AimedShot = 19434, TrueshotAura = 19506,
        SilencingShot = 34490, ConcussiveShot = 5116, Volley = 1510,
        Misdirection = 34477, MongooseBite = 1495, ImmolationTrap = 13795,
        SnakeTrap = 34600, WyvernSting = 19386, ScareBeast = 1513,
    },
    action_matches = function() return true end,
    action_execute = function() return true end,
    spell_ready = function() return true end,
    spell_action = function(ids, name) return { name = name, ids = ids } end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    try_cast = function() return true end,
    is_spell_learned = function() return true end,
    use_item_by_id = function() return true end,
    unit_mana_pct = function() return 40 end,
    cooldown_remains = function() return 0 end,
    time_now = function() return 100 end,
    log = function() end,
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    GetFocus = function() return nil end,
    rotation_registry = { register = function() end },
    PLAYER_UNIT = {},
}

package.preload["shared/hunter_core_sylvanas"] = function()
    return {
        get_pet = function() return nil end,
        pet_alive = function() return false end,
        pet_hp_pct = function() return 100 end,
        should_viper = function(m) return m < 20 end,
        should_hawk = function(m) return m >= 20 end,
        can_cast_instant = function() return true end,
        can_cast_steady = function() return true end,
        should_feign_death = function() return false end,
        sting_remains = function() return 0 end,
        record_mend = function() end,
        record_instant_shot = function() end,
        record_steady_start = function() end,
        get_auto_shot_buffer_ms = function() return 150 end,
    }
end
package.preload["shared/shot_timer_sylvanas"] = function()
    return { should_delay_cast = function() return false end, get_auto_shot_buffer_ms = function() return 150 end }
end
package.preload["shared/targeting_sylvanas"] = function() return {} end
package.preload["shared/pet_manager_sylvanas"] = function()
    return { set_defensive = function() return true end, set_passive = function() return true end, set_aggressive = function() return true end }
end
package.preload["shared/potion_helper_sylvanas"] = function()
    return { try_use_potion = function() return false end, HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {} }
end
package.preload["shared/hit_cap_tracker_sylvanas"] = function()
    return { get_hit_cap = function() return nil end }
end
package.preload["shared/cooldown_planner_sylvanas"] = function()
    return { is_major_offensive_cd_active = function() return false end }
end
package.preload["common/utility/inventory_helper"] = function()
    return { has_item = function() return false end }
end
-- Do NOT mock shared/leveling_sylvanas via package.preload — that pollutes later
-- suites (test_leveling_hunter etc.). Leveling strategies are tested via match
-- functions only; build_state for BM/MM/SV does not need the leveling module.

print("=== test_hunter_low_level_gating ===")

-- Load specs once
local bm = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
local mm = dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua")
local sv = dofile("EaxRotations/classes/hunter/survival_sylvanas.lua")

-- Leveling file requires shared/leveling_sylvanas (real module). Clear any stale
-- preload first so we never leave a mock in package.loaded for later suites.
package.preload["shared/leveling_sylvanas"] = nil
package.loaded["shared/leveling_sylvanas"] = nil
local leveling = dofile("EaxRotations/classes/hunter/leveling_sylvanas.lua")

local bm_strats = bm.strategies
local mm_strats = mm.strategies
local sv_strats = sv.strategies
local leveling_strats = type(leveling) == "table" and (leveling.strategies or leveling) or leveling

-- --------------------------------------------------------------------------
-- BM: pre_steady_leveling from build_state
-- --------------------------------------------------------------------------
test("BM build_state sets pre_steady_leveling at level 42", function()
    local state = bm.build_state({
        me = {}, target = { get_health_percentage = function() return 80 end },
        in_combat = true, player_level = 42, level = 42, mana_pct = 40,
        is_leveling = true, enemy_count = 1, settings = {},
    })
    assert_true(state.pre_steady_leveling == true, "level 42 must be pre_steady")
    assert_true((state.level or 0) == 42, "level should be 42")
end)

test("BM build_state clears pre_steady_leveling at level 70 with Steady ready", function()
    local state = bm.build_state({
        me = {}, target = { get_health_percentage = function() return 80 end },
        in_combat = true, player_level = 70, level = 70, mana_pct = 80,
        is_leveling = false, enemy_count = 1, settings = {},
    })
    -- steady_shot_ready comes from spell_ready mock (true), so pre_steady should be false
    assert_false(state.pre_steady_leveling, "level 70 with Steady ready is not pre_steady")
end)

-- --------------------------------------------------------------------------
-- BM: LevelingArcaneShot / ArcaneShot mana floor at low level
-- --------------------------------------------------------------------------
test("BM LevelingArcaneShot matches at level 42 with mid mana", function()
    local strat = find_strategy(bm_strats, "LevelingArcaneShot")
    assert_true(strat ~= nil, "LevelingArcaneShot strategy must exist on BM")
    local ok = strat.matches(
        { in_combat = true, settings = {} },
        {
            in_combat = true, pre_steady_leveling = true, arcane_shot_ready = true,
            is_mounted = false, in_dead_zone = false, shot_buffer = 150, mana_pct = 40,
        }
    )
    assert_true(ok, "LevelingArcaneShot must fire at mid mana pre-Steady (was silent before fix)")
end)

test("BM ArcaneShot uses relaxed mana floor when pre_steady_leveling", function()
    local strat = find_strategy(bm_strats, "ArcaneShot")
    assert_true(strat ~= nil, "ArcaneShot strategy must exist")
    -- 40% mana: endgame floor is 50% (would fail), pre-steady floor is 20% (must pass)
    local ok_pre = strat.matches(
        { in_combat = true, settings = {} },
        {
            in_combat = true, pre_steady_leveling = true, arcane_shot_ready = true,
            is_mounted = false, in_dead_zone = false, shot_buffer = 150, mana_pct = 40,
        }
    )
    assert_true(ok_pre, "ArcaneShot at 40% mana must pass when pre_steady")

    local ok_endgame = strat.matches(
        { in_combat = true, settings = {} },
        {
            in_combat = true, pre_steady_leveling = false, arcane_shot_ready = true,
            is_mounted = false, in_dead_zone = false, shot_buffer = 150, mana_pct = 40,
        }
    )
    assert_false(ok_endgame, "ArcaneShot at 40% mana must fail at endgame (50% floor)")
end)

test("BM LevelingSting matches when Serpent missing pre-Steady", function()
    local strat = find_strategy(bm_strats, "LevelingSting")
    assert_true(strat ~= nil, "LevelingSting strategy must exist on BM")
    local ok = strat.matches(
        { in_combat = true, target = {}, settings = {} },
        {
            in_combat = true, pre_steady_leveling = true, has_serpent_sting = false,
            serpent_sting_ready = true, mana_pct = 40, is_mounted = false,
        }
    )
    assert_true(ok, "LevelingSting must apply DoT pre-Steady")
end)

-- --------------------------------------------------------------------------
-- BM: Kill Command / Bestial Wrath correctly require pet (not silent whole rotation)
-- --------------------------------------------------------------------------
test("BM KillCommand does not match without pet (expected gate)", function()
    local strat = find_strategy(bm_strats, "KillCommand")
    assert_true(strat ~= nil, "KillCommand must exist")
    local ok = strat.matches(
        { in_combat = true, settings = {} },
        { in_combat = true, pet_alive = false, kill_command_ready = true, is_mounted = false }
    )
    assert_false(ok, "KillCommand must require live pet")
end)

-- --------------------------------------------------------------------------
-- MM / SV: pre_steady_leveling still works
-- --------------------------------------------------------------------------
test("MM build_state sets pre_steady_leveling at level 35", function()
    local state = mm.build_state({
        me = {}, target = {}, pet = nil,
        in_combat = true, player_level = 35, mana_pct = 50,
        is_leveling = true, enemy_count = 1, settings = {},
    })
    assert_true(state.pre_steady_leveling == true, "MM level 35 must be pre_steady")
end)

test("SV build_state sets pre_steady_leveling at level 35", function()
    local state = sv.build_state({
        me = {}, target = {}, pet = nil,
        in_combat = true, player_level = 35, mana_pct = 50,
        is_leveling = true, enemy_count = 1, settings = {},
    })
    assert_true(state.pre_steady_leveling == true, "SV level 35 must be pre_steady")
end)

test("MM LevelingArcaneShot matches pre-Steady", function()
    local strat = find_strategy(mm_strats, "LevelingArcaneShot")
    assert_true(strat ~= nil, "MM LevelingArcaneShot must exist")
    assert_true(strat.matches(
        { settings = {} },
        { pre_steady_leveling = true, arcane_shot_ready = true }
    ), "MM LevelingArcaneShot must match")
end)

test("SV LevelingArcaneShot matches pre-Steady", function()
    local strat = find_strategy(sv_strats, "LevelingArcaneShot")
    assert_true(strat ~= nil, "SV LevelingArcaneShot must exist")
    assert_true(strat.matches(
        { settings = {} },
        { pre_steady_leveling = true, arcane_shot_ready = true }
    ), "SV LevelingArcaneShot must match")
end)

-- --------------------------------------------------------------------------
-- MM: wing_clip_ready is populated (was always false — silent WingClip)
-- --------------------------------------------------------------------------
test("MM build_state populates wing_clip_ready", function()
    local state = mm.build_state({
        me = {}, target = {}, pet = nil,
        in_combat = true, player_level = 40, mana_pct = 80,
        enemy_count = 1, settings = {}, distance_sq = 16,
    })
    assert_true(state.wing_clip_ready == true, "wing_clip_ready must be set from spell_ready")
end)

-- --------------------------------------------------------------------------
-- Leveling: level_from_context used for low-mana threshold
-- --------------------------------------------------------------------------
test("leveling ArcaneShot fires when not low_mana (no Steady/KC dependency)", function()
    local arcane = find_strategy(leveling_strats, "ArcaneShot")
    assert_true(arcane ~= nil, "leveling ArcaneShot must exist")
    local ctx = { in_combat = true, target = {}, is_leveling = true, settings = {} }
    assert_true(arcane.matches(
        ctx,
        { target = {}, in_combat = true, low_mana = false, arcane_shot_ready = true }
    ), "leveling ArcaneShot fires when not low_mana")
    assert_false(arcane.matches(
        ctx,
        { target = {}, in_combat = true, low_mana = true, arcane_shot_ready = true }
    ), "leveling ArcaneShot conserves mana when low_mana")
end)

test("leveling SerpentSting does not require high-level abilities", function()
    local sting = find_strategy(leveling_strats, "SerpentSting")
    assert_true(sting ~= nil, "leveling SerpentSting must exist")
    assert_true(sting.matches(
        { in_combat = true, target = {}, is_leveling = true, settings = {} },
        {
            target = {}, in_combat = true, low_mana = false,
            serpent_sting_use = true, serpent_sting_ready = true,
        }
    ), "SerpentSting must work at low level without Steady/KC")
end)

test("leveling RaptorStrike works in melee without Steady Shot", function()
    local rs = find_strategy(leveling_strats, "RaptorStrike")
    assert_true(rs ~= nil, "leveling RaptorStrike must exist")
    assert_true(rs.matches(
        { in_combat = true, target = {}, is_leveling = true, settings = {} },
        {
            target = {}, in_combat = true, low_mana = false,
            in_melee = true, raptor_strike_ready = true,
        }
    ), "RaptorStrike is a valid low-level filler in melee")
end)

-- --------------------------------------------------------------------------
-- Scrub mocks so later suites in run_rotation_tests.lua are not polluted.
runner_lib.clear_loaded({
    "shared/hunter_core_sylvanas",
    "shared/shot_timer_sylvanas",
    "shared/targeting_sylvanas",
    "shared/pet_manager_sylvanas",
    "shared/potion_helper_sylvanas",
    "shared/hit_cap_tracker_sylvanas",
    "shared/cooldown_planner_sylvanas",
    "common/utility/inventory_helper",
    "shared/leveling_sylvanas",
    "shared/leveling_helpers_sylvanas",
    "shared/spec_kit_sylvanas",
})

print(string.format("\nResults: %d passed, %d failed, %d assertions", passed, failed, assertions))
if failed > 0 then
    os.exit(1)
end
print("PASS test_hunter_low_level_gating")
