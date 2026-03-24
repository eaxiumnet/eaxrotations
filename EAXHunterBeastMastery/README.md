# EAX Hunter Beast Mastery

Minimal Beast Mastery Hunter script for Project Sylvanas + TBC Classic.

## Focus
- **Pet-assisted DPS** with Kill Command once the pet is engaged on target.
- **Steady Shot weaving** keeps focus topped off between priority casts.
- **Pet awareness** toggles remind you when pet care (Mend Pet) might be needed.

## Modes
- Auto mode detects party size and switches between Solo, Dungeon, and Raid behavior.
- Solo/Dungeon/Raid modes force the rotation to specific target assumptions when you prefer manual control.

## Configuration
- Toggle the addon via the menu or the configured keybind.
- Enable/disable Kill Command and Steady Shot individually.
- Adjust the pet-care slider (purely conceptual) to remind you when health falls below the threshold.

## Usage
1. Drop the `EAXHunterBeastMastery` folder into Sylvanas' `scripts/` directory.
2. Reload Sylvanas or restart WoW Classic.
3. Open the menu (default key 6) and enable the addon.
4. Set the mode to Auto or the content-specific preset.
5. Let the rotation trigger Kill Command once the pet is on target and use Steady Shot as filler.

## Notes
- Actual spell casting is driven by the Sylvanas runtime; this plugin handles ability priorities and logging only.
- Pet care hints rely on player health as a proxy; adjust the slider to match your comfort level.
