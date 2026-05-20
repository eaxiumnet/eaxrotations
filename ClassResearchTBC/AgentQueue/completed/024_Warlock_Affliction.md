# Job 024 - Warlock Affliction

Status: completed
Created: 2026-05-19
Completed: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Warlock_Affliction_CHECKLIST.md

## Queue Instructions

This job is consumed by AgentQueue\AGENT_RUNNER.md.

The agent must:
- Move this file to AgentQueue\in_progress\ before code edits.
- Execute only vetted missing/partial work.
- Update the checklist named above.
- Append a run result section to this job.
- Move this file to AgentQueue\completed\ when 100% done.
- Move this file to AgentQueue\blocked\ if evidence/runtime validation is required.

## Prompt

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Warlock Affliction
[prompt truncated for brevity]
```

## Run Result

**Date:** 2026-05-19

**Files changed:** 3

| File | Changes |
|---|---|
| `affliction_sylvanas.lua` | DOT_REFRESH_WINDOW 3.0 → 1.5s (Research Angle 1: clip DoTs at <1.5s) |
| `class_sylvanas.lua` | 18 DB2 level corrections (Corruption, CurseOfAgony, CurseOfDoom, CurseOfTongues, DarkPact, DeathCoil, DrainLife, DrainSoul, Fear, HealthFunnel, Immolate, LifeTap, SeedOfCorruption, ShadowBolt, Shadowburn, SiphonLife, Soulshatter, UnstableAffliction) |
| `schema_sylvanas.lua` | Added Affliction section (Mana Management + Damage subsections, 6 settings); fixed seed_targets min 2→3, life_tap_mana max 100→65 |

**Validations:**
- luac -p: all 3 files pass
- Code review (deepseek): cleared (2 minor fixes applied)

**Behavior improved:**
- DoT clipping reduced (refresh at <1.5s instead of <3.0s) — saves GCDs and mana
- 18 spells now have accurate DB2 level gating — prevents trying to cast spells not yet learned
- 6 Affliction settings now user-configurable via menu instead of hidden code defaults

**Remaining risk:** LOW. All changes are DB2-verified level corrections and one behavioral threshold alignment.
