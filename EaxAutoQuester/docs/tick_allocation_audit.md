# Per-state tick allocation audit — every coordinator state, down to zero

`tests/test_tick_allocation.lua` measures the real `coordinator.update()` per coordinator state,
driven by `tests/mock_core` with the collector stopped (gross bytes per tick, n=300 and n=1000,
pinned Lua 5.1.5). When the per-state half was added it covered five states (T10-T14), three of
them non-zero with their bounds recorded as *ratchets* around measured debt; this pass closes that
debt and adds the sixth state (DO_ACTION, T18). A later pass adds a seventh scenario, T19, for the
path the bot spends most of its life on — IDLE while it evaluates a goal, which the T11 fixture
(mid-cast) cannot reach. **All seven bounds are now 8 B** (measured + 8, against a run-to-run
spread under 1.5 B), so any added per-tick allocation fails in its own state — down to a single
no-upvalue closure, which costs 20 B.

Nothing here is a behaviour change, and nothing here is asserted: the four fixes are the hoisting
and reuse the attribution named, each is killed by a mutant that reinstates exactly it, and the
whole tick sequence is proven identical to the pre-change tree by transcript diff (section 4).
The sixth state is a coverage addition only — it measured zero — and section 5 states exactly how
far its fixture reaches and what it leaves uncovered.

---

## 1. Measured, before and after

| state | before (n=300 / n=1000) | after | bound | what it was |
|---|---|---|---|---|
| WAITING | -0.43 / 0.00 | -0.43 / 0.00 | 8 | clean already |
| IDLE | 388.07 / 387.89 | **0.07 / -0.11** | 8 | seven inline `pcall(function() ... end)` closures in `idle_state.run`'s head |
| INTERACT | 320.31 / 319.97 | **0.31 / -0.03** | 8 | two fresh three-field step-info tables per tick |
| NAV | 385.24 / 384.29 | **1.24 / 0.29** | 8 | `nav_state`'s combat probe, `navigation.update`'s fallback mover probes, `mount_manager.update`'s four probes |
| DEAD | 0.00 / -0.13 | 0.00 / -0.13 | 8 | clean already |
| DO_ACTION | not measured | 0.00 / -0.13 | 8 | clean, but only its wait tick is pinnable — section 5 |
| IDLE (goal evaluation, T19) | 120.79 / 120.24 | **0.45 / 0.14** | 8 | two fresh `{}` defaults on the tick path and a per-tick closure inside `object_scanner` — section 6 |

Two independent runs at both sizes gave the same numbers to the hundredth, and the suite
reproduces them.

## 2. The four fixes

| # | Site | Fix | Evidence |
|---|------|-----|----------|
| 1 | `quest_state/idle_state.lua:83`, `:89`, `:102`, `:146`, `:147` | `unit_is_dead(u)`, `unit_get_health(u)`, `unit_aura_read(u, method)`, `unit_is_casting(u)`, `unit_is_channelling(u)` — the unit is passed to the pcall instead of captured in a fresh closure | 388.07 → 0.07 B/tick; the death check alone paid three closures a tick, plus one per aura method scanned (the method list `{ "get_buffs", "get_auras", "get_debuffs" }` was a fresh table literal per tick too, now `AURA_METHODS`) |
| 2 | `zygor_reader_sylvanas.lua:90-105` (`get_current_step_info`) | ONE module-level `_step_info` refreshed in place (Pattern 4) instead of a fresh three-field table per call; the empty-goals case reuses one `_EMPTY_GOALS` | 320.31 → 0.31 B/tick; `interact_state.lua:61` and `:99` both ask for it in the same tick (flight-path section, then the frame handler), and `do_action_state` asks twice in its area branch |
| 3 | `quest_state/nav_state.lua:31` | `unit_is_in_combat(u)` hoisted | part of 385.24 → 1.24 |
| 4 | `navigation_sylvanas.lua:835`, `:838`, `:845` (fallback tick) and `:150`/`:152` (`stop_internal`) | `mover_process(mover)`, `unit_get_position(u)`, `mover_is_moving(mover)`, `mover_stop(mover)`, `client_stop(client)` hoisted; the duplicate `unit_get_position` in the render half is now defined once, at the top of the file | part of 385.24 → 1.24; the mount half measured 225 B/tick of the 385 |
| 5 | `mount_manager_sylvanas.lua:35`, `:44`, `:72`, `:107` (+ the two dismount calls) | `unit_is_mounted(u)`, `unit_is_in_combat(u)`, `unit_get_position(u)`, `input_mount(idx)`, `input_dismount()` hoisted | part of 385.24 → 1.24 |

`pcall(fn, arg)` is not a behaviour change: the same function runs, with the same error caught and
the same value returned. The probes are module-level, so nothing is created per call.

### Why the step-info reuse cannot leak state

`get_current_step_info`'s only caller-visible fields are `step_num`, `is_complete` and `goals`,
and the returned table is now valid **for the call that returned it**. That is safe here because,
verified across production code rather than assumed:

* No caller stores it. All nine production call sites (`do_action_state.lua:391`, `:414`, `:909`,
  `:1032`; `idle_state.lua:234`, `:283`; `nav_state.lua:72`; `interact_state.lua:61`, `:99`) read
  fields inside the same call and drop the reference.
* No caller mutates it. The only writes to `step_num` / `is_complete` / `goals` in the tree are
  inside the reader itself.
* Its use of `ctx.safe(step.goals, …)` and `#goals` iteration is unchanged, and the empty-goals
  table is read-only (nothing in the tree writes into `goals`).

The function header says all of this in place, so a future caller that wants to keep the table is
warned where it would read it.

## 3. Mutants — each killed by its own state, and only that state

One reinstated allocation at a time, each file restored byte-identically afterwards (`cmp` against
a backup copy). The probe used prints all five states in one run, so "only that state" is
measured rather than asserted.

| mutant | reinstated | all five states (n=300) | gate |
|---|---|---|---|
| A | the inline `is_dead` closure in `idle_state` | **IDLE 56.07** (was 0.07); WAITING -0.43, INTERACT 0.31, NAV 1.24, DEAD 0.00 unchanged | `T11e FAIL: the IDLE tick allocated 56.07 B/tick (n=300) and 55.89 B/tick (n=1000), bound is 8` |
| B | the fresh table in `zygor_reader` | **INTERACT 320.31** (was 0.31); the other four unchanged | `T12e FAIL: the INTERACT tick allocated 320.31 B/tick (n=300) and 319.97 B/tick (n=1000), bound is 8` |
| C | the inline `is_mounted` closure in `mount_manager` | **NAV 113.24** (was 1.24); the other four unchanged | `T13e FAIL: the NAV tick allocated 113.24 B/tick (n=300) and 112.29 B/tick (n=1000), bound is 8` |

Mutant B reproduces the pre-change INTERACT number exactly (320.31 / 319.97), which is the
strongest available confirmation that the attribution and the fix are the same thing.

## 4. The proof of no behaviour change

A scripted 60-tick sequence drives the real coordinator through every state in one transcript
(`tests/_probe_ab.lua` during the pass, removed before staging): no guidance, a bare step, a loot
window with a gold slot between two items, a mid-cast gather channel, a waypoint 70yd away, a
combat override, death, a goal step, then guidance disappearing. Each tick records the state, the
navigation state, every recorded input call and every `debug_log` line — and no allocation
numbers. The same script was run against a shadow copy of the tree whose five changed files were
restored from `HEAD`:

* 144 lines, covering all five measured states plus DO_ACTION (WAITING 7, IDLE 8, INTERACT 6,
  NAV 12, DEAD 5, DO_ACTION 8), 52 log lines, 6 input-call lines — including the loot walk
  `loot_item(1) loot_item(2) loot_item(0) close_loot()`, i.e. the gold-first, compaction-surviving
  walk inside INTERACT, the state whose per-tick cost this pass removed.
* `diff /tmp/tr_before.txt /tmp/tr_after.txt` prints **nothing**: the transcripts are byte-identical.

## 5. DO_ACTION (T18) — the sixth state, and what its fixture can and cannot cover

`DO_ACTION` was the one coordinator state the gate never covered, even though the pass above
showed the machine really ticking there. The gate now drives it too: **0.00 / −0.13 B/tick,
settled in DO_ACTION, its handler entered on every tick (305/1005) with no other handler running,
bound 8**.

That number needed a fixture decision, and the honest version of it is narrower than the other
five, so it is recorded here rather than implied:

| fixture shape tried | where it settled | measured (n=300) | why it cannot be the T18 fixture |
|---|---|---|---|
| area goal, no NPC, **frozen clock** | DO_ACTION, pure | **0.00** | this is T18 — but see below: the measured tick is the armed wait, not an evaluation |
| area goal, no NPC, clock **+0.1/tick** | DO_ACTION (295/300) | 13.51 amortized | 5 evaluation cycles (25 step-info reads, 5 NPC/enemy scans) and 5 one-tick IDLE hand-offs: the purity assertion *correctly* fails |
| area goal, no NPC, clock **+0.5/tick** | DO_ACTION (275/300) | 33.03 amortized | same, 25 cycles and 25 hand-offs in the window |
| `kill` goal, quest mob present | **IDLE** | 224.79 | the kill branch acts and returns IDLE on its first tick |
| `use` goal, crate present | **IDLE** | 176.74 | the use branch acts and returns IDLE on its first tick |

The structural reason, from the handler itself (`do_action_state.lua:1010-1030`, `:1100-1110`):
DO_ACTION is **transient**. Every acting branch finishes by returning `"IDLE"` (after arming an
action-pause), and the only path that returns `"DO_ACTION"` is an armed wait
(`shared._area_wait_timer` / `shared._action_pause_timer`, compared against `ctx.now`). With the
mock clock frozen, the measured tick is therefore the wait's early return, and the state's
evaluation path is *not* in the measurement window. With the clock advancing, the evaluation runs
— and the tick necessarily alternates with IDLE, so the purity assertion the other five states
satisfy cannot hold. No fixture satisfies both, and inventing one would mean changing behaviour.

So the T18 bound is honest about its scope: it pins that **entering DO_ACTION and holding in its
wait costs nothing**, which is where this state spends its steady time, and it does not claim to
bound the evaluation path. Both mutants were applied to the entry path (the precedent the other
five states used) and each fails T18 and only T18:

| mutant | all six states (n=300) | gate |
|---|---|---|
| E — a no-op `pcall(function() end)` at the top of `M.run` | **DO_ACTION 20.00**; the other five unchanged | `T18e FAIL: the DO_ACTION tick allocated 20.00 B/tick (n=300) and 19.87 B/tick (n=1000), bound is 8` |
| F — `local _t = { now = ctx.now }` at the top of `M.run` | **DO_ACTION 64.00**; the other five unchanged | `T18e FAIL: the DO_ACTION tick allocated 64.00 B/tick (n=300) and 63.87 B/tick (n=1000), bound is 8` |

### What the DO_ACTION measurement surfaced instead

Chasing the evaluation path turned up a real, *unbounded* cost on the live path — in **IDLE**, not
DO_ACTION: with a goal step the machine acts on and hands back, the ticks that follow are IDLE
ticks, and they measure **120.79 B/tick** (kill goal, no enemy in range), **224.79 B/tick** (kill
goal with an enemy present, `combat_helper.is_current_target_valid` 310 times in the window) and
**176.74 B/tick** (use goal). The gate's IDLE scenario is the mid-cast gather pause, which returns
at the top of the handler, so none of that goal-evaluation wiring is under any bound today. It is
its own pass (it needs its own fixture, and possibly the same hoisting), and this one does not
touch it.

## 6. IDLE while it evaluates a goal (T19) — the busiest live path, and it was unbounded

Section 5 ended by naming a cost no bound could see: IDLE ticks that actually evaluate a goal. The
T11 fixture is the mid-cast gather pause, which returns at the top of the handler, so the goal
evaluation, the goal filter, the goal details and the autoloot scan all sat outside every bound
while running on the path the bot spends most of its life on.

### The fixture, and why this shape

`T19` is a **kill goal with no enemy in range**. Of the goal shapes tried, it is the one that both
holds IDLE and evaluates on every tick: the goal loop runs, `goal_filter.passes` runs, the goal
details are built, the autoloot scan runs, and the state stays IDLE because there is nothing to
act on. The shapes that do act cannot pin it — a kill goal with an enemy present and a use goal
with a crate both settled in IDLE for a single tick and handed the machine to DO_ACTION/NAV, so
the purity assertion ("no other handler running") would fail for them, correctly. Same settled,
same purity, same n=300/n=1000 discipline as the other six scenarios.

**120.79 / 120.24 B/tick → 0.45 / 0.14 B/tick, bound 8.** T11's fixture and the other five
bounds are untouched.

### Attribution (bisection by early return, then per site)

The handler was bisected by inserting `do return "IDLE" end` before each region and measuring:

| up to | B/tick | segment |
|---|---|---|
| death block | 0.07 | death / cast / combat / quest-log maintenance — free |
| has-active-goal block | 32.07 | **the has-active-goal probe: 32.00** |
| autoloot | 88.07 | **the autoloot scan: 56.00** |
| step info + goals + debug log | 120.79 | **the goal loop and details: 32.72** |
| post-interact / at-object / flight / hearth / respawn wait | 120.79 | tail — free for this fixture |

Each segment was then confirmed by a one-edit mutant, which is what identified the exact sites:

| site | measured when reverted | what it was |
|---|---|---|
| `idle_state.lua:236` — has-active-goal default | **+32.00** | `ctx.safe(step.goals, {})` built a fresh table every tick |
| `idle_state.lua:317` — goal-loop default | **+32.00** | the same literal in the second place |
| `shared/corpse_loot` → `object_scanner.get_player_pos` | **+56.00** | an inline `pcall(function() ... end)` closure rebuilt on every cache refresh — i.e. once per tick for anything that scans |
| `idle_state.lua:340-347` — goal-details debug log | **+0.34** | `debug_log(...)` was handed a freshly concatenated string that it then discarded (`shared._debug` false) |
| `goal_filter.passes` | **+0.39** | not fixed; sub-byte, and inside a module this pass did not otherwise touch |

The three fixes: `EMPTY_GOALS` is a module-level empty table handed to `ctx.safe` in both places
(`safe` only ever *returns* its default — coordinator.lua:127 — and both call sites only iterate
it, so one shared table is correct as well as cheaper); `object_scanner` hoists the position probe
and calls `pcall(unit_get_position, me)`; the goal-details log is guarded by `shared._debug`, which
is the same output when debug is on and no concatenation when it is off.

### Mutants

| mutant | all seven scenarios (n=300) | gate |
|---|---|---|
| G — fresh `{}` back at the has-active-goal probe | **T19 32.45**; T11 0.07, T12 0.31, T13 1.24, T18 0.00 unchanged | `T19e FAIL: … 32.45 B/tick (n=300) and 32.13 (n=1000), bound is 8` |
| H — fresh `{}` back at the goal loop | **T19 32.45**; the other six unchanged | `T19e FAIL: … 32.45 / 32.13, bound is 8` |
| I — `object_scanner` probe back inline | **T19 56.45**; the other six unchanged | `T19e FAIL: … 56.45 / 56.13, bound is 8` |
| J — debug-log guard removed | T19 0.79 — **survives** (under the 8 B bound) | — |

G, H and I each fail T19 and only T19, which is what makes them load-bearing for this scenario:
T11 returns at the top of the handler, so it never reaches any of the three sites. J is recorded
rather than dressed up: the guard is worth having (a string that is built to be discarded should
not be built), but at 0.34 B/tick it is below the bound's resolution, so the gate cannot prove it
and does not claim to.

### The proof of no behaviour change

A scripted 54-tick sequence through the real coordinator — no guidance, a bare step, a loot window
with a gold slot between two items, a mid-cast channel, a waypoint 70yd out, a combat override,
death, an area goal, a **kill goal with no enemy (this pass's path, 10 ticks)** and guidance
disappearing — recorded per tick as state + navigation state + every input call + every log line,
run against the working tree and against a shadow copy whose two changed production files were
restored from `HEAD`: **176 lines, all six coordinator states (WAITING 10, IDLE 11, INTERACT 6,
NAV 12, DEAD 5, DO_ACTION 12), 64 log lines, 6 input-call lines, and `diff` prints nothing.** The
goal-details line appears in both transcripts exactly twice, which is the direct proof that the
`shared._debug` guard changed allocation and not output.

### Deliberately not fixed

`do_action_state.lua:1036` carries the same fresh-`{}` default on DO_ACTION's evaluation path. It
is one line and the same class, but no bound covers that tick (section 5: DO_ACTION's evaluation
cannot be pinned pure), so the change could not be proven here and is left named instead.

## 7. What this cannot prove

The measurement is the desktop interpreter's view of `tests/mock_core`. The client's own per-call
allocation is not measured and cannot be from here: a real `get_buffs`, `get_position`,
`is_mounted()` or `core.addons.zygor.get_current_step_info` may hand back a fresh table of its own
— in which case the *plugin* still allocates nothing, but the tick is not free in the client. The
fixtures' stubs (the aura table, the loot window, the movement stand-ins, the coords helper) are
exactly the places a real build could differ. T19 is one goal shape among many: it is the shape
that holds IDLE and evaluates, but a bot evaluating a *loot* or *talk* goal runs different
branches, and those ticks are not in this bound. The transcript covers the states and the paths
the script drives; it is not a claim about paths no fixture reaches, such as the SentinelNavClient
navmesh tick or the vendor/trainer frames. And the render half (T4-T9, T15-T17) is measured
separately, with its own caveats in `docs/render_path_audit.md`.
