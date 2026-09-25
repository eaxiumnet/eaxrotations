# Navigation reachability — a place the client cannot walk to is not offered again

## The loop this closes

Live log, `NAV` and `IDLE` trading places once a second:

```
IDLE: area goal — navigating to wp 8/9 (13yd)
State: IDLE → NAV
NAV: starting navigation
[SentinelNavClient] State navigating.awaiting_path -> arrived
NAV: arrived callback but still 13yd away (retry 44/3)
Navigation arrived but still far after 3 retries — giving up
State: NAV → IDLE
IDLE: area goal — navigating to wp 8/9 (13yd)
```

The client reports `arrived` for a waypoint it never walked to (it cannot path there), the
retry ladder gives up, and **IDLE offers the same coordinates one second later** — so the
step's other waypoints are never covered and the goal behind the step never progresses.
Two separate defects produce the identical log:

1. **The producer was not told.** `nav_state` knows the place is bad (`/nav unreachable` is
   its own state) and records it; the producers that choose where to walk never asked.
2. **The retry count outlived its destination.** The counter is reset on a step change and on
   a clean arrival, but the give-up path returned with whatever it had reached — `3`. Every
   walk afterwards through the same `shared` table started at `4/3`, `5/3`, … and was
   abandoned on its *first* `arrived` callback, however good a destination it was.

## What owns what

`shared/nav_destination.lua` owns the memory of **places** the client recently could not
reach, because three files have to agree on which place it was:

| Function | Meaning |
|---|---|
| `mark_unreachable(shared, now, point)` | remember that place, for `UNREACHABLE_FOR` (60s) |
| `recently_unreachable(shared, now, point)` | is this place still inside that window? |
| `retire_place(shared, point)` | refuse that place for the rest of the pass over the step's waypoints |
| `place_retired(shared, point)` | was this place refused in the current pass? |
| `retired_count(shared)` | how many places the pass has given up on |
| `clear_retired(shared)` | a new step, or a new pass: forget every refusal |

The set is keyed by **place** for the same reason the memory is. `idle_state`'s sweep reads
the step's waypoint list fresh every tick and that list can shift under it — the reader drops
any waypoint whose map conversion fails, and the guide's own list changes as goals complete —
so a refusal recorded against a *slot* would skip whichever waypoint later occupies that slot
(the live symptom, again: a walkable part of the path lost for the rest of the step).

A place is identified by its coordinates (tenths of a yard, as whole numbers so the question
costs no string per candidate per tick) and **nothing else**. It used to be identified by how
the destination was *classified* (`unit` / `wp` / `point`), and a destination that failed
while `nav_state` was walking its waypoint fallback was therefore remembered under a name the
producer could never reproduce — it handed the same coordinates straight back and the bot
re-walked them. A place is a place; the flags around it are bookkeeping. The place and its
expiry live in one field (`_nav_unreachable`), so nothing can copy or clear half of the memory.

## The rules

- **The producer skips it, and records the refusal against the place.** `idle_state`'s
  movement-only sweep asks about each of the step's waypoints before offering one, retires a
  blocked one, and walks to the next. The refusal is NOT written into the index-keyed
  `_visited_waypoints` (that is for waypoints it actually *reached*) — the slot a refusal was
  seen in says nothing about whatever ends up there next (`P16`).
- **A window, then a refusal that lasts the pass.** The memory expires on its own so a
  waypoint comes back into play (`P12d`), and the retirement is what continues to hold the
  skip after the window lapses: otherwise the bot spent itself on the same one or two points
  the navmesh reaches and never covered the rest of the path (`P13`, `P14`).
- **One attempt per waypoint per pass, then a bounded retry.** When the pass ends, the state
  hands over (`DO_ACTION`) rather than marching the path again; a new pass starts at most once
  per `SWEEP_RELAP_SECONDS` (60s), which is also the retry a refused waypoint gets — one a
  minute, not one a tick and not never (`P13d`, `P15`). A new *step* clears the refusals
  outright: what the client could not reach on the old path says nothing about the new one.
- **Nothing walkable left → wait.** When every candidate is blocked, the state returns
  `WAITING` instead of falling through to `DO_ACTION` or resetting its marks. Both of those
  are the same loop wearing a hat: `DO_ACTION` has nothing to act on at those coordinates,
  and clearing the marks re-offers the coordinates the client just refused. `WAITING`
  re-reads the guide on its 3s throttle and hands back to `IDLE` if the step changes.
- **The counter belongs to its destination.** The `arrived`-too-far give-up resets
  `_nav_retries`, so the next walk gets its own three attempts.
- **The memory is the nav owner's, not the producer's.** `nav_state` resolves it through the
  same module (`recently_unreachable`) at the point it would otherwise re-issue a failed
  destination, so a producer that has not been taught the rule still cannot loop on a place
  the client just refused.

## Tests

`tests/test_nav_state.lua` — **N17** the retry counter does not survive the destination it
counted (a fresh destination's first short arrival is retry 1, not a give-up), with the
give-up path itself asserted first; **N18** the same place is skipped however it was
classified (recorded while the waypoint-fallback flag was set, offered back as an ordinary
point with a rebuilt `Z`), the skipped place being dropped without a single instruction to
the client, and a control one yard away still walked. **N10** continues to pin that the
memory expires rather than latching.

`tests/test_idle_state.lua` — **P12** an unreachable waypoint is skipped for the next one,
the skip survives into the following tick, and the waypoint is offered again once the window
passes (with the no-memory control walking the nearest one). **P13** when the only waypoint
is unreachable-recent the state waits, offers no destination, keeps the mark, and keeps
making that same decision across further ticks — the no-progress case is stable rather than
alternating with `DO_ACTION`.

**P14/P15** a pass retires what the client cannot reach, covers the rest, and re-patrols only
after the cooldown (`P14d`'s third tick runs *past* the 60s memory window, so the retirement
is the only thing that can be holding the skip). **P16** a waypoint the list gains in front of
the refused one is still walked: the refusal follows the place, not the slot.

**8 mutants, 8 killed** for the reachability rules (the retry reset, the classification-tainted
identity, the expiring window, the `FAILED` skip, the per-candidate skip, the persistence of
the marks, the all-blocked branch, the "anything was blocked" flag), and **11 mutants, 11 killed**
for the sweep's coverage rules, each rule reverted alone with the file restored byte-identically
between runs: no retirement at all, the retirement not consulted, the pass-over reporting
`DO_ACTION` when everything was refused, the re-lap cooldown removed, a new pass not clearing its
marks, a new step not clearing them, the 60s memory not consulted, a refusal blocking every place,
the retirement keyed by slot rather than place (both the store and the query), and a refusal
stored under the wrong key.

## Not verifiable without the client

Everything here is decided before the hand-off: the place is judged, the walk is chosen. Why
`SentinelNavClient` reports `arrived` for a destination it did not reach is the client's
answer, and this pass does not guess at it. In game the fix's signal is that the log stops
repeating one waypoint — `IDLE: area goal — wp 8/9 is unreachable — retiring it for this
step` once, followed by `navigating to wp` at a *different* index — and, if the whole step is
unreachable, `none of the N step waypoints is reachable — waiting for the retry` rather than a
once-a-second ping-pong, with `re-patrolling the step's waypoints` at most once a minute.

## The arrival probe (2026-09-22)

`navigation_sylvanas.lua` now logs one line on **every** successful arrival:

```
[EaxAutoQuester] NAV arrival probe (<source>): dest=x,y,z player=x,y,z dist=<yd> client_state=<s> progress_index=<n>
```

`<source>` is `event` (the client's `arrived` event), `polled` (its top-level state read on
tick), or `fallback` (a simple_movement distance arrival). It fires through `fire_callback`,
so no arrival path can skip it, and it reads `_destination` which now survives
`stop_internal()` so the probe and the failure paths see the same lifetime.

This is the instrument for the live loop where `SentinelNavClient` reported `arrived` while
the player stood 13yd from the requested point: the scraped client doc (v0.0.8,
"Off-mesh targets auto-snap") says a slightly off-mesh target is snapped to the nearest
reachable point and the `arrived` event carries no payload, so the shortfall was previously
invisible. The probe records the requested destination against the player's actual position
each time, so a snap shows up as a recurring non-zero `dist` on the same `dest`.

What to look for in game: `dist=` persistently non-zero on one `dest=` identifies the
off-mesh point (check its `z` against the player's — the doc names wrong/unknown `z` as the
common cause); `progress_index` stuck at the same value says the client considered its
snapped path finished. The movement-only `idle_state` sweep now runs every step waypoint
through the same terrain-height owner before selection and caches the repaired vec3 by
place, so a guide point is not published with its raw `z=0`. A persistent shortfall after
that is evidence about the source coordinates or the client's navmesh, not an un-fixed
area waypoint.

Pinned by C14–C14d in `tests/test_nav_client_contract.lua` (probe fires on all three
arrival paths with the right source label, records dest/player/dist, stays silent on a
failed navigation) and P18 in `tests/test_idle_state.lua` (terrain-fixed publication and
one-query caching); M1 mutant confirms the suite fails when the probe is removed.
