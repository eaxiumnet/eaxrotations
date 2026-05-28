-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_balance_faerie_fire.lua"
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
--[[
test_balance_faerie_fire.lua — FrostByte Gap Coverage
Verifies: Faerie Fire auto-application on cooldown
Pattern: Custom matches function via strategy closure
]]

-- Helper: assert wrapper with label
local function assert_true(cond, label)
    if not cond then
        error("FAIL: " .. label, 2)
    end
end
local function assert_false(cond, label)
    if cond then
        error("FAIL: " .. label, 2)
    end
end

-- Minimal NS mocks
_G.EaxRotations = {
    DruidSpells = {},
    SPF_NAMES = {},
    debuff_remains = function(spell_id, unit)
        local mock_ff = _G.EaxRotations._mock_ff_remains or 0
        if spell_id == "FaerieFire" then
            return mock_ff
        end
        return 0
    end,
    spell_ready = function(spell, unit)
        return true
    end,
    action_matches = function(context, action)
        return true
    end,
    spell_action = function(spell_id, name)
        return { spell = spell_id, name = name or "unknown" }
    end,
    has_player_buff = function(buff_id)
        return false
    end,
    log = function(msg) end,
    rotation_registry = {
        register = function(strategies)
            _G.EaxRotations._registered = strategies
        end
    },
}

-- Load spec
package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path
local result = dofile("EaxRotations/classes/druid/balance_sylvanas.lua")

assert_true(type(result) == "table", "dofile returns a table")
assert_true(type(result.strategies) == "table", "result.strategies is a table")

-- Find FaerieFire strategy (name is FaerieFireDebuff in this spec)
local ff_strategy
for k, v in pairs(result.strategies) do
    if type(v) == "table" and (v.name == "FaerieFireDebuff" or v.name == "FaerieFire") then
        ff_strategy = v
        break
    end
end

assert_true(ff_strategy ~= nil, "FaerieFireDebuff/FaerieFire strategy exists")
assert_true(type(ff_strategy.matches) == "function", "FaerieFire has matches function")

-- Test cases
local function make_context(target_hp, has_feral)
    return {
        target = { get_health_percentage = function() return target_hp or 100 end },
        target_hp = target_hp or 100,
        has_feral_druid = has_feral or false,
        has_valid_enemy_target = true,
    }
end

-- Build state helper: test passes state properly into matches(context, state)
local function make_state(ff_remains)
    return { ff_remains = ff_remains or 0 }
end

-- Test: Faerie Fire should match when debuff is about to expire (remains <= 5)
local function test_matches_when_ff_expiring()
    local ctx = make_context(100)
    local state = make_state(3)
    assert_true(ff_strategy.matches(ctx, state), "FaerieFire matches when ff_remains <= 5")
end

-- Test: Faerie Fire should NOT match when debuff has plenty of time (remains > 5)
local function test_does_not_match_when_ff_fresh()
    local ctx = make_context(100)
    local state = make_state(10)
    assert_false(ff_strategy.matches(ctx, state), "FaerieFire does NOT match when ff_remains > 5")
end

-- Test: Faerie Fire should match at boundary (remains = 5)
local function test_matches_at_boundary()
    local ctx = make_context(100)
    local state = make_state(5)
    assert_true(ff_strategy.matches(ctx, state), "FaerieFire matches when ff_remains == 5 (boundary)")
end

-- Test: Faerie Fire should match when debuff has fallen off (remains = 0)
local function test_matches_when_ff_expired()
    local ctx = make_context(100)
    local state = make_state(0)
    assert_true(ff_strategy.matches(ctx, state), "FaerieFire matches when ff_remains == 0 (expired)")
end

-- Test: Faerie Fire should NOT match when there is a feral druid in group
local function test_does_not_match_with_feral()
    local ctx = make_context(100, true)
    local state = make_state(0)
    assert_false(ff_strategy.matches(ctx, state), "FaerieFire does NOT match when has_feral_druid is true")
end

-- Test: Faerie Fire should not match when no target
local function test_does_not_match_no_target()
    local ctx = {}
    local state = make_state(0)
    assert_false(ff_strategy.matches(ctx, state), "FaerieFire does NOT match with no target")
end

-- Test: Faerie Fire should match when remains is just barely expired (remains = -1, e.g. on pull)
local function test_matches_when_ff_just_expired()
    local ctx = make_context(100)
    local state = make_state(-1)
    assert_true(ff_strategy.matches(ctx, state), "FaerieFire matches when ff_remains == -1 (just expired)")
end

-- Run all tests
local all_passed = true
local failures = {}

local tests = {
    test_matches_when_ff_expiring = test_matches_when_ff_expiring,
    test_does_not_match_when_ff_fresh = test_does_not_match_when_ff_fresh,
    test_matches_at_boundary = test_matches_at_boundary,
    test_matches_when_ff_expired = test_matches_when_ff_expired,
    test_does_not_match_with_feral = test_does_not_match_with_feral,
    test_does_not_match_no_target = test_does_not_match_no_target,
    test_matches_when_ff_just_expired = test_matches_when_ff_just_expired,
}

for name, fn in pairs(tests) do
    local ok, err = pcall(fn)
    if not ok then
        all_passed = false
        table.insert(failures, name .. ": " .. tostring(err))
    end
end

if all_passed then
    print("All Faerie Fire tests PASSED")
else
    print("Some Faerie Fire tests FAILED:")
    for _, f in ipairs(failures) do
        print("  " .. f)
    end
    os.exit(1)
end
