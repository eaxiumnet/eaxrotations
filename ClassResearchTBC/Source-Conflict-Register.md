# Source Conflict Register

Created: 2026-05-18.

Purpose: record places where DB2 data, TBC 2.4.3 references, TBC Classic Anniversary behavior, guide pages, sims, or local implementation code can disagree.

## Resolution Policy

| Conflict type | Resolution rule |
|---|---|
| Spell ID, rank, class skill line, talent row | Prefer Wago DB2 `wow_anniversary`, then Wowhead/TBCDB/WoWClassicDB cross-checks |
| Set bonus spell ID or item-set mapping | Prefer Wago `ItemSet` and `ItemSetSpell`, with Wowhead/Icy Veins for readable guide context |
| Rotation priority | Prefer sim/log/class-community consensus, then document the implementation choice |
| TBC 2.4.3 vs TBC Classic Anniversary | Document both when behavior differs; target branch is `wow_anniversary` unless code explicitly targets old 2.4.3 |
| Local code vs game source | Treat local code as implementation evidence, not game-data authority |

## Known Conflict-Prone Areas

| Area | Risk | Current decision |
|---|---|---|
| Paladin faction seals | Seal of Blood/Martyr availability can differ by TBC version/ruleset | Spec docs require faction/ruleset detection or configuration before seal twisting |
| Bloodlust/Heroism scope | TBC Anniversary behavior can differ from original TBC group-only assumptions | Docs say use by raid assignment; implementation should not assume scope without branch-specific validation |
| Seal twisting | Timing depends on client/server batching and swing timing | Docs require swing timer and latency-aware state; local Flux/Sonah references are implementation hints |
| Totem twisting | Value depends on group composition, swing timing, and totem pulse behavior | Enhancement docs require assignment and swing/totem timing checks |
| Druid Cat AoE | Later expansions add Cat Swipe, but TBC Cat does not have it | Explicitly forbidden; TBC Cat multi-target is target-swap/single-target focused |
| Priest modern AoE | Mind Sear/modern Holy tools are later-expansion mechanics | Explicitly forbidden; Shadow multi-target is multidot/priority targeting |
| Paladin modern healing | Beacon/Holy Power/Sacred Shield/Divine Plea are not TBC | Explicitly forbidden; Holy uses Flash/Holy Light/Holy Shock/Cleanse tools |
| Shaman Wrath kit | Lava Burst, Riptide, Hex, Wind Shear, Feral Spirit, Maelstrom Weapon are not TBC | Explicitly forbidden; use Earth Shock interrupt, Chain Heal, Earth Shield, totems |
| Warrior Wrath kit | Titan's Grip, Shockwave, Bladestorm, Sword and Board, Heroic Throw are not TBC | Explicitly forbidden; use TBC stance/rage/shield rules |
| Set bonus descriptions | DB2 descriptions may contain unresolved formula placeholders | Keep DB2 spell IDs and descriptions; use Wowhead/Icy Veins for readable confirmation |
| Encounter details | Generic encounter modifiers are complete enough for rotation rules, but boss-by-boss details can be expanded indefinitely | Current docs record S+ modifiers; future boss pages should append exact boss ability timing |

## Open Items

- No unresolved class spell/talent ID conflict is currently blocking rotation research.
- Boss-by-boss encounter pages can be expanded later without changing the S+ spec template.
- If a plugin targets strict private-server 2.4.3 instead of `wow_anniversary`, re-run DB2 checks against that source set and update the affected rows.
