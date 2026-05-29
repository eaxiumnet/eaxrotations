local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;?.lua;" .. package.path

local orig_require = require
function require(path)
    if path == "classes/druid/balance_sylvanas" then return "TBC_BALANCE" end
    if path == "classes/druid/balance_vanilla" then return "VANILLA_BALANCE" end
    if path == "classes/druid/bear_sylvanas" then return "TBC_BEAR" end
    if path == "classes/druid/bear_vanilla" then return "VANILLA_BEAR" end
    if path == "classes/druid/cat_sylvanas" then return "TBC_CAT" end
    if path == "classes/druid/cat_vanilla" then return "VANILLA_CAT" end
    if path == "classes/druid/resto_sylvanas" then return "TBC_RESTO" end
    if path == "classes/druid/resto_vanilla" then return "VANILLA_RESTO" end
    if path:match("^shared/class_loader_sylvanas") then return orig_require(path) end
    if path == "core_sylvanas" then return orig_require(path) end
    return orig_require(path)
end

_G.core = {
    time = function() return 0 end,
    log = function() end,
    get_game_version = function() return "Tbc" end,
}
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
local core_mod = require("core_sylvanas")
assert_true(core_mod.is_tbc(), "Should be TBC")

local loader = require("shared/class_loader_sylvanas")
local load_tbc = loader.create_expansion_loader("druid", "Druid")
assert_eq(load_tbc("balance", true), "TBC_BALANCE", "TBC balance should load _sylvanas")
assert_eq(load_tbc("bear", true), "TBC_BEAR", "TBC bear should load _sylvanas")
assert_eq(load_tbc("cat", true), "TBC_CAT", "TBC cat should load _sylvanas")
assert_eq(load_tbc("resto", true), "TBC_RESTO", "TBC resto should load _sylvanas")

_G.core.get_game_version = function() return "Vanilla" end
package.loaded.core_sylvanas = nil; _G.EaxRotations = nil
core_mod = require("core_sylvanas")
assert_true(core_mod.is_vanilla(), "Should be Vanilla")

loader = require("shared/class_loader_sylvanas")
local load_vanilla = loader.create_expansion_loader("druid", "Druid")
assert_eq(load_vanilla("balance", true), "VANILLA_BALANCE", "Vanilla balance should load _vanilla")
assert_eq(load_vanilla("bear", true), "VANILLA_BEAR", "Vanilla bear should load _vanilla")
assert_eq(load_vanilla("cat", true), "VANILLA_CAT", "Vanilla cat should load _vanilla")
assert_eq(load_vanilla("resto", true), "VANILLA_RESTO", "Vanilla resto should load _vanilla")

require = orig_require

print("PASS classic_druid_spec")