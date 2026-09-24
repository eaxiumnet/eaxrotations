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
| 8 | **AQ-P2-2** | Tighten quest-item identity and distinguish issued use from successful use. | Quest-item manager tests. |
| 9 | **AQ-P2-3** | Make interact range authoritative or remove the control. | Menu/NPC-manager distance tests. |
| 10 | **AQ-P2-4** | Preserve and use step text in dungeon filtering. | Dungeon detector/goal-filter matrix. |
| 11 | **AQ-P2-5** | Wire or remove the unused anti-detection members. | Production-call and allocation tests. |
| 12 | **AQ-P2-6** | Make equipment classification deterministic and slot-aware. | Equipment-comparison and reward tests. |

## Current execution state

- [x] AQ-P0-1 — reward auto-equip and bind-on-equip path
- [x] AQ-P0-2 — three invalid item-use call sites
- [x] AQ-P1-1 — menu contract
- [x] AQ-P1-2 — live autoloot/vendor pressure
- [x] AQ-P1-3 — bank/repair service gossip
- [x] AQ-P1-4 — failure policy
- [ ] AQ-P2-1 — transport locality
- [ ] AQ-P2-2 — quest-item identity and result tracking
- [ ] AQ-P2-3 — interact range
- [ ] AQ-P2-4 — dungeon step evidence
- [ ] AQ-P2-5 — anti-detection scope
- [ ] AQ-P2-6 — equipment comparison

## Verification protocol for each execution step

1. Change only the objective's production surface and its focused tests.
2. Run Lua 5.1 `luac -p` on every changed Lua file.
3. Run the focused suite(s) through the pinned Lua 5.1 interpreter.
4. Run `lua EaxAutoQuester/tests/run_quester_tests.lua` for the full 61-suite battery.
5. Before task completion, run the repository-mandated rotation and leveling batteries as well.

## Next objective

AQ-P2-1 — transport locality — is next. It must make transport selection nearest and prevent cross-map service fallback for flight, inn, and vendor navigation.
