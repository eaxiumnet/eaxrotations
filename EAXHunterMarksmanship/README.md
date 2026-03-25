# EAX Hunter Marksmanship

Lightweight Marksmanship set-up for Sylvanas + TBC Classic.

## Focus
- **Aimed Shot burst** when targets are healthy enough for the damage spike.
- **Multi-Shot weaving** whenever multiple enemies are present (Auto/Dungeon/Raid modes).
- **Steady Shot options** keep focus ticking between heavier casts.
- **Travel aspects** default to Cheetah, with Pack optional for dungeon/raid travel.
- **Emergency Deterrence** is available as a low-HP safety button.
- **Optional focus utility** includes Scare Beast and Flare.
- **Pet autocast sync** can keep Growl disabled in group content.

## Modes
- Auto mode senses party size and switches between Solo, Dungeon, or Raid assumptions.
- Solo/Dungeon/Raid options force that specific mode if you want to lock in the behavior.

## Configuration
- Use the menu or keybind to toggle the addon.
- Enable/disable each ability and tune the Multi-Shot target cap to avoid wasted aoe when few enemies remain.

## Usage
1. Copy `EAXHunterMarksmanship` into the Sylvanas `scripts/` folder.
2. Reload Sylvanas or restart the client.
3. Toggle the addon on in the menu and adjust Multi-Shot limits.
4. Let Kill Command (for pet) run automatically while we weave Steady Shot and Aimed Shot.

## Notes
- The script assumes the Sylvanas runtime handles casts; this module only organizes priorities and logs.
- Multi-Shot is skipped in Solo mode to avoid eating focus when only one enemy is present.
- Out-of-combat food/drink sustain is handled by the shared OOC system.
