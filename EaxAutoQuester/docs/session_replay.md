# Session recording and replay

What: capture one live quest-loop decision sequence, export it as JSONL, and replay it against a
small contract that turns the observed failure into a non-zero test result.

Why: a live bug such as `arrived callback but still 13yd away` is not a single assertion. It is a
sequence: a waypoint was selected, NAV received a destination, the client reported arrival short,
and IDLE offered or retired the place again. The recorder preserves that sequence. The replay
runner treats the log as data, never as code.

## Capture a live session

Recording is opt-in and bounded to 2,048 preallocated events. It does not write files, use the
network, or change the menu's debug-output setting. From the live quester console or a developer
bridge, use the exported state-machine API:

```lua
local quester = EaxAutoQuester.quest_state
quester.start_session_recording()
-- reproduce the bug in the client
local session_jsonl = quester.stop_session_recording()
```

`start_session_recording()` clears the previous in-memory session. `stop_session_recording()`
returns chronological JSONL and includes `session_start`/`session_stop` markers. The supported
client surface has no file-write API, so the plugin deliberately returns the string rather than
inventing a persistence path. Pass it to the normal client log capture, or save it from the
developer tooling used to run the console command.

The recorder also exports itself as `EaxAutoQuester.session_recorder` for direct tooling. The
quester feeds it existing log lines plus structured events for state transitions, selected area
waypoints, short arrivals, successful arrivals, unreachable waypoint retirement, and abandoned
navigation destinations. A missing recorder is a no-op.

## Replay it as a test

The runner accepts either recorder JSONL or a raw client log:

```bash
python EaxAutoQuester/tools/replay_session.py session.jsonl
python EaxAutoQuester/tools/replay_session.py live-client.log
cat live-client.log | python3 EaxAutoQuester/tools/replay_session.py -
```

A passing session prints `PASS` and exits zero. A session with a contract violation prints the
source line, rule, and place, then exits one, making it usable as a CI check or a failing test
command. The current rules are:

- `short_arrival`: NAV reports arrival while the player is still away from the destination;
- `raw_waypoint_z`: an area waypoint with raw `z=0` is selected while the terrain owner reports
  that it was not repaired;
- `retired_waypoint`: the area sweep retires a waypoint as unreachable;
- `abandoned_destination`: NAV gives up after the retry ladder.

The raw-log fallback recognizes the human log forms of the same symptoms, so an older client log
can become a regression check without being re-recorded. A session with no violations is not proof
that the quest is correct; it proves only that these named loop symptoms did not occur.

## Development self-test

The runner has no third-party dependencies and carries its own contract test:

```bash
python EaxAutoQuester/tools/replay_session.py --self-test
```

It proves a repaired session passes, a short-arrival/retirement session fails, and raw client log
fallback detects both symptoms. `tests/test_session_recorder.lua` separately proves the Lua ring's
opt-in behavior, JSONL escaping, chronological ordering, and fixed-capacity eviction.
