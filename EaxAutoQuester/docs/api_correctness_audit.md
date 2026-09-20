# Loot / vendor / repair / mail API audit — plan item 14

Every production call site in the four domains, checked against `.api/core.lua` (the runtime
stub, hand-maintained and dated) and `scraped_docs_md/dev/` (the user-facing docs). Where the
two disagree the stub is the authority: it carries the measured values and the "verified on
wow_tbc_ps" notes. Nothing here is inferred from documentation that does not exist — a call
whose shape is not documented anywhere is recorded as such instead of being "fixed".

Corrections in this pass: **5**, each pinned by a test that fails against the old call.
Confirms handled: **2**. Confirms deliberately not handled: **2**. Mail calls: **0**.

---

## 1. Loot window readers and takers

| # | Site | Verdict | Evidence |
|---|------|---------|----------|
| 1 | `loot_manager_sylvanas.lua:10-14` (caches `get_loot_item_count/_id/_name/_is_gold`, `loot_item`, `close_loot`) | correct, unchanged | `.api/core.lua:1022` — "Every loot index below is 0 based, running 0 to this count minus 1"; `loot_item`/`confirm_loot_slot` match it (:1849, :2123) |
| 2 | `loot_manager.try_loot` — two descending 0-based passes, count re-read for pass 2 | correct, unchanged | `:1022` (0-based), `:1016-1018` — the window "is NOT populated on the frame that opens it"; a slot taken compacts the window, so descending is the safe direction |
| 3 | `loot_manager.auto_loot_all` → `core.input.loot_object(obj)` | **corrected** (was the wrong function for containers) | `:2121-2123` — "UNITS AND CORPSES ONLY. The native path rejects anything that is not a unit and answers false straight away, so a fishing bobber, chest, herb node or ore node cannot be looted through this"; `:2143` — `use_object` is "the entry point for world objects rather than units". A chest answered false, stayed shut, and the pass still counted it as handled |
| 4 | `loot_manager.close()` → `close_loot` | correct, unchanged | `:2255` |
| 5 | `shared/corpse_loot.lua:35` `get_loot_item_count`; `:96` `loot_object(best_loot)` | correct, unchanged | the object is filtered by `obj:is_unit()` first (:41), i.e. exactly the population `loot_object` accepts (`:2121`) |
| 6 | `quest_state/idle_state.lua:26` `get_loot_item_count` as the open-frame probe | correct, unchanged | `:1017-1018` — "Zero when no loot window is open" |
| 7 | `quest_state/interact_state.lua:88` `close_loot` | correct, unchanged | `:2255` |
| 8 | `quest_state/do_action_state.lua:679` `use_object(obj)` | correct, unchanged | `:2143` — world object, not a unit |

**Load-bearing correction (#3).** `auto_loot_all` collected everything `can_be_looted()`
returned and handed it to `loot_object`. For a corpse that is right; for a chest, herb node or
ore node the native path refuses it without erroring, so the container was never opened and the
object was still reported as processed. The opener is now chosen per object from `is_unit()`,
and only an object **proven** not to be a unit is redirected — a failed `is_unit()` keeps the
object on `loot_object`, which is what it got before.

## 2. Bag space (the loot gate)

| # | Site | Verdict | Evidence |
|---|------|---------|----------|
| 9 | `loot_manager.get_bag_space` (gates looting at `< 4` free slots, feeds the 80 % vendor trigger) | **corrected** — two documented defects | (a) the two bindings are shifted: "the pairing you want is `get_num_bag_slots(N)` alongside `get_items_in_bag(N - 1)`. Passing the same number to both asks about two different bags and the mistake is silent" (`:906-909`), and `get_num_bag_slots(0)` fails an internal range guard and "returns 0 on EVERY build, always" (`:923-929`); (b) `get_items_in_bag(0)` is not the backpack — it is "the identical whole-player-container list", worn gear and the bag objects included, with the backpack proper starting at `BAG_1_REAL_START` (`:859-876`) |
| 10 | same, now read from `common/utility/inventory_helper` totals | correct | `:889-890` — the mini-lib "owns that conversion and is the supported way"; its `get_total_free_slots` / `get_total_bag_capacity` / `get_total_used_slots` are documented in `scraped_docs_md/dev/libraries/mini-libs/inventory-helper.md` |

Effect of the old numbers, on the fixture in `test_loot_manager` S0: raw said 64 − 65 → clamped
to **0 free** ("bags full — skipping loot"), while the owner says 80 − 65 = **15 free**. The used
count also carried every worn item and bag object, so `get_bag_fullness_pct` overstated.

Helper absent → the numbers are **unknown**, and unknown means "loot anyway". The plugin never
invents an inventory state.

## 3. Vendor, repair

| # | Site | Verdict | Evidence |
|---|------|---------|----------|
| 11 | `vendor_manager.should_repair` → `get_total_repair_cost()` (`cost > 0`) | correct, unchanged | `:947-948`; `:958-963` — a zero cost is ambiguous ("nothing is damaged" vs "this vendor cannot repair") and only `can_merchant_repair` separates the two, but a **positive** cost already implies a repair-capable merchant, so the positive gate is sound |
| 12 | `handle_vendor` → `repair_all_items(false)` | correct, unchanged | `:1864-1867` — documented boolean "use guild bank" argument |
| 13 | `handle_vendor` → `get_gold()` | correct, unchanged | `:980-983` |
| 14 | `handle_vendor`'s vendor-open check via `get_vendor_item_count()` | correct, unchanged | `:1279-1284`; `can_merchant_repair` is documented as "not a substitute for a vendor-open check" (`:953-954`), and no other vendor-frame predicate exists in the stub or the scraped docs |
| 15 | `vendor_manager.sell_junk` → `use_container_item(bag_id, item.slot_id)` | **corrected** — raw slot_id | `:1747-1750` — the pair "are the bag_id and bag_slot that common/utility/inventory_helper.lua hands you; that module owns the shift from the raw get_items_in_bag slot_id… Passing a raw slot_id straight from get_items_in_bag targets the item NEXT to the one you meant". In a **sale** that is someone else's item, and for bag 0 the raw 24..39 range is out of range for the 16-slot backpack (`:886-888`). `use_container_item` has no documented result either, so `pcall` success was counted as "sold" regardless |
| 16 | `vendor_manager.should_sell_junk` (same scan) | **corrected** | same read: `get_items_in_bag(0)` is the whole player container (`:859-876`), so equipped gear and the bag objects were offered up as sell candidates |
| 17 | `should_sell_junk`/`sell_junk` now enumerate `inventory_helper:get_character_bag_slots()` and sell with **its** `bag_id`/`bag_slot` | correct | `:1747-1750`; helper absent → **nothing is sold** (guessing is the bug) |
| 18 | `buy_quest_items` → `get_vendor_item_info(i)` for `i = 1..count` | correct, unchanged | `:1272` — "vendor_item_id is 1-indexed (internally adjusted to 0-indexed)" |
| 19 | `buy_quest_items` → `buy_item(index, quantity)` with the snapshot **position** (or the undocumented `vendor_item_index` field) | **corrected** — wrong index provenance | the buyer's index is documented 1-based in the same space as the reader (`scraped_docs_md/dev/api/input.md`, "Vendor Interaction" — "The vendor item index (1-based)"), while `vendor_item_index` carries no documented base (`:1269`) and the snapshot position shifts whenever a read fails (the list compacts at `:1263`). The write now carries the 1-based index each entry was **read** with |

## 4. Mail

No production call site exists: `core.mail.*` appears only in `.api/core.lua`, never in
`EaxAutoQuester/` outside `tests/`. There is nothing to audit, and nothing was added.

## 5. Confirm popups — only what the plugin's own actions raise

| Event | Plugin action that raises it | Verdict | Evidence |
|-------|------------------------------|---------|----------|
| `CONFIRM_BINDER` | `service_gossip_sylvanas.handle_service_gossip` **selects the innkeeper bind option itself** (`_INN_PATTERNS`, `select_gossip_option(option_id)`) | **handled** — `core.input.confirm_binder()` | `:1841-1845` — "the one raised by CONFIRM_BINDER. Fires after using a hearthstone bind gossip option". The prompt outlives the gossip frame (the frame closes when the option is taken), so the answer runs from the coordinator's per-tick seam, and only within a bounded window after **our own** selection |
| `LOOT_BIND_CONFIRM` | `loot_manager.try_loot` loots every slot of the window it opened | **handled** — `core.input.confirm_loot_slot(slot - 1)` | `:1849-1854` — "loot_slot is 0 BASED… WoW's own LOOT_BIND_CONFIRM event reports the 1 BASED slot, so forwarding args[1] straight from that event confirms the wrong slot: subtract one first". The window is kept open so the next tick takes the item the client released |
| `AUTOEQUIP_BIND_CONFIRM` / `EQUIP_BIND_CONFIRM` | **none — the plugin never equips anything** | **not handled, deliberately** | `core.input.equip_pending_item` / `cancel_pending_equip` / `core.game_ui.get_pending_equip_slot` have no production call site. `quest_interaction_sylvanas.auto_equip_best_reward` (`:228-275`) **selects the reward** (`get_quest_reward(i)`) and then `break`s with the comment "(The exact bag/slot is unknown at this moment; we'll scan on next tick)" — no scan exists and nothing equips from bags, so the client never holds an equip of ours. Answering that prompt would be auto-confirm behavior for an action the plugin does not take, which this item forbids |

The four confirm events are *recorded* by `quest_frame_events_sylvanas` (item 12) and never pulse
the quest-frame gate. This pass added one read-only accessor, `take_confirm(name)`, which the two
handled prompts use; it changes no classification, no pulse and no polling behavior.

## 6. Same defect class, out of this item's scope (recorded, not changed)

These are the raw-`use_container_item` sites outside loot/vendor/repair/mail. They carry the
identical documented defect as #15 — a raw `core.inventory` slot_id handed to a binding that
wants the helper's pair — and each is a one-line change to `core.input.use_item(item_id)` where
the intent is "use this item", which needs no slot at all (`scraped_docs_md/dev/api/input.md`,
"Use Container Item": `use_item` takes the item ID instead of a bag position):

* `quest_item_manager_sylvanas.lua:229` — fallback 3 of `use_quest_item` (self-cast and
  target-cast already tried first, so the fallback is reachable).
* `navigation_sylvanas.lua:717` — the stuck-recovery hearthstone scan (item 6948).
* `quest_state/coordinator.lua:464` — the death-loop hearthstone scan (item 6948, a second copy
  of the same loop).

Left alone because item 14 is scoped to loot/vendor/repair/mail and the confirm inputs, and two of
the three sit in navigation code that items 12/13 own. They are listed here so the next pass
inherits the finding rather than rediscovering it.

## 7. What cannot be confirmed without the game client

* Whether `inventory_helper:get_character_bag_slots()` includes the **backpack** (bag 0) or only
  the four equipped bags. The plugin trusts it to own the shift and filters to `bag_id` 0..4; if
  the mini-lib's list omits the backpack, backpack junk is simply not sold — never the wrong item,
  which is the trade this pass chose deliberately.
* Whether `use_container_item` is in fact the sell action while a merchant window is open. No
  binding in `.api/core.lua` or the scraped docs is documented as "sell", and the plugin has
  always relied on it; this pass did not change that relationship, only the slot it names.
* Whether the client really delivers `CONFIRM_BINDER` after the bind gossip option and
  `LOOT_BIND_CONFIRM` after looting a BoP slot on these builds (item 12 already flags that the
  whole event surface is unverified in game). The handlers are inert where the events never
  arrive: `take_confirm` returns nil and nothing is confirmed.
* Whether `slot_data.global_slot` could have been used as a cross-check for the pair; it is
  documented only as "Global slot identifier" with no stated meaning, so it is unused.
