-- Phase 2 interrupt spec integration tests.
-- Tests the InterruptManager integration patterns used by:
--   1. Warrior Protection (shield_bash_matches_fn)
--   2. Druid Bear (BashInterrupt)
--   3. Shaman Enhancement (should_interrupt_target)
--   4. Rogue Subtlety (kick_matches)
--
-- Key behaviors tested per spec:
--   - settings.use_interrupts == false gate
--   - InterruptManager path: try_interrupt + cast_has_interrupt_window + humanize_interrupt_elapsed
--   - Fallback path (IM nil): bare target_is_casting + target_casting_interruptible
--   - Cast window gating at various percentages
--   - Humanization delay behavior

local spec_kit = require("shared/spec_kit_sylvanas")
local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Global mocks
-- ============================================================================

local _G = _G
local call_log = {}  -- { im_path_called, fallback_path_called, try_interrupt_calls, window_calls, humanize_calls }

local function reset_call_log()
    call_log = { im_path_called = 0, fallback_path_called = 0, try_interrupt_calls = 0, window_calls = 0, humanize_calls = 0 }
end

-- Mock NS namespace
local NS = {
    try_interrupt = function(target)
        call_log.try_interrupt_calls = call_log.try_interrupt_calls + 1
        return target and target._is_casting or false
    end,
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
    time_now = function() return 0 end,
    log = function() end,
    get_setting = function() return false end,
    InterruptManager = nil,  -- set after loading IM
}
_G.EaxRotations = NS

-- Load InterruptManager
dofile("EaxRotations/shared/interrupt_manager_sylvanas.lua")
local M = _G.EaxInterruptManager
assert_true(M ~= nil, "InterruptManager should be loaded")

NS.InterruptManager = M

-- Override humanize for tests: default nil-enabled passes through
local orig_humanize = M.humanize_interrupt_elapsed
M.humanize_interrupt_elapsed = function(target, settings)
    if not settings or settings.interrupt_humanize_enabled == nil then
        return true
    end
    call_log.humanize_calls = call_log.humanize_calls + 1
    return orig_humanize(target, settings)
end

-- Override cast_has_interrupt_window to log calls
local orig_window = M.cast_has_interrupt_window
M.cast_has_interrupt_window = function(target, settings)
    call_log.window_calls = call_log.window_calls + 1
    return orig_window(target, settings)
end

-- ============================================================================
-- Helper: create mock target with various casting states
-- ============================================================================

local function mock_target(opts)
    opts = opts or {}
    local t = {
        _is_casting = opts.is_casting ~= false,
        get_casting_percent = function() return opts.cast_pct or nil end,
        get_casting_spell_id = function() return opts.cast_spell_id or 2054 end,
        get_active_spell_id = function() return opts.cast_spell_id or 2054 end,
        is_channeling = function() return opts.is_channeling or false end,
        is_casting = function() return opts.is_casting ~= false end,
        _interruptible = opts.interruptible ~= false,
    }
    return t
end

-- ============================================================================
-- Pattern 1: Warrior Protection (shield_bash_matches_fn)
-- Taken from EaxRotations/classes/warrior/protection_sylvanas.lua lines 288-306
-- ============================================================================

local function shield_bash_matches_pattern(context, state)
    if not spec_kit.setting_bool(context, "use_interrupts", true) then return false end
    local mgr = NS.InterruptManager
    local target = context.target
    if mgr then
        call_log.im_path_called = call_log.im_path_called + 1
        if not NS.try_interrupt(target) then return false end
        if not mgr.cast_has_interrupt_window(target, context.settings or {}) then return false end
        if not mgr.humanize_interrupt_elapsed(target, context.settings or {}) then return false end
    else
        call_log.fallback_path_called = call_log.fallback_path_called + 1
        if not state.target_is_casting then return false end
        if not (state.target_casting_interruptible or false) then return false end
    end
    if not state.shield_bash_ready then return false end
    if not state.defensive_stance then return false end
    return true
end

print("--- Warrior Protection: ShieldBash pattern ---")

-- Test 1: use_interrupts == false blocks everything
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = false }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { shield_bash_ready = true, defensive_stance = true, target_is_casting = true, target_casting_interruptible = true }
), "use_interrupts==false should block")
assert_eq(call_log.im_path_called, 0, "IM path should NOT be called when use_interrupts==false")
assert_eq(call_log.fallback_path_called, 0, "fallback path should NOT be called when use_interrupts==false")

-- Test 2: IM path with valid target (casting at 30%, should pass window)
reset_call_log()
assert_true(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { shield_bash_ready = true, defensive_stance = true }
), "valid interrupt with IM should match")
assert_eq(call_log.im_path_called, 1, "IM path should be called")
assert_eq(call_log.try_interrupt_calls, 1, "try_interrupt should be called once")
assert_eq(call_log.window_calls, 1, "cast_has_interrupt_window should be called once")

-- Test 3: IM path — target at 60% cast (above default 50% threshold) → blocked by window
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 60 }) },
    { shield_bash_ready = true, defensive_stance = true }
), "60% cast should be blocked by default 50% window")
assert_eq(call_log.im_path_called, 1, "IM path should be called (but window fails)")
assert_eq(call_log.window_calls, 1, "cast_has_interrupt_window should be called")

-- Test 4: IM path — target at 60% but custom 80% threshold → passes
reset_call_log()
assert_true(shield_bash_matches_pattern(
    { settings = { use_interrupts = true, interrupt_cast_percent = 80 }, target = mock_target({ is_casting = true, cast_pct = 60 }) },
    { shield_bash_ready = true, defensive_stance = true }
), "60% cast should pass with 80% threshold")
assert_eq(call_log.window_calls, 1, "cast_has_interrupt_window should be called")

-- Test 5b: Explicit humanize disabled → humanize passes through, call_log not incremented
reset_call_log()
assert_true(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { shield_bash_ready = true, defensive_stance = true }
), "without humanize_enabled, interrupt should match (humanize defaults to pass-through)")
assert_eq(call_log.humanize_calls, 0, "humanize should NOT be called when interrupt_humanize_enabled is nil (default pass-through)")

-- Test 6: IM path — target NOT casting → blocked by try_interrupt
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = false }) },
    { shield_bash_ready = true, defensive_stance = true }
), "non-casting target should be blocked by try_interrupt")
assert_eq(call_log.im_path_called, 1, "IM path entered")
assert_eq(call_log.try_interrupt_calls, 1, "try_interrupt should be called")

-- Test 6: IM path — humanization delay blocks first call, allows after delay
reset_call_log()
M.humanize_cleanup(999)
NS.time_now = function() return 0 end
local humanized_target = mock_target({ is_casting = true, cast_pct = 30, cast_spell_id = 118 })
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true, interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1 }, target = humanized_target },
    { shield_bash_ready = true, defensive_stance = true }
), "humanization should block first call")
assert_eq(call_log.humanize_calls, 1, "humanize should be called")

-- After 1 second, same spell should pass
reset_call_log()
NS.time_now = function() return 1 end
assert_true(shield_bash_matches_pattern(
    { settings = { use_interrupts = true, interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1 }, target = humanized_target },
    { shield_bash_ready = true, defensive_stance = true }
), "humanization should allow after 1s delay")
assert_eq(call_log.humanize_calls, 1, "humanize should be called")

-- Test 7: Fallback path — IM is nil, target casting + interruptible
reset_call_log()
NS.InterruptManager = nil
assert_true(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }) },
    { shield_bash_ready = true, defensive_stance = true, target_is_casting = true, target_casting_interruptible = true }
), "fallback: target casting + interruptible should match")
assert_eq(call_log.fallback_path_called, 1, "fallback path should be used when IM is nil")

-- Test 8: Fallback path — target casting but NOT interruptible
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }) },
    { shield_bash_ready = true, defensive_stance = true, target_is_casting = true, target_casting_interruptible = false }
), "fallback: target casting but not interruptible should NOT match")
assert_eq(call_log.fallback_path_called, 1, "fallback path entered but blocked by interruptible check")

-- Test 9: Fallback path — target NOT casting
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = false }) },
    { shield_bash_ready = true, defensive_stance = true, target_is_casting = false, target_casting_interruptible = true }
), "fallback: target not casting should NOT match")
assert_eq(call_log.fallback_path_called, 1, "fallback path entered but blocked by is_casting check")

-- Restore IM
NS.InterruptManager = M
M.humanize_cleanup(999)

-- Test 10: Spec-specific gates — shield_bash_ready == false
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { shield_bash_ready = false, defensive_stance = true }
), "shield_bash_ready==false should block even with valid interrupt")

-- Test 11: Spec-specific gates — not in defensive stance
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { shield_bash_ready = true, defensive_stance = false }
), "non-defensive stance should block even with valid interrupt")

-- ============================================================================
-- Pattern 2: Rogue Subtlety (kick_matches)
-- Taken from EaxRotations/classes/rogue/subtlety_sylvanas.lua lines 272-286
-- ============================================================================

local function kick_matches_pattern(context, state)
    if not spec_kit.setting_bool(context, "use_interrupts", true) then return false end
    local mgr = NS.InterruptManager
    if mgr then
        call_log.im_path_called = call_log.im_path_called + 1
        if not NS.try_interrupt(context.target) then return false end
        if not mgr.cast_has_interrupt_window(context.target, context.settings or {}) then return false end
        if not mgr.humanize_interrupt_elapsed(context.target, context.settings or {}) then return false end
    else
        call_log.fallback_path_called = call_log.fallback_path_called + 1
        -- Replicates the spec's fallback: target_is_casting(context.target)
        -- which probes is_casting, is_casting_spell, is_channeling, etc.
        local t = context.target
        if not t then return false end
        if not (t.is_casting and t:is_casting()) then return false end
    end
    if not state.enough_energy then return false end
    return NS.spell_ready(context.spell, context.target)
end

print("--- Rogue Subtlety: Kick pattern ---")

-- Test 12: use_interrupts == false blocks
reset_call_log()
assert_false(kick_matches_pattern(
    { settings = { use_interrupts = false }, target = mock_target({ is_casting = true, cast_pct = 30 }), spell = 1766 },
    { enough_energy = true }
), "use_interrupts==false should block Kick")

-- Test 13: IM path — casting at 30% passes window
reset_call_log()
assert_true(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }), spell = 1766 },
    { enough_energy = true }
), "Kick should match when target casting at 30%")
assert_eq(call_log.try_interrupt_calls, 1, "try_interrupt should be called")
assert_eq(call_log.window_calls, 1, "cast_has_interrupt_window should be called")

-- Test 14: IM path — target at 80% cast → blocked by default 50% window
reset_call_log()
assert_false(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 80 }), spell = 1766 },
    { enough_energy = true }
), "80% cast should be blocked by 50% default window")

-- Test 15: IM path — 80% cast with 85% threshold → passes
reset_call_log()
assert_true(kick_matches_pattern(
    { settings = { use_interrupts = true, interrupt_cast_percent = 85 }, target = mock_target({ is_casting = true, cast_pct = 80 }), spell = 1766 },
    { enough_energy = true }
), "80% cast should pass with 85% threshold")

-- Test 16: Fallback — IM nil, target casting → passes via _is_casting
reset_call_log()
NS.InterruptManager = nil
assert_true(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }), spell = 1766 },
    { enough_energy = true }
), "fallback: target casting should match Kick")
assert_eq(call_log.fallback_path_called, 1, "fallback path used when IM nil")

-- Test 17: Fallback — IM nil, target NOT casting → blocked
reset_call_log()
assert_false(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = false }), spell = 1766 },
    { enough_energy = true }
), "fallback: target not casting should NOT match Kick")

NS.InterruptManager = M

-- Test 18: Spec-specific gate — not enough energy
reset_call_log()
assert_false(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }), spell = 1766 },
    { enough_energy = false }
), "not enough energy should block Kick")

-- ============================================================================
-- Pattern 3: Druid Bear (BashInterrupt)
-- Taken from EaxRotations/classes/druid/bear_sylvanas.lua lines 802-822
-- Simplified: tests same IM integration pattern but includes rage + form gates
-- ============================================================================

local function bash_interrupt_pattern(context, state)
    if not spec_kit.setting_bool(context, "use_interrupts", true) then return false end
    if not state.can_use_bear_ability then return false end
    local mgr = NS.InterruptManager
    local target = context.target
    if mgr then
        call_log.im_path_called = call_log.im_path_called + 1
        if not NS.try_interrupt(target) then return false end
        if not mgr.cast_has_interrupt_window(target, context.settings or {}) then return false end
        if not mgr.humanize_interrupt_elapsed(target, context.settings or {}) then return false end
    else
        call_log.fallback_path_called = call_log.fallback_path_called + 1
        if not state.target_is_casting then return false end
        if not state.target_interruptible then return false end
    end
    if state.rage < 10 then return false end
    return state.bash_ready
end

print("--- Druid Bear: BashInterrupt pattern ---")

-- Test 19: use_interrupts == false blocks
reset_call_log()
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = false }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true }
), "use_interrupts==false should block BashInterrupt")

-- Test 20: IM path — valid interrupt
reset_call_log()
assert_true(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true }
), "BashInterrupt should match when target casting at 30%")
assert_eq(call_log.im_path_called, 1, "IM path should be used")
assert_eq(call_log.try_interrupt_calls, 1, "try_interrupt called")
assert_eq(call_log.window_calls, 1, "cast_has_interrupt_window called")

-- Test 21: IM path — target at 70% cast blocked by window
reset_call_log()
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 70 }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true }
), "70% cast should be blocked by 50% default window for Bash")

-- Test 22: Fallback — IM nil, target casting + interruptible
reset_call_log()
NS.InterruptManager = nil
assert_true(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true, target_is_casting = true, target_interruptible = true }
), "fallback: casting + interruptible should match BashInterrupt")
assert_eq(call_log.fallback_path_called, 1, "fallback path used")

-- Test 23: Fallback — IM nil, target not interruptible → blocked
reset_call_log()
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true, target_is_casting = true, target_interruptible = false }
), "fallback: not interruptible should block BashInterrupt")

NS.InterruptManager = M

-- Test 24: Spec-specific gate — not in bear form
reset_call_log()
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { can_use_bear_ability = false, rage = 20, bash_ready = true }
), "not in bear form should block BashInterrupt")

-- Test 25: Spec-specific gate — insufficient rage
reset_call_log()
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { can_use_bear_ability = true, rage = 5, bash_ready = true }
), "insufficient rage (< 10) should block BashInterrupt")

-- Test 26: Bash not ready
reset_call_log()
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = false }
), "bash_ready==false should block")

-- ============================================================================
-- Pattern 4: Shaman Enhancement IM integration (Phase 2 enhanced should_interrupt_target)
-- The Phase 2 change routes should_interrupt_target through InterruptManager
-- when available, preserving the existing min/max cast_pct logic.
-- ============================================================================

local function shaman_im_interrupt_pattern(context, state)
    if not spec_kit.setting_bool(context, "use_interrupts", true) then return false end
    if state.earth_shock_mode ~= "interrupts" then return false end
    if not state.earth_shock_ready then return false end
    local mgr = NS.InterruptManager
    if mgr then
        call_log.im_path_called = call_log.im_path_called + 1
        if not NS.try_interrupt(context.target) then return false end
        if not mgr.cast_has_interrupt_window(context.target, context.settings or {}) then return false end
        if not mgr.humanize_interrupt_elapsed(context.target, context.settings or {}) then return false end
        -- After IM checks pass, apply enh-specific cast_pct window
        local mode = state.interrupt_mode or "target"
        if mode == "target" then
            if not state.target_can_interrupt then return false end
            local cast_pct = state.target_cast_pct
            local min_pct = state.kick_min_pct
            local max_pct = state.kick_max_pct
            if min_pct >= max_pct then min_pct = max_pct - 10 end
            return cast_pct >= min_pct and cast_pct <= max_pct
        end
        return true
    else
        call_log.fallback_path_called = call_log.fallback_path_called + 1
        -- Fallback: bare enh interrupt checks (target can interrupt + cast_pct)
        if not state.target_can_interrupt then return false end
        local cast_pct = state.target_cast_pct
        local min_pct = state.kick_min_pct
        local max_pct = state.kick_max_pct
        if min_pct >= max_pct then min_pct = max_pct - 10 end
        return cast_pct >= min_pct and cast_pct <= max_pct
    end
end

print("--- Shaman Enhancement: IM integration pattern ---")

-- Test 36: use_interrupts == false blocks
reset_call_log()
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = false }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "use_interrupts==false should block shaman interrupt")

-- Test 37: IM path — valid interrupt through IM + enh cast_pct window
reset_call_log()
assert_true(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "shaman IM path: casting at 30% within enh window should match")
assert_eq(call_log.im_path_called, 1, "IM path used")
assert_eq(call_log.try_interrupt_calls, 1, "try_interrupt called")
assert_eq(call_log.window_calls, 1, "cast_has_interrupt_window called")

-- Test 38: IM path — IM window passes but enh cast_pct above max → blocked
reset_call_log()
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 95, kick_min_pct = 0, kick_max_pct = 90 }
), "IM passes but enh max_pct blocks")
assert_eq(call_log.im_path_called, 1, "IM path entered but enh gate blocked")

-- Test 39: IM path — humanization blocks first call
reset_call_log()
M.humanize_cleanup(999)
NS.time_now = function() return 0 end
local enh_target = mock_target({ is_casting = true, cast_pct = 30, cast_spell_id = 2054 })
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true, interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1 }, target = enh_target },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "shaman humanization should block first call")
assert_eq(call_log.humanize_calls, 1, "humanize called")

-- Test 40: IM path — humanization allows after delay
reset_call_log()
NS.time_now = function() return 1 end
assert_true(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true, interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 1 }, target = enh_target },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "shaman humanization should allow after delay")

-- Test 41: Fallback — IM nil, valid cast_pct within enh window
reset_call_log()
NS.InterruptManager = nil
assert_true(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "shaman fallback: valid cast_pct window should match")
assert_eq(call_log.fallback_path_called, 1, "fallback used")

-- Test 42: Fallback — IM nil, cast_pct outside window → blocked
reset_call_log()
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 95 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 95, kick_min_pct = 0, kick_max_pct = 90 }
), "shaman fallback: cast_pct outside enh window should block")

NS.InterruptManager = M
M.humanize_cleanup(999)

-- Test 43: dps mode blocks (even with valid target, IM path)
reset_call_log()
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "dps", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "earth_shock_mode==dps should block even with valid target")

-- Test 44: earth_shock_ready == false blocks
reset_call_log()
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = false, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "earth_shock_ready==false should block")

-- Test 45: any-in-range mode bypasses target_can_interrupt (IM path)
reset_call_log()
assert_true(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = false, interrupt_mode = "any", target_cast_pct = 30, kick_min_pct = 0, kick_max_pct = 90 }
), "any-in-range mode should bypass target_can_interrupt and cast_pct window")

-- Test 46: min>=max clamp guard — min clamped to max-10, cast_pct within clamped range
reset_call_log()
assert_true(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 75, kick_min_pct = 90, kick_max_pct = 80 }
), "min>=max guard: cast_pct 75 should pass (min clamped from 90 to 70, range [70,80])")

-- Test 47: min>=max clamp guard — cast_pct below clamped range → blocked
reset_call_log()
assert_false(shaman_im_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true, cast_pct = 30 }) },
    { earth_shock_mode = "interrupts", earth_shock_ready = true, target_can_interrupt = true, interrupt_mode = "target", target_cast_pct = 20, kick_min_pct = 90, kick_max_pct = 80 }
), "min>=max guard: cast_pct 20 should be blocked (min clamped to 70, 20 < 70)")

-- ============================================================================
-- Cross-spec: Humanization delay consistency
-- Verify all 3 IM-path specs handle humanization the same way
-- ============================================================================

print("--- Cross-spec: Humanization consistency ---")

NS.time_now = function() return 0 end
M.humanize_cleanup(999)

local human_target = mock_target({ is_casting = true, cast_pct = 30, cast_spell_id = 2054 })
local human_settings = { use_interrupts = true, interrupt_humanize_enabled = true, interrupt_cast_jitter_min = 2 }
local ready_state = { shield_bash_ready = true, defensive_stance = true }
local energy_state = { enough_energy = true }
local bear_state = { can_use_bear_ability = true, rage = 20, bash_ready = true }

-- All 3 specs should block on first call (humanization not elapsed)
reset_call_log()
local war_ok = shield_bash_matches_pattern({ settings = human_settings, target = human_target }, ready_state)
local rogue_ok = kick_matches_pattern({ settings = human_settings, target = human_target, spell = 1766 }, energy_state)
local bear_ok = bash_interrupt_pattern({ settings = human_settings, target = human_target }, bear_state)
assert_false(war_ok, "Warrior: humanization should block first call")
assert_false(rogue_ok, "Rogue: humanization should block first call")
assert_false(bear_ok, "Druid: humanization should block first call")

-- After 1s (jitter min=2 converted to 0.2s), same spell should pass
NS.time_now = function() return 1 end
reset_call_log()
assert_true(shield_bash_matches_pattern({ settings = human_settings, target = human_target }, ready_state),
    "Warrior: humanization should pass after delay")
assert_true(kick_matches_pattern({ settings = human_settings, target = human_target, spell = 1766 }, energy_state),
    "Rogue: humanization should pass after delay")
assert_true(bash_interrupt_pattern({ settings = human_settings, target = human_target }, bear_state),
    "Druid: humanization should pass after delay")

-- ============================================================================
-- Cross-spec: Fallback consistency when IM is nil
-- Verify all 3 specs fall back to bare cast checks
-- ============================================================================

print("--- Cross-spec: Fallback consistency (IM = nil) ---")

NS.InterruptManager = nil

-- Warrior fallback: needs target_is_casting + target_casting_interruptible
reset_call_log()
assert_true(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }) },
    { shield_bash_ready = true, defensive_stance = true, target_is_casting = true, target_casting_interruptible = true }
), "Warrior fallback: both casting and interruptible → match")
assert_eq(call_log.fallback_path_called, 1, "fallback used")

-- Rogue fallback: only needs target._is_casting (simpler)
reset_call_log()
assert_true(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }), spell = 1766 },
    { enough_energy = true }
), "Rogue fallback: target casting → match (simpler fallback)")

-- Druid fallback: needs target_is_casting + target_interruptible
reset_call_log()
assert_true(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = true }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true, target_is_casting = true, target_interruptible = true }
), "Druid fallback: both casting and interruptible → match")

-- All 3 should block when target not casting in fallback
reset_call_log()
assert_false(shield_bash_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = false }) },
    { shield_bash_ready = true, defensive_stance = true, target_is_casting = false, target_casting_interruptible = true }
), "Warrior fallback: not casting → block")
assert_false(kick_matches_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = false }), spell = 1766 },
    { enough_energy = true }
), "Rogue fallback: not casting → block")
assert_false(bash_interrupt_pattern(
    { settings = { use_interrupts = true }, target = mock_target({ is_casting = false }) },
    { can_use_bear_ability = true, rage = 20, bash_ready = true, target_is_casting = false, target_interruptible = true }
), "Druid fallback: not casting → block")

-- Restore IM for cleanup
NS.InterruptManager = M
M.humanize_cleanup(999)

print("PASS test_interrupt_spec_integration")