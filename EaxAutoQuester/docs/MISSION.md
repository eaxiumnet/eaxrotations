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

**Known consequence (closed by AQ-P2-8).** The legacy direct reward scan (`auto_equip_best_reward` with no recorded selection) took the first accepted choice, so on an open reward frame it could take an earlier choice that only filled a free pair member where it previously skipped it and took a better reward later — a real change to an existing selection outcome. AQ-P2-8 gave that scan its replacement-before-fill order and re-proved the choice against the pre-AQ-P2-7 revision.

**Proving surface:** `equipment_compare_sylvanas.lua` (`lowest_row_of_category`, `free_pair_member`, `comparison_slots`, `equip_slot_for`), `quest_interaction_sylvanas.lua`, and `tests/test_auto_equip.lua` S18 (second ring/trinket acquired), S19 (no downgrade into an occupied pair or a singleton, plus the unprovable-member guard), and S20 (both pair members empty).

### AQ-P2-8 — Direct reward-scan preference order
**Status: complete (2026-09-24).** The direct scan answers with the first choice that REPLACES what is worn, holding a choice that only fills a free pair member as the fallback, so AQ-P2-7's wider accept set can no longer trade away a better reward.

**Reachability (measured, not assumed):** the scan is the branch of `auto_equip_best_reward` taken when no selection is recorded. Production reaches it from `handle_quest_detail`'s reward-frame branch, which calls `select_best_reward()` and then `auto_equip_best_reward()` in the same tick on a frame that publishes choices. `select_best_reward` records nothing when no choice publishes a sell price (`best_idx == 0`), when its own `get_quest_reward` call fails, or when the selected reward carries no resolvable item id — each leaves a live reward frame with an unrecorded selection, which is the state the scan runs in. The coordinator tick reaches it only through `process_auto_equip`, which returns before the scan while nothing is pending.

**Acceptance criteria met:**
- The scan keeps the first choice that replaces something (including a category that is not worn at all) exactly as it did before AQ-P2-7, and falls back to the first fill only when no choice replaces anything.
- Exactly one reward choice is ever selected: a held fill is selected only if nothing replaced something.
- `select_best_reward` — the live, sell-price-based selection path — is untouched.
- No new stat weighting or scoring model: the order is the accept decision's own kind, which the comparison already computes and now reports as its third return.

**Proof:** a read-only 264-frame matrix driving both revisions' real scan against the pre-AQ-P2-7 revision (`95731203e`) shows **246 identical selections, 18 intended selections where the old revision chose nothing (fills), and no unexplained difference** — including the traded-away-better-reward frame (a fill at choice 1, a replacement at choice 2), which answers choice 2 again as it did before AQ-P2-7. The decision layer is re-proven against the same revision: 840 cases, **800 identical decisions (identical slot returns), 40 intended fills, 0 unexplained**.

**Proving surface:** `quest_interaction_sylvanas.lua` (`auto_equip_best_reward`'s scan), `equipment_compare_sylvanas.lua` (`should_equip`'s third return), and `tests/test_auto_equip.lua` S21 (the traded-away reward, driven through `handle_quest_detail`) and S22 (a fill-only frame still takes its first fill; an unusable frame takes nothing).

## P3 — the live objective path

### AQ-P3-1 — A quest object is the destination
**Status: complete (2026-09-24).** Live log, step 7 of the guide: `DO_ACTION: area goal — npc_id=233818 target=Ogre Remains`, then `SPAWN PATROL: 5 spawn point(s)`, legs at 108yd and 113yd, `spawn point 2 unreachable`, and not one click — the objective was a quest game object and the bot searched for it forever.

**Objective:** a step whose goal names an interactable game object is walked to and used, instead of being handed to a spawn sweep that cannot describe it.

**Acceptance criteria met:**
- A visible quest object (a non-unit the goal's own name/identity matches) is approached and used before any search leg is published. The approach destination is the object, so the walk is never overwritten by a search point.
- A UNIT carrying the goal's id keeps the existing id/patrol order, unchanged: kill steps behave exactly as before.
- With no visible objective the sweep still runs, and its candidates are unchanged.
- The sweep no longer publishes a leg for a place the player is standing on: arrival is measured on the ground plane, because a guide waypoint arrives from the map conversion with `z=0` and a 3D compare read the waypoint underfoot as hundreds of yards away (`spawning spawn point 5/5 (0yd)`).
- A place the client has already refused is not offered again, and a leg that merely ended is no longer reported as `unreachable` — the client's word (`shared/nav_destination.lua`) is the only source of that verdict.
- A turn-in frame that shows MONEY is never claimed with `accept_quest`: money is paid for a quest already handed in, so the dialog is closed and the verb reported is the one actually performed. An offer-shaped frame (choice links, no money) is still claimed.
- The IDLE goal line reports the goal's id wherever it is carried (`targetid`, `id`, the `{name,id}` pairs) and is logged on a change instead of every tick, so the decisions are readable.

**Proving surface:** `quest_state/do_action_state.lua` (`visible_quest_object`), `shared/spawn_patrol.lua` (`ground_sq`, `choose`, the leg-end verdict), `quest_interaction_sylvanas.lua` (the money/accept gate), `quest_state/idle_state.lua` (the goal line), and `tests/test_do_action_state.lua` S31–S34, `tests/test_spawn_patrol.lua` P16–P18, `tests/test_quest_turnin.lua` S9, `tests/test_idle_state.lua` P17.

**Client-only unknown (explicitly outside this mission):** whether the world object for a given guide id is within the client's object stream at the step's waypoints. The code path is proven; the walk to a coordinate the guide supplies is the client's answer. `docs/quest_object_objectives.md` is the runbook for that check.

## P4 — quest-object coordinates

### AQ-P4-1 — Game-object spawn index with a no-data fallback
**Status: complete (2026-09-24).** A Zygor objective's one id field can name either a creature entry or a `gameobject_template` entry. The existing creature index could answer only the former, so a named game object had no coordinates beyond the guide's own waypoints.

**Objective:** resolve a game-object goal's entry, or its whole name when no entry is usable, to the coordinates it spawns at, while retaining the pre-index sweep whenever the generated data is absent.

**Acceptance criteria met:**
- `object_spawns.lua` exposes the same two-question shape as `npc_spawns.lua`: spawn rows by entry, and ids by world name. Exact whole-name matches win; substring matching is the bounded fallback.
- `shared/spawn_patrol.lua` asks both namespaces for each goal id and merges their rows before adding the step waypoints. A visible objective still outranks the sweep; a UNIT kill goal retains its existing creature-patrol order.
- The first build logs `object spawn index supplied N point(s)` only when object-index coordinates actually supplied candidates. No index, an unknown entry, and an absent chunk are silent: the candidate list is exactly the step waypoints it was before this work.
- The generated chunks and manifest are build output, not tracked source. `tools/generate_object_spawns.py` makes them reproducibly from cMaNGOS SQL or CSV, with type filtering, optional named-entry overrides, dedup, `--check`, and an embedded `--self-test`.
- No destination, map conversion, visible-object interaction, combat rule, or menu setting is invented when the extract is missing.

**Proving surface:** `object_spawns.lua`, `shared/spawn_patrol.lua`, `tools/generate_object_spawns.py`, `tests/test_object_spawns.lua` O1-O8, and `tests/test_spawn_patrol.lua` P19-P22. The operator procedure is in `docs/objective_coordinates.md`; the live interpretation is in `docs/quest_object_objectives.md`.

**Client-only unknown (explicitly outside this mission):** the source dump is not in this checkout, so the shipped index intentionally has no generated data and the real Ogre Remains coordinates are not locally verified. Even with the extract, the client alone decides whether a recorded object is loaded, spawned, and interactable at that coordinate.

### AQ-P4-2 — Terrain-fixed movement-only area sweep
**Status: complete (2026-09-24).** The live reachability loop reported `arrived` while the player remained 13yd from a step waypoint, then IDLE offered the same place again. A guide conversion can carry `z=0`; publishing that raw point lets the client snap to an off-mesh location and the sweep can retire a waypoint that was never actually tested at its terrain position.

**Objective:** make every movement-only area-sweep waypoint pass through the existing terrain-height owner before distance selection, retirement checks, and NAV publication, without adding a per-tick raycast storm.

**Acceptance criteria met:**
- `quest_state/idle_state.lua` owns one cached `waypoint_fixer` handle and applies it to the final current waypoint, goal-resolver replacement, flight/inn destinations, and each movement-only step waypoint.
- The area sweep repairs each waypoint once per step/place, keyed against the fresh reader list, and reuses the repaired vec3 on later ticks. A changed x/y invalidates the cached repair.
- Arrival, nearest-waypoint selection, unreachable/retired checks, and the destination handed to NAV all use the same repaired point; a raw `z=0` list is never the area sweep's publication source.
- A new step clears the repair cache. The existing no-fix graceful fallback remains: a missing fixer returns the original point rather than crashing or inventing a height.
- No combat, interaction, menu, or navigation policy changes; the client still decides whether a repaired point is on its reachable mesh.

**Proving surface:** `quest_state/idle_state.lua` (`fix_destination_z`, movement-only sweep), `quest_state/coordinator.lua` (`_area_waypoint_fixes` declaration), and `tests/test_idle_state.lua` P18. The existing arrival probe remains in `tests/test_nav_client_contract.lua` C14-C14d.

**Client-only unknown (explicitly outside this mission):** whether the repaired coordinate is on the client's current navmesh, and whether a source waypoint is stale for the live quest. The fix removes the known raw-height publication path; it cannot make an off-mesh or stale source point reachable.

### AQ-P4-3 — Session recorder and replay contract
**Status: complete (2026-09-24).** The quester could print a live failure but could not preserve the decision sequence that produced it. A log line was evidence, not a reproducible regression input.

**Objective:** capture a bounded live quester session, export it without an unsupported file-write dependency, and replay it as a deterministic failing test when the named navigation symptoms recur.

**Acceptance criteria met:**
- `session_recorder_sylvanas.lua` is opt-in, preallocated, bounded to 2,048 events, and exports chronological JSONL without `io`, network, or client mutation.
- The coordinator captures existing log lines before the debug-display gate and adds structured state, area-waypoint, short-arrival, arrival, retirement, and abandonment events. Existing debug output and state behavior are unchanged when recording is off.
- The recorder is explicitly startable/stoppable/exportable through `quest_state`, so a developer can capture a reproduction without a new menu or persistence API.
- `tools/replay_session.py` accepts recorder JSONL and raw client logs, never executes recorded content, prints line/rule/place findings, and exits non-zero for short arrivals, unrepaired raw-height waypoints, retired waypoints, or abandoned destinations.
- A passing replay means only that the named symptoms did not occur; it does not claim the live client is correct.

**Proving surface:** `session_recorder_sylvanas.lua`, `quest_state/coordinator.lua` (capture seam and public session API), `quest_state/idle_state.lua` / `quest_state/nav_state.lua` (structured event producers), `tests/test_session_recorder.lua` R1-R4, and `tools/replay_session.py --self-test`. The operator guide is `docs/session_replay.md`.

**Client-only unknown (explicitly outside this mission):** whether a developer's client console can persist the returned JSONL string in their particular tooling. The recorder and replay formats are complete without inventing an API the client does not document.

### AQ-P4-5 — Per-character profile system
**Status: complete (2026-09-24); profession-detection follow-up complete (2026-09-25).** Character settings are now isolated by name and realm for the current client session, with safe defaults for a first character and no cross-character leakage. A new profile also seeds its four supported gathering routes from the client's learned professions.

**Acceptance criteria met:**
- `character_profile_sylvanas.lua` captures and restores the four gathering-profession preferences, the vendor bag threshold, the existing three pull-policy controls, and the mount-use choice when the active character changes.
- For each newly created profile it reads the documented `core.spell_book.get_professions()` and `core.spell_book.get_profession_info(index)` surface once and maps the reported `skill_line` id into the four existing checkboxes, so detection is independent of the client language. The four ids (182 Herbalism, 186 Mining, 356 Fishing, 393 Skinning) are derived from this repo's 2.5.5 DBC `SkillLineAbility` rows, not guessed; localized names remain only as a fallback for a build that leaves `skill_line` empty. The checkboxes stay the manual override afterward, detection never repeats on later activations, and it never runs on the tick path.
- The same one-shot pass emits one `core.log` line per new profile listing every present profession slot with its skill level, the supported professions it unlocked, and — when detection is unavailable — the reason, so the in-game smoke check is a single glance.
- `main.lua` activates and synchronizes the active profile before the enable/state path, including while the quester is disabled, so menu edits are captured before a character switch.
- The real pull gate continues to read the existing menu rows; the real vendor fullness owner reads the profile threshold; the real mount manager refuses automatic casts when mount use is off while keeping dismount safety unconditional.
- A nameless or unreadable player stays on the established defaults and is never assigned another character's profile.
- Profiles are explicitly session-scoped because the supported runtime has no documented file-write API; no unsupported persistence mechanism is introduced.
- A missing/failing/tableless profession surface, an unsupported profession such as Alchemy, or an unrecognized localized name leaves the route off. The side-effecting `core.profession.open_profession` opener is never called, and the `core.profession` enum is never treated as discovery data.
- Gathering preferences now drive a bounded IDLE route: it runs only with no active guide goal/waypoint, scans at most 50 visible non-unit objects within 50yd once per second, recognizes a conservative client-name vocabulary, NAVs to enabled nodes, and uses the existing `use_object` plus cast/channel pause. Active quests, combat, frames, and casts always outrank it.
- Gathering also stops when the bags hold fewer than this character's reserve, read through the exported `loot_manager_sylvanas.get_bag_space()` — the single inventory-helper owner the loot gate already uses, so both gates share one set of free/total/used numbers. The reserve is a per-character slider (`eaxaq_profile_gather_min_free_slots`, 0-16, default 4 to match the loot gate; 0 turns the bag gate off), clamped on capture and on read. An in-progress node is abandoned and its NAV cleared; a blocked check is throttled to the scan cadence. An unreadable inventory does not block, and the profile vendor threshold remains the backstop.
- A bag-blocked route raises the same `_force_vendor_soon` flag the fullness trigger uses and stays `IDLE`, so the coordinator's force-vendor route actually sends it to a vendor — the reserve is a slots rule that bites long before the fullness percentage, and without this the bot would simply stop gathering and stand there. The flag also makes the vendor sell up to green, which is what frees the slots. The request is idempotent and paced by a 180s retry so a visit that freed nothing cannot become a vendor trip loop; the vendor clears the flag when it handles the visit.
- Both raisers record **why** in `_force_vendor_reason` and the vendor clears the reason with the flag, so the coordinator's `force vendor` log line names the cause that actually asked for the visit. It previously always printed the fullness threshold, which sent a reader looking at nearly-empty bags after a gather block. A request that arrives with no recorded cause falls back to the character threshold rather than a hardcoded 80.

**Proving surface:** `character_profile_sylvanas.lua`, `main.lua`, `menu_sylvanas.lua`, `loot_manager_sylvanas.lua`, `mount_manager_sylvanas.lua`, `quest_state/idle_state.lua`, `quest_state/coordinator.lua`, `tests/mock_core.lua`, `tests/test_character_profiles.lua` P1h-P1j/P5d/P6-P10, `tests/test_gathering_profile.lua` G1-G14, `tests/test_menu_pull_gate.lua` M7, `tests/test_vendor_bag_trigger.lua` S1c/S5b/S6e-S6f/S7/S8, and the in-game verification steps in `docs/client_runbook.md`, `loot_manager_sylvanas.lua` `M.get_bag_space`, `tests/test_menu_pull_gate.lua` M6, `tests/test_vendor_bag_trigger.lua` S2b-S2d, and `tests/test_mount_manager.lua` H16. The behavior, gathering limits, profession-detection boundary, and persistence boundary are documented in `docs/character_profiles.md`.

**Client-only unknown (explicitly outside this mission):** whether the target Sylvanas client returns populated `get_professions()`/`get_profession_info()` results at the moment the first character profile is created, and whether it populates `skill_line` on that info table. The Lua battery proves the wiring against the documented contract, not that runtime answer; the startup diagnostic's `[skill N]` field shows which path fired. An empty, late, or unsupported result is safe — the four checkboxes stay at their manual off defaults and no profession is assumed — but the in-game result still needs one smoke check.

### AQ-P4-6 — Reached-path memory
**Status: complete (2026-09-25).** Within a client session, ground the quester has already stood on is not walked again.

**Acceptance criteria met:**
- The area sweep records the PLACE it reaches — not the slot the guide returned — in a session-scoped bounded table (`shared._reached_places`, owned by `quest_state/idle_state.lua`, declared in the coordinator). The reader hands back a fresh table every tick, so a slot index says nothing about which ground it names.
- A candidate the character has already stood on is skipped for selection exactly like a retired or visited waypoint, so a later pass — or a later step crossing the same route — walks only what has not been covered.
- The memory deliberately SURVIVES a step change and a new sweep pass, which is the whole point: `visited` is per-pass and retirement is per-step, so both used to let a covered route come back in full. The per-step retirement contract (P15) is untouched — a place the client refused is still retried once per pass, because a refusal is never a "reached" place.
- Keyed by rounded numeric coordinates, so the per-candidate check on the tick path allocates nothing (the tick-allocation bound is unchanged at 0.00 B in IDLE).
- Bounded to `REACHED_PLACE_LIMIT = 64` places; the oldest insertion is dropped first, so a long session cannot grow the table without limit.
- Session-scoped only, exactly like the per-character profiles: the runtime has no file-write API, so nothing is persisted across a restart and none is claimed.
- The sweep is movement-only (it runs only when there is no target), so skipping a covered waypoint forfeits no trigger the bot still owes — a kill/loot/interact goal is handled by the goal path, not the sweep.

**Proving surface:** `quest_state/idle_state.lua` (the `place_reached` / `remember_reached_place` owners and the sweep call sites), `quest_state/coordinator.lua` (`_reached_places` declaration), `tests/test_idle_state.lua` P19a-P19j: first pass still walks and reaches both waypoints (memory never blocks first-time walking), a post-relap pass re-walks nothing, a re-ordered list still walks only a genuinely new waypoint, a new step does not resurrect covered ground, and the 64-place cap holds under 90 distinct reached places. The in-game verification steps are in `docs/client_runbook.md`.

## Completion rule
An objective is complete only after its production surface, focused tests, Lua syntax check, and full EaxAutoQuester battery are green. Client-only unknowns remain explicitly outside this mission.
