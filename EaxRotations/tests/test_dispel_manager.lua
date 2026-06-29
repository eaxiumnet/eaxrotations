-- test_dispel_manager.lua — Unit tests for dispel_manager_sylvanas.
-- WHAT:  Verify DispelManager.can_dispel, is_throttled, should_dispel.
-- WHEN:  load-time verification.
-- WHY:   Prevent regression in auto-dispel logic.

local function mock_NS(class_id)
    return {
        log = function() end,
        GetPlayer = function()
            return {
                get_class = function() return class_id end,
            }
        end,
        time_now = function() return 0 end,
    }
end

local function run_test()
    local _G = _G
    local orig_NS = _G.EaxRotations

    -- Test 1: PRIEST can dispel magic and disease
    _G.EaxRotations = mock_NS(5)
    local ok, mod = pcall(dofile, "EaxRotations/shared/dispel_manager_sylvanas.lua")
    if not ok or not mod then
        _G.EaxRotations = orig_NS
        error("Failed to load dispel_manager_sylvanas: " .. tostring(mod))
    end

    local DM = mod
    assert(DM.can_dispel("magic") == true, "PRIEST should dispel magic")
    assert(DM.can_dispel("disease") == true, "PRIEST should dispel disease")
    assert(DM.can_dispel("curse") == false, "PRIEST should not dispel curse")
    assert(DM.can_dispel("poison") == false, "PRIEST should not dispel poison")

    -- Test 2: get_dispel_spell returns a number for magic
    local spell = DM.get_dispel_spell("magic")
    assert(type(spell) == "number" and spell > 0, "PRIEST dispel magic spell should be a positive number")

    -- Test 3: Throttle
    assert(DM.is_throttled() == false, "Fresh throttle should be false")
    DM.record_dispel()
    assert(DM.is_throttled() == true, "After record_dispel, should be throttled")

    -- Test 4: should_dispel respects auto_dispel = false
    local ctx = { settings = { auto_dispel = false } }
    local should = DM.should_dispel(ctx, {})
    assert(should == false, "auto_dispel=false should block")

    -- Test 5: should_dispel respects throttling
    ctx = { settings = { auto_dispel = true } }
    should = DM.should_dispel(ctx, {})
    assert(should == false, "Throttled should block even with auto_dispel=true")

    -- Test 6: should_dispel respects tank critical HP
    DM._last_dispel_at = -10  -- reset throttle
    should = DM.should_dispel(ctx, { tank_hp = 40, lowest_hp = 100 })
    assert(should == false, "Tank <50% should block dispel")

    -- Test 7: MAGE can dispel curse but not magic
    _G.EaxRotations = mock_NS(8)
    ok, mod = pcall(dofile, "EaxRotations/shared/dispel_manager_sylvanas.lua")
    if not ok or not mod then error("reload failed") end
    DM = mod
    assert(DM.can_dispel("curse") == true, "MAGE should dispel curse")
    assert(DM.can_dispel("magic") == false, "MAGE should not dispel magic")

    _G.EaxRotations = orig_NS
    print("PASS: dispel_manager tests")
end

run_test()
