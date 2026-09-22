# Quest frames that will not close, and the facing lock that turned the player in circles

Two live reports, two rules that follow from them. Both are enforced by suites that fail if the
rule is undone, and both were proven load-bearing by reverting them one at a time.

## 1. A frame is closed when a LATER tick sees no frame — never in the same tick an action was issued

`quest_interaction_sylvanas.handle_quest_detail` selects the reward and calls `complete_quest()`
(the documented order: `get_quest_reward` selects *and* completes, `complete_quest` finishes;
`scraped_docs_md/dev/api/quests.md`). What follows that call is the whole problem.

The first version probed for the reward link right after completing, and treated "the choices read
empty" as success. In the live client they empty for an instant and the server **re-populates**
them, because the turn-in was refused — so the probe read *closed* while the caller's own probe
(`idle_state.detect_open_frame`, same client state a millisecond later) read the window still on
screen. The counter behind "give up after 3 attempts" was reset by that phantom success, so it
could never reach 3, and the log filled with one completed-looking attempt per second:

```
INTERACT: handled (complete_quest+best_reward:1(10126c))
INTERACT: frame still open
```

None of the exits could fire: the give-up was unreachable, and `interact_state` resets its own 15s
safety timeout on every "handled" result, so the frame was retried for as long as the client kept
it.

**Rules, all three load-bearing:**

1. An attempt is charged unconditionally (`_quest_retry_count + 1`). Success is *not* decided
   after the action; it is observed at the top of a later pass, where "no frame" is the only thing
   that clears the budget. That absence check runs **before** the give-up check, so a frame that
   closes — by our attempt or by the player's hand — cannot poison the next one.
2. The give-up asks the caller's probe, passed in as `handle_any_frame(step_text, frame_open_fn)`
   and supplied by `interact_state` as `ctx.detect_open_frame`. One truth for "is it still there".
3. An offer frame publishes `"choice"` links too, as a preview of what the quest pays. When the
   frame outlives `complete_quest`, the claim path (`accept_quest`) is tried in the **same pass** —
   otherwise every offer is only ever "completed", the three attempts are spent, and a quest the
   bot should have taken is given up on. That probe selects the verb only; it is never the success
   test, for the reason above.

After three attempts the handler reports `quest_giveup`, `interact_state` leaves for a 60s cooldown,
one warning names the step, and the player finishes the turn-in by hand. Bounded, and quiet.

## 2. Facing has one owner, and a look-at lock is not a snap

`movement_handler:look_at_target(lock_duration, delay, target)` **holds** a facing for that
duration and releases only when it expires or is unlocked (`scraped_docs_md/dev/api/
movement-handler.md`). It is not a point-at-instant call.

The quest states re-issued it with `0.5` from every combat tick, at whatever unit was selected —
so the character was servo-driven continuously. Worst at a mob circling in melee, at an alternating
"best enemy", and at the client's stale target after a kill, which is a corpse. That is the
"spinning around in circles" report.

`shared/facing.lua` is now the only file that may issue the call (`test_no_turn_keys.lua` S4 scans
all 50 production files and fails on any other site), and it aims at most once per 3 seconds, only
when the target is outside a 60-degree cone, and never at a dead or lootable unit. When the client
cannot answer (`get_direction()` missing), it degrades to "aim once per interval" — a character
that cannot turn cannot cast, which is worse than a slow turn.

The turn keys (`turn_left_start` / `turn_right_start`) are banned outright by the same suite: they
begin *holding* an arrow key until a matching stop, and one was already started with no stop
anywhere in the plugin.

## Related

- `docs/mount_and_travel.md` — the same shape of bug: a 1.5s cast attempted from a tick that is
  already walking.
- `tests/test_quest_turnin.lua`, `tests/test_facing.lua` — the scenarios behind every claim above.
