# EAX Priest Shadow — TBC rewrite

Shadow Priest DPS automation for Project Sylvanas with a TBC-only spell list and single-target priority.

## Rotation
- Maintain `Shadowform`, `Vampiric Embrace`, and `Inner Fire`.
- Refresh `Vampiric Touch` with hostile debuff timing when it is missing or near expiry.
- Refresh `Shadow Word: Pain` and `Devouring Plague` with hostile debuff timing instead of friendly buff APIs.
- Cast `Mind Blast` on cooldown once the three core DoTs are active.
- Cast `Shadow Word: Death` in execute at `<= 25%` target HP, with a small finishing fallback when the target is about to die.
- Use `Mind Flay` as filler and `Shadowfiend` on cooldown for mana return.

## TBC cleanup
- Removed WotLK-only spell table entries such as `MIND_SEAR`, `PRAYER_OF_MENDING`, `DIVINE_AEGIS`, `DEBUFF_WEAKENED_SOUL`, and `STARSHARDS`.
- Removed Shadow Orb tracking from the rotation runtime.
- Switched DoT upkeep to `get_debuff_remaining_ms` for hostile targets.

## Install
1. Extract `EAXPriestShadow` into your Sylvanas `scripts` folder.
2. Reload the runtime or restart WoW.
3. Enable `EAX Priest Shadow` in the menu.
