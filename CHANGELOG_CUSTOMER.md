# EaxRotations Changelog

*Player-facing updates. No code, no filenames � just what changed and why it matters.*

---

## v2.3.12 � July 4, 2026

### ? Feature: Healthstone Automation � All 29 Specs

**Every rotation now automatically uses a Healthstone when you drop below 28% HP in combat.**

Before this release, only 19 of 29 specs had healthstone automation. Now it covers everyone: Hunter (all 3), Shaman (all 3), Warrior (Arms/Protection), Rogue (Subtlety), and Priest (Smite) join the existing coverage.

**How it works:** The rotation scans your bags for any Healthstone (Major 22105, Greater 22104, Lesser 22103, Minor 19013/19012/19011, or base 5512). When you are in combat and drop below 28% HP, it uses the best one you have. No menu setting needed � it just works.

---

### ? Feature: Affliction Warlock � Death Coil Survival

**Affliction Warlock now automatically uses Death Coil when you drop below 30% HP in combat.**

Death Coil is a powerful emergency button: it fears the target and heals you for the damage dealt. Destruction and Demonology Warlocks already had this, but Affliction was missing it. Now all three Warlock specs are covered.

---

### ? Feature: Target-Switch State Hygiene

**Switching targets now correctly resets TTD (Time-To-Death) tracking.**

Previously, TTD data from your old target (DPS averages, debuff timers) would leak onto your new target for the first few seconds after a switch. This caused wrong decisions � for example, refreshing a DoT early because the old target's TTD was short, or skipping an execute because the old target's HP was high.

Now, the moment you switch target, the TTD tracker and EMA tracker are reset. Clean slate, correct decisions.

---

### ?? Fixed: Priest � Tab-Target Safety

**Shadow, Holy, and Discipline priests no longer accidentally pull unengaged mobs when tab-targeting.**

Spread-DoT and idle-damage strategies (Multi-Dot, SW:P spread, idle Smite / Holy Fire) now verify the target has actually engaged with you or your party before casting. Prevents dots from landing on patrols, wanderers, or neutral mobs you just happened to tab onto.

**Holy & Discipline bonus:** Party Fortitude � out of combat, the rotation scans your group and casts Power Word: Fortitude on any party member missing the buff. No more manually buffing everyone after a rez.

---

### ?? Fixed: Rotation Toggle Survives Reload

**Turning the rotation OFF now stays OFF after a UI reload.**

Previously, disabling the rotation via keybind and then reloading UI caused the rotation to run for 1-2 ticks before the toggle state synced back. This could trigger accidental spell casts immediately on reload. Fixed by reading the toggle state directly from the persisted widget instead of the ephemeral settings store.

## v2.3.11 — July 4, 2026

### 🐛 Fixed: Druid Cat — Travel Form Spam

**The problem:** Feral Cat druids were seeing their rotation rapidly flip between Cat Form and Travel Form every few seconds while out of combat. This burned mana, locked the global cooldown, and made it impossible to set up a clean Prowl opener.

**The fix:**
- Form-switching now has a longer cooldown, preventing the rapid back-and-forth
- Travel Form auto-cast is now **off by default** — you can turn it on in settings if you want it
- Travel Form only fires when you're actually moving
- If you're already in Travel Form running toward a distant target, the rotation won't force you back into Cat Form

**How to enable Travel Form auto-cast:**
EaxRotations Menu → Class Settings → Cat → check **"Auto Travel Form"**

---

## v2.3.10 — July 4, 2026

### 🐛 Fixed: Hunter — Aspect of the Hawk / Viper Missing

Hunter rotations were not correctly maintaining Aspect of the Hawk (or Viper when low on mana) through the class middleware. The aspect manager strategies were not being registered properly, causing some hunters to fight without their primary attack-power buff.

---

## v2.3.9 — July 3, 2026

### 🐛 Fixed: Shadow Priest — Mind Flay Firing Too Early

Mind Flay was sometimes opening on fresh targets before Shadow Word: Pain and Mind Blast had been applied. It now correctly waits until the target has engaged (either by attacking you or a party member) before channeling Mind Flay.

---

## v2.3.8 — July 3, 2026

### 🐛 Fixed: Mage — Fire — Clearcasting Not Working

The Clearcasting proc (from Arcane Concentration) was not being consumed by Fireball. The rotation now tracks Clearcasting properly and will fire an instant-cast Fireball when the proc is active.

### 🐛 Fixed: Warrior — Arms — Death Wish Not Bursting on Bosses

Death Wish was not firing during boss fights when it should have been. The rotation now correctly detects boss targets and uses Death Wish as a burst cooldown.

### 🐛 Fixed: Druid — Bear — Nature's Grasp Not Firing When Rooted

In PvP, when the bear was rooted or snared, Nature's Grasp was not automatically casting to peel melee attackers. It now fires correctly when crowd-controlled.

### 🐛 Fixed: Warlock — Demonology — Pet Strategies Stalling

Pet-related strategies were using stale state information, causing Felguard / Voidwalker abilities to not cast reliably. Pet state is now refreshed correctly every tick.

---

## v2.3.7 — July 2, 2026

### ✨ Improved: Healer Dispel Throttle

All four healer specs (Holy Paladin, Discipline Priest, Restoration Druid, Restoration Shaman) now throttle dispels and cleanses to a 3-second interval. This prevents rapid-fire casting when debuff data is updating slowly, saving mana and GCDs.

---

## v2.3.0–2.3.6 — July 2, 2026

### ✨ Major: Server-Authoritative Swing Timer

**For melee specs:** Retribution Paladin, Enhancement Shaman, Arms Warrior, Fury Warrior

The rotation now reads the exact server swing timestamp from combat log events instead of guessing. This means:
- **Seal Twisting** is judged against real server data — no more phantom twists from latency
- **Stormstrike alignment** (Enhancement) and **Heroic Strike trick timing** (Warrior) are now precise
- Falls back automatically to native prediction if combat log data is unavailable

### ✨ Instant Snap Threat on Pull

**For tanks:** Protection Paladin, Protection Warrior

Your opener (Judgement / Shield Slam) now fires the exact moment combat begins, giving you a 50–100ms head start before DPS opens. Reduces early aggro loss on trash and boss pulls.

### ✨ Light's Grace Chaining (Holy Paladin)

When Light's Grace has less than 2.5 seconds remaining, the rotation automatically queues another Holy Light to keep the 0.5-second cast-time reduction rolling. Only fires in combat and stays below emergency spells (Divine Favor + Holy Shock) on priority.

### ✨ Blessing of Kings Party Buff (Protection Paladin)

Out of combat, the rotation scans party members and applies Blessing of Kings to anyone missing the buff. Gated by a setting (default enabled).

### ✨ Configurable DoT Refresh Windows (Shadow Priest)

Replaced hardcoded refresh thresholds with user-configurable sliders:

| Setting | Range | Default |
|---------|-------|---------|
| Vampiric Touch Refresh Window | 0.5s – 3.0s | 1.5s |
| Shadow Word: Pain Refresh Window | 0.5s – 3.0s | 1.5s |

Lower values = refresh closer to expiration (better for low latency). Higher values = refresh earlier (safer for movement-heavy fights).

### ✨ PvP DR Gating

Stun abilities now check diminishing returns before casting:
- **Hammer of Justice** (Holy / Prot Paladin)
- **Cheap Shot** (Combat Rogue)
- **Kidney Shot** (Combat / Subtlety Rogue)

This prevents wasting a full-duration stun on a target that is already DR-immune.

### ✨ Warrior Fear Break

Death Wish and Berserker Rage now automatically fire when the warrior is feared, sapped, or incapacitated. Death Wish works in any stance (unlike Berserker Rage which requires Berserker Stance).

### ✨ Druid Barkskin Configurability (Restoration)

The Barkskin HP threshold is no longer hardcoded at 55%. The rotation now respects the slider value you've set in the menu.

### ✨ Shaman Tremor Totem PvP Coverage (Enhancement)

Tremor Totem now drops automatically when any nearby party member has a fear debuff (Warlock Fear, Priest Psychic Scream, etc.), not just against known fear-casting boss NPCs.

---

## Installation

1. Download the latest `EaxRotations-vX.X.X.zip` from [Releases](https://github.com/eaxiumnet/eaxrotations/releases)
2. Extract to your Project Sylvanas `Scripts/` folder
3. Reload UI or restart the game

All updates are backward compatible — no settings reset required.

---

*Report issues: https://github.com/eaxiumnet/eaxrotations/issues*
