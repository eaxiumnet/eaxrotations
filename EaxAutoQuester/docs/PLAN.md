# EaxAutoQuester gap-closure plan

## Execution order

| Order | Objective | Work | Exit proof |
|---:|---|---|---|
| 1 | **AQ-P0-1** | Add deferred reward ownership, helper-backed reward lookup, valid bag-slot equip, and bounded confirmation handling through the coordinator seam. | Auto-equip suite plus confirm-input/coordinator tests; syntax and full battery. |
| 2 | **AQ-P0-2** | Replace only the three audited raw container-item calls with `core.input.use_item(item_id)`. | Focused item/navigation/death-flow tests; syntax and full battery. |
| 3 | **AQ-P1-1** | Decide and implement wire-or-hide for every currently rendered dead menu control. | Menu contract tests. |
| 4 | **AQ-P1-2** | Connect the live corpse-loot path to force-vendor navigation. | Corpse-loot → vendor trigger integration test. |
| 5 | **AQ-P1-3** | Supply bank/repair intent to service gossip through its production caller. | Service-gossip and quest-interaction path tests. |
| 6 | **AQ-P1-4** | Specify and wire the retained-failure policy without quest abandonment. | Blacklist/progress integration tests. |
| 7 | **AQ-P2-1** | Correct transport locality and remove cross-map service fallback. | NPC database and transport path tests. |
| 8 | **AQ-P2-2** | Pin the selected inventory object's client ID and distinguish issued use from successful use. | Real DO_ACTION quest-item identity/result tests. |
| 9 | **AQ-P2-3** | Keep the removed control gone and align every friendly interaction dispatch site to the fixed 5yd gate; preserve hostile combat and search policies. | Real DO_ACTION, NAV, and IDLE boundary tests plus menu-removal tests. |
| 10 | **AQ-P2-4** | Re-measure the Zygor contract; use documented `target`/`npc` goal evidence without inventing an unsupported `step.text` field. | Real reader/IDLE goal-filter matrix, including the documented in-instance override. |
| 11 | **AQ-P2-5** | Retire the dead anti-detection members and coordinator hook; retain the separately owned, supported NAV jump and existing action pacing. | Real coordinator/NAV call matrix plus the existing allocation battery. |
| 12 | **AQ-P2-6** | Make equipment classification deterministic and slot-aware from client `equip_loc`/`slot_id`, preserving the quality/keyword policy. | Equipment-comparison and real deferred reward tests, including an equal-quality slot-order tie. |
| 13 | **AQ-P2-7** | Treat an empty member of a ring/trinket pair as a destination, so a reward the worn member beats is worn alongside it instead of discarded. | Real reward-path tests for acquiring a second ring/trinket, for no downgrade into an occupied pair or a singleton, and for both members empty; plus a read-only decision matrix against the previous revision. |
| 14 | **AQ-P2-8** | Give the direct reward scan a replacement-before-fill order, so a widened accept set cannot trade away a better reward. | Real `handle_quest_detail` test of the traded-away reward, a fill-only frame, and an unusable frame; plus read-only scan and decision matrices against the pre-AQ-P2-7 revision. |
| 15 | **AQ-P3-1** | Make a visible quest object outrank the search sweep, and make the sweep's arrival and refusal reporting honest. | Object-path, patrol, turn-in, and goal-diagnostics tests plus the client runbook. |
| 16 | **AQ-P4-1** | Add a generated quest game-object coordinate index and query it alongside the existing creature index, with the pre-index waypoint fallback when no extract is present. | Index no-data and identity tests; sweep entry/name/namespace tests; generator self-test and drift check. |
| 17 | **AQ-P4-2** | Repair and cache every movement-only area-sweep waypoint through the terrain-height owner before selection, retirement, and NAV publication. | IDLE terrain-fix/cache regression plus the existing nav-client arrival probe. |
| 18 | **AQ-P4-3** | Capture a bounded live quester session and replay its JSONL/raw log as a deterministic regression contract. | Recorder R1-R4 plus replay runner self-test and a failing raw-log probe. |
| 19 | **AQ-P4-5** | Isolate settings by character name/realm and wire the profile-backed vendor, pull, mount, and gathering fields through the real menu/owners; seed the four supported gathering routes once from the client's learned professions, keep the checkboxes as manual overrides, run gathering only when no guide goal/waypoint is active, and log one startup diagnostic line per new profile. | Profile isolation/restoration, one-shot locale-proof profession detection (verified skill-line ids) + one-line diagnostic, manual-override proofs, four-profession route with a shared bag-free-slot reserve, quest-priority, menu-row, vendor-threshold, mount-gate, and full-battery proofs; explicit session-persistence boundary. |
| 20 | **AQ-P4-6** | Remember the places the character has actually reached during the session and stop the area sweep re-walking them on a later pass or a later step. | Reached-path P19a-P19j: first pass still walks, post-relap pass re-walks nothing, re-ordered list walks only the new waypoint, new step does not resurrect covered ground, 64-place cap holds; per-step retirement contract and the tick-allocation bound unchanged. |

## Current execution state

- [x] AQ-P0-1 — reward auto-equip and bind-on-equip path
- [x] AQ-P0-2 — three invalid item-use call sites
- [x] AQ-P1-1 — menu contract
- [x] AQ-P1-2 — live autoloot/vendor pressure
- [x] AQ-P1-3 — bank/repair service gossip
- [x] AQ-P1-4 — failure policy
- [x] AQ-P2-1 — transport locality
- [x] AQ-P2-2 — quest-item identity and result tracking
- [x] AQ-P2-3 — interact range
- [x] AQ-P2-4 — dungeon step evidence (documented step shape; `target`/`npc` goal labels; unsupported `step.text` not invented)
- [x] AQ-P2-5 — anti-detection scope (dead module surface retired; supported NAV jump/pacing retained)
- [x] AQ-P2-6 — deterministic equipment classification, client-slot-aware comparison, and stable paired-slot tie handling
- [x] AQ-P2-7 — the empty member of a ring/trinket pair is a destination (second ring/trinket acquired; no downgrade into an occupied pair or a singleton)
- [x] AQ-P2-8 — the direct reward scan prefers a replacement over an earlier fill (choice re-proved against the pre-AQ-P2-7 revision; `select_best_reward` untouched)
- [x] AQ-P3-1 — a quest object is the destination (visible object outranks the spawn sweep; ground-plane arrival; refused places not re-offered; a money turn-in is never accepted; the goal line reports the real id once per change)
- [x] AQ-P4-1 — quest-object coordinates (a generated cMaNGOS game-object index is optional at runtime; entries and names resolve through the sweep; a checkout without its extract keeps the original waypoint-only behavior)
- [x] AQ-P4-2 — terrain-fixed area sweep (each movement-only waypoint is repaired once per place, cached across fresh reader tables, and published with the repaired Z)
- [x] AQ-P4-3 — session replay (opt-in bounded JSONL capture, structured navigation events, and a dependency-free runner that fails named live-loop symptoms)
- [x] AQ-P4-5 — per-character profiles (name/realm isolation for gathering preferences, vendor bag threshold, pull policy, and mount use; opt-in nearby-node gathering is active only without a guide goal/waypoint; session-scoped because the runtime has no documented file-write API)
- [x] AQ-P4-6 — reached-path memory (the places the character actually stood on are remembered by rounded coordinates and skipped on a later sweep pass or a later step; bounded to 64 places; session-scoped, never persisted)

## Verification protocol for each execution step

1. Change only the objective's production surface and its focused tests.
2. Run Lua 5.1 `luac -p` on every changed Lua file.
3. Run the focused suite(s) through the pinned Lua 5.1 interpreter.
4. Run `lua EaxAutoQuester/tests/run_quester_tests.lua` for the full 65-suite battery.
5. Before task completion, run the repository-mandated rotation and leveling batteries as well.

## Execution complete

All eighteen objectives, AQ-P0-1 through AQ-P4-3, remain complete, and AQ-P4-5 and AQ-P4-6 are now complete as well; AQ-P4-4 remains the next roadmap item. AQ-P4-6 adds the session's reached-path memory: the area sweep now records the place it reaches (rounded x/y, not the guide's slot index) and skips ground already covered on a later pass or a later step, bounded to 64 places and never persisted, while leaving the per-step retirement contract and the tick-allocation bound untouched. AQ-P2-6 follow-up (2026-09-24): the comparison's resolved slot is now the equip's destination (`core.input.equip_container_item`), so the reward lands where the decision was made instead of wherever the client's destination-less use put it; the call's result is consumed and an abandoned equip hands its cursor back. AQ-P2-6 closed the final equipment-comparison gap: the comparator now uses deterministic slot classification and the client's `equip_loc`/`slot_id` data, while the real selected-reward path proves both slot overrides and an equal-quality paired-slot tie without changing reward-selection or quality/keyword policy.

AQ-P3-1 (2026-09-24) closes the live "Ogre Remains" loop: a quest object's goal carried an id the creature spawn index cannot resolve, so `do_action_state` handed every tick to `shared/spawn_patrol.lua`, whose candidates were the step's own waypoints — including one under the player, because arrival was measured in 3D against a waypoint whose height is `z=0`. The object was found and approached in the mock harness and its destination overwritten by the next sweep leg before it was ever walked. The object now outranks the sweep (units do not), arrival is measured on the ground plane, a place the client refused is not offered again, and a refused money turn-in is closed instead of accepted. `docs/quest_object_objectives.md` is the client runbook.

AQ-P4-1 (2026-09-24) makes the fallback a real coordinate source: an optional generated game-object index resolves an objective's entry or whole name and the sweep merges it with the creature index and guide waypoints. Its data is build output, so a checkout without the cMaNGOS extract is explicitly supported and unchanged. `docs/objective_coordinates.md` records generation and `docs/quest_object_objectives.md` explains the live evidence.

AQ-P4-2 (2026-09-24) closes the raw-height half of the area-waypoint loop: IDLE now repairs every movement-only step waypoint through the cached terrain owner before choosing, retiring, or publishing it. The known `z=0`/13yd-short path is removed without claiming that a stale or genuinely off-mesh source point becomes reachable; the client remains the final navmesh authority.

AQ-P4-3 (2026-09-24) makes a reproduction durable: an opt-in fixed-ring recorder captures log and structured navigation events, and `replay_session.py` turns the export or a raw client log into a non-zero regression check for short arrivals, unrepaired raw-height waypoints, retirement, and abandonment. It adds no runtime persistence or recorded-code execution.
