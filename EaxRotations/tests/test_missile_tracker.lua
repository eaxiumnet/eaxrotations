-- ============================================================================
-- Test: Missile Tracker (missile_tracker_sylvanas.lua)
-- Scenarios:
--   a) Mock 1 incoming Polymorph → incoming_cc() returns true
--   b) Mock 0 missiles → incoming_cc() returns false
--   c) Mock 1 incoming Fireball (not CC) → incoming_cc() returns false
--   d) Mock API unavailable → all functions return safe defaults
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;" .. package.path

local test_logs = {}

-- Mock local player
local mock_player = {
    get_guid = function() return "PlayerGUID-001" end,
    get_name = function() return "TestPlayer" end,
}

-- Mock missile factory
local function make_missile(spell_id, target_guid)
    return {
        spell_id = spell_id,
        target = target_guid and { get_guid = function() return target_guid end } or nil,
        caster = { get_guid = function() return "EnemyGUID-001" end },
        source_position = { x = 0, y = 0, z = 0 },
        current_position = { x = 10, y = 5, z = 0 },
        impact_position = { x = 20, y = 10, z = 0 },
        speed = 20,
    }
end

-- Polymorph (118) is a CC spell
-- Fireball (133) is NOT a CC spell
local POLYMORPH_ID = 118
local FIREBALL_ID = 133

-- ============================================================================
-- Scenario A: 1 incoming Polymorph → incoming_cc() returns true
-- ============================================================================
do
    _G.core = {
        object_manager = {
            get_all_missiles = function()
                return {
                    make_missile(POLYMORPH_ID, "PlayerGUID-001"),
                }
            end,
        },
    }
    _G.EaxRotations = {
        log = function(msg) test_logs[#test_logs + 1] = msg end,
        GetPlayer = function() return mock_player end,
        time_now = function() return 100.0 end,
        register_on_spell_cast = function() return true end,
    }

    package.loaded["shared/missile_tracker_sylvanas"] = nil
    local MT = require("shared/missile_tracker_sylvanas")

    assert(MT.incoming_cc() == true, "Scenario A: incoming_cc() should return true with Polymorph missile targeting player")
    print("  [ PASS ] Scenario A: incoming Polymorph detected")
end

-- ============================================================================
-- Scenario B: 0 missiles → incoming_cc() returns false
-- ============================================================================
do
    _G.core = {
        object_manager = {
            get_all_missiles = function()
                return {}
            end,
        },
    }
    _G.EaxRotations = {
        log = function(msg) test_logs[#test_logs + 1] = msg end,
        GetPlayer = function() return mock_player end,
        time_now = function() return 100.0 end,
        register_on_spell_cast = function() return true end,
    }

    package.loaded["shared/missile_tracker_sylvanas"] = nil
    local MT = require("shared/missile_tracker_sylvanas")

    assert(MT.incoming_cc() == false, "Scenario B: incoming_cc() should return false with no missiles")
    assert(MT.missile_count() == 0, "Scenario B: missile_count() should return 0 with empty list")
    print("  [ PASS ] Scenario B: no missiles -> false/0")
end

-- ============================================================================
-- Scenario C: 1 incoming Fireball (not CC) → incoming_cc() returns false
-- ============================================================================
do
    _G.core = {
        object_manager = {
            get_all_missiles = function()
                return {
                    make_missile(FIREBALL_ID, "PlayerGUID-001"),
                }
            end,
        },
    }
    _G.EaxRotations = {
        log = function(msg) test_logs[#test_logs + 1] = msg end,
        GetPlayer = function() return mock_player end,
        time_now = function() return 100.0 end,
        register_on_spell_cast = function() return true end,
    }

    package.loaded["shared/missile_tracker_sylvanas"] = nil
    local MT = require("shared/missile_tracker_sylvanas")

    assert(MT.incoming_cc() == false, "Scenario C: incoming_cc() should return false with non-CC Fireball missile")
    assert(MT.missile_count() == 1, "Scenario C: missile_count() should return 1 with one missile")
    print("  [ PASS ] Scenario C: non-CC Fireball -> false, count=1")
end

-- ============================================================================
-- Scenario D: API unavailable → all functions return safe defaults
-- ============================================================================
do
    _G.core = {
        object_manager = {
            get_all_missiles = nil,  -- API not available
        },
    }
    _G.EaxRotations = {
        log = function(msg) test_logs[#test_logs + 1] = msg end,
        GetPlayer = function() return nil end,
        time_now = function() return 100.0 end,
        register_on_spell_cast = function() return true end,
    }

    package.loaded["shared/missile_tracker_sylvanas"] = nil
    local MT = require("shared/missile_tracker_sylvanas")

    assert(MT.incoming_cc() == false, "Scenario D: incoming_cc() should return false when API unavailable")
    assert(MT.missile_count() == 0, "Scenario D: missile_count() should return 0 when API unavailable")
    local targeting = MT.missiles_targeting(mock_player)
    assert(type(targeting) == "table", "Scenario D: missiles_targeting() should return a table")
    assert(#targeting == 0, "Scenario D: missiles_targeting() should return empty table when API unavailable")
    print("  [ PASS ] Scenario D: API unavailable returns safe defaults")
end

print("PASS test_missile_tracker")
