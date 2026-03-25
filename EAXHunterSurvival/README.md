# EAX Hunter Survival

Survival Hunter assistant for Project Sylvanas + TBC Classic.

## Focus
- **Hunter's Mark** and **Serpent Sting** upkeep.
- **Aimed Shot**, **Arcane Shot**, **Multi-Shot**, and **Steady Shot** as the core ranged kit.
- **Traps** for utility, control, and pull management.
- **Kill Command**, melee fallback, kiting, and pet tools for survival play.
- **Travel aspects** default to Cheetah, with Pack optional for dungeon/raid travel.

## Modes
- Auto mode keeps Solo/Dungeon/Raid thresholds automatically tuned by party size detection.
- Manual Solo/Dungeon/Raid modes lock that assumption when you want strict behavior.

## Configuration
- Use the menu to enable traps, choose the default trap, and tune trap timing.
- Configure ranged priority, Kill Command, melee fallback, kiting, and pet support tools.

## Usage
1. Drop `EAXHunterSurvival` into the Sylvanas `scripts/` folder.
2. Reload the runtime or restart WoW.
3. Enable the addon and choose your preferred trap and mode.
4. Let the rotation maintain Hunter's Mark / Serpent Sting, then fall back through the ranged kit, traps, and survival tools.

## Notes
- Trap logic uses a timed gate to avoid overlapping drops; actual placement depends on the runtime's handling of area spells.
- Kill Command, melee fallback, kiting, and pet tools are used when ranged options are unavailable or unsafe.
- Out-of-combat food/drink sustain is handled by the shared OOC system.
