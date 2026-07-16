-- test_affliction_vanilla_strategies.lua — Affliction Vanilla strategy match coverage.
-- WHAT:  Exercises DrainSoulExecute / ShadowBoltFiller / PreCombatPull gates.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for warlock affliction vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    WarlockSpells = {
        ShadowBolt = 686, Corruption = 172, CurseOfAgony = 980, CurseOfDoom = 603,
        SiphonLife = 18265, Immolate = 348, DrainSoul = 1120, DrainLife = 689,
        LifeTap = 1454, DeathCoil = 6789, Fear = 6215, AmplifyCurse = 18288,
        DarkPact = 18220, DemonArmor = 706, ShadowWard = 6229, HealthFunnel = 755,
        CreateHealthstone = 6201, CreateSoulstone = 693, Shoot = 5019,
        CurseOfElements = 1490, CurseOfExhaustion = 18223, CurseOfTongues = 1714,
        HowlOfTerror = 5484, SummonImp = 688, SummonVoidwalker = 697,
        SummonSuccubus = 712, SummonFelhunter = 691,
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
    has_item = function() return false end,
    is_item_ready = function() return false end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
    broken_api_throttled = function() return false end,
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, MANA_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/pet_manager_sylvanas"] = {
    set_defensive = function() return true end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
}
package.loaded["shared/tbc_data_sylvanas"] = {
    ITEMS = { potions = {}, healthstones = {} },
}

local result = dofile("EaxRotations/classes/warlock/affliction_vanilla.lua")
local strategies = (type(result) == "table" and result.strategies) or result
assert_true(type(strategies) == "table" and #strategies > 0, "affliction strategies load")
assert_true(type(result.build_state) == "function", "affliction exports build_state")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local drain = find("DrainSoulExecute")
local bolt = find("ShadowBoltFiller")
local prepull = find("PreCombatPull")

assert_false(drain.matches({ has_valid_enemy_target = true, target = {} }, { target_hp = 50 }),
    "DrainSoul must not match above 25% HP")
assert_false(drain.matches({ has_valid_enemy_target = false, target = {} }, { target_hp = 10 }),
    "DrainSoul must not match without valid target")
assert_true(drain.matches({ has_valid_enemy_target = true, target = {}, is_channeling = false }, { target_hp = 20 }),
    "DrainSoul matches in execute")

assert_false(bolt.matches({ has_valid_enemy_target = false, target = {} }),
    "ShadowBoltFiller must not match without target")
assert_true(bolt.matches({ has_valid_enemy_target = true, target = {} }),
    "ShadowBoltFiller matches with valid target")

assert_false(prepull.matches({ in_combat = true, has_valid_enemy_target = true, target = {} }),
    "PreCombatPull must not match in combat")
assert_true(prepull.matches({ in_combat = false, has_valid_enemy_target = true, target = {} }),
    "PreCombatPull matches OOC with target")

print("PASS test_affliction_vanilla_strategies")
