-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_interrupt_manager.lua"
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

print("PASS interrupt_manager")
