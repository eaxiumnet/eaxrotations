# Index staleness audit — collections captured once and walked while they renumber

Sweep of every production loop in `EaxAutoQuester` that addresses a collection by index
or position **and performs an action between iterations**, i.e. the defect class the
quest-gossip fix closed (a 1-based row index that stops meaning the same thing once an
earlier action changes the list).

Method: locate mutation-capable loops mechanically (a brace/indent scan of every loop
body for a mutating call — 12 sites), then adjudicate each against the documented
behaviour of the collection it walks. Verdicts below cite `.api/core.lua` and
`scraped_docs_md/dev/`; nothing is guarded on a hunch.

## Index-base evidence (decides the range question)

| Collection | Base | Citation |
|---|---|---|
| Loot slots | **0** | `.api/core.lua:1025` — *"Every loot index below is 0 based, running 0 to this count minus 1"*; `loot_item`/`confirm_loot_slot` match (`:1849`, `:2123`); published walk is `for i = 0, count - 1` (`game-ui.md:209`, `:1601`) |
| Vendor items | **1** | `.api/core.lua:1272` — *"vendor_item_id is 1-indexed (internally adjusted to 0-indexed)"* |
| Quest log | **1** | `game-ui.md:1455` — *"`quest_log_id`: `integer` - The 1-based index of the quest log entry"*; `:1485` repeats it |
| Trainer services | not stated | `.api/core.lua:4539-4553` (count / info / cost / buy all "the trainer service index") |
| Bag slots, auras, Zygor goals | not index-acting | items carry their own `slot_id`; aura arrays and Zygor goal lists are read-only snapshots |

## Verdicts — all 12 mutation-capable loops

| # | Site | Walk | Verdict | Evidence |
|---|---|---|---|---|
| 1 | `loot_manager_sylvanas.lua` `M.try_loot` | `1..count`, then loot recorded indices ascending | **STALE + WRONG BASE — fixed** | 0-based (`core.lua:1025`) and taking a slot compacts the window, so 1-based skips slot 0, reads one past the end, and an ascending walk loses slots that shift down |
| 2 | `quest_interaction_sylvanas.lua` loot branch (`handle_any_frame`, priority 1) | `1..loot_count` ascending | **STALE + WRONG BASE — fixed** | same two citations; single pass over recorded indices, so an ascending walk silently drops items |
| 3 | `quest_log_manager_sylvanas.lua` `M.maintenance_check` | snapshot of grey entries, abandon up to 3 by captured `q.index` | **STALE — fixed** | the log is 1-based and index addressed (`game-ui.md:1455`); each abandonment **removes** an entry and renumbers the rest, so indexes captured in one scan point at a different quest by the second abandon |
| 4 | `vendor_manager_sylvanas.lua:93` sell loop | `for i = #items, 1, -1` | safe — already descending | the file's own comment: *"Process in reverse order so slot shifts don't affect remaining items"*; identity comes from `item.slot_id`, not the array position |
| 5 | `vendor_manager_sylvanas.lua:144` buy loop | vendor snapshot, `1..vendor_count` | safe | vendor list is 1-based (`core.lua:1272`) and buying does not change what the vendor offers; the flag argument is `vendor_item_index`, a documented field (`core.lua:1269`) |
| 6 | `navigation_sylvanas.lua:297` hearthstone | bags, `for bag = 0, 4` + `ipairs` | safe | finds item 6948 and `break`s; acts by `item.slot_id`; no list is renumbered |
| 7 | `quest_state/coordinator.lua:416` hearthstone | same pattern | safe | as #6 |
| 8 | `static_popup_sylvanas.lua:67` battlefield port | `for i = 1, 3` | safe | accepts the first `"confirm"` slot and `return`s; no iteration after the action |
| 9 | `quest_interaction_sylvanas.lua:236` reward scan | `for i = 1, 6` | safe | read-only walk; the single action (`get_quest_reward`) is followed by `break` |
| 10 | `quest_state/nav_state.lua:69` goals | `for i = 1, #goals` | safe | `set_target`/`interact_with_object` are world actions; the walk is a Zygor snapshot and `break`s after acting |
| 11 | `quest_interaction_sylvanas.lua` `handle_trainer` | `1..num_services`, buys each affordable service | **FIXED (semantics-independent)** | the docs (`quests.md:881-941`) never say whether purchasing removes the service from the list, so the walk is made correct under BOTH: re-read the offers per step and act on the index that read just returned, with "already bought" tracked by `spell_name` — the only identifier a `trainer_service_info` carries (`.api/core.lua:4379-4383` has no id field) |
| 12 | read-only walks — bag scans (`goal_resolver:91`, `navigation:297/402`, `loot_manager:106`, `quest_item_manager:42/72`, `coordinator:416`), quest log reads (`quest_log_manager:50`, `quest_blacklist:83/132`), aura arrays (`coordinator:375`, `dead_state:41/103`, `idle_state:104`), object scans, gossip (fixed previously) | — | safe | no action between iterations |

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
* **`quest_log_manager_sylvanas.lua`** — `maintenance_check` re-scans the live log for
  each of its (up to 3) abandons and acts on the index that read just returned, instead
  of walking the one snapshot taken before the first removal. The threshold gate, the
  3-per-check cap, the 30s throttle and the blacklist are unchanged.
* **`quest_interaction_sylvanas.lua`** — `handle_trainer` re-reads the offer list per
  step and buys the first affordable service it has not already bought, addressing the
  index that read returned. The entry-time count still bounds the pass (a purchase can
  only remove an offer, never add one), and on a list that does not compact the buys,
  their order and the returned report are identical to the single-pass walk.

## Proof — mutant first, then fix

Each guard was shown failing against the wrong code before passing against the fix.

| Defect | Mutant / pre-fix behaviour | Guard that fires |
|---|---|---|
| Loot walked 1-based | pre-fix `test_loot_manager`: `S2c FAIL: every slot 0..2 must be looted, got 1,2,3` (slot 0 skipped, index 3 past the end) | `test_loot_manager.lua` S2c/S2d |
| Loot branch walked 1-based | pre-fix `test_interact_state`: `loot branch must address slots 0 and 1` | `test_interact_state.lua` |
| Loot walk ascending over a compacting window | mutant → `both items must actually be looted from a compacting window, got: First` (second item lost) | `test_interact_state.lua` (name assertion) |
| Single ascending sweep in `try_loot` | mutant → `S2e FAIL: the gold slot (1) must be looted first, got 0` | `test_loot_manager.lua` S2e/S3 |
| Quest-log snapshot walk | pre-fix `test_quest_log_manager`: `S6b FAIL: only the grey quests may be removed, removed: 902,1006,1011` — one grey quest, then **two non-grey quests** | `test_quest_log_manager.lua` S6b |
| Trainer walk over a list that compacts on purchase | pre-fix `test_interact_state`: `S-T2a FAIL: a compacting list must still buy all 3 services, bought: Frostbolt,Ice Lance` — the middle service was skipped | `test_interact_state.lua` S-T2a |
| Re-read per step but **no** identity tracking | mutant → `S-T1a FAIL: … got trainer:4spells(1:Ice Lance,1:Ice Lance,1:Ice Lance,1:Ice Lance)` — re-buys the same service on a list that does not compact | `test_interact_state.lua` S-T1a/S-T1c |

Both production files were restored byte-identical after the mutants (`diff` clean) and
both suites pass against the restored code. The mock gained the ability to model the
renumbering (`_loot_compacts`, `_quest_log_compacts`), off by default so no other suite's
semantics changed.

## What cannot be confirmed without the client

1. **Which semantics the trainer list has** — whether `buy_trainer_service(i)` removes the
   service from the list. The docs leave this open, which is why the fixed walk is
   written to be correct either way rather than to guess; the answer is observable only
   in game, and is no longer needed for the code to be right.
2. **That the live loot window compacts per slot** — the docs state the index base and the
   count contract but never say when the window is rebuilt. The fix is correct under both
   semantics (a stable window loots the same set in either walk order), so the answer is
   not needed to ship it.
3. **That abandoning compacts the log rather than leaving a hole** — `get_num_quest_log_entries`
   is documented as an entry count (headers included) and every entry carries an internal
   `quest_log_index` (`core.lua:4278`), which is the shape of a compacting list; the exact
   packet behaviour is only observable in game.
