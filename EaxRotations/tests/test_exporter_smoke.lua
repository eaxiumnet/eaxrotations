package.path = "EaxRotations/?.lua;" .. package.path

local logs = {}

_G.EaxRotations = {
    class_config = {
        class = "mage",
        playstyle_labels = {
            arcane = "Arcane",
        },
    },
    current_playstyle = "arcane",
    rotation_registry = {
        strategy_maps = {
            arcane = {
                { name = "ArcaneBlast", spell = { ID = 30451 }, priority = 1000, matches = function() return true end },
                { name = "FireBlast", spell = { ID = 2136 }, priority = 900, is_aoe = false },
            },
        },
        middleware = {
            { is_burst = true, spell = { ID = 12042 } },
        },
    },
    time_now = function() return 123 end,
    log = function(message) logs[#logs + 1] = message end,
}

package.loaded.exporter = nil
local exporter = require("exporter")

local rotation = exporter.export_rotation("arcane")
assert(rotation.class == "mage", "exported class")
assert(rotation.spec == "arcane", "exported spec")
assert(#rotation.priorities == 2, "exported priorities")
assert(rotation.priorities[1].spell_id == 30451, "spell ID exported")
assert(#rotation.cooldowns == 1, "middleware cooldown exported")

local all = exporter.export_all_rotations()
assert(#all == 1, "export all rotations")

local json = exporter.export_to_json("unused.json", "arcane")
assert(type(json) == "string", "offline export returns JSON")
assert(json:find('"source_addon":"Sylvanas"', 1, true), "JSON contains source")
assert(json:find('"spell_id":30451', 1, true), "JSON contains spell id")

print("PASS test_exporter_smoke")
