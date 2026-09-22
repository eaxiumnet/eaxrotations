# Index staleness audit — collections captured once and walked while they renumber

Sweep of every production loop in `EaxAutoQuester` that addresses a collection by index
or position **and performs an action between iterations**, i.e. the defect class the
quest-gossip fix closed (a 1-based row index that stops meaning the same thing once an
earlier action changes the list).

Method: locate action-in-loop sites mechanically, then adjudicate each against the
documented behaviour of the collection it walks. Two patterns were used, and the wider
one is the one to trust for coverage: a **narrow** pattern (a named set of mutating calls
— `loot_item`, `use_container_item`, `buy_item`, `buy_trainer_service`,
`abandon_quest`, …) flags **12** loops, while a **broad** pattern (any call that is not a
documented getter, including calls made through file-local aliases such as
`_loot_object`, `_get_item_info` or `pcall(_get_…)`) flags **22**. The 12 the narrow
pattern found are in the first table; the ten the broad pattern adds are in the second,
all verified safe. The narrow pattern's blind spot is exactly the aliased call, so an
inventory built only from it would miss a real site — it did not, this time.

Verdicts below cite `.api/core.lua` and `scraped_docs_md/dev/`; nothing is guarded on a
hunch. (The two scans use different loop-body heuristics, so line numbers can differ by a
few lines between them for the same loop.)

## Index-base evidence (decides the range question)

| Collection | Base | Citation |
|---|---|---|
| Loot slots | **0** | `.api/core.lua:1025` — *"Every loot index below is 0 based, running 0 to this count minus 1"*; `loot_item`/`confirm_loot_slot` match (`:1849`, `:2123`); published walk is `for i = 0, count - 1` (`game-ui.md:209`, `:1601`) |
| Vendor items | **1** | `.api/core.lua:1272` — *"vendor_item_id is 1-indexed (internally adjusted to 0-indexed)"* |
| Quest log | **1** | `game-ui.md:1455` — *"`quest_log_id`: `integer` - The 1-based index of the quest log entry"*; `:1485` repeats it |
| Trainer services | not stated | `.api/core.lua:4539-4553` (count / info / cost / buy all "the trainer service index") |
| Bag slots, auras, Zygor goals | not index-acting | items carry their own `slot_id`; aura arrays and Zygor goal lists are read-only snapshots |

## Verdicts — the 12 loops the narrow pattern flagged

| # | Site | Walk | Verdict | Evidence |
|---|---|---|---|---|
| 1 | `loot_manager_sylvanas.lua` `M.try_loot` | `1..count`, then loot recorded indices ascending | **STALE + WRONG BASE — fixed** | 0-based (`core.lua:1025`) and taking a slot compacts the window, so 1-based skips slot 0, reads one past the end, and an ascending walk loses slots that shift down |
| 2 | `quest_interaction_sylvanas.lua` loot branch (`handle_any_frame`, priority 1) | `1..loot_count` ascending | **STALE + WRONG BASE — fixed** | same two citations; single pass over recorded indices, so an ascending walk silently drops items |
| 3 | `quest_log_manager_sylvanas.lua` `M.maintenance_check` (module since deleted) | snapshot of grey entries, abandon up to 3 by captured `q.index` | **STALE — fixed, then removed entirely** | the log is 1-based and index addressed (`game-ui.md:1455`); each abandonment **removes** an entry and renumbers the rest, so indexes captured in one scan point at a different quest by the second abandon. The walk was fixed, but the premise was wrong: the pass deleted quests the player was still going to turn in (live: three grey quests abandoned, a hearthstone and a walk back). The module, its call site and its suite are gone; `tests/test_no_quest_abandon.lua` now fails if any production file can delete a quest. |
| 4 | `vendor_manager_sylvanas.lua:93` sell loop | `for i = #items, 1, -1` | safe — already descending | the file's own comment: *"Process in reverse order so slot shifts don't affect remaining items"*; identity comes from `item.slot_id`, not the array position |
| 5 | `vendor_manager_sylvanas.lua:144` buy loop | vendor snapshot, `1..vendor_count` | safe | vendor list is 1-based (`core.lua:1272`) and buying does not change what the vendor offers; the flag argument is `vendor_item_index`, a documented field (`core.lua:1269`) |
| 6 | `navigation_sylvanas.lua:297` hearthstone | bags, `for bag = 0, 4` + `ipairs` | safe | finds item 6948 and `break`s; acts by `item.slot_id`; no list is renumbered |
| 7 | `quest_state/coordinator.lua:416` hearthstone | same pattern | safe | as #6 |
| 8 | `static_popup_sylvanas.lua:67` battlefield port | `for i = 1, 3` | safe | accepts the first `"confirm"` slot and `return`s; no iteration after the action |
| 9 | `quest_interaction_sylvanas.lua:236` reward scan | `for i = 1, 6` | safe | read-only walk; the single action (`get_quest_reward`) is followed by `break` |
| 10 | `quest_state/nav_state.lua:69` goals | `for i = 1, #goals` | safe | `set_target`/`interact_with_object` are world actions; the walk is a Zygor snapshot and `break`s after acting |
| 11 | `quest_interaction_sylvanas.lua` `handle_trainer` | `1..num_services`, buys each affordable service | **FIXED (semantics-independent)** | the docs (`quests.md:881-941`) never say whether purchasing removes the service from the list, so the walk is driven purely by **position in a fresh read**: each step reads its target through the read it just took, and after a purchase the list is read again — if it shrank the rest renumbered, so the cursor stays on the index that now holds the next offer; if it did not, the cursor steps past the offer just bought. No field is used as identity, because `trainer_service_info` (`.api/core.lua:4379-4383`) carries `spell_name` **and `rank`** — a name is not unique (two ranks of one spell) and need not exist at all |
| 12 | read-only walks — bag scans (`goal_resolver:91`, `coordinator:416`), quest log reads (`quest_blacklist:83/132`), aura arrays (`coordinator:375`, `dead_state:41/103`, `idle_state:104`), object scans, gossip (fixed previously) | — | safe | no action between iterations |

### The ten action-in-loop sites the broad pattern adds (all verified safe)

| Site | Call in the loop | Verdict | Why |
|---|---|---|---|
| `dungeon_detector_sylvanas.lua:60` | `get_quest_log_title`, `get_num_quest_leader_boards`, `get_quest_log_leader_board` | safe | reads only; the loop returns on match |
| `progress_tracker_sylvanas.lua:42` | same leader-board reads | safe | reads only |
| `goal_resolver_sylvanas.lua:119` | `pcall(_get…)` alias read | safe | alias for a getter |
| `mount_manager_sylvanas.lua:56` | `get_mount_info` | safe | reads until the first usable mount, then returns |
| `vendor_manager_sylvanas.lua:56` | `_get_item_info` alias read | safe | read |
| `vendor_manager_sylvanas.lua:130` | `_get_vendor_item_info` alias read | safe | read; the list is 1-based (`core.lua:1272`) |
| `loot_manager_sylvanas.lua:107` | `get_num_bag_slots` / `get_items_in_bag` | safe | read; fills the bag-space totals |
| `loot_manager_sylvanas.lua:195` | `_loot_object` per collected object | safe | walks a list the function built itself; objects are not renumbered |
| `navigation_sylvanas.lua:402` | `circle_3d` / `line_3d` | safe | draws the navmesh path; rendering, not game state |
| `quest_state/do_action_state.lua:616` | `look_at`, `set_target`, `use_object` | safe | world actions over a locally built `names_to_try`; nothing renumbered |

Collections named in the brief with **no production site at all**: loot rolls / need /
greed (no roll API used), mail (`core.mail.*` unused), party/raid member lists
(`get_party_members` unused), spell lists (`core.spell_book.*` unused).

## What changed

* **`loot_manager_sylvanas.lua`** — `try_loot` classifies and loots over `0 .. count-1`
  and walks **downward** in both passes (gold first, then the remaining item slots, the
  count re-read for the second pass so slots taken after the first read cannot go stale).
  The two static index tables (`_gold_indices`, `_item_indices`) are gone with the
  two-pass-recorded-index design they served.
* **`quest_interaction_sylvanas.lua`** — the loot branch walks `loot_count-1 .. 0`.
* **`quest_log_manager_sylvanas.lua`** — *deleted.* Its `maintenance_check` re-scanned the
  live log for each of its (up to 3) abandons and acted on the index that read just
  returned, which fixed the stale-index defect but left the real one: it deleted quests.
  The module, its `idle_state` call site and `test_quest_log_manager.lua` are gone, and
  `tests/test_no_quest_abandon.lua` scans every production file for a quest-deletion call.
* **`quest_interaction_sylvanas.lua`** — `handle_trainer` walks a **cursor over a freshly
  read list**, with no field used as identity: each step reads its target through the read
  it just took; after a purchase the count is read once more and the cursor stays put if
  the list shrank (the same index now holds the next offer) or steps past the offer just
  bought if it did not. The count read on entry bounds the pass, since a purchase can only
  remove an offer. The previous design's `bought[spell_name]` table, its `service#i`
  index-derived fallback and the unguarded `num_services < 1` comparison are all gone; the
  count is now type-checked, so a non-numeric return yields `nil` instead of a raise. On a
  stable list the buys, their order and the returned report are identical to the original
  single-pass walk. Cost is linear in offers (~3 API calls each), not quadratic: no step
  rescans the list.

## Proof — mutant first, then fix

Each guard was shown failing against the wrong code before passing against the fix.

| Defect | Mutant / pre-fix behaviour | Guard that fires |
|---|---|---|
| Loot walked 1-based | pre-fix `test_loot_manager`: `S2c FAIL: every slot 0..2 must be looted, got 1,2,3` (slot 0 skipped, index 3 past the end) | `test_loot_manager.lua` S2c/S2d |
| Loot branch walked 1-based | pre-fix `test_interact_state`: `loot branch must address slots 0 and 1` | `test_interact_state.lua` |
| Loot walk ascending over a compacting window | mutant → `both items must actually be looted from a compacting window, got: First` (second item lost) | `test_interact_state.lua` (name assertion) |
| Single ascending sweep in `try_loot` | mutant → `S2e FAIL: the gold slot (1) must be looted first, got 0` | `test_loot_manager.lua` S2e/S3 |
| Quest-log snapshot walk | pre-fix `test_quest_log_manager`: `S6b FAIL: only the grey quests may be removed, removed: 902,1006,1011` — one grey quest, then **two non-grey quests** | `test_quest_log_manager.lua` S6b (both suite and module since deleted — see below) |
| A quest the plugin decided to delete | the module above and `do_action_state`'s failure path both called `core.quests.abandon_quest`, so a quest the player was still working on could vanish | `test_no_quest_abandon.lua` S2 (positive control S1: a real call is caught, prose about one is not) |
| Trainer keyed on `spell_name` (the superseded design) | pre-fix `test_interact_state`: `S-T4a FAIL: both ranks must be bought, bought: Frostbolt` — two ranks of one spell buy **once** (a regression: `2spells` → `1spells`), and `S-T6a` for nameless offers under compaction, where the `service#i` fallback collides | `test_interact_state.lua` S-T4a / S-T5a / S-T6a |
| Compaction never noticed by the cursor walk | mutant → `S-T2a` at `test_interact_state.lua:127` — the list shifts and an offer is skipped | `test_interact_state.lua` S-T2a |
| Cursor never advances on a stable list | mutant → `S-T1a` at `test_interact_state.lua:112` — re-buys the same offer until the step budget runs out | `test_interact_state.lua` S-T1a |
| Non-numeric service count | pre-fix: raised `attempt to compare string with number` (`quest_interaction_sylvanas.lua:415`) | `test_interact_state.lua` S-T8a |
| A scenario with no assertion | `test_loot_manager` S6 called `close()` and printed a pass line, so it could not fail. It now asserts the mock received `close_loot` | `test_loot_manager.lua` S6 |

Both production files were restored byte-identical after the mutants (`diff` clean) and
both suites pass against the restored code. The mock gained the ability to model the
renumbering (`_loot_compacts`, `_quest_log_compacts`, `_trainer_compacts`) and to record
which offer each trainer index resolved to, off by default so no other suite's semantics
changed. Its trainer label is never nil and an index with no offer behind it records
`<no offer @N>` — verified to actually fire, so the suite's no-over-reach assertion is not
another vacuous guard.

## What cannot be confirmed without the client

1. **Which semantics the trainer list has** — whether `buy_trainer_service(i)` removes the
   service from the list. The docs leave this open, which is why the walk is driven by
   position in a fresh read rather than by any field: it is the only formulation that is
   correct either way, including for offers that share a `spell_name` or have none. The
   answer is observable only in game, and is no longer needed for the code to be right.
   Also still unstated by the docs: the **base** of the trainer index (the code keeps
   1-based, unchanged by this work).
2. **That the live loot window compacts per slot** — the docs state the index base and the
   count contract but never say when the window is rebuilt. The fix is correct under both
   semantics (a stable window loots the same set in either walk order), so the answer is
   not needed to ship it.
3. **That abandoning compacts the log rather than leaving a hole** — `get_num_quest_log_entries`
   is documented as an entry count (headers included) and every entry carries an internal
   `quest_log_index` (`core.lua:4278`), which is the shape of a compacting list; the exact
   packet behaviour is only observable in game.
