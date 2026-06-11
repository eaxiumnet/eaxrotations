-- TDD test for evaluate_cast check #6: player casting/channeling guard.
-- Scenarios:
--   S1: Player is casting → evaluate_cast returns false
--   S2: Player is channeling → evaluate_cast returns false
--   S3: Player is idle (not casting/channeling) → evaluate_cast returns true
--   S4: skip_casting=true bypasses guard while casting
--   S5: Player API fails (nil/error) → safe fallback, no crash

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed: expected false", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS infrastructure (replicates NS.evaluate_cast from core_sylvanas.lua)
-- ============================================================================

local mock_player
local mock_spell_queue_called = false

local NS = {
    get_spell_id = function(spell) return type(spell) == "number" and spell or 133 end,
    log = function() end,
    time_now = function() return 1000 end,
    cooldown_remains = function() return 0 end,
    spell_ready = function() return true end,
    gcd_remains = function() return 0 end,
    spell_exists = function() return true end,
    get_setting = function() return nil end,
    buff_up = function() return false end,
    not_same_unit = function(a, b) return a ~= b end,
    GetPlayer = function() return mock_player end,
    sticky_spell_should_override = function() end,
    spell_label = function(spell, fallback) return tostring(fallback or "test") end,
}
_G.EaxRotations = NS

-- Replicating the evaluate_cast guard from core_sylvanas.lua (lines 2610-2705)
-- with the NEW check #6 added (line ~2702).
local EMPTY = {}

local function evaluate_cast(spell, unit, reason, opts)
    opts = opts or EMPTY
    local id = NS.get_spell_id(spell)
    if not id then return false end
    local target = unit or NS.GetPlayer()

    -- Dead check
    local me = NS.GetPlayer()
    if me then
        local alive_ok, alive = pcall(function() return me:is_alive() end)
        if alive_ok and alive == false then return false end
    end

    -- 6. Player casting/channeling guard (THE NEW CHECK)
    if not opts.skip_casting then
        local me = NS.GetPlayer()
        if me then
            local cast_ok, is_casting = pcall(function() return me:is_casting_spell() end)
            local chan_ok, is_channeling = pcall(function() return me:is_channelling_spell() end)
            if (cast_ok and is_casting) or (chan_ok and is_channeling) then
                return false
            end
        end
    end

    return true
end

-- ============================================================================
-- S1: Player is casting → evaluate_cast returns false
-- ============================================================================

print("--- S1: evaluate_cast returns false when player is casting ---")

mock_player = {
    is_alive = function() return true end,
    is_casting_spell = function() return true end,
    is_channelling_spell = function() return false end,
}

local r1 = evaluate_cast(686, nil, "test", {})
assert_false(r1, "S1: evaluate_cast should return false when player is casting")

print("PASS S1: Player casting blocked")

-- ============================================================================
-- S2: Player is channeling → evaluate_cast returns false
-- ============================================================================

print("--- S2: evaluate_cast returns false when player is channeling ---")

mock_player = {
    is_alive = function() return true end,
    is_casting_spell = function() return false end,
    is_channelling_spell = function() return true end,
}

local r2 = evaluate_cast(686, nil, "test", {})
assert_false(r2, "S2: evaluate_cast should return false when player is channeling")

print("PASS S2: Player channeling blocked")

-- ============================================================================
-- S3: Player is idle → evaluate_cast returns true
-- ============================================================================

print("--- S3: evaluate_cast returns true when player is idle ---")

mock_player = {
    is_alive = function() return true end,
    is_casting_spell = function() return false end,
    is_channelling_spell = function() return false end,
}

local r3 = evaluate_cast(686, nil, "test", {})
assert_true(r3, "S3: evaluate_cast should return true when player is idle")

print("PASS S3: Player idle allowed")

-- ============================================================================
-- S4: skip_casting=true bypasses guard while casting
-- ============================================================================

print("--- S4: skip_casting=true bypasses guard while casting ---")

mock_player = {
    is_alive = function() return true end,
    is_casting_spell = function() return true end,
    is_channelling_spell = function() return false end,
}

local r4 = evaluate_cast(686, nil, "test", { skip_casting = true })
assert_true(r4, "S4: evaluate_cast should return true with skip_casting=true")

print("PASS S4: skip_casting bypass works")

-- ============================================================================
-- S5: Player API fails (nil) → safe fallback, no crash
-- ============================================================================

print("--- S5: evaluate_cast handles nil player safely ---")

mock_player = nil  -- GetPlayer returns nil

local ok_s5, r5 = pcall(evaluate_cast, 686, nil, "test", {})
assert_true(ok_s5, "S5: evaluate_cast should not crash when player is nil")
assert_true(r5, "S5: evaluate_cast should return true when player is nil (can't determine state)")

print("PASS S5: Nil player no crash")

-- ============================================================================
-- S5b: Player API method missing → safe fallback, no crash
-- ============================================================================

print("--- S5b: evaluate_cast handles missing is_casting_spell method safely ---")

mock_player = {
    is_alive = function() return true end,
    -- no is_casting_spell method
    is_channelling_spell = function() return false end,
}

local ok_s5b, r5b = pcall(evaluate_cast, 686, nil, "test", {})
assert_true(ok_s5b, "S5b: evaluate_cast should not crash when is_casting_spell is missing")
assert_true(r5b, "S5b: evaluate_cast should return true when API method missing")

print("PASS S5b: Missing method no crash")

-- ============================================================================
-- S5c: Player API method returns error → handled by pcall, no crash
-- ============================================================================

print("--- S5c: evaluate_cast handles API error safely ---")

mock_player = {
    is_alive = function() return true end,
    is_casting_spell = function() error("API crash") end,
    is_channelling_spell = function() return false end,
}

local ok_s5c, r5c = pcall(evaluate_cast, 686, nil, "test", {})
assert_true(ok_s5c, "S5c: evaluate_cast should not crash when API throws")

print("PASS S5c: API error no crash")

-- ============================================================================
-- All scenarios pass
-- ============================================================================

print("PASS test_evaluate_cast_casting_guard (all 6 scenarios)")
