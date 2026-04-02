# EAX TBC Classic Rotations

> **TBC-targeted** rotation pack for **WoW TBC 2.4.3 / Project Sylvanas** with all **27 playable specs** in one repository.

![TBC 2.4.3](https://img.shields.io/badge/TBC-2.4.3-7c3aed?style=flat-square)
![27 Specs](https://img.shields.io/badge/specs-27-111827?style=flat-square)
![Lua Only](https://img.shields.io/badge/shipping-lua%20%2B%20md-0f766e?style=flat-square)
![No TOC](https://img.shields.io/badge/package-no%20.toc-dd1144?style=flat-square)
![PvP Ready](https://img.shields.io/badge/pvp-targeting%20%2B%20cds-2563eb?style=flat-square)
![Leveling](https://img.shields.io/badge/leveling-1--70%20optimized-16a34a?style=flat-square)

---

## Snapshot

- **Coverage:** Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior — all 27 specs
- **Packaging rule:** only `.lua` and `.md` files ship in the EAX rotation folders
- **Removed from shipping:** all EAX `.toc` files, vendor automation, mount manager, WotLK-era menu toggles
- **Scoring model:** usefulness is estimated from `main.lua`, `spells.lua`, helper modules, and visible rotation complexity
- **Important:** these numbers are **not** live raid logs or in-game benchmarks; they are source-based readiness estimates
- **TBC truth:** this repo aims for true TBC behavior, verified against FLUX/wowsims research docs and Icy Veins TBC guides

### Current Release Status — 2026-04-02

- **All 27 specs:** rotation logic improved with FLUX/wowsims verified priorities
- **Code optimization:** -591 lines of bloat removed, 42% pcall reduction in HunterMM, 14% size reduction in WarriorProtection
- **Leveling 1-70:** spell rank downranking, pull speed optimization, mana conservation
- **PvP:** enemy player targeting, spec-specific cooldowns, arena/BG awareness
- **Dungeons:** encounter awareness, CC tracking, interrupt management
- **Raids:** BigWigs integration, boss ability timing, group buff management
- **Biggest remaining gap:** live in-game validation — everything compiles and is logically sound, but needs real combat proof
- **Release stance:** ship **after smoke tests**, not blind ship

### Usefulness Matrix

| Class | Spec | Role | Races | Solo | Dungeon | Raid | PvP |
|-------|------|:----:|:-----:|:----:|:-------:|:----:|:---:|
| **Druid** | | | | | | | |
| | Balance | ⚔️ DPS | Night Elf, Tauren | 78% | 76% | 72% | 60% |
| | Feral | 🛡️⚔️ Tank/DPS | Night Elf, Tauren | 84% | 80% | 76% | 65% |
| | Restoration | 💚 Healer | Night Elf, Tauren | 70% | 92% | 88% | 55% |
| **Hunter** | | | | | | | |
| | Beast Mastery | ⚔️ DPS | Dwarf, Night Elf, Orc, Tauren, Troll, Blood Elf | 88% | 84% | 82% | 70% |
| | Marksmanship | ⚔️ DPS | Dwarf, Night Elf, Orc, Tauren, Troll, Blood Elf | 82% | 78% | 76% | 68% |
| | Survival | ⚔️ DPS | Dwarf, Night Elf, Orc, Tauren, Troll, Blood Elf | 78% | 74% | 72% | 72% |
| **Mage** | | | | | | | |
| | Arcane | ⚔️ DPS | Gnome, Human, Dwarf, Undead, Troll, Blood Elf | 76% | 80% | 84% | 75% |
| | Fire | ⚔️ DPS | Gnome, Human, Dwarf, Undead, Troll, Blood Elf | 76% | 80% | 82% | 72% |
| | Frost | ⚔️ DPS | Gnome, Human, Dwarf, Undead, Troll, Blood Elf | 82% | 86% | 88% | 80% |
| **Paladin** | | | | | | | |
| | Holy | 💚 Healer | Human, Dwarf, Blood Elf | 52% | 96% | 94% | 45% |
| | Protection | 🛡️ Tank | Human, Dwarf, Blood Elf | 72% | 94% | 92% | 60% |
| | Retribution | ⚔️ DPS | Human, Dwarf, Blood Elf | 90% | 90% | 88% | 70% |
| **Priest** | | | | | | | |
| | Discipline | 💚 Healer | Human, Dwarf, Night Elf, Undead, Troll, Blood Elf, Draenei | 55% | 82% | 76% | 75% |
| | Holy | 💚 Healer | Human, Dwarf, Night Elf, Undead, Troll, Blood Elf, Draenei | 50% | 86% | 82% | 50% |
| | Shadow | ⚔️ DPS | Human, Dwarf, Night Elf, Undead, Troll, Blood Elf, Draenei | 84% | 80% | 76% | 70% |
| **Rogue** | | | | | | | |
| | Assassination | ⚔️ DPS | Human, Dwarf, Night Elf, Gnome, Orc, Troll, Undead, Blood Elf | 88% | 86% | 86% | 80% |
| | Combat | ⚔️ DPS | Human, Dwarf, Night Elf, Gnome, Orc, Troll, Undead, Blood Elf | 84% | 88% | 84% | 75% |
| | Subtlety | ⚔️ DPS | Human, Dwarf, Night Elf, Gnome, Orc, Troll, Undead, Blood Elf | 78% | 74% | 70% | 85% |
| **Shaman** | | | | | | | |
| | Elemental | ⚔️ DPS | Orc, Tauren, Troll, Draenei | 76% | 76% | 72% | 65% |
| | Enhancement | ⚔️ DPS | Orc, Tauren, Troll, Draenei | 84% | 84% | 80% | 70% |
| | Restoration | 💚 Healer | Orc, Tauren, Troll, Draenei | 70% | 92% | 88% | 55% |
| **Warlock** | | | | | | | |
| | Affliction | ⚔️ DPS | Human, Gnome, Orc, Undead, Blood Elf | 88% | 84% | 84% | 70% |
| | Demonology | ⚔️ DPS | Human, Gnome, Orc, Undead, Blood Elf | 78% | 78% | 74% | 65% |
| | Destruction | ⚔️ DPS | Human, Gnome, Orc, Undead, Blood Elf | 84% | 84% | 84% | 72% |
| **Warrior** | | | | | | | |
| | Arms | ⚔️ DPS | All Races | 84% | 80% | 80% | 75% |
| | Fury | ⚔️ DPS | All Races | 86% | 82% | 78% | 70% |
| | Protection | 🛡️ Tank | All Races | 60% | 92% | 88% | 65% |

**Legend:** ⚔️ DPS | 🛡️ Tank | 💚 Healer | 🛡️⚔️ Dual Role

> **Reading the scores:** `90-100` = strong fit, `75-89` = very usable, `60-74` = workable, `<60` = partial
> 
> **Races:** Alliance = Human, Dwarf, Night Elf, Gnome, Draenei | Horde = Orc, Undead, Tauren, Troll, Blood Elf

---

## What Ships

- `EAX<Class><Spec>/` rotation folders
- `.lua` runtime and rotation files
- `.md` documentation files
- `eax_shared/` shared modules (pull optimizer, PvP manager, etc.)

### What Does **Not** Ship

- `.toc` files
- zip artifacts
- screenshots / binaries / temp files
- non-EAX reference trees as part of the rotation package
- vendor automation / mount manager (removed — users handle this manually)

---

## Installation

```bash
git clone https://github.com/eaxiumnet/eax-tbc-classic-rotations.git
cd eax-tbc-classic-rotations
```

1. Keep the shared runtime already present in the repo.
2. Copy the `EAX...` spec folders you want into your Sylvanas `scripts` directory.
3. Reload the client or restart Sylvanas.
4. Enable the spec you want in the in-game menu.

---

## Features

### Leveling 1-70
- **Spell rank downranking** — uses mana-efficient spell ranks for low-level targets
- **Pull speed optimization** — skips cast-time spells on trivial targets (>10 levels below)
- **Mana conservation** — tiered mana management (full/conserve/emergency)
- **OOC management** — food/drink, group buffs, rez dead party members
- **Wand support** — auto-wand when mana is low (caster specs)

### PvE (Dungeons & Raids)
- **Encounter awareness** — boss-specific rotation adjustments
- **BigWigs integration** — proactive defensive timing on boss abilities
- **CC tracking** — knows when targets are crowd-controlled
- **Interrupt management** — priority-based interrupt system
- **Group buff management** — blessings, totems, auras
- **Defensive thresholds** — HP-based defensive cooldown tiers

### PvP (Arena & Battlegrounds)
- **Enemy player targeting** — finds all enemy players in range
- **Priority targeting** — Healers > Casters > Melee
- **Arena focus fire** — targets lowest HP enemy in 2v2/3v2
- **Battleground awareness** — flag carrier priority, node defense
- **Spec-specific cooldowns** — trinket, defensive, offensive CDs per class
- **CC detection** — auto-trinket when crowd-controlled

### Warlock Utility
- **Auto Healthstone** — creates and uses healthstones OOC/in-combat
- **Auto Soulstone** — applies to self and dead party members OOC

---

## Spec Notes

### TBC Cleanliness Summary

- **Closest to clean TBC behavior:** Holy Paladin, Protection Paladin, Retribution Paladin, Shadow Priest, Elemental Shaman, Enhancement Shaman, Affliction Warlock, Destruction Warlock, Arms Warrior, **Marksmanship Hunter** ✅
- **Mostly TBC, but still wants live validation:** Druid specs, Hunter specs (BM/Survival), Mage specs, Assassination Rogue, Subtlety Rogue, Restoration Shaman, Demonology Warlock, Protection Warrior
- **Still carrying visible non-TBC leftovers in source:** ~~Marksmanship Hunter utility flags~~ ✅ cleaned, Discipline Priest, Holy Priest, Combat Rogue, Fury Warrior

<details>
<summary><strong>Druid</strong></summary>

### Balance
- **Supported:** `Moonkin Form`, `Faerie Fire`, `Moonfire`, `Insect Swarm`, `Wrath`, `Starfire`, `Hurricane`, `Force of Nature`, `Innervate`
- **Unsupported / caveats:** no `Starfall`, no `Typhoon`, no `Eclipse`; DoT refresh windows improved, mana tier system added

### Feral
- **Supported:** `Cat Form`, `Bear Form`, `Dire Bear Form`, `Mangle`, `Rake`, `Shred`, `Rip`, `Ferocious Bite`, `Faerie Fire (Feral)`
- **Unsupported / caveats:** no `Savage Roar`, no `Berserk`; form weaving and edge-case tank/DPS swaps still need live verification

### Restoration
- **Supported:** `Rejuvenation`, `Regrowth`, `Swiftmend`, `Healing Touch`, `Nature's Swiftness`, `Innervate`, `Tranquility`, `Lifebloom`
- **Unsupported / caveats:** no `Wild Growth`, no `Nourish`; Lifebloom API sync, mana tier system, and spell downranking all solid

</details>

<details>
<summary><strong>Hunter</strong></summary>

### Beast Mastery
- **Supported:** `Auto Shot`, `Steady Shot`, `Arcane Shot`, `Aimed Shot`, `Multi-Shot`, `Kill Command`, `Bestial Wrath`, `Intimidation`, `Mend Pet`
- **Unsupported / caveats:** no `Chimera Shot`, no `Explosive Shot`, no `Black Arrow`; Kill Command pet engagement check added

### Marksmanship
- **Supported:** `Auto Shot`, `Aimed Shot`, `Arcane Shot`, `Steady Shot`, `Multi-Shot`, `Serpent Sting`, `Scorpid Sting`, `Kill Command`
- **Optimized:** Non-TBC stealth detection bloat removed (-380 lines, -42% pcall overhead)
- **Unsupported / caveats:** no `Chimera Shot`, no `Black Arrow`; shot weaving timing improved

### Survival
- **Supported:** `Auto Shot`, `Aimed Shot`, `Arcane Shot`, `Steady Shot`, `Multi-Shot`, `Serpent Sting`, `Hunter's Mark`, aspect handling
- **Unsupported / caveats:** no `Explosive Shot`, no `Black Arrow`; Mongoose Bite counter logic improved

</details>

<details>
<summary><strong>Mage</strong></summary>

### Arcane
- **Supported:** `Arcane Blast`, `Arcane Missiles`, `Arcane Power`, `Arcane Explosion`, `Evocation`, `Fire Blast`, `Counterspell`, curse removal
- **Unsupported / caveats:** no `Arcane Barrage`, no `Mirror Image`, no `Focus Magic`; burn/conserve phase transitions added

### Fire
- **Supported:** `Scorch`, `Fireball`, `Pyroblast`, `Combustion`, `Fire Blast`, `Flamestrike`, `Dragon's Breath`, `Blast Wave`, `Mage Armor`
- **Unsupported / caveats:** no `Living Bomb`, no `Hot Streak`; Imp Scorch stack tracking, Combustion timing improved

### Frost
- **Supported:** `Frostbolt`, `Ice Lance`, `Icy Veins`, `Water Elemental`, `Frost Nova`, `Cone of Cold`, `Ice Barrier`, `Arcane Explosion`
- **Unsupported / caveats:** no `Deep Freeze`, no `Fingers of Frost`, no `Brain Freeze`; Winters Chill tracking, FSCT timing improved

</details>

<details>
<summary><strong>Paladin</strong></summary>

### Holy
- **Supported:** `Holy Light`, `Flash of Light`, `Holy Shock`, `Lay on Hands`, `Divine Illumination`, `Divine Favor`, `Cleanse`, `Purify`, `Blessing of Wisdom`, `Blessing of Might`, conservative `Seal of Wisdom` sustain, `Concentration Aura`
- **Unsupported / caveats:** no `Beacon of Light`, no `Divine Plea`, no `Word of Glory`; Light's Grace tracking, Divine Illumination proactive timing added

### Protection
- **Supported:** `Avenger's Shield`, `Consecration`, `Judgement`, `Holy Shield`, `Righteous Fury`, `Seal of Righteousness`, `Seal of Wisdom`, `Seal of Light`, `Exorcism`, `Holy Wrath`, prepull `Holy Shield`, `Devotion Aura`
- **Unsupported / caveats:** no `Hammer of the Righteous`, no `Shield of the Righteous`, no `Holy Power`; Holy Shield charge tracking, SoV stack tracking added

### Retribution
- **Supported:** `Seal of Command`, `Seal of Blood`, `Seal of Righteousness`, `Seal of Wisdom`, `Seal of Light`, `Seal of the Crusader`, real `Judgement` flow, `Crusader Strike`, `Exorcism`, `Consecration`, `Hammer of Wrath`, optional seal twisting, `Retribution Aura`
- **Unsupported / caveats:** no `Divine Storm`, no `Templar's Verdict`, no `Holy Power`; Vengeance stack tracking, seal twist optimization added

</details>

<details>
<summary><strong>Priest</strong></summary>

### Discipline
- **Supported:** `Power Word: Shield`, `Renew`, `Prayer of Mending`, `Power Infusion`, `Pain Suppression`, `Flash Heal`, `Greater Heal`, `Prayer of Healing`, `Fear Ward`
- **Unsupported / caveats:** Weakened Soul tracking, PW:Shield proactive timing, Rapture proc tracking added

### Holy
- **Supported:** `Renew`, `Greater Heal`, `Prayer of Healing`, `Prayer of Mending`, `Flash Heal`, `Circle of Healing`, `Binding Heal`, `Holy Fire`, `Smite`
- **Unsupported / caveats:** Renew refresh windows, PoM+CoH pairing improved

### Shadow
- **Supported:** `Vampiric Touch`, `Shadow Word: Pain`, `Devouring Plague`, `Mind Blast`, `Mind Flay`, `Shadow Word: Death`, `Shadowfiend`, `Silence`, `Vampiric Embrace`
- **Unsupported / caveats:** no `Mind Sear`, no `Dispersion`; SW:P only when fallen off, MF clipping (3 tick types), VT haste-aware refresh, SW:D execute priority

</details>

<details>
<summary><strong>Rogue</strong></summary>

### Assassination
- **Supported:** `Mutilate`, `Envenom`, `Eviscerate`, `Slice and Dice`, `Rupture`, `Kick`, `Cold Blood`, `Vanish`, `Expose Armor`, poison support
- **Unsupported / caveats:** no `Fan of Knives`; Shiv for DP refresh, Envenom gating (DP stacks >= 3), Cold Blood + Envenom pairing

### Combat
- **Supported:** `Sinister Strike`, `Slice and Dice`, `Eviscerate`, `Rupture`, `Kick`, `Blade Flurry`, `Adrenaline Rush`, stealth openers, poison support
- **Optimized:** Unused stealth constants removed (STEALTH, VANISH, BUFF_STEALTH)
- **Unsupported / caveats:** energy pooling, SnD state machine, BF+AR stacking

### Subtlety
- **Supported:** `Stealth`, `Premeditation`, `Cheap Shot`, `Ambush`, `Backstab`, `Hemorrhage`, `Slice and Dice`, `Rupture`, `Expose Armor`, `Ghostly Strike`, `Shadowstep`
- **Unsupported / caveats:** no `Shadow Dance`; Shadowstep enabled in all modes, Ghostly Strike builder, Preparation simplified

</details>

<details>
<summary><strong>Shaman</strong></summary>

### Elemental
- **Supported:** `Lightning Bolt`, `Chain Lightning`, `Flame Shock`, `Elemental Mastery`, `Nature's Swiftness`, `Totem of Wrath`, `Earth Shock`, `Frost Shock`
- **Unsupported / caveats:** no `Lava Burst`, no `Thunderstorm`, no `Wind Shear`; Clearcasting tracking, rotation type selector, Flame Shock refresh at <=2s

### Enhancement
- **Supported:** `Stormstrike`, `Shamanistic Rage`, `Earth Shock`, `Flame Shock`, `Frost Shock`, `Chain Lightning`, `Lightning Bolt`, weapon imbues, totem support
- **Unsupported / caveats:** no `Lava Lash`, no `Feral Spirit`; Flame Shock always maintained, Stormstrike debuff tracking, totem twist WF+GoA improved, Fire Nova Totem twist added

### Restoration
- **Supported:** `Chain Heal`, `Healing Wave`, `Lesser Healing Wave`, `Earth Shield`, `Mana Tide Totem`, `Healing Stream Totem`, `Wrath of Air Totem`, `Windfury Totem`, `Grounding Totem`, `Tremor Totem`
- **Unsupported / caveats:** no `Riptide`, no `Earthliving Weapon`; Earth Shield charge tracking, Mana Tide proactive timing improved

</details>

<details>
<summary><strong>Warlock</strong></summary>

### Affliction
- **Supported:** `Unstable Affliction`, `Corruption`, `Siphon Life`, `Curse of Agony`, `Curse of Doom`, `Curse of Elements`, `Drain Soul`, `Shadow Bolt`, `Drain Life`
- **Unsupported / caveats:** no `Haunt`; Nightfall proc tracking, Siphon Life ISB-gating, Drain Soul TTD check, auto Healthstone/Soulstone

### Demonology
- **Supported:** `Corruption`, `Immolate`, `Shadow Bolt`, `Soul Fire`, `Shadowfury`, `Shadowburn`, `Drain Soul`, curses, pet-oriented support lanes
- **Unsupported / caveats:** no `Metamorphosis`, no `Immolation Aura`; pet health monitoring, Felguard management, Soul Link awareness, auto Healthstone/Soulstone

### Destruction
- **Supported:** `Immolate`, `Shadow Bolt`, `Incinerate`, `Conflagrate`, `Shadowfury`, `Shadowburn`, `Seed of Corruption`, `Soul Fire`, `Hellfire`, `Rain of Fire`
- **Unsupported / caveats:** no `Chaos Bolt`; Backlash proc tracking, Immolate->Conflag->Incinerate cycle, shard gating at >=2, Drain Soul priority in execute, auto Healthstone/Soulstone

</details>

<details>
<summary><strong>Warrior</strong></summary>

### Arms
- **Supported:** `Mortal Strike`, `Slam`, `Whirlwind`, `Execute`, `Heroic Strike`, `Cleave`, `Overpower`, `Hamstring`, `Rend`, `Thunder Clap`
- **Unsupported / caveats:** no `Bladestorm`; Overpower dodge proc tracking, Slam weaving timing, Thunder Clap single-target in dungeon/raid, HS disabled during execute

### Fury
- **Supported:** `Bloodthirst`, `Whirlwind`, `Execute`, `Heroic Strike`, `Cleave`, `Sunder Armor`, `Hamstring`, `Slam`, stance tools
- **Optimized:** Duplicate require cleaned (ooc_manager)
- **Unsupported / caveats:** no `Heroic Throw`; Rampage buff maintenance (stacks + duration), HS disabled during execute, Rend/Overpower removed, Flurry-aware Bloodthirst priority

### Protection
- **Supported:** `Shield Slam`, `Revenge`, `Devastate`, `Heroic Strike`, `Cleave`, `Sunder Armor`, `Thunder Clap`, `Shield Block`, stance and taunt tools
- **Optimized:** Stance and burst systems refactored (-528 lines, -14% size, table-driven approach)
- **Unsupported / caveats:** no `Shockwave`, no `Sword and Board`; Shield Block charge tracking, Revenge proc priority, Devastate integration

</details>

---

## Shared Runtime Highlights

- interrupt management
- defensive thresholds
- threat handling
- visual overlays / ESP
- out-of-combat support
- leveling helpers (spell downranking, pull optimization, mana conservation)
- encounter helpers (BigWigs integration, boss awareness)
- reactive runtime / cached context support
- **PvP manager** (enemy targeting, cooldowns, arena/BG logic)
- **Pull optimizer** (trivial target detection, instant-cast-only mode)

---

## Repository Standards

- ✅ ship `.lua`
- ✅ ship `.md`
- ❌ do not ship `.toc`
- ❌ do not ship zip artifacts or temp files
- ❌ do not stage unrelated reference trees when the request is specifically about EAX rotations

---

## Maintenance

This repository is maintained with a **source-first** standard:

1. inspect git state first
2. limit commits to the requested scope
3. keep EAX packages clean (`.lua` + `.md` only)
4. verify deleted `.toc` files stay deleted
5. push only after status/diff review

If you open a new OpenCode session and ask for updates, the session guidance in `AGENTS.md` now tells the agent to run the repo-status checks before touching anything.
