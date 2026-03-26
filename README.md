# EAX TBC Classic Rotations

> **TBC-targeted** rotation pack for **WoW TBC 2.4.3 / Project Sylvanas** with all **27 playable specs** in one repository.

![TBC 2.4.3](https://img.shields.io/badge/TBC-2.4.3-7c3aed?style=flat-square)
![27 Specs](https://img.shields.io/badge/specs-27-111827?style=flat-square)
![Lua Only](https://img.shields.io/badge/shipping-lua%20%2B%20md-0f766e?style=flat-square)
![No TOC](https://img.shields.io/badge/package-no%20.toc-dd1144?style=flat-square)

---

## Snapshot

- **Coverage:** Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior
- **Packaging rule:** only `.lua` and `.md` files ship in the EAX rotation folders
- **Removed from shipping:** all EAX `.toc` files
- **Scoring model:** usefulness is estimated from `main.lua`, `spells.lua`, helper modules, and visible rotation complexity
- **Important:** these numbers are **not** live raid logs or in-game benchmarks; they are source-based readiness estimates
- **TBC truth:** this repo aims for true TBC behavior, but a few specs still contain leftover non-TBC spell references in source and are explicitly called out below instead of being misrepresented as clean

### Usefulness Matrix

| Class | Spec | Solo | Dungeon | Raid |
|-------|------|:----:|:-------:|:----:|
| Druid | Balance | 74% | 72% | 68% |
| Druid | Feral | 82% | 78% | 73% |
| Druid | Restoration | 65% | 90% | 86% |
| Hunter | Beast Mastery | 86% | 82% | 80% |
| Hunter | Marksmanship | 79% | 76% | 74% |
| Hunter | Survival | 74% | 72% | 70% |
| Mage | Arcane | 72% | 76% | 80% |
| Mage | Fire | 72% | 76% | 78% |
| Mage | Frost | 78% | 82% | 85% |
| Paladin | Holy | 40% | 95% | 90% |
| Paladin | Protection | 52% | 90% | 86% |
| Paladin | Retribution | 80% | 84% | 80% |
| Priest | Discipline | 48% | 78% | 72% |
| Priest | Holy | 45% | 82% | 78% |
| Priest | Shadow | 80% | 76% | 72% |
| Rogue | Assassination | 86% | 84% | 84% |
| Rogue | Combat | 80% | 86% | 80% |
| Rogue | Subtlety | 74% | 70% | 66% |
| Shaman | Elemental | 72% | 72% | 68% |
| Shaman | Enhancement | 80% | 80% | 76% |
| Shaman | Restoration | 66% | 90% | 86% |
| Warlock | Affliction | 86% | 82% | 82% |
| Warlock | Demonology | 74% | 74% | 70% |
| Warlock | Destruction | 80% | 80% | 80% |
| Warrior | Arms | 80% | 76% | 76% |
| Warrior | Fury | 82% | 78% | 74% |
| Warrior | Protection | 55% | 90% | 86% |

> **Reading the scores:** `90-100` = strong fit for that role, `75-89` = very usable, `60-74` = workable with caveats, `<60` = partial or role-mismatched.

---

## What Ships

- `EAX<Class><Spec>/` rotation folders
- `.lua` runtime and rotation files
- `.md` documentation files

### What Does **Not** Ship

- `.toc` files
- zip artifacts
- screenshots / binaries / temp files
- non-EAX reference trees as part of the rotation package

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

## Spec Notes

### TBC Cleanliness Summary

- **Closest to clean TBC behavior:** Holy Paladin, Protection Paladin, Retribution Paladin, Shadow Priest, Elemental Shaman, Enhancement Shaman, Affliction Warlock, Destruction Warlock, Arms Warrior
- **Mostly TBC, but still wants live validation:** Druid specs, Hunter specs, Mage specs, Assassination Rogue, Subtlety Rogue, Restoration Shaman, Demonology Warlock, Protection Warrior
- **Still carrying visible non-TBC leftovers in source:** Marksmanship Hunter utility flags, Discipline Priest, Holy Priest, Combat Rogue, Fury Warrior

<details>
<summary><strong>Druid</strong></summary>

### Balance
- **Supported:** `Moonkin Form`, `Faerie Fire`, `Moonfire`, `Insect Swarm`, `Wrath`, `Starfire`, `Hurricane`, `Force of Nature`, `Innervate`
- **Unsupported / caveats:** no `Starfall`, no `Typhoon`, no `Eclipse`; remaining file references still deserve live validation

### Feral
- **Supported:** `Cat Form`, `Bear Form`, `Dire Bear Form`, `Mangle`, `Rake`, `Shred`, `Rip`, `Ferocious Bite`, `Faerie Fire (Feral)`
- **Unsupported / caveats:** no `Savage Roar`, no `Berserk`; form weaving and edge-case tank/DPS swaps still need live verification

### Restoration
- **Supported:** `Rejuvenation`, `Regrowth`, `Swiftmend`, `Healing Touch`, `Nature's Swiftness`, `Innervate`, `Tranquility`, `Lifebloom`
- **Unsupported / caveats:** no `Wild Growth`, no `Nourish`; stopcast and raid triage behavior are still estimate-only

</details>

<details>
<summary><strong>Hunter</strong></summary>

### Beast Mastery
- **Supported:** `Auto Shot`, `Steady Shot`, `Arcane Shot`, `Aimed Shot`, `Multi-Shot`, `Kill Command`, `Bestial Wrath`, `Intimidation`, `Mend Pet`
- **Unsupported / caveats:** no `Chimera Shot`, no `Explosive Shot`, no `Black Arrow`; pet engagement timing is improved but still should be validated live

### Marksmanship
- **Supported:** `Auto Shot`, `Aimed Shot`, `Arcane Shot`, `Steady Shot`, `Multi-Shot`, `Serpent Sting`, `Scorpid Sting`, `Kill Command`
- **Unsupported / caveats:** no `Chimera Shot`, no `Black Arrow`; source still shows a non-TBC `Silencing Shot` reference, so this spec is not yet fully clean

### Survival
- **Supported:** `Auto Shot`, `Aimed Shot`, `Arcane Shot`, `Steady Shot`, `Multi-Shot`, `Serpent Sting`, `Hunter's Mark`, aspect handling
- **Unsupported / caveats:** no `Explosive Shot`, no `Black Arrow`; trap / utility value is decent but not fully proven in raid logs

</details>

<details>
<summary><strong>Mage</strong></summary>

### Arcane
- **Supported:** `Arcane Blast`, `Arcane Missiles`, `Arcane Power`, `Arcane Explosion`, `Evocation`, `Fire Blast`, `Counterspell`, curse removal
- **Unsupported / caveats:** no `Arcane Barrage`, no `Mirror Image`, no `Focus Magic`; mana cycle quality is solid on paper, not benchmarked here

### Fire
- **Supported:** `Scorch`, `Fireball`, `Pyroblast`, `Combustion`, `Fire Blast`, `Flamestrike`, `Dragon's Breath`, `Blast Wave`, `Mage Armor`
- **Unsupported / caveats:** no `Living Bomb`, no `Hot Streak`; AoE and combustion windows still need in-game pacing checks

### Frost
- **Supported:** `Frostbolt`, `Ice Lance`, `Icy Veins`, `Water Elemental`, `Frost Nova`, `Cone of Cold`, `Ice Barrier`, `Arcane Explosion`
- **Unsupported / caveats:** no `Deep Freeze`, no `Fingers of Frost`, no `Brain Freeze`; strong utility profile, but actual raid throughput remains estimate-based

</details>

<details>
<summary><strong>Paladin</strong></summary>

### Holy
- **Supported:** `Holy Light`, `Flash of Light`, `Holy Shock`, `Lay on Hands`, `Divine Illumination`, `Cleanse`, `Purify`, `Blessing of Light`, `Blessing of Wisdom`, `Blessing of Might`
- **Unsupported / caveats:** no `Beacon of Light`, no `Divine Plea`, no `Word of Glory`; poor solo fit, very strong healer fit

### Protection
- **Supported:** `Avenger's Shield`, `Consecration`, `Judgement`, `Holy Shield`, `Righteous Fury`, `Seal of Righteousness`, `Exorcism`, basic self-heal fallback
- **Unsupported / caveats:** no `Hammer of the Righteous`, no `Shield of the Righteous`, no `Holy Power`; strong dungeon/raid tank shell, weak solo efficiency

### Retribution
- **Supported:** `Seal of Command`, `Seal of Righteousness`, `Seal of Blood`, `Judgement of Wisdom`, `Judgement of the Crusader`, `Crusader Strike`, `Exorcism`, `Consecration`, `Hammer of Wrath`
- **Unsupported / caveats:** no `Divine Storm`, no `Templar's Verdict`, no `Holy Power`; good TBC core, still needs live burst-window validation

</details>

<details>
<summary><strong>Priest</strong></summary>

### Discipline
- **Supported:** `Power Word: Shield`, `Renew`, `Prayer of Mending`, `Power Infusion`, `Pain Suppression`, `Flash Heal`, `Greater Heal`, `Prayer of Healing`, `Fear Ward`
- **Unsupported / caveats:** current files still carry non-TBC references like `Penance` / `Inner Will`; do **not** treat this as fully true-TBC yet

### Holy
- **Supported:** `Renew`, `Greater Heal`, `Prayer of Healing`, `Prayer of Mending`, `Flash Heal`, `Circle of Healing`, `Binding Heal`, `Holy Fire`, `Smite`
- **Unsupported / caveats:** current files still carry non-TBC references like `Divine Hymn` and `Inner Will`; usable healer shell, but not clean enough to claim true-TBC purity

### Shadow
- **Supported:** `Vampiric Touch`, `Shadow Word: Pain`, `Devouring Plague`, `Mind Blast`, `Mind Flay`, `Shadow Word: Death`, `Shadowfiend`, `Silence`, `Vampiric Embrace`
- **Unsupported / caveats:** no `Mind Sear`, no `Dispersion`; mostly solid single-target DoT shell, but raid utility tuning is still only estimated

</details>

<details>
<summary><strong>Rogue</strong></summary>

### Assassination
- **Supported:** `Mutilate`, `Envenom`, `Eviscerate`, `Slice and Dice`, `Rupture`, `Kick`, `Cold Blood`, `Vanish`, `Expose Armor`, poison support
- **Unsupported / caveats:** no `Fan of Knives`; relies on poison state and finisher timing being correct at runtime

### Combat
- **Supported:** `Sinister Strike`, `Slice and Dice`, `Eviscerate`, `Rupture`, `Kick`, `Blade Flurry`, `Adrenaline Rush`, stealth openers, poison support
- **Unsupported / caveats:** current files still carry `Killing Spree`; solid sustained melee shell, but not fully true-TBC yet

### Subtlety
- **Supported:** `Stealth`, `Premeditation`, `Cheap Shot`, `Ambush`, `Backstab`, `Hemorrhage`, `Slice and Dice`, `Rupture`, `Expose Armor`
- **Unsupported / caveats:** no `Shadow Dance`; PvP-flavored utility makes PvE value less stable than Assassination or Combat

</details>

<details>
<summary><strong>Shaman</strong></summary>

### Elemental
- **Supported:** `Lightning Bolt`, `Chain Lightning`, `Flame Shock`, `Elemental Mastery`, `Nature's Swiftness`, `Totem of Wrath`, `Earth Shock`, `Frost Shock`
- **Unsupported / caveats:** no `Lava Burst`, no `Thunderstorm`, no `Wind Shear`; clean TBC spell shell, but mana-floor behavior still needs live proof

### Enhancement
- **Supported:** `Stormstrike`, `Shamanistic Rage`, `Earth Shock`, `Flame Shock`, `Frost Shock`, `Chain Lightning`, `Lightning Bolt`, weapon imbues, totem support
- **Unsupported / caveats:** no `Lava Lash`, no `Feral Spirit`; strong paper rotation, still sensitive to weaving and shock cadence

### Restoration
- **Supported:** `Chain Heal`, `Healing Wave`, `Lesser Healing Wave`, `Earth Shield`, `Mana Tide Totem`, `Healing Stream Totem`, `Wrath of Air Totem`, `Windfury Totem`, `Grounding Totem`, `Tremor Totem`
- **Unsupported / caveats:** no `Riptide`, no `Earthliving Weapon`; strong group-healing fit, but stopcast/totem edge cases remain a known caveat

</details>

<details>
<summary><strong>Warlock</strong></summary>

### Affliction
- **Supported:** `Unstable Affliction`, `Corruption`, `Siphon Life`, `Curse of Agony`, `Curse of Doom`, `Curse of Elements`, `Drain Soul`, `Shadow Bolt`, `Drain Life`
- **Unsupported / caveats:** no `Haunt`; one of the stronger source-based DPS shells in the repo

### Demonology
- **Supported:** `Corruption`, `Immolate`, `Shadow Bolt`, `Soul Fire`, `Shadowfury`, `Shadowburn`, `Drain Soul`, curses, pet-oriented support lanes
- **Unsupported / caveats:** no `Metamorphosis`, no `Immolation Aura`; workable, but less polished than Affliction and Destruction

### Destruction
- **Supported:** `Immolate`, `Shadow Bolt`, `Incinerate`, `Conflagrate`, `Shadowfury`, `Shadowburn`, `Seed of Corruption`, `Soul Fire`, `Hellfire`, `Rain of Fire`
- **Unsupported / caveats:** no `Chaos Bolt`; strong core burst shell, pending live shard / curse validation

</details>

<details>
<summary><strong>Warrior</strong></summary>

### Arms
- **Supported:** `Mortal Strike`, `Slam`, `Whirlwind`, `Execute`, `Heroic Strike`, `Cleave`, `Overpower`, `Hamstring`, `Rend`, `Thunder Clap`
- **Unsupported / caveats:** no `Bladestorm`; strong TBC core, but single-target/AoE switching still needs real combat verification

### Fury
- **Supported:** `Bloodthirst`, `Whirlwind`, `Execute`, `Heroic Strike`, `Cleave`, `Sunder Armor`, `Hamstring`, `Slam`, `Overpower`, stance tools
- **Unsupported / caveats:** current files still carry `Heroic Throw`; powerful shell overall, but still not fully true-TBC yet

### Protection
- **Supported:** `Shield Slam`, `Revenge`, `Devastate`, `Heroic Strike`, `Cleave`, `Sunder Armor`, `Thunder Clap`, `Shield Block`, stance and taunt tools
- **Unsupported / caveats:** no `Shockwave`, no `Sword and Board`; very strong group tank utility, weak solo efficiency

</details>

---

## Shared Runtime Highlights

- interrupt management
- defensive thresholds
- threat handling
- visual overlays / ESP
- out-of-combat support
- leveling helpers
- encounter helpers
- reactive runtime / cached context support

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
