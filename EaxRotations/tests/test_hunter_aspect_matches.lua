-- test_hunter_aspect_matches.lua -- Hunter aspect manager match validation tests.
-- WHAT:  Hunter aspect manager match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Regression: hunter aspect upkeep must not depend on Call Pet readiness.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;api/?/?/?.lua;" .. package.path

_G.core = { object_manager = { get_local_player = function() return {} end } }

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end

local action_calls = 0
_G.EaxRotations = {
    HunterSpells = {
        AspectOfTheHawk = 13165,
        AspectOfTheViper = 34074,
        ArcaneShot = 3044,
        SerpentSting = 1978,
        MendPet = 136,
        CallPet = 883,
        KillCommand = 34026,
    },
    action_matches = function()
        action_calls = action_calls + 1
        return true
    end,
    action_execute = function() return true end,
    spell_ready = function() return true end,
    debuff_up = function() return false end,
    buff_up = function() return false end,
    log = function() end,
    time_now = function() return 100 end,
    rotation_registry = { register = function() end },
    HunterCore = {
        should_hawk = function(mana_pct) return mana_pct > 50 end,
        should_viper = function(mana_pct) return mana_pct < 30 end,
    },
}

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

-- BM uses AutoAspect (not separate Hawk/Viper strategies). Also has LevelingArcaneShot
-- for pre-Steady Shot (lvl < 62) so the rotation does not go silent at mid mana.
local function check_bm(path)
    local strategies = dofile(path).strategies
    local hawk = find_strategy(strategies, "AspectOfTheHawk")
    local viper = find_strategy(strategies, "AspectOfTheViper")
    local auto_aspect = find_strategy(strategies, "AutoAspect")
    local mend_pet = find_strategy(strategies, "MendPet")
    local call_pet = find_strategy(strategies, "CallPet")
    local leveling_arcane = find_strategy(strategies, "LevelingArcaneShot")

    -- Named Hawk/Viper strategies are not on BM (AutoAspect covers in-combat swap)
    assert_true(hawk == nil, path .. " AspectOfTheHawk should not be a named BM strategy")
    assert_true(viper == nil, path .. " AspectOfTheViper should not be a named BM strategy")
    assert_true(auto_aspect ~= nil, path .. " AutoAspect should exist on BM")

    action_calls = 0
    assert_true(mend_pet ~= nil, path .. " MendPet should exist")
    assert_true(not mend_pet.matches({ settings = {} }, { pet_alive = false, pet_hp_pct = 20, mend_pet_ready = true }), path .. " Mend Pet should require live pet")
    assert_true(action_calls == 0, path .. " dead/missing pet should fail before action gate")

    action_calls = 0
    assert_true(call_pet ~= nil, path .. " CallPet should exist")
    assert_true(call_pet.matches({ settings = {} }, { has_pet = false, has_pet_spell = true, in_combat = false, call_pet_ready = true, is_mounted = false }), path .. " Call Pet should match when pet missing OOC")

    assert_true(leveling_arcane ~= nil, path .. " LevelingArcaneShot must exist (pre-Steady silent-gate fix)")
    assert_true(leveling_arcane.matches(
        { settings = {}, in_combat = true },
        { pre_steady_leveling = true, arcane_shot_ready = true, in_combat = true, is_mounted = false, in_dead_zone = false, shot_buffer = 150 }
    ), path .. " LevelingArcaneShot must match pre-Steady")
end

-- MM/Survival match functions check has_aspect_hawk and delegate to action_matches
-- Accept a path (string) or a function that returns the strategies table
-- (spec_kit-converted specs have canonical {strategies, build_state} return).
local function check(path_or_fn)
    local strategies = type(path_or_fn) == "function" and path_or_fn() or dofile(path_or_fn)
    local hawk = find_strategy(strategies, "AspectOfTheHawk")
    local viper = find_strategy(strategies, "AspectOfTheViper")
    local leveling_arcane = find_strategy(strategies, "LevelingArcaneShot")
    local leveling_sting = find_strategy(strategies, "LevelingSting")
    local mend_pet = find_strategy(strategies, "MendPet")
    local call_pet = find_strategy(strategies, "CallPet")

    action_calls = 0
    assert_true(hawk.matches({ settings = {} }, { has_aspect_hawk = false, call_pet_ready = false, aspect_mode = "auto", mana_pct = 30 }), tostring(path_or_fn) .. " hawk should not require Call Pet")

    action_calls = 0
    assert_true(viper.matches({ settings = {} }, { has_aspect_viper = false, mana_pct = 3, call_pet_ready = false, aspect_mode = "auto" }), tostring(path_or_fn) .. " viper should not require Call Pet")

    action_calls = 0
    if leveling_arcane then
        assert_true(leveling_arcane.matches({ settings = {} }, { pre_steady_leveling = true, arcane_shot_ready = true }), tostring(path_or_fn) .. " pre-Steady Arcane Shot should match")
    end

    action_calls = 0
    if leveling_sting then
        assert_true(leveling_sting.matches({ settings = {} }, { pre_steady_leveling = true, has_serpent_sting = false, serpent_sting_ready = true, mana_pct = 40 }), tostring(path_or_fn) .. " pre-Steady sting should match")
    end

    action_calls = 0
    assert_true(not mend_pet.matches({ settings = {} }, { pet_alive = false, pet_hp_pct = 20, mend_pet_ready = true }), tostring(path_or_fn) .. " Mend Pet should require live pet")
    assert_true(action_calls == 0, tostring(path_or_fn) .. " dead/missing pet should fail before action gate")

    action_calls = 0
    assert_true(call_pet.matches({ settings = {} }, { has_pet = false, in_combat = false, call_pet_ready = true }), tostring(path_or_fn) .. " Call Pet should match when pet missing OOC")
end

check_bm("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
check(function() return dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua").strategies end)
check(function() return dofile("EaxRotations/classes/hunter/survival_sylvanas.lua").strategies end)

print("PASS test_hunter_aspect_matches")
