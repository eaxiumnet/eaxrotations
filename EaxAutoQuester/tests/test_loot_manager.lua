-- What: Unit tests for EaxAutoQuester/loot_manager_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify loot window processing and auto-loot scanning
-- Safety: pins the 0 BASED loot index range (.api/core.lua:1025 — "Every loot index
--         below is 0 based, running 0 to this count minus 1"), gold priority, and that
--         a window which compacts as slots are taken still loses nothing. Addressing
--         these slots 1-based skips the first slot and reads one past the end.
--         Item 14 adds: bag space read from the documented owner (the raw
--         get_items_in_bag/get_num_bag_slots pairing is shifted by one and answers 0 for
--         bag 0 on every build), containers opened with use_object because loot_object
--         refuses anything that is not a unit, and the LOOT_BIND_CONFIRM answer carrying
--         the event's 1-based slot converted to the 0-based one confirm_loot_slot wants.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- mock.reset() restarts the clock at 0 while the loot throttle remembers absolute times, so
-- every reset after the first has to step the clock past the cycles this suite already ran,
-- or the next auto_loot_all is silently throttled away.
-- The clock has to keep moving FORWARD across a reset: the throttle compares against the last
-- cycle's stamp, so landing behind it silently throttles the next cycle away.
local _clock = 0
local function reset_time()
    mock.reset()
    _clock = _clock + 100.0
    mock.set_time(_clock)
end

local player = mock.create_player({ pos = {x=0, y=0, z=0} })

--- Every loot_item index passed to the mock, in call order.
local function loot_calls()
    local out = {}
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "loot_item" then out[#out + 1] = call[2] end
    end
    return out
end

-- ============================================================================
-- S1: try_loot with no loot window
-- ============================================================================
local loot_manager = require("loot_manager_sylvanas")

-- ============================================================================
-- S0: bag space comes from the documented owner, not from the raw pairing
-- ============================================================================
-- The raw read paired get_items_in_bag(N) with get_num_bag_slots(N): the two bindings are
-- shifted by one and get_num_bag_slots(0) answers 0 on EVERY build (.api/core.lua:906-929),
-- while get_items_in_bag(0) is the whole player container rather than the backpack (:859-876).
-- This fixture is that reality — raw total 64, raw used 65 — while the mini-lib's own totals
-- say 80 capacity with 65 used, i.e. 15 free.
mock._bag_slots = { [0] = 0, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
mock._bag_items = {}
for bag_id = 0, 4 do
    mock._bag_items[bag_id] = {}
    for i = 1, 13 do
        local item_id = 1000 + bag_id * 100 + i
        mock._bag_items[bag_id][i] = { object = { get_item_id = function() return item_id end } }
    end
end
local s0_corpse = mock.create_object({ pos = {x=2, y=0, z=0}, name = "Corpse", lootable = true, valid = true, unit = true })
mock._objects = { s0_corpse }

-- S0a: mini-lib absent -> the bag state is unknown -> loot anyway (never invent numbers)
mock.uninstall_inventory_helper()
mock.set_time(mock.get_time() + 1.0)
mock._input_calls = {}
assert(loot_manager.auto_loot_all(5) == true,
    "S0a FAIL: an unreadable bag state must not stop looting")
print("  S0a PASS: no inventory_helper -> bag state unknown -> loot anyway")

-- S0b: mini-lib present -> its totals are the gate (15 free). The old raw pairing computed
-- 64 - 65 -> 0 free and skipped looting entirely.
mock.install_inventory_helper()
mock._helper_capacity = 80
mock.set_time(mock.get_time() + 1.0)
mock._input_calls = {}
assert(loot_manager.auto_loot_all(5) == true,
    "S0b FAIL: the documented totals leave 15 free slots, so looting must proceed")
print("  S0b PASS: bag space read from inventory_helper totals (raw pairing said 0 free)")

reset_time()
local result = loot_manager.try_loot()
assert(result == false, "S1 FAIL: try_loot should return false when no loot window")
print("  S1 PASS: no loot window -> false")

-- ============================================================================
-- S2: every 0-based slot is looted exactly once, and gold goes first
-- ============================================================================
mock._loot_items = {
    { id = 1, name = "Sword", is_gold = false },   -- slot 0
    { id = 2, name = "Gold",  is_gold = true  },   -- slot 1
    { id = 3, name = "Shield", is_gold = false },  -- slot 2
}
mock._input_calls = {}

result = loot_manager.try_loot()
assert(result == true, "S2a FAIL: try_loot should return true when loot window open")

local calls = loot_calls()
local seen, dup = {}, nil
for _, idx in ipairs(calls) do
    if seen[idx] then dup = idx end
    seen[idx] = true
end
assert(not dup, "S2b FAIL: slot " .. tostring(dup) .. " was looted twice")
assert(seen[0] and seen[1] and seen[2],
    "S2c FAIL: every slot 0..2 must be looted, got " .. table.concat(calls, ","))
assert(not seen[3], "S2d FAIL: index 3 is out of range for a 3 slot window (slots 0..2)")
assert(calls[1] == 1, "S2e FAIL: the gold slot (1) must be looted first, got " .. tostring(calls[1]))
assert(mock._input_calls[#mock._input_calls][1] == "close_loot",
    "S2f FAIL: the loot window must be closed after processing")
print("  S2 PASS: 0-based slots, gold priority, no out-of-range index")

-- ============================================================================
-- S3: a window that compacts as slots are looted loses nothing
-- ============================================================================
-- Real windows compact: taking a slot removes it and the ones above renumber.
-- Capturing the window once and then walking it by ascending index therefore
-- skips slots (and reads past the end). Same fixtures, compaction on.
reset_time()
mock._loot_items = {
    { id = 1, name = "Sword", is_gold = false },
    { id = 2, name = "Gold",  is_gold = true  },
    { id = 3, name = "Shield", is_gold = false },
}
mock._loot_compacts = true
mock._input_calls = {}

result = loot_manager.try_loot()
assert(result == true, "S3a FAIL: try_loot should return true")

local expected = { "Gold", "Shield", "Sword" }
assert(#mock._looted_names == 3,
    "S3b FAIL: all 3 items must be looted when the window compacts, looted " ..
    tostring(#mock._looted_names) .. " (" .. table.concat(mock._looted_names, ",") .. ")")
for n = 1, 3 do
    assert(mock._looted_names[n] == expected[n],
        "S3c FAIL: looted order should be " .. table.concat(expected, ",") ..
        ", got " .. table.concat(mock._looted_names, ","))
end
print("  S3 PASS: compacting window still loots every item, gold first")

-- ============================================================================
-- S4: auto_loot_all with no lootable objects
-- ============================================================================
reset_time()
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock._objects = {}
local auto_loot = loot_manager.auto_loot_all(5)
assert(auto_loot == false, "S4 FAIL: auto_loot_all should return false with no lootable objects")
print("  S4 PASS: no lootable objects -> false")

-- ============================================================================
-- S5: auto_loot_all with lootable object
-- ============================================================================
local lootable = mock.create_object({ pos = {x=2, y=0, z=0}, name = "Corpse", lootable = true, valid = true, unit = true })
mock._objects = { lootable }
mock.set_time(mock.get_time() + 1.0)  -- advance time past the 0.5s loot throttle
auto_loot = loot_manager.auto_loot_all(5)
assert(auto_loot == true, "S5 FAIL: auto_loot_all should return true with lootable object")
print("  S5 PASS: lootable object -> true")

-- ============================================================================
-- S6: close() actually closes the loot window
-- ============================================================================
reset_time()
mock._input_calls = {}
loot_manager.close()
local closed = false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "close_loot" then closed = true end
end
assert(closed, "S6 FAIL: close() must call close_loot, calls: " ..
    tostring(#mock._input_calls))
print("  S6 PASS: close() closes the loot window")

-- ============================================================================
-- S7: containers go through use_object, units keep loot_object
-- ============================================================================
-- "loot_object ... UNITS AND CORPSES ONLY. The native path rejects anything that is not a unit
-- and answers false straight away, so a fishing bobber, chest, herb node or ore node cannot be
-- looted through this" (.api/core.lua:2121); use_object is "the entry point for world objects
-- rather than units" (:2143). A chest sent to loot_object answered false, left the container
-- shut, and was still counted as handled.
reset_time()
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
local chest = mock.create_object({ pos = {x=2, y=0, z=0}, name = "Chest", lootable = true, valid = true, unit = false })
local corpse = mock.create_object({ pos = {x=3, y=0, z=0}, name = "Corpse", lootable = true, valid = true, unit = true })
mock._objects = { chest, corpse }
mock.set_time(mock.get_time() + 1.0)
mock._input_calls = {}
loot_manager.auto_loot_all(5)

local opened_chest, sent_chest_to_loot, looted_corpse = false, false, false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "use_object" and call[2] == chest then opened_chest = true end
    if call[1] == "loot_object" and call[2] == chest then sent_chest_to_loot = true end
    if call[1] == "loot_object" and call[2] == corpse then looted_corpse = true end
end
assert(opened_chest, "S7a FAIL: a container must be opened with use_object")
assert(not sent_chest_to_loot,
    "S7b FAIL: loot_object refuses non-units, so a chest must never be sent to it")
assert(looted_corpse, "S7c FAIL: a corpse must still go through loot_object")
print("  S7 PASS: containers -> use_object, units -> loot_object")

-- ============================================================================
-- S9: a BoP slot's bind prompt is answered 0-based, and the window stays open
-- ============================================================================
-- The prompt is the plugin's own action: this pass looted the slot. "WoW's own
-- LOOT_BIND_CONFIRM event reports the 1 BASED slot, so forwarding args[1] straight from that
-- event confirms the wrong slot: subtract one first" (core.input.confirm_loot_slot).
local bridge = require("quest_frame_events_sylvanas")
reset_time()
mock._input_calls = {}
mock._loot_items = { { id = 5000, name = "Bind Item" } }
bridge.on_game_event("LOOT_BIND_CONFIRM", { 1 })
local processed = loot_manager.try_loot()
assert(processed == true, "S9a FAIL: the pass should report a processed loot window")

local confirm_slot, closed_early = nil, false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "confirm_loot_slot" then confirm_slot = call[2] end
    if call[1] == "close_loot" then closed_early = true end
end
assert(confirm_slot == 0,
    "S9b FAIL: event slot 1 is the 0-based slot 0; got " .. tostring(confirm_slot))
assert(not closed_early,
    "S9c FAIL: the window must stay open while the client releases the held item")
print("  S9 PASS: LOOT_BIND_CONFIRM answered 0-based, window left open")

-- Next tick: the prompt is consumed, so the item is taken and the window closes.
mock._input_calls = {}
loot_manager.try_loot()
local confirmed_again, closed_now = false, false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "confirm_loot_slot" then confirmed_again = true end
    if call[1] == "close_loot" then closed_now = true end
end
assert(not confirmed_again, "S9d FAIL: a consumed prompt must not be answered twice")
assert(closed_now, "S9e FAIL: with no prompt outstanding the pass must close the window")
print("  S9 PASS: released slot taken next tick, window closed")

-- No prompt pending -> nothing is confirmed (this is what kills an always-confirm version).
reset_time()
mock._input_calls = {}
mock._loot_items = { { id = 5001, name = "Plain Item" } }
loot_manager.try_loot()
for _, call in ipairs(mock._input_calls) do
    assert(call[1] ~= "confirm_loot_slot",
        "S9f FAIL: no bind prompt was pending, so there is nothing to confirm")
end
print("  S9 PASS: no prompt pending -> no confirm call")

print("PASS test_loot_manager")
os.exit(0)
