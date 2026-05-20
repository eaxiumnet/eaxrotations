# Job 006 - Hunter Marksmanship

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Hunter_Marksmanship_CHECKLIST.md

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
Assigned spec: Hunter Marksmanship

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Hunter\Marksmanship\Research.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Hunter\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\hunter\marksmanship_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\cliptracker_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\hunter\schema_sylvanas.lua

Task:
Compare MM implementation to the Research.md contract and patch missing vetted behavior only. Focus on Auto Shot clipping prevention, Steady Shot timing, Aimed Shot, Multi-Shot, Arcane Shot, Rapid Fire, Trueshot Aura, Silencing Shot [34490], and Aspect of the Viper [34074].

Hard rules:
- Silencing Shot [34490] is valid TBC, 20s DB2 cooldown, 3s Wowhead silence. Gate by casting target and immunity.
- No Trap Launcher, Focus resource, Chimera Shot, Kill Shot, or later-expansion Hunter mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Hunter_Marksmanship_CHECKLIST.md

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

## Run Result (2026-05-19)

**3 files changed** (8 DB2 fixes + 7 behavioral fixes + 2 strategy wiring):

| File | Changes |
|---|---|
| `class_sylvanas.lua` | AimedShot, FeignDeath, ViperSting, Misdirection levels corrected to DB2; SilencingShot [34490] added; MultiShot constructor added |
| `marksmanship_sylvanas.lua` | SerpentSting refresh 3→1.5, SilencingShot interrupt strat wired, InCombatAimedShot+mana gate wired, Multi-Shot CC+mana gates, Arcane Shot mana gate, Aspect Hawk flip-flop guard |
| `schema_sylvanas.lua` | mana_viper_start default 10→20 (carried from BM pass) |

- ✅ `luac -p` passes all files
- ✅ Code review cleared
- ✅ 22 strategies in rotation array (2 previously unwired)
- ✅ Checklist updated with evidence

**Remaining risk**: WingClip spell in class_sylvanas.lua has incorrect IDs (uses SerpentSting/ArcaneShot IDs instead of Wing Clip IDs 2974/14267/14268). Low priority — not wired into any Hunter spec rotation currently.
``





