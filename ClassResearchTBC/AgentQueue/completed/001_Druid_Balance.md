# Job 001 - Druid Balance

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Balance_CHECKLIST.md

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
Assigned spec: Druid Balance

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Balance\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\balance_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\caster_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare current Balance implementation to the Research.md contract and patch missing vetted behavior only. Focus on Starfire/Wrath filler choice, Moonfire/Insect Swarm refresh gates, mana conservation, Force of Nature, Innervate/Rebirth assignment, movement fallback, and target validity.

Hard rules:
- Do not hard-code the [VERIFY] SP breakpoint rows at 800/1000/1200 spell power. Make them configurable or leave as comments/TODOs only.
- No Eclipse, Starfall, Typhoon, Wild Growth, Berserk, Savage Roar, or other later-expansion mechanics.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Balance_CHECKLIST.md

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

## Run Result - 2026-05-19 09:30

Agent: Sisyphus (Sisyphus-Junior)
Status: completed

### Changes Made

| File | Change | Evidence |
|---|---|---|
| EaxRotations/classes/druid/balance_sylvanas.lua | **FIXED: Reordered strategies — Faerie Fire/DoTs now run BEFORE Starfire/Wrath filler** | Lines ~253-372 |
| EaxRotations/classes/druid/balance_sylvanas.lua | **FIXED: Target validity gate no longer short-circuited by `or context.target`** | Lines ~253-372 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Replaced hard-coded DoT refresh thresholds (2s) with NS.should_refresh_dot + TTD gate for Moonfire and Insect Swarm | Lines ~280-305 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Added `target_ttd` to state builder from `context.ttd` | Line ~84 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Added `has_valid_enemy_target` gate to DoT, Faerie Fire, and nuke strategies | Lines ~253-372 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Added `balance_use_force_of_nature` setting toggle + 12s TTD gate to Force of Nature | Lines ~159-175 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Added `balance_use_insect_swarm` setting toggle to Insect Swarm | Line ~293 |
| EaxRotations/classes/druid/balance_sylvanas.lua | **FIXED: Innervate reverted to safe self-cast (assignment-aware blocked due to no runtime API)** | Lines ~177-193 |
| EaxRotations/classes/druid/balance_sylvanas.lua | **FIXED: Rebirth wired to `NS.find_dead_party_ally` using raw party members (includes dead units)** | Lines ~196-213 |
| EaxRotations/main_sylvanas.lua | **FIXED: Added `context.tank_alive` wiring via NS.GetPartyMembers + safe pcall on u:is_tank() and u:is_alive()** | Lines ~236-254 |
| EaxRotations/classes/druid/balance_sylvanas.lua | **FIXED: Mana state reads `context.mana_pct` first, not just `context.mana`** | Line ~82 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Improved Starfire vs Wrath choice: clearer conserve floor and Nature's Grace priority | Lines ~100-119 |
| EaxRotations/classes/druid/balance_sylvanas.lua | Fixed Nature's Grasp max rank ID from 27010 to 27009 per DB2 | Line ~26 |
| EaxRotations/classes/druid/class_sylvanas.lua | Fixed RemoveCurse secondary ID: removed erroneous 20739 (Rebirth), kept 2782 only | Line ~534 |
| EaxRotations/classes/druid/schema_sylvanas.lua | Added `balance_use_force_of_nature` and `balance_use_insect_swarm` settings | Lines ~50-52 |
| EaxRotations/tests/test_balance_*.lua | **Updated tests to match fixed code (strategy name, has_valid_enemy_target)** | All PASSED |

### Validation

- `luac -p` passed on: balance_sylvanas.lua, schema_sylvanas.lua, class_sylvanas.lua
- `test_balance_custom_matches.lua` PASSED
- `test_balance_faerie_fire.lua` PASSED
- `test_balance_war_stomp.lua` PASSED
- `test_leveling_druid.lua` PASSED (90 tests, 248 assertions)
- `test_druid_caster_custom_matches.lua` PASSED

### Remaining Risk / Blocked Items

| Item | Why | Evidence needed |
|---|---|---|
| SP breakpoint auto-switching (800/1000/1200) | **Tracked separately** → `blocked/SP_Breakpoints_Druid_Balance.md`. [VERIFY] rows in Research.md; no auto-detect wired, thresholds kept configurable via `balance_starfire_mana` slider. | wowsims/tbc + combat logs |
| ~~Innervate assignment-aware casting~~ | **Resolved 2026-05-21**: smart healer scanning (`HEALER_CLASS_IDS`, `NS.GetPartyMembers()`, `NS.mana_pct`) now prefers low-mana healers over self. Split into `InnervateHealer` + `InnervateSelf` strategies. | N/A — implemented |
| ~~Hurricane Barkskin-cast-before-channel automation~~ | **Resolved 2026-05-21**: `PreHurricaneBarkskin` (strategy #7) + `HurricaneAoE` (strategy #8) already implement the two-tick pattern. Verified in code 2026-05-19. | N/A — already implemented |

### Unblocking Pass — 2026-05-21

Re-verified all three blockers:

1. **Hurricane Barkskin automation**: ✅ **RESOLVED**. `PreHurricaneBarkskin` (strategy #7, lines ~243-265) casts Barkskin when available and not active; `HurricaneAoE` (strategy #8, lines ~267-284) defers when Barkskin is ready but not yet active, then fires on next tick when Barkskin is confirmed active. Complete two-tick pattern implemented 2026-05-19.

2. **Innervate assignment-aware casting**: ✅ **RESOLVED**. Ported Resto spec's smart healer scanning pattern to Balance: scans `NS.GetPartyMembers()` for healer-class party members (`HEALER_CLASS_IDS`: Paladin/2, Priest/5, Shaman/7, Druid/11) with mana ≤ (healer_mana_floor + 5)%, prefers them over self, falls back to self-cast when own mana ≤ threshold. Split into `InnervateHealer` + `InnervateSelf` strategies. Uses pcall-safe `unit:get_class()`, `NS.mana_pct()`, `NS.same_unit()`. No overhead in solo play (gated behind `context.in_combat`, `context.is_group`, `NS.GetPartyMembers`).

3. **SP breakpoints (800/1000/1200)**: ⛔ **TRACKED SEPARATELY** → `blocked/SP_Breakpoints_Druid_Balance.md`. No new sim/log evidence available. Thresholds remain configurable via `balance_starfire_mana` slider (schema line 47). Does not block completion of 001_Druid_Balance.

**Summary**: 2 of 3 blockers fully resolved, 1 (SP breakpoints) split into its own tracked blocked task. Job moved to `completed/`.

### Final Run Result — 2026-05-21

Agent: Buffy (Codebuff)
Status: unblock → completed

Changes:
- Added `HEALER_CLASS_IDS` table and `innervate_target` field to `balance_state`
- Party scan in `build_state()` finds low-mana healers before self
- Split `InnervateSelf` into `InnervateHealer` + `InnervateSelf` strategies
- SP breakpoints deferred to separate tracked file `SP_Breakpoints_Druid_Balance.md`

Validation:
- `luac -p` PASS on balance_sylvanas.lua
- `test_balance_custom_matches.lua` PASSED (updated mock for Hurricane + Barkskin cooldown path)
- Full rotation test suite: 95/95 PASS
- Full leveling test suite: 11/11 PASS
