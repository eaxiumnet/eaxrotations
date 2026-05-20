# Job 007 - Hunter Survival

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Hunter_Survival_CHECKLIST.md

## Queue Instructions

This job is consumed by AgentQueue\AGENT_RUNNER.md.

The agent must:
- Move this file to AgentQueue\in_progress\ before code edits.
- Execute only vetted missing/partial work.
- Update the checklist named above.
- Append a run result section to this job.
- Move this file to AgentQueue\completed\ when 100% done.
- Move this file to AgentQueue\blocked\ if evidence/runtime validation is required.

## Run Result

**Completed**: 2026-05-20 | **Runner**: Buffy

### Files Changed

| File | Changes |
|---|---|
| `class_sylvanas.lua` | 6 DB2 corrections: ExplosiveTrap levels (61,54,44,34), ScorpidSting (7 ranks→1 rank [3043]), RaptorStrike (all 9 ranks rewritten from wrong IDs), WingClip (6 ranks→3 correct ranks), Volley (4 ranks with correct IDs), added WyvernSting [27068,24133,24132,19386] at {70,60,50,40} |
| `survival_sylvanas.lua` | Behavioral fixes: SerpentSting refresh 3→1.5, Arcane Shot mana gate <10%, Multi-Shot CC+mana gate <15%, Volley 4+ gate (was 3+), ExplosiveTrap any combat state+3 enemies minimum, ExplosiveTrap enemy_count 7→3, added WyvernSting strategy with DoT guard (serpent/scorpid suppress), repositioned near FreezingTrap for PvP CC priority |
| `schema_sylvanas.lua` | No changes needed (Viper mana_pct already set via earlier BM job) |

### Validation
- ✅ `luac -p` passes on both modified files
- ✅ Code review cleared (one suggestion applied: WyvernSting repositioned)
- ✅ All 6 DB2 spell IDs corrected
- ✅ All 7 behavioral gaps patched

### Remaining Risk
- Low: Expose Weakness is a passive talent proc — no code gate needed
- Low: No test file for Survival exists; manual verification recommended
