# EAXPriestShadow/

## Responsibility

Shadow Priest combat automation for TBC Sylvanas. Maintains core self-buffs, applies/refreshes DoTs using hostile debuff timing, executes `Mind Blast` / `Mind Flay` filler, and handles defensive, mana, and out-of-combat utility behaviors.

## Design

- Spec-local addon tree with `main.lua` as the hot-path loop and `utils.lua` as the shared helper layer.
- TBC-only spell table in `spells.lua`; runtime resolves ranks through cached spell lookup.
- `main.lua` is organized as small action helpers (`try_*`) for buffs, DoTs, execute, defensive, and mana actions.
- Performance-sensitive work is cached: local core aliases, cached combat context, throttled set-bonus checks, and reusable visual state.
- Uses shared managers for target selection, interrupts, defensives, threat, consumables, mounts, OOC actions, and rendering.

## Flow

1. `menu.lua` / `header.lua` establish configuration and plugin state.
2. `main.lua` initializes shared managers, caches spell IDs, and wires render/update callbacks.
3. On each update tick, it validates player state, runs OOC helpers, updates set bonus and mode state, enforces `Shadowform` / `Inner Fire` / `Vampiric Embrace`, selects a target, and runs the DoT/filler priority.
4. The rotation refreshes `Vampiric Touch`, `Shadow Word: Pain`, and `Devouring Plague`, then casts `Mind Blast`, `Shadow Word: Death`, `Mind Flay`, and `Shadowfiend` as appropriate.
5. Render callbacks update ESP / telemetry snapshots and menu UI.

## Integration

- Depends on shared runtime modules such as `interrupt_manager`, `defensive_manager`, `racial_manager`, `mana_manager`, `mana_conservator`, `threat_manager`, `resource_gate`, `rotation_context`, `reactive_runtime`, `visual_state`, `dps_runtime`, and `dps_risk`.
- Uses `common/modules/spell_queue`, `common/modules/buff_manager`, `esp_renderer`, `dps_meter`, `cooldown_tracker`, and `ttd_tracker`.
- Hooks Sylvanas APIs for update/render callbacks, spell cooldowns, object scanning, time, and menu windows.
