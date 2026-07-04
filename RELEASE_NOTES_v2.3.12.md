# EaxRotations v2.3.12 — Release Notes

**Release Date:** 2026-07-04

---

## ? Feature: Healthstone Automation — All 29 Specs

**Every rotation now automatically uses a Healthstone when you drop below 28% HP in combat.**

Specs newly covered in this release:
- **Hunter:** Beast Mastery, Marksmanship, Survival
- **Shaman:** Elemental, Enhancement, Restoration
- **Warrior:** Arms (Kebab), Protection
- **Rogue:** Subtlety
- **Priest:** Smite

Already covered (prior releases):
- Druid: Balance, Bear, Cat, Restoration
- Mage: Arcane, Fire, Frost
- Paladin: Holy, Protection
- Priest: Holy, Discipline, Shadow
- Warrior: Arms, Fury
- Warlock: Affliction, Demonology, Destruction
- Rogue: Assassination, Combat

**How it works:** The rotation scans your bags for any Healthstone (Major, Greater, Lesser, Minor, or the base 5512). If you're in combat and drop below 28% HP, it uses the best one you have. No menu setting needed — it just works.

---

## ? Feature: Target-Switch State Hygiene

**Switching targets now correctly resets TTD (Time-To-Death) tracking.**

Previously, TTD data from your old target (debuff timers, DPS averages, swing remains) would leak onto your new target for the first few seconds. This caused wrong decisions — for example, refreshing a DoT early because the old target's TTD was short, or skipping an execute because the old target's HP was high.

Now, the moment you switch target (manually or automatically), the TTD tracker and EMA tracker are reset. Clean slate, correct decisions.

---

## ?? Bug Fix: Priest — Tab-Target Safety

**Shadow, Holy, and Discipline priests no longer accidentally pull unengaged mobs when tab-targeting.**

Spread-DoT and idle-damage strategies (Multi-Dot, Shadow Word: Pain spread, idle Smite/Holy Fire) now check that the target has actually engaged with you or your party before casting. Prevents dots from landing on patrols, wanderers, or neutral mobs you just happened to tab onto.

**Holy & Discipline bonus:** Party Fortitude now scans your group and casts Power Word: Fortitude on any party member missing the buff. No more manually buffing everyone after a rez.

---

## ?? Bug Fix: Rotation Toggle Survives Reload

**Turning the rotation OFF now stays OFF after a UI reload.**

Previously, if you disabled the rotation via the quick-toggle keybind and then reloaded your UI, the rotation would run for 1-2 ticks before the toggle state synced back to OFF. This caused accidental spell casts on reload. Fixed by reading the toggle state directly from the widget (which Sylvanas persists) instead of the ephemeral settings store.

---

## ? Quality & Reliability

- **219 rotation test suites** — all passing
- **13 leveling rotation suites** — all passing
- All changes are backward compatible. No settings reset required.

---

## ?? Installation

1. Download EaxRotations-v2.3.12.zip
2. Extract to your Project Sylvanas Scripts/ folder
3. Reload UI or restart the game

---

*Questions? Report issues at: https://github.com/eaxiumnet/eaxrotations/issues*
