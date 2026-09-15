-- test_class_loader_forever_fallback.lua — Verify the Forever expansion loader prefers _forever then _vanilla.
-- WHAT:  mocks require() to confirm the _forever -> _vanilla fallback chain and that
--        Forever NEVER falls through to _sylvanas/_wotlk (TBC/WotLK semantics are
--        wrong for a level-60 Forever client).
-- WHEN:  run as a standalone test or via test runner.
-- WHY:   Forever day 1 has no _forever spec files; every class must resolve its
--        _vanilla fallback while a _forever overlay, once authored, must win.
--        Also pins the core_sylvanas era contract: is_forever() true, and
--        is_vanilla() TRUE on Forever (vanilla-superset semantics — the 40
--        NS.is_vanilla() gates in the fallback spec files are production lanes).
-- SAFETY: fully mocked; no real spec logic executed.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local orig_require = require
function require(path)
    if path == "classes/paladin/retribution_forever" then return "FOREVER_RET" end
    if path == "classes/paladin/retribution_vanilla" then return "VANILLA_RET" end
    if path == "classes/paladin/retribution_sylvanas" then return "TBC_RET" end
    if path == "classes/paladin/retribution_wotlk" then return "WOTLK_RET" end
    -- No retribution_forever module for fury: exercises the vanilla fallback.
    if path == "classes/warrior/fury_forever" then error("module 'classes/warrior/fury_forever' not found", 0) end
    if path == "classes/warrior/fury_vanilla" then return "VANILLA_FURY" end
    if path == "classes/warrior/fury_sylvanas" then return "TBC_FURY" end
    if path == "classes/warrior/fury_wotlk" then return "WOTLK_FURY" end
    if path:match("^shared/class_loader_sylvanas") then return orig_require(path) end
    return orig_require(path)
end

_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "WoW Forever" end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod = require("core_sylvanas")
assert_true(core_mod.is_forever(), "Version 'WoW Forever' should resolve the forever era")
assert_true(core_mod.is_vanilla(), "is_vanilla() must stay TRUE on Forever (vanilla-superset lanes)")
assert_eq(core_mod.get_expansion_max_level(), 60, "Forever caps at 60")
assert_true(not core_mod.is_sod() and not core_mod.is_tbc() and not core_mod.is_wotlk() and not core_mod.is_cata(),
    "no other era flag may fire on Forever")

local loader = require("shared/class_loader_sylvanas")
local load_forever = loader.create_expansion_loader("paladin", "Paladin")

-- _forever overlay wins when present (the post-beta Paladin deltas).
assert_eq(load_forever("retribution", true), "FOREVER_RET", "Forever retribution should load _forever")

-- No _forever module: falls back to _vanilla, and NEVER to _sylvanas/_wotlk.
local load_fury = loader.create_expansion_loader("warrior", "Warrior")
assert_eq(load_fury("fury", true), "VANILLA_FURY", "fury without a _forever file must fall back to _vanilla")

require = orig_require

print("PASS class_loader_forever_fallback")
