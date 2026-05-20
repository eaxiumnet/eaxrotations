-- behavior tests for healer solo damage fallback gates.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function reset_package(name)
    package.loaded[name] = nil
end

_G.core = { object_manager = { get_local_player = function() return {} end }, time = function() return 0 end, game_time = function() return 0 end }

-- Druid Resto solo fallback.
reset_package("classes/druid/resto_sylvanas")
_G.EaxRotations = {
    DruidSpells = { Moonfire = 8921, InsectSwarm = 5570, Wrath = 5176 },
    PLAYER_UNIT = {},
    DruidHealing = {
        scan_healing_targets = function() return {}, 0 end,
    },
    spell_action = function(ids, label) return { ids = ids, label = label } end,
    spell_ready = function() return true end,
    debuff_remains = function() return 0 end,
    buff_up = function() return false end,
    has_player_buff = function() return false end,
    healing_get_tank = function() return nil end,
    healing_get_lowest_hp = function() return nil end,
    try_cast = function() return true end,
    unit_alive = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}
local druid_module = dofile("EaxRotations/classes/druid/resto_sylvanas.lua")
local druid = druid_module.strategies
local solo_moonfire = find_strategy(druid, "SoloMoonfire")
assert_true(solo_moonfire.matches({ is_solo = true, has_valid_enemy_target = true, target = {}, mana_pct = 60, settings = {} }, { moonfire_remains = 0, in_tree = false, lowest = { effective_hp = 95 } }), "Resto Moonfire should match in stable solo fallback")
assert_false(solo_moonfire.matches({ is_solo = true, has_valid_enemy_target = true, target = {}, mana_pct = 60, settings = {} }, { moonfire_remains = 0, in_tree = false, lowest = { effective_hp = 70 } }), "Resto Moonfire should not match when healing is unstable")

-- Holy Paladin solo fallback.
reset_package("classes/paladin/holy_sylvanas")
_G.EaxRotations = {
    PaladinSpells = {
        SealRighteousness = 21084,
        Judgement = 20271,
        HolyShock = 20473,
        HammerOfWrath = 24275,
        Consecration = 26573,
    },
    PaladinHealing = {
        scan_healing_targets = function() return {}, 0 end,
    },
    PLAYER_UNIT = {},
    POWER_MANA = 0,
    spell_action = function(ids, label) return { ids = ids, label = label } end,
    spell_ready = function() return true end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    healing_get_lowest_hp = function() return nil end,
    healing_get_tank = function() return nil end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}
local paladin = dofile("EaxRotations/classes/paladin/holy_sylvanas.lua")
local seal = find_strategy(paladin, "SealOfRighteousnessSolo")
assert_true(seal.matches({ is_solo = true, has_valid_enemy_target = true, target = {}, settings = {} }, { lowest = { effective_hp = 95, unit = {} }, has_seal_righteousness = false, mana_pct = 70 }), "Holy Paladin solo seal should match when stable")
assert_false(seal.matches({ is_solo = true, has_valid_enemy_target = true, target = {}, settings = {} }, { lowest = { effective_hp = 70, unit = {} }, has_seal_righteousness = false, mana_pct = 70 }), "Holy Paladin solo seal should not match when healing is unstable")

-- Shaman Restoration solo fallback.
reset_package("classes/shaman/restoration_sylvanas")
_G.EaxRotations = {
    ShamanSpells = {
        FlameShock = 8050,
        LightningBolt = 403,
        ChainLightning = 421,
        WaterShield = 24398,
        LightningShield = 324,
    },
    ShamanHealing = {
        scan_healing_targets = function() return {}, 0 end,
        select_heal = function() return nil end,
    },
    PLAYER_UNIT = {},
    action_matches = function() return true end,
    action_execute = function() return true end,
    spell_ready = function() return true end,
    buff_up = function() return false end,
    debuff_remains = function() return 0 end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    healing_get_lowest_hp = function() return nil end,
    healing_get_tank = function() return nil end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}
local shaman = dofile("EaxRotations/classes/shaman/restoration_sylvanas.lua")
local flame_shock = find_strategy(shaman, "FlameShock")
assert_true(flame_shock.matches({ is_solo = true, has_valid_enemy_target = true, target = {}, settings = {} }, { flame_shock_ready = true, flame_shock_remains = 0, mana_pct = 60, lowest = { effective_hp = 95 } }), "Resto Shaman Flame Shock should match in stable solo fallback")
assert_false(flame_shock.matches({ is_solo = true, has_valid_enemy_target = true, target = {}, settings = {} }, { flame_shock_ready = true, flame_shock_remains = 0, mana_pct = 20, lowest = { effective_hp = 95 } }), "Resto Shaman Flame Shock should not match below mana floor")

print("PASS test_healer_solo_fallback_matches")
