# EAXHunterBeastMastery/

## Responsibility

Beast Mastery Hunter addon for TBC Classic on Sylvanas. Handles combat rotation, pet control, kiting/utility, travel aspects, OOC automation, and on-screen telemetry.

## Design

- **Spec-local addon** with its own `main.lua`, `menu.lua`, `utils.lua`, and spell table.
- **Priority-driven rotation** centered on BM burst/CDs and ranged weave: `Bestial Wrath > Rapid Fire > Kill Command > Arcane Shot > Serpent Sting > Aimed Shot > Multi-Shot > Steady Shot`.
- **Hot-path caching**: `resolve()` throttles spell lookup/talent refresh; local aliases cache core API calls.
- **Separated managers** for pet AI, stealth/flare handling, OOC/vendor/mount/consumables, defensive/racial logic, threat, kiting, and visual state.
- **Shared runtime reuse** through `rotation_context`, `combat_context`, `smart_cast_manager`, `reactive_runtime`, and shared `common/*` modules.

## Flow

1. `toc` loads `header.lua`, `utils.lua`, `spells.lua`, `menu.lua`, then `main.lua`.
2. `menu.lua` defines user toggles for shots, pet behavior, aspects, traps, kiting, OOC automation, and ESP.
3. `main.lua` initializes managers, resolves spell IDs, and builds cached runtime state.
4. Each update tick reads local player/target, refreshes visual snapshot and reactive state, updates pet/threat/defensive/OOC systems, chooses mode, and runs the shot/cooldown priority.
5. `pet_manager.lua` maintains pet state, attack, focus usage, mend/revive logic, and autocast sync.

## Integration

- Uses `core.*` Sylvanas object, spellbook, input, menu, graphics, and callback APIs.
- Reuses shared modules such as `common/modules/spell_queue`, `buff_manager`, `common/utility/*`, and `common/color`.
- Integrates with `utils.lua`, `spells.lua`, `rotation_context.lua`, `pet_manager.lua`, `esp_renderer`, `visual_state`, `dps_meter`, `cooldown_tracker`, `ttd_tracker`, `ooc_manager`, `vendor_automation`, `consumables_manager`, `mount_manager`, `leveling_manager`, `racial_manager`, `defensive_manager`, `threat_manager`, `interrupt_manager`, and `kiting_manager`.
