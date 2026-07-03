# EAX vs Competitors — Full TBC+Classic Marketplace Analysis
**Date:** 2026-06-28
**Scope:** All 66 plugins (Classic Era + TBC, Free + Paid)
**Source:** project-sylvanas.net marketplace

---

## Market Overview

| Category | Count | Key Players |
|----------|-------|-------------|
| **Rotation Plugins** | 30 | (13), EAX (3), Astro (3), KxE (2), LX (2), Asbo (1), OpenPriest (1), Pixel (1), Root_Priest (1), RaidRush (1) |
| **Utility Plugins** | 6 | Universal series (kicks, dispels, racials, items, reflects, revive) |
| **ESP/Visual** | 7 | Byte ESP (3), King Lion (2), Jambix (1), Cursor Highlight (1) |
| **Botting** | 10 | Brawguy (3), Lekora (1), LX Botsuite (1), Auto Follow/Dodge (1), Kebab Auto BG (1), Fishing (2), Auto Loot (1) |
| **Dev Tools** | 13 | Prediction Playground, Developer Tools, LX Data DevTool, Stream Mode, etc. |

---

## Rotation Plugin Coverage Matrix

| Class | Spec | Competitor | EAX Status |
|-------|------|------------|------------|
| **Warrior** | Arms | ✅, Asbo ✅ | ✅ |
| | Fury | ✅, Asbo ✅ | ✅ |
| | Protection | ✅, Asbo ✅, EAX (separate) ✅ | ✅ |
| **Paladin** | Holy | ✅ | ✅ |
| | Protection | ✅ | ✅ |
| | Retribution | ✅ | ✅ |
| **Hunter** | BM | ✅, LX ✅, Astro ✅, KxE ✅ | ✅ |
| | MM | (has BM + Survival, no dedicated MM) | ✅ |
| | Survival | ✅ | ✅ |
| **Rogue** | All | Astro ✅, Pixel (Classic AIO) | ✅ (3 specs) |
| **Priest** | Holy | ✅ (Holy+Disc), Root_Priest ✅, OpenPriest ✅ | ✅ |
| | Discipline | ✅ (Holy+Disc), Root_Priest ✅, OpenPriest ✅ | ✅ |
| | Shadow | ✅, OpenPriest ✅ | ✅ |
| **Shaman** | Elemental | ✅ | ✅ |
| | Enhancement | ✅ (2 plugins: endgame + leveling) | ✅ |
| | Restoration | ✅ | ✅ |
| **Mage** | All | Pixel (Classic AIO) | ✅ (3 specs) |
| **Warlock** | Affliction | ✅ | ✅ |
| | Destruction | ✅ | ✅ |
| | Demonology | ❌ NO COMPETITOR | ✅ |
| **Druid** | Balance | ✅ | ✅ |
| | Feral (Cat) | EAX (separate) ✅ | ✅ |
| | Feral (Bear) | EAX (in Feral) ✅ | ✅ |
| | Restoration | Astro ✅, ❌ | ✅ |
| **Death Knight** | All | ❌ NO TBC PLUGIN | N/A (TBC) |

**Coverage:** EAX covers all 29 specs + 11 leveling. covers ~20 specs with dedicated plugins. No competitor has full coverage.

---

## Competitor Features EAX is Missing

### (13 plugins) — Most Serious Competitor

#### General Advantages (across all specs)
1. **Dedicated Discord Community** — Branded server per-spec, daily active support
2. **Changelog on Every Plugin** — Versioned releases with dates, detailed patch notes
3. **Trial Periods** — "TRY FREE FOR 3 DAYS" on multiple plugins
4. **GUI/Settings Windows** — Draggable HUD overlays, 8-page settings (Prot Warrior)
5. **Nexus Integration** — "Nexus" — improved cast validation, buff/debuff tracking, enemy scanning
6. **Sticky Target** — Target locking (Elemental Shaman)
7. **Raid Marker Priority** — Target selection by raid marker (Elemental Shaman)
8. **Debug Diagnostics** — PERFECT/LATE/NO-TWIST/PHANTOM logging (Ret Pally)
9. **Swing Timer HUD** — Live sync status display (Enh Shaman)
10. **Free Trial System** — Built-in trial claiming UI

#### Warrior (Arms/Fury/Prot)
1. **Auto-Charge** — Automatic Charge + stance swap
2. **Rampage Stack Management** — Tracks Rampage buff stacks
3. **Bloodrage Integration** — Auto Bloodrage for rage generation
4. **Shield Block Smart Mode** — "Smart mode" for Shield Block (Prot)
5. **Interrupt Delay Slider** — Configurable delay (0–800ms)
6. **1-70 Unified** — Single script for leveling + endgame (merged in v2.0)
7. **Rend on Charge** — Applies Rend immediately after Charge before Berserker Stance swap
8. **Demoralizing Shout** — Auto-maintains

#### Hunter (BM/Survival)
1. **Auto-Shot Timer System** — Shot weaving with buffer slider
2. **Complete Pet Management** — Auto-summon, Mend Pet, Kill Command, pet attack, auto-feed
3. **Pet Food Selection** — Auto-selects level-appropriate food from bags
4. **Expose Weakness Uptime** — Survival-specific tracking
5. **Readiness Cooldown Management** — Survival

#### Shaman (Enhancement Endgame)
1. **Flurry Swing Synchronization** — Tracks MH/OH timers, detects sync status
2. **Totem Twisting** — Windfury + Grace of Air twist (both endgame AND leveling)
3. **Stormstrike Priority** — Proper SS priority
4. **Totem Duration Tracking** — Recasts before expiry
5. **Ghost Wolf Integration** — Auto-shifts OOC
6. **Tremor Totem Support** — Auto-drop when feared
7. **Weapon Buff Timer** — Ensures weapon buffs never fall off

#### Priest (Holy+Disc)
1. **Auto Spec Detection** — Detects Holy vs Disc at load (Circle of Healing anchor)
2. **Respec Detection** — Mid-session respec without /reload
3. **Pet Healing** — Tops off party/raid pets
4. **Mounted Bail** — Suppresses all casts while mounted

#### Warlock (Affliction/Destruction)
1. **Pet Totem Targeting** — Pet attacks enemy totems
2. **Multi-DoT Spreading** — SW:P/Corruption to multiple targets
3. **Shadowfury Interrupt** — Smart interrupt with cooldown awareness
4. **Dual Build Support** — Fire/Shadow destruction
5. **Soul Shard Management** — Drain Soul at configurable shard count

#### Druid (Balance)
1. **Multi-DoT Management** — Moonfire/Insect Swarm spread
2. **Intelligent Pull Mechanics** — Starfire vs Wrath based on range
3. **Eclipse Cycle Tracking** — Solar/Lunar awareness

#### Paladin (Holy/Prot/Ret)
1. **Light's Grace Chaining** — Maintains 0.5s haste buff continuously
2. **Judgement of the Crusader** — Maintains spell crit debuff
3. **Fonsas-Exact Seal Twist** — 400ms/1900ms edge algorithm
4. **Snap Threat on Combat Start** — Early Judgement at combat entry
5. **Swing Timer Diagnostics** — Debug mode with ms values
6. **Mana Emergency Swap** — Auto JoW below threshold

### Asbo_Warrior (1 plugin — AIO)
1. **WASD Friendly** — Works with WASD movement
2. **Auto Spec Detection** — Arms/Fury/Prot auto-detect
3. **Spell Reflection** — Protection utility
4. **Full Custom Settings UI** — Extensive GUI

### LX Hunter (1 plugin)
1. **Distance-Based Zone Detection** — Ranged vs melee detection
2. **Multi-Rank Support** — All spells with rank selection
3. **Pet Food Selection** — Auto from bags
4. **LxGrinder Integration** — Botting automation pairing

### OpenPriest (1 plugin — open source!)
1. **Open Source** — Codeberg repository (public)
2. **5SR Logic** — Five Second Rule mana management
3. **PvP Dispel on Friendlies** — Smart dispel targeting
4. **Burst Healing** — Emergency burst mode
5. **Free + Public** — Completely free with public fixes

### Root_Priest (1 plugin)
1. **Profile System** — Enable/Disable profiles
2. **Solo/5-Man/Raid Modes** — Content-aware switching
3. **Automated Rotation** — One-button simplicity

### Pixel - Classic AIO (1 plugin)
1. **Classic AIO** — All classes in one plugin
2. **Quick Updates** — Developer responsive to feedback

### KxE Hunter (1 plugin)
1. **Endgame Parsing Optimized** — Built for parsing/ranking
2. **Leveling Mode Toggle** — Separate leveling vs endgame

---

## EAX Advantages Over Competitors

| Feature | EAX | Competitors |
|---------|-----|-------------|
| **Spec Coverage** | 29 + 11 leveling | : ~20, Others: 1-3 each |
| **Overheal Prevention** | ✅ Predictive gate_overheal() | ❌ Not mentioned by any |
| **Triage Scoring** | ✅ Triage.rank() target selection | ❌ Not mentioned |
| **Predictive Healing** | ✅ Cast-time prediction | ❌ Not mentioned |
| **Blessing Management** | ✅ Auto BoL/BoW/Kings + Greater | ❌ mentions BoK only |
| **Aura Management** | ✅ Auto-switch all resist auras | ❌ Not mentioned |
| **Dispel/Cleanse** | ✅ Auto magic/poison/disease | ❌ OpenPriest only |
| **Defensive Utility** | ✅ BoP, BoFreedom, BoSac, DS | ❌ Limited |
| **CC Break** | ✅ Preemptive DS/Freedom | ❌ Not mentioned |
| **Solo/Idle DPS** | ✅ Full damage rotation OOC | ❌ Not mentioned |
| **Friendly Target Honor** | ✅ Respects manual selection | ❌ Not mentioned |
| **Consumables** | ✅ Auto mana pots + Dark Runes | ❌ Not mentioned |
| **Avenging Wrath** | ✅ +20% healing burst, TTD gated | ❌ has basic |
| **Cross-Spec Shared Logic** | ✅ 50 shared modules | ❌ Standalone plugins |
| **Test Suite** | ✅ 171 rotation + 11 leveling tests | ❌ Not mentioned |
| **Open Source** | ❌ Private | ✅ OpenPriest is open source |

---

## Actionable Gaps to Close

### Critical (Easy Wins, High Impact)
1. **Add Changelog to EaxRotations page** — Every plugin has detailed changelogs. EAX has one entry.
2. **Add Trial Period** — "TRY FREE FOR 3 DAYS" is standard for . EAX has no trial.
3. **Improve Plugin Description** — EAX description is generic ("early build, report bugs"). has detailed feature lists, Discord links, configuration options.
4. **Add Plugin Marketing Copy** — plugins have "Perfect For" sections listing raids/dungeons, rotation priorities, configuration options.
5. **Add Settings/Configuration Details** — lists all config options in description. EAX mentions nothing.

### High Priority (Feature Gaps)
6. **Judgement of the Crusader** — Missing across all EAX paladin specs. has it on all three.
7. **Snap Threat on Combat Start** — Prot Pally: early Judgement at combat entry.
8. **Inner Focus → Mind Blast** — Shadow Priest: hold IF for MB.
9. **DoT TTD Gating** — Shadow Priest: skip VT/SW:P on dying targets. has this.
10. **Multi-DoT Spread** — Shadow Priest: spread to nearby enemies.
11. **Seal Twist Diagnostics** — Ret Pally: PERFECT/LATE/NO-TWIST/PHANTOM logging.
12. **Post-Swing Judgement** — Ret Pally: judge after swing to avoid melee delay.

### Medium Priority
13. **Totem Twisting** — Enhancement Shaman: WF + GoA twist.
14. **Flurry Swing Sync** — Enh Shaman: MH/OH timer tracking.
15. **Auto Weapon Buffs by Level** — Enh Shaman: Rockbiter→Flametongue→Windfury.
16. **Ghost Wolf OOC** — Enh Shaman: auto-shift for movement.
17. **Tremor Totem Auto-Drop** — Enh Shaman: when feared.
18. **Shield Switching by Mana** — Enh Shaman: Lightning/Water shield auto.
19. **Pet Totem Targeting** — Warlock: pet attacks enemy totems.
20. **Soul Shard Management** — Warlock: Drain Soul at configurable count.
21. **Mounted Bail** — All specs: no casts while mounted.
22. **Auto Spec Detection** — Detect spec at load without manual switching.
23. **Pet Healing** — Healers: top off party/raid pets.
24. **WASD Friendly** — Movement compatibility.

### Lower Priority
25. **Interrupt Delay Slider** — Configurable interrupt timing.
26. **Draggable HUD Overlay** — Live status display.
27. **Debug Mode** — Detailed logging for troubleshooting.
28. **Free Trial System** — Built-in trial claiming.
29. **Sticky Target** — Target locking mechanism.
30. **Raid Marker Priority** — Target by raid marker.

---

## Marketing/Copy Recommendations

### What EAX Should Add to Plugin Page
1. **Feature list with bullet points** (like)
2. **"Perfect For" section** listing raids/dungeons
3. **Rotation priority list** (numbered 1-10)
4. **Configuration options list**
5. **Discord link**
6. **Detailed changelog** with version numbers and dates
7. **Screenshots of settings/menu**
8. **Testimonials/reviews section**
9. **Trial period**
10. **Class coverage grid** showing all 29 specs

### EAX Description (Current)
> "EaxRotations is an early-build TBC Classic rotation package... Because this is an early build, user feedback is extremely important..."

### Description (Example)
> "Full Holy Paladin healing automation for TBC Classic. Handles the complete healing priority chain including rank selection, proc tracking, and cooldown management — so you can focus on positioning and raid awareness.
>
> **Rank-Aware Holy Light** — Automatically selects the correct HL rank...
> **Light's Grace Chaining** — Tracks the Light's Grace buff...
> **Divine Favor Combo** — Pairs Divine Favor with Holy Shock...
>
> **Configuration Options:**
> - Holy Light threshold: HP% below which HL is preferred
> - Flash of Light threshold: HP% for emergency heal
> - Divine Favor HP trigger: threshold for DF combo
> - Lay on Hands HP threshold: configurable emergency floor
>
> **Perfect For:** Holy Paladins main-tanking heal assignments in Karazhan, Gruul's Lair, Serpentshrine Cavern, and The Eye.
>
> **Rotation Priority:**
> 1. Lay on Hands (emergency)
> 2. Divine Favor + Holy Shock (combo)
> 3. Divine Illumination (cooldown)
> 4. Holy Light (rank-selected)
> 5. Flash of Light (efficient)
> 6. Judgement of the Crusader (debuff)"

---

## Summary

**EAX Competitive Position:**
- ✅ **Breadth:** Unmatched (29 specs + 11 leveling vs 's ~20)
- ✅ **Technical depth:** gate_overheal, Triage, predictive healing, blessing/aura management
- ❌ **Marketing:** Minimal descriptions, no changelog, no trial, no feature lists
- ❌ **Some feature gaps:** JoC, snap threat, TTD gating, seal twist diagnostics, totem twisting
- ❌ **No open source:** OpenPriest is free + open source

**Priority for next sprint:**
1. Improve EaxRotations plugin page with feature lists, changelog, trial
2. Close JoC gap across paladin specs
3. Add snap threat for prot warrior/paladin
4. Add TTD gating for shadow priest DoTs
5. Consider open-sourcing or adding free trial
