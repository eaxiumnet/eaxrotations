-- test_marksmanship_vanilla_strategies.lua — MM Vanilla strategy match coverage.
-- WHAT:  Exercises InCombatAimedShot / AimedShotPrepull / MultiShot gates.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for hunter marksmanship vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local ms_until_auto_val = 0

_G.EaxRotations = {
    HunterSpells = {
        AimedShot = 19434, ArcaneShot = 3044, AspectOfTheHawk = 13165,
        CallPet = 883, FeignDeath = 5384, FreezingTrap = 1499, HuntersMark = 1430,
        MendPet = 136, MultiShot = 2643, RapidFire = 3045, RevivePet = 982,
        SerpentSting = 1978, ViperSting = 3034, BestialWrath = 19574,
        PetAggressive = 1742, PetDefensive = 1742, PetPassive = 1742,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
    should_use_long_cd = function() return true end,
    HunterClipTracker = {
        ms_until_auto = function() return ms_until_auto_val end,
        record_manual_shot = function() end,
    },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {},
}
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}

local strategies = dofile("EaxRotations/classes/hunter/marksmanship_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "MM strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local combat_aimed = find("InCombatAimedShot")
local prepull = find("AimedShotPrepull")
local multi = find("MultiShot")
local rapid = find("RapidFire")

ms_until_auto_val = 0
assert_false(combat_aimed.matches({}, { in_combat = false, aimed_shot_ready = true, mana_pct = 80 }),
    "InCombatAimedShot must not match OOC")
assert_false(combat_aimed.matches({}, { in_combat = true, aimed_shot_ready = true, mana_pct = 10 }),
    "InCombatAimedShot must not match at low mana")
assert_true(combat_aimed.matches({}, { in_combat = true, aimed_shot_ready = true, mana_pct = 80 }),
    "InCombatAimedShot matches in combat with mana")

assert_false(prepull.matches({}, { is_ooc = false, aimed_shot_prepull_ready = true }),
    "AimedShotPrepull must not match in combat")
assert_true(prepull.matches({}, { is_ooc = true, aimed_shot_prepull_ready = true }),
    "AimedShotPrepull matches OOC when ready")

assert_false(multi.matches({ has_breakable_cc_nearby = true }, { in_combat = true, enemy_count = 2, multi_shot_ready = true, mana_pct = 80 }),
    "MultiShot must not match near breakable CC")
assert_false(multi.matches({}, { in_combat = false, enemy_count = 2, multi_shot_ready = true, mana_pct = 80 }),
    "MultiShot must not match OOC (BM-parity gate)")
assert_false(multi.matches({}, { in_combat = true, enemy_count = 1, multi_shot_ready = true, mana_pct = 80 }),
    "MultiShot must not match on a single enemy (BM-parity gate)")
assert_true(multi.matches({}, { in_combat = true, enemy_count = 2, multi_shot_ready = true, mana_pct = 80 }),
    "MultiShot matches in combat with 2+ enemies and mana")

ms_until_auto_val = 50
assert_true(rapid.matches({ settings = {} }, {
    in_combat = true, rapid_fire_ready = true, aimed_shot_ready = true,
}), "RapidFire aligns inside the wowsims 100ms auto-shot window")
ms_until_auto_val = 100
assert_false(rapid.matches({ settings = {} }, {
    in_combat = true, rapid_fire_ready = true, aimed_shot_ready = true,
}), "RapidFire defers outside the wowsims auto-shot window")
ms_until_auto_val = 50
assert_false(rapid.matches({ settings = {} }, {
    in_combat = true, rapid_fire_ready = true, aimed_shot_ready = false,
}), "RapidFire defers when the required Aimed Shot rank is unavailable")

print("PASS test_marksmanship_vanilla_strategies")
