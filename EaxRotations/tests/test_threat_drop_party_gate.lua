-- Readability notes:
--   What: regression test for Fade, Feign Death, Cower, and Soulshatter gating.
--   When: run from the repository root with lua.
--   Why: threat drops must never fire while solo or around unrelated friendly units.
--   Safety: uses a local API stub only; no game input is called.

-- Decision notes:
--   Tests use local stubs instead of a live Sylvanas client so API-bound behavior remains reproducible.
--   Each case protects one previous failure mode or role rule; keep assertions narrow and descriptive.
--   No test should call real input/cast APIs because regression runs must be safe outside the game.
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
