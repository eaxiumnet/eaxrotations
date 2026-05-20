# Job 026 - Warlock Destruction

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Warlock_Destruction_CHECKLIST.md

## Run Result - 2026-05-20 12:15

**Outcome:** Completed — one patch applied.

**Summary:**
- Compared `Warlock\Destruction\Research.md` (296 lines) against four target implementation files.
- Found one vetted bug: `Conflagrate` spell IDs in `class_sylvanas.lua` had only `{17962}` (rank 1) but DB2 lists 6 ranks: `{17962, 18930, 18931, 18932, 27266, 30912}`.
- Patched `class_sylvanas.lua`: expanded to full 6-rank list with corrected level map.
- All other Research.md requirements are present: Immolate-before-Conflagrate gate, Incinerate-when-Immolate-active gate, Backlash proc handling, Shadowburn execute phase, curse assignment, Life Tap/Dark Pact mana thresholds, Seed/Rain AoE, Soulshatter, Death Coil emergency.
- Forbidden mechanics (Chaos Bolt, Backdraft, Havoc, Ember resource) are absent.
- `luac -p` passed on all modified files.

**Files changed:**
- `EaxRotations/classes/warlock/class_sylvanas.lua` — Conflagrate rank list expanded from 1 to 6 ranks.

**Remaining risk:** None. Spec is fully aligned.


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
Assigned spec: Warlock Destruction

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warlock\Destruction\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warlock\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warlock\destruction_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warlock\schema_sylvanas.lua

Task:
Compare Destruction implementation to the Research.md contract and patch missing vetted behavior only. Focus on Shadow Bolt/Incinerate priority, Immolate before Conflagrate, Shadowburn, curses, Life Tap, pet state, mana tools, and target validity.

Hard rules:
- Chaos Bolt [50796] and Backdraft [54274] are DB2 absent. Do not implement them.
- No Havoc, Ember resource, Soul Fire modern procs, or later-expansion Warlock mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Warlock_Destruction_CHECKLIST.md

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





