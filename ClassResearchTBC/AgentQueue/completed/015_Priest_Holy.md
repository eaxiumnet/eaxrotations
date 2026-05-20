# Job 015 - Priest Holy

Status: completed
Created: 2026-05-19
Completed: 2026-05-20
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Holy_CHECKLIST.md

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
Assigned spec: Priest Holy

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Priest\Holy\Research.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Priest\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\priest\holy_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\healing_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\priest\schema_sylvanas.lua

Task:
Compare Holy implementation to the Research.md contract and patch missing vetted behavior only. Focus on Flash Heal/Greater Heal triage, Renew, Prayer of Healing, Circle of Healing [34861], Lightwell [724], Prayer of Mending, Guardian Spirit guardrail, dispels, and mana conservation.

Hard rules:
- Guardian Spirit [47788] is DB2 absent. Do not implement it.
- Circle of Healing [34861] and Lightwell [724] are valid TBC Holy spells.
- No Chakra, Serendipity, modern Holy Words, or Mind Sear.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Priest_Holy_CHECKLIST.md

Checklist workflow:
1. Read the existing checklist first if it exists.
2. Compare Research.md against the current EaxRotations files and list each requirement as Present, Missing, Partial, Not applicable, or Blocked.
3. Do not redo items marked Present/Implemented unless the evidence is wrong.
4. Patch only vetted Missing/Partial items.
5. Do not hard-code [VERIFY] rows; mark them Keep configurable or Blocked with the needed evidence.
6. After patching, update the checklist with file/line evidence, tests run, and remaining work.
7. If no vetted Missing/Partial items remain, make no code changes and report that the spec is already aligned.
Run luac -p on touched Lua files and relevant tests if available. Report changed files, behavior improved, tests run, and remaining risk.
```



## Run Results

### Changes Applied

**Pass 1 — DB2 corrections (class_sylvanas.lua):**
- DesperatePrayer: expanded from 1 rank to 8 ranks per DB2 (13908→25437)
- HolyFire: added missing 15261(60), all 9 ranks now match DB2
- PrayerOfHealing: fixed 10961 level from 54 to 60 per DB2

**Pass 2 — Behavioral strategies (holy_sylvanas.lua):**
- Lightwell: CD heal on 3+ injured allies
- Shadowfiend: mana regen CD when mana < 30%
- DispelMagic: dangerous magic dispel on tank/lowest
- CureDisease: disease removal on allies
- AbolishDisease: preventive disease ward on tanks
- ManaBelow5Wand: auto-attack/wand when mana < 5%

**Pass 3 — Code review fix (schema_sylvanas.lua):**
- Added missing `holy_use_lightwell` checkbox to Holy tab

### Validation
- ✅ `luac -p` passes on all 3 modified files + healing_sylvanas.lua
- ✅ Code review cleared (Pass 2 + Pass 3 both reviewed)
- ✅ 32/32 behavioral requirements Present or N/A

### Files Changed
| File | Lines changed |
|---|---|
| class_sylvanas.lua | 3 DB2 corrections |
| holy_sylvanas.lua | ~120 lines (6 new strategies + state tracking) |
| schema_sylvanas.lua | 1 line (holy_use_lightwell key) |
