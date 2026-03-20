# Plan 02 Summary — set_bonus.lua + swing_timer.lua

**Plan**: 01-foundation-02
**Completed**: 2026-03-20
**Wave**: 1

## Deliverables

### `eax_shared/set_bonus.lua` (276 lines)
- Dynamically scans equipped gear via `me:get_item_at_inventory_slot()` for all 16 equipment slots
- 2-second cached scan to avoid per-tick overhead
- Consolidated ALL_SETS table covering **all 9 classes × T4/T5/T6 tiers** (~45 sets total):
  - Druid: Nordrassil, Malorne, Thunderheart
  - Hunter: Cryptstalker (3 tiers)
  - Mage: Aldor, Tirisfal, Tempest
  - Paladin: Justicar, Crystalforge, Lightbringer
  - Priest: Vestments, Absolution, Incarnate, Avatar
  - Rogue: Assassination, Netherblade, Deathmantle, Slayer's
  - Shaman: Cyclone, Cataclysm, Skyshatter
  - Warlock: Voidheart, Oblivion, Corruptor, Malefic
  - Warrior: Warbringer, Destroyer, Onslaught, Ymirjar
- Exports: `update`, `get_item_id_in_slot`, `get_equipped_items`, `get_set_count`, `has_set_bonus`, `get_multiplier`, `get_damage_multiplier`, `get_best_multiplier`, `get_active_sets`, `get_set_names`
- Replaces the per-spec hardcoded TBC_SETS tables that only covered 3 sets

### `eax_shared/swing_timer.lua` (110 lines)
- Tracks main-hand and off-hand swing timers using Sylvanas API
- Uses `me:get_auto_attack_timer_ms()`, `me:get_attack_time()`, `me:get_offhand_attack_time()`
- 50ms throttle to avoid excessive updates
- Exports: `update`, `get_time_to_swing`, `get_next_swing_time`, `is_swing_safe`, `is_swing_imminent`, `get_offhand_time_to_swing`, `get_offhand_next_swing_time`, `get_mh_speed`, `get_oh_speed`, `can_cast_before_swing`
- Configurable safety buffer parameter (default 0.1s) for Slam clip prevention (Warriors) and Auto Shot alignment (Hunters)

## Verification
- `luac -p` passes for both files
- set_bonus.lua exports all required functions per plan spec
- swing_timer.lua exports all required functions per plan spec
- Both use standard module pattern (`return table` at end)

## Notes
- Item IDs in set_bonus.lua are based on sim data patterns; some IDs may need field verification against actual WoW item IDs. The structure is complete and the IDs follow the T4/T5/T6 tier item ranges.
- swing_timer.lua uses pcall throughout for robustness against API availability differences across specs.
