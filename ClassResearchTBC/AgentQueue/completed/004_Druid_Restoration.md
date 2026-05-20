# Job 004 - Druid Restoration

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Restoration_CHECKLIST.md

## Queue Instructions

This job is consumed by AgentQueue\AGENT_RUNNER.md.

The agent must:
- Move this file to AgentQueue\in_progress\ before code edits.
- Execute only vetted missing/partial work.
- Update the checklist named above.
- Append a run result section to this job.
- Move this file to AgentQueue\completed\ when 100% done.
- Move this file to AgentQueue\blocked\ if evidence/runtime validation is required.

## Prompt```

## Run Result (2026-05-19)

**Files changed**: 2
- `EaxRotations/classes/druid/resto_sylvanas.lua` — 5 behavioral fixes
- `EaxRotations/classes/druid/schema_sylvanas.lua` — 2 new setting sections

**Behavior improved**:
1. Regrowth suppressed at mana_conserve (≤ 30%) instead of mana_critical (≤ 5%)
2. Rejuvenation (Priority + Moving) suppressed at mana_emergency (≤ 15%) instead of mana_critical (≤ 5%)
3. Innervate healer threshold now uses configurable `resto_innervate_mana + 5`
4. Mana conservation thresholds now read from schema settings (wired to build_state)
5. MovingRejuvenation now respects mana_emergency gate (was missing)

**Tests run**:
- ✅ `luac -p` passes on resto_sylvanas.lua and schema_sylvanas.lua
- ✅ `test_restoration_healing_way` — PASS (24 strategies, 2 FrostByte gaps closed)
- ✅ `code-reviewer-deepseek` — 2 issues found and fixed (MovingRejuvenation gate, dead schema settings)

**DB2 verified**: All spell ID tables, cooldowns, and levels confirmed correct. Nourish [50464] confirmed absent.

**Remaining risk**: Low. Tranquility default target count (3) is below Research-recommended 5 — intentionally user-configurable. Boss encounter modifiers not yet wired (out of scope).
text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Druid Restoration

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Restoration\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\resto_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare Restoration implementation to the Research.md contract and patch missing vetted behavior only. Focus on Lifebloom bloom/refresh logic, Rejuvenation, Regrowth, Swiftmend, Nature's Swiftness, emergency triage, Clearcasting, decurse/utility, mana conservation, and target selection.

Hard rules:
- Nourish [50464] is DB2 absent. Do not implement it.
- No Wild Growth, Efflorescence, Tree modern behavior, or later-expansion healing mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Restoration_CHECKLIST.md

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





