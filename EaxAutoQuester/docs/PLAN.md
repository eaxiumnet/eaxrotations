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
| 12 | **AQ-P2-6** | Make equipment classification deterministic and slot-aware. | Equipment-comparison and reward tests. |

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
- [ ] AQ-P2-6 — equipment comparison

## Verification protocol for each execution step

1. Change only the objective's production surface and its focused tests.
2. Run Lua 5.1 `luac -p` on every changed Lua file.
3. Run the focused suite(s) through the pinned Lua 5.1 interpreter.
4. Run `lua EaxAutoQuester/tests/run_quester_tests.lua` for the full 61-suite battery.
5. Before task completion, run the repository-mandated rotation and leveling batteries as well.

## Next objective

AQ-P2-6 — equipment comparison — is next. AQ-P2-5 retired the dead anti-detection compatibility surface and its invalid coordinator camera hook; the supported NAV jump and existing action pacing remain separately owned and covered.
