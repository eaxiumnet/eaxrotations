# EAXWarriorFury/

## Responsibility

Fury Warrior addon module for TBC Classic on Sylvanas. It provides the full combat loop plus out-of-combat automation, menu/UI, threat/defensive logic, consumables, mounting/vendor helpers, and visual telemetry.

## Design

- **Addon-first layout**: `EAXWarriorFury.toc` loads `header.lua`, `utils.lua`, `spells.lua`, `menu.lua`, then `main.lua`.
- **Shared-manager heavy**: combat decisions are split across small managers (`resource_gate`, `interrupt_manager`, `defensive_manager`, `ooc_manager`, `vendor_automation`, `consumables_manager`, `mount_manager`, `leveling_manager`, `threat_manager`, `dps_runtime`, etc.).
- **Hot-path caching**: `main.lua` aliases core API calls locally and reuses cached visual/state tables to reduce frame-time overhead.
- **Rotation context separation**: `rotation_context.lua` wraps `combat_context` with a short refresh window for stance/target-sensitive decisions.
- **Data-driven spells**: `spells.lua` centralizes rank tables, buffs, debuffs, stances, racials, and consumables.

## Flow

1. `menu.lua` builds the in-game control panel and persists user toggles/sliders.
2. `utils.lua` resolves spell ranks and provides targeting/cast helpers.
3. `main.lua` initializes managers, caches spell IDs, and hooks Sylvanas update/render callbacks.
4. Each tick, `main.lua` updates combat/visual runtime, reactive state, target snapshots, and ESP/HUD telemetry.
5. The priority lane then evaluates rage, stance, swing timing, burst windows, interrupts, utilities, and AoE/single-target branches.

## Integration

- **Sylvanas API**: uses `core.menu`, `core.object_manager`, `core.spell_book`, `core.register_on_update_callback`, and render/menu hooks.
- **Shared utilities**: imports `common/utility/auto_attack_helper`, `common/utility/key_helper`, `common/utility/control_panel_helper`, `common/modules/buff_manager`, and `common/modules/spell_queue`.
- **Combat framework**: integrates `combat_context`, `rotation_context`, `reactive_runtime`, `esp_renderer`, `visual_state`, `ttd_tracker`, `dps_meter`, and `cooldown_tracker`.
- **Gameplay managers**: wired to `racial_manager`, `defensive_manager`, `interrupt_manager`, `ooc_manager`, `vendor_automation`, `consumables_manager`, `mount_manager`, `leveling_manager`, `threat_manager`, and `set_bonus`.
