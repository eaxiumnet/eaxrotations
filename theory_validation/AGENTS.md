# Theory Validation Framework for EAX TBC Rotations

This directory contains theoretical validation tools to test rotation logic, spell priorities, and encounter handling without live gameplay.

## Purpose

Validate specs through:
1. **Mathematical modeling** - Calculate expected DPS/HPS/TPS
2. **Rotation simulation** - Run rotation logic through encounter timelines
3. **Mana modeling** - Verify sustain over fight duration
4. **Priority validation** - Check against known TBC theorycraft
5. **Edge case detection** - Find logical gaps in rotation code

## Files

| File | Purpose |
|------|---------|
| `simulator_core.lua` | Core simulation engine |
| `encounter_library.lua` | Boss ability timelines and mechanics |
| `class_validators/` | Per-class validation suites |
| `mana_model.lua` | Mana consumption/sustain calculator |
| `threat_model.lua` | Threat generation calculator |
| `dps_calculator.lua` | Damage output modeling |
| `validation_runner.lua` | Execute all validations and generate reports |

## Usage

```bash
# Run full validation suite
lua theory_validation/validation_runner.lua

# Validate specific spec
lua theory_validation/class_validators/druid_balance_test.lua

# Run encounter simulation
lua theory_validation/encounter_library.lua gruul

# Generate mana model for spec
lua theory_validation/mana_model.lua EAXDruidBalance
```

## Validation Criteria

| Check | Threshold | Notes |
|-------|-----------|-------|
| DPS variance | <5% from wowsims | Within sim error margin |
| Mana sustain | >0% at fight end | Never OOM before boss dies |
| Threat lead | >110% of top DPS | Tank maintains aggro |
| HPS output | >70% of class average | Healer throughput acceptable |
| Rotation gaps | 0 dead zones | Always have valid next action |
| Cooldown usage | >80% efficiency | Major CDs used appropriately |

## Output

Validation generates:
- `validation_report.md` - Summary of all specs
- `spec_reports/EAX<Spec>_report.md` - Per-spec detailed analysis
- `encounter_reports/<boss>_report.md` - Per-encounter validation

## Theorycraft Sources

- FLUX simulation data
- wowsims TBC classic
- Icy Veins TBC guides
- EJ (Elitist Jerks) TBC archives
- Personal TBC experience 2007-2008

---

See AGENTS.md for common conventions.
