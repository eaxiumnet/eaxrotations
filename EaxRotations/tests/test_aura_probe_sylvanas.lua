-- test_aura_probe_sylvanas.lua — Unit tests for aura probe shared module.
-- WHAT:  mocks core API and validates aura query helpers (has_buff, buff_remains, etc.).
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   aura_probe is a low-level shared dependency; regressions break many specs.
-- SAFETY: fully mocked; no real unit or spell interaction.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local logs = {}
_G.core = {
    log = function(message) logs[#logs + 1] = message end,
    object_manager = {},
}

local player = {}
function player:get_buffs()
    return {
        { buff_id = 25472, buff_name = "Lightning Shield", count = 3, remaining = 120 },
        { buff_id = 33736, buff_name = "Water Shield", count = 1, remaining = 300 },
    }
end

function player:get_auras()
    return {
        { buff_id = 430, buff_name = "Drink", count = 1, remaining = 20 },
    }
end

function player:get_debuffs()
    return {}
end

function player:has_buff(ids)
    for i = 1, #ids do
        if ids[i] == 25472 then return true end
    end
    return false
end

_G.EaxRotations = {
    GetPlayer = function() return player end,
    log = function(message) logs[#logs + 1] = message end,
}

package.loaded["shared/aura_probe_sylvanas"] = nil
local probe = require("shared/aura_probe_sylvanas")

local rows, checks = probe.compare_player_auras(player)
assert(#rows == 3, "expected three mocked aura rows")

local found_lightning = false
local found_drink = false
for i = 1, #checks do
    if checks[i].name == "spells.shaman.lightning_shield" then
        found_lightning = true
        assert(checks[i].raw == true, "Lightning Shield should match raw cache")
        assert(checks[i].unit_buff == true, "Lightning Shield should match direct buff helper")
    elseif checks[i].name == "buffs.drink" then
        found_drink = true
        assert(checks[i].raw == true, "Drink should match raw cache")
    end
end

assert(found_lightning, "expected Lightning Shield central-data match")
assert(found_drink, "expected drink central-data match")
assert(probe.dump_player_auras() == true, "dump should return true with local player")
assert(_G.EaxRotations.get_aura_probe_report() ~= nil, "last report should be exposed")

print("PASS test_aura_probe_sylvanas")
