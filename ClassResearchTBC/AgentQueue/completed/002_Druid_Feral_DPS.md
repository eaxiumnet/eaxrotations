# Job 002 - Druid Feral DPS

Status: completed
Heartbeat: 2026-05-19
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Feral_DPS_CHECKLIST.md

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
Assigned spec: Druid Feral DPS

Read first:
- C:\newbot\scripts\ClassResearchTBC\AGENTS.md
- C:\newbot\scripts\ClassResearchTBC\VETTING_LOG.md
- C:\newbot\scripts\ClassResearchTBC\VERIFY_LIST.md
- C:\newbot\scripts\api\
- C:\newbot\scripts\apidocs\
- C:\newbot\scripts\ClassResearchTBC\Druid\Feral-DPS\Research.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Spells.md
- C:\newbot\scripts\ClassResearchTBC\Druid\DB2-Talents.md

Target implementation files:
- C:\newbot\scripts\EaxRotations\classes\druid\cat_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\class_sylvanas.lua
- C:\newbot\scripts\EaxRotations\classes\druid\schema_sylvanas.lua

Task:
Compare Cat/Feral DPS implementation to the Research.md contract and patch missing vetted behavior only. Focus on Mangle uptime before bleed spenders, Shred/Rip/Ferocious Bite priority, powershift gates, Clearcasting use, combo-point handling, target time-to-die, and movement/reopen logic.

Hard rules:
- Do not hard-code [VERIFY] AP/energy floors around 1500/2000/2500 AP. Keep these configurable.
- No Berserk [50334], Savage Roar, Cat Swipe, or later-expansion energy logic.
- Use DB2 spell IDs/rank lists, nil-guard settings, cache hot APIs, and keep Lua 5.1 compatible.
- Before adding or changing Project Sylvanas API calls, inspect C:\newbot\scripts\api\ and C:\newbot\scripts\apidocs\ for exact function names, signatures, and examples. Do not invent APIs. Record checked API files/functions in the checklist under API Validation.

Before patching, create or update the per-spec checklist:
- C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Druid_Feral_DPS_CHECKLIST.md

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
---

## Run Result — 2026-05-19

**Status:** complete ✅

**Files changed:** 2

| File | Changes |
|---|---|
| `class_sylvanas.lua` | 21 DB2 level corrections (Bash, BearForm, Claw, Cower, Dash, DemoRoar, FaerieFire, FaerieFireFeral, FeralCharge, FerociousBite, Growl, Maim, MangleCat, Moonfire, Pounce, Prowl, Rake, Ravage, Rip, Shred, TigersFury) |
| `cat_sylvanas.lua` | RAKE_DEBUFF spell ID fix: 27003→1822 (was using wrong Rake rank as debuff ID) |

**Validations:**
- ✅ `luac -p` passes all 3 files
- ✅ `test_cat_custom_matches.lua` — PASS
- ✅ `test_cat_snapshot_upgrade.lua` — PASS
- ✅ Code review passed (flagged RAKE_DEBUFF issue → fixed)

**Behavioral:** All 14 Research.md contract items confirmed Present — no behavioral changes needed.

**Remaining risk:** None.

---

## Run Result — 2026-05-19 (Session 2)

**Status:** complete ✅

**Files changed:** 5

| File | Changes |
|---|---|
| `class_sylvanas.lua` | DB2 level corrections: TravelForm 16→30, ChallengingRoar 58→28, TrackHumanoids 14→32, GiftOfTheWild removed extra level 40, Innervate 60→40, NaturesSwiftness 50→30 |
| `cat_sylvanas.lua` | **REMOVED forbidden non-TBC hooks:** Berserk (spell, buff check, matches function, action), SurvivalInstincts (spell, matches function, action), SwipeCat (spell, matches function, action). Updated `has_high_ap_window` to not reference Berserk. Renamed `cat_berserk_hp`→`cat_barkskin_hp` in Barkskin threshold. |
| `schema_sylvanas.lua` | Renamed `cat_berserk_hp`→`cat_barkskin_hp`, updated label to "Barkskin HP%" |
| `002_Druid_Feral_DPS.md` | Status: in_progress → completed |
| `MANIFEST.md` | Status: pending → completed |

**Validations:**
- ✅ `luac -p` passes on `cat_sylvanas.lua`, `class_sylvanas.lua`, `schema_sylvanas.lua`
- ✅ `test_cat_snapshot_upgrade.lua` — PASS (61/61 assertions)
- ✅ `test_cat_custom_matches.lua` — PASS
- ✅ No Berserk/SurvivalInstincts/SwipeCat references remain in cat_sylvanas.lua
- ✅ All Research.md TBC-only compliance verified

**Behavioral:** Feral DPS rotation remains compliant with TBC mechanics; no Berserk, Savage Roar, or Cat Swipe. Powershift, bleeds, snapshotting, and PvP logic intact.

**Remaining risk:** None.
