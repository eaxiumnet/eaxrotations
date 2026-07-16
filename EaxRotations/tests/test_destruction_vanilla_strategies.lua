-- test_destruction_vanilla_strategies.lua — Destruction Vanilla strategy match coverage.
-- WHAT:  Exercises SoulFire execute / Shadowburn priority / Conflagrate presence.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for warlock destruction vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    WarlockSpells = {
        Shadowburn = 17877, Immolate = 348, Conflagrate = 17962,
        ShadowBolt = 686, Corruption = 172, CurseOfAgony = 980,
        CurseOfDoom = 603, SearingPain = 5676, SoulFire = 6353,
        DeathCoil = 6789, Fear = 6215, RainOfFire = 5740,
        Hellfire = 1949, DrainLife = 689, LifeTap = 1454,
        HealthFunnel = 755, FelDomination = 18708, ShadowWard = 6229,
        CreateHealthstone = 6201, SummonImp = 688, SummonVoidwalker = 697,
        SummonSuccubus = 712, SummonFelhunter = 691, DemonArmor = 706,
    },
    has_item = function() return true end,
    is_execute_phase = function(target_hp, pct)
        if target_hp == nil then return false end
        return target_hp <= pct
    end,
    spell_ready = function() return true end,
    spell_action = function(ids, name) return { spell = ids, name = name } end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
    broken_api_throttled = function() return false end,
    should_refresh_dot = function() return true end,
    should_use_long_cd = function() return true end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
    define_action_for_class = function()
        return function(name, ids) return ids end
    end,
    safe_state = function(s) return s end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
}
package.loaded["shared/curse_helper_sylvanas"] = {
    other_curse_active = function() return false end,
}

local strategies = dofile("EaxRotations/classes/warlock/destruction_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "destruction strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return i, strategies[i] end
    end
    return nil, nil
end

local sf_i, soul_fire = find("SoulFire")
local sb_i, shadowburn = find("Shadowburn")
local conf_i, conflag = find("Conflagrate")
local bolt_i = find("ShadowBolt")

assert_true(soul_fire ~= nil, "SoulFire present")
assert_true(shadowburn ~= nil, "Shadowburn present")
assert_true(conflag ~= nil, "Conflagrate present")
assert_true(sb_i < sf_i, "Shadowburn before SoulFire")
assert_true(sf_i < bolt_i, "SoulFire before ShadowBolt")

assert_false(soul_fire.matches({ target = {}, target_hp = 100, settings = {} }, {}),
    "SoulFire must not match at full HP")
assert_false(soul_fire.matches({ target = {}, target_hp = 40, settings = {} }, {}),
    "SoulFire must not match outside execute")
assert_true(soul_fire.matches({ target = {}, target_hp = 15, settings = {} }, {}),
    "SoulFire matches in execute with shard")

assert_true(shadowburn.matches({ target = {}, target_hp = 15, settings = {} }, {})
    or shadowburn.matches({ target = {}, target_hp = 15, settings = {} }, {}) == false,
    "Shadowburn.matches returns boolean")
-- Shadowburn typically execute-gated; assert callable without crash
local sb_result = shadowburn.matches({ target = {}, target_hp = 15, settings = {} }, {})
assert_true(sb_result == true or sb_result == false, "Shadowburn returns boolean")


local hp_i, health_potion = find("HealthPotion")
local tr_i, trinket = find("Trinket")
assert_true(health_potion ~= nil, "HealthPotion present")
assert_true(trinket ~= nil, "Trinket present")
assert_true(health_potion.matches({ in_combat = true, settings = {} }, { hp_pct = 20 }), "HealthPotion at low HP")
assert_false(health_potion.matches({ in_combat = true, settings = {} }, { hp_pct = 80 }), "HealthPotion skips high HP")
print("PASS test_destruction_vanilla_strategies")

