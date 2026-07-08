package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
-- test_stance_manager.lua — Unit tests for stance_manager_sylvanas.
-- WHAT:  Verify StanceManager.get_optimal_stance and should_switch.
-- WHEN:  load-time verification.
-- WHY:   Prevent regression in stance dance logic.

local function run_test()
    local _G = _G
    local orig_NS = _G.EaxRotations
    _G.EaxRotations = {
        WarriorConstants = { STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 } },
        log = function() end,
    }

    local ok, mod = pcall(dofile, "EaxRotations/shared/stance_manager_sylvanas.lua")
    if not ok or not mod then
        _G.EaxRotations = orig_NS
        error("Failed to load stance_manager_sylvanas: " .. tostring(mod))
    end

    local SM = mod

    -- Test 1: get_optimal_stance returns nil in manual mode
    local ctx_manual = { settings = { stance_mode = "manual" } }
    local state_battle = { stance = 1, hp = 100, rage = 50, in_combat = true }
    local result = SM.get_optimal_stance(ctx_manual, state_battle)
    assert(result == nil, "manual mode should return nil, got: " .. tostring(result))

    -- Test 2: get_optimal_stance returns battle when locked to battle
    local ctx_battle = { settings = { stance_mode = "battle" } }
    result = SM.get_optimal_stance(ctx_battle, state_battle)
    assert(result == "battle", "battle mode should return 'battle', got: " .. tostring(result))

    -- Test 3: get_optimal_stance returns defensive when HP < 30
    local ctx_auto = { settings = { stance_mode = "auto" } }
    local state_low_hp = { stance = 1, hp = 25, rage = 50, in_combat = true }
    result = SM.get_optimal_stance(ctx_auto, state_low_hp)
    assert(result == "defensive", "low HP should return 'defensive', got: " .. tostring(result))

    -- Test 4: should_switch returns false when already in desired stance
    local state_battle2 = { stance = 1, hp = 100, rage = 50, in_combat = true }
    local should = SM.should_switch(ctx_auto, state_battle2, "battle")
    assert(should == false, "should_switch when already in stance should be false")

    -- Test 5: should_switch returns false in manual mode
    should = SM.should_switch(ctx_manual, state_battle2, "berserker")
    assert(should == false, "should_switch in manual mode should be false")

    -- Test 6: stance_name round-trips
    assert(SM.stance_name(1) == "battle", "stance_name(1) should be 'battle'")
    assert(SM.stance_name(2) == "defensive", "stance_name(2) should be 'defensive'")
    assert(SM.stance_name(3) == "berserker", "stance_name(3) should be 'berserker'")
    assert(SM.stance_id("battle") == 1, "stance_id('battle') should be 1")
    assert(SM.stance_id("berserker") == 3, "stance_id('berserker') should be 3")

    _G.EaxRotations = orig_NS
    print("PASS: stance_manager tests")
end

run_test()
