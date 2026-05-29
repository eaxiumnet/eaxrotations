-- Expansion helper regression test.
-- Validates NS.get_expansion_max_level, NS.is_tbc, NS.is_vanilla for TBC and Classic.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

-- Test 1: TBC returns max level 70
_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Tbc" end,
    get_exact_game_version = function() return "wow_tbc" end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod = require("core_sylvanas")
assert_true(type(core_mod.get_expansion_max_level) == "function", "NS.get_expansion_max_level should exist")
assert_eq(core_mod.get_expansion_max_level(), 70, "TBC max level should be 70")
assert_true(type(core_mod.is_tbc) == "function", "NS.is_tbc should exist")
assert_true(core_mod.is_tbc(), "NS.is_tbc() should be true for Tbc")
assert_true(type(core_mod.is_vanilla) == "function", "NS.is_vanilla should exist")
assert_true(not core_mod.is_vanilla(), "NS.is_vanilla() should be false for Tbc")

-- Test 2: Vanilla returns max level 60
_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Vanilla" end,
    get_exact_game_version = function() return "wow_vanilla" end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod2 = require("core_sylvanas")
assert_eq(core_mod2.get_expansion_max_level(), 60, "Vanilla max level should be 60")
assert_true(not core_mod2.is_tbc(), "NS.is_tbc() should be false for Vanilla")
assert_true(core_mod2.is_vanilla(), "NS.is_vanilla() should be true for Vanilla")

-- Test 3: Unknown/nil version defaults to 70 (TBC-safe fallback)
_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return nil end,
    get_exact_game_version = function() return nil end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod3 = require("core_sylvanas")
assert_eq(core_mod3.get_expansion_max_level(), 70, "Unknown version should default to 70")

-- Test 4: Explicit player level 60 on Vanilla should NOT be leveling
-- (regression guard for main_sylvanas.lua leveling gate)
_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Vanilla" end,
    get_exact_game_version = function() return nil end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod4 = require("core_sylvanas")
assert_eq(core_mod4.get_expansion_max_level(), 60, "Vanilla max level 60")

print("PASS expansion_helpers")
