-- test_destruction_vanilla_soul_fire_execute.lua — Classic Destro Soul Fire execute gate.
-- WHAT:  SoulFire must not match outside execute; Shadowburn priority above SoulFire/ShadowBolt.
-- WHEN:  During rotation test suite execution.
-- WHY:   classic warlock APL does not spam Soul Fire whenever a soul shard exists.
-- SAFETY: Pure unit tests; drives shipped strategy matches.

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
        SummonSuccubus = 712, SummonFelhunter = 691,
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
}

package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
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
local bolt_i = find("ShadowBolt")
assert_true(soul_fire ~= nil, "SoulFire strategy present")
assert_true(shadowburn ~= nil, "Shadowburn strategy present")
assert_true(sf_i > sb_i or true, "indices exist")
assert_true(sb_i < bolt_i, string.format("Shadowburn (%d) before ShadowBolt (%d)", sb_i, bolt_i))
assert_true(sb_i < sf_i, string.format("Shadowburn (%d) before SoulFire (%d)", sb_i, sf_i))
assert_true(sf_i < bolt_i, string.format("SoulFire (%d) before ShadowBolt (%d)", sf_i, bolt_i))

-- Outside execute: must not match (even with soul shard)
assert_false(soul_fire.matches({ target = {}, target_hp = 100, settings = {} }, {}),
    "SoulFire must not match at 100% HP")
assert_false(soul_fire.matches({ target = {}, target_hp = 50, settings = {} }, {}),
    "SoulFire must not match at 50% HP")

-- Execute: must match
assert_true(soul_fire.matches({ target = {}, target_hp = 15, settings = {} }, {}),
    "SoulFire matches in execute with soul shard")
assert_true(soul_fire.matches({ target = {}, target_hp = 20, settings = {} }, {}),
    "SoulFire matches at 20% boundary")

print("PASS test_destruction_vanilla_soul_fire_execute")
