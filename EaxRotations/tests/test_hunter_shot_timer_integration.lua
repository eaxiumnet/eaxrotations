-- Test: Shot timer wiring in all 3 Hunter specs.

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
package.loaded["shared/targeting_sylvanas"] = {}

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

-- Helper to load specs with a given shot_timer mock
local function load_specs_with_mock(should_delay)
    local mock = {
        should_delay_cast = function(ctx, buffer)
            return should_delay
        end,
        can_cast_steady = function() return true end,
        can_cast_instant = function() return true end,
    }
    package.loaded["shared/shot_timer_sylvanas"] = mock
    -- Clear any cached spec modules
    for k in pairs(package.loaded) do
        if k:find("beast_mastery_sylvanas") or k:find("marksmanship_sylvanas") or k:find("survival_sylvanas") then
            package.loaded[k] = nil
        end
    end
    local bm = dofile("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
    local mm = dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua").strategies
    local sv = dofile("EaxRotations/classes/hunter/survival_sylvanas.lua").strategies
    return bm, mm, sv
end

-- Test with should_delay = false (safe to cast)
local bm_s, mm_s, sv_s = load_specs_with_mock(false)
local bm_steady = find_strategy(bm_s, "SteadyShot")
local mm_steady = find_strategy(mm_s, "SteadyShot")
local sv_steady = find_strategy(sv_s, "SteadyShot")

assert_true(bm_steady ~= nil, "BM SteadyShot should exist")
assert_true(bm_steady.matches({ in_combat = true, is_moving = false, target = {} },
    { in_combat = true, steady_shot_ready = true, hunter_shot_timer_buffer = 150, in_dead_zone = false }), "BM steady should match when safe")

assert_true(mm_steady ~= nil, "MM SteadyShot should exist")
assert_true(mm_steady.matches({ target = {} },
    { steady_shot_ready = true, hunter_shot_timer_buffer = 150 }), "MM steady should match when safe")

assert_true(sv_steady ~= nil, "SV SteadyShot should exist")
assert_true(sv_steady.matches({ target = {} },
    { steady_shot_ready = true, hunter_shot_timer_buffer = 150 }), "SV steady should match when safe")

-- Test with should_delay = true (unsafe to cast)
local bm_d, mm_d, sv_d = load_specs_with_mock(true)
local bm_steady_d = find_strategy(bm_d, "SteadyShot")
local mm_steady_d = find_strategy(mm_d, "SteadyShot")
local sv_steady_d = find_strategy(sv_d, "SteadyShot")

assert_false(bm_steady_d.matches({ in_combat = true, is_moving = false, target = {} },
    { in_combat = true, steady_shot_ready = true, hunter_shot_timer_buffer = 150, in_dead_zone = false }), "BM steady should NOT match when delay")

assert_false(mm_steady_d.matches({ target = {} },
    { steady_shot_ready = true, hunter_shot_timer_buffer = 150 }), "MM steady should NOT match when delay")

assert_false(sv_steady_d.matches({ target = {} },
    { steady_shot_ready = true, hunter_shot_timer_buffer = 150 }), "SV steady should NOT match when delay")

print("PASS test_hunter_shot_timer_integration")
