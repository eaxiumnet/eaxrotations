-- test_paladin_healing_strategies.lua — Paladin Healing rotation strategy coverage.
-- WHAT:  Exercises emergency heal, triage FoL, cleanse, overheal gate, OOC buffs.
-- WHEN:  During rotation test suite execution.
-- WHY:   Scorecard gap: healing_sylvanas must be a real rotation (not a re-export stub).
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

-- Lua 5.4 compat: global unpack was moved to table.unpack
local unpack = table.unpack or unpack

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local registered = {}
local overheal_calls = 0

_G.EaxRotations = {
    CLASS_ID = { PALADIN = 2, PRIEST = 5, SHAMAN = 7, DRUID = 11 },
    PLAYER_UNIT = { _is_player = true },
    PaladinSpells = {
        FlashOfLight = 27137,
        HolyLight = 27136,
        HolyShock = 33072,
        Cleanse = 4987,
        Purify = 1152,
        DivineShield = 642,
        LayOnHands = 27154,
        BlessingOfWisdom = 27142,
        ConcentrationAura = 19746,
        SealOfWisdom = 27166,
    },
    GetPlayer = function()
        return {
            get_class = function() return 2 end,
        }
    end,
    game_time_ms = function() return 1000 end,
    import_helpers = function(...)
        local out = {}
        for i = 1, select("#", ...) do out[i] = function() return 0 end end
        return unpack(out)
    end,
    has_dispel_type_debuff = function() return false end,
    has_healing_reduction_debuff = function() return false end,
    build_healing_entries = function(t, cb)
        t[1] = {
            unit = { _u = 1 },
            hp = 40,
            effective_hp = 40,
            current_hp = 4000,
            max_hp = 10000,
            deficit = 6000,
            effective_deficit = 6000,
            time_to_die = 20,
        }
        if cb then cb(t[1], t[1].unit) end
        return 1
    end,
    healing_get_tank = function(entries) return entries and entries[1] end,
    healing_get_lowest_hp = function(entries, _, threshold)
        local e = entries and entries[1]
        if e and (e.effective_hp or 100) < (threshold or 100) then return e end
        return e
    end,
    healing_all_above_hp = function() return false end,
    healing_get_cleanse_target = function(entries)
        local e = entries and entries[1]
        if e and e.needs_cleanse then return e end
        return nil
    end,
    is_in_raid = function() return false end,
    is_in_party = function() return true end,
    spell_ready = function() return true end,
    spell_action = function(ids, name) return { id = function() return type(ids) == "table" and ids[1] or ids end, name = name } end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    has_player_buff = function() return false end,
    is_item_ready = function() return false end,
    use_item_by_id = function() return false end,
    gate_overheal = function()
        overheal_calls = overheal_calls + 1
        return false
    end,
    HealerDeficit = {
        gate_spell_overheal = function()
            overheal_calls = overheal_calls + 1
            return false
        end,
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

package.loaded["common/enums"] = { class_id = { PALADIN = 2, PRIEST = 5, SHAMAN = 7 } }
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
    try_use_potion = function() return false end,
}
package.loaded["classes/paladin/heal_helper_sylvanas"] = nil
package.loaded["classes/paladin/healing_sylvanas"] = nil

local mod = dofile("EaxRotations/classes/paladin/healing_sylvanas.lua")
assert_true(type(mod) == "table", "module returns table")
assert_true(type(mod.scan_healing_targets) == "function" or type(_G.EaxRotations.PaladinHealing) == "table",
    "helpers available")

local strategies = registered.strategies
assert_true(type(strategies) == "table" and #strategies >= 10, "≥10 strategies registered, got " .. tostring(strategies and #strategies))
assert_true(registered.name == "healing", "registers as healing")
assert_true(type(registered.opts) == "table" and type(registered.opts.get_state) == "function", "get_state provided")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local required = {
    "LayOnHands", "DivineShield", "Cleanse", "HolyShockEmergency",
    "HolyLightEmergency", "FlashOfLight", "ManaPotion", "Healthstone",
    "BlessingOfWisdom", "ConcentrationAura",
}
for i = 1, #required do
    assert_true(find(required[i]) ~= nil, "strategy present: " .. required[i])
end

local state = registered.opts.get_state({
    in_combat = true,
    is_group = true,
    is_solo = false,
    is_raid = false,
    is_pvp = false,
    is_leveling = false,
    mana_pct = 80,
    hp = 90,
    settings = {},
    me = _G.EaxRotations.PLAYER_UNIT,
})

assert_true(state ~= nil, "build_state returns state")
assert_true(state.lowest ~= nil, "state.lowest populated")
assert_true((state.lowest.effective_hp or 100) == 40, "lowest at 40%")

local loh = find("LayOnHands")
assert_false(loh.matches({ settings = {} }, { lowest = { effective_hp = 40, unit = {} }, loh_ready = true }),
    "LoH must not match at 40%")
assert_true(loh.matches({ settings = {} }, { lowest = { effective_hp = 12, unit = {} }, loh_ready = true }),
    "LoH matches emergency <15%")

local fol = find("FlashOfLight")
assert_true(fol.matches({
    in_combat = true,
    is_moving = false,
    settings = { healer_predict_enabled = true },
}, {
    lowest = { effective_hp = 70, unit = {}, deficit = 2000 },
    mana_pct = 50,
    fol_ready = true,
}), "FoL matches injured target")
assert_true(overheal_calls > 0, "FoL path exercises HealerDeficit/overheal gate")

local cleanse = find("Cleanse")
assert_false(cleanse.matches({ settings = {} }, { cleanse_target = nil, cleanse_ready = true }),
    "Cleanse skips without target")
assert_true(cleanse.matches({ settings = {} }, {
    cleanse_target = { unit = {}, needs_cleanse = true },
    cleanse_ready = true,
}), "Cleanse matches when cleanse_target set")

local bow = find("BlessingOfWisdom")
assert_true(bow.matches({
    in_combat = false,
    settings = {},
}, {
    has_blessing_wisdom = false,
    bow_ready = true,
}), "BoW matches OOC without buff")
assert_false(bow.matches({
    in_combat = true,
    settings = {},
}, {
    has_blessing_wisdom = false,
    bow_ready = true,
}), "BoW skips in combat")

print("PASS test_paladin_healing_strategies (" .. #strategies .. " strategies)")
