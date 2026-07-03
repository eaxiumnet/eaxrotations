## EAX Rotations v2.3.5 — Missing Spells + Defensive Fixes

### New Features

- **Discipline Priest — Shadowfiend**: Now automatically summons Shadowfiend when mana drops below 35% in combat. Major mana recovery for long fights.
- **Holy Paladin — Divine Protection**: Now casts automatically as an emergency defensive when HP drops below 40% and Forbearance is not active. Saves your life when the tank loses aggro.

### Bug Fixes

- **Enhancement Shaman — Totem Twist**: Fixed rare nil-guard issue on totem timer comparison that could skip Windfury/Grace of Air recasts.
- **Holy Paladin — Triage Scoring**: Added nil-guard on group count check to prevent edge-case skip.

### What to Expect

- Discipline Priests: no more going OOM in long boss fights. Shadowfiend fires automatically at the right time.
- Holy Paladins: extra defensive layer. Divine Protection kicks in before you die.
- Enhancement Shamans: totem twisting stays reliable even during rapid state changes.

---
*Verified: 219 rotation tests + 13 leveling tests pass. All spell IDs verified against WoW 2.5.5.68101 client DBC.*
