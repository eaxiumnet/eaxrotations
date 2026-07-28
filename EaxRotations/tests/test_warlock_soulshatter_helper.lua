-- test_warlock_soulshatter_helper.lua — Unit tests for warlock_soulshatter_sylvanas.
-- WHAT:  verifies threat/aggro gating and pure-API cooldown/ready checks of the
--        Soulshatter helper.
-- WHEN:  runs as part of the rotation test suite.
-- WHY:   regression guard for the shared helper used by warlock middleware.
-- SAFETY: pure mocked tests; no game API calls; no hardcoded timers.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false, assert_eq

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
end
setup_asserts()

-- ============================================================================
-- Mocks and module load
-- ============================================================================
local spell_ready_calls = {}
local try_cast_calls = {}

local mock_spec_kit = {
    setting_bool = function(context, key, default)
        if context and context.settings and context.settings[key] ~= nil then
            return context.settings[key]
        end
        return default
    end,
    setting_number = function(context, key, default)
        if context and context.settings and type(context.settings[key]) == "number" then
            return context.settings[key]
        end
        return default
    end,
}

_G.EaxRotations = {
    GetPlayer = function() return { name = "Player" } end,
    PLAYER_UNIT = { name = "Player" },
    cooldown_remains = function(spell_obj)
        return 0
    end,
    spell_ready = function(spell_obj, target, opts)
        table.insert(spell_ready_calls, { spell = spell_obj, target = target, opts = opts })
        return true
    end,
    try_cast = function(spell_obj, target, label, opts)
        table.insert(try_cast_calls, { spell = spell_obj, target = target, label = label, opts = opts })
        return true
    end,
}

package.loaded["shared/spec_kit_sylvanas"] = mock_spec_kit

local soulshatter_helper = require("shared/warlock_soulshatter_sylvanas")

local SPELL_OBJ = { id = { 29858 }, name = "Soulshatter" }

-- ============================================================================
-- Stub helper: restores NS field even if the body asserts fail
-- ============================================================================
local function with_stub(ns_key, stub_fn, body)
    local original = _G.EaxRotations[ns_key]
    _G.EaxRotations[ns_key] = stub_fn
    local ok, err = pcall(body)
    _G.EaxRotations[ns_key] = original
    if not ok then error(err, 2) end
end

-- ============================================================================
-- Test helpers
-- ============================================================================
local function base_context(overrides)
    local ctx = {
        in_combat = true,
        threat_pct = 80,
        has_aggro = false,
        settings = {},
    }
    if overrides then
        for k, v in pairs(overrides) do ctx[k] = v end
    end
    return ctx
end

-- ============================================================================
-- Nil-context safety
-- ============================================================================
assert_false(soulshatter_helper.matches(nil, SPELL_OBJ), "matches should return false when context is nil")

-- ============================================================================
-- Setting gate: use_threat_drop = false blocks the cast
-- ============================================================================
spell_ready_calls = {}
cooldown_calls = {}
local ctx_disabled = base_context({ settings = { use_threat_drop = false } })
assert_false(soulshatter_helper.matches(ctx_disabled, SPELL_OBJ), "matches should return false when use_threat_drop is disabled")

-- ============================================================================
-- Combat gate: out of combat blocks the cast
-- ============================================================================
local ctx_ooc = base_context({ in_combat = false })
assert_false(soulshatter_helper.matches(ctx_ooc, SPELL_OBJ), "matches should return false when not in combat")

-- ============================================================================
-- Threat gating: low threat and no aggro blocks the cast
-- ============================================================================
local ctx_low_threat = base_context({ threat_pct = 50, has_aggro = false })
assert_false(soulshatter_helper.matches(ctx_low_threat, SPELL_OBJ), "matches should return false when threat_pct < 80 and not has_aggro")

-- ============================================================================
-- Threat gating: high threat permits the cast
-- ============================================================================
spell_ready_calls = {}
cooldown_calls = {}
local ctx_high_threat = base_context({ threat_pct = 80 })
assert_true(soulshatter_helper.matches(ctx_high_threat, SPELL_OBJ), "matches should return true when threat_pct >= 80")
assert_true(#spell_ready_calls > 0, "spell_ready should be consulted when threat gate passes")

-- ============================================================================
-- Threat gating: aggro permits the cast even with low threat
-- ============================================================================
spell_ready_calls = {}
cooldown_calls = {}
local ctx_aggro = base_context({ threat_pct = 30, has_aggro = true })
assert_true(soulshatter_helper.matches(ctx_aggro, SPELL_OBJ), "matches should return true when has_aggro even with low threat_pct")

-- ============================================================================
-- Cooldown gating: if Soulshatter is on cooldown, cast is blocked
-- ============================================================================
spell_ready_calls = {}
cooldown_calls = {}
with_stub("cooldown_remains", function() return 5 end, function()
    local ctx_cooldown = base_context({ threat_pct = 95 })
    assert_false(soulshatter_helper.matches(ctx_cooldown, SPELL_OBJ), "matches should return false when cooldown_remains is positive")
end)

-- ============================================================================
-- Ready gating: if spell is not ready, cast is blocked
-- ============================================================================
with_stub("spell_ready", function() return false end, function()
    local ctx_ready = base_context({ threat_pct = 95 })
    assert_false(soulshatter_helper.matches(ctx_ready, SPELL_OBJ), "matches should return false when spell_ready returns false")
end)

-- ============================================================================
-- Execute success path
-- ============================================================================
try_cast_calls = {}
local exec_ok = soulshatter_helper.execute({}, SPELL_OBJ, "[TEST] Soulshatter")
assert_true(exec_ok, "execute should return true when try_cast succeeds")
assert_eq(#try_cast_calls, 1, "execute should call try_cast exactly once")
assert_eq(try_cast_calls[1].label, "[TEST] Soulshatter", "execute should pass the label through to try_cast")
assert_eq(try_cast_calls[1].opts.skip_range, true, "execute should pass skip_range=true to try_cast")

-- ============================================================================
-- Execute default label
-- ============================================================================
try_cast_calls = {}
soulshatter_helper.execute({}, SPELL_OBJ)
assert_eq(try_cast_calls[1].label, "[WARLOCK] Soulshatter", "execute should use the default label when label is omitted")

-- ============================================================================
-- Execute returns false when try_cast fails
-- ============================================================================
with_stub("try_cast", function() return false end, function()
    local exec_false = soulshatter_helper.execute({}, SPELL_OBJ, "[TEST] Fails")
    assert_false(exec_false, "execute should return false when try_cast returns false")
end)

-- ============================================================================
-- make_strategy factory wires matches/execute correctly
-- ============================================================================
local strat = soulshatter_helper.make_strategy("SoulshatterTest", SPELL_OBJ, "[TEST] Strategy Soulshatter")
assert_true(strat and strat.name == "SoulshatterTest", "make_strategy should return a strategy with the requested name")
assert_false(strat.matches(ctx_disabled), "strategy produced by make_strategy should respect the use_threat_drop setting")
assert_true(strat.matches(ctx_high_threat), "strategy produced by make_strategy should match when gates pass")
try_cast_calls = {}
strat.execute({})
assert_eq(#try_cast_calls, 1, "strategy execute should call try_cast")
assert_eq(try_cast_calls[1].label, "[TEST] Strategy Soulshatter", "strategy execute should pass the label through")

print("PASS test_warlock_soulshatter_helper")
