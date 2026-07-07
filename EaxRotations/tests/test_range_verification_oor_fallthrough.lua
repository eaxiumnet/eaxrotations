-- test_range_verification_oor_fallthrough.lua — Range verification: OOR must not stall.
-- WHAT:  verifies try_cast returns false (does NOT commit) when a spell is out of
--        range, so the dispatcher falls through to in-range spells; and that an
--        in-range spell still casts. Covers the is_spell_in_range native-false fix
--        and the is_out_of_range defense-in-depth gate in evaluate_cast.
-- WHEN:  run standalone or via the test runner.
-- WHY:   bug: rotations stalled on a short-range spell (e.g. Mind Flay 24yd at 30yd)
--        while a longer-range spell (Mind Blast 36yd) was castable, because try_cast
--        committed the OOR spell instead of returning false so the dispatcher could
--        fall through to the in-range spell.
-- SAFETY: fully mocked; no real casting.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local MF_ID = 18807  -- Mind Flay (24yd channeled filler)
local MB_ID = 8092   -- Mind Blast (36yd nuke)

-- Inject a mock spell_helper that simulates the native QUIRK: is_spell_in_range /
-- is_spell_castable report "in range / castable" regardless of ground-truth
-- distance. This is the exact stall scenario — the is_out_of_range backstop must
-- still catch the OOR spell via real distance vs spell max range.
local sh_calls = { in_range = 0, castable = 0 }
local mock_spell_helper = {
    is_spell_in_range = function(self, id, target, src, dst)
        sh_calls.in_range = sh_calls.in_range + 1
        return true  -- quirk: native says in-range regardless
    end,
    is_spell_castable = function(self, id, caster, target, sf, sr, su, sc, sl)
        sh_calls.castable = sh_calls.castable + 1
        return true  -- quirk: native says castable regardless of range
    end,
    get_spell_cooldown = function(self, id) return 0 end,
}
package.loaded["common/utility/spell_helper"] = mock_spell_helper

local izi_casts = 0
local player = {
    is_alive = function() return true end,
    is_valid = function() return true end,
    is_casting_spell = function() return false end,
    is_channelling_spell = function() return false end,
    get_health_percentage = function() return 100 end,
    get_mana_percentage = function() return 100 end,
    get_power = function() return 1000 end,
}

local function make_target(dist)
    return {
        is_alive = function() return true end,
        is_valid = function() return true end,
        get_health_percentage = function() return 100 end,
        get_distance = function() return dist end,
    }
end

-- Per-spell max range mock (matches TBC ranges: Mind Flay 24, Mind Blast 36).
local MAX_RANGE = { [MF_ID] = 24, [MB_ID] = 36 }

_G.core = {
    time = function() return 100 end,
    game_time = function() return 100000 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    object_manager = { get_local_player = function() return player end },
    spell_book = {
        is_spell_learned = function() return true end,
        has_spell = function() return true end,
        get_global_cooldown = function() return 0 end,
        get_spell_cooldown = function() return 0 end,
        get_spell_cooldown_information = function() return nil end,
        get_spell_costs = function() return {} end,
        get_spell_max_range = function(id) return MAX_RANGE[id] or 0 end,
        is_spell_in_range = function() return true end,
    },
    input = { cast_target_spell = function() return true end },
}

package.loaded.core_sylvanas = nil
_G.EaxRotations = nil

local NS = require("core_sylvanas")

NS.izi = {
    spell = function(id)
        return {
            cast_safe = function(_, unit, reason)
                izi_casts = izi_casts + 1
                return true
            end,
        }
    end,
}

-- Sanity: numeric spell ids resolve and the mock spell_helper was wired in.
assert(NS.get_spell_id(MF_ID) == MF_ID, "Mind Flay id should resolve")
assert(NS.get_spell_id(MB_ID) == MB_ID, "Mind Blast id should resolve")

----------------------------------------------------------------
-- Case 1: OOR spell must NOT commit (Mind Flay 24yd at 30yd).
--          Ground-truth distance defeats the native "in range" quirk so the
--          dispatcher can fall through to an in-range spell.
----------------------------------------------------------------
local far_target = make_target(30)
assert(NS.is_out_of_range(MF_ID, far_target) == true,
    "Mind Flay (24yd) at 30yd must be detected OOR by ground truth (distance vs max range)")
assert(NS.try_cast(MF_ID, far_target, "[TEST] Mind Flay OOR") == false,
    "try_cast must return false for OOR Mind Flay so the dispatcher can fall through")
assert(izi_casts == 0,
    "OOR Mind Flay must NOT commit via cast_safe (izi_casts=" .. izi_casts .. ")")

----------------------------------------------------------------
-- Case 2: in-range spell DOES cast (Mind Blast 36yd at 30yd).
--          This is the fallthrough target — must not be false-positive blocked.
----------------------------------------------------------------
local in_range_target = make_target(30)
assert(NS.is_out_of_range(MB_ID, in_range_target) == false,
    "Mind Blast (36yd) at 30yd must NOT be flagged OOR (would break fallthrough)")
assert(NS.try_cast(MB_ID, in_range_target, "[TEST] Mind Blast in range") == true,
    "try_cast must succeed for in-range Mind Blast (the fallthrough target)")
assert(izi_casts == 1,
    "in-range Mind Blast should commit exactly once (izi_casts=" .. izi_casts .. ")")

----------------------------------------------------------------
-- Case 3: Mind Flay at the edge of its range (24yd at 24yd) casts.
--          Tolerance must not false-positive a valid at-max-range cast.
----------------------------------------------------------------
izi_casts = 0
local edge_target = make_target(24)
assert(NS.is_out_of_range(MF_ID, edge_target) == false,
    "Mind Flay (24yd) at exactly 24yd must NOT be flagged OOR")
assert(NS.try_cast(MF_ID, edge_target, "[TEST] Mind Flay edge") == true,
    "try_cast must succeed for Mind Flay at max range")
assert(izi_casts == 1,
    "edge Mind Flay should commit exactly once (izi_casts=" .. izi_casts .. ")")

----------------------------------------------------------------
-- Case 4: is_spell_in_range respects a native false (OOR) verdict.
--          Previously it fell through to fail-open, masking real OOR.
----------------------------------------------------------------
local native_false_calls = 0
mock_spell_helper.is_spell_in_range = function(self, id, target, src, dst)
    native_false_calls = native_false_calls + 1
    return false  -- native says OOR
end
local oor_target = make_target(40)
assert(NS.is_spell_in_range(MF_ID, oor_target) == false,
    "is_spell_in_range must RESPECT a native false (OOR) verdict, not fall through to true")
assert(native_false_calls >= 1, "native is_spell_in_range should be consulted")

print("PASS test_range_verification_oor_fallthrough")
