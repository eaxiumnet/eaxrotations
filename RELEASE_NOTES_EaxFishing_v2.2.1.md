EaxFishing v2.2.1 Release Notes
Released: July 4, 2026

NEW FEATURES

Stealth Mode
EaxFishing now detects when other players are nearby and automatically slows down. Cast rhythm becomes more relaxed, breaks get longer, and pool navigation pauses while someone is watching. This makes the addon look far less robotic when other people are around.

To enable it, check "Slow Down When Players Near" in the Stealth section of the menu. You can adjust the detection range with the "Stealth Range" slider (default is 30 yards). If you also run Ultra-Safe Mode, the slowdown is even more pronounced.

Rare Catch Alert
When you hook something valuable, EaxFishing now plays a sound and flashes a large colored message on your screen so you notice it immediately without staring at the loot window.

The alert triggers on:
- Blue (rare) quality items, such as Mr. Pinchy
- Green (uncommon) items worth 1 gold or more, such as Stonescale Eel
- Any item with a vendor value of 3 gold or higher

Toggle it with "Rare Catch Alert" in the Alerts section of the menu.

BUG FIXES

Fixed fishing not auto-casting for some players
The addon was referencing a non-existent spell ID that does not exist in the live game client. All fishing skill ranks are now verified against the actual WoW 2.5.5 client database, so auto-cast works correctly regardless of whether you are Apprentice, Journeyman, Expert, Artisan, or Master.

Fixed Flesh Eating Worm lure not being recognized
The Flesh Eating Worm is now correctly detected as a valid lure and will be applied automatically when "Auto-Apply Lure" is enabled.

Fixed duplicate fish entry
Removed a duplicate entry for Zangarian Sporefish in the internal loot database.

IMPROVEMENTS

- Loot window processing is faster.
- Unused code has been removed, making the addon lighter.
- All your existing settings are preserved. No reconfiguration is needed after updating.

INSTALLATION

1. Download EaxFishing_v2.2.1.zip
2. Extract the EaxFishing_v2.2.1 folder into your scripts/ directory
3. Restart Sylvanas. The addon loads automatically.
