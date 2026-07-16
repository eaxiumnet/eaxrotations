-- test_beast_mastery_vanilla_strategies.lua — BM Vanilla strategy match coverage.
-- WHAT:  Exercises AimedShot / ArcaneShot priority and mana gates on beast_mastery_vanilla.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for hunter BM vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local ms_until_auto_val = 0

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
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
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
    HunterClipTracker = {
        ms_until_auto = function() return ms_until_auto_val end,
        record_manual_shot = function() end,
    },
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
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}

local result = dofile("EaxRotations/classes/hunter/beast_mastery_vanilla.lua")
local strategies = (type(result) == "table" and result.strategies) or result
assert_true(type(strategies) == "table" and #strategies > 0, "BM strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local aimed = find("AimedShot")
local arcane = find("ArcaneShot")
local multi = find("MultiShot")

local aimed_i, multi_i, arcane_i
for i = 1, #strategies do
    if strategies[i].name == "AimedShot" then aimed_i = i end
    if strategies[i].name == "MultiShot" then multi_i = i end
    if strategies[i].name == "ArcaneShot" then arcane_i = i end
end
assert_true(aimed_i < multi_i, "AimedShot before MultiShot")
assert_true(aimed_i < arcane_i, "AimedShot before ArcaneShot")

ms_until_auto_val = 0
local state = { in_combat = true, aimed_shot_ready = true, arcane_shot_ready = true, mana_pct = 80, is_mounted = false }
assert_true(aimed.matches({ in_combat = true, target = {}, me = {} }, state),
    "AimedShot matches in combat with mana")
assert_false(aimed.matches({ in_combat = true, target = {}, me = {} }, { in_combat = true, aimed_shot_ready = true, mana_pct = 10, is_mounted = false }),
    "AimedShot must not match at low mana")
assert_false(arcane.matches({ in_combat = true, target = {}, me = {} }, state),
    "ArcaneShot yields when AimedShot ready")

state.aimed_shot_ready = false
assert_true(arcane.matches({ in_combat = true, target = {}, me = {} }, state),
    "ArcaneShot matches when Aimed not ready")

print("PASS test_beast_mastery_vanilla_strategies")
