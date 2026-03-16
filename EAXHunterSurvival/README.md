# EAX Hunter Survival

Survival Hunter assistant for Project Sylvanas + TBC Classic.

## Focus
- **Traps** (Explosive, Freezing, Snake, Wyvern) on a configurable interval.
- **Wyvern Sting** to lock down primary targets.
- **Expose Weakness** for raid or dungeon priority debuff uptime.

## Modes
- Auto mode keeps Solo/Dungeon/Raid thresholds automatically tuned by party size detection.
- Manual Solo/Dungeon/Raid modes lock that assumption when you want strict behavior.

## Configuration
- Use the menu to enable traps, switch the default trap, and tune the interval between casts.
- Toggle Wyvern Sting and Expose Weakness to keep them on cooldown.

## Usage
1. Drop `EAXHunterSurvival` into the Sylvanas `scripts/` folder.
2. Reload the runtime or restart WoW.
3. Enable the addon and choose your preferred trap and mode.
4. Let the rotation try traps when the timer expires and keep debuffs refreshed.

## Notes
- Trap logic uses a timed gate to avoid overlapping drops; actual placement depends on the runtime's handling of area spells.
- Wyvern Sting and Expose Weakness only cast when the target lacks the debuff and the ability is ready.
