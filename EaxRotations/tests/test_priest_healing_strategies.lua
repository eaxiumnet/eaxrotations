-- test_priest_healing_strategies.lua — Priest Healing rotation strategy coverage.
-- WHAT:  Exercises emergency PW:S/Flash, triage, dispel, overheal gate, OOC buffs.
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
    PriestSpells = {
        PowerWordShield = 25218, FlashHeal = 25235, GreaterHeal = 25213,
        Renew = 25222, DispelMagic = 988, CureDisease = 528, AbolishDisease = 552,
        Fade = 586, DesperatePrayer = 25437, InnerFire = 25431, PowerWordFortitude = 25389,
    },
    GetPlayer = function()
        return { get_class = function() return 5 end }
    end,
    game_time_ms = function() return 1000 end,
    import_helpers = function(...)
        local n = select("#", ...)
        local out = {}
        for i = 1, n do out[i] = function() return 0 end end
        return unpack(out)
    end,
    has_dispel_type_debuff = function() return false end,
    build_healing_entries = function(t, cb)
        t[1] = {
            unit = { _u = 1 },
            hp = 45, effective_hp = 45, current_hp = 4500, max_hp = 10000,
            deficit = 5500, effective_deficit = 5500, time_to_die = 15,
        }
        if cb then cb(t[1], t[1].unit) end
        return 1
    end,
    healing_get_tank = function(entries) return entries and entries[1] end,
    healing_get_lowest_hp = function(entries) return entries and entries[1] end,
    healing_count_below_hp = function() return 1 end,
    is_in_raid = function() return false end,
    is_in_party = function() return true end,
    spell_ready = function() return true end,
    spell_action = function(ids, name) return { id = function() return type(ids) == "table" and ids[1] or ids end, name = name } end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    buff_remains = function() return 0 end,
    buff_points = function() return nil end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return false end,
    gate_overheal = function() overheal_calls = overheal_calls + 1; return false end,
    HealerDeficit = {
        gate_spell_overheal = function() overheal_calls = overheal_calls + 1; return false end,
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

package.loaded["common/enums"] = { class_id = { PRIEST = 5, PALADIN = 2, SHAMAN = 7 } }
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
package.loaded["classes/priest/healing_sylvanas"] = nil

local mod = dofile("EaxRotations/classes/priest/healing_sylvanas.lua")
assert_true(type(mod) == "table", "module returns table")
assert_true(type(mod.scan_healing_targets) == "function", "helpers preserved")

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
    "EmergencyPWS", "EmergencyFlashHeal", "FlashHeal", "GreaterHeal", "Renew",
    "DispelMagic", "CureDisease", "Fade", "ManaPotion", "InnerFire", "PowerWordFortitude",
}) do
    assert_true(find(name) ~= nil, "strategy present: " .. name)
end

local state = registered.opts.get_state({
    in_combat = true, is_group = true, mana_pct = 70, hp = 80, settings = {},
})
assert_true(state.lowest ~= nil, "lowest populated")

local pws = find("EmergencyPWS")
assert_true(pws.matches({ settings = {} }, {
    lowest = { effective_hp = 40, unit = {} },
    pws_ready = true, has_weakened_soul = false,
}), "EmergencyPWS matches low HP without Weakened Soul")
assert_false(pws.matches({ settings = {} }, {
    lowest = { effective_hp = 40, unit = {} },
    pws_ready = true, has_weakened_soul = true,
}), "EmergencyPWS blocked by Weakened Soul")

local flash = find("FlashHeal")
assert_true(flash.matches({
    is_moving = false, settings = { healer_predict_enabled = true },
}, {
    lowest = { effective_hp = 60, unit = {} },
    flash_ready = true, mana_pct = 50,
}), "FlashHeal matches injured")
assert_true(overheal_calls > 0, "overheal gate exercised")

local inner = find("InnerFire")
assert_true(inner.matches({ in_combat = false, settings = {} }, {
    has_inner_fire = false, inner_fire_ready = true,
}), "InnerFire OOC")
assert_false(inner.matches({ in_combat = true, settings = {} }, {
    has_inner_fire = false, inner_fire_ready = true,
}), "InnerFire skips combat")

print("PASS test_priest_healing_strategies (" .. #strategies .. " strategies)")
