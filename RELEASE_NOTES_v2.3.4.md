## EAX Rotations v2.3.4 — Hotfix Release

### Bug Fixes

- **Warrior — All TBC Specs**: Added missing **Pummel** interrupt. Now automatically interrupts enemy casts when in Berserker Stance. Affects Arms, Fury, Protection, and Kebab.
- **Priest — Holy**: Fixed crash that could freeze the rotation with repeated errors:
  - `attempt to call upvalue 'player_control_locked' (a nil value)`
  - `attempt to compare number with nil` (line 414)
- **Priest — Holy**: Fixed Dispel Magic / Cure Disease spam loop that would cast repeatedly even when no debuff was present. Now properly throttled (3s) and only fires when an actual harmful effect is detected.
- **Priest — Holy**: Abolish Disease no longer wastes mana as a "preventive" cast. It now only fires when the tank has an actual disease.
- **Druid — Caster (TBC + Classic)**: Fixed rare crash when checking Faerie Fire or Moonfire debuff timers.
- **Druid — Bear (Classic)**: Fixed rare crash when checking Faerie Fire or Demoralizing Roar debuff timers.

### What to Expect

- Warriors: smoother interrupt handling in PvE and PvP. No more missed casts from enemy healers.
- Holy Priests: rotation stays responsive. Dispel and disease removal only happen when needed, saving mana and GCDs.
- Druids: no more rare startup crashes on state initialization.
- All 29 specs remain stable.

---
*Verified: 219 rotation tests + 13 leveling tests pass. All spell IDs verified against WoW 2.5.5.68101 client DBC.*
