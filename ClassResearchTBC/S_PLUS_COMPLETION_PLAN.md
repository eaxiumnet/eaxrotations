# S+ Completion Plan

Created: 2026-05-18.

Goal: raise `ClassResearchTBC` from a broad research base to an S+ reference set for TBC Classic class rotation work. In this plan, S+ means the docs are complete enough that a developer can implement or audit a Project Sylvanas rotation without needing to rediscover core class mechanics, spell IDs, talents, set bonuses, consumables, or encounter-specific exceptions.

## Current Baseline

- 29 spec research files exist.
- 9 class ability and talent index files exist.
- Shared mechanics and consumables docs exist.
- Source index exists.
- Flux, Sonah, and SlyRotate local references have been checked.
- DB2 extracts exist for class skill lines, class ability rows, talents, spell levels, spell power, cooldowns, categories, class options, and effects.

Main gaps:

- Mob, boss, dungeon, raid, and encounter behavior is underdocumented.
- Set pieces and gear are not yet phase-by-phase or rotation-impact mapped.
- Spell and talent data exists in CSV form, but not all of it has been converted into readable per-class/per-spec tables.
- PvP guidance is practical but not matchup-grade.
- Multi-target guidance needs target-count thresholds, threat rules, CC risk, and pack-type handling.
- Healing and tanking need more concrete decision tables.

## S+ Definition

A section is S+ only when it satisfies all of these:

- Exact TBC spell/talent IDs are present where relevant.
- The gameplay rule is written as a condition, priority, threshold, exception, or decision table.
- The section has source support from at least one primary or database-backed source, and guide/log/sim sources where applicable.
- TBC-only guardrails are explicit when later-expansion mechanics are easy to confuse with TBC.
- The research is actionable for rotation logic, not just descriptive.

## Workstream 1: Coverage Rubric and Tracker

Create a tracker at `ClassResearchTBC/S_PLUS_COVERAGE_TRACKER.csv`.

Columns:

- `Class`
- `Spec`
- `SingleTarget`
- `MultiTarget`
- `Healing`
- `Tanking`
- `PvP`
- `Spells`
- `Talents`
- `Consumables`
- `GearSets`
- `MobsEncounters`
- `LocalRefs`
- `DB2Verified`
- `SourceLinks`
- `Grade`
- `Notes`

Acceptance criteria:

- Every one of the 29 specs has one row.
- Every category has a grade and short gap note.
- The tracker is updated after each pass.

## Workstream 2: DB2-to-Readable Expansion

Use the existing DB2 CSVs to generate readable class appendices.

Outputs:

- `ClassResearchTBC/<Class>/DB2-Spells.md`
- `ClassResearchTBC/<Class>/DB2-Talents.md`
- `ClassResearchTBC/<Class>/DB2-Rotation-Relevant-Effects.md`

Spell tables should include:

- Spell ID
- Spell name
- Skill line
- Level or base level when available
- Power cost
- Cooldown/GCD/category when available
- Effect/aura summary when useful
- Rotation relevance: `core`, `conditional`, `utility`, `pvp`, `rank-only`, `ignore`

Talent tables should include:

- Talent tree
- Row/column
- Rank spell IDs
- Talent name
- Prerequisite when present
- Rotation impact
- Build relevance by spec

Acceptance criteria:

- Every class has DB2-backed spell and talent docs.
- Every spec doc links to the class DB2 docs.
- Major rotation spells and talents are cross-checked against DB2 IDs.

## Workstream 3: Spec S+ Rewrite Pass

Upgrade each `Research.md` into a consistent spec playbook.

Required sections per DPS spec:

- Role summary
- Talent builds and variants
- Core stats and caps
- Spell table with IDs
- Single-target priority
- Opener
- Execute or burn phase if applicable
- Multi-target and AoE matrix
- Cooldown usage
- Resource management
- Threat management
- Utility and interrupts
- PvP playstyle
- Consumables
- Gear and set bonuses
- Encounter and mob modifiers
- Automation rules
- Source notes

Required sections per healer spec:

- Role summary
- Talent builds and variants
- Spell table with IDs and ranks
- Downranking table
- Tank-healing priority
- Raid-healing priority
- Emergency cooldown usage
- Mana rules
- Dispel/cleanse rules
- PvP healing
- Consumables
- Gear and set bonuses
- Encounter modifiers
- Automation rules
- Source notes

Required sections per tank spec:

- Role summary
- Talent builds and variants
- Spell table with IDs
- Pull/opening threat
- Single-target threat priority
- Multi-target threat priority
- Taunt and recovery rules
- Defensive cooldown table
- Resource management
- Threat lead and snap threat rules
- PvP/tank utility
- Consumables
- Gear and set bonuses
- Encounter and mob modifiers
- Automation rules
- Source notes

Acceptance criteria:

- Every spec has all relevant sections.
- Every priority is written in implementable order.
- Every advanced mechanic has timing, threshold, and failure-case notes.

## Workstream 4: Single-Target and Multi-Target Matrices

Add compact decision tables to every spec.

Single-target matrix:

- Normal priority
- Low mana/low resource priority
- High threat priority
- Movement priority
- Cooldown/burst priority
- Execute phase where relevant

Multi-target matrix:

- 2 targets
- 3 targets
- 4+ targets
- Sustained AoE
- Short-lived adds
- CC-sensitive packs
- Threat-sensitive packs

Acceptance criteria:

- Every DPS/tank spec has target-count rules.
- Every healer spec has single-target tank healing and multi-target raid healing tables.
- AoE spells include minimum target count and threat caveats.

## Workstream 5: Gear, Set Pieces, and Phase Tables

Create gear and set-piece research that explains behavior, not just lists names.

Outputs:

- `ClassResearchTBC/Shared/Gear-and-Set-Pieces.md`
- `ClassResearchTBC/<Class>/Gear-and-Sets.md`
- Optional spec-level `Gear-and-Sets.md` where a class has very different specs.

Each gear/set section should include:

- Tier sets and major set bonuses.
- Dungeon/pre-raid sets if relevant.
- PvP sets where relevant.
- Phase-by-phase important pieces.
- Trinkets with use conditions.
- Weapon speed/type rules.
- Meta gem and enchant notes.
- Rotation impact from set bonuses.

Acceptance criteria:

- Every class has set-piece coverage.
- Every spec doc states which set bonuses change rotation behavior.
- Gear notes separate survival, throughput, threat, and PvP priorities.

## Workstream 6: Consumables, Professions, Imbues, and Temporary Buffs

Upgrade consumable and temporary-buff docs into per-role decision tables.

Outputs:

- Expand `Shared/Consumables-and-Professions.md`.
- Add per-spec consumable tables inside each `Research.md`.

Coverage:

- Flask/elixir choice.
- Food.
- Weapon oils, stones, poisons, imbues.
- Potions.
- Drums.
- Engineering items.
- Mana consumables.
- Resistance consumables.
- Class-specific temporary buffs.

Acceptance criteria:

- Every spec has best/default/budget consumable options.
- Imbues, poisons, oils, sharpening stones, seals, and totems are separated by class/spec.
- Rules mention conflicts and non-stacking where relevant.

## Workstream 7: Mobs, Bosses, Dungeons, and Raids

This is the largest gap and needs a dedicated new research tree.

Create:

- `ClassResearchTBC/Encounters/README.md`
- `ClassResearchTBC/Encounters/Dungeons.md`
- `ClassResearchTBC/Encounters/Raids.md`
- `ClassResearchTBC/Encounters/Mob-Behavior.md`
- `ClassResearchTBC/Encounters/Resistance-and-Immunity-Notes.md`

Coverage:

- Dungeon and raid boss mechanics that affect rotation.
- Common trash mob behavior: casters, healers, runners, cleavers, fear mobs, poison/disease/magic/curse users.
- Interrupt priorities.
- Dispel/cleanse priorities.
- Resist or immunity notes.
- Threat-sensitive encounters.
- Movement-heavy encounters.
- Add waves and AoE windows.
- Tank swap or taunt-sensitive fights.

Acceptance criteria:

- Every spec has encounter modifier notes linked from its `Research.md`.
- Every tank/healer spec has boss/trash decision rules.
- DPS specs call out fights where normal priority changes.

## Workstream 8: PvP S+ Pass

Upgrade PvP from general notes to matchup-aware rules.

Outputs:

- `ClassResearchTBC/Shared/PvP-Mechanics.md`
- Per-class PvP sections expanded in `Abilities-and-Talents.md`.
- Per-spec PvP tables in `Research.md`.

Coverage:

- Arena role by spec.
- Common comps.
- Matchup priorities by enemy class.
- Burst windows.
- Defensive response table.
- CC, interrupts, dispels, and DR awareness.
- Anti-kite and anti-caster rules.
- PvP consumables and gear.

Acceptance criteria:

- Every spec has PvP use cases even if the spec is niche.
- PvP rules are implementable as conditions where possible.
- Sonah PvP/local references are linked where useful.

## Workstream 9: Local-Code Cross-Reference

Mine local rotation sources for implementation patterns.

Sources:

- `flux/`
- `Sonah/`
- `SlyRotate/`
- Current `EAX<Class><Spec>/` plugins

Outputs:

- Add `Implementation-Notes.md` per class.
- Add spec-level `Automation rules` sections with local reference notes.

Coverage:

- Existing priority logic.
- Swing-timer handling.
- Seal twisting.
- Totem twisting.
- Powershifting.
- Pet handling.
- Defensive and burst managers.
- PvP utility toggles.
- Cooldown/trinket handling.

Acceptance criteria:

- Every spec has at least one local implementation cross-reference where available.
- Rotation research distinguishes game truth from local implementation choices.

## Workstream 10: Source Validation and Conflict Resolution

Maintain a strict source policy.

Primary/databased sources:

- Wago Tools DB2 exports.
- Wowhead TBC database and guides.
- TBCDB / WoWClassicDB.
- WoW.tools where useful.
- AzerothCore/TrinityCore schema references for DB interpretation only.

Secondary gameplay sources:

- Icy Veins.
- Warcraft Tavern.
- WoWSims TBC.
- TBC.TXT.
- TBCBIS.
- Timeless Azeroth.
- Scarmonit.

Conflict rules:

- If spell IDs/ranks conflict, DB2/Wowhead/TBCDB take priority.
- If rotation priority conflicts, prefer sim/log-supported or class-community consensus, then document the disagreement.
- If a mechanic differs between TBC 2.4.3 and TBC Classic Anniversary, document both and mark which one applies to the target branch.

Acceptance criteria:

- Every doc has a source notes section.
- Every unresolved conflict is listed explicitly.
- No WotLK/Cata mechanic is left unmarked in a TBC doc.

## Workstream 11: Final S+ Audit

Run a final audit after all expansion passes.

Audit checks:

- No spec missing required sections.
- No class missing DB2 spell/talent docs.
- No role missing consumable and gear notes.
- No tank/healer missing encounter rules.
- No melee spec missing weapon/swing rules.
- No Paladin spec missing seal/judgement notes.
- No Shaman spec missing totem/imbue notes.
- No Druid spec missing form/powershift notes where relevant.
- No Hunter/Warlock spec missing pet notes.
- No Rogue spec missing poison/energy/combo point notes.
- No Warrior spec missing rage/stance/threat notes.
- Source index updated.
- Coverage tracker grades all S+.

## Execution Order

1. Create the coverage tracker and spec template.
2. Generate DB2-readable spell/talent/effect docs for each class.
3. Upgrade shared mechanics, consumables, gear, PvP, and encounters.
4. Rewrite each class ability/talent file with DB2 links and local implementation notes.
5. Rewrite all 29 spec research files to the S+ template.
6. Add encounter modifiers back into each spec.
7. Run the final audit and update the tracker to S+ only where the acceptance criteria are actually met.

## Priority Order for Spec Passes

First pass should prioritize specs with high mechanic complexity:

1. Paladin Retribution, Protection, Holy
2. Shaman Enhancement, Restoration, Elemental
3. Druid Feral DPS, Bear Tank, Restoration, Balance
4. Hunter BM, MM, Survival
5. Warlock Affliction, Demonology, Destruction
6. Warrior Protection, Fury, Arms
7. Rogue Combat, Assassination, Subtlety
8. Priest Holy, Discipline, Shadow, Smite
9. Mage Arcane, Fire, Frost

Reason: Paladin, Shaman, Druid, Hunter, and Warlock have the highest number of class-specific external systems such as seals, totems, forms, pets, imbues, swing timers, and twisting/snapshot-like behavior.

## Done Criteria

The research set is S+ when:

- The coverage tracker grades every category S+ for every spec.
- Every spec document has implementable priority tables.
- Every class has DB2-backed spell and talent appendices.
- Gear and set bonuses are mapped to rotation impact.
- Consumables are role/spec-specific.
- Encounter and mob behavior exists and is linked into spec docs.
- PvP has matchup-aware rules.
- Sources are current, linked, and conflict-noted.
- The docs are usable as direct input for EAX rotation plugin changes.
