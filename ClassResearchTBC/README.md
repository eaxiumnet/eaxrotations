# TBC Classic Class Research

Research started: 2026-05-17.

This folder is a source-linked research base for World of Warcraft: The Burning Crusade Classic class and specialization mechanics. It is intended to support rotation plugin work, so each document focuses on gameplay rules that can become rotation logic: ability priorities, role behavior, cooldown handling, PvP utility, consumables, set-piece triggers, weapon imbues, seal twisting, totem twisting, powershifting, and similar TBC-specific mechanics.

## Layout

- `Sources.md` - master source index for Wowhead, Icy Veins, Warcraft Tavern, and mechanic-specific pages.
- `Source-Conflict-Register.md` - conflict policy for DB2, guide, sim, local-code, and TBC-version disagreements.
- `Shared/` - cross-class mechanics, consumables, professions, and gear rules.
- `DB2/` - Wago Tools DB2 CSV extracts for TBC Classic Anniversary class skill lines, class spellbook abilities, talents, and filtered spell metadata.
- `<Class>/Abilities-and-Talents.md` - class-level spell, talent, and mechanic index.
- `<Class>/<Spec>/Research.md` - spec-level playstyle research for single target, multi target, healing, tanking, PvP, consumables, gear, and automation notes.

## Spec Coverage

- Druid: Balance, Feral DPS, Bear Tank, Restoration
- Hunter: Beast Mastery, Marksmanship, Survival
- Mage: Arcane, Fire, Frost
- Paladin: Holy, Protection, Retribution
- Priest: Discipline, Holy, Shadow, Smite
- Rogue: Assassination, Combat, Subtlety
- Shaman: Elemental, Enhancement, Restoration
- Warlock: Affliction, Demonology, Destruction
- Warrior: Arms, Fury, Protection

## Research Rules

- Treat Wowhead TBC spell database and talent calculator pages as the source of truth for exact spell ranks, spell IDs, and talent names.
- Treat Icy Veins and Wowhead class guides as playstyle sources, then verify rotation-impacting claims against game data or logs before code changes.
- Do not import WotLK/Cata mechanics into rotation logic. TBC Classic only.
- Mark spec-specific advanced mechanics explicitly, especially if they depend on swing timers, snapshotting, aura timing, or raid assignments.
- For automation, prefer priority rules and state checks over fixed scripts, because TBC rotations are heavily affected by mana, threat, swing timers, and group buffs.

## S+ Research Pass

The S+ execution pass adds:

- `S_PLUS_COVERAGE_TRACKER.csv` - per-spec/category S+ tracker.
- `S_PLUS_SPEC_TEMPLATE.md` - required spec documentation template.
- `S_PLUS_FINAL_AUDIT.md` - final audit table.
- `Source-Conflict-Register.md` - explicit conflict resolution policy and known conflict-prone mechanics.
- Per-class `DB2-Spells.md`, `DB2-Talents.md`, `DB2-Rotation-Relevant-Effects.md`, `Gear-and-Sets.md`, and `Implementation-Notes.md`.
- Shared `Gear-and-Set-Pieces.md`, `PvP-Mechanics.md`, expanded consumable/mechanics docs, and `Encounters/`.
- S+ addenda appended to every spec `Research.md`.

## Total Coverage Pass

The second expansion pass adds:

- `All-Spells-Usage-Index.csv` and `All-Talents-Usage-Index.csv`.
- `All-Spells-and-Talents-Usage.md`.
- `Encounters/All-Dungeons-Deep-Matrix.md`.
- `Encounters/All-Raids-Deep-Matrix.md`.
- `Shared/PvP-Total-Coverage-Matrix.md`.
- `Shared/Healing-Total-Playbook.md`.
- `Shared/Tanking-Total-Playbook.md`.
- `Shared/All-Playstyles-Role-Matrix.md`.
- `TOTAL_COVERAGE_PASS_AUDIT.md`.

## Timing and Niche Mechanics Pass

The third expansion pass adds:

- `All-Spells-Timing-Index.csv` and `All-Spells-Timing-Index.md`.
- Per-class `Spell-Timing-Index.md` files.
- `Pet-Spells-Timing.md`.
- Deep niche mechanics docs for powershifting, seal twisting, totem twisting, Hunter shot timing, Warrior Slam timing, Rogue energy/poisons, Warlock imp machine gun, and healing downrank timing.
- `Shared/All-Niche-Mechanics-Index.md`.

