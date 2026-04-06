# EAX Hunter Beast Mastery

Minimal Beast Mastery Hunter script for Project Sylvanas + TBC Classic.

## Focus
- **Pet-assisted DPS** with Kill Command once the pet is engaged on target.
- **Steady Shot weaving** keeps focus topped off between priority casts.
- **Pet awareness** helps keep Mend Pet available when the pet actually needs healing.
- **Travel aspects** can auto-swap to Cheetah, or Pack in group travel if enabled.
- **Emergency Deterrence** is available as a low-HP safety button.
- **Optional focus utility** includes Scare Beast and Flare.
- **Pet autocast sync** can keep Growl disabled in group content.

## Modes
- Auto mode detects party size and switches between Solo, Dungeon, and Raid behavior.
- Solo/Dungeon/Raid modes force the rotation to specific target assumptions when you prefer manual control.

## Configuration
- Toggle the addon via the menu or the configured keybind.
- Enable/disable Kill Command and Steady Shot individually.
- Adjust the pet-heal threshold to control when Mend Pet becomes eligible.

## Usage
1. Open the Hunter BM menu and enable the rotation.
2. Leave the mode on Auto unless you want to force Solo / Dungeon / Raid behavior.
3. Let the profile handle Kill Command, pet recovery, aspects, and the TBC BM shot lane.

## Notes
- Actual spell casting is driven by the Sylvanas runtime; this plugin handles ability priorities and logging only.
- Pet heal hints use the pet's health threshold; tune it to your preference.
- Out-of-combat food/drink sustain is handled by the shared OOC system.
- Anti-stealth Flare is best-effort and prediction-based, not perfect hidden-unit detection.
