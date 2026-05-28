-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_threat_drop_party_gate.lua"
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
-- regression test for Fade, Feign Death, Cower, and Soulshatter gating.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local now = 0
local target = {}
local party_members = {}
local player = {}
local threat = 0

function player:get_party_members_in_range() return party_members end
function player:get_threat_situation() return threat end
function player:is_alive() return true end
function player:is_valid() return true end

local function ally(in_combat, yards)
    return {
        is_in_combat = function() return in_combat end,
        get_distance = function() return yards end,
    }
end

_G.core = {
    game_time = function() now = now + 200; return now end,
    time = function() return now / 1000 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = {
        get_local_player = function() return player end,
        get_visible_objects = function() return {} end,
    },
    spell_book = {},
    input = {},
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil
local NS = require("core_sylvanas")
local context = { in_combat = true, target = target }

party_members, threat = {}, 3
assert(NS.should_drop_threat(context) == false, "solo threat drop blocked")

party_members, threat = { ally(false, 30) }, 3
assert(NS.should_drop_threat(context) == false, "out-of-combat party member blocked")

party_members, threat = { ally(true, 30) }, 1
assert(NS.should_drop_threat(context) == false, "low threat blocked")

party_members, threat = { ally(true, 30) }, 3
assert(NS.should_drop_threat(context) == true, "party combat high threat allowed")

print("PASS test_threat_drop_party_gate")
