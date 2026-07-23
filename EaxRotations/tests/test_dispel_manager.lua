package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
-- test_dispel_manager.lua — Unit tests for dispel_manager_sylvanas.
-- WHAT:  Verify DispelManager can_dispel, throttle, should_dispel, create_dispel_strategy.
-- WHEN:  load-time verification.
-- WHY:   Prevent regression in auto-dispel logic for healer/hybrid classes.

local function mock_NS(class_id)
    return {
        log = function() end,
        GetPlayer = function()
            return {
                get_class = function() return class_id end,
            }
        end,
        time_now = function() return 0 end,
        is_spell_learned = function() return true end,
        try_cast = function() return true end,
        unit_health_pct = function() return 80 end,
        has_debuff = function() return false end,
    }
end

local function assert_true(v, msg)
    if not v then error(msg or "assert_true failed", 2) end
end

local function assert_false(v, msg)
    if v then error(msg or "assert_false failed", 2) end
end

local function assert_eq(a, b, msg)
    if a ~= b then error((msg or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end

local function load_dm(class_id)
    _G.EaxRotations = mock_NS(class_id)
    package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
        define_action_for_class = function() return function() end end,
        setting = function(_, _, d) return d end,
        setting_bool = function(_, _, d) return d end,
    }
    local ok, mod = pcall(dofile, "EaxRotations/shared/dispel_manager_sylvanas.lua")
    if not ok or not mod then
        error("Failed to load dispel_manager_sylvanas: " .. tostring(mod))
    end
    return mod
end

local function run_test()
    local orig_NS = _G.EaxRotations

    local DM = load_dm(5)
    assert_true(DM.can_dispel("magic"), "PRIEST should dispel magic")
    assert_true(DM.can_dispel("disease"), "PRIEST should dispel disease")
    assert_false(DM.can_dispel("curse"), "PRIEST should not dispel curse")
    assert_false(DM.can_dispel("poison"), "PRIEST should not dispel poison")
    local spell = DM.get_dispel_spell("magic")
    assert_true(type(spell) == "number" and spell > 0, "PRIEST magic spell is positive number")

    assert_false(DM.is_throttled(), "Fresh throttle should be false")
    DM.record_dispel()
    assert_true(DM.is_throttled(), "After record_dispel, should be throttled")

    local ctx = { settings = { auto_dispel = false } }
    local should = DM.should_dispel(ctx, {})
    assert_false(should, "auto_dispel=false should block")

    ctx = { settings = { auto_dispel = true } }
    should = DM.should_dispel(ctx, {})
    assert_false(should, "Throttled should block even with auto_dispel=true")

    local t = 0
    _G.EaxRotations.time_now = function() return t end
    DM.record_dispel()
    t = 10
    should = DM.should_dispel(ctx, { tank_hp = 40, lowest_hp = 100 })
    assert_false(should, "Tank <50% should block dispel")

    DM = load_dm(8)
    assert_true(DM.can_dispel("curse"), "MAGE should dispel curse")
    assert_false(DM.can_dispel("magic"), "MAGE should not dispel magic")

    DM = load_dm(2)
    assert_true(DM.can_dispel("poison"), "PALADIN should dispel poison")
    assert_true(DM.can_dispel("disease"), "PALADIN should dispel disease")
    assert_true(DM.can_dispel("magic"), "PALADIN should dispel magic")
    assert_false(DM.can_dispel("curse"), "PALADIN should not dispel curse")
    assert_eq(DM.get_dispel_spell("poison"), 4987, "PALADIN Cleanse id is 4987")

    DM = load_dm(7)
    assert_true(DM.can_dispel("poison"), "SHAMAN should dispel poison")
    assert_true(DM.can_dispel("disease"), "SHAMAN should dispel disease")
    assert_false(DM.can_dispel("magic"), "SHAMAN should not dispel magic")
    assert_eq(DM.get_dispel_spell("poison"), 526, "SHAMAN Cure Poison id is 526")
    assert_eq(DM.get_dispel_spell("disease"), 2870, "SHAMAN Cure Disease id is 2870")

    DM = load_dm(11)
    assert_true(DM.can_dispel("poison"), "DRUID should dispel poison")
    assert_true(DM.can_dispel("curse"), "DRUID should dispel curse")
    assert_false(DM.can_dispel("magic"), "DRUID should not dispel magic")
    assert_eq(DM.get_dispel_spell("curse"), 2782, "DRUID Remove Curse id is 2782")

    DM = load_dm(9)
    assert_true(DM.can_dispel("magic"), "WARLOCK should dispel magic")
    assert_false(DM.can_dispel("poison"), "WARLOCK should not dispel poison")

    DM = load_dm(5)
    local strat = DM.create_dispel_strategy({ name = "AutoDispel" })
    assert_true(type(strat) == "table", "create_dispel_strategy returns table")
    assert_eq(strat.name, "AutoDispel", "strategy name is AutoDispel")
    assert_true(type(strat.matches) == "function", "strategy has matches")
    assert_true(type(strat.execute) == "function", "strategy has execute")

    local me = {
        get_class = function() return 5 end,
        get_debuffs = function() return {} end,
    }
    _G.EaxRotations.GetPlayer = function() return me end
    _G.EaxRotations.time_now = function() return 50 end
    local no_debuff_ctx = {
        me = me,
        settings = { auto_dispel = true },
        party_members = {},
    }
    assert_false(strat.matches(no_debuff_ctx, { lowest_hp = 100, tank_hp = 100 }),
        "strategy should not match without dispellable debuffs")

    me.get_debuffs = function()
        return { { type = "magic", id = 118 } }
    end
    local cast_target, cast_spell
    _G.EaxRotations.try_cast = function(spell_id, target, reason)
        cast_spell = spell_id
        cast_target = target
        return true
    end
    assert_true(strat.matches(no_debuff_ctx, { lowest_hp = 100, tank_hp = 100 }),
        "strategy should match when self has magic debuff")
    assert_true(strat.execute(no_debuff_ctx), "execute_dispel should succeed")
    assert_eq(cast_target, me, "dispel cast on self")
    assert_true(type(cast_spell) == "number" and cast_spell > 0, "dispel cast uses spell id")
    assert_true(DM.is_throttled(), "execute records throttle")

    assert_false(DM.execute_dispel(nil, 988), "execute_dispel nil target fails")
    assert_false(DM.execute_dispel(me, nil), "execute_dispel nil spell fails")

    DM = load_dm(5)
    _G.EaxRotations.time_now = function() return 0 end
    me = {
        get_class = function() return 5 end,
        get_debuffs = function() return { { type = "magic" } } end,
    }
    _G.EaxRotations.GetPlayer = function() return me end
    local target, spell_id = DM.find_dispel_target({
        me = me,
        settings = { dispel_priority = "self" },
        party_members = {},
    }, {})
    assert_eq(target, me, "find_dispel_target self priority returns me")
    assert_true(type(spell_id) == "number", "find_dispel_target returns spell id")

    _G.EaxRotations = orig_NS
    print("PASS: dispel_manager tests")
end

run_test()
