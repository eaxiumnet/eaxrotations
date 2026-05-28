-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_cooldown_registry.lua"
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
-- Cooldown suggestion registry regression test.
-- Validates register_cooldown, priority ordering, get_cooldown_suggestions, and category filtering.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.core = {
    spell_book = {
        is_spell_learned = function(id) return true end,
        get_spell_cooldown_information = function(id) return nil end,
    }
}

local NS = {
    time_now = function() return 100 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}
_G.EaxRotations = NS

dofile("EaxRotations/core_sylvanas.lua")

-- Ensure spell_id_is_known treats all IDs as known in this test harness
NS.spell_id_is_known = function(id) return true end

-- Test 1: register validates entry
assert_true(NS.register_cooldown({ name = "Bloodlust", spell = 2825, priority = 10, category = "offensive" }) == true, "valid entry should register")
assert_true(NS.register_cooldown({ spell = 1, priority = 5, category = "offensive" }) == false, "missing name should fail")
assert_true(NS.register_cooldown({ name = "NoSpellOrItem" }) == true, "name-only entry should still register (will never show ready)")

-- Test 2: priority ordering
NS.clear_cooldown_registry()
NS.register_cooldown({ name = "Low", spell = 1, priority = 1, category = "offensive" })
NS.register_cooldown({ name = "High", spell = 2, priority = 10, category = "offensive" })
local suggestions = NS.get_cooldown_suggestions({}, "offensive")
assert_true(suggestions.n >= 2, "should have 2+ suggestions")
assert_eq(suggestions[1].name, "High", "highest priority should be first")

-- Test 3: category filtering
NS.clear_cooldown_registry()
NS.register_cooldown({ name = "Off", spell = 1, priority = 5, category = "offensive" })
NS.register_cooldown({ name = "Def", spell = 2, priority = 5, category = "defensive" })
-- NOTE: get_cooldown_suggestions returns a static buffer; do NOT hold references across calls.
local off_buf = NS.get_cooldown_suggestions({}, "offensive")
assert_eq(off_buf.n, 1, "offensive filter should return 1")
assert_eq(off_buf[1].name, "Off", "offensive should be Off")

local def_buf = NS.get_cooldown_suggestions({}, "defensive")
assert_eq(def_buf.n, 1, "defensive filter should return 1")
assert_eq(def_buf[1].name, "Def", "defensive should be Def")

-- Test 4: condition gate
NS.clear_cooldown_registry()
NS.register_cooldown({ name = "Gated", spell = 1, priority = 5, category = "offensive", condition = function(ctx) return ctx and ctx.allow end })
-- Read each result immediately; do NOT hold references across calls to the static buffer.
local gated_on_n = NS.get_cooldown_suggestions({ allow = true }, "offensive").n
local gated_off_n = NS.get_cooldown_suggestions({ allow = false }, "offensive").n
assert_eq(gated_on_n, 1, "condition true should include")
assert_eq(gated_off_n, 0, "condition false should exclude")

-- Test 5: best offensive/defensive helpers
NS.clear_cooldown_registry()
NS.register_cooldown({ name = "Best", spell = 1, priority = 99, category = "offensive" })
local best = NS.get_best_offensive_cooldown({})
assert_true(best ~= nil, "best offensive should exist")
assert_eq(best.name, "Best", "best offensive should be Best")

-- Test 6: unregister
NS.clear_cooldown_registry()
NS.register_cooldown({ name = "RemoveMe", spell = 1, priority = 1, category = "offensive" })
assert_true(NS.unregister_cooldown("RemoveMe") == true, "unregister should succeed")
local after_n = NS.get_cooldown_suggestions({}, "offensive").n
assert_eq(after_n, 0, "after unregister should be empty")

print("PASS cooldown_registry")
