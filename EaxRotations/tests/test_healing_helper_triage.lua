-- test_healing_helper_triage.lua — Priest/Shaman/Paladin healing helper surface.
-- WHAT:  verifies healing helper modules expose triage/overheal APIs used by full specs.
-- WHEN:  rotation suite (Scenario 3 emergency/triage contract).
-- WHY:  healing_*_sylvanas helpers scored features:1; prove real APIs + overheal gate.
-- SAFETY: synthetic NS; class-gate bypassed via mocked player class.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;api/?.lua;" .. package.path

-- Lua 5.4 compat: global unpack was moved to table.unpack
local unpack = table.unpack or unpack

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local CLASS = { PRIEST = 5, SHAMAN = 7, PALADIN = 2, DRUID = 11 }
local current_class = CLASS.PRIEST

_G.core = {
    log_error = function() end,
    log = function() end,
}

_G.EaxRotations = {
    CLASS_ID = CLASS,
    GetPlayer = function()
        return {
            get_class = function() return current_class end,
        }
    end,
    import_helpers = function(...)
        local out = {}
        for i = 1, select("#", ...) do out[i] = function() return 0 end end
        return unpack(out)
    end,
    buff_points = function() return { 500 } end,
    has_dispel_type_debuff = function() return false end,
    is_in_raid = function() return false end,
    is_in_party = function() return true end,
    has_healing_reduction_debuff = function() return false end,
    build_healing_entries = function() return 0 end,
    healing_get_tank = function() return nil end,
    healing_get_lowest_hp = function() return nil end,
    healing_all_above_hp = function() return true end,
    healing_get_cleanse_target = function() return nil end,
    healing_count_below_hp = function() return 0 end,
    game_time_ms = function() return 1000 end,
    HealerDeficit = {
        gate_spell_overheal = function(spell_key, unit, cast_time, settings, spell_id)
            if spell_key == "flash" and unit and unit._hp and unit._hp > 90 then return true end
            return false
        end,
    },
    gate_overheal = function() return false end,
    PriestSpells = {},
    ShamanSpells = {},
    PaladinSpells = {},
    DruidSpells = {},
}

package.loaded["common/enums"] = { class_id = CLASS }

-- Priest healing helper
current_class = CLASS.PRIEST
package.loaded["classes/priest/healing_sylvanas"] = nil
dofile("EaxRotations/classes/priest/healing_sylvanas.lua")
local PH = _G.EaxRotations.PriestHealing
assert_true(type(PH) == "table", "PriestHealing table")
assert_true(type(PH.pws_absorb_remaining) == "function", "pws_absorb_remaining")
assert_true(type(PH.gate_overheal) == "function", "priest gate_overheal")
assert_true(PH.gate_overheal("flash", { _hp = 95 }, 1.5, {}, 2061) == true, "priest overheal gate blocks high HP")
assert_true(PH.gate_overheal("flash", { _hp = 40 }, 1.5, {}, 2061) == false, "priest overheal allows low HP")
assert_eq(PH.pws_absorb_remaining({}), 500, "pws absorb from buff_points")

-- Shaman healing helper
current_class = CLASS.SHAMAN
package.loaded["classes/shaman/healing_sylvanas"] = nil
-- re-require via dofile fresh globals
dofile("EaxRotations/classes/shaman/healing_sylvanas.lua")
local SH = _G.EaxRotations.ShamanHealing
assert_true(type(SH) == "table", "ShamanHealing table")
assert_true(type(SH.get_lowest_hp_target) == "function", "shaman get_lowest_hp_target")
assert_true(type(SH.scan_healing_targets) == "function", "shaman scan_healing_targets")
assert_true(type(SH.get_cleanse_target) == "function", "shaman get_cleanse_target")

-- Paladin heal helper (via healing re-export path)
current_class = CLASS.PALADIN
local ok_pally = pcall(dofile, "EaxRotations/classes/paladin/healing_sylvanas.lua")
assert_true(ok_pally, "paladin healing re-export loads")

print("PASS test_healing_helper_triage")
