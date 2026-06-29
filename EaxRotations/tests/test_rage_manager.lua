-- test_rage_manager.lua — Unit tests for rage_manager_sylvanas.
-- WHAT:  Verify RageManager.should_heroic_strike, should_cleave, recommend_dump.
-- WHEN:  load-time verification.
-- WHY:   Prevent regression in rage dump logic.

local function run_test()
    local _G = _G
    local orig_NS = _G.EaxRotations
    _G.EaxRotations = {
        log = function() end,
        GetPlayer = function() return {} end,
        swing_time_until = function(me, slot)
            if slot == 2 then return 999 end
            return 999
        end,
    }

    local ok, mod = pcall(dofile, "EaxRotations/shared/rage_manager_sylvanas.lua")
    if not ok or not mod then
        _G.EaxRotations = orig_NS
        error("Failed to load rage_manager_sylvanas: " .. tostring(mod))
    end

    local RM = mod

    -- Test 1: should_heroic_strike returns false below threshold
    local ctx = { settings = { rage_dump_threshold = 80, rage_dump_ability = "auto" } }
    local state_low = { rage = 50, enemy_count = 1, ms_cd = 99, bt_cd = 99, execute_phase = false, target_casting_interruptible = false, pummel_ready = false }
    local result = RM.should_heroic_strike(ctx, state_low, "arms")
    assert(result == false, "HS below threshold should be false")

    -- Test 2: should_heroic_strike returns true above threshold in ST
    local state_high = { rage = 90, enemy_count = 1, ms_cd = 99, bt_cd = 99, execute_phase = false, target_casting_interruptible = false, pummel_ready = false }
    result = RM.should_heroic_strike(ctx, state_high, "arms")
    assert(result == true, "HS above threshold in ST should be true")

    -- Test 3: should_cleave returns false in ST
    result = RM.should_cleave(ctx, state_high, 1, "arms")
    assert(result == false, "Cleave in ST should be false")

    -- Test 4: should_cleave returns true in AoE with enough rage
    local state_aoe = { rage = 90, enemy_count = 3, ms_cd = 99, bt_cd = 99, execute_phase = false, target_casting_interruptible = false, pummel_ready = false }
    result = RM.should_cleave(ctx, state_aoe, 3, "arms")
    assert(result == true, "Cleave in AoE should be true")

    -- Test 5: recommend_dump returns cleave in AoE
    local dump = RM.recommend_dump(ctx, state_aoe, "arms")
    assert(dump == "cleave", "recommend_dump in AoE should be 'cleave', got: " .. tostring(dump))

    -- Test 6: recommend_dump returns heroic_strike in ST
    dump = RM.recommend_dump(ctx, state_high, "arms")
    assert(dump == "heroic_strike", "recommend_dump in ST should be 'heroic_strike', got: " .. tostring(dump))

    -- Test 7: should_heroic_strike respects dump_mode = "cleave"
    ctx.settings.rage_dump_ability = "cleave"
    result = RM.should_heroic_strike(ctx, state_high, "arms")
    assert(result == false, "HS when dump_mode=cleave should be false")

    _G.EaxRotations = orig_NS
    print("PASS: rage_manager tests")
end

run_test()
