# EaxAutoQuester gap-closure mission

## Mission
Close the P0/P1/P2 gaps identified in the autoquester audit, without changing behavior outside the affected surfaces. Each objective must prove its outcome through the production module path and its registered tests. The scope is the audited inventory below; it does not add mail, rolls, party automation, or new heuristic capabilities.

## P0 — production correctness

### AQ-P0-1 — Reward auto-equip
**Objective:** Equip the selected quest reward when it is an equipment upgrade, including a bind-on-equip reward; do not select a different reward as a side effect.

**Acceptance criteria:**
- The chosen item is located through `common/utility/inventory_helper` and requested with the documented `(bag_id, bag_slot)` pair.
- A non-bind upgrade is equipped through the production reward path.
- An `AUTOEQUIP_BIND_CONFIRM` raised by that pending action is answered with `core.input.equip_pending_item`, exactly once and within a bounded ownership window.
- A player-originated prompt is not answered.
- Reward selection, quest completion, and non-reward interaction behavior remain unchanged.

**Proving surface:** `EaxAutoQuester/quest_interaction_sylvanas.lua`, its coordinator per-tick seam, and the auto-equip/confirm-input suites.

### AQ-P0-2 — Valid item-use fallback
**Objective:** Replace all three raw `use_container_item` calls in the audited quest-item and hearthstone paths with valid item-ID use.

**Acceptance criteria:**
- `quest_item_manager_sylvanas.lua`, `navigation_sylvanas.lua`, and `quest_state/coordinator.lua` no longer pass a raw inventory slot to `use_container_item`.
- The three paths retain their existing self/target/position and hearthstone intent.
- Tests pin the valid item ID and fail a regression to raw container-slot use.

**Proving surface:** the three production modules, the mock input trace, and their existing coordinator/navigation/item tests.

## P1 — remove advertised-but-unreachable behavior

### AQ-P1-1 — Menu contract
**Status: complete (2026-09-24).** Re-measurement found that the ten audited controls did not have a live setting contract: several behaviors existed as always-on or separately hardcoded paths, while none of these controls had a production reader. To preserve behavior outside the menu surface, all ten unsupported controls were removed from the rendered menu rather than inventing new toggles or changing quest-loop behavior.

**Acceptance criteria met:**
- `auto_loot`, `auto_repair`, `auto_vendor`, `auto_train`, `auto_accept`, `auto_turnin`, `vendor_threshold`, `interact_range`, `min_hp`, and `min_mana` are not created or rendered.
- The existing always-on corpse-loot, quest interaction, vendor, trainer, and pull-safety behavior is unchanged.
- `nav_tolerance` and the three live pull-gate controls remain created and rendered.
- The real menu module and its render body prove both the removals and the retained controls.

**Proving surface:** `menu_sylvanas.lua` and `tests/test_menu_pull_gate.lua` M4/M5.

### AQ-P1-2 — Live autoloot/vendor pressure
**Status: complete (2026-09-24).** The live `shared/corpse_loot.lua` path now calls the existing loot-manager fullness owner after requesting a nearby corpse loot. No menu, vendor feature, threshold, or navigation policy was added.

**Acceptance criteria met:**
- A real corpse-loot request at 80%+ bag fullness raises `_G.EaxAutoQuester._force_vendor_soon` through `loot_manager_sylvanas.lua`.
- The existing coordinator test still proves that flag transitions IDLE to vendor NAV.
- Below-threshold corpse loot does not raise the flag.
- `auto_loot_all` and the live corpse path share one fullness/flag implementation.

**Proving surface:** `shared/corpse_loot.lua`, `loot_manager_sylvanas.lua`, and `tests/test_vendor_bag_trigger.lua` S1b/S3.

### AQ-P1-3 — Bank/repair service gossip
**Status: complete (2026-09-24).** Re-measurement found existing Bank and Repair pattern matching and option selection in `service_gossip_sylvanas.lua`; only the quest-loop caller was omitting the wanted-services list. The loop now derives the existing service intent from the current step text and passes it into the existing handler.

**Acceptance criteria met:**
- A normal bank step selects the existing Bank gossip option.
- A normal repair step selects the existing Repair gossip option.
- The existing automatic inn request remains unchanged.
- Steps with no service intent still produce no service selection.
- No menu, vendoring, repair, or new service capability was added.

**Proving surface:** `service_gossip_sylvanas.lua`, the `quest_interaction_sylvanas.handle_gossip` caller, and `tests/test_service_gossip.lua` S6-S8.

### AQ-P1-4 — Failure policy
**Status: complete (2026-09-24).** The existing recorded-failure surface now marks a quest as a session-persistent skip. Goal resolution consults that mark together with the existing progress blacklist, and the current DO_ACTION tick checks it before targeting or interacting. The policy is quiet and non-abandoning: it does not wire `should_abandon`, delete a quest, or add UI or messaging.

**Acceptance criteria met:**
- A recorded production area failure marks the quest without requiring the legacy five-entry abandonment query.
- A later step's real goal-resolution tick avoids the marked goal and selects the next eligible goal.
- If the marked goal was already selected, the real DO_ACTION tick returns to IDLE without targeting, using, or interacting.
- The existing progress-tracker blacklist remains honored; unmarked goals and their routing, navigation, and combat behavior are unchanged.
- `test_no_quest_abandon` remains green; no quest-deletion call or new user-facing notice was added.

**Proving surface:** `quest_blacklist_sylvanas.lua`, `goal_filter_sylvanas.lua`, `quest_state/do_action_state.lua`, the real `coordinator.update()` path, and `tests/test_quest_blacklist.lua` S5b plus `tests/test_coordinator.lua` S11b-S11f.

## P2 — correctness and usability

### AQ-P2-1 — Transport locality
**Status: complete (2026-09-24).** Transport lookup now resolves the player's current map, ranks valid same-map spawns by 3D squared distance, and returns nil when only another-map candidates exist. The flight and inn IDLE callers plus the coordinator's force-vendor caller all pass the current map and player position through the existing lookup surface.

**Acceptance criteria met:**
- The real flight caller selects the nearest local flight master and does not NAV when only another-map candidates exist.
- The real inn caller selects the nearest local innkeeper and does not NAV when only another-map candidates exist.
- The real force-vendor caller selects the nearest local vendor and does not NAV when only another-map candidates exist.
- No local candidate preserves the existing caller-visible no-navigation outcome; no new error state or UI was added.
- Combat, quest routing, and unrelated navigation policy remain unchanged.

**Proving surface:** `npc_db_sylvanas.lua`, the flight/inn branches in `quest_state/idle_state.lua`, the force-vendor branch in `quest_state/coordinator.lua`, and `tests/test_transport_helper.lua` S8-S12.

### AQ-P2-2 — Quest-item identity and result tracking
**Status: complete (2026-09-24).** The documented goal shape carries no item ID, so the existing ordered text queries remain the candidate selector. Once an inventory object is selected, its client-owned `get_item_id()` is re-read and pinned across every use attempt; bag-row metadata is never treated as identity. Every `use_item*` call now counts as successful only when `pcall` completes **and** the API returns literal `true`, so `false` and thrown errors continue through the unchanged self/target/position fallbacks.

**Acceptance criteria met:**
- The real `do_action_state.run` → `handle_goal_item` path sends the first selected inventory object's concrete ID, not a bag row's unrelated fields.
- A client `true` produces the existing successful-use log and ends the quest-item branch.
- Client `false` and thrown errors are not reported as success and continue through the same three-attempt target/self/self order before existing routing.
- No item source, extraction/search query, usage pattern, fallback order, combat behavior, or routing policy was added or changed.

**Proving surface:** `quest_item_manager_sylvanas.lua` and `tests/test_do_action_state.lua` AQ-P2-2 S1-S3; the existing S12a direct fallback regression remains green.

### AQ-P2-3 — Interact range
**Status: complete (2026-09-24).** AQ-P1-1 had already removed the decorative `interact_range` row, and remeasurement confirmed that no current menu or production setting reader remained. The final policy is one honest friendly-dispatch gate: **within 5yd (25 squared)**. The named/Questie/NPC-id area paths already used 25. The remaining friendly gaps were the talk/gossip path (36 squared), the visible-object area fallback (a 25yd search radius with no second interaction gate), NAV's 50yd en-route pre-tag (which interacted regardless of distance), and IDLE's objective-first scan (which could apply a caster's 28yd combat band to a friendly objective). Each gap now gates only friendly interaction; hostile combat engagement, pull safety, scan radii, and combat routing remain separate policies.

**Acceptance criteria met:**
- `interact_range` remains absent from the created and rendered menu; no replacement setting, control, or production reader was added.
- The real DO_ACTION talk path interacts at 4yd and routes a named quest NPC at 5.1yd to NAV without a remote interaction.
- The real DO_ACTION visible-object fallback still searches 25yd, but now routes a friendly NPC at 20yd with the fixed 5yd stand-off and still interacts at 4yd.
- The real NAV pre-tag still targets a friendly NPC during its 50yd search, but only calls `interact_with_object` at 4/4.1yd; 5.1yd is refused. Hostile pre-tag behavior at its existing combat scan remains covered.
- The real IDLE objective-first path uses the fixed 5yd gate for friendly units and game objects, while priest hostile P5/P6 behavior and their 28yd combat stand-off remain unchanged.
- Wider 25/50/80/100yd values remain search or combat policies; they are not interaction permissions. No behavior inside the fixed 5yd friendly gate was removed.

**Proving surface:** `quest_state/do_action_state.lua` and `tests/test_do_action_state.lua` P9a-P9c and S30; `quest_state/nav_state.lua` and `tests/test_nav_state.lua` N6/N6a-N6c/N16; `quest_state/idle_state.lua` and `tests/test_idle_state.lua` P1c-P1d plus the existing hostile P4-P7 contract; alongside the AQ-P1-1 menu-removal contract in `tests/test_menu_pull_gate.lua`.

### AQ-P2-4 — Dungeon step evidence
**Status: complete (2026-09-24).** Re-measurement found that the supported Zygor API does not expose step text: `core.addons.zygor.get_current_step()` is documented as `num`, `is_complete`, and `goals[]`; the reader correctly forwards those as `step_num`, `is_complete`, and `goals[]`. The documented goal fields are `action`, `quest_id`, `npc_id`, `target_id`, `target`, `npc`, and `is_complete`—not `text` or `name`. The old detector therefore had a direct, fixture-only step-text lane and a goal lane that did not inspect the production `target`/`npc` labels.

The production change is limited to the existing dungeon-keyword set: the detector now checks the documented `target` and `npc` labels, while retaining `text`/`name` and the optional `step_text` argument for explicit callers. No new dungeon phrases, zone data, routing, navigation, or combat behavior was added. The quest loop still passes the complete step object to `goal_filter.passes`, but it does not fabricate a `step.text` field that the client contract does not provide.

**Acceptance criteria met:**
- The real `zygor_reader` → `goal_filter` → `quest_state/idle_state.lua` path proves the documented step shape, `target`/`npc` dungeon decisions, benign-goal allowance, and the existing in-instance override.
- Existing quest-log dungeon evidence and the explicit step-text detector contract remain covered without claiming unsupported production step text.
- The step-text half of the original premise is closed as a documented client-only unknown, rather than implemented with a mock-only field.

**Proving surface:** `dungeon_detector_sylvanas.lua`, the real reader/IDLE call chain, and `tests/test_dungeon_detector.lua` S1-S7.

### AQ-P2-5 — Anti-detection scope
**Status: complete (2026-09-24).** Re-measurement separated the module's dead compatibility surface from the two live timing/movement policies owned elsewhere.

| Member or related behavior | Measured production caller | Result |
|---|---|---|
| `random_delay` | None | Removed; it only fed the dead `action_delay` helper. |
| `action_delay` | None | Removed; its per-call delay table was dead allocation. |
| `jitter_destination` | None | Removed; no destination producer called it. |
| `varied_tick_interval` | None; `main.lua` uses the engine's fixed pre-tick callback | Removed; no tick cadence was changed. |
| `maybe_camera_jitter` | `coordinator.update` only | Removed its call and implementation: it attempted undocumented `core.input.turn`, which is absent from the supported API and therefore produced no camera action. |
| `react_to_nearby_player` | `coordinator.update` only | Removed its call and implementation: the surrounding scan/return had no consumer, and its only action was the same unavailable `core.input.turn`. |
| `anti_detection_sylvanas` module | No live caller after the above removals | Kept as an empty requireable compatibility shim with no state, randomization, timing, or per-tick work. |
| NAV random jump | `quest_state/nav_state.run` | Retained: it is a real supported `core.input.jump` path, already covered by the real NAV N7 test. It is not a second anti-detection module. |
| Progressive action pacing | `quest_state/do_action_state.run` | Retained: it is the existing anti-loop pause policy, not `action_delay`; its existing P10 coverage remains unchanged. |

The separate random recovery actions in `navigation_sylvanas.lua` were measured but intentionally left untouched because this objective explicitly excludes navigation changes. No new evasion, randomization, timing, combat, routing, navigation, or pull-safety behavior was added.

**Acceptance criteria met:**
- The real coordinator tick no longer loads the retired anti-detection module, carries an anti-detection context member, or calls the unsupported turn path.
- The retired exports are absent, so the old per-call delay-table and destination-table allocations cannot return through the module.
- The genuinely wired NAV jump remains covered through the real NAV handler; the existing real-coordinator allocation battery remains green.

**Proving surface:** `anti_detection_sylvanas.lua`, `quest_state/coordinator.lua`, `tests/test_anti_detection.lua` S1-S2, the existing `tests/test_nav_state.lua` N7, and `tests/test_tick_allocation.lua`.

### AQ-P2-6 — Equipment comparison
**Status: complete (2026-09-24).** The comparison now consumes the client's equipment location data without changing the reward-selection or quality/keyword policy.

**Acceptance criteria met:**
- Name fallback classification visits the existing categories in an explicit order; it no longer depends on `pairs()` hash order.
- Equipped rows use the documented 1-based `slot_id` (worn slots 1–19), and reward/item data uses `quest_item_info.equip_loc`; display names are only fallbacks when authoritative slot data is absent. Non-equipment inventory positions are excluded.
- Paired client slots use the lowest `slot_id` consistently, so an equal-quality comparison cannot change with the order in which the client returns equipped rows. This is ordering only; the existing quality comparison and priority-keyword bonus remain unchanged.
- Both the direct reward scan and the deferred bag recheck use the same slot-aware equipped-row builder. Reward selection remains the existing sell-value choice, including its first-choice behavior on equal prices; no stats, weights, scoring model, or preference policy was added.

- **Destination (2026-09-24 follow-up):** the equip names the slot the comparison resolved, through `core.input.equip_container_item(bag, slot, INVSLOT_*)`, instead of the destination-less `use_container_item` — the client's own documentation says the latter never fills the second ring (12), second trinket (14) or off hand (17). The call's documented result is consumed: `true` ends the request, and an equip that never lands is dropped when the confirmation window expires with the cursor this module loaded handed back. A bind prompt recorded *before* the attempt is no longer answered as its own.

**Proving surface:** `equipment_compare_sylvanas.lua` (`equip_slot_for`), `quest_interaction_sylvanas.lua`, and `tests/test_auto_equip.lua` S6-S6b, S10, S11, S13-S14, and S15-S17 (resolved destinations 11/12/14/17, a refused placement that releases its own cursor once, and an unowned cursor left alone).

### AQ-P2-7 — Paired-slot fill policy
**Status: complete (2026-09-24).** An empty member of a ring/trinket pair is now a destination in its own right, so a reward the worn member beats is worn alongside it instead of being discarded — a second ring or trinket can finally be acquired through the destination AQ-P2-6 wired.

**Acceptance criteria met:**
- Rings (11/12) and trinkets (13/14) only: a candidate that does not beat the worn member is equipped into the free member, exactly as a category that is not worn at all accepts anything; the worn member is never overwritten in that case. A candidate that beats it still goes into the worn member's own slot, unchanged.
- Every previously unambiguous case is unchanged. A read-only 840-case matrix (10 candidate specs x 6 qualities x 14 equipped-row shapes) against the previous revision shows **800 identical decisions with identical destinations, 40 intended rejections-turned-fills (free pair member), and no other difference, in either direction**.
- A member that cannot be proven occupied is never treated as free: a row of the category without a client `slot_id` disables the rule, so an old rejection can never silently become an equip.
- No new stat weighting, scoring model, preference policy, alias-table data, or restructure of the module or the auto-equip lifecycle. Singleton categories are untouched (no pair, no free member).

**Known consequence (recorded, not a defect):** the legacy direct reward scan (`auto_equip_best_reward` called with no recorded selection) takes the first accepted choice, so on an open reward frame it can now take an earlier choice that fills a free pair member where it previously skipped it. `select_best_reward` — the live path — is untouched.

**Proving surface:** `equipment_compare_sylvanas.lua` (`lowest_row_of_category`, `free_pair_member`, `comparison_slots`, `equip_slot_for`), `quest_interaction_sylvanas.lua`, and `tests/test_auto_equip.lua` S18 (second ring/trinket acquired), S19 (no downgrade into an occupied pair or a singleton, plus the unprovable-member guard), and S20 (both pair members empty).

## Completion rule
An objective is complete only after its production surface, focused tests, Lua syntax check, and full EaxAutoQuester battery are green. Client-only unknowns remain explicitly outside this mission.
