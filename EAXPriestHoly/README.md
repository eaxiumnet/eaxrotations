# EAX Priest Holy

Healing-focused automation that keeps Renew ticking, drops Greater Heals on emergencies, and fires Prayer of Healing when there are several injured allies.

## Highlights

- **Renew uptime:** `Renew Threshold` + `Renew Refresh Window` keep the HoT on tank and raid leads.
- **Greater Heal gating:** Use `Greater Heal Threshold` to trigger big heals when health is critically low.
- **Prayer of Healing:** Checks for wounded allies crossing `PoH Threshold` and uses the spell when `PoH Count` is met.
- **Prayer of Mending:** Automatically refreshes PoM when allies fall below the configured threshold without clipping Renew.
- **Mode support:** Choose `Auto`, `Solo`, `Dungeon`, or `Raid` mode to reflect your current group size.

## Menu Reference

- `Enabled` / `Debug Logging`
- `Mode` (Auto, Solo, Dungeon, Raid)
- `Renew Threshold`, `Renew Refresh Window`
- `Greater Heal Threshold`
- `Prayer of Healing` toggle, `PoH Threshold`, `PoH Count`
- `Auto Prayer of Mending`, `PoM Threshold`

## Usage

1. Use the Sylvannas control panel to adjust your healing thresholds.
2. Let the addon detect the mode, or force Solo/Dungeon/Raid behavior when you need precise control.
3. The rotation first refreshes Renew, then checks for Prayer of Healing opportunities before casting Greater Heal on emergencies.
