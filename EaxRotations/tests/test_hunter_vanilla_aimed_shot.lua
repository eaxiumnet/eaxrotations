-- test_hunter_vanilla_aimed_shot.lua — Classic BM/Survival Aimed Shot priority + weave tests.
-- WHAT:  Assert AimedShot above Multi/Arcane; BM weave uses AIMED cast window not Steady.
-- WHEN:  During rotation test suite execution.
-- WHY:   wowsims classic hunter p1.apl uses Aimed as primary cast (no Steady Shot).
-- SAFETY: Pure unit tests with mocked API; drives shipped matches/execute.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local ms_until_auto_val = 0
local manual_shot_calls = 0
local steady_calls = 0
local instant_record_calls = 0

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
    -- MM/Survival weave path: remain > cast_ms + buffer (Aimed = 3000ms + 100ms)
    HunterClipTracker = {
        ms_until_auto = function() return ms_until_auto_val end,
        record_manual_shot = function()
            manual_shot_calls = manual_shot_calls + 1
        end,
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
-- Poison trap: if BM Aimed still calls can_cast_steady, count it; weave test must not rely on it.
package.loaded["shared/hunter_core_sylvanas"] = {
    get_pet = function() return nil end,
    pet_alive = function() return false end,
    pet_hp_pct = function() return 100 end,
    can_cast_steady = function()
        steady_calls = steady_calls + 1
        -- Mimic TBC Steady high-haste case3: allow whenever remain > 500
        return ms_until_auto_val == 0 or ms_until_auto_val > 500
    end,
    can_cast_instant = function() return true end,
    record_instant_shot = function()
        instant_record_calls = instant_record_calls + 1
    end,
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
ms_until_auto_val = 0
assert_true(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot matches in combat with mana and ready")
bm_state.in_combat = false
assert_false(bm_aimed.matches({ in_combat = false, target = {}, me = {} }, bm_state),
    "BM AimedShot does not match OOC")
bm_state.in_combat = true
bm_state.mana_pct = 10
assert_false(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot does not match at low mana")
bm_state.mana_pct = 80

-- ============================================================================
-- BM weave: Aimed needs remain > 3000 + 100, NOT Steady-length (can_cast_steady remain>500)
-- ============================================================================
steady_calls = 0
-- 1500ms left: enough for Steady high-haste (remain>500) but NOT for 3.0s Aimed cast
ms_until_auto_val = 1500
assert_false(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot must NOT match when only 1500ms until auto (needs AIMED_SHOT_CAST_MS gap)")
assert_eq(steady_calls, 0,
    "BM AimedShot must not call hunter_core.can_cast_steady (Steady-length/haste path)")

-- 2500ms: still below 3000+100 Aimed window
ms_until_auto_val = 2500
assert_false(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot must NOT match at 2500ms until auto")

-- 3200ms: above AIMED_SHOT_CAST_MS (3000) + AUTO_SHOT_BUFFER_MS (100)
ms_until_auto_val = 3200
assert_true(bm_aimed.matches({ in_combat = true, target = {}, me = {} }, bm_state),
    "BM AimedShot matches when remain > AIMED cast + buffer (3200ms)")

-- Execute must record manual shot (casted Aimed), not instant-shot tracker
manual_shot_calls = 0
instant_record_calls = 0
ms_until_auto_val = 0
assert_true(bm_aimed.execute({ target = {}, me = {} }), "BM AimedShot execute returns true")
assert_eq(manual_shot_calls, 1, "BM AimedShot execute must call HunterClipTracker.record_manual_shot")
assert_eq(instant_record_calls, 0, "BM AimedShot execute must NOT call record_instant_shot")

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
ms_until_auto_val = 0
assert_true(sv_aimed.matches({ in_combat = true, target = {} }, sv_state),
    "Survival AimedShot matches in combat")
sv_state.in_combat = false
assert_false(sv_aimed.matches({ in_combat = false, target = {} }, sv_state),
    "Survival AimedShot does not match OOC")
sv_state.in_combat = true
ms_until_auto_val = 1500
assert_false(sv_aimed.matches({ in_combat = true, target = {} }, sv_state),
    "Survival AimedShot must NOT match at 1500ms until auto")
ms_until_auto_val = 3200
assert_true(sv_aimed.matches({ in_combat = true, target = {} }, sv_state),
    "Survival AimedShot matches at 3200ms until auto")

print("PASS test_hunter_vanilla_aimed_shot")
