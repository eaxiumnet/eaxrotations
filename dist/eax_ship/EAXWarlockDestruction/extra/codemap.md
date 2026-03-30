# EAXWarlockDestruction/

## Responsibility

TBC Destruction Warlock automation for Project Sylvanas. This folder handles combat rotation, out-of-combat utility, pet selection, shard/mana management, defensive/threat responses, and ESP/telemetry for the spec.

## Design

- **Entry-point driven**: `main.lua` owns the live update/render callbacks and orchestrates all subsystems.
- **Menu-gated rotation**: nearly every action is behind `menu` toggles and profile/mode selectors.
- **Cached hot-path state**: spell IDs, set bonuses, mode, encounter policy, and combat context are cached and invalidated on cast/tick events.
- **Subsystem split**: dedicated managers handle interrupts, defensives, threat fade, mana conservation, DoT refresh, pet summoning, leveling fallback, mount/vendor/OOC actions, and visuals.
- **Hybrid fire/shadow profile**: the rotation dynamically prefers Incinerate/Conflagrate or Shadow Bolt based on resolved spell availability and menu profile.

## Flow

1. `main.lua` loads menus, resolves spells, initializes ESP and smart-cast throttling.
2. On update, the addon refreshes mode/set bonus, handles toggle state, and exits early when disabled or dead.
3. Out of combat, it runs OOC services: threat init, mount, repair/sell, consumables, and pet correction.
4. In combat, it builds/reads rotation context, updates encounter policy and TTD, then checks interrupts, wanding, racials, defensives, and threat fade.
5. The priority lane then executes: pet summon check → Fel Armor → AoE tools (`Seed of Corruption`, `Shadowfury`) → curse upkeep → `Immolate` → execute tools (`Shadowburn`, `Drain Soul`, `Soul Fire`) → filler (`Incinerate`/`Shadow Bolt`) → shard farming / `Life Tap`.

## Integration

- Uses shared/common modules: `menu`, `utils`, `rotation_context`, `resource_gate`, `esp_renderer`, `visual_state`, `reactive_runtime`, `dps_risk`, `dps_runtime`, `set_bonus`, `ttd_tracker`.
- Hooks spec services: `interrupt_manager`, `defensive_manager`, `racial_manager`, `threat_manager`, `mana_conservator`, `dot_manager`, `ooc_manager`, `vendor_automation`, `consumables_manager`, `mount_manager`, `leveling_manager`, `creature_utils`.
- Connects to shared UI/helpers: `common/utility/key_helper`, `common/utility/control_panel_helper`, `common/geometry/vector_2`.
