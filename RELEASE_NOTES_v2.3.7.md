## EAX Rotations v2.3.7 — Healer Dispel Spam Fix

### Bug Fixes

- **Discipline Priest**: DispelMagic now has a 3-second throttle. No more spamming dispel when debuff detection returns stale data.
- **Shaman Restoration**: CurePoison, CureDisease, PoisonCleansingTotem, and DiseaseCleansingTotem now have 3-second throttles each.
- **Druid Restoration**: RemoveCurse and AbolishPoison now have 3-second throttles.
- **Paladin Holy**: PurifySelf and CleanseParty now have 3-second throttles.

### What Was Wrong

Only Holy Priest had dispel throttling (since v2.3.2). The other 3 healers would attempt to dispel/cleanse every single frame when the debuff API reported a debuff that had already been removed or was a false positive. This caused:
- Rapid-fire casts that did nothing
- Mana waste
- Log spam
- Potential GCD lockouts

### What to Expect

- **All healers**: Dispels now fire once every 3 seconds maximum when a valid debuff is detected.
- **No more spam**: Your console won't flood with DispelMagic/CureDisease/Cleanse messages.
- **Mana efficiency**: Throttled dispels waste less mana on edge cases.

---
*Verified: 219 rotation tests + 13 leveling tests pass. All spell IDs verified against WoW 2.5.5.68101 client DBC.*
