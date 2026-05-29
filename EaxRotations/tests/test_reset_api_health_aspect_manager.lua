-- Test: NS.reset_api_health() integration with AspectManager
-- Uses debug.setupvalue to control the real _api_health_broken flag, verifying
-- that AspectManager.try_ooc_aspect() and .try_swap_aspect() respond correctly
-- through the real NS.is_spell_learned → NS.spell_id_is_known() → _api_health_broken chain.
--
-- Key insight: when _api_health_broken=true (non-PS), spell_id_is_known() returns
-- true unconditionally (line 1771), so is_spell_learned returns true even when
-- the underlying spell_book API returns false. This allows aspect casts to
-- proceed. After reset_api_health() clears the flag, is_spell_learned returns
-- the real API result (false in this test), blocking aspect casts.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_eq = function(a, b, msg)
    if a ~= b then
        io.write("FAIL: " .. tostring(msg or "assert_eq") .. " expected=" .. tostring(b) .. " actual=" .. tostring(a) .. "\n")
        os.exit(1)
    end
    io.write("PASS: " .. tostring(msg or "assert_eq") .. "\n")
end

local assert_true = function(v, msg)
    if v ~= true then
        io.write("FAIL: " .. tostring(msg or "assert_true") .. " expected=true actual=" .. tostring(v) .. "\n")
        os.exit(1)
    end
    io.write("PASS: " .. tostring(msg or "assert_true") .. "\n")
end

local assert_false = function(v, msg)
    if v ~= false then
        io.write("FAIL: " .. tostring(msg or "assert_false") .. " expected=false actual=" .. tostring(v) .. "\n")
        os.exit(1)
    end
    io.write("PASS: " .. tostring(msg or "assert_false") .. "\n")
end

-- Helper: find a named upvalue index on a function
local function find_upval(fn, name)
    for i = 1, 30 do
        local n = debug.getupvalue(fn, i)
        if n == nil then return nil end
        if n == name then return i end
    end
    return nil
end

-- Helper: write a named upvalue on a function
local function set_upval(fn, name, value)
    local idx = find_upval(fn, name)
    if not idx then error("upvalue '" .. name .. "' not found on " .. tostring(fn)) end
    debug.setupvalue(fn, idx, value)
end

-- ====================================================================
-- SETUP: Minimal core mock with spell_book that always returns false
-- ====================================================================
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil
_G.core = {
    get_game_version = function() return "wow_tbc" end,
    get_exact_game_version = function() return "wow_tbc" end,  -- non-PS
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    spell_book = {
        is_spell_learned = function(id) return false end,  -- always false
    },
    input = {},
}

local NS = require("core_sylvanas")
_G.EaxRotations = NS

-- Verify non-PS build: _api_health_broken starts false
assert_false(NS.is_api_health_broken(), "non-PS: initially not broken")

-- Mock NS.has_player_buff: always return false (no aspect active)
-- so that has_hawk()/has_viper() don't short-circuit the aspect swap.
NS.has_player_buff = function(id) return false end

-- Spy on NS.try_cast to track whether aspect casts were attempted
local try_cast_calls = {}
NS.try_cast = function(id, target, reason, opts)
    try_cast_calls[#try_cast_calls + 1] = { id = id, target = target, reason = reason, opts = opts }
    return true
end

-- Spy on NS.log to track output (optional, but useful for debugging)
NS.log = function(msg) end

-- Load AspectManager
local M = require("shared/aspect_manager_sylvanas")
assert_true(M ~= nil, "AspectManager should load")
assert_true(NS.AspectManager == M, "AspectManager should be registered on NS")

-- Build a minimal context for try_ooc_aspect
-- try_ooc_aspect requires: context (with me, settings, in_combat=OOC, etc.)
local ooc_ctx = {
    me = { get_health_percentage = function() return 100 end },
    in_combat = false,    -- must be OOC for try_ooc_aspect
    is_mounted = false,
    mana_pct = 5,         -- below default viper_start (10), triggers Viper path
    settings = {},
}

-- Build a context for try_swap_aspect (combat version)
local swap_ctx = {
    me = { get_health_percentage = function() return 100 end },
    in_combat = true,
    is_mounted = false,
    mana_pct = 5,
    settings = {},
}

-- ====================================================================
-- SECTION 1: _api_health_broken=true → aspect_manager can cast aspects
-- (is_spell_learned returns true through broken-API fallback)
-- ====================================================================
io.write("--- Section 1: _api_health_broken=true (aspect casts succeed) ---\n")

set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "broken=true: flag is set")

-- try_ooc_aspect (low mana → Viper path)
try_cast_calls = {}
local result = M.try_ooc_aspect(ooc_ctx)
assert_true(result, "broken=true: try_ooc_aspect returns true (Viper cast attempted)")
assert_eq(#try_cast_calls, 1, "broken=true: try_cast called once for Viper")
if try_cast_calls[1] then
    assert_eq(try_cast_calls[1].id, 34074, "broken=true: Viper spell ID 34074")
end

-- try_swap_aspect (in combat, same low mana)
try_cast_calls = {}
result = M.try_swap_aspect(swap_ctx)
assert_true(result, "broken=true: try_swap_aspect returns true")
assert_true(#try_cast_calls >= 1, "broken=true: try_cast called for aspect swap")
if try_cast_calls[1] then
    assert_eq(try_cast_calls[1].id, 34074, "broken=true: swap uses Viper spell ID 34074")
end

-- ====================================================================
-- SECTION 2: Call NS.reset_api_health() → _api_health_broken=false
--            → is_spell_learned returns false → aspect_cast blocked
-- ====================================================================
io.write("--- Section 2: After NS.reset_api_health() (aspect casts blocked) ---\n")

NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "after reset: flag is cleared")

-- try_ooc_aspect: should fail because is_spell_learned returns false
try_cast_calls = {}
result = M.try_ooc_aspect(ooc_ctx)
assert_false(result, "after reset: try_ooc_aspect returns false (spells not learned)")
assert_eq(#try_cast_calls, 0, "after reset: try_cast NOT called")

-- try_swap_aspect: same behavior
try_cast_calls = {}
result = M.try_swap_aspect(swap_ctx)
assert_false(result, "after reset: try_swap_aspect returns false")
assert_eq(#try_cast_calls, 0, "after reset: swap try_cast NOT called")

-- ====================================================================
-- SECTION 3: Toggle broken=true again — aspect casts work again
-- ====================================================================
io.write("--- Section 3: Toggle broken=true again ---\n")

set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "toggle back: flag is set")

try_cast_calls = {}
result = M.try_ooc_aspect(ooc_ctx)
assert_true(result, "toggle back: try_ooc_aspect returns true again")
assert_eq(#try_cast_calls, 1, "toggle back: try_cast called once")
if try_cast_calls[1] then
    assert_eq(try_cast_calls[1].id, 34074, "toggle back: Viper spell ID 34074")
end

-- ====================================================================
-- SECTION 4: Reset again — aspect casts blocked again
-- ====================================================================
io.write("--- Section 4: Reset again ---\n")

NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "reset again: flag cleared")

try_cast_calls = {}
result = M.try_ooc_aspect(ooc_ctx)
assert_false(result, "reset again: try_ooc_aspect returns false")
assert_eq(#try_cast_calls, 0, "reset again: try_cast NOT called")

-- ====================================================================
-- SECTION 5: pcall-safe reset guard (simulating /reload)
-- ====================================================================
io.write("--- Section 5: pcall-safe reset guard ---\n")

set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "pcall guard: flag set")

-- This is the pattern used in dispatcher/reload: pcall(NS.reset_api_health)
local ok, err = pcall(NS.reset_api_health)
assert_true(ok, "pcall guard: reset_api_health did not error")
if err then io.write("  (reset error: " .. tostring(err) .. ")\n") end

assert_false(NS.is_api_health_broken(), "pcall guard: flag cleared after pcall reset")

try_cast_calls = {}
result = M.try_ooc_aspect(ooc_ctx)
assert_false(result, "pcall guard: try_ooc_aspect returns false after pcall reset")
assert_eq(#try_cast_calls, 0, "pcall guard: try_cast NOT called after pcall reset")

-- ====================================================================
io.write("\nAll tests passed!\n")
