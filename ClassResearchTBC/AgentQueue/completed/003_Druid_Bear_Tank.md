# Job 003 - Druid Bear Tank

Status: completed
Heartbeat: 2026-05-19 20:00
Completed: 2026-05-19
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Bear_Tank_CHECKLIST.md

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
Assigned spec: Druid Bear Tank

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Bear-Tank\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\bear_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare Bear implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mangle (Bear), Lacerate, Maul rage dump, Swipe target-count and CC gates, Demoralizing Roar, Faerie Fire (Feral), defensive cooldowns, threat, and form checks.

Hard rules:
- Do not hard-code runtime taunt/form-swap assumptions marked for Sylvanas validation.
- No Cat Swipe, Berserk, Savage Defense, Thrash, or later-expansion tank mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Bear_Tank_CHECKLIST.md

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
## Run Result

**Date**: 2026-05-19
**Outcome**: All vetted Missing/Partial items patched.

### Files Changed

| File | Changes |
|---|---|
| `EaxRotations/classes/druid/class_sylvanas.lua` | 5 DB2 fixes: SwipeBear +3 ranks (769,780,9754), FrenziedRegeneration +3 ranks (22895,22896,26999) + cooldown 180→0, MangleBear levels 70/64→68/58/50, Maul levels corrected to 8-rank DB2 set |
| `EaxRotations/classes/druid/bear_sylvanas.lua` | 3 behavioral fixes: CC gate (`has_breakable_cc_nearby` on Swipe), RAGE_MANGLE_RESERVE 15→20, maul_rage default 50→40 |

### Behavior Improved

- **SwipeBear**: All 6 DB2 ranks now resolve correctly (was missing 769, 780, 9754)
- **FrenziedRegeneration**: All 4 castable ranks now resolve; cooldown 0 (TBC toggle, not WotLK 3min CD)
- **MangleBear**: Level values now match DB2 (68/58/50, not 70/64)
- **Maul**: 8-rank DB2 mapping with correct levels (was missing 1 level entry)
- **CC safety**: Swipe now gates on `has_breakable_cc_nearby` per Research: "avoid Swipe near controlled targets"
- **Rage efficiency**: Mangle reserve 20 rage (was 15), Maul queue at 40+ (was 50) — both aligned with Research Angle 4

### Tests Run

- `luac -p EaxRotations/classes/druid/bear_sylvanas.lua` — PASS
- `luac -p EaxRotations/classes/druid/class_sylvanas.lua` — PASS
- No spec-specific tests exist for Bear Tank

### Remaining Risk

- **Low**: FrenziedRegeneration cooldown=0 is TBC-accurate; match function uses buff detection anyway
- **Medium**: No Bear-specific unit tests; rage threshold changes untested at runtime
- **None**: All spell IDs DB2-verified; all Research contract items marked Present in checklist

### Checklist

`ClassResearchTBC/ImplementationChecklists/Druid_Bear_Tank_CHECKLIST.md` — created with full DB2 verification, behavioral alignment, API validation, and risk assessment.



