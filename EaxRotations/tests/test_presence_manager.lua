package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
-- test_presence_manager.lua — Unit tests for presence_manager_sylvanas.
-- WHAT:  Verify PresenceManager.get_optimal_presence, should_switch_presence,
--        presence_name, and presence_id.
-- WHEN:  load-time verification.
-- WHY:   Prevent regression in Death Knight presence logic.

local function run_test()
    local _G = _G
    local orig_NS = _G.EaxRotations

    -- Default WotLK NS mock
    _G.EaxRotations = {
        is_wotlk = function() return true end,
        log = function() end,
    }

    local ok, mod = pcall(dofile, "EaxRotations/shared/presence_manager_sylvanas.lua")
    if not ok or not mod then
        _G.EaxRotations = orig_NS
        error("Failed to load presence_manager_sylvanas: " .. tostring(mod))
    end

    local PM = mod

    -- Test 1: get_optimal_presence returns blood for default DPS state
    local ctx_auto = { settings = { presence_mode = "auto" } }
    local state_dps = { hp = 100, in_combat = true, role = "dps", spec = "blood" }
    local result = PM.get_optimal_presence(ctx_auto, state_dps)
    assert(result == "blood", "default DPS should return 'blood', got: " .. tostring(result))

    -- Test 2: get_optimal_presence returns frost for tank role
    local state_tank = { hp = 100, in_combat = true, role = "tank", spec = "blood" }
    result = PM.get_optimal_presence(ctx_auto, state_tank)
    assert(result == "frost", "tank role should return 'frost', got: " .. tostring(result))

    -- Test 3: get_optimal_presence returns frost for low HP in combat
    local state_low_hp = { hp = 25, in_combat = true, role = "dps", spec = "blood" }
    result = PM.get_optimal_presence(ctx_auto, state_low_hp)
    assert(result == "frost", "low HP in combat should return 'frost', got: " .. tostring(result))

    -- Test 4: get_optimal_presence returns unholy for movement needs
    local state_movement = { hp = 100, in_combat = true, role = "dps", spec = "blood",
        movement = { is_rooted = true } }
    result = PM.get_optimal_presence(ctx_auto, state_movement)
    assert(result == "unholy", "rooted movement should return 'unholy', got: " .. tostring(result))

    -- Test 5: get_optimal_presence returns unholy for Unholy spec
    local state_unholy = { hp = 100, in_combat = true, role = "dps", spec = "unholy" }
    result = PM.get_optimal_presence(ctx_auto, state_unholy)
    assert(result == "unholy", "unholy spec should return 'unholy', got: " .. tostring(result))

    -- Test 6: get_optimal_presence returns nil in manual mode
    local ctx_manual = { settings = { presence_mode = "manual" } }
    result = PM.get_optimal_presence(ctx_manual, state_dps)
    assert(result == nil, "manual mode should return nil, got: " .. tostring(result))

    -- Test 7: get_optimal_presence respects locked modes
    local ctx_blood = { settings = { presence_mode = "blood" } }
    result = PM.get_optimal_presence(ctx_blood, state_tank)
    assert(result == "blood", "blood locked mode should return 'blood', got: " .. tostring(result))

    local ctx_frost = { settings = { presence_mode = "frost" } }
    result = PM.get_optimal_presence(ctx_frost, state_dps)
    assert(result == "frost", "frost locked mode should return 'frost', got: " .. tostring(result))

    local ctx_unholy = { settings = { presence_mode = "unholy" } }
    result = PM.get_optimal_presence(ctx_unholy, state_dps)
    assert(result == "unholy", "unholy locked mode should return 'unholy', got: " .. tostring(result))

    -- Test 8: should_switch_presence returns false when already in desired presence
    local state_blood = { presence = 1, hp = 100, in_combat = true, role = "dps", spec = "blood" }
    local should = PM.should_switch_presence(ctx_auto, state_blood, "blood")
    assert(should == false, "should_switch when already in desired presence should be false")

    -- Test 9: should_switch_presence returns true when presence differs
    local should_frost = PM.should_switch_presence(ctx_auto, state_blood, "frost")
    assert(should_frost == true, "should_switch to frost from blood should be true")

    -- Test 10: should_switch_presence returns false in manual mode
    local should = PM.should_switch_presence(ctx_manual, state_blood, "frost")
    assert(should == false, "should_switch in manual mode should be false")

    -- Test 11: presence_name round-trips
    assert(PM.presence_name(1) == "blood", "presence_name(1) should be 'blood'")
    assert(PM.presence_name(2) == "frost", "presence_name(2) should be 'frost'")
    assert(PM.presence_name(3) == "unholy", "presence_name(3) should be 'unholy'")
    assert(PM.presence_id("blood") == 1, "presence_id('blood') should be 1")
    assert(PM.presence_id("frost") == 2, "presence_id('frost') should be 2")
    assert(PM.presence_id("unholy") == 3, "presence_id('unholy') should be 3")

    -- Test 12: presence_spell_id maps to correct WotLK spell IDs
    assert(PM.presence_spell_id("blood") == 48266, "blood presence spell id should be 48266")
    assert(PM.presence_spell_id("frost") == 48263, "frost presence spell id should be 48263")
    assert(PM.presence_spell_id("unholy") == 48265, "unholy presence spell id should be 48265")

    -- Test 13: non-WotLK fallback returns nil/false safely
    _G.EaxRotations.is_wotlk = function() return false end
    local non_wotlk_optimal = PM.get_optimal_presence(ctx_auto, state_dps)
    assert(non_wotlk_optimal == nil, "non-WotLK get_optimal_presence should return nil, got: " .. tostring(non_wotlk_optimal))
    local non_wotlk_switch = PM.should_switch_presence(ctx_auto, state_blood, "frost")
    assert(non_wotlk_switch == false, "non-WotLK should_switch_presence should return false")

    _G.EaxRotations = orig_NS
    print("PASS: presence_manager tests")
end

run_test()
