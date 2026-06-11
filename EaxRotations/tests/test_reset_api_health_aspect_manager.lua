-- Test: NS.is_api_health_broken() / NS.reset_api_health() backward-compat stubs
-- PS build API health tracking was removed in v2.1.x. These stubs are no-ops.
-- The test verifies that aspect_manager still works (no regression from removal)
-- and that the stubs don't crash when called.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

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

-- ====================================================================
-- SETUP: Minimal core mock with spell_book
-- ====================================================================
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil
_G.core = {
    get_game_version = function() return "wow_tbc" end,
    get_exact_game_version = function() return "wow_tbc" end,
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    spell_book = {
        is_spell_learned = function(id) return false end,
    },
    input = {},
}

local NS = require("core_sylvanas")
_G.EaxRotations = NS

-- ====================================================================
-- SECTION 1: Stub verification
-- ====================================================================
io.write("--- Section 1: Stub verification ---\n")

-- is_api_health_broken always returns false (PS build tracking removed)
assert_false(NS.is_api_health_broken(), "is_api_health_broken: always false")

-- reset_api_health is a no-op
local ok, err = pcall(NS.reset_api_health)
assert_true(ok, "reset_api_health: pcall does not error (" .. tostring(err) .. ")")

-- Idempotent: calling again does nothing
ok, err = pcall(NS.reset_api_health)
assert_true(ok, "reset_api_health: idempotent (" .. tostring(err) .. ")")

-- Still false after reset
assert_false(NS.is_api_health_broken(), "is_api_health_broken: still false after reset")

-- ====================================================================
-- SECTION 2: Stub usage in realistic patterns
-- ====================================================================
io.write("--- Section 2: Realistic usage patterns ---\n")

-- Pattern used in affliction/demonology vanilla warlock:
--   NS.is_api_health_broken and NS.is_api_health_broken() and ...
local chained = NS.is_api_health_broken and NS.is_api_health_broken()
assert_false(chained, "chained call: returns false (no crash)")

-- Pattern used in paladin class init:
--   if NS.reset_api_health then NS.reset_api_health() end
if NS.reset_api_health then
    ok, err = pcall(NS.reset_api_health)
    assert_true(ok, "paladin pattern: pcall ok (" .. tostring(err) .. ")")
end

-- ====================================================================
-- SECTION 3: AspectManager loads and runs (regression check)
--   The old test manipulated _api_health_broken upvalues to toggle the
--   broken-API fallback. Since that mechanism is removed, we just verify
--   that AspectManager loads and its basic entry points don't crash.
-- ====================================================================
io.write("--- Section 3: AspectManager load + entry points ---\n")

NS.has_player_buff = function(id) return false end

local try_cast_calls = {}
NS.try_cast = function(id, target, reason, opts)
    try_cast_calls[#try_cast_calls + 1] = { id = id, target = target, reason = reason, opts = opts }
    return true
end
NS.log = function(msg) end

local M = require("shared/aspect_manager_sylvanas")
assert_true(M ~= nil, "AspectManager: loaded")
assert_true(NS.AspectManager == M, "AspectManager: registered on NS")

-- try_ooc_aspect does not crash
local ooc_ctx = {
    me = { get_health_percentage = function() return 100 end },
    in_combat = false,
    is_mounted = false,
    mana_pct = 5,
    settings = {},
}
ok, err = pcall(M.try_ooc_aspect, ooc_ctx)
assert_true(ok, "AspectManager: try_ooc_aspect does not crash (" .. tostring(err) .. ")")

-- try_swap_aspect does not crash
local swap_ctx = {
    me = { get_health_percentage = function() return 100 end },
    in_combat = true,
    is_mounted = false,
    mana_pct = 5,
    settings = {},
}
ok, err = pcall(M.try_swap_aspect, swap_ctx)
assert_true(ok, "AspectManager: try_swap_aspect does not crash (" .. tostring(err) .. ")")

-- ====================================================================
io.write("\nAll tests passed!\n")
