-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_exporter_smoke.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
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
