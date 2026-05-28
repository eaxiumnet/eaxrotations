-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_hunter_aspect_matches.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
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
    return nil  -- strategy may not exist in all specs (e.g. BM has no LevelingArcaneShot)
end

-- BM's match functions check should_hawk/should_viper and spell_ready, and return true directly
local function check_bm(path)
    local strategies = dofile(path)
    local hawk = find_strategy(strategies, "AspectOfTheHawk")
    local viper = find_strategy(strategies, "AspectOfTheViper")
    local mend_pet = find_strategy(strategies, "MendPet")
    local call_pet = find_strategy(strategies, "CallPet")

    action_calls = 0
    -- BM uses has_hawk (not has_aspect_hawk), checks aspect_mode, should_hawk(>50), and spell_ready
    assert_true(hawk.matches({ settings = {} }, { has_hawk = false, call_pet_ready = false, aspect_mode = "auto", mana_pct = 60, is_mounted = false }), path .. " hawk should not require Call Pet")

    action_calls = 0
    assert_true(viper.matches({ settings = {} }, { has_viper = false, mana_pct = 20, call_pet_ready = false, aspect_mode = "auto", is_mounted = false }), path .. " viper should not require Call Pet")

    action_calls = 0
    assert_true(not mend_pet.matches({ settings = {} }, { pet_alive = false, pet_hp_pct = 20, mend_pet_ready = true }), path .. " Mend Pet should require live pet")
    assert_true(action_calls == 0, path .. " dead/missing pet should fail before action gate")

    action_calls = 0
    assert_true(call_pet.matches({ settings = {} }, { has_pet = false, has_pet_spell = true, in_combat = false, call_pet_ready = true, is_mounted = false }), path .. " Call Pet should match when pet missing OOC")
end

-- MM/Survival match functions check has_aspect_hawk and delegate to action_matches
local function check(path)
    local strategies = dofile(path)
    local hawk = find_strategy(strategies, "AspectOfTheHawk")
    local viper = find_strategy(strategies, "AspectOfTheViper")
    local leveling_arcane = find_strategy(strategies, "LevelingArcaneShot")
    local leveling_sting = find_strategy(strategies, "LevelingSting")
    local mend_pet = find_strategy(strategies, "MendPet")
    local call_pet = find_strategy(strategies, "CallPet")

    action_calls = 0
    assert_true(hawk.matches({ settings = {} }, { has_aspect_hawk = false, call_pet_ready = false, aspect_mode = "auto", mana_pct = 30 }), path .. " hawk should not require Call Pet")

    action_calls = 0
    assert_true(viper.matches({ settings = {} }, { has_aspect_viper = false, mana_pct = 20, call_pet_ready = false, aspect_mode = "auto" }), path .. " viper should not require Call Pet")

    action_calls = 0
    if leveling_arcane then
        assert_true(leveling_arcane.matches({ settings = {} }, { pre_steady_leveling = true, arcane_shot_ready = true }), path .. " pre-Steady Arcane Shot should match")
    end

    action_calls = 0
    if leveling_sting then
        assert_true(leveling_sting.matches({ settings = {} }, { pre_steady_leveling = true, has_serpent_sting = false, serpent_sting_ready = true, mana_pct = 40 }), path .. " pre-Steady sting should match")
    end

    action_calls = 0
    assert_true(not mend_pet.matches({ settings = {} }, { pet_alive = false, pet_hp_pct = 20, mend_pet_ready = true }), path .. " Mend Pet should require live pet")
    assert_true(action_calls == 0, path .. " dead/missing pet should fail before action gate")

    action_calls = 0
    assert_true(call_pet.matches({ settings = {} }, { has_pet = false, in_combat = false, call_pet_ready = true }), path .. " Call Pet should match when pet missing OOC")
end

check_bm("EaxRotations/classes/hunter/beast_mastery_sylvanas.lua")
check("EaxRotations/classes/hunter/marksmanship_sylvanas.lua")
check("EaxRotations/classes/hunter/survival_sylvanas.lua")

print("PASS test_hunter_aspect_matches")
