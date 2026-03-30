# eax_shared/

## Responsibility
Provides the shared runtime layer for the live EAX rotations: combat context building, smart cast protection, threat and defensive management, role-aware gating, telemetry, and common utility services.

## Design
- **Manager-oriented architecture**: behavior is split into narrow modules such as `interrupt_manager.lua`, `defensive_manager.lua`, `threat_manager.lua`, and `mount_manager.lua`.
- **Cached hot-path context**: `combat_context.lua`, `rotation_context.lua`, and `reactive_runtime.lua` reduce repeated expensive API reads on update ticks.
- **Shared UI/telemetry layer**: `esp_renderer.lua`, `visual_state.lua`, `cooldown_tracker.lua`, and `dps_meter.lua` feed overlays and cast visibility.
- **Role/resource gating**: `resource_gate.lua`, `mana_manager.lua`, `healer_triage.lua`, and `tank_recovery.lua` encode cross-spec decision constraints.

## Flow
1. Spec `main.lua` files require shared modules from this directory.
2. On update, specs query cached context and role-aware managers here before deciding their next action.
3. Shared managers evaluate interrupts, defensives, consumables, threat, and visual state.
4. Specs execute the selected action and invalidate/update cached context as needed.

## Integration
- Consumed by: nearly all live `EAX*/` spec directories.
- Depends on: Sylvanas runtime APIs exposed through the bot environment.
- Key integration points: `smart_cast_manager.lua`, `combat_context.lua`, `rotation_context.lua`, `interrupt_manager.lua`, `encounter_manager.lua`, `reactive_runtime.lua`.
