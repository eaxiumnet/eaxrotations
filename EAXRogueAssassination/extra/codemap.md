# EAXRogueAssassination/

## Responsibility

TBC Assassination Rogue automation for Sylvanas. It handles combat rotation, poison application, interrupts, defensive cooldowns, out-of-combat vendor/mount logic, leveling fallback behavior, and HUD/ESP telemetry for the rogue spec.

## Design

- `main.lua` is the composition root: it wires menus, shared managers, caches, and update callbacks.
- `menu.lua` defines all user-facing toggles and thresholds, grouped into rotation, defensive, targeting, racial, OOC, and ESP sections.
- `spells.lua` centralizes all spell/racial/item rank tables and debuff identifiers used by the spec.
- Shared decision helpers are split into focused managers (`rotation_context`, `combat_context`, `resource_gate`, `poison_manager`, `smart_cast_manager`, `reactive_runtime`, etc.) to keep `main.lua` thin.
- Performance-sensitive paths use local aliases (`_core_time`, `_get_local_player`, `_get_spell_cd`) and cached context objects instead of rebuilding tables each frame.

## Flow

1. `main.lua` loads `menu`, spell tables, utility helpers, and the various managers.
2. `esp_renderer` is initialized and its `on_cast` hook is wrapped to feed `cooldown_tracker`.
3. The render/update callback pulls the local player, then calls `visual_update_snapshot()` to refresh ESP, DPS telemetry, TTD, and reactive state.
4. Rotation execution uses `rotation_context.get()` plus `combat_context` to derive current resources, combo points, buffs/debuffs, and target state.
5. Managers then decide action priority: poison upkeep, builder/finisher selection (`Mutilate`, `Envenom`, `Rupture`, `Eviscerate`), interrupts, defensives (`Evasion`, `Vanish`, `Sprint`, `Blind`), and OOC automation.
6. Out-of-combat helpers (`ooc_manager`, `vendor_automation`, `mount_manager`, `consumables_manager`, `leveling_manager`) run when combat conditions are false.

## Integration

- Depends on Sylvanas core APIs (`core.menu`, object manager, spell book, combat/update callbacks, input helpers).
- Reuses shared modules from `common/utility/*` and `common/modules/*`, especially `spell_helper`, `spell_queue`, `buff_manager`, and control-panel/keybind helpers.
- Integrates with shared platform modules in this folder: `combat_context`, `rotation_context`, `reactive_runtime`, `set_bonus`, `racial_manager`, `defensive_manager`, `interrupt_manager`, `threat_manager`, `ttd_tracker`, `dps_meter`, `cooldown_tracker`, `visual_state`, and `esp_renderer`.
- `spells.lua` supplies every rank table and aura ID consumed by managers and menu logic, while `utils.lua` exposes cached spell resolution, aura lookups, throttling, target selection, and mode detection.
- `EAXRogueAssassination.toc` loads only `header.lua`, `utils.lua`, `spells.lua`, `menu.lua`, and `main.lua`; the rest are required transitively from `main.lua`.
