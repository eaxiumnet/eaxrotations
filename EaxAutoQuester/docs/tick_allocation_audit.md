# Per-state tick allocation audit — closing the three non-zero bounds

`tests/test_tick_allocation.lua` measures the real `coordinator.update()` per coordinator state
(T10-T14), driven by `tests/mock_core` with the collector stopped (gross bytes per tick, n=300
and n=1000, pinned Lua 5.1.5). When the per-state half was added, three of the five states were
non-zero and their bounds were recorded as *ratchets* around measured debt, with the attribution
of each state already written down. This pass removes that debt: **all five bounds are now 8 B**
(measured + 8, against a run-to-run spread under 1.5 B), so any added per-tick allocation fails
in its own state — down to a single no-upvalue closure, which costs 20 B.

Nothing here is a behaviour change, and nothing here is asserted: the four fixes are the hoisting
and reuse the attribution named, each is killed by a mutant that reinstates exactly it, and the
whole tick sequence is proven identical to the pre-change tree by transcript diff (section 4).

---

## 1. Measured, before and after

| state | before (n=300 / n=1000) | after | bound | what it was |
|---|---|---|---|---|
| WAITING | -0.43 / 0.00 | -0.43 / 0.00 | 8 | clean already |
| IDLE | 388.07 / 387.89 | **0.07 / -0.11** | 8 | seven inline `pcall(function() ... end)` closures in `idle_state.run`'s head |
| INTERACT | 320.31 / 319.97 | **0.31 / -0.03** | 8 | two fresh three-field step-info tables per tick |
| NAV | 385.24 / 384.29 | **1.24 / 0.29** | 8 | `nav_state`'s combat probe, `navigation.update`'s fallback mover probes, `mount_manager.update`'s four probes |
| DEAD | 0.00 / -0.13 | 0.00 / -0.13 | 8 | clean already |

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

## 5. What this cannot prove

The measurement is the desktop interpreter's view of `tests/mock_core`. The client's own per-call
allocation is not measured and cannot be from here: a real `get_buffs`, `get_position`,
`is_mounted()` or `core.addons.zygor.get_current_step_info` may hand back a fresh table of its own
— in which case the *plugin* still allocates nothing, but the tick is not free in the client. The
fixtures' stubs (the aura table, the loot window, the movement stand-ins, the coords helper) are
exactly the places a real build could differ. The transcript covers the states and the paths the
script drives; it is not a claim about paths no fixture reaches, such as the SentinelNavClient
navmesh tick or the vendor/trainer frames. And the render half (T4-T9, T15-T17) is measured
separately, with its own caveats in `docs/render_path_audit.md`.
