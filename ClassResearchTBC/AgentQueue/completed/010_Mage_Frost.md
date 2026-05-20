# Job 010 - Mage Frost

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Mage_Frost_CHECKLIST.md

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
Assigned spec: Mage Frost

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Mage\Frost\Research.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Mage\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\mage\frost_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\mage\schema_sylvanas.lua

Task:
Compare Frost implementation to the Research.md contract and patch missing vetted behavior only. Focus on Frostbolt priority, Water Elemental if talented/valid, Icy Veins, Cold Snap, Shatter/Frostbite awareness, defensive Ice Block/Ice Barrier, and movement/CC gates.

Hard rules:
- Brain Freeze [44549] is DB2 absent. Do not implement it.
- No Deep Freeze, Frostfire Bolt, Fingers of Frost, or later-expansion Mage mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Mage_Frost_CHECKLIST.md

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






## Run Result - 2026-05-19

**Status:** completed  
**Agent:** Sisyphus  
**Duration:** ~10 minutes

### Changes Made

| File | Change |
|------|--------|
| rost_sylvanas.lua | Added rcane_explosion_matches strategy (priority 19) for close-range instant AoE |
| class_sylvanas.lua | ArcaneExplosion already present from Job 009 (shared spell) |

### Summary

Compared Mage Frost implementation against Research.md contract. **One vetted missing item found and fixed:**

- **[MISSING → FIXED]** Arcane Explosion for close stacked AoE targets
  - Research.md line 21: "Cone of Cold/Frost Nova/Arcane Explosion when safe"
  - Added rcane_explosion_matches with enemy_count >= 3 threshold
  - Inserted before Blizzard (priority 19) per AoE priority ordering

### Items Verified as Present

- Frostbolt filler, Water Elemental, Icy Veins, Cold Snap
- Ice Barrier refresh (<5s), Ice Block (<20% HP)
- Frost Nova, Cone of Cold, Blizzard
- Shatter combo (Frostbite → Frostbolt at priority 8)
- Winter's Chill maintenance (5-stack, refresh at <3s)
- Counterspell, Polymorph, Remove Curse, Mana Gem/Evocation
- All forbidden mechanics absent (Brain Freeze, Deep Freeze, etc.)

### Validation

- luac -p frost_sylvanas.lua - **PASS**
- luac -p class_sylvanas.lua - **PASS**
- luac -p schema_sylvanas.lua - **PASS**

### No Vetted Missing Items Remain

### Files Modified

- C:\newbot\scripts\EaxRotations\classes\mage\frost_sylvanas.lua

