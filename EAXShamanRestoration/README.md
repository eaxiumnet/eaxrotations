# EAX Shaman Restoration

Restoration Shaman support rotation that keeps Chain Heal windows sharp, Riptide/Earth Shield maintained, and Healing Wave as the execute hump.

## Rotation

- **Chain Heal** – Runs whenever multiple allies fall below the configured party HP slider and the `chain_heal_targets` threshold is met, honoring the `mana_floor` slider before committing.
- **Tank Support** – Earth Shield and Riptide refresh automatically to protect and stabilize the main tank; Healing Wave finishes the tank when the HP slider is hit.
- **Burst** – Nature's Swiftness is available for emergency saves (`NS Emergency HP`) when cooldowns are enabled, providing instant Chain Heals.
- **DPS Fillers** – Optional Chain Lightning / Lightning Bolt filler keeps DPS soft-capped when `Enable DPS Filler` is on and mana allows.
- **Totems** – Mana Tide Totem + Healing Stream rotating support keeps the raid topped off without manual totem twisting.

## Modes

- **Auto** – Detects content type to switch between the Solo / Dungeon / Raid defaults.
- **Solo** – Allows DPS filler and keeps lower healing thresholds so the player can self-sustain.
- **Dungeon** – Keeps a balanced heal / DPS mix while tightening the mana floor and raising party HP requirements.
- **Raid** – Disables DPS filler, raises healing thresholds, and focuses purely on the tank/party heal window.

## Install

1. Drop `EAXShamanRestoration` into your `scripts` directory.
2. Reload Sylvanas or restart.
3. Enable the plugin and choose the desired mode.

## Use

- Use the sliders to control Chain Heal burst size, tank/party HP cutoffs, and mana floor.
- Toggle auto Totems to keep Mana Tide and Healing Stream refreshed without micromanaging.
- Nature's Swiftness respects the emergency slider so it only fires when a raid member is critically injured.
- Turn on `Enable DPS Filler` + `Use DPS Filler` if you still want occasional Chain Lightning while healing.

## Notes

- Modes automatically drive the `chain_heal_targets`, `mana_floor`, and `heal_*` slider defaults to match the legacy profiles.
- The addon resolves essential healing spells at load and logs them when debug mode is enabled.
- Totem automation honors the `Pre-pull Totems` flag so you can prime totems before a boss or pull starts.
