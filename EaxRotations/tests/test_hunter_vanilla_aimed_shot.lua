-- test_hunter_vanilla_aimed_shot.lua — Classic BM/Survival Aimed Shot priority tests.
-- WHAT:  Assert AimedShot exists above Multi/Arcane and matches on real strategy tables.
-- WHEN:  During rotation test suite execution.
-- WHY:   wowsims classic hunter p1.apl uses Aimed as primary cast (no Steady Shot).
-- SAFETY: Pure unit tests with mocked API; drives shipped matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    HunterSpells = {
        AimedShot = 19434, ArcaneShot = 3044, AspectOfTheHawk = 13165,
        BestialWrath = 19574, CallPet = 883, ConcussiveShot = 5116,
        FeignDeath = 5384, FreezingTrap = 1499, HuntersMark = 1430,
        MendPet = 136, MultiShot = 2643, RapidFire = 3045,
        RaptorStrike = 2973, RevivePet = 982, SerpentSting = 1978,
        ViperSting = 3034, Volley = 1510, WingClip = 2974,
        ExplosiveTrap = 8294, ScorpidSting = 3043, Intimidation = 19577,
        PetAggressive = 1742, PetDefensive = 1742, PetPassive = 1742,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    spell_action = function(ids, name) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    is_spell_learned = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    unit_mana_pct = function() return 80 end,
    unit_alive = function() return false end,
    time_now = function() return 0 end,
    is_vanilla = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
    broken_api_throttled = function() return false end,
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/hunter_core_sylvanas"] = {
    get_pet = function() return nil end,
    pet_alive = function() return false end,
    pet_hp_pct = function() return 100 end,
    can_cast_steady = function() return true end,
    can_cast_instant = function() return true end,
    record_instant_shot = function() end,
    sting_remains = function() return 10 end,
    should_feign_death = function() return false end,
}
package.loaded["shared/targeting_sylvanas"] = {}
package.loaded["shared/pet_manager_sylvanas"] = {}

local function strategy_index(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return i, strategies[i] end
    end
    return nil, nil
end

local function load_strategies(path)
    local result = dofile(path)
    if type(result) == "table" and result.strategies then return result.strategies end
    return result
end

-- ============================================================================
-- Beast Mastery
-- ============================================================================
local bm = load_strategies("EaxRotations/classes/hunter/beast_mastery_vanilla.lua")
assert_true(type(bm) == "table" and #bm > 0, "BM strategies should load")

local bm_aimed_i, bm_aimed = strategy_index(bm, "AimedShot")
local bm_multi_i = strategy_index(bm, "MultiShot")
local bm_arcane_i = strategy_index(bm, "ArcaneShot")
assert_true(bm_aimed_i ~= nil, "BM AimedShot strategy present")
assert_true(bm_multi_i ~= nil, "BM MultiShot present")
assert_true(bm_arcane_i ~= nil, "BM ArcaneShot present")
assert_true(bm_aimed_i < bm_multi_i,
    string.format("BM AimedShot (%d) must be before MultiShot (%d)", bm_aimed_i, bm_multi_i))
assert_true(bm_aimed_i < bm_arcane_i,
    string.format("BM AimedShot (%d) must be before ArcaneShot (%d)", bm_aimed_i, bm_arcane_i))

local bm_state = {
    in_combat = true, aimed_shot_ready = true, mana_pct = 80, is_mounted = false,
}
assert_true(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot matches in combat with mana and ready")
bm_state.in_combat = false
assert_false(bm_aimed.matches({ in_combat = false, target = {}, me = {} }, bm_state),
    "BM AimedShot does not match OOC")
bm_state.in_combat = true
bm_state.mana_pct = 10
assert_false(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot does not match at low mana")

-- ============================================================================
-- Survival
-- ============================================================================
local sv = load_strategies("EaxRotations/classes/hunter/survival_vanilla.lua")
assert_true(type(sv) == "table" and #sv > 0, "Survival strategies should load")

local sv_aimed_i, sv_aimed = strategy_index(sv, "AimedShot")
local sv_multi_i = strategy_index(sv, "MultiShot")
local sv_arcane_i = strategy_index(sv, "ArcaneShot")
assert_true(sv_aimed_i ~= nil, "Survival AimedShot strategy present")
assert_true(sv_multi_i ~= nil, "Survival MultiShot present")
assert_true(sv_arcane_i ~= nil, "Survival ArcaneShot present")
assert_true(sv_aimed_i < sv_multi_i,
    string.format("Survival AimedShot (%d) must be before MultiShot (%d)", sv_aimed_i, sv_multi_i))
assert_true(sv_aimed_i < sv_arcane_i,
    string.format("Survival AimedShot (%d) must be before ArcaneShot (%d)", sv_aimed_i, sv_arcane_i))

local sv_state = { in_combat = true, aimed_shot_ready = true, mana_pct = 80 }
assert_true(sv_aimed.matches({ in_combat = true, target = {} }, sv_state),
    "Survival AimedShot matches in combat")
sv_state.in_combat = false
assert_false(sv_aimed.matches({ in_combat = false, target = {} }, sv_state),
    "Survival AimedShot does not match OOC")

print("PASS test_hunter_vanilla_aimed_shot")
