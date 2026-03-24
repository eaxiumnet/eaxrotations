# EAX Warrior Arms

Lightweight Arms Warrior rotation helper built for the Sylvannas runtime.

## Core design

- **Auto/Solo/Dungeon/Raid modes** drive how aggressive the rotation is and how utilities behave.
- **Primary rotation:** Overpower when available, Mortal Strike on cooldown, Thunder Clap on single targets, Slam weaving between swings, Whirlwind stance dancing for AoE, and Execute below 20% health.
- **Utility support:** Battle/Commanding Shout, Demoralizing Shout, Sunder Armor stacks, and Hamstring (Solo mode).

## Installation

1. Drop the `EAXWarriorArms` folder into your Sylvannas `scripts/` directory.
2. Reload Sylvannas or restart the client.
3. Open the control menu, enable `EAX Warrior Arms`, pick a mode, and adjust utilities.

## Notes

- Only loads for Warriors in the Arms specialization (spec ID 1).
- Slam weaves honor the configured safety buffer to avoid cutting auto swings.
- Thunder Clap is wired into the single-target lane instead of being treated as AoE-only.
- The `Auto` mode detects party size to decide between Solo/Dungeon/Raid behaviors.
