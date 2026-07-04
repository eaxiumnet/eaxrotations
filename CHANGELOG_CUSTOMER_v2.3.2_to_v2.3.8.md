# EAX Rotations — Customer Changelog
## Versions 2.3.2 through 2.3.9

---

## v2.3.9 — Shadow Priest Mind Flay Opener Fix (Latest)

### Bug Fixes
- **Shadow Priest**: Fixed Mind Flay opening on fresh targets. Every other damage spell checks whether the mob has actually targeted you before casting. Mind Flay was missing this check, so it fired immediately while Shadow Word: Pain and Mind Blast correctly waited. The result was a "Mind Flay opener" that felt wrong and wasted the first GCD of a pull.
  - Now Mind Flay waits for engagement just like every other spell.
  - Fresh pulls will correctly open with Shadow Word: Pain → Mind Blast → Mind Flay, or auto-attack first if needed.

### What to Expect
- Shadow Priests: Your opener is now consistent. No more Mind Flay firing before DoTs are applied.
- All other specs: No changes.

---

## v2.3.8 — Boss Detection Accuracy + Dead State Field Fixes

### Bug Fixes
- **Mage — Fire**: Clearcasting proc (Arcane Concentration) is now consumed by Fireball. Previously `build_state` never tracked the proc, so it sat unused.
- **Warrior — Arms**: Death Wish now auto-fires on boss targets above 20% HP. The boss-burst gate was dead code because `state.is_boss` was never populated.
- **Druid — Bear**: Nature's Grasp now auto-casts in PvP when you're rooted or snared. The PvP peel matcher was silently skipped because `state.is_rooted` / `state.is_snared` were never set.
- **Warlock — Demonology**: Pet Defensive/Passive/Aggressive state matchers now read a properly populated `state.in_combat`. Previously the field was a stale dead reference.

### API Compliance
- **Boss detection (all specs)**: Rewired to use the accurate `unit_helper:is_boss()` instead of the raw `target:is_boss()` which the Sylvanas docs explicitly warn is inaccurate ("only certain bosses like world bosses have this flag enabled"). Affects Arms Death Wish, Fire Combustion, Destruction Demonic Sacrifice, Bear Maul boss-bypass, and the shared combat-forecast gate.
- **Tank detection (all healers)**: Now prefers the accurate `unit_helper:is_tank()` before falling back to raw heuristics. This improves Rejuvenation tank-priority and triage scoring across all 5 healer specs.

### What to Expect
- Fire mages: Clearcasting procs are consumed on Fireball for higher burst.
- Arms warriors: Death Wish fires as a burst opener on dungeon/raid bosses above 20% HP.
- Bear druids: Nature's Grasp peels melee/root in PvP when you're CC'd.
- All healers: Tank detection is more accurate — Rejuvenation and triage correctly prioritize the tank.
- All specs: Boss detection is now accurate — no more missed burst CDs on bosses the raw flag didn't catch.

---

## v2.3.7 — Healer Dispel Spam Fix

### Bug Fixes
- **All healer specs** — Fixed a bug where dispels and cleanses would sometimes fire repeatedly in rapid succession, wasting mana and filling your combat log with spam.
  - Affected specs: Discipline Priest, Restoration Shaman, Restoration Druid, Holy Paladin
  - Now all dispel/cleanse spells are properly throttled to fire once every 3 seconds when needed.

### What to Expect
- Healers: No more rapid-fire dispel spam. Mana is preserved. Combat log stays clean.
- This was the last healer spec missing the dispel throttle — all four are now consistent.

---

## v2.3.6 — Stash Recovery Features

### New Features
- **Warlock Affliction — Imp Detection**: The rotation now tracks when your Imp is actively casting Firebolt. This gives you better pet awareness in combat.
- **Druid Feral Cat — BiteTrick**: A new strategy that optimizes Ferocious Bite timing. When you have 5 combo points and low energy, it bites at exactly the right moment to avoid wasting energy before your next tick.
- **Druid Feral Cat — Form Diagnostics**: When debug mode is enabled, the rotation logs which form-detection APIs are available. Useful if you ever feel like cat form isn't being detected properly.

### What to Expect
- Warlocks: Better pet tracking.
- Feral Druids: Slightly more efficient Ferocious Bite usage at 5 combo points.
- These were features recovered from an earlier development branch and cleanly added to the stable release.

---

## v2.3.5 — Missing Spells & Defensive Fix

### New Features
- **Discipline Priest — Shadowfiend**: Now automatically summons your Shadowfiend when your mana drops below 35% in combat. This is a major mana recovery tool for long boss fights.
- **Holy Paladin — Divine Protection**: Now casts automatically as an emergency defensive when your health drops below 40% and Forbearance is not active. This can save your life when the tank loses aggro.

### Bug Fixes
- **Enhancement Shaman**: Fixed a rare issue where totem twisting could skip Windfury or Grace of Air recasts during rapid state changes.
- **Holy Paladin**: Fixed a rare edge case where group healing could skip targets.

### What to Expect
- Discipline Priests: No more going out of mana in long fights. Shadowfiend fires automatically at the right time.
- Holy Paladins: An extra defensive layer kicks in before you die.
- Enhancement Shamans: Totem twisting stays reliable even during fast-paced combat.

---

## v2.3.4 — Warrior Pummel & Priest/Druid Crash Fixes

### Bug Fixes
- **Warrior (all specs) — Pummel Added**: All four Warrior specs (Arms, Fury, Protection, Kebab) now have Pummel in their rotation. This was missing and is a critical interrupt for PvP and PvE.
- **Holy Priest — Crash Fix**: Fixed a crash that could occur when the rotation checked player control status.
- **Holy Priest — Settings Crash**: Fixed a crash on line 414 that happened when settings weren't fully loaded.
- **Druid (Caster form, TBC & Classic)**: Fixed a crash related to Faerie Fire and Moonfire tracking.
- **Druid (Bear form, Classic)**: Fixed a crash related to Faerie Fire and Demoralizing Roar tracking.

### What to Expect
- Warriors: You can now interrupt enemy casts reliably in all specs.
- Holy Priests: Rotation no longer crashes on startup or during combat.
- Druids: No more rare crashes when casting certain spells.

---

## v2.3.3 — Settings Nil-Guard Sweep

### Bug Fixes
- Fixed multiple spots across the codebase where missing or unloaded settings could cause the rotation to behave unexpectedly or skip actions.
- This was a preventative maintenance pass to make the rotation more robust when settings panels haven't fully initialized yet.

### What to Expect
- More consistent behavior when logging in or reloading UI.
- No more "settings not found" edge cases.

---

## v2.3.2 — Holy Priest Overhaul

### Bug Fixes
- **Dispel Spam**: Added a 3-second throttle to Dispel Magic and Cure Disease so they don't fire repeatedly when debuff detection returns stale data.
- **Abolish Disease Waste**: The rotation now only casts Abolish Disease when a disease is actually detected, instead of casting it blindly.
- **Settings Guards**: Added safety checks around all Holy Priest settings references to prevent crashes.

### What to Expect
- Holy Priests: Dispel and Cure Disease no longer spam your combat log.
- Abolish Disease is only cast when actually needed.
- The rotation is much more stable overall.

---

## Summary: What Changed Across All Versions

| What | v2.3.2 | v2.3.3 | v2.3.4 | v2.3.5 | v2.3.6 | v2.3.7 | v2.3.8 | v2.3.9 |
|------|--------|--------|--------|--------|--------|--------|--------|--------|
| Holy Priest stability | Fixed | — | Fixed | — | — | — | — | — |
| Warrior interrupts | — | — | Added | — | — | — | — | — |
| Druid crashes | — | — | Fixed | — | — | — | — | — |
| Shadowfiend | — | — | — | Added | — | — | — | — |
| Divine Protection | — | — | — | Added | — | — | — | — |
| Imp detection | — | — | — | — | Added | — | — | — |
| Cat BiteTrick | — | — | — | — | Added | — | — | — |
| All healer dispel throttle | Partial | — | — | — | — | Complete | — | — |
| Fire Clearcasting fix | — | — | — | — | — | — | Fixed | — |
| Arms Death Wish boss burst | — | — | — | — | — | — | Fixed | — |
| Bear PvP peel | — | — | — | — | — | — | Fixed | — |
| Boss detection accuracy | — | — | — | — | — | — | Improved | — |
| Tank detection accuracy | — | — | — | — | — | — | Improved | — |
| Shadow Priest MF opener | — | — | — | — | — | — | — | Fixed |

---

*All changes verified against the WoW TBC Classic 2.5.5.68101 client database.*
*219 rotation tests and 13 leveling tests pass on every release.*
