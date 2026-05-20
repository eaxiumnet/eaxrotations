# Job 027 - Warrior Arms

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Warrior_Arms_CHECKLIST.md

## Run Result - 2026-05-20 12:25

**Outcome:** Completed — no changes required.

**Summary:**
- Compared `Warrior\Arms\Research.md` (296 lines) against four target implementation files.
- All core rotation requirements (Mortal Strike CD, Slam swing timing, Whirlwind, Execute execute_phase gate, Overpower, Sweeping Strikes 2+ target, Battle/Commanding Shout, stance dancing, interrupts, Hamstring/Tactician weave) are present and correct.
- Research.md "Implementation Divergence Table" (Angle 5) — all 5 divergence items are already addressed:
  1. Slam timing: `slam_matches` uses SwingTimer API with clipping prevention.
  2. Overpower reaction: High priority position (#17); `overpower_ready` checked per tick.
  3. Execute threshold: `execute_phase` at <=20% HP; rage threshold configurable.
  4. Sweeping Strikes: `enemy_count >= 2` enforced.
  5. Commanding Shout: Registered in class table [469]; available if assigned.
- Forbidden mechanics (Bladestorm, Heroic Throw, Taste for Blood, Colossus Smash) absent.
- `luac -p` passed on all 4 target files.
- No code edits made.

**Files touched:** None (no code changes needed).
- Checklist created: `Warrior_Arms_CHECKLIST.md`.

**Remaining risk:** None. Spec is fully aligned.


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
Assigned spec: Warrior Arms

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Warrior\Arms\Research.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Warrior\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\warrior\arms_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\warrior\schema_sylvanas.lua

Task:
Compare Arms implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mortal Strike, Slam timing after swing, Whirlwind, Execute, rage pooling, Hamstring/Overpower if supported, Battle/Commanding Shout, interrupts, stance checks, and target validity.

Hard rules:
- Commanding Shout [469] is valid TBC. Gate by learned spell and raid assignment.
- No Bladestorm, Heroic Throw, Taste for Blood, Colossus Smash, or later-expansion Warrior mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Warrior_Arms_CHECKLIST.md

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





