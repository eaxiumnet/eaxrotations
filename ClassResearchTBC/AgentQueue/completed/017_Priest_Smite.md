# Job 017 - Priest Smite

Status: complete
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Smite_CHECKLIST.md

## Queue Instructions

## Run Result

**Completed**: 2026-05-20

### Files changed (3):

| File | Changes |
|---|---|
| `class_sylvanas.lua` | Added PowerInfusion spell {10060, lvl40, 180s CD}. Fixed HolyNova levels (70,64,58... → 68,68,60,52,44,60,52,44,36,28,20). |
| `smite_sylvanas.lua` | Added PowerInfusion burst strategy [3.5] (gates on smite_use_power_infusion, no mana_emergency, pairs with HF). |
| `schema_sylvanas.lua` | Added `smite_use_power_infusion` checkbox to DPS Priority section. |

### Validation:
- ✅ `luac -p` passes (all 3 files)
- ✅ Code review cleared
- ✅ 20/22 behavioral requirements Present
- ⚠️ 1 Partial (Smite downrank at 30%), 1 Missing (fire immune target check — rare edge case)

## Prompt

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Priest Smite

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Smite\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\smite_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Smite implementation to the Research.md contract and patch missing vetted behavior only. Focus on Smite/Holy Fire priority, Shadow Word: Pain if documented, Inner Fire maintenance, Power Word: Shield safety, wand/mana fallback, emergency self-heal, and target validity.

Hard rules:
- Penance [47540] is DB2 absent. Do not implement it.
- No Atonement, Chakra, Mind Sear, or later-expansion Priest mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Smite_CHECKLIST.md

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





