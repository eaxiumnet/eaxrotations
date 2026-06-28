# FrostByte Supremacy Phase 1 — Implementation Plan

## Date: 2026-06-28
## Scope: 5 shared modules + spec wiring + tests

### Modules to Create

1. **stopcast_sylvanas.lua** — Cancel in-flight heal when target recovers above threshold
2. **pet_heal_sylvanas.lua** — Include party/raid pets in healing target scan
3. **triage_sylvanas.lua** enhancement — Tank HP bias in urgency score
4. **snap_threat_sylvanas.lua** — Immediate threat ability on combat entry
5. **combat_mode_sylvanas.lua** — Force ST/AoE/Auto mode override

### Specs to Wire
- Holy Priest, Discipline Priest, Resto Shaman, Resto Druid, Holy Paladin
- Prot Paladin, Prot Warrior
- All DPS specs (combat mode)

### Schemas to Update
- priest/schema_sylvanas.lua
- shaman/schema_sylvanas.lua
- druid/schema_sylvanas.lua
- paladin/schema_sylvanas.lua
- warrior/schema_sylvanas.lua

### Tests to Add
- test_stopcast_engine.lua
- test_pet_heal.lua
- test_triage_tank_bias.lua
- test_snap_threat.lua
- test_combat_mode.lua

### Validation
- luac -p on all modified files
- run_rotation_tests.lua must pass all 171 suites
- run_leveling_tests.lua must pass all 11 suites
