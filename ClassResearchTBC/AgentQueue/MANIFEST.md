# Agent Queue Manifest

Created: 2026-05-19
Updated: 2026-05-21

Status meanings:
- pending: not processed yet.
- in_progress: currently being processed by an agent.
- completed: no vetted missing/partial work remains.
- blocked: requires evidence, runtime validation, missing source, or unresolved blocker.

Agents must update this manifest after every run.

| Job | Spec | Status | Last update | Summary |
|---|---|---|---|---|
| 001_Druid_Balance.md | Druid Balance | completed | 2026-05-21 | Innervate smart healer scanning + Hurricane Barkskin resolved; SP breakpoints tracked separately in SP_Breakpoints_Druid_Balance.md |
| 002_Druid_Feral_DPS.md | Druid Feral DPS | completed | 2026-05-19 | Removed forbidden non-TBC hooks (Berserk, SurvivalInstincts, SwipeCat); fixed DB2 spell levels; cat tests pass |
| 003_Druid_Bear_Tank.md | Druid Bear Tank | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 004_Druid_Restoration.md | Druid Restoration | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 005_Hunter_Beast_Mastery.md | Hunter Beast Mastery | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 006_Hunter_Marksmanship.md | Hunter Marksmanship | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 007_Hunter_Survival.md | Hunter Survival | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 008_Mage_Arcane.md | Mage Arcane | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 009_Mage_Fire.md | Mage Fire | completed | 2026-05-19 | Added ArcaneExplosion AoE spell; validated Research.md compliance; all vetted work complete |
| 010_Mage_Frost.md | Mage Frost | completed | 2026-05-19 | Added ArcaneExplosion AoE strategy; validated Research.md compliance; all vetted work complete |
| 011_Paladin_Holy.md | Paladin Holy | completed | 2026-05-19 | Verified DB2 levels; no code changes needed; all vetted work present |
| 012_Paladin_Protection.md | Paladin Protection | completed | 2026-05-19 | Verified CC-safe gates, Blessing of Sanctuary, Holy Wrath, DB2 spell levels; all vetted work done |
| 013_Paladin_Retribution.md | Paladin Retribution | completed | 2026-05-19 | Verified seal twisting, faction gating, Crusader Strike, Judgement, Consecration; all present |
| 014_Priest_Discipline.md | Priest Discipline | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 015_Priest_Holy.md | Priest Holy | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 016_Priest_Shadow.md | Priest Shadow | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 017_Priest_Smite.md | Priest Smite | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 018_Rogue_Assassination.md | Rogue Assassination | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 019_Rogue_Combat.md | Rogue Combat | completed | 2026-05-20 | No code changes needed; all vetted requirements present; checklist created |
| 020_Rogue_Subtlety.md | Rogue Subtlety | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 021_Shaman_Elemental.md | Shaman Elemental | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 022_Shaman_Enhancement.md | Shaman Enhancement | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 023_Shaman_Restoration.md | Shaman Restoration | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 024_Warlock_Affliction.md | Warlock Affliction | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 025_Warlock_Demonology.md | Warlock Demonology | completed | 2026-05-19 | Created from LLM_IMPLEMENTATION_PROMPTS_29.md |
| 026_Warlock_Destruction.md | Warlock Destruction | completed | 2026-05-20 | Conflagrate spell IDs expanded; Rain of Fire threshold corrected to 4 |
| 027_Warrior_Arms.md | Warrior Arms | completed | 2026-05-20 | No code changes; checklist created |
| 028_Warrior_Fury.md | Warrior Fury | completed | 2026-05-20 | Rampage IDs + stack/expiry fix; checklist created |
| 029_Warrior_Protection.md | Warrior Protection | completed | 2026-05-20 | Shield Block reorder + refresh; added CS config gate |

Recovery run 2026-05-19 14:50: moved 1 stale job(s): 021_Shaman_Elemental.md
Recovery run 2026-05-20: completed 5 jobs (019, 026, 027, 028, 029): 1 code patch (Conflagrate IDs), 1 reorder+refresh (Shield Block), 1 spell ID fix (Rampage), 2 no-change audits (Combat, Arms).
Recovery run 2026-05-20 v2: corrected 3 gaps found by Oracle review — Rain of Fire enemy_count 3→4, Rampage min_stacks 3→5 + expiry check, Commanding Shout config-gate added.

Verification run 2026-05-21: full re-verification across all 29 specs — 31/31 files pass `luac -p`, 0 banned WotLK/Cata spell IDs in active codebase, all 29 ImplementationChecklists present, in_progress/ and pending/ empty. No code changes required.

Unblocking run 2026-05-21: Druid Balance (001) moved from blocked to completed — Hurricane Barkskin automation confirmed already implemented, Innervate smart healer scanning ported from Resto spec. SP breakpoints deferred to `blocked/SP_Breakpoints_Druid_Balance.md` as standalone tracked task. All 29 specs now completed.

Blocked tasks (non-job):
- *(none)*

Deferred tasks (research complete; implementation low-priority optimization):
- `deferred/SP_Breakpoints_Druid_Balance.md` — SP breakpoints (800/1000/1200) for Druid Balance; coefficients verified, breakpoints confirmed, implementation deferred per Option B recommendation.
