-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_sticky_spell.lua"
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
-- Sticky spell anti-flicker regression test.
-- Validates sticky_spell_should_override priority rules, min_duration gating, and refresh.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local NS = {
    time_now = function() return _G._test_now or 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}
_G.EaxRotations = NS

dofile("EaxRotations/core_sylvanas.lua")

-- Re-override time_now because core_sylvanas.lua overwrote it
NS.time_now = function() return _G._test_now or 0 end

-- Test 1: First spell always sticks
_G._test_now = 0
assert_true(NS.sticky_spell_should_override(1, "Fireball", 0), "first spell should always stick")
local id, name = NS.sticky_spell_get()
assert_eq(id, 1, "sticky should be Fireball id")
assert_eq(name, "Fireball", "sticky should be Fireball name")

-- Test 2: Same spell refreshes timer
_G._test_now = 0.1
assert_true(NS.sticky_spell_should_override(1, "Fireball", 0), "same spell should refresh")

-- Test 3: Different spell blocked before min_duration
_G._test_now = 0.15
assert_false(NS.sticky_spell_should_override(2, "Frostbolt", 0), "equal priority before 0.3s should block")

-- Test 4: Higher priority overrides immediately
_G._test_now = 0.15
assert_true(NS.sticky_spell_should_override(3, "Pyroblast", 5), "higher priority should override immediately")
local id2, name2 = NS.sticky_spell_get()
assert_eq(id2, 3, "sticky should switch to Pyroblast")

-- Test 5: After min_duration elapsed, equal priority can switch
_G._test_now = 1.0
assert_true(NS.sticky_spell_should_override(4, "Arcane Missiles", 0), "after min_duration, new spell should stick")

-- Test 6: reset clears sticky
NS.sticky_spell_reset()
local id3, name3 = NS.sticky_spell_get()
assert_eq(id3, nil, "after reset id should be nil")
assert_eq(name3, nil, "after reset name should be nil")

print("PASS sticky_spell")
