-- test_interrupt_manager.lua -- manager tests.
-- WHAT:  manager tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- interrupt manager strategy matching regression test.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Load the interrupt manager (depends on NS global)
local NS = {
    try_interrupt = function(target) return true end,
    spell_ready = function(spell, target, opts) return true end,
    gcd_remains = function() return 0 end,
    can_attack_target = function() return true end,
    GetPlayer = function() return { is_casting = function() return false end, is_channeling = function() return false end } end,
    try_cast = function(spell, target, reason, opts) return true end,
    safe_field = function(obj, key)
        if not obj then return nil end
        local ok, val = pcall(function() return obj[key] end)
        return ok and val or nil
    end,
    unit_alive = function(unit) return true end,
    player_control_locked = function() return false end,
}
_G.EaxRotations = NS

dofile("EaxRotations/shared/interrupt_manager_sylvanas.lua")

local M = _G.EaxInterruptManager
assert_true(M ~= nil, "InterruptManager should be loaded")

-- Backward-compat override: tests that don't explicitly set interrupt_humanize_enabled
-- pass through immediately so existing strategy matching tests aren't broken.
local orig_humanize = M.humanize_interrupt_elapsed
M.humanize_interrupt_elapsed = function(target, settings)
    if not settings or settings.interrupt_humanize_enabled == nil then
        return true
    end
    return orig_humanize(target, settings)
end

-- Test priority scoring
assert_eq(M.interrupt_priority(2054), 4, "heal cast priority should be 4")
assert_eq(M.interrupt_priority(118), 3, "CC cast priority should be 3")
assert_eq(M.interrupt_priority(686), 2, "damage cast priority should be 2")
assert_eq(M.interrupt_priority(99999), 1, "unknown cast priority should be 1")
assert_eq(M.interrupt_priority(nil), 1, "nil cast priority should be 1")

-- Test cast_has_interrupt_window
-- Target at 30% cast, default threshold 50% => should interrupt (30 < 50)
local mock_target_30 = {
    get_casting_percent = function() return 30 end,
}
assert_true(M.cast_has_interrupt_window(mock_target_30, {}),
    "should interrupt when cast at 30% with 50% threshold")

-- Target at 60% cast, default threshold 50% => should NOT interrupt (60 >= 50)
local mock_target_60 = {
    get_casting_percent = function() return 60 end,
}
assert_false(M.cast_has_interrupt_window(mock_target_60, {}),
    "should NOT interrupt when cast at 60% with 50% threshold")

-- Target with no casting percent method => should interrupt (safe default)
local mock_target_no_cast = {}
assert_true(M.cast_has_interrupt_window(mock_target_no_cast, {}),
    "should interrupt when casting percent is unknown")

-- Custom threshold: 80%
-- With 80% threshold, 60% cast progress is still below threshold => should interrupt
assert_true(M.cast_has_interrupt_window(mock_target_60, {interrupt_cast_percent = 80}),
    "should interrupt when cast at 60% with 80% threshold (60 < 80)")
-- 30% is also below 80% threshold => should interrupt
assert_true(M.cast_has_interrupt_window(mock_target_30, {interrupt_cast_percent = 80}),
    "should interrupt when cast at 30% with 80% threshold")

-- Test create_interrupt_strategy matching conditions
local mock_spell = {id = 2139, _meta = {id = 2139}}  -- Counterspell
local mock_target_casting = {
    get_casting_spell_id = function() return 2054 end,
    get_casting_percent = function() return 30 end,
}
local mock_target_not_casting = {
    get_casting_spell_id = function() return nil end,
    get_casting_percent = function() return nil end,
}

local strategy = M.create_interrupt_strategy(
    {spell = mock_spell, class_key = "mage"},
    nil  -- no extra target validator
)

-- Case 1: Target is casting, spell ready, no GCD, player can act => should match
local ctx1 = {
    me = {is_casting = function() return false end, is_channeling = function() return false end},
    target = mock_target_casting,
    settings = {use_interrupts = true},
    gcd_remains = 0,
    in_combat = true,
}
-- Override NS.try_interrupt to return true for our mock target
local try_interrupt_called = false
NS.try_interrupt = function(target)
    try_interrupt_called = true
    return target == mock_target_casting
end
NS.spell_ready = function(spell, target, opts) return true end

local match1 = strategy.matches(ctx1)
assert_true(match1, "strategy should match when target is casting and spell is ready")
assert_true(try_interrupt_called, "try_interrupt should have been called")

-- Case 2: Target NOT casting => should NOT match
try_interrupt_called = false
local ctx2 = {
    me = {is_casting = function() return false end, is_channeling = function() return false end},
    target = mock_target_not_casting,
    settings = {use_interrupts = true},
    gcd_remains = 0,
    in_combat = true,
}
local match2 = strategy.matches(ctx2)
assert_false(match2, "strategy should NOT match when target is not casting")

-- Case 3: GCD active => should NOT match
NS.gcd_remains = function() return 1.5 end
local ctx3 = {
    me = {is_casting = function() return false end, is_channeling = function() return false end},
    target = mock_target_casting,
    settings = {use_interrupts = true},
    gcd_remains = 1.5,
    in_combat = true,
}
local match3 = strategy.matches(ctx3)
assert_false(match3, "strategy should NOT match when GCD is active")

-- Case 4: use_interrupts disabled => should NOT match
local ctx4 = {
    me = {is_casting = function() return false end, is_channeling = function() return false end},
    target = mock_target_casting,
    settings = {use_interrupts = false},
    gcd_remains = 0,
    in_combat = true,
}
local match4 = strategy.matches(ctx4)
assert_false(match4, "strategy should NOT match when use_interrupts is false")

-- Case 5: Player is casting => should NOT match
local ctx5 = {
    me = {is_casting = function() return true end, is_channeling = function() return false end},
    target = mock_target_casting,
    settings = {use_interrupts = true},
    gcd_remains = 0,
    in_combat = true,
}
local match5 = strategy.matches(ctx5)
assert_false(match5, "strategy should NOT match when player is casting")

-- Case 6: Spell not ready => should NOT match
NS.try_interrupt = function(target) return true end
NS.spell_ready = function(spell, target, opts) return false end
local ctx6 = {
    me = {is_casting = function() return false end, is_channeling = function() return false end},
    target = mock_target_casting,
    settings = {use_interrupts = true},
    gcd_remains = 0,
    in_combat = true,
}
local match6 = strategy.matches(ctx6)
assert_false(match6, "strategy should NOT match when spell is not ready")

-- Reset GCD state for subsequent tests
NS.gcd_remains = function() return 0 end

-- Case 7: nil settings defaults to interrupts enabled
local ctx7 = {
    me = {is_casting = function() return false end, is_channeling = function() return false end},
    target = mock_target_casting,
    settings = {},
    gcd_remains = 0,
    in_combat = true,
}
NS.spell_ready = function(spell, target, opts) return true end
local match7 = strategy.matches(ctx7)
assert_true(match7, "strategy should match with nil/empty settings (interrupts default on)")

-- ============================================================================
-- Humanization Tests
-- ============================================================================

NS.time_now = function() return 0 end

local mock_target_cast = {
    get_active_spell_id = function() return 118 end,
    is_channeling = function() return false end,
}

local mock_target_channel = {
    get_active_spell_id = function() return 5143 end,
    is_channeling = function() return true end,
}

-- Test: disabled humanization passes immediately
assert_true(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = false}), "humanize disabled should return true immediately")

-- Test: first regular cast is delayed (use min=1 to guarantee non-zero jitter)
M.humanize_cleanup(999)
NS.time_now = function() return 0 end
assert_false(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "first cast should be delayed (humanize not elapsed)")

-- Test: after 1s, same cast is no longer delayed (reuses jitter from cache)
NS.time_now = function() return 1 end
assert_true(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "after 1s humanize should be elapsed for same cast")

-- Test: channel uses different (longer) delay range
M.humanize_cleanup(999)
NS.time_now = function() return 10 end
assert_false(M.humanize_interrupt_elapsed(mock_target_channel, {interrupt_humanize_enabled = true}), "first channel should be delayed")
NS.time_now = function() return 11 end
assert_true(M.humanize_interrupt_elapsed(mock_target_channel, {interrupt_humanize_enabled = true}), "after 1s channel humanize should be elapsed")

-- Test: same spell within 5-second window reuses cached jitter
M.humanize_cleanup(999)
NS.time_now = function() return 20 end
assert_false(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "create cache entry for reuse test")
NS.time_now = function() return 24 end
assert_true(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "same spell within 5s should reuse jitter")

-- Test: same spell after 6s (>5s window) is treated as new cast
NS.time_now = function() return 26 end
assert_false(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "same spell after 6s should be treated as new cast")

-- Test: cleanup removes stale entries
M.humanize_cleanup(999)
NS.time_now = function() return 0 end
assert_false(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "create entry for cleanup test")
NS.time_now = function() return 20 end
M.humanize_cleanup(20)
assert_false(M.humanize_interrupt_elapsed(mock_target_cast, {interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1}), "after cleanup stale entries should be removed, treating as new cast")

-- Test: max < min guard clamps jitter to min
M.humanize_cleanup(999)
NS.time_now = function() return 0 end
local guard_settings = {
    interrupt_humanize_enabled = true,
    interrupt_cast_jitter_min = 5,
    interrupt_cast_jitter_max = 2,
}
assert_false(M.humanize_interrupt_elapsed(mock_target_cast, guard_settings), "guard: max < min should still delay (clamped to min)")
NS.time_now = function() return 1 end
assert_true(M.humanize_interrupt_elapsed(mock_target_cast, guard_settings), "guard: after 1s with clamped min should be elapsed")

-- ============================================================================
-- Public API coverage: spell_interrupt_priority, register_interrupt_spell, execute
-- ============================================================================

-- spell_interrupt_priority: known heal/CC/damage map + fallback to interrupt_priority
assert_eq(M.spell_interrupt_priority(2060), 10, "Greater Heal should be priority 10")
assert_eq(M.spell_interrupt_priority(118), 9, "Polymorph should be priority 9")
assert_eq(M.spell_interrupt_priority(133), 8, "Fireball should be priority 8")
assert_eq(M.spell_interrupt_priority(99999), 1, "unknown spell falls back to interrupt_priority=1")
assert_eq(M.spell_interrupt_priority(nil), 1, "nil spell_interrupt_priority is 1")

-- register_interrupt_spell: builds a strategy from class spell table
local spells = { Counterspell = mock_spell }
local reg = M.register_interrupt_spell("mage", "Counterspell", spells)
assert_true(type(reg) == "table", "register_interrupt_spell returns strategy table")
assert_eq(reg.name, "Interrupt", "registered strategy name is Interrupt")
assert_true(type(reg.matches) == "function", "registered strategy has matches")
assert_true(type(reg.execute) == "function", "registered strategy has execute")

-- register_interrupt_spell with missing spell uses FALLBACK_IDS via NS.spell_action
NS.spell_action = function(ids, name)
    return { id = ids[1], _meta = { id = ids[1] }, name = name }
end
local empty_spells = {}
local reg_fallback = M.register_interrupt_spell("mage", "Counterspell", empty_spells)
assert_true(type(reg_fallback) == "table", "fallback register returns strategy")
assert_true(empty_spells.Counterspell ~= nil, "fallback injects spell into spell table")

-- strategy execute: casts and records school lock
NS.try_interrupt = function() return true end
NS.spell_ready = function() return true end
NS.gcd_remains = function() return 0 end
local cast_called = false
local cast_spell, cast_target
NS.try_cast = function(spell, target, reason, opts)
    cast_called = true
    cast_spell = spell
    cast_target = target
    return true
end
M.clear_school_locks()
local exec_target = {
    get_active_spell_id = function() return 2054 end,
    get_casting_percent = function() return 30 end,
    get_guid = function() return "exec_guid" end,
}
local exec_ctx = {
    me = { is_casting = function() return false end, is_channeling = function() return false end },
    target = exec_target,
    settings = { use_interrupts = true, interrupt_humanize_enabled = false },
}
local exec_strategy = M.create_interrupt_strategy({ spell = mock_spell, class_key = "mage" })
assert_true(exec_strategy.matches(exec_ctx), "execute path: matches when casting")
assert_true(exec_strategy.execute(exec_ctx), "execute path: try_cast succeeds")
assert_true(cast_called, "execute path: try_cast was called")
assert_eq(cast_target, exec_target, "execute path: cast on interrupt target")
-- Counterspell (2139) locks the cast school (heal=holy via SPELL_SCHOOL_LOOKUP, else arcane default)
-- 2054 is Heal which is holy in SPELL_SCHOOL_LOOKUP
assert_true(M.is_school_locked(exec_target, "holy") or M.is_school_locked(exec_target, "arcane"),
    "execute path: school lock recorded after successful interrupt")

-- school_lock_remains: positive during window, 0 after expiry / missing
NS.time_now = function() return 100 end
M.clear_school_locks()
local lock_target = { get_guid = function() return "lock_remains_guid" end }
M.record_school_lock(lock_target, 1766) -- Kick: physical 5s
assert_true(M.school_lock_remains(lock_target, "physical") > 0, "school_lock_remains > 0 during lock")
assert_eq(M.school_lock_remains(lock_target, "frost"), 0, "school_lock_remains 0 for unlocked school")
NS.time_now = function() return 106 end
assert_eq(M.school_lock_remains(lock_target, "physical"), 0, "school_lock_remains 0 after expiry")
assert_eq(M.school_lock_remains(nil, "physical"), 0, "school_lock_remains nil target is 0")

print("PASS interrupt_manager")
