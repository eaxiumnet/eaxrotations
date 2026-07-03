## EAX Rotations v1.0.7 — Hotfix Release

### Bug Fixes

- **Warrior — All Specs**: Added missing **Pummel** interrupt. Now interrupts enemy casts automatically when in Berserker Stance.
- **Priest — Holy**: Fixed crash that could spam "attempt to call upvalue 'player_control_locked' (a nil value)" and freeze the rotation.
- **Priest — Holy**: Fixed Dispel Magic / Cure Disease spam loop that would cast repeatedly even when no debuff was present. Now throttled and only fires when an actual harmful effect is detected.
- **Priest — Holy**: Abolish Disease no longer wastes mana as a "preventive" cast. It now only fires when the tank has an actual disease.

### What to Expect

- Warriors: smoother interrupt handling in PvE and PvP. No more missed casts from enemy healers.
- Holy Priests: rotation stays responsive. Dispel and disease removal only happen when needed, saving mana and GCDs.
- All 29 specs remain stable. No rotation changes for other classes.

---
*Verified: 219 rotation tests + 13 leveling tests pass.*
