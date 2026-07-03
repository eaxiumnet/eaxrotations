-- =============================================================================
-- test_state_machine.lua — EAXFishing core/state.lua pure-logic tests.
-- =============================================================================
-- WHAT:  Verifies State.create / reset_bite / reset_fishing / reset_shoreline.
-- WHEN:  Run by run_fishing_tests.lua.
-- WHY:   The state module is the single source of truth for all runtime state
--        and is pure logic (no core.* dependency) — ideal for unit testing.
--        reset_bite / reset_fishing are called on every catch and every
--        enable/disable transition; a regression here would corrupt the
--        whole fishing loop (phantom bites, stuck hard_stop, double-casts).
-- SAFETY: No io.popen, os.execute, ffi.C, debug.*, or math.sqrt.
-- =============================================================================

package.path = "./EAXFishing/?.lua;./EAXFishing/?/init.lua;" .. package.path

local State = require("core/state")

local pass_count = 0
local function check(name, cond)
  if cond then
    pass_count = pass_count + 1
  else
    error("FAIL: " .. name, 0)
  end
end

-- 1. create() returns a fully-populated state table
local s = State.create(100)
check("create returns table", type(s) == "table")
check("fishing subtable exists", type(s.fishing) == "table")
check("bite subtable exists", type(s.bite) == "table")
check("loot subtable exists", type(s.loot) == "table")
check("equip subtable exists", type(s.equip) == "table")
check("navigation subtable exists", type(s.navigation) == "table")
check("bag subtable exists", type(s.bag) == "table")
check("anti_afk subtable exists", type(s.anti_afk) == "table")
check("profile subtable exists", type(s.profile) == "table")
check("lure subtable exists", type(s.lure) == "table")
check("vendor subtable exists", type(s.vendor) == "table")
check("safety subtable exists", type(s.safety) == "table")
check("session subtable exists", type(s.session) == "table")
print(" ST1 PASS: create() returns all 12 state subtables")

-- 2. initial defaults
check("fishing.status == 'Idle'", s.fishing.status == "Idle")
check("fishing.awaiting_bobber == false", s.fishing.awaiting_bobber == false)
check("fishing.consecutive_catches == 0", s.fishing.consecutive_catches == 0)
check("bite.pending == false", s.bite.pending == false)
check("safety.hard_stop == false", s.safety.hard_stop == false)
check("session.start_time == 100", s.session.start_time == 100)
check("session.catches == 0", s.session.catches == 0)
check("navigation.stop_distance == 15.0", s.navigation.stop_distance == 15.0)
print(" ST2 PASS: initial defaults are correct")

-- 3. reset_bite clears bite detection state
s.bite.pending = true
s.bite.detected_time = 42.5
s.bite.reaction_deadline = 50.0
s.bite.escape_deadline = 52.0
s.bite.should_miss = true
State.reset_bite(s)
check("reset_bite clears pending", s.bite.pending == false)
check("reset_bite clears detected_time", s.bite.detected_time == 0.0)
check("reset_bite clears reaction_deadline", s.bite.reaction_deadline == 0.0)
check("reset_bite clears escape_deadline", s.bite.escape_deadline == 0.0)
check("reset_bite clears should_miss", s.bite.should_miss == false)
print(" ST3 PASS: reset_bite() clears all bite fields")

-- 4. reset_fishing clears fishing + safety + equip + lure + nav + bag + bite
s.fishing.status = "Casting..."
s.fishing.awaiting_bobber = true
s.fishing.consecutive_catches = 7
s.fishing.no_bobber_count = 3
s.fishing.next_cast_time = 99.0
s.fishing.no_lure_warned = true
s.safety.hard_stop = true
s.session.time_limit_warned = true
s.equip.upgrade_announced = true
s.equip.pole_equip_delay_end = 12.0
s.lure.lure_apply_delay_end = 5.0
s.navigation.shoreline_no_route_count = 4
s.navigation.pool_face_update = 88.0
s.bag.full_confirm_count = 2
s.bite.pending = true
State.reset_fishing(s)
check("reset_fishing sets status Idle", s.fishing.status == "Idle")
check("reset_fishing clears awaiting_bobber", s.fishing.awaiting_bobber == false)
check("reset_fishing clears consecutive_catches", s.fishing.consecutive_catches == 0)
check("reset_fishing clears no_bobber_count", s.fishing.no_bobber_count == 0)
check("reset_fishing clears next_cast_time", s.fishing.next_cast_time == 0.0)
check("reset_fishing clears no_lure_warned", s.fishing.no_lure_warned == false)
check("reset_fishing clears hard_stop", s.safety.hard_stop == false)
check("reset_fishing clears time_limit_warned", s.session.time_limit_warned == false)
check("reset_fishing clears upgrade_announced", s.equip.upgrade_announced == false)
check("reset_fishing clears pole_equip_delay_end", s.equip.pole_equip_delay_end == 0.0)
check("reset_fishing clears lure_apply_delay_end", s.lure.lure_apply_delay_end == 0.0)
check("reset_fishing clears shoreline_no_route_count", s.navigation.shoreline_no_route_count == 0)
check("reset_fishing clears pool_face_update", s.navigation.pool_face_update == 0.0)
check("reset_fishing clears bag full_confirm_count", s.bag.full_confirm_count == 0)
check("reset_fishing calls reset_bite (bite.pending cleared)", s.bite.pending == false)
print(" ST4 PASS: reset_fishing() clears fishing + safety + equip + lure + nav + bag + bite")

-- 5. reset_shoreline_solver_cache
s.navigation.shoreline_solver_cache.key = "abc"
s.navigation.shoreline_solver_cache.next_retry_time = 30.0
s.navigation.shoreline_solver_cache.result = { x = 1 }
s.navigation.shoreline_solver_cache.result_radius = 15
State.reset_shoreline_solver_cache(s)
local cache = s.navigation.shoreline_solver_cache
check("reset_cache clears key", cache.key == nil)
check("reset_cache clears next_retry_time", cache.next_retry_time == 0.0)
check("reset_cache clears result", cache.result == nil)
check("reset_cache clears result_radius", cache.result_radius == nil)
print(" ST5 PASS: reset_shoreline_solver_cache() clears cache")

-- 6. create() is independent across instances (no shared mutable state)
local s2 = State.create(200)
s.bite.pending = true
check("create() instances are independent (s2.bite.pending unaffected)", s2.bite.pending == false)
check("create() session.start_time is per-instance", s2.session.start_time == 200)
print(" ST6 PASS: create() instances are independent")

-- 7. reset_bite is idempotent (safe to call on already-clean state)
State.reset_bite(s)
State.reset_bite(s)
check("reset_bite idempotent on clean state", s.bite.pending == false)
print(" ST7 PASS: reset_bite() idempotent")

print("PASS test_state_machine (" .. pass_count .. " assertions)")
os.exit(0)