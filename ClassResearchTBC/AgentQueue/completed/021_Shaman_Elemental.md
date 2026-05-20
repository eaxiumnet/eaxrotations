# Job 021 - Shaman Elemental

Status: completed
Created: 2026-05-19
Completed: 2026-05-20
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Shaman_Elemental_CHECKLIST.md

## Queue Instructions

This job is consumed by AgentQueue\AGENT_RUNNER.md.

The agent must:
- Move this file to AgentQueue\in_progress\ before code edits.
- Execute only vetted missing/partial work.
- Update the checklist named above.
- Append a run result section to this job.
- Move this file to AgentQueue\completed\ when 100% done.
- Move this file to AgentQueue\blocked\ if evidence/runtime validation is required.

## Run Result — 2026-05-20

### Files Changed (2)

| File | Changes |
|---|---|
| `EaxRotations/classes/shaman/class_sylvanas.lua` | 13 DB2 level corrections: LightningBolt, ChainLightning, EarthShock, FlameShock, FrostShock, LightningShield, WaterShield, Purge, ChainHeal, ManaTideTotem, Bloodlust, EarthbindTotem, ManaSpringTotem, TotemicCall |
| `EaxRotations/classes/shaman/elemental_sylvanas.lua` | ManaEmergencyWand strategy (position 1, mana<5%); mana_emergency gates on 5 early strategies |

### Verification

- ✅ luac -p passes on class_sylvanas.lua, elemental_sylvanas.lua, schema_sylvanas.lua
- ✅ Code review cleared (2 passes)
- ✅ 32/33 behavioral requirements Present; 1 Blocked (totem range — requires engine-level totem range API)

## Original Prompt

```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Shaman Elemental

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Shaman\Elemental\Research.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\shaman\elemental_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\schema_sylvanas.lua

Task:
Compare Elemental implementation to the Research.md contract and patch missing vetted behavior only. Focus on Lightning Bolt, Chain Lightning [25442], Flame Shock refresh, Earth Shock interrupts, Elemental Mastery, totems, mana floors, target validity, and AoE target thresholds.

Hard rules:
- Chain Lightning [25442] has 3 total targets and 0.70 jump amplitude; keep any cluster-radius heuristic configurable.
- No Lava Burst, Thunderstorm, Hex, Wind Shear, or later-expansion Shaman mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Shaman_Elemental_CHECKLIST.md

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






## Recovery - 2026-05-19 14:50

Moved from in_progress back to pending by RECOVER_STALE_IN_PROGRESS.ps1 after 367.6 minutes without heartbeat.
