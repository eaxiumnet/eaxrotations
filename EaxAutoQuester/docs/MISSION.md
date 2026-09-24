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
Make normal corpse looting set the documented force-vendor state; acceptance is a real idle/corpse-loot path test for the flag and navigation response.

### AQ-P1-3 — Bank/repair service gossip
Make bank and repair reachable from the quest-loop path while retaining inn handling; acceptance is a service-gossip path test without manually supplied service flags.

### AQ-P1-4 — Failure policy
Define and wire the non-abandon policy for recorded quest failures; acceptance is a persistent-failure test that skips/notifies without calling `abandon_quest`.

## P2 — correctness and usability

### AQ-P2-1 — Transport locality
Make transport selection truly nearest and prevent cross-map fallback for flight/inn/vendor navigation; acceptance is map-and-distance path tests.

### AQ-P2-2 — Quest-item identity and result tracking
Replace the remaining quest-item name/word fallback and the false-success `pcall` contract; acceptance is item identity and result-path tests.

### AQ-P2-3 — Interact range
Make the rendered interaction range setting authoritative, or remove it; acceptance is a setting-to-distance test.

### AQ-P2-4 — Dungeon step evidence
Pass step text into dungeon filtering and prove both goal- and step-text decisions; acceptance is a goal-filter test matrix.

### AQ-P2-5 — Anti-detection scope
Wire or deliberately remove destination jitter, action delay, and varied ticks; acceptance is a production-call matrix and an allocation check for retained members.

### AQ-P2-6 — Equipment comparison
Replace unordered name-only classification/quality-only comparison with deterministic, slot-aware comparison; acceptance is classifier and upgrade-path tests.

## Completion rule
An objective is complete only after its production surface, focused tests, Lua syntax check, and full EaxAutoQuester battery are green. Client-only unknowns remain explicitly outside this mission.
