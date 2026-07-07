-- Test: Melee weave wiring in all 3 Hunter specs.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

_G.EaxRotations = {
    HunterSpells = {
        AspectOfTheHawk = 13165, AspectOfTheViper = 34074, ArcaneShot = 3044,
        SerpentSting = 1978, MendPet = 136, CallPet = 883, KillCommand = 34026,
        SteadyShot = 5662, MultiShot = 2643, BestialWrath = 19574,
        RapidFire = 3045, FeignDeath = 5384, Readiness = 23989,
        HuntersMark = 1130, FreezingTrap = 1499, ExplosiveTrap = 13813,
        AimedShot = 19434, SilencingShot = 34490, TrueshotAura = 19506,
        ConcussiveShot = 5116, ViperSting = 3034, WyvernSting = 19386,
        ScorpidSting = 3043, Volley = 1510, MongooseBite = 1495,
        WingClip = 2974, RaptorStrike = 2973, ImmolationTrap = 13795,
        SnakeTrap = 34600, Misdirection = 34477,
    },
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    is_spell_learned = function() return true end,
    debuff_up = function() return false end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    cooldown_remains = function() return 0 end,
    log = function() end,
    time_now = function() return 100 end,
    rotation_registry = { register = function() end },
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    HunterCore = {
        should_hawk = function() return true end,
        should_viper = function() return false end,
        get_pet = function() return nil end,
        pet_alive = function() return false end,
        pet_hp_pct = function() return 100 end,
        can_cast_steady = function() return true end,
        can_cast_instant = function() return true end,
        ms_until_auto = function() return 3000 end,
        get_steady_cast_ms = function() return 1500 end,
        record_mend = function() end,
    },
    HunterClipTracker = {
        can_cast_steady = function() return true end,
        ms_until_auto = function() return 3000 end,
    },
}

package.loaded["shared/hunter_core_sylvanas"] = _G.EaxRotations.HunterCore
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() end, set_passive = function() end, set_aggressive = function() end,
}
package.loaded["shared/potion_helper_sylvanas"] = {}
package.loaded["shared/shot_timer_sylvanas"] = {
    should_delay_cast = function() return false end,
    can_cast_steady = function() return true end,
    can_cast_instant = function() return true end,
}
package.loaded["shared/targeting_sylvanas"] = {}

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

-- BM
local bm_strategies = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua").strategies
local bm_raptor = find_strategy(bm_strategies, "RaptorStrike")
assert_true(bm_raptor ~= nil, "BM RaptorStrike should exist")
-- Melee weave enabled, in range -> match
assert_true(bm_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 16, raptor_strike_ready = true, is_mounted = false }), "BM raptor in range -> match")
-- Melee weave disabled -> no match
assert_false(bm_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = false, distance_sq = 16, raptor_strike_ready = true, is_mounted = false }), "BM raptor disabled -> no match")
-- Out of range -> no match
assert_false(bm_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 100, raptor_strike_ready = true, is_mounted = false }), "BM raptor out of range -> no match")

-- MM
local mm_strategies = dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua").strategies
local mm_raptor = find_strategy(mm_strategies, "RaptorStrike")
assert_true(mm_raptor ~= nil, "MM RaptorStrike should exist")
assert_true(mm_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 16, raptor_strike_ready = true }), "MM raptor in range -> match")
assert_false(mm_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = false, distance_sq = 16, raptor_strike_ready = true }), "MM raptor disabled -> no match")

local mm_wing = find_strategy(mm_strategies, "WingClip")
assert_true(mm_wing ~= nil, "MM WingClip should exist")
assert_true(mm_wing.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 16, wing_clip_ready = true, wing_clip_active = false }), "MM wing clip -> match")
assert_false(mm_wing.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 16, wing_clip_ready = true, wing_clip_active = true }), "MM wing clip already active -> no match")

-- SV
local sv_strategies = dofile("EaxRotations/classes/hunter/survival_sylvanas.lua").strategies
local sv_raptor = find_strategy(sv_strategies, "RaptorStrike")
assert_true(sv_raptor ~= nil, "SV RaptorStrike should exist")
assert_true(sv_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 16, raptor_strike_ready = true }), "SV raptor in range -> match")
assert_false(sv_raptor.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = false, distance_sq = 16, raptor_strike_ready = true }), "SV raptor disabled -> no match")

local sv_wing = find_strategy(sv_strategies, "WingClip")
assert_true(sv_wing ~= nil, "SV WingClip should exist")
assert_true(sv_wing.matches({ in_combat = true, target = {} },
    { in_combat = true, hunter_melee_weave = true, distance_sq = 16, wing_clip_ready = true, wing_clip_active = false }), "SV wing clip -> match")

print("PASS test_hunter_melee_weave")
