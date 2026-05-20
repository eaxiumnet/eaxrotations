# Job 018 - Rogue Assassination

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Rogue_Assassination_CHECKLIST.md

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
Assigned spec: Rogue Assassination

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Rogue\Assassination\Research.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\rogue\assassination_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\schema_sylvanas.lua

Task:
Compare Assassination implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mutilate [34413] poison/behind gates, Slice and Dice, Rupture/Eviscerate, poisons, energy pooling, cooldowns, interrupts, and target immunity checks.

Hard rules:
- Mutilate [34413] is valid TBC and gains +50% damage against poisoned targets; it requires proper position/poison checks.
- No Envenom if not DB2/ruleset-validated, Fan of Knives, Vendetta, or later-expansion Rogue mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Rogue_Assassination_CHECKLIST.md

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





