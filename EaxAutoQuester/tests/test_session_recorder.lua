-- What: EaxAutoQuester/session_recorder_sylvanas.lua — bounded session capture and JSONL export.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: a live quest-loop failure is a sequence of state, waypoint, and navigation decisions. The
--       recorder must preserve that sequence without allocating per tick or requiring file I/O.
-- Safety: pure in-memory module with a mocked clock; no client, network, or filesystem writes.

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local recorder = require("session_recorder_sylvanas")

-- R1 — recording is opt-in and a disabled recorder is a no-op.
recorder.reset()
assert(recorder.is_enabled() == false, "R1a FAIL: a fresh recorder must be disabled")
assert(recorder.record_log("ignored") == false, "R1b FAIL: a disabled recorder must not record")
assert(recorder.count() == 0, "R1c FAIL: a disabled recorder must stay empty")

-- R2 — start, structured events, log lines, and stop produce chronological JSONL.
recorder.start(100)
assert(recorder.is_enabled() == true, "R2a FAIL: start must enable capture")
recorder.record_event("waypoint_selected", {
    index = 3,
    x = 10,
    y = 20,
    z = 91.5,
    raw_z = 0,
    terrain_fixed = true,
}, 101)
recorder.record_log("NAV: arrived", 102)
local jsonl = recorder.stop(103)
assert(recorder.is_enabled() == false, "R2b FAIL: stop must disable capture")
assert(jsonl:find('"kind":"session_start"', 1, true), "R2c FAIL: the session start marker is missing")
assert(jsonl:find('"kind":"waypoint_selected"', 1, true), "R2d FAIL: the structured event is missing")
assert(jsonl:find('"raw_z":0', 1, true), "R2e FAIL: scalar event fields must survive export")
assert(jsonl:find('"terrain_fixed":true', 1, true), "R2f FAIL: boolean event fields must survive export")
assert(jsonl:find('"message":"NAV: arrived"', 1, true), "R2g FAIL: the log line is missing")
assert(jsonl:find('"kind":"session_stop"', 1, true), "R2h FAIL: the stop marker is missing")
local start_at = jsonl:find('"kind":"session_start"', 1, true)
local event_at = jsonl:find('"kind":"waypoint_selected"', 1, true)
local stop_at = jsonl:find('"kind":"session_stop"', 1, true)
assert(start_at < event_at and event_at < stop_at, "R2i FAIL: events must export in sequence order")

-- R3 — escaping keeps a log line one valid JSONL record.
recorder.start(200)
recorder.record_log('quote " slash \\ newline\nend', 201)
jsonl = recorder.stop(202)
assert(not jsonl:find('newline\nend', 1, true), "R3a FAIL: a newline must be escaped inside JSONL")
assert(jsonl:find('newline\\nend', 1, true), "R3b FAIL: the escaped newline is missing")

-- R4 — the ring is bounded: a long session cannot grow without limit.
recorder.start(300)
local capacity = recorder.capacity()
for i = 1, capacity + 25 do recorder.record_log("event " .. tostring(i), 300 + i) end
assert(recorder.count() == capacity, "R4a FAIL: the recorder exceeded its fixed capacity")
jsonl = recorder.stop(1000)
local event_count = 0
for _ in jsonl:gmatch('"kind":"log"') do event_count = event_count + 1 end
assert(event_count == capacity - 1,
    "R4b FAIL: the bounded export must contain the newest capacity-sized window, got " ..
    tostring(event_count))
assert(jsonl:find('"message":"event 1"', 1, true) == nil,
    "R4c FAIL: the oldest events must be evicted")
assert(jsonl:find('"message":"event ' .. tostring(capacity + 25) .. '"', 1, true) ~= nil,
    "R4d FAIL: the newest event must remain")

print("PASS test_session_recorder")
os.exit(0)
