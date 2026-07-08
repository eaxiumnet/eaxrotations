-- test_cooldown_planner.lua -- cooldown tracking cooldown planner tests.
-- WHAT:  cooldown tracking cooldown planner tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Test: shared/cooldown_planner_sylvanas.lua alignment helpers.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

local function make_me(buff_ids)
    buff_ids = buff_ids or {}
    return {
        buff_up = function(_, ids)
            for _, id in ipairs(ids or {}) do
                for _, bid in ipairs(buff_ids) do
                    if id == bid then return true end
                end
            end
            return false
        end,
    }
end

local NS = {
    GetPlayer = function() return make_me({}) end,
    buff_up = function(unit, ids) return unit and unit:buff_up(ids) or false end,
}
_G.EaxRotations = NS

local M = require("shared/cooldown_planner_sylvanas")
assert_true(M ~= nil, "cooldown_planner should load")

-- No haste CDs active -> false
local ctx_no = { me = make_me({}) }
assert_false(M.is_external_haste_active(ctx_no), "no haste -> false")
assert_false(M.is_major_offensive_cd_active(ctx_no), "no major CD -> false")

-- Bloodlust active -> true
local ctx_bl = { me = make_me({ 2825 }) }
assert_true(M.is_external_haste_active(ctx_bl), "bloodlust -> true")
assert_true(M.should_fire_offensive(ctx_bl), "should fire during bloodlust")

-- Arcane Power active -> major offensive CD true
local ctx_ap = { me = make_me({ 12042 }) }
assert_true(M.is_major_offensive_cd_active(ctx_ap), "Arcane Power -> major CD true")
assert_true(M.should_fire_offensive(ctx_ap), "should fire during AP")

-- No windows and early combat -> hold (if burst_on_bloodlust set)
local ctx_wait = {
    me = make_me({}),
    settings = { burst_on_bloodlust = true },
    combat_time = 10,
    ttd = 120,
}
assert_false(M.should_fire_offensive(ctx_wait), "early combat, no BL, wait")

-- Timeout fallback -> fire
local ctx_timeout = {
    me = make_me({}),
    settings = { burst_on_bloodlust = true },
    combat_time = 50,
    ttd = 120,
}
assert_true(M.should_fire_offensive(ctx_timeout), "timeout -> fire")

-- Low TTD fallback -> fire
local ctx_dying = {
    me = make_me({}),
    settings = { burst_on_bloodlust = true },
    combat_time = 10,
    ttd = 12,
}
assert_true(M.should_fire_offensive(ctx_dying), "dying target -> fire")

-- Explicit should_burst -> fire regardless
local ctx_burst = { me = make_me({}), should_burst = true, combat_time = 5, ttd = 120 }
assert_true(M.should_fire_offensive(ctx_burst), "should_burst -> fire")

-- trinket_align_with_cds=false -> legacy fire on CD
local ctx_legacy = {
    me = make_me({}),
    settings = { trinket_align_with_cds = false },
    combat_time = 5,
    ttd = 120,
}
assert_true(M.should_fire_offensive(ctx_legacy), "alignment disabled -> fire")

print("PASS test_cooldown_planner")
