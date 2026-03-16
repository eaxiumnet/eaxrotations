# EAX Paladin Retribution

Minimal Retribution Paladin helper tuned for TBC Classic's seal-twisting gameplay. This plugin maintains Command → Blood → Righteousness seal cycles, keeps Crusader Strike rolling, and refreshes Judgement so the debuff never drops. Works as a Sylvannas combat helper and mirrors the design laid out in `docs/superpowers/specs/2026-03-13-eax-paladin-retribution-design.md`.

## Features

- **Seal Twisting** – automatically drops from Seal of Command into Seal of Blood and Righteousness, then re-applies Command once the window closes.
- **Crusader Strike** – queues the melee strike whenever the GCD is ready and the target is in melee range.
- **Judgement Maintenance** – keeps either Judgement of Wisdom or Judgement of the Crusader active on the current target.
- **Mode awareness** – Auto detection plus explicit Solo, Dungeon, and Raid modes; seal twisting can be restricted per mode.

## Menu Options

- **Enabled / Toggle Key** – master toggle and quick keybinding for the rotation.
- **Mode** – Auto uses group detection, Solo/Dungeon/Raid override it explicitly.
- **Judgement Mode** – choose between Wisdom or Crusader and whether to keep that debuff active.
- **Crusader Strike** – toggle the melee strike.
- **Seal Twisting** – enable the twist sequence, adjust the time until the next swing and the cooldown between twists, and opt-in/out of dungeon/raid twists.

## Seal Twisting Cycle

1. Ensure Seal of Command is always the baseline when idle.
2. When there is enough time before the next melee swing, cast Seal of Blood to start the twist.
3. Immediately queue Seal of Righteousness and then reapply Seal of Command once the twist completes.

The twist cooldown prevents repeated swaps that would drop the DPS burst window.

## Modes

- **Auto** – detects how many party members are present and switches between solo/dungeon/raid.
- **Solo/Dungeon/Raid** – forces the rotation logic to one of those states; twisting can be gated separately via its own checkboxes.

## Getting Started

Put this folder under `scripts/EAXPaladinRetribution/` (already in place) and load it from Sylvannas. Adjust the menu to match your preferred Judgement, twist pace, and mode behavior. Logs can be enabled through the debug checkbox and appear in `core.log` prefixed with `[EAX Paladin Retribution]`.

## References

- Design doc: `docs/superpowers/specs/2026-03-13-eax-paladin-retribution-design.md`
