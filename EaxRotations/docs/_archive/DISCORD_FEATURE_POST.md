# EaxRotations — Feature Overview

**An ambitious TBC Classic rotation suite with a standout visual HUD and one of the deepest PvP layers in the project.**

---

## All 9 TBC Classes, All Specs

EaxRotations covers every TBC class with a mix of deeply theorycrafted rotations, functional priority lists, and shared helper modules:

| Class | Specs | Role |
|---|---|---|
| **Warrior** | Arms, Fury, Protection | DPS / Tank |
| **Paladin** | Holy, Retribution, Protection | Heal / DPS / Tank |
| **Hunter** | Beast Mastery, Marksmanship, Survival | DPS |
| **Rogue** | Assassination, Combat, Subtlety | DPS |
| **Priest** | Holy, Discipline, Shadow | Heal / DPS |
| **Shaman** | Elemental, Enhancement, Restoration | DPS / Heal |
| **Mage** | Arcane, Fire, Frost | DPS |
| **Warlock** | Affliction, Demonology, Destruction | DPS |
| **Druid** | Balance, Bear, Feral Cat, Restoration | DPS / Tank / Heal |

> **Total: 27 playstyle implementations — 10 deeply theorycrafted, 17 functional priority lists, plus 4 shared helper modules.** The 4 helper modules (Druid/Paladin/Priest/Shaman healing helpers) are not playstyles themselves; they provide shared logic consumed by the Resto/Holy/Discipline/Restoration specs. Depth varies by spec and is called out honestly below.

---

## What You Get

### Smart Rotation Engine
- **Priority-based casting** with real-time condition checks (health, rage, mana, energy, combo points, stance, form).
- **DoT refresh optimization** — refreshes before expiration to maintain uptime.
- **Execute phase detection** — dynamically switches priorities below 20% / 25% / 35% HP depending on class.
- **Sticky spell system** — prevents flickering recommendations by holding the same suggested spell across frames.

### PvP Intelligence
- **Arena target scoring** — scoring exists for kill and CC targets, while manual target selection is respected.
- **Class threat taxonomy** — understands that Rogues and Mages are burst/CC threats, Warriors are sustained melee, etc.
- **DR tracking** — tracks Diminishing Returns per target (stun/fear/root/cyclone/incap/silence/disarm) so you can avoid wasting CC on immune targets.
- **Enemy cooldown tracker** — watches for major defensive/offensive cooldowns (Ice Block, Divine Shield, Recklessness, etc.) and can adjust burst timing accordingly.
- **PvP burst window scoring** — recommends offensive CDs when the target appears vulnerable.

### Healing Support
- **Predictive healing** — effective-health style healing for Paladin; simplified healing logic for Priest/Shaman.
- **Smart downranking** — Paladin only; Priest selects the first ready rank rather than a full deficit/mana efficiency model.
- **Preemptive targeting** — flags units taking damage before their health drops where supported, so HoTs and shields can land earlier.
- **Party dispel automation** — cleanses magic, poison, disease, and curses on a priority basis where the class toolkit supports it.
- **Tank priority** — prioritizes the tank in raid-style healing scenarios.

### Tanking & Mitigation
- **Shield Block uncrushable logic** — maintains Shield Block uptime as a top Warrior Protection priority to help push crushing blows off the attack table.
- **Revenge proc awareness** — detects when Revenge is available after dodge/parry/block and prioritizes it for efficient threat.
- **Threat drop automation** — uses available threat drops such as Fade or Feint when supported by the spec.
- **Stance-aware rage math** — calculates rage preserved after stance swaps so Warrior rotations avoid dead swaps.
- **AoE threat** — switches to tools such as Cleave, Swipe, or Thunder Clap at multi-target thresholds where implemented.

### Cooldown & Buff Management
- **Trinket automation** — uses offensive and defensive trinkets around burst, execute, or emergency windows where implemented.
- **Racial ability usage** — Blood Fury, Berserking, Arcane Torrent, Will of the Forsaken triggered automatically where supported.
- **Out-of-combat buff upkeep** — rebuffs Battle Shout, Arcane Intellect, Mark of the Wild, etc. before combat starts. Now with **urgency coloring** (green/yellow/red) so you always know which buff is falling off next.
- **Weapon imbue tracking** — ensures Windfury, Poison, or Shaman enchant state is visible/handled where supported.

### Dashboard & HUD
- **Real-time combat overlay** showing:
  - Current suggested spell icon
  - Cooldown timers (big + small)
  - Buff/debuff status bars
  - Resource bars (rage, mana, energy, combo points)
  - Swing timer (melee + ranged)
  - Threat bar
  - Energy tick sweep (Rogues)
- **Debug log window** — scrollable combat log with copy/clear/resize support where enabled.
- **Note:** Real-time DPS tracking requires a CLEU-equivalent API from the Sylvanas runtime. A timer-based damage approximation module exists but is disabled pending full combat-log integration.

### Gear & Simulation Integration
- **Gear set awareness** — tracks ~133 TBC set item IDs and bonus spell IDs for reference.
- **Gear score calculator** — evaluates equipped gear quality per slot with tier detection.
- **JSON exporter** — exports rotation strategy data for external simulation/analysis workflows where supported.

### Settings & Customization
- **Per-spec settings panel** with checkboxes, sliders, keybinds, and color pickers.
- **Mode selection** — Auto (PvE/PvP detection), PvE Only, PvP Only.
- **Force commands** — manual override keybinds to force burst, defensive, or gap-closer usage for short windows where supported.
- **Custom rotation builder** — available for advanced priority-list experimentation where wired into the spec.
- **Settings persistence** — preferences saved and restored across sessions.

### Safety & Performance
- **Cached/throttled hot paths** — expensive calls are cached at load, throttled, or pre-allocated where the active code follows the shared pattern.
- **Nil-safe menus** — setting access is guarded to prevent crashes.
- **Square-distance checks** — avoids slow `math.sqrt()` in tight loops in active rotation code.
- **Static table reuse** — pre-allocated tables are reused in combat paths to reduce garbage collection.

---

## New in This Update

- **Warrior Protection** — Shield Block now prioritizes keeping you uncrushable. Revenge triggers immediately when its proc is available for efficient threat.
- **Warrior Stance Dancing** — Tactical Mastery rage math helps prevent stance swaps into an empty rage bar.
- **Buff Urgency System** — OOC buff refresh now shows color-coded urgency (green → yellow → red) so you always know which buff expires first.
- **Arena Threat Scoring** — Kill target scoring now factors in per-class threat profiles such as burst mages vs sustained warriors.

---

## What Makes EaxRotations Different

- **Honest breadth** — every TBC class is represented, with clear separation between deeply theorycrafted specs, functional priority lists, and shared helper modules.
- **Best visual HUD + deepest PvP layer** — the strongest differentiators are the real-time dashboard and the arena-aware scoring/DR/cooldown systems.
- **Healer support with clear limits** — Paladin has the deepest predictive/downranking work; Priest and Shaman healing paths are simpler.
- **Tank precision where implemented** — Warrior Protection gets uncrushable logic, proc-aware Revenge, and stance math; other tanks use more conventional priority support.
- **Developer-grade validation focus** — `luac` validation, banned API avoidance, nil-safe menu patterns, and documented architecture guide ongoing development.

---

EaxRotations is built for players who want a polished HUD, strong PvP awareness, and practical TBC rotation support without pretending every spec has the same depth. Whether you're pushing arena rating, parsing on Gruul, or farming heroics, there is a playstyle path for you — with the deepest work concentrated in the audited core specs.
