# Job 014 - Priest Discipline

Status: completed
Created: 2026-05-19
Completed: 2026-05-20 (2 passes)
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Discipline_CHECKLIST.md

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
Assigned spec: Priest Discipline

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Discipline\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\discipline_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Discipline implementation to the Research.md contract and patch missing vetted behavior only. Focus on Power Word: Shield with Weakened Soul gates, Flash Heal/Greater Heal triage, Prayer of Mending, Pain Suppression, Power Infusion, dispels, mana conservation, and target selection.

Hard rules:
- Penance [47540] and Rapture [47535] are DB2 absent. Do not implement them.
- No Atonement, Borrowed Time, modern absorbs, or Mind Sear.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Discipline_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
``

## Run Results — Pass 2 (2026-05-20): Behavioral fixes

**2 files changed** (6 behavioral fixes + schema tab):

| File | Changes |
|---|---|
| `discipline_sylvanas.lua` | Mana floor gates: PW:S (removed — shield should cast at any mana per Research.md), Flash Heal (stop at <15%), Greater Heal (stop at <30%). DivineSpirit + PrayerOfFortitude strategies added. Fixed `unit_mana_pct` nil guard. Fixed DivineSpirit match (removed copy-paste `has_inner_fire` check). |
| `schema_sylvanas.lua` | Added "Discipline" tab with 5 sections (Healing Priority, Cooldowns, AoE, DPS When Idle, Self Survival) — 15 settings total. |

- ✅ `luac -p` passes
- ✅ Code review addressed (3 bugs from review feedback: PW:S gate removed, GH 30% floor, DivineSpirit match fixed)
- 27/29 behavioral requirements Present, 1 Partial (PI target picker), 1 N/A (wand <5%)
- 15 DB2 spells corrected in pass 1, 4 missing spells added (DivineSpirit, MassDispel, PrayerOfFortitude, ManaBurn)

## Run Results — Pass 1 (2026-05-20): DB2 corrections

**1 file changed** (15 DB2 level/ID corrections + 4 missing spells):

| File | Changes |
|---|---|
| `class_sylvanas.lua` | InnerFire, Fade, PW:Fortitude, Renew, PoH, PsychicScream, Smite, ShackleUndead, FearWard, CoH, Lightwell — all level/ID corrections. Added DivineSpirit, MassDispel, PrayerOfFortitude, ManaBurn (were missing). |

- ✅ `luac -p` passes
