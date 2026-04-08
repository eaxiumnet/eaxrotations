# Cross-Spec Pattern Analysis
## EAX TBC Classic Rotations - Wave 3 Review

**Analysis Date**: 2026-04-08  
**Specs Analyzed**: 29 (100% coverage)  
**Patterns Reviewed**: 8 categories

---

## Executive Summary

| Pattern | Consistency | Status | Risk Level |
|---------|-------------|--------|------------|
| Menu System (ps_theme) | 100% (29/29) | ✅ Standardized | None |
| Menu Nil Guards | 100% (29/29) | ✅ Standardized | None |
| Health/Mana Percentage Scale | 93% (27/29) | ⚠️ 2 Deviations | **Major** |
| CC Break Helpers | 100% (29/29) | ✅ Standardized | None |
| IZI SDK Adoption | 100% (29/29) | ⚠️ Underutilized | Moderate |
| Middleware Integration | 100% (29/29) | ✅ Standardized | None |
| Burst/Trinket Managers | 100% (29/29) | ✅ Standardized | None |
| Spell Resolution | 100% (29/29) | ✅ Standardized | None |
| Dashboard Integration | 14% (4/29 wired) | ⚠️ Incomplete | Moderate |

**Critical Finding**: Health/mana percentage scale inconsistency (0-1 vs 0-100) creates **high risk of logic bugs** in EAXDruidBear and EAXPriestSmite.

---

## 1. Menu System Consistency

### Pattern: ps_theme vs simple_ui

**Standard**: `ps_theme` (Space Theme v4.0)

| Spec | UI Theme | File | Line |
|------|----------|------|------|
| All 29 specs | ps_theme | `libraries/menu.lua` | 2-7 |

**Adoption Rate**: 100% (29/29 specs use ps_theme)

**No specs use simple_ui** - the codebase has achieved complete standardization on ps_theme.

### Standard Menu Structure

```lua
-- Standard header (all 29 specs)
local ps       = require("libraries/ps_theme")
local settings = require("libraries/settings_framework")
local menu = {}

-- Tree nodes (Standard EAX Menu Structure)
local root_tree      = ps.tree_node()
local rotation_tree  = ps.tree_node()
local cd_tree        = ps.tree_node()
local defensive_tree = ps.tree_node()
local utility_tree   = ps.tree_node()
local buffs_tree     = ps.tree_node()
local automation_tree = ps.tree_node()
local ooc_tree       = ps.tree_node()
local group_tree     = ps.tree_node()
local dashboard_tree = ps.tree_node()
local pvp_tree       = ps.tree_node()
local advanced_tree  = ps.tree_node()

-- Standard controls with nil guards
menu.enabled    = core.menu.checkbox(true,  "eax<spec>_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eax<spec>_toggle_key")
menu.mode       = core.menu.combobox(1, "eax<spec>_mode")  -- 1=Auto, 2=PvE, 3=PvP
```

### Deviations Found

#### Minor: EAXPaladinHoly settings_tree Anomaly
**File**: `EAXPaladinHoly/libraries/menu.lua:28-33`
**Issue**: References undefined variables
```lua
local settings_tree = {
    targeting = tgt_tree,      -- ERROR: tgt_tree undefined
    racial = racial_tree,      -- ERROR: racial_tree undefined
    ooc = ooc_tree,
    display = esp_tree,        -- ERROR: esp_tree undefined
}
```
**Impact**: Unused legacy code - no runtime effect
**Recommendation**: Remove unused table

#### Minor: EAXMageFrost Menu Items in Render
**File**: `EAXMageFrost/libraries/menu.lua:212-230`
**Issue**: Menu items declared inside `menu.render()` instead of module level
**Impact**: Functional but non-standard pattern
**Recommendation**: Move declarations to module level for consistency

#### Minor: EAXPriest Duplicate Declarations
**Files**: 
- `EAXPriestDiscipline/libraries/menu.lua:126-142`
- `EAXPriestHoly/libraries/menu.lua:133-142`
**Issue**: Healthstone and healing potion declared twice
**Impact**: Last declaration wins - functional but confusing
**Recommendation**: Consolidate duplicate declarations

---

## 2. Health/Mana Percentage Return Values

### Critical Inconsistency Detected

**Standard Pattern**: 0-1 scale (decimal: 0.5 = 50%)
**Deviations**: 0-100 scale (percentage: 50 = 50%)

### Health Percentage by Spec

#### 0-1 Scale (27 specs - STANDARD)
| Spec | Function | File | Line | Return Value |
|------|----------|------|------|--------------|
| EAXDruidBalance | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXDruidFeral | `utils.get_health_pct(unit)` | utils.lua | 62-68 | `hp / max` |
| EAXDruidResto | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXHunterBM | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXHunterMM | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXHunterSurvival | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXMageArcane | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXMageFire | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXMageFrost | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXPriestDiscipline | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXPriestHoly | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXPriestShadow | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXPaladinHoly | `utils.get_health_pct(unit)` | utils.lua | 59-65 | `hp / max` |
| EAXPaladinProtection | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXPaladinRetribution | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXRogueAssassination | `utils.get_health_pct(unit)` | utils.lua | 61-67 | `hp / max` |
| EAXRogueCombat | `utils.get_health_pct(unit)` | utils.lua | 61-67 | `hp / max` |
| EAXRogueSubtlety | `utils.get_health_pct(unit)` | utils.lua | 61-67 | `hp / max` |
| EAXShamanElemental | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXShamanEnhancement | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXShamanRestoration | `utils.get_health_pct(unit)` | utils.lua | 56-62 | `hp / max` |
| EAXWarlockAffliction | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXWarlockDemonology | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXWarlockDestruction | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXWarriorArms | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXWarriorFury | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |
| EAXWarriorProtection | `utils.get_health_pct(unit)` | utils.lua | 53-59 | `hp / max` |

#### 0-100 Scale (2 specs - **MAJOR DEVIATION**)
| Spec | Function | File | Line | Return Value | Severity |
|------|----------|------|------|--------------|----------|
| **EAXDruidBear** | `utils.get_health_percentage(me)` | utils.lua | 58-66 | `(hp / max_hp) * 100` | **Major** |
| **EAXPriestSmite** | `utils.get_health_percentage(me)` | utils.lua | 45-53 | `(hp / max_hp) * 100` | **Major** |

### Mana Percentage by Spec

#### 0-1 Scale (10 specs - STANDARD)
| Spec | Function | File | Line |
|------|----------|------|------|
| EAXDruidBalance | `utils.mana_pct(me)` | utils.lua | 203-212 |
| EAXDruidFeral | `utils.mana_pct(me)` | utils.lua | 223-231 |
| EAXDruidResto | `utils.mana_pct(me)` | utils.lua | 203-212 |
| EAXHunterBM | `utils.mana_pct(me)` | utils.lua | 203-212 |
| EAXHunterMM | `utils.mana_pct(me)` | utils.lua | 203-212 |
| EAXHunterSurvival | `utils.mana_pct(me)` | utils.lua | 203-212 |
| EAXPaladinRetribution | `utils.mana_pct(me)` | utils.lua | 203-212 |
| EAXRogueAssassination | `utils.mana_pct(me)` | utils.lua | 222-231 |
| EAXRogueCombat | `utils.mana_pct(me)` | utils.lua | 222-231 |
| EAXRogueSubtlety | `utils.mana_pct(me)` | utils.lua | 222-231 |

#### 0-100 Scale (1 spec - **MAJOR DEVIATION**)
| Spec | Function | File | Line | Severity |
|------|----------|------|------|----------|
| **EAXPriestSmite** | `utils.get_mana_pct(me)` | utils.lua | 32-40 | **Major** |

### Bug Risk Analysis

**Critical Issue**: Code comparing health percentages against thresholds like `if health_pct < 0.5` will behave incorrectly if passed a 0-100 scale value.

**Example Bug Scenario**:
```lua
-- In EAXDruidBear (uses 0-100 scale)
local hp_pct = utils.get_health_percentage(me)  -- Returns 50 for 50% health
if hp_pct < 0.5 then  -- 50 < 0.5 is FALSE
    -- Defensive logic NEVER triggers!
end
```

### Standardization Recommendation

**Priority**: HIGH  
**Action**: Standardize all specs to 0-1 scale

1. **EAXDruidBear**: Change `utils.get_health_percentage()` to return 0-1
2. **EAXPriestSmite**: Change both health and mana functions to return 0-1
3. **Audit threshold comparisons** in affected specs to verify current logic

---

## 3. CC Break Helper Patterns

### Standard: Centralized CC Detection

**All 29 specs** use the centralized `cc_detector.lua` module:

| Component | File | Coverage |
|-----------|------|----------|
| cc_detector | `libraries/cc_detector.lua` | 29/29 (100%) |
| PvP Trinket Menu | `libraries/menu.lua` | 29/29 (100%) |

### CC Detection API

```lua
-- Standard CC detection (all 29 specs)
local cc_detector = require("libraries/cc_detector")

-- Key functions
cc_detector.is_ccd(unit)                    -- Generic CC check
cc_detector.should_stop_rotation(unit)        -- Stop rotation when CC'd
cc_detector.is_stunned()                      -- Stun detection
cc_detector.is_silenced()                     -- Silence detection
cc_detector.is_feared()                       -- Fear detection
cc_detector.is_rooted()                       -- Root detection
cc_detector.has_cc_type(unit, cc_type)        -- Generic CC type check
```

### Class-Specific CC Break Functions

| Class | CC Break Ability | Specs | Implementation |
|-------|-----------------|-------|----------------|
| **Paladin** | Divine Shield | Holy, Prot, Ret | `utils.try_divine_shield_cc_break()` |
| **Warrior** | Berserker Rage | Arms, Fury, Prot | Inline in pvp_manager (archive) |
| **Rogue** | Vanish/Cloak | All 3 specs | middleware_manager.lua |
| **Mage** | Ice Block | All 3 specs | middleware_manager.lua |
| **Druid** | Form Shifting | All 4 specs | Implicit via forms |
| **Priest** | Fear Ward | All 4 specs | Not explicitly implemented |

### Best Practice: Paladin CC Break Integration

**File**: `EAXPaladinRetribution/main.lua:420-435`

```lua
-- CC Detection: Stop rotation if crowd controlled
local cc_detector = require("libraries/cc_detector")
local should_stop, cc_reason = cc_detector.should_stop_rotation(me)

-- Paladin special: Try Divine Shield for any CC before stopping
if should_stop then
    if utils.try_divine_shield_cc_break(me, menu) then
        return  -- Successfully broke CC
    end
end

if should_stop then
    return  -- Stop rotation while CC'd
end
```

### PvP Trinket Menu Options

All 29 specs have PvP trinket support:

```lua
-- Standard pattern (EAXWarriorFury/libraries/menu.lua:160)
menu.pvp_trinket_defensive = core.menu.checkbox(true, "eaxwarriorfury_pvp_trinket_defensive")

-- Alternative pattern (EAXDruidBalance/libraries/menu.lua:151)
menu.pvp_use_trinket = core.menu.checkbox(true, "eaxdruidbalance_pvp_use_trinket")
```

### Gaps Identified

| Gap | Affected Specs | Recommendation |
|-----|---------------|----------------|
| No Fear Ward CC break | All 4 Priest specs | Add proactive Fear Ward usage |
| No Berserker Rage (current) | All 3 Warrior specs | Add fear break to current specs |
| No Form Shift root break | All 4 Druid specs | Add explicit root break logic |

---

## 4. IZI SDK Adoption

### Adoption Summary

| Level | Count | Specs |
|-------|-------|-------|
| **PARTIAL** | 29/29 | All specs (library-only) |
| **FULL** | 0/29 | None (no event callbacks) |
| **NONE** | 0/29 | None (all have some IZI) |

### IZI Feature Usage Matrix

| Feature | Usage | Files | Status |
|---------|-------|-------|--------|
| `require("common/izi_sdk")` | 153 files | All library files | ✅ Universal |
| `izi.spell(id)` | 29 specs | utils.lua | ✅ Universal |
| `izi.item(id)` | 29 specs | trinket_manager.lua | ✅ Universal |
| `izi.on_buff_gain` | 0 specs | None | ❌ Not adopted |
| `izi.on_spell_success` | 0 specs | None | ❌ Not adopted |
| `izi.on_combat_start` | 0 specs | None | ❌ Not adopted |
| `izi.pick_enemy()` | 0 specs | None | ❌ Not adopted |
| `izi.ts()` | 0 specs | None | ❌ Not adopted |
| `izi.draw_icon()` | 0 specs | None | ❌ Not adopted |
| `izi.me()` | 0 specs in main | None | ❌ Not adopted |

### Current IZI Usage Pattern

**File**: `EAXWarriorFury/libraries/utils.lua:143-159`

```lua
-- IZI SDK spell caching (all 29 specs)
local izi = require("common/izi_sdk")
local cached_spells = {}

local function get_izi_spell(spell_id)
    if not spell_id then return nil end
    if not cached_spells[spell_id] then
        cached_spells[spell_id] = izi.spell(spell_id)
    end
    return cached_spells[spell_id]
end

-- Usage in cast functions
function utils.cast_self(spell_id, me)
    local izi_spell = get_izi_spell(spell_id)
    if izi_spell:is_learned() and izi_spell:is_castable_to_unit(me) then
        return izi_spell:cast_safe(me, "[Self] Cast")
    end
    return false
end
```

### Most IZI Integration

**EAXPriestSmite** - Only spec using IZI in main.lua:

**File**: `EAXPriestSmite/main.lua:167`
```lua
local izi_spell = izi.spell(spell_id)
```

### Standardization Opportunity

**Priority**: MODERATE  
**Recommendation**: Migrate from polling-based architecture to IZI event-driven model

1. **Event Callbacks**: Replace buff polling with `izi.on_buff_gain()`
2. **Smart Targeting**: Replace manual scanning with `izi.pick_enemy()`
3. **Unit Helpers**: Replace `core.object_manager.get_local_player()` with `izi.me()`
4. **Graphics**: Use `izi.draw_spell_icon()` for HUD rendering

---

## 5. Middleware Integration Depth

### Universal Middleware Stack

**All 29 specs** use identical heavy middleware integration:

| Middleware | File | Adoption | Purpose |
|------------|------|----------|---------|
| **spell_resolver** | `libraries/spell_resolver.lua` | 29/29 (100%) | Talent-based spell resolution |
| **buff_manager** | `common/modules/buff_manager` | 29/29 (100%) | Aura/buff tracking |
| **spell_queue** | `common/modules/spell_queue` | 29/29 (100%) | Ability queuing |
| **target_selector** | `common/modules/target_selector` | 29/29 (100%) | Healing target selection |
| **heal_utils** | `libraries/heal_utils.lua` | 29/29 (100%) | Healing utilities |
| **heal_context** | `libraries/heal_context.lua` | 29/29 (100%) | Healing context |
| **ooc_manager** | `libraries/ooc_manager.lua` | 29/29 (100%) | Out-of-combat management |
| **middleware.lua** | `libraries/middleware.lua` | 29/29 (100%) | Core rotation middleware |
| **context_builder** | `libraries/context_builder.lua` | 29/29 (100%) | Combat context |
| **cc_detector** | `libraries/cc_detector.lua` | 29/29 (100%) | CC detection |
| **hot_manager** | `libraries/hot_manager.lua` | 29/29 (100%) | HoT tracking |

### Middleware Integration Pattern

**File**: `EAXWarriorFury/libraries/utils.lua:1-5`

```lua
-- Standard middleware requires (all 29 specs)
local buff_manager = require("common/modules/buff_manager")
local spell_queue = require("common/modules/spell_queue")
local spell_resolver = require("libraries/spell_resolver")
```

### No Variation Detected

All 29 specs have **identical** middleware integration depth. There are no "light" vs "heavy" integration specs - all use the complete stack.

---

## 6. Burst/Trinket Manager Usage

### Universal Burst System

**All 29 specs** have complete burst/trinket management:

| Component | File | Coverage |
|-----------|------|----------|
| **burst_manager** | `libraries/burst_manager.lua` | 29/29 (100%) |
| **trinket_manager** | `libraries/trinket_manager.lua` | 29/29 (100%) |
| **force_commands** | `libraries/force_commands.lua` | 29/29 (100%) |
| **combat_forecast** | `libraries/combat_forecast.lua` | 29/29 (100%) |
| **racial_manager** | `libraries/racial_manager.lua` | 29/29 (100%) |

### Standard Menu Toggles

**File**: `EAXWarriorFury/libraries/menu.lua:127-134`

```lua
-- Burst & Trinket Automation (all 29 specs)
menu.auto_burst_enabled     = core.menu.checkbox(false, "eax<class><spec>_auto_burst")
menu.burst_on_bloodlust     = core.menu.checkbox(true, "eax<class><spec>_burst_bloodlust")
menu.burst_on_pull          = core.menu.checkbox(true, "eax<class><spec>_burst_pull")
menu.burst_on_execute       = core.menu.checkbox(true, "eax<class><spec>_burst_execute")
menu.burst_in_combat        = core.menu.checkbox(false, "eax<class><spec>_burst_always")
menu.cd_min_ttd             = core.menu.slider_int(0, 60, 0, "eax<class><spec>_cd_min_ttd")
menu.trinket1_mode          = core.menu.combobox(1, "eax<class><spec>_trinket1_mode")
menu.trinket2_mode          = core.menu.combobox(1, "eax<class><spec>_trinket2_mode")
```

### Burst Detection Logic

**File**: `libraries/burst_manager.lua:36-87`

```lua
function burst_manager.should_auto_burst(me, target, combat_time, menu)
    -- Check if auto-burst enabled
    local auto_burst = (menu.auto_burst_enabled and menu.auto_burst_enabled:get_state()) or false
    if not auto_burst then return false, nil end
    
    -- TTD gating - don't waste CDs on dying targets
    local min_ttd = (menu.cd_min_ttd and menu.cd_min_ttd:get()) or 0
    if min_ttd > 0 and target then
        local forecast = require("combat_forecast")
        if not forecast:is_valid_forecast_logic(min_ttd, target, false) then
            return false, "ttd"
        end
    end
    
    -- Bloodlust check
    local burst_on_bloodlust = (menu.burst_on_bloodlust and menu.burst_on_bloodlust:get_state()) or false
    if burst_on_bloodlust and burst_manager.has_bloodlust(me) then
        return true, "bloodlust"
    end
    
    -- Pull window check (first 5 seconds)
    local burst_on_pull = (menu.burst_on_pull and menu.burst_on_pull:get_state()) or false
    if burst_on_pull and combat_time < 5 then return true, "pull" end
    
    -- Execute phase check (<20% HP)
    local burst_on_execute = (menu.burst_on_execute and menu.burst_on_execute:get_state()) or false
    if burst_on_execute and target then
        local target_hp_pct = (target:get_health() / target:get_max_health()) * 100
        if target_hp_pct < 20 then return true, "execute" end
    end
    
    return false, nil
end
```

### Manual Override Commands

All 29 specs support:
- `/eax burst` - Force burst mode for 3 seconds
- `/eax def` - Force defensive mode for 3 seconds

**File**: `libraries/force_commands.lua:20-55`

```lua
-- Parse /eax burst
if msg:match("^/eax%s+burst") or msg:match("^/eax%s+offensive") then
    force_commands.flags.burst = _core_time() + force_commands.DURATION
    _core_log("[EAX] Burst mode activated for 3 seconds")
    return
end

-- Parse /eax def
if msg:match("^/eax%s+def") or msg:match("^/eax%s+defensive") then
    force_commands.flags.defensive = _core_time() + force_commands.DURATION
    _core_log("[EAX] Defensive mode activated for 3 seconds")
    return
end
```

---

## 7. Spell Resolution Patterns

### Standard Pattern: Throttled Resolution

**All 29 specs** use the same spell resolution architecture:

1. **Spell tables** in `spells.lua` define rank arrays (highest-first)
2. **utils.resolve_spell_id()** resolves highest learned rank
3. **Throttled resolution** in main.lua (1.0s interval)
4. **Pre-cast validation** before casting

### Spell Table Organization

**File**: `EAXWarriorFury/libraries/spells.lua:8-43`

```lua
-- Rank tables - highest rank first (descending order)
spells.BLOODTHIRST = { 30335, 23894, 23893, 23892, 25251, 23881 }
spells.WHIRLWIND = { 1680 }
spells.EXECUTE = { 25236, 25234, 20662, 20661, 20660, 20658, 5308 }

-- Buff tables
spells.BUFF_BATTLE_SHOUT = { 25289, 2048, 11551, 11549, 6192, 6673 }
spells.BUFF_BERSERKER_STANCE = { 2458 }

-- Debuff tables
spells.DEBUFF_DEMORALIZING_SHOUT = { 25202, 11556, 11555, 11554, 1160 }
spells.DEBUFF_SUNDER_ARMOR = { 25225, 11597, 11596, 7405, 7386, 58567 }

-- Talent-gated spells (implicit talent detection)
spells.RAMPAGE = { 30033, 30030, 29801 }  -- Only available if talented
```

### Resolution Function

**File**: `EAXWarriorFury/libraries/utils.lua:39-51`

```lua
function utils.resolve_spell_id(rank_table)
    if not rank_table then return nil end
    if type(rank_table) == "number" then
        return core.spell_book.is_spell_learned(rank_table) and rank_table or nil
    end
    for i = 1, #rank_table do
        local spell_id = rank_table[i]
        if spell_id and core.spell_book.is_spell_learned(spell_id) then
            return spell_id
        end
    end
    return nil
end
```

### Runtime Resolution Pattern

**File**: `EAXWarriorFury/main.lua:75-103`

```lua
-- Runtime spell spec table
local RUNTIME_SPELL_SPECS = {
    { field = "bloodthirst_id", ranks = spells.BLOODTHIRST },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
    { field = "execute_id", ranks = spells.EXECUTE },
    -- ... 18 total specs
}

-- Throttled resolution (1.0s interval)
local function resolve_spells()
    local now = _core_time()
    if (now - rt.last_spell_refresh) < SPELL_REFRESH then return end
    rt.last_spell_refresh = now
    
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
end
```

### Pre-Cast Validation

**File**: `EAXWarriorFury/libraries/utils.lua:75-82`

```lua
function utils.can_cast_target(spell_id, me, target)
    if not spell_id or not me or not target then return false end
    if not core.spell_book.is_spell_learned(spell_id) then return false end
    if core.spell_book.get_spell_cooldown(spell_id) > 0 then return false end
    if not core.spell_book.is_usable_spell(spell_id) then return false end
    if not core.spell_book.is_spell_in_range(spell_id, target, me) then return false end
    return true
end
```

### spell_resolver.lua Underutilization

**Finding**: All 29 specs have `spell_resolver.lua` but primarily use direct `core.spell_book.is_spell_learned()` calls via `utils.resolve_spell_id()`.

**Recommendation**: Either migrate to spell_resolver caching or remove unused files.

---

## 8. Dashboard Integration Patterns

### Current State

| Component | File Coverage | Main.lua Wired | Status |
|-----------|---------------|----------------|--------|
| dashboard.lua | 29/29 (100%) | 4/29 (14%) | Incomplete |
| dashboard_config.lua | 29/29 (100%) | 4/29 (14%) | Incomplete |
| menu dashboard_tree | 11/29 (38%) | N/A | Partial |

### Specs with Full Dashboard Integration

| Spec | Main.lua Wired | Menu Tree | Config |
|------|---------------|-----------|--------|
| **EAXPaladinRetribution** | ✅ Yes | ✅ Yes | ✅ Complete |
| **EAXPriestSmite** | ✅ Yes | ❌ No | ✅ Complete |
| **EAXHunterMM** | ✅ Yes | ✅ Yes | ✅ Complete |
| **EAXHunterSurvival** | ✅ Yes | ✅ Yes | ✅ Complete |

### Specs with Partial Integration (Files Only)

| Spec | Dashboard File | Config File | Menu Tree | Main.lua |
|------|---------------|-------------|-----------|----------|
| EAXWarriorFury | ✅ | ✅ | ✅ | ❌ |
| EAXWarriorArms | ✅ | ✅ | ✅ | ❌ |
| EAXWarriorProtection | ✅ | ✅ | ✅ | ❌ |
| EAXPaladinHoly | ✅ | ✅ | ❓ | ❌ |
| EAXPaladinProtection | ✅ | ✅ | ✅ | ❌ |
| EAXHunterBM | ✅ | ✅ | ✅ | ❌ |
| EAXDruidBalance | ✅ | ✅ | ✅ | ❌ |
| EAXDruidBear | ✅ | ✅ | ✅ | ❌ |
| EAXDruidResto | ✅ | ✅ | ✅ | ❌ |
| + 16 others | ✅ | ✅ | ❌ | ❌ |

### Dashboard Configuration Best Practice

**File**: `EAXPaladinRetribution/libraries/dashboard_config.lua:1-156`

```lua
return {
    class_name = "Paladin Retribution",
    class_id = 2,
    resource_type = "mana",
    
    -- Cooldown tracking
    cooldowns = { 35395, 31884, 642, 1022, 19752, 10308, 20271, 53408 },
    
    -- Buff monitoring
    buffs = {
        {id = 31884, label = "Avenging Wrath"},
        {id = 20049, label = "Vengeance"},
        {id = 20375, label = "Seal of Command"},
    },
    
    -- Debuff monitoring
    debuffs = {
        {id = 25771, label = "Forbearance"},
        {id = 20185, label = "Judgement of Light"},
    },
    
    -- Custom dynamic lines
    custom_lines = {
        function(ctx)
            local me = core.object_manager.get_local_player()
            if utils.has_buff(me, spells.BUFF_SEAL_OF_COMMAND) then
                return "Seal", "Command"
            elseif utils.has_buff(me, spells.BUFF_SEAL_OF_BLOOD) then
                return "Seal", "Blood"
            end
        end,
        function(ctx)
            local stacks = utils.get_aura_stacks(me, spells.BUFF_VENGEANCE_TALENT[1]) or 0
            return "Vengeance", tostring(stacks) .. "/5"
        end,
    },
    
    -- Feature toggles
    show_timer_bars = true,
    show_action_history = true,
    enable_smart_collapse = true,
}
```

### Main.lua Integration Pattern

**File**: `EAXPriestSmite/main.lua:10,758-760`

```lua
-- Top of main.lua
local dashboard = require("libraries/dashboard")
local dashboard_config = require("libraries/dashboard_config")

-- In on_update() or initialization
dashboard.init(dashboard_config)
dashboard.set_enabled((menu.show_dashboard and menu.show_dashboard:get_state()) or true)
```

### Menu Dashboard Tree

**File**: `EAXWarriorFury/libraries/menu.lua:383-385`

```lua
dashboard_tree:render("Dashboard", function()
    menu.show_dashboard:render("Show Dashboard", "Enable in-game HUD")
end)
```

### Standardization Gap

**Priority**: MODERATE  
**Issue**: 25 specs have dashboard files but aren't wired to main.lua

**Recommendation**: Add to all 29 specs:
1. `dashboard.init(dashboard_config)` in main.lua
2. `dashboard.set_enabled()` with menu toggle
3. `dashboard.render()` in on_update() if needed

---

## Deviation Severity Classification

### Major Deviations (Require Immediate Action)

| # | Pattern | Affected Specs | Risk | Action Required |
|---|---------|---------------|------|-----------------|
| 1 | **Health/Mana 0-100 Scale** | EAXDruidBear, EAXPriestSmite | **Critical** | Standardize to 0-1 scale |

**Risk**: Logic bugs where threshold comparisons fail (e.g., `50 < 0.5` is false)

### Moderate Deviations (Should Address)

| # | Pattern | Affected Specs | Risk | Action Required |
|---|---------|---------------|------|-----------------|
| 2 | **Dashboard Not Wired** | 25/29 specs | Medium | Add dashboard.init() to main.lua |
| 3 | **IZI SDK Underutilized** | All 29 specs | Low | Migrate to event-driven architecture |
| 4 | **spell_resolver Unused** | All 29 specs | Low | Either use caching or remove files |

### Minor Deviations (Cleanup When Convenient)

| # | Pattern | Affected Specs | Risk | Action Required |
|---|---------|---------------|------|-----------------|
| 5 | **Menu Items in Render** | EAXMageFrost | Low | Move to module level |
| 6 | **Duplicate Menu Declarations** | EAXPriestDiscipline, EAXPriestHoly | Low | Consolidate duplicates |
| 7 | **Unused settings_tree** | EAXPaladinHoly | None | Remove dead code |

---

## Standardization Recommendations

### Immediate (Wave 4)

1. **Fix Health/Mana Scale Inconsistency**
   - Modify EAXDruidBear `utils.get_health_percentage()` to return 0-1
   - Modify EAXPriestSmite `utils.get_health_percentage()` and `utils.get_mana_pct()` to return 0-1
   - Audit all threshold comparisons in affected specs

### Short-term (Wave 5)

2. **Complete Dashboard Integration**
   - Wire dashboard to main.lua in remaining 25 specs
   - Add dashboard_tree to menu.lua where missing
   - Standardize dashboard toggle naming

3. **CC Break Helper Gaps**
   - Add Fear Ward usage to Priest specs
   - Add Berserker Rage fear break to Warrior specs
   - Add explicit form shift root break to Druid specs

### Long-term (Wave 6+)

4. **IZI SDK Migration**
   - Replace buff polling with `izi.on_buff_gain()` callbacks
   - Replace manual targeting with `izi.pick_enemy()`
   - Replace `core.object_manager` calls with `izi.me()`, `izi.target()`
   - Use `izi.draw_spell_icon()` for HUD rendering

5. **Code Cleanup**
   - Remove or utilize spell_resolver.lua caching
   - Consolidate duplicate menu declarations
   - Remove unused settings_tree code

---

## Best Practice Examples by Pattern

### Menu System
**Spec**: EAXWarriorFury  
**File**: `libraries/menu.lua:1-400`  
**Strengths**: Complete tree structure, nil guards, standardized categories

### Health Percentage (0-1 Scale)
**Spec**: EAXWarriorFury  
**File**: `libraries/utils.lua:53-59`  
**Pattern**: `hp / max` returning decimal

### CC Break Integration
**Spec**: EAXPaladinRetribution  
**File**: `main.lua:420-435`  
**Pattern**: Try Divine Shield before stopping rotation

### IZI SDK Usage
**Spec**: EAXPriestSmite  
**File**: `main.lua:167`  
**Pattern**: `local izi_spell = izi.spell(spell_id)`

### Middleware Integration
**Spec**: EAXWarriorFury  
**File**: `libraries/utils.lua:1-5`  
**Pattern**: Standard requires for buff_manager, spell_queue, spell_resolver

### Burst/Trinket Management
**Spec**: EAXWarriorFury  
**File**: `libraries/menu.lua:127-134`  
**Pattern**: Complete menu toggles for all burst conditions

### Spell Resolution
**Spec**: EAXDruidBalance  
**File**: `main.lua:74-95`  
**Pattern**: Throttled resolution with 1.0s refresh interval

### Dashboard Configuration
**Spec**: EAXPaladinRetribution  
**File**: `libraries/dashboard_config.lua:1-156`  
**Pattern**: Custom lines, complete cooldown/buff/debuff tracking

---

## Appendix: Pattern Consistency Matrix

| Pattern | Standard | Deviations | Severity | Files to Review |
|---------|----------|------------|----------|-----------------|
| Menu System | ps_theme | 0 | None | N/A |
| Menu Nil Guards | 100% | 0 | None | N/A |
| Health Pct Scale | 0-1 | 2 specs (0-100) | **Major** | EAXDruidBear/utils.lua:58, EAXPriestSmite/utils.lua:45 |
| Mana Pct Scale | 0-1 | 1 spec (0-100) | **Major** | EAXPriestSmite/utils.lua:32 |
| CC Detection | cc_detector | 0 | None | N/A |
| IZI SDK | Partial | 0 (all same) | Moderate | All main.lua files |
| Middleware | Full stack | 0 | None | N/A |
| Burst System | Complete | 0 | None | N/A |
| Spell Resolution | Throttled | 0 | None | N/A |
| Dashboard | Files exist | 25 not wired | Moderate | All main.lua files |

---

## File References Summary

### Critical Files (Require Attention)
- `EAXDruidBear/libraries/utils.lua:58` - Health percentage 0-100 scale
- `EAXPriestSmite/libraries/utils.lua:32` - Mana percentage 0-100 scale
- `EAXPriestSmite/libraries/utils.lua:45` - Health percentage 0-100 scale

### Best Practice Reference Files
- `EAXWarriorFury/libraries/menu.lua` - Complete menu structure
- `EAXWarriorFury/libraries/utils.lua:53-59` - Health percentage 0-1 scale
- `EAXPaladinRetribution/main.lua:420-435` - CC break integration
- `EAXDruidBalance/main.lua:74-95` - Throttled spell resolution
- `EAXPaladinRetribution/libraries/dashboard_config.lua` - Dashboard configuration

### Shared Library Files
- `libraries/burst_manager.lua` - Burst detection
- `libraries/trinket_manager.lua` - Trinket automation
- `libraries/force_commands.lua` - Manual burst commands
- `libraries/combat_forecast.lua` - TTD calculation
- `libraries/middleware.lua` - Cross-cutting concerns
- `libraries/dashboard.lua` - HUD rendering
- `libraries/cc_detector.lua` - CC detection

---

*Document generated from Wave 3 cross-spec pattern analysis*  
*All 29 EAX TBC Classic rotation specs analyzed*  
*8 pattern categories reviewed*
