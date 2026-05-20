# Job 025 - Warlock Demonology

Status: completed
Created: 2026-05-19
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Warlock_Demonology_CHECKLIST.md

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
| `class_sylvanas.lua` | 4 DB2 corrections: ShadowWard (1→4 ranks), Incinerate (shorthand→full with levels {70,64}), FelArmor (shorthand→full with levels {69,62}), HowlofTerror (shorthand→full with levels {54,40}, cooldown 40→0 per DB2) |
| `demonology_sylvanas.lua` | 4 behavioral fixes: FelDomination cooldown 900ms→900000ms (15min per DB2), Corruption refresh 3→1.5s, Immolate refresh 3→1.5s, ShadowBolt now before Incinerate in strategies (Demo is shadow-primary) |

### Validation
- ✅ `luac -p` passes on both modified files
- ✅ `test_demonology_custom_matches.lua` PASS (DeathCoil, SummonFelguard, HealthFunnel unchanged)
- ✅ Code review cleared (one suggestion: HowlofTerror cooldown corrected to 0)
- ✅ All 5 TBC-absent spells confirmed absent (Demonic Empowerment, Metamorphosis, Demon Soul, Demonic Pact, Fel Intelligence)

### Remaining Risk
- Low: Soul Link [19028] not in rotation (PvP defensive, beyond DPS scope)
- Low: No Demonology-specific schema section (schema already has Pet/Stones settings at class level)
