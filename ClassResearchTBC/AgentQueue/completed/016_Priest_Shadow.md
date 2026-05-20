# Job 016 - Priest Shadow

Status: complete
Created: 2026-05-19
Completed: 2026-05-20
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Shadow_CHECKLIST.md

## Run Result (2026-05-20)

**3 files changed** across 2 passes:

| File | Changes |
|---|---|
| `class_sylvanas.lua` | 6 DB2 level corrections: MindBlast (11 ranks), MindFlay (7 ranks), ShadowWordPain (10 ranks), VampiricTouch (3 ranks), DevouringPlague (7 ranks), Starshards (8 ranks) |
| `shadow_sylvanas.lua` | SILENCE_ACTION uses SPELLS.Silence (consistency); ManaBelow5Wand strategy for mana<5% auto-attack/wand |
| schema_sylvanas.lua | No changes needed (14 settings already comprehensive) |

- ✅ `luac -p` passes | ✅ Code review Pass 2 clear
- ✅ 22/22 behavioral requirements Present
- ✅ 6/6 DB2 corrections verified

## Original Prompt
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Shadow_CHECKLIST.md

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
Assigned spec: Priest Shadow

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Shadow\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\shadow_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Shadow implementation to the Research.md contract and patch missing vetted behavior only. Focus on Vampiric Touch, Shadow Word: Pain, Mind Blast, Mind Flay, Shadow Word: Death safety, Shadow Weaving, mana support, interrupts/silence if valid, and multi-dot target gating.

Hard rules:
- Dispersion [47585] is DB2 absent. Do not implement it.
- No Mind Sear, Devouring Plague for non-valid race/ruleset if not already supported, Shadow Orbs, or later-expansion Shadow mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Shadow_CHECKLIST.md

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





