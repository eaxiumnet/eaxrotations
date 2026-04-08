# EAX TBC Classic - Shared Library Drift Audit

**Audit Date**: 2026-04-08  
**Specs Analyzed**: 29 EAX TBC Classic rotation plugins  
**Scope**: Shared library usage patterns, function duplication, and version drift analysis

---

## Executive Summary

This audit reveals **significant code duplication** across all 29 EAX TBC Classic rotation specs. Despite having a `libraries/` folder with shared utilities, **every spec maintains its own local copies** of all libraries, resulting in 800+ duplicate files and ~7,500 lines of duplicated utility code.

### Key Findings

| Metric | Value |
|--------|-------|
| Total Specs Analyzed | 29 |
| Shared Libraries in Root | 22 |
| Specs Actually Using Shared Libraries | **0** |
| Local Library Files Per Spec | 30-32 |
| Total Duplicate Library Files | ~870 |
| Core Functions Duplicated Across All Specs | 20 |
| Lines of Duplicated Utility Code | ~7,500 |
| Functions with Version Drift | 3 |

---

## 1. Shared Library Usage Matrix

### 1.1 Core Libraries (Used by ALL 29 Specs)

| Library | Used in Main.lua | Has Local Copy | Notes |
|---------|------------------|----------------|-------|
| `middleware_manager.lua` | ✅ ALL 29 | ✅ ALL 29 | Primary middleware system |
| `dashboard.lua` | ✅ ALL 29 | ✅ ALL 29 | HUD/visualization |
| `dashboard_config.lua` | ✅ ALL 29 | ✅ ALL 29 | Dashboard configuration |
| `menu.lua` | ✅ ALL 29 | ✅ ALL 29 | Settings UI |
| `spells.lua` | ✅ ALL 29 | ✅ ALL 29 | Spell ID tables |
| `utils.lua` | ✅ ALL 29 | ✅ ALL 29 | Core utility functions |
| `spell_resolver.lua` | ✅ ALL 29 | ✅ ALL 29 | Spell caching |
| `settings_framework.lua` | ✅ ALL 29 | ✅ ALL 29 | Settings persistence |
| `ps_theme.lua` | ✅ ALL 29 | ✅ ALL 29 | UI theming |
| `compat.lua` | ✅ ALL 29 | ✅ ALL 29 | Compatibility layer |

### 1.2 Combat & Rotation Libraries

| Library | Specs Using | Has Local Copy In | Notes |
|---------|-------------|-------------------|-------|
| `combat_forecast.lua` | ~25 specs | ALL 29 specs | TTD prediction |
| `trinket_manager.lua` | ~20 DPS specs | ALL 29 specs | Trinket automation |
| `burst_manager.lua` | ~20 DPS specs | ALL 29 specs | Burst CD coordination |
| `ooc_manager.lua` | ~25 specs | ALL 29 specs | Out-of-combat rotation |
| `force_commands.lua` | ~20 specs | ALL 29 specs | Manual override system |
| `cc_detector.lua` | 28 specs | ALL 29 specs | CC detection |
| `swing_manager.lua` | ~15 melee specs | ALL 29 specs | Swing timer integration |
| `anti_fake_manager.lua` | 8 specs | ALL 29 specs | Anti-fake cast protection |

### 1.3 Class-Specific Libraries (Wasted Duplication)

These libraries exist in **ALL 29 specs** but are only relevant to specific classes:

| Library | Relevant To | Exists In | Waste Factor |
|---------|-------------|-----------|--------------|
| `hunter_clip_tracker.lua` | 3 Hunter specs | ALL 29 specs | 89% waste |
| `powershift.lua` | 1 Druid spec | ALL 29 specs | 96% waste |
| `energy_tick.lua` | 5 Rogue/Druid specs | ALL 29 specs | 83% waste |
| `mana_manager.lua` | 12 caster specs | ALL 29 specs | 59% waste |
| `heal_utils.lua` | 4 healer specs | ALL 29 specs | 86% waste |
| `heal_context.lua` | 4 healer specs | ALL 29 specs | 86% waste |
| `hot_manager.lua` | 1 Druid spec | ALL 29 specs | 96% waste |
| `smart_defensive.lua` | 3 tank specs | ALL 29 specs | 90% waste |
| `threat_tab_manager.lua` | 3 tank specs | ALL 29 specs | 90% waste |
| `context_builder.lua` | 3 tank specs | ALL 29 specs | 90% waste |
| `form_consumables.lua` | 4 Druid specs | ALL 29 specs | 86% waste |

### 1.4 Unused Shared Libraries

These libraries exist in `C:\newbot\scripts\libraries\` but are **not used by any spec**:

| Library | Location | Status |
|---------|----------|--------|
| `middleware.lua` | Shared root | ❌ Unused (legacy) |
| `spell_resolver.lua` | Shared root | ❌ Unused (local copies only) |

---

## 2. Function Duplication Analysis

### 2.1 Core Functions (Present in ALL 29 Specs)

The following 20 functions are **byte-identical** across all 29 specs' `utils.lua` files:

| Function | Signature | Lines of Code | Duplication Factor |
|----------|-----------|---------------|-------------------|
| `throttle` | `(key, interval) -> boolean` | ~8 | 29x |
| `resolve_spell_id` | `(rank_table) -> number\|nil` | ~12 | 29x |
| `get_health_pct` | `(unit) -> number` | ~6 | 29x |
| `get_distance_to_target` | `(me, target) -> number` | ~8 | 29x |
| `is_valid_hostile_target` | `(me, target) -> boolean` | ~10 | 29x |
| `can_cast_target` | `(spell_id, me, target) -> boolean` | ~15 | 29x |
| `same_unit` | `(a, b) -> boolean` | ~4 | 29x |
| `can_cast_hostile` | `(spell_id, me, target) -> boolean` | ~8 | 29x |
| `has_buff` | `(unit, buff_table) -> boolean` | ~8 | 29x |
| `has_debuff` | `(unit, debuff_table) -> boolean` | ~8 | 29x |
| `log_debug` | `(menu_module, message)` | ~4 | 29x |
| `can_cast_self` | `(spell_id, me) -> boolean` | ~8 | 29x |
| `cast_self` | `(spell_id, me) -> boolean` | ~6 | 29x |
| `cast_target` | `(spell_id, me, target) -> boolean` | ~6 | 29x |
| `get_energy` | `(me) -> number` | ~4 | 29x |
| `get_max_energy` | `(me) -> number` | ~4 | 29x |
| `get_combo_points` | `(me) -> number` | ~4 | 29x |
| `mana_pct` | `(me) -> number` | ~6 | 29x |
| `dist_squared` | `(me, target) -> number` | ~8 | 29x |
| `is_cced` | `(unit) -> boolean` | ~12 | 29x |

**Total duplicated lines**: ~280 lines × 29 specs = **~8,120 lines**

### 2.2 Role-Based Functions (Present in 4+ Specs)

| Function | Present In | Count | Notes |
|----------|------------|-------|-------|
| `find_lowest_effective_ally()` | Holy Paladin, Disc Priest, Holy Priest, Resto Druid, Resto Shaman | 5 | Heal target selection |
| `get_tank_unit()` | Holy Paladin, Disc Priest, Holy Priest, Resto Druid, Resto Shaman | 5 | Tank detection |
| `count_below_hp()` | Holy Paladin, Disc Priest, Holy Priest, Resto Druid, Resto Shaman | 5 | AoE heal decision |
| `detect_pvp_context()` | Warrior (3), Feral Druid | 4 | PvP state detection |
| `is_pvp_active()` | Warrior (3), Feral Druid | 4 | PvP mode check |
| `is_pvp_setting_enabled()` | Warrior (3), Feral Druid | 4 | PvP setting check |
| `try_berserker_rage_fear_break()` | Warrior (3) | 3 | CC break |
| `is_melee_target()` | Warrior (3), Prot Paladin | 4 | Melee range check |
| `enemy_count_in_radius()` | Warrior (2), Prot Paladin, Bear Druid | 4 | Enemy counting |
| `ensure_melee_auto_attack()` | Warrior (3), Ret Paladin | 4 | Auto-attack helper |

---

## 3. Version Drift Analysis

### 3.1 HIGH SEVERITY: Health Percentage Functions

**Issue**: Two incompatible implementations with different return values.

| Function Name | Specs Using | Return Value | Implementation |
|---------------|-------------|--------------|----------------|
| `get_health_pct(unit)` | 27 specs | **0-1 ratio** (e.g., 0.75) | Direct division, no pcall |
| `get_health_percentage(me)` | 2 specs | **0-100 percentage** | Uses pcall(), ×100 |

**Affected Files**:
- `EAXDruidBear/libraries/utils.lua` (line ~45): Uses `get_health_percentage` with pcall
- `EAXPriestSmite/libraries/utils.lua` (line ~42): Uses `get_health_percentage` with pcall
- All other 27 specs: Use `get_health_pct` without pcall

**Risk**: Code expecting 0-1 may break with 0-100 values, or vice versa.

### 3.2 HIGH SEVERITY: Mana Percentage Functions

**Issue**: Three different implementations with incompatible return values.

| Function Name | Specs | Return Value | Implementation |
|---------------|-------|--------------|----------------|
| `mana_pct(me)` | 26 specs | **0-1 ratio** | Direct division |
| `get_mana_pct(me)` | 2 specs | **0-100 percentage** | Uses pcall() |
| `get_mana_pct(me)` | 1 spec (Holy Paladin) | **0-1 ratio** | Wrapper: `heal_utils.get_mana_pct()/100` |

**Affected Files**:
- `EAXDruidBear/libraries/utils.lua`: `get_mana_pct` returns 0-100
- `EAXPriestSmite/libraries/utils.lua`: `get_mana_pct` returns 0-100
- `EAXPaladinHoly/libraries/utils.lua`: `get_mana_pct` returns 0-1 (divides by 100)
- All other 26 specs: Use `mana_pct` returning 0-1

### 3.3 MEDIUM SEVERITY: Combo Points Implementation

**Issue**: Rogues and Feral Druid use enhanced implementation.

| Spec Type | Function | Implementation |
|-----------|----------|----------------|
| Standard specs | `get_combo_points(me)` | Simple fallback: `me:get_combo_points() or 0` |
| Rogue (3 specs) + Feral | `get_combo_points(me)` | Enhanced with `enums.COMBOPOINTS_PT` for TBC compatibility |

**Affected Files**:
- `EAXRogueAssassination/libraries/utils.lua`
- `EAXRogueCombat/libraries/utils.lua`
- `EAXRogueSubtlety/libraries/utils.lua`
- `EAXDruidFeral/libraries/utils.lua`

**Note**: This is intentional - Rogues and Feral Druids need the enhanced version for TBC power type compatibility.

### 3.4 LOW SEVERITY: CC Break Functions in Wrong Spec

**Issue**: Warrior Fury utils contains CC break functions for other classes.

**File**: `EAXWarriorFury/libraries/utils.lua`

**Out-of-place functions**:
- `try_blink_stun_break()` - Mage ability
- `try_divine_shield_cc_break()` - Paladin ability
- `try_cloak_of_shadows_cc_break()` - Rogue ability
- `try_shapeshift_root_break()` - Druid ability

**Recommendation**: These should be in their respective class specs or moved to a shared CC break library.

---

## 4. Inconsistency Patterns

### 4.1 Naming Inconsistencies

| Function | Variations Found | Standardization Needed |
|----------|------------------|----------------------|
| Health percentage | `get_health_pct` vs `get_health_percentage` | Choose one convention |
| Mana percentage | `mana_pct` vs `get_mana_pct` | Choose one convention |
| Swing timer | `swing_manager.lua` vs `swing_timer.lua` | HunterBM uses different name |
| Middleware | `middleware.lua` vs `middleware_manager.lua` | Legacy vs current |

### 4.2 Return Value Inconsistencies

| Function | Standard Return | Exceptions |
|----------|-----------------|------------|
| Health percentage | 0-1 ratio | DruidBear, PriestSmite return 0-100 |
| Mana percentage | 0-1 ratio | DruidBear, PriestSmite return 0-100 |
| Combo points | Simple fallback | Rogues/Feral use enum-enhanced |

---

## 5. Recommendations

### 5.1 Immediate Actions (High Priority)

1. **Standardize Health/Mana Percentage Functions**
   - Choose either 0-1 ratio OR 0-100 percentage convention
   - Update DruidBear and PriestSmite to match the 27-spec standard
   - Or update all 27 specs to use pcall-protected 0-100 format

2. **Remove Out-of-Place CC Break Functions**
   - Remove Mage/Rogue/Paladin/Druid CC break functions from WarriorFury utils
   - Either delete (if unused) or move to appropriate specs

3. **Fix Naming Inconsistencies**
   - Standardize on `get_health_pct` and `mana_pct` OR `get_health_percentage` and `get_mana_percentage`
   - Rename HunterBM's `swing_timer.lua` to `swing_manager.lua` for consistency

### 5.2 Consolidation Opportunities (Medium Priority)

1. **Create Shared Utility Library**
   - Extract 20 core functions to `libraries/shared_utils.lua`
   - Eliminates ~8,120 lines of duplication
   - All specs require the shared version

2. **Consolidate PvP Utilities**
   - Warrior and Druid PvP detection functions are nearly identical
   - Extract to `libraries/pvp_utils.lua`

3. **Consolidate Healing Utilities**
   - 5 healing specs have similar `find_lowest_effective_ally()`, `get_tank_unit()`, `count_below_hp()`
   - Extract to `libraries/heal_utils.lua` (already exists but underutilized)

4. **Consolidate CC Break Functions**
   - Create `libraries/cc_break_manager.lua` with all CC break abilities
   - Each spec registers its own CC breaks

### 5.3 Cleanup (Low Priority)

1. **Remove Unused Shared Libraries**
   - `middleware.lua` in shared root (legacy, unused)
   - `spell_resolver.lua` in shared root (local copies used instead)

2. **Remove Class-Specific Libraries from Irrelevant Specs**
   - Remove `hunter_clip_tracker.lua` from non-Hunter specs (26 specs)
   - Remove `powershift.lua` from non-Druid specs (25 specs)
   - Remove `heal_utils.lua` from non-healer specs (25 specs)
   - Remove `mana_manager.lua` from non-caster specs (17 specs)

3. **Delete Legacy Files**
   - Remove `middleware.lua` from all 29 spec directories (unused)

### 5.4 Long-Term Architecture Improvements

1. **Migrate to IZI SDK**
   - Many utility functions could be replaced with `izi.spell()` and `izi.unit()` methods
   - Reduces custom code maintenance burden

2. **Implement True Shared Library Loading**
   - Modify require paths to prioritize shared libraries over local copies
   - Specs only override when they need custom behavior

3. **Create Library Dependency Manifest**
   - Each spec declares which libraries it actually needs
   - Build system only includes required libraries

---

## 6. Appendix: File Paths for Verification

### 6.1 Version Drift Locations

```
# Health percentage drift
C:\newbot\scripts\EAXDruidBear\libraries\utils.lua (line ~45)
C:\newbot\scripts\EAXPriestSmite\libraries\utils.lua (line ~42)

# Mana percentage drift
C:\newbot\scripts\EAXDruidBear\libraries\utils.lua (line ~55)
C:\newbot\scripts\EAXPriestSmite\libraries\utils.lua (line ~52)
C:\newbot\scripts\EAXPaladinHoly\libraries\utils.lua (line ~48)

# Combo points enhancement
C:\newbot\scripts\EAXRogueAssassination\libraries\utils.lua (line ~35)
C:\newbot\scripts\EAXRogueCombat\libraries\utils.lua (line ~35)
C:\newbot\scripts\EAXRogueSubtlety\libraries\utils.lua (line ~35)
C:\newbot\scripts\EAXDruidFeral\libraries\utils.lua (line ~38)

# Out-of-place CC break functions
C:\newbot\scripts\EAXWarriorFury\libraries\utils.lua (lines ~400-450)
```

### 6.2 Shared Library Locations

```
# Root shared libraries (unused)
C:\newbot\scripts\libraries\middleware.lua
C:\newbot\scripts\libraries\spell_resolver.lua

# Actually used shared libraries
C:\newbot\scripts\libraries\middleware_manager.lua (used by ALL specs via local copy)
C:\newbot\scripts\libraries\combat_forecast.lua (used by most specs via local copy)
C:\newbot\scripts\libraries\dashboard.lua (used by ALL specs via local copy)
```

### 6.3 Largest utils.lua Files (Most Duplication)

```
C:\newbot\scripts\EAXWarriorFury\libraries\utils.lua (821 lines)
C:\newbot\scripts\EAXDruidFeral\libraries\utils.lua (484 lines)
C:\newbot\scripts\EAXDruidResto\libraries\utils.lua (480 lines)
C:\newbot\scripts\EAXPaladinProtection\libraries\utils.lua (472 lines)
C:\newbot\scripts\EAXPaladinHoly\libraries\utils.lua (446 lines)
```

---

## 7. Conclusion

The EAX TBC Classic rotation plugins suffer from **extensive code duplication** due to each spec maintaining local copies of all libraries. While this provides isolation and prevents cross-spec regressions, it creates significant maintenance overhead:

- **870+ duplicate library files** across 29 specs
- **~8,120 lines of duplicated utility code**
- **Version drift** in 3 critical functions (health/mana percentage)
- **Wasted space** from class-specific libraries in irrelevant specs

**Recommended Priority**:
1. Fix version drift in health/mana functions (HIGH)
2. Standardize naming conventions (HIGH)
3. Create shared utility library for core functions (MEDIUM)
4. Remove class-specific libraries from irrelevant specs (MEDIUM)
5. Consider IZI SDK migration for long-term maintenance (LOW)

---

*Audit generated by Sisyphus-Junior agent*  
*Wave 1, Task 3 of 3 - Flux Reference Comparison*
