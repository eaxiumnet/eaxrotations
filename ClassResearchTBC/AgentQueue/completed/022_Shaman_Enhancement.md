# Job 022 - Shaman Enhancement

Status: completed
Created: 2026-05-19
Completed: 2026-05-20
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Shaman_Enhancement_CHECKLIST.md

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
| `EaxRotations/classes/shaman/class_sylvanas.lua` | 4 DB2 level corrections: GraceOfAirTotem (60,56,42), Stormstrike (40), LesserHealingWave (66,60,52,44,36,28,20), RockbiterWeapon (70,62,54,44,34,24,16,8,1) |
| `EaxRotations/classes/shaman/enhancement_sylvanas.lua` | Added ManaEmergencyWand strategy at position 0 (mana<10% auto-attack only); added mana_emergency gate to Stormstrike |

- ✅ `luac -p` passes | ✅ Code review cleared
- ✅ 23/24 behavioral requirements Present | ⚠️ 1 Partial (weapon sync, pre-existing)
- ✅ 4/4 DB2 corrections verified | ✅ 35/35 schema keys verified


```text
You are improving EaxRotations for TBC Classic.
Working root: C:\newbot\scripts
Assigned spec: Shaman Enhancement

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Shaman\Enhancement\Research.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Shaman\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\shaman\enhancement_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\shaman\schema_sylvanas.lua

Task:
Compare Enhancement implementation to the Research.md contract and patch missing vetted behavior only. Focus on Stormstrike, shocks, Shamanistic Rage [30823], weapon imbues, Windfury/Grace of Air totems, totem twisting, mana, target validity, and melee uptime.

Hard rules:
- Grace of Air Totem [10627] is rank 2; max TBC rank is [25359]. Resolve ranks [8835/10627/25359].
- No Feral Spirit, Maelstrom Weapon, Lava Lash, Wind Shear, Lava Burst, or later-expansion Shaman mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Shaman_Enhancement_CHECKLIST.md

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





