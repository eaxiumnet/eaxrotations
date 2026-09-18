-- test_diagnostic_dump.lua — Basic load + structure test for diagnostic_dump_sylvanas.lua
package.path = "EaxAutoQuester/?.lua;./?.lua;api/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Mock core minimally so module loads
_G.core = {
    log = function() end,
    object_manager = {
        get_local_player = function()
            return {
                get_position = function() return { x = 0, y = 0, z = 0 } end
            }
        end,
        get_visible_objects = function() return {} end,
        get_all_objects = function() return {} end,
    },
    quests = {
        get_num_quest_log_entries = function() return 0 end,
    },
    addons = {
        questie = { is_loaded = function() return false end },
        zygor = { is_loaded = function() return false end },
    },
}

local M = dofile("EaxAutoQuester/diagnostic_dump_sylvanas.lua")

assert_true(M ~= nil, "module should load")
assert_true(type(M.dump) == "function", "M.dump should be a function")
assert_true(type(M.dump_objects) == "function", "M.dump_objects should be a function")
assert_true(type(M.dump_quests) == "function", "M.dump_quests should be a function")

-- Smoke-test: run all three without error
M.dump()
M.dump_objects()
M.dump_quests()

-- Verify global registration
assert_true(_G.EaxAutoQuester and _G.EaxAutoQuester.diagnostic_dump == M, "registered on _G.EaxAutoQuester.diagnostic_dump")

print("PASS test_diagnostic_dump")
