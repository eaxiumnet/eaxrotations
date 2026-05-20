# Job 019 - Rogue Combat

Status: completed
Heartbeat: 2026-05-20 12:00
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Rogue_Combat_CHECKLIST.md

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
Assigned spec: Rogue Combat

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Rogue\Combat\Research.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Rogue\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\rogue\combat_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\rogue\schema_sylvanas.lua

Task:
Compare Combat implementation to the Research.md contract and patch missing vetted behavior only. Focus on Slice and Dice uptime, Sinister Strike, Rupture/Eviscerate, Adrenaline Rush, Blade Flurry [13877], poisons, energy pooling, interrupts, and target-count/CC-safe cleave.

Hard rules:
- Blade Flurry [13877] is valid TBC: +20% melee attack speed, additional nearby target, 15s duration, 2m cooldown.
- No Killing Spree, Fan of Knives, Bandit's Guile, or later-expansion Rogue mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Rogue_Combat_CHECKLIST.md

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

## Run Result - 2026-05-20 12:00

**Outcome:** Completed — no changes required.

**Summary:**
- Compared `Rogue\Combat\Research.md` (294 lines) against four target implementation files.
- All core rotation requirements (SnD uptime, SS builder, Rupture/Eviscerate gates, Adrenaline Rush/Blade Flurry timings, energy pooling, interrupts, Expose Armor assignment, threat drops) are already present and correct.
- DB2 spell IDs match exactly across `class_sylvanas.lua` rank tables.
- Research.md "Implementation Divergence Table" (Angle 5) — all 4 divergence items are already addressed:
  1. Slice and Dice refresh: `SND_REFRESH_WINDOW = 3` enforced in `slice_and_dice_wrapper`.
  2. Blade Flurry target count: `combat_blade_flurry_count` slider (default 2) enforced.
  3. Eviscerate CP gate: `combo_points < 4` → false.
  4. Rupture TTD: `combat_rupture_ttd` slider (default 12) enforced.
- All forbidden mechanics (Killing Spree, Fan of Knives, etc.) are absent.
- `luac -p` passed on all 4 target files: `combat_sylvanas.lua`, `class_sylvanas.lua`, `schema_sylvanas.lua`, `middleware_sylvanas.lua`.
- No code edits were made.

**Files touched:** None (no code changes needed).
- Checklist created: `Rogue_Combat_CHECKLIST.md`.

**Remaining risk:** None. Spec is fully aligned.






