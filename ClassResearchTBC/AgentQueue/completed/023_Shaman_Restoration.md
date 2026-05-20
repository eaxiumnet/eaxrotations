# Job 023 - Shaman Restoration

Status: completed
Created: 2026-05-19
Completed: 2026-05-20
Runner: C:\newbot\scripts\ClassResearchTBC\AgentQueue\AGENT_RUNNER.md
Checklist: C:\newbot\scripts\ClassResearchTBC\ImplementationChecklists\Shaman_Restoration_CHECKLIST.md

## Run Result — 2026-05-20

### Files Changed (2)

| File | Changes |
|---|---|
| `EaxRotations/classes/shaman/class_sylvanas.lua` | 6 DB2 level corrections: EarthShield (60,50), HealingWave (5 entries), GroundingTotem (30), CurePoison (16), PoisonCleansingTotem (22), StoneclawTotem (67) |
| `EaxRotations/classes/shaman/restoration_sylvanas.lua` | Added ManaEmergencyWand strategy at position 0 (separate matches/execute — pure check + auto-attack with nil guard); mana_emergency gates on water_shield, earth_shield_tank, natures_swiftness; fixed tab indentation throughout |

### Validation
- ✅ `luac -p` passes (all 3 files)
- ✅ Code review cleared (2 passes)
- ✅ Existing test `test_restoration_healing_way.lua` lints clean
- ✅ 6/6 DB2 corrections verified against DB2-Spells.md

### Research Compliance
- Mana < 5% emergency: auto-attack only, all spells forbidden ✅
- Earth Shield refresh at ≤2 charges ✅
- Water Shield refresh on missing/depleted ✅
- Nature's Swiftness emergency path (HP < 30%, time-to-die < 3s) ✅
- Chain Heal bounce logic (≥2 targets, HP < 65%) ✅
- Healing Way stack maintenance (HW on tank when <3 stacks) ✅
- Mana Tide at group mana < 60% ✅
- Bloodlust gated on group HP > 85% ✅





