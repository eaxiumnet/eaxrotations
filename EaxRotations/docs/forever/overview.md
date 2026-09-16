# World of Warcraft: Forever — Era Overview

> **Status**: PRE-BETA era support (era plumbing + fallback chain live; no
> `_forever` spec files yet). Beta opens **September 17, 2026**; launch
> **November 4, 2026, 3:00 p.m. PST**; first raids unlock **December 9, 2026**.

## What this era is

Blizzard's official Classic+ (BlizzCon 2026): a **new game/client** set in a
reimagined original Azeroth, level cap **60**, horizontal progression ("time
bubble" — new raids/dungeons/quests added without raising the cap). Not a mode,
season, or version of Classic — an evergreen parallel product.

## EAX era contract (how Forever integrates)

| Concern | Decision |
|---|---|
| Expansion key | `"forever"` in `core_sylvanas.lua::_resolve_expansion_key()` |
| Runtime override | `runtime_mode = "forever"` (canonical lowercase only — noncanonical labels like `"WoW Forever"` fail closed, mirroring SoD) |
| Version detection | any version string containing `forever` (checked BEFORE vanilla/classic); refine when the beta build string is known |
| `NS.is_forever()` | true only on Forever |
| `NS.is_vanilla()` | **ALSO true on Forever** — vanilla-superset semantics; the 40 `NS.is_vanilla()` gates in `_vanilla` fallback spec files are production lanes |
| Class loader chain | `_forever → _vanilla` (never falls through to `_sylvanas`/`_wotlk`) |
| Max level | 60 (`NS.get_expansion_max_level()`) |
| Context fields | `context.is_forever`, `context.forever_phase` (schema slider default 1, waves 1–8) |
| Battery | `behavioral_audit.lua forever` runs the vanilla manifest under the Forever harness; **strict, never=0 from day 1** |
| Spell-ID authority | Forever client DBC (see `dbc_runbook.md`) — nothing is real/removed until it resolves there |

**Why fallback-first**: Forever ships all 9 vanilla classes with a familiar
1.12 talent structure. Every existing `_vanilla` rotation is
correct-until-proven-otherwise the moment the era resolves. `_forever` delta
files are added ONLY where the kit actually changed (Paladin first — the only
fully-revealed class).

## Confirmed mechanics that affect rotations (with sources)

### Talents
- Familiar 1.12 structure, same row count; milestone talents at 11/21/31 points
  **plus a new 16-point milestone**.
- **Baseline for all classes**: Divine Spirit, Blessing of Kings, Improved
  Mark of the Wild (the key-buff talents).
- Tuning goal: "every single talent tree should be a viable option for
  dungeons or raids."

### Racials
- Every race: **2 active + 2 passive**, retuned for similar offensive power
  while keeping signature utility.
- Examples: Dwarf Stoneform → removes/grants immunity to Bleeds/Poisons/
  Diseases and reduces **Physical damage taken** (no longer armor); Mace
  Specialization → crit with all spells/abilities while a mace is equipped;
  Undead Cannibalize restores **mana as well as health**; new **Touch of the
  Grave** (attacks may drain life); Will of the Forsaken no longer grants
  immunity.
- **Six new race/class combos**: Gnome Priest, Human Hunter, Dwarf Shaman,
  Orc Mage, Troll Warlock, Undead Paladin.
- **New race: Skyborne** — Horde-aligned: Shaman; Alliance-aligned: Mage;
  both: Warrior, Hunter, Rogue, Druid (new druid forms). Starting experience
  on Zephras Isle (levels 1–12).

### Stat system ("unsolving" the game)
- **Merged hit** (spell/melee/ranged) and **merged crit** (spell/melee/ranged).
- **Bonus healing now grants ⅓ as bonus spell damage** (healers questing/soloing).
- Weapon skill still exists but items grant less per item.
- New stats: parry/dodge-reduction on some items; caster weapons with spell
  damage; biome- and creature-type-conditional item effects.

### Combat pacing
- Solo mob kill ~10–15s; CC (Polymorph/Banish/Fear/Root) stays relevant in
  dungeons; threat management emphasized. Rotation pacing stays Classic-like —
  the TBC-era EAX engine assumptions carry over.

### Paladin (only fully-revealed class — see `kits/paladin.md`)
Class-wide: **Holy Strike** (level 6, instant, 12s CD, Holy damage weapon
strike); **Judgment no longer consumes the seal**; **Seal of Fury** (tank seal,
fast weapons, absorbs, Judgment = taunt); **Consecration baseline at level 20**
(front-loaded threat on first 4 targets). Holy: Infusion of Light, Holy Shock
10s CD, Light's Vigil, Voice of Truth, Reverence (mana-from-Spirit while
casting). Protection: Templar's Bulwark, redesigned Reckoning (block-triggered),
Swift Judgment, Shield Specialization, Iron Creed. Retribution: Twist of Light
(seal-twist echo without swing-timer addon), Sacred Arbiter, Vindication
redesign, Champion of the Light, Instrument of the Law.
**Preserved weaknesses**: no interrupt, no slows, Seal/Judgment-mediated taunt.

### Addons & data visibility (MMORPG.com BlizzCon interview, 2026-09-16)
- **Addon policy**: "broadly takes cues from modern WoW, with adjustments
  based on feedback" — i.e., Retail-style combat-add-on restrictions are the
  stated direction, but not itemized yet. **For EAX this is a launch-risk
  register entry, not a code change**: Project Sylvanas reads game memory
  directly (no WoW add-on API), so a client add-on crackdown does not
  constrain the runtime — the open question is whether Forever clients ship
  new integrity checks that affect any external tooling. Watch on beta day.
- **First-seen item stat hiding**: item stats hidden until discovered on the
  realm; no Dungeon Journal at first; secrets scattered in the world. Docs/
  data pipeline impact only: the `wowhead_data/` mirror may lag launch
  discovery; never treat scraped item stats as pre-verified — DBC rules.
- **Built-in damage meter + planned cooldown manager**: neutral-to-good —
  validates our CD-tracking lane shapes; no EAX action required.
- **Bank ~96 slots** (tentative), class quests ported/expanded from SoD,
  camping fixtures ~10 min (tentative), campfire-nearby buff (see Camping
  below).

### Legacy system (account perk tree — see `legacy_perks.md`)
16-point account-wide perk tree (21 perks, beta-captured tooltips). Mostly
economy/XP QoL, but **three perks touch our code paths** and are flagged for
beta verification: **Reagent Economy** (class abilities reagent-free → cast
guard's reagent lane), **Field Medicine** (Recently Bandaged −5s → bandage
cadence), **Permanence** (extends eligible long class buffs → refresh
thresholds). No runtime wiring until beta data confirms the effects.

### Camping (future rotation-relevant note)
Campsite objects grant 1-hour buffs that are **variants of class buffs and do
not stack with them** — buff-allowlisting logic must account for them post-launch.

## Sources

| Source | URL | Accessed |
|---|---|---|
| Blizzard "What's Next" panel recap | https://news.blizzard.com/en-us/article/24303862/world-of-warcraft-forever-whats-next-panel-recap | 2026-09-15 |
| Blizzard "Deep Dive" panel recap (combat/classes/stats/racials) | https://news.blizzard.com/en-us/article/24303313/world-of-warcraft-forever-deep-dive-panel-recap | 2026-09-15 |
| Wowhead Forever hub (dedicated subdomain; liveblog + database) | https://www.wowhead.com/forever/ | 2026-09-15 |
| Massively Overpowered Deep-Dive report | https://massivelyop.com/2026/09/13/blizzcon-2026-world-of-warfores-deep-dive-panel-talks-group-play-progression-and-item-updates/ | 2026-09-15 |
| Windows Central overview | https://www.windowscentral.com/gaming/blizzard/world-of-warcraft-forever-is-blizzards-take-on-classic-revamping-vanilla-azeroth | 2026-09-15 |
| Classic WoW Forever — Legacy perk reference (community; beta-captured tooltips) | https://classicwowforever.com/legacy/ | 2026-09-15 |
| Icy Veins — Forever talent calculator (7-row trees, 51 points, Zierhut: 4th gold-medal slot at 16 points; beta "Thursday") | https://www.icy-veins.com/wow-forever/news/start-planning-your-wow-forever-character-with-our-new-talent-calculator/ | 2026-09-16 |
| MMORPG.com BlizzCon interview via Icy Veins (Greenfield/Parrott: addon policy, hidden item stats, damage meter, bank ~96, class quests) | https://www.icy-veins.com/wow-forever/news/brand-new-interview-reveals-strict-addon-policy-hidden-item-stats-and-new-camping-details/ | 2026-09-16 |

Scrape targets as content lands (mirror per the wowheadScrape pipeline):
`wowhead.com/forever/spell={id}`, Icy Veins Forever class guides
(`icy-veins.com/wow-forever/`), and the official class-identity video/article
series Blizzard promised ("more class and race details ... through future
videos and articles").

## Build sequence (status)

| Phase | Deliverable | Status |
|---|---|---|
| 1 | Era plumbing: expansion key, `is_forever`, superset `is_vanilla`, loader chain, schema/context hook, bootstrap + loader suites | **DONE (pre-beta)** |
| 2 | Research corpus (this dir, incl. `legacy_perks.md`) + DBC runbook + forever spell audit scaffold | **IN PROGRESS** |
| 3 | Beta-day: DBC extraction → `wowhead_data_bridge_spell_index_forever_sylvanas.lua` → audit goes live | Blocked on 2026-09-17 |
| 4 | `_forever` spec deltas: paladin (ret/prot/holy/leveling) first, then other classes as kits are revealed | Blocked on reveals + DBC |
| 5 | Racial manager Forever tables (new actives/passives + race/class combos incl. Skyborne), merged hit/crit, ⅓ healing→damage, talent baseline | Post-beta, per-domain commits |

## Out of scope until launch data exists
New dungeon/raid encounter logic, camping-buff stacking rules, Darkspear Islands BG
logic, Skyborne starting-zone automation. Legacy-system RUNTIME integration also
stays out of scope until beta data exists — the perk reference (`legacy_perks.md`)
flags the three perks that touch our code paths for beta verification: Reagent
Economy (cast-guard reagent lane), Field Medicine (bandage cadence), Permanence
(long-buff refresh thresholds).
