# EAX TBC Classic Rotations - Changelog

## Release v1.0.0 - Metadata Standardization & Cleanup

**Release Date:** 2026-04-08  
**Author:** Eax  
**Repository:** https://github.com/eaxiumnet/eax-tbc-classic-rotations

---

### Summary

This release represents a comprehensive cleanup and standardization effort across all 29 TBC Classic rotation specifications. All specs have been audited, cleaned, and standardized for consistency.

### Changes

#### 🧹 Cleanup
- **Removed all "Port" mentions** from incomplete template placeholders across 26 files
  - Fixed header comments: `-- EAX Port) | ...` → `-- EAX <Class><Spec> | ...`
  - Fixed plugin names: `"EAX Port)"` → `"EAX <Class><Spec>"`
  - Fixed author fields: `"Eax Team ( Port)"` → `"Eax"`
  - Removed incomplete "Ported from ." descriptions

#### 📋 Metadata Standardization
- **Author field unification**: All 29 specs now use `"Eax"` consistently
  - Standardized from mixed: `"EAX"`, `"Eax Team"`, `"Eax"`
  - 35+ files updated across all specs
  
- **Plugin naming consistency**:
  - Fixed Priest specs: `"EAX)"` → `"EAX Priest Discipline/Holy/Shadow"`
  - Fixed Mage specs: `" Mage Arcane/Fire/Frost"` → `"EAX Mage Arcane/Fire/Frost"`
  - Standardized plugin_load_name to `"EAX"` across all specs

- **Version normalization**: 
  - Shaman specs: `"2.0.0"` → `"1.0.0"` (consistent with all other specs)
  - All 29 specs now use semantic versioning `1.0.0`

#### 📁 Affected Specs (29 Total)

**Druid (4 specs):**
- EAXDruidBalance
- EAXDruidBear  
- EAXDruidFeral
- EAXDruidResto

**Hunter (3 specs):**
- EAXHunterBM
- EAXHunterMM
- EAXHunterSurvival

**Mage (3 specs):**
- EAXMageArcane
- EAXMageFire
- EAXMageFrost

**Paladin (3 specs):**
- EAXPaladinHoly
- EAXPaladinProtection
- EAXPaladinRetribution

**Priest (4 specs):**
- EAXPriestDiscipline
- EAXPriestHoly
- EAXPriestShadow
- EAXPriestSmite

**Rogue (3 specs):**
- EAXRogueAssassination
- EAXRogueCombat
- EAXRogueSubtlety

**Shaman (3 specs):**
- EAXShamanElemental
- EAXShamanEnhancement
- EAXShamanRestoration

**Warlock (3 specs):**
- EAXWarlockAffliction
- EAXWarlockDemonology
- EAXWarlockDestruction

**Warrior (3 specs):**
- EAXWarriorArms
- EAXWarriorFury
- EAXWarriorProtection

### Files Modified

**Plugin metadata files:**
- `EAX*/plugin_info.lua` (29 files) - Author, version, and plugin_load_name standardization
- `EAX*/header.lua` (29 files) - Author and name field fixes
- `EAX*/libraries/spells.lua` (26 files) - Header comment cleanup

### Quality Assurance

- ✅ All Lua files pass `luac -p` syntax validation
- ✅ No remaining "Port" placeholder references
- ✅ Consistent author = "Eax" across all specs
- ✅ Consistent version = "1.0.0" across all specs
- ✅ Proper plugin naming with "EAX" prefix

### Migration Notes

No breaking changes. This is a pure metadata cleanup release. All rotation logic remains unchanged.

### Known Issues

None.

### Contributors

- **Eax** - Metadata audit, standardization, and cleanup

---

*This changelog follows the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.*
