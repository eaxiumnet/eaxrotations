# Menu Wiring Verification Report

## Executive Summary

- **Total specs verified**: 27
- **Total critical issues found**: 165+
- **Specs with no issues**: 9 (EAXDruidBear, EAXHunterBM, EAXPriestDiscipline, EAXPriestHoly, EAXPriestShadow, EAXPriestSmite, EAXRogueAssassination, EAXRogueCombat, EAXRogueSubtlety, EAXShamanElemental, EAXShamanEnhancement, EAXWarlockAffliction - Note: Affliction has 1 missing, so actually 8 clean specs)
- **Specs needing fixes**: 18 (All specs except the 9 clean ones listed above)

*Note: Based on the provided data, EAXWarlockAffliction has 1 missing definition, so it should be counted among the specs needing fixes. The actual clean specs count is 8.*

## Critical Issues Summary by Spec

### EAXDruidBalance
- 6 missing definitions

### EAXDruidFeral
- 2 missing definitions
- 3 wrong names
- 13 unguarded menu accesses

### EAXDruidResto
- 5 missing definitions

### EAXHunterMM
- 11 missing definitions
- 24 unguarded menu accesses

### EAXHunterSurvival
- 10 missing definitions

### EAXMageArcane
- 12 missing definitions

### EAXMageFire
- 8 missing definitions
- 5 wrong names

### EAXMageFrost
- 15 missing definitions
- 6 wrong names
- 19 unguarded menu accesses

### EAXPaladinHoly
- 13 missing definitions
- Multiple wrong names
- 4 unguarded menu accesses

### EAXPaladinProtection
- 17 missing definitions
- 2 wrong names
- 12 unguarded menu accesses

### EAXPaladinRetribution
- 4 missing definitions
- 1 wrong name

### EAXShamanRestoration
- 15 missing definitions
- 15 wrong names
- 3 wrong accessors

### EAXWarlockAffliction
- 1 missing definition

### EAXWarlockDemonology
- 5 missing definitions

### EAXWarlockDestruction
- 3 missing definitions

### EAXWarriorArms
- 6 missing definitions
- 1 unguarded menu access

### EAXWarriorFury
- 12 missing definitions
- 1 wrong name
- 35 unguarded menu accesses

### EAXWarriorProtection
- 14 missing definitions
- 25 unguarded menu accesses

## Common Issue Patterns

1. **Missing menu definitions**: Menu items are accessed in the code but not defined in the menu.lua file
2. **Wrong accessor names**: Incorrect menu item names used (e.g., `frost_use_icy_veins` vs `use_icy_veins`)
3. **Unguarded menu accesses**: Direct access to menu items without nil checks, causing potential crashes
4. **Dashboard mismatches**: Inconsistencies between menu definitions and usage

## Recommended Fix Approach

### Phase 1: Mage specs (pilot)
- Fix EAXMageArcane, EAXMageFire, EAXMageFrost
- Estimated effort: 2-3 hours
- Approach: Establish fix patterns and validate

### Phase 2: Warrior specs
- Fix EAXWarriorArms, EAXWarriorFury, EAXWarriorProtection
- Estimated effort: 3-4 hours
- Approach: Apply learned patterns from Mage phase

### Phase 3: Paladin specs
- Fix EAXPaladinHoly, EAXPaladinProtection, EAXPaladinRetribution
- Estimated effort: 3-4 hours
- Approach: Continue with refined process

### Phase 4: Remaining specs
- Fix Druid, Hunter, Shaman, Warlock specs
- Estimated effort: 4-5 hours
- Approach: Finalize and clean up

**Total estimated effort**: 12-16 hours across 4 phases

## User Decision Options

### Option 1: "yes" - Proceed with full parallel fix
- Address all 18 affected specs simultaneously
- Fastest resolution but requires coordination

### Option 2: "pilot" - Fix only Mage specs first
- Start with EAXMageArcane, EAXMageFire, EAXMageFrost
- Validate approach before scaling to other specs

### Option 3: "critical" - Fix only P0 specs
- Focus on specs with highest issue counts (WarriorFury, PaladinProtection, MageFrost, etc.)
- Address most critical crash risks first

### Option 4: "list" - Generate master fix list only
- Create detailed issue list without implementing fixes
- For manual review or external handling

## Appendix: Detailed Per-Spec Findings

Due to the extensive nature of the verification results (165+ issues across 18 specs), detailed per-spec findings with exact missing items and line numbers are available in the individual verification reports generated during the audit process. These reports can be found in the verification artifacts directory or by re-running the verification tool with detailed output enabled.

For immediate reference, the summary above captures the critical metrics needed for decision-making. Detailed line-by-line reports can be generated on demand for any specific spec requiring deeper analysis.

---
*Report generated based on menu wiring verification completed on 2026-04-08*