-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_leveling_shared.lua"
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
-- leveling shared unit tests.
-- Covers all 8 exported functions in shared/leveling_sylvanas.lua:
--   create_context_guard, execute_wand, create_wand_matches,
--   build_common_state, create_interrupt_matches, create_ooc_buff_matches,
--   dot_needs_refresh, create_aoe_matches

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_nil(v, label) if v ~= nil then error(label or "assert_nil failed: expected nil got " .. tostring(v), 2) end end

-- ============================================================================
-- Mock environment
-- ============================================================================

_G = _G or {}
_G.EaxRotations = {}
local NS = _G.EaxRotations

-- Mock core for wand execution
_G.core = {}
_G.core.input = {}
_G.core.input.cast_target_spell_called_with = nil
_G.core.input.cast_target_spell = function(spell_id, target)
    _G.core.input.cast_target_spell_called_with = { spell_id = spell_id, target = target }
    return true
end
NS.try_cast_called_with = nil
NS.try_cast = function(spell_id, target, reason)
    NS.try_cast_called_with = { spell_id = spell_id, target = target, reason = reason }
    return true
end

-- Mock spell_exists
NS.spell_exists = function(spell_id)
    -- Pretend wand (5019) is learned, everything else is not
    return spell_id == 5019
end

-- Mock debuff_remains
NS.debuff_remains = function(target, debuff_ids)
    if not target then return 0 end
    -- target.magic_remains controls mock response
    if target.magic_remains ~= nil then return target.magic_remains end
    return 0
end

-- ============================================================================
-- Load the shared module
-- ============================================================================

local leveling = dofile('EaxRotations/shared/leveling_sylvanas.lua')
assert_true(leveling ~= nil, "module should load successfully")
assert_true(leveling.create_context_guard ~= nil, "create_context_guard should exist")
assert_true(leveling.execute_wand ~= nil, "execute_wand should exist")
assert_true(leveling.create_wand_matches ~= nil, "create_wand_matches should exist")
assert_true(leveling.build_common_state ~= nil, "build_common_state should exist")
assert_true(leveling.create_interrupt_matches ~= nil, "create_interrupt_matches should exist")
assert_true(leveling.create_ooc_buff_matches ~= nil, "create_ooc_buff_matches should exist")
assert_true(leveling.dot_needs_refresh ~= nil, "dot_needs_refresh should exist")
assert_true(leveling.create_aoe_matches ~= nil, "create_aoe_matches should exist")

-- ============================================================================
-- Tests: create_context_guard
-- ============================================================================

do
    local guard = leveling.create_context_guard()
    assert_true(guard ~= nil, "guard function should be returned")

    -- Test 1: nil context returns false
    assert_false(guard(nil), "nil context should return false")

    -- Test 2: context.is_solo = true
    assert_true(guard({ is_solo = true }), "context.is_solo should return true")

    -- Test 3: context.is_leveling = true
    assert_true(guard({ is_leveling = true }), "context.is_leveling should return true")

    -- Test 4: settings.playstyle = "leveling"
    assert_true(guard({ settings = { playstyle = "leveling" } }), "settings.playstyle=leveling should return true")

    -- Test 5: settings.active_playstyle = "leveling"
    assert_true(guard({ settings = { active_playstyle = "leveling" } }), "settings.active_playstyle=leveling should return true")

    -- Test 6: Neither solo nor leveling
    assert_false(guard({ settings = { playstyle = "arcane" } }), "non-leveling playstyle should return false")
    assert_false(guard({}), "empty context should return false")

    print("PASS create_context_guard")
end

-- ============================================================================
-- Tests: execute_wand
-- ============================================================================

do
    -- Reset mock tracker
    _G.core.input.cast_target_spell_called_with = nil

    -- Test 7: nil context returns false
    assert_false(leveling.execute_wand(nil), "nil context should return false")

    -- Test 8: context without target returns false
    assert_false(leveling.execute_wand({}), "no target should return false")

    -- Test 9: happy path - routes Shoot through guarded try_cast with wand ID
    local mock_target = { guid = "mock-1" }
    local result = leveling.execute_wand({ target = mock_target })
    assert_true(result, "execution should return true")
    assert_nil(_G.core.input.cast_target_spell_called_with, "raw cast_target_spell should not be called")
    assert_true(NS.try_cast_called_with ~= nil, "try_cast should have been called")
    assert_eq(NS.try_cast_called_with.spell_id, 5019, "should cast spell 5019 (Shoot)")
    assert_true(NS.try_cast_called_with.target == mock_target, "should pass target")

    print("PASS execute_wand")
end

-- ============================================================================
-- Tests: create_wand_matches
-- ============================================================================

do
    local wand_matches = leveling.create_wand_matches()
    assert_true(wand_matches ~= nil, "wand matches function should be returned")

    -- Gotta pass through build_common_state to populate required state fields.
    -- We'll construct state manually for targeted tests.

    -- Test 10: nil context returns false
    assert_false(wand_matches(nil, {}), "nil context should return false")

    -- Test 11: no target returns false
    assert_false(wand_matches({ target = nil }, { wand_learned = true, in_combat = true, mana_pct = 10, wand_threshold = 30 }), "no target should return false")

    -- Test 12: wand not learned returns false
    assert_false(wand_matches({ target = {} }, { wand_learned = false, in_combat = true, mana_pct = 10, wand_threshold = 30 }), "wand not learned should return false")

    -- Test 13: not in combat returns false
    assert_false(wand_matches({ target = {} }, { wand_learned = true, in_combat = false, mana_pct = 10, wand_threshold = 30 }), "not in combat should return false")

    -- Test 14: mana above threshold returns false
    assert_false(wand_matches({ target = {} }, { wand_learned = true, in_combat = true, mana_pct = 50, wand_threshold = 30 }), "mana above threshold should return false")

    -- Test 15: mana at threshold returns false (>= threshold)
    assert_false(wand_matches({ target = {} }, { wand_learned = true, in_combat = true, mana_pct = 30, wand_threshold = 30 }), "mana at threshold should return false")

    -- Test 16: all conditions met returns true
    assert_true(wand_matches({ target = {} }, { wand_learned = true, in_combat = true, mana_pct = 20, wand_threshold = 30 }), "all conditions met should return true")

    -- Test 17: custom threshold key and default value
    local custom_wand = leveling.create_wand_matches("custom_key", 50)
    -- With state not having wand_threshold, should use default 50
    assert_false(custom_wand({ target = {} }, { wand_learned = true, in_combat = true, mana_pct = 50 }), "custom default threshold 50 should be used")
    assert_true(custom_wand({ target = {} }, { wand_learned = true, in_combat = true, mana_pct = 40 }), "mana 40 < default 50 should return true")

    print("PASS create_wand_matches")
end

-- ============================================================================
-- Tests: build_common_state
-- ============================================================================

do
    -- Test 18: builds state correctly from context
    local context = {
        in_combat = true,
        mana_pct = 65,
        hp = 80,
        enemies_count = 2,
        target = { guid = "t1" },
        is_moving = false,
        pet = { guid = "p1" },
        settings = {
            use_interrupt = true,
        },
    }
    local state = {}
    local result = leveling.build_common_state(context, state)
    assert_true(result == state, "should return same state table for chaining")
    assert_eq(state.in_combat, true, "should set in_combat")
    assert_eq(state.mana_pct, 65, "should set mana_pct")
    assert_eq(state.hp, 80, "should set hp")
    assert_eq(state.enemies, 2, "should set enemies count")
    assert_eq(state.target, context.target, "should set target")
    assert_eq(state.is_moving, false, "should set is_moving (not moving)")
    assert_eq(state.pet, context.pet, "should set pet")
    assert_true(state.wand_learned, "wand_learned should be true (5019 is mocked as learned)")
    assert_eq(state.use_interrupt, true, "should set use_interrupt from settings")

    -- Test 19: defaults when context fields are missing
    local empty_state = leveling.build_common_state({ settings = {} }, {})
    assert_eq(empty_state.in_combat, false, "missing in_combat defaults to false")
    assert_eq(empty_state.mana_pct, 100, "missing mana_pct defaults to 100")
    assert_eq(empty_state.hp, 100, "missing hp defaults to 100")
    assert_eq(empty_state.enemies, 0, "missing enemies defaults to 0")
    assert_eq(empty_state.is_moving, false, "missing is_moving defaults to false")

    -- Test 20: use_interrupt defaults to true when setting not present
    local no_interrupt_setting = leveling.build_common_state({ settings = {} }, {})
    assert_eq(no_interrupt_setting.use_interrupt, true, "use_interrupt should default to true")

    print("PASS build_common_state")
end

-- ============================================================================
-- Tests: create_interrupt_matches
-- ============================================================================

do
    local interrupt_matches = leveling.create_interrupt_matches("kick_ready")
    assert_true(interrupt_matches ~= nil, "interrupt matches function should be returned")

    -- Helper to create a target with is_casting ability
    local function make_target(is_casting_val)
        return { is_casting = function() return is_casting_val end }
    end

    local base_state = {
        target = make_target(true),
        use_interrupt = true,
        kick_ready = true,
    }

    -- Test 21: nil context returns false
    assert_false(interrupt_matches(nil, base_state), "nil context should return false")

    -- Test 22: no target in state returns false
    assert_false(interrupt_matches({}, { use_interrupt = true, kick_ready = true }), "no target should return false")

    -- Test 23: use_interrupt disabled returns false
    assert_false(interrupt_matches({}, { target = make_target(true), use_interrupt = false, kick_ready = true }), "interrupt disabled should return false")

    -- Test 24: spell not ready returns false
    assert_false(interrupt_matches({}, { target = make_target(true), use_interrupt = true, kick_ready = false }), "spell not ready should return false")

    -- Test 25: target not casting returns false
    assert_false(interrupt_matches({}, { target = make_target(false), use_interrupt = true, kick_ready = true }), "target not casting should return false")

    -- Test 26: all conditions met returns true
    assert_true(interrupt_matches({}, base_state), "all interrupt conditions met should return true")

    -- Test 27: is_casting pcall safety - throws nil handled gracefully
    local bad_target = { is_casting = function() error("oops") end }
    assert_false(interrupt_matches({}, { target = bad_target, use_interrupt = true, kick_ready = true }), "is_casting error should be caught and return false")

    print("PASS create_interrupt_matches")
end

-- ============================================================================
-- Tests: create_ooc_buff_matches
-- ============================================================================

do
    local ooc_buff = leveling.create_ooc_buff_matches("has_mark", "mark_ready")
    assert_true(ooc_buff ~= nil, "ooc buff matches function should be returned")

    -- Test 28: nil context returns false
    assert_false(ooc_buff(nil, {}), "nil context should return false")

    -- Test 29: in combat returns false
    assert_false(ooc_buff({}, { in_combat = true, has_mark = false, mark_ready = true }), "in combat should return false")

    -- Test 30: buff already active returns false
    assert_false(ooc_buff({}, { in_combat = false, has_mark = true, mark_ready = true }), "buff already active should return false")

    -- Test 31: spell not ready returns false
    assert_false(ooc_buff({}, { in_combat = false, has_mark = false, mark_ready = false }), "spell not ready should return false")

    -- Test 32: all conditions met returns true
    assert_true(ooc_buff({}, { in_combat = false, has_mark = false, mark_ready = true }), "all OOC buff conditions met should return true")

    print("PASS create_ooc_buff_matches")
end

-- ============================================================================
-- Tests: dot_needs_refresh
-- ============================================================================

do
    -- Test 33: nil target returns false
    assert_false(leveling.dot_needs_refresh(nil, {100}), "nil target should return false")

    -- Test 34: debuff remains 0 (expired) - needs refresh
    local target1 = { magic_remains = 0 }
    assert_true(leveling.dot_needs_refresh(target1, {100}), "expired debuff should need refresh")

    -- Test 35: debuff remains 2, default refresh threshold 4 - needs refresh
    local target2 = { magic_remains = 2 }
    assert_true(leveling.dot_needs_refresh(target2, {100}), "2s remains < 4s threshold should need refresh")

    -- Test 36: debuff remains 5, default refresh threshold 4 - does NOT need refresh
    local target3 = { magic_remains = 5 }
    assert_false(leveling.dot_needs_refresh(target3, {100}), "5s remains > 4s threshold should not need refresh")

    -- Test 37: custom refresh threshold
    local target4 = { magic_remains = 3 }
    assert_true(leveling.dot_needs_refresh(target4, {100}, 5), "3s remains < 5s custom threshold should need refresh")

    -- Test 38: debuff remains exactly at threshold (<=)
    local target5 = { magic_remains = 4 }
    assert_true(leveling.dot_needs_refresh(target5, {100}, 4), "remains equals threshold should need refresh (<=)")

    print("PASS dot_needs_refresh")
end

-- ============================================================================
-- Tests: create_aoe_matches
-- ============================================================================

do
    local aoe_matches = leveling.create_aoe_matches()  -- default threshold 3
    assert_true(aoe_matches ~= nil, "aoe matches function should be returned")

    -- Test 39: nil context returns false
    assert_false(aoe_matches(nil, {}), "nil context should return false")

    -- Test 40: no target returns false
    assert_false(aoe_matches({}, { target = nil, in_combat = true, enemies = 5 }), "no target should return false")

    -- Test 41: not in combat returns false
    assert_false(aoe_matches({}, { target = {}, in_combat = false, enemies = 5 }), "not in combat should return false")

    -- Test 42: below enemy threshold returns false
    assert_false(aoe_matches({}, { target = {}, in_combat = true, enemies = 2 }), "2 enemies < 3 threshold should return false")

    -- Test 43: moving returns false
    assert_false(aoe_matches({}, { target = {}, in_combat = true, enemies = 5, is_moving = true }), "moving should return false")

    -- Test 44: all conditions met returns true
    assert_true(aoe_matches({}, { target = {}, in_combat = true, enemies = 5 }), "5 enemies in combat not moving should return true")

    -- Test 45: custom minimum threshold
    local aoe_custom = leveling.create_aoe_matches(2)
    assert_true(aoe_custom({}, { target = {}, in_combat = true, enemies = 2 }), "2 enemies >= 2 custom threshold should return true")
    assert_false(aoe_custom({}, { target = {}, in_combat = true, enemies = 1 }), "1 enemy < 2 custom threshold should return false")

    print("PASS create_aoe_matches")
end

print("PASS test_leveling_shared")
