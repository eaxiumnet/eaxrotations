#!/usr/bin/env python3
"""Replay a recorded EaxAutoQuester session as a small regression contract.

The recorder emits JSONL, but this runner also accepts a raw client log. A session fails when it
contains one of the quest-loop symptoms the recorder is meant to turn into a regression:

* a NAV arrival that is still away from its destination;
* an area waypoint published with raw z=0 and no terrain repair;
* a waypoint retired as unreachable, or a destination abandoned after retries.

The runner has no project dependencies and never executes a recorded message. It treats a log as
 data, applies deterministic rules, prints one finding per line, and exits non-zero on a failure.
That makes it suitable for CI or for a developer's post-reproduction command.

Usage:
  python3 EaxAutoQuester/tools/replay_session.py session.jsonl
  python3 EaxAutoQuester/tools/replay_session.py live-client.log
  cat live-client.log | python3 EaxAutoQuester/tools/replay_session.py -
  python3 EaxAutoQuester/tools/replay_session.py --self-test
"""

import argparse
import json
import re
import sys
from typing import Any, Dict, Iterable, List


SHORT_ARRIVAL_RE = re.compile(
    r"arrived\s+(?:callback\s+)?but\s+still\s+\d+(?:\.\d+)?\s*yd", re.IGNORECASE
)
RETIRED_WAYPOINT_RE = re.compile(
    r"(?:is\s+unreachable\s*[—:-]\s*retiring|waypoint\s+.*\bretir(?:ed|ing)\b)",
    re.IGNORECASE,
)
ABANDONED_RE = re.compile(
    r"(?:giving\s+up|after\s+3\s+retries|abandon(?:ed|ing))", re.IGNORECASE
)


def _event_message(event: Dict[str, Any]) -> str:
    value = event.get("message", "")
    return str(value) if value is not None else ""


def _location(event: Dict[str, Any]) -> str:
    parts = []
    for key in ("x", "y", "z"):
        if event.get(key) is not None:
            parts.append("%s=%s" % (key, event[key]))
    return " ".join(parts) if parts else "unknown place"


def _finding(line: int, rule: str, detail: str) -> Dict[str, Any]:
    return {"line": line, "rule": rule, "detail": detail}


def parse_session(lines: Iterable[str]) -> List[Dict[str, Any]]:
    """Parse recorder JSONL, accepting raw log lines as message-only events."""
    events: List[Dict[str, Any]] = []
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        try:
            value = json.loads(line)
        except (TypeError, ValueError):
            value = None
        if isinstance(value, dict):
            event = dict(value)
            event.setdefault("kind", "log")
            events.append(event)
        else:
            events.append({"kind": "log", "message": line})
    return events


def replay_events(events: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Return contract violations; an empty list is a passing replay."""
    findings: List[Dict[str, Any]] = []
    short_places: Dict[str, int] = {}

    for line, event in enumerate(events, 1):
        kind = str(event.get("kind", "log"))
        message = _event_message(event)

        if kind == "waypoint_selected":
            # This is a recorder contract, not a claim that every real-world z=0 point is bad:
            # the event must explicitly say that the terrain owner was not applied.
            if event.get("raw_z") == 0 and event.get("terrain_fixed") is False:
                findings.append(_finding(
                    line,
                    "raw_waypoint_z",
                    "area waypoint %s was selected with raw z=0 and terrain_fixed=false"
                    % _location(event),
                ))

        if kind == "nav_short_arrival" or SHORT_ARRIVAL_RE.search(message):
            place = _location(event)
            short_places[place] = short_places.get(place, 0) + 1
            suffix = ""
            if short_places[place] > 1:
                suffix = " (repeat %d for the same place)" % short_places[place]
            findings.append(_finding(
                line,
                "short_arrival",
                "NAV reported arrival away from its destination at %s%s" % (place, suffix),
            ))

        if kind == "waypoint_retired" or RETIRED_WAYPOINT_RE.search(message):
            findings.append(_finding(
                line,
                "retired_waypoint",
                "the sweep retired a waypoint as unreachable at %s" % _location(event),
            ))

        if kind == "nav_abandoned" or ABANDONED_RE.search(message):
            findings.append(_finding(
                line,
                "abandoned_destination",
                "navigation gave up on a destination at %s" % _location(event),
            ))

    return findings


def _self_test() -> int:
    good = [
        {"kind": "session_start", "capacity": 2048},
        {"kind": "waypoint_selected", "raw_z": 0, "terrain_fixed": True,
         "x": 10, "y": 20, "z": 91.5},
        {"kind": "nav_arrived", "x": 10, "y": 20, "z": 91.5},
        {"kind": "session_stop", "count": 4},
    ]
    if replay_events(good):
        raise AssertionError("good session unexpectedly failed replay")

    bad = [
        {"kind": "waypoint_selected", "raw_z": 0, "terrain_fixed": False,
         "x": 10, "y": 20, "z": 0},
        {"kind": "nav_short_arrival", "x": 10, "y": 20, "z": 0, "distance_yds": 13},
        {"kind": "nav_short_arrival", "x": 10, "y": 20, "z": 0, "distance_yds": 13},
        {"kind": "waypoint_retired", "x": 10, "y": 20, "z": 0},
    ]
    findings = replay_events(bad)
    rules = {finding["rule"] for finding in findings}
    if rules != {"raw_waypoint_z", "short_arrival", "retired_waypoint"}:
        raise AssertionError("bad session missed rules: %r" % sorted(rules))

    raw = parse_session([
        "[EaxAutoQuester-DEBUG] NAV: arrived callback but still 13yd away (retry 1/3)",
        "[EaxAutoQuester-DEBUG] IDLE: area goal - wp 2/9 is unreachable - retiring it for this step",
    ])
    if len(replay_events(raw)) != 2:
        raise AssertionError("raw live-log fallback did not detect both symptoms")

    print("replay_session self-test PASS")
    return 0


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("session", nargs="?", help="JSONL recorder export or raw live log; use - for stdin")
    parser.add_argument("--self-test", action="store_true", help="run the embedded parser/rule test")
    args = parser.parse_args(argv)

    if args.self_test:
        return _self_test()
    if not args.session:
        parser.error("a session path is required (or use --self-test)")

    try:
        if args.session == "-":
            events = parse_session(sys.stdin)
        else:
            with open(args.session, "r", encoding="utf-8", errors="replace") as handle:
                events = parse_session(handle)
    except OSError as exc:
        print("FAIL: cannot read session: %s" % exc, file=sys.stderr)
        return 2

    findings = replay_events(events)
    if not findings:
        print("PASS: %d event(s), no replay contract violations" % len(events))
        return 0

    print("FAIL: %d replay contract violation(s) in %d event(s)" % (len(findings), len(events)))
    for finding in findings:
        print("  line %d [%s] %s" % (finding["line"], finding["rule"], finding["detail"]))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
