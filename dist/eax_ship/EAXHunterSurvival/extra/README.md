# EAX Hunter Survival

Survival Hunter assistant for Project Sylvanas + TBC Classic.

## Focus
- **Hunter's Mark** and **Serpent Sting** upkeep.
- **Aimed Shot**, **Arcane Shot**, **Multi-Shot**, and **Steady Shot** as the core ranged kit.
- **Traps** for utility, control, and pull management.
- **Kill Command**, melee fallback, kiting, and pet tools for survival play.
- **Travel aspects** default to Cheetah, with Pack optional for dungeon/raid travel.
- **Emergency Deterrence** is available as a low-HP safety button.
- **Optional focus utility** includes Scare Beast, Flare, and Wyvern Sting.
- **Pet autocast sync** can keep Growl disabled in group content.

## Modes
- Auto mode keeps Solo/Dungeon/Raid thresholds automatically tuned by party size detection.
- Manual Solo/Dungeon/Raid modes lock that assumption when you want strict behavior.

## Configuration
- Use the menu to enable traps, choose the default trap, and tune trap timing.
- Configure ranged priority, Kill Command, melee fallback, kiting, and pet support tools.

## Usage
1. Open the Hunter Survival menu and enable the rotation.
2. Choose your preferred trap setup and leave the mode on Auto unless you want to force Solo / Dungeon / Raid behavior.
3. Let the profile maintain mark/sting, ranged shots, traps, pet recovery, and utility tools.

## Notes
- Trap logic uses a timed gate to avoid overlapping drops; actual placement depends on the runtime's handling of area spells.
- Kill Command, melee fallback, kiting, and pet tools are used when ranged options are unavailable or unsafe.
- Out-of-combat food/drink sustain is handled by the shared OOC system.
- Anti-stealth Flare is best-effort and prediction-based, not perfect hidden-unit detection.
