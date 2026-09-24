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
