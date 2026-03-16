# EAX Shaman Elemental

Elemental Shaman DPS tuned for the lightning-heavy window. It keeps Lightning Bolt in a narrow range band, weaves Chain Lightning during cleave, and uses Flame Shock + totem twists to sustain burst phases.

## Rotation

- **Primary Builder** – Lightning Bolt is the filler as long as targets stay within the `range_min` / `range_max` window and mana stays above the configured mana floor.
- **AoE** – Chain Lightning engages once the `aoe_threshold` is met or mana spikes past the AoE slider, then the rotation falls back to Lightning Bolt when the pack thins.
- **Dot Management** – Flame Shock is dropped on stationary targets as long as the execute slider allows it; the burst loop already respects the same `execute_hp` cutoff.
- **Cooldowns** – Elemental Mastery and Nature's Swiftness fire during boss windows when `Use Burst Cooldowns` is enabled, extending Lightning Bolt throughput.
- **Totem Twisting** – Auto Totems keeps Totem of Wrath and Mana Spring active with configurable refresh intervals.

## Modes

- **Auto** – Detects party composition and switches between the profiles below.
- **Solo** – Low AoE threshold, aggressive Lightning Bolt range, keeps Mana Spring on to sustain solo pulls.
- **Dungeon** – Higher AoE threshold with more Chain Lightning weaving and a `execute_hp` gate at ~40%.
- **Raid** – Tightest AoE gate, highest mana floor, and extra execute protection that favors single-target Lightning Bolt.

## Install

1. Drop the `EAXShamanElemental` folder into your `scripts` directory.
2. Reload Sylvanas or restart the client.
3. Open the menu, enable the plugin, and pick a Mode (Auto/Solo/Dungeon/Raid).

## Use

- Modes keep the built-in thresholds tuned for the selected content; Auto will swap as party size changes.
- Totem Twist keeps Wrath + Mana Spring up without extra clicks; disable or slow it down if you prefer manual control.
- Burst toggles gate Elemental Mastery / Nature's Swiftness so the plugin only spikes during boss windows.
- Flame Shock and execute sliders give you precise control over when dots or Lightning Bolts are held back for the final phase.

## Notes

- The plugin resolves Lightning Bolt, Chain Lightning, Flame Shock, Elemental Mastery, and Nature's Swiftness at load and logs their IDs when debug mode is on.
- Totem helpers respect the `Totem Refresh (sec)` slider so you can match pull start macros or raid pacing.
- Menu sliders feed both the rotation and the mode defaults, ensuring Solo/Dungeon/Raid profiles stay consistent with the original OpenShaman2 tuning.
