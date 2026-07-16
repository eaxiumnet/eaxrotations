-- test_shaman_healing_strategies.lua — Shaman Healing rotation strategy coverage.
-- WHAT:  Exercises NS emergency, LHW/HW/CH triage, cleanse, overheal gate, shields.
-- WHEN:  During rotation test suite execution.
-- WHY:   Scorecard gap: healing_sylvanas must be a real rotation with triage/dispel.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local registered = {}
local overheal_calls = 0

_G.EaxRotations = {
    CLASS_ID = { PALADIN = 2, PRIEST = 5, SHAMAN = 7 },
    PLAYER_UNIT = {},
    ShamanSpells = {
        HealingWave = 25396, LesserHealingWave = 25420, ChainHeal = 25423,
        EarthShield = 32594, WaterShield = 33736, NaturesSwiftness = 16188,
        CurePoison = 526, CureDisease = 2870, ManaTideTotem = 16190, ManaSpringTotem = 25570,
    },
    GetPlayer = function()
        return { get_class = function() return 7 end }
    end,
    game_time_ms = function() return 1000 end,
    import_helpers = function(...)
        local n = select("#", ...)
        local out = {}
        for i = 1, n do out[i] = function() return 0 end end
        return unpack(out)
    end,
    has_dispel_type_debuff = function(_, dtype) return dtype == "Poison" end,
    has_healing_reduction_debuff = function() return false end,
    build_healing_entries = function(t, cb)
        t[1] = {
            unit = { _u = 1 },
            hp = 40, effective_hp = 40, current_hp = 4000, max_hp = 10000,
            deficit = 6000, effective_deficit = 6000, time_to_die = 12,
            has_poison = true, has_disease = false, needs_cleanse = true,
        }
        if cb then cb(t[1], t[1].unit) end
        return 1
    end,
    healing_get_tank = function(entries) return entries and entries[1] end,
    healing_get_lowest_hp = function(entries) return entries and entries[1] end,
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function(entries) return entries and entries[1] end,
    healing_count_below_hp = function() return 2 end,
    is_in_raid = function() return false end,
    is_in_party = function() return true end,
    spell_ready = function() return true end,
    spell_action = function(ids, name) return { id = function() return type(ids) == "table" and ids[1] or ids end, name = name } end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return false end,
    gate_overheal = function() overheal_calls = overheal_calls + 1; return false end,
    HealerDeficit = {
        gate_spell_overheal = function() overheal_calls = overheal_calls + 1; return false end,
        heal_would_overheal = function() return false end,
    },
    log = function() end,
    rotation_registry = {
        register = function(_, name, strategies, opts)
            registered.name = name
            registered.strategies = strategies
            registered.opts = opts
        end,
    },
}

package.loaded["common/enums"] = { class_id = { SHAMAN = 7, PRIEST = 5, PALADIN = 2 } }
package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
    define_action_for_class = function(SPELLS)
        return function(name, ids)
            if SPELLS and SPELLS[name] ~= nil then return SPELLS[name] end
            return type(ids) == "table" and ids[1] or ids
        end
    end,
    safe_state = function(s) return s end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    MANA_POTION_IDS = { 22832 },
    try_use_potion = function() return false end,
}
package.loaded["classes/shaman/healing_sylvanas"] = nil

local mod = dofile("EaxRotations/classes/shaman/healing_sylvanas.lua")
assert_true(type(mod) == "table", "module returns table")
assert_true(type(mod.select_heal) == "function", "helpers preserved")

local strategies = registered.strategies
assert_true(type(strategies) == "table" and #strategies >= 10, "≥10 strategies, got " .. tostring(strategies and #strategies))
assert_true(registered.name == "healing", "registers as healing")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

for _, name in ipairs({
    "NaturesSwiftness", "NSHealingWave", "LesserHealingWave", "HealingWave", "ChainHeal",
    "EarthShield", "WaterShield", "CurePoison", "CureDisease", "ManaPotion", "ManaSpringTotem",
}) do
    assert_true(find(name) ~= nil, "strategy present: " .. name)
end

local state = registered.opts.get_state({
    in_combat = true, is_group = true, mana_pct = 60, hp = 85, settings = {},
})
assert_true(state.lowest ~= nil, "lowest populated")
assert_true(state.cleanse_target ~= nil, "cleanse_target populated")

local ns = find("NaturesSwiftness")
assert_true(ns.matches({ settings = {} }, {
    ns_ready = true, ns_active = false, lowest_hp = 20,
}), "NS matches emergency")
assert_false(ns.matches({ settings = {} }, {
    ns_ready = true, ns_active = false, lowest_hp = 50,
}), "NS skips above emergency")

local lhw = find("LesserHealingWave")
assert_true(lhw.matches({
    is_moving = false, settings = { healer_predict_enabled = true },
}, {
    lowest = { effective_hp = 40, unit = {} },
    lhw_ready = true,
}), "LHW matches low HP")
assert_true(overheal_calls > 0, "overheal gate exercised")

local poison = find("CurePoison")
assert_true(poison.matches({ settings = {} }, {
    cure_poison_ready = true,
    cleanse_target = { unit = {}, has_poison = true },
}), "CurePoison matches poison target")

local ws = find("WaterShield")
assert_true(ws.matches({ settings = {} }, {
    has_water_shield = false, ws_ready = true,
}), "WaterShield when missing")

print("PASS test_shaman_healing_strategies (" .. #strategies .. " strategies)")
