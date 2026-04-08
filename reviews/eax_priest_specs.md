# EAX Priest Specs Review

**Review Date:** 2026-04-08  
**Specs Reviewed:** EAXPriestShadow, EAXPriestDiscipline, EAXPriestHoly, EAXPriestSmite  
**Flux Comparison:** flux/rotation/source/aio/priest/*.lua

---

## Executive Summary

All 4 Priest specs use **ps_theme** (Space Theme v4.0) for menu rendering - NOT simple_ui. This is a **critical documentation error** in the original request. The EAX Priest specs have consistent UI architecture using the ps_theme library with space-themed backgrounds (stars, nebula, meteors).

**Key Finding:** EAX Shadow has **channel protection** for Mind Flay anti-clipping; Flux uses framework-level channel handling. EAX healing specs use traditional priority-based rotation; Flux uses strategy registry pattern.

---

## 1. File Structure Comparison

### EAX Priest Specs Structure
```
EAXPriest<Spec>/
├── main.lua                    # Rotation engine (priority-based)
├── header.lua                  # Plugin metadata
├── plugin_info.lua             # Load configuration
└── libraries/
    ├── menu.lua                # ps_theme-based UI (ALL specs)
    ├── ps_theme.lua            # Space theme rendering
    ├── spells.lua              # TBC spell tables
    ├── utils.lua               # Helper functions
    ├── settings_framework.lua  # Keybind management
    ├── middleware_manager.lua  # Healthstones/potions/racials
    ├── dashboard.lua           # Combat HUD
    ├── dashboard_config.lua    # HUD configuration
    ├── ooc_manager.lua         # Out-of-combat buffs
    ├── mana_manager.lua        # Mana recovery
    ├── burst_manager.lua       # CD automation
    ├── trinket_manager.lua     # Trinket automation
    ├── combat_forecast.lua     # TTD tracking
    ├── cc_detector.lua         # Crowd control detection
    └── [spec-specific libs]
```

### Flux Priest Structure
```
flux/rotation/source/aio/priest/
├── class.lua                   # Class registration
├── schema.lua                  # Settings schema
├── middleware.lua              # Shared middleware
├── healing.lua                 # Healing engine integration
├── shadow.lua                  # Shadow rotation (strategy registry)
├── discipline.lua              # Discipline rotation (strategy registry)
├── holy.lua                    # Holy rotation (strategy registry)
└── smite.lua                   # Smite rotation (strategy registry)
```

---

## 2. Menu System Analysis

### CRITICAL FINDING: ps_theme (NOT simple_ui)

**All 4 EAX Priest specs use ps_theme**, not simple_ui. This is a significant deviation from the premise of the review request.

#### ps_theme Features (Space Theme v4.0)
- **Visual Style:** Space/nebula background with animated stars and meteors
- **Implementation:** `libraries/ps_theme.lua` (415 lines)
- **Rendering:** Custom `draw_space()` function with:
  - 160 pre-seeded stars (twinkling animation)
  - 55 dust particles
  - Meteor shower effects (max 4 concurrent)
  - Corner bracket lines with diamond gems
  - Titlebar glow line

#### Menu.lua Pattern (Consistent Across All 4 Specs)
```lua
local ps = require("libraries/ps_theme")
local menu = {}

-- Tree nodes
local root_tree = ps.tree_node()
local rotation_tree = ps.tree_node()
-- ... more trees

-- Controls using core.menu
menu.enabled = core.menu.checkbox(true, "eaxpriest<spec>_enabled")
menu.toggle_key = core.menu.keybind(7, false, "eaxpriest<spec>_toggle_key")

-- Render function
function menu.render()
    if _win and root_tree:is_open() then
        ps.draw_space(_win, "eaxpriest<spec>")  -- Space background
    end
    root_tree:render("Eax's Priest <Spec>", function()
        -- Menu sections using ps.header() for styling
    end)
end
```

#### Flux Menu Pattern (ProfileUI/ps_theme)
Flux uses `profileui` with `ps_theme` styling - **same visual theme, different implementation**:
- Flux: Settings schema in `schema.lua`, rendered by ProfileUI framework
- EAX: Manual menu construction using `core.menu.*` APIs

---

## 3. Flux Comparison: Rotation Architecture

### EAX Shadow vs Flux Shadow

| Aspect | EAX Shadow | Flux Shadow |
|--------|------------|-------------|
| **Architecture** | Priority-based function calls | Strategy registry pattern |
| **State Management** | Manual `runtime` table | `get_shadow_state(context)` builder |
| **Channel Protection** | ✅ Custom implementation (lines 130-189) | ❌ Framework handles channels |
| **DoT Tracking** | `utils.get_debuff_remaining_ms()` | `Unit():HasDeBuffs()` |
| **Rotation Priority** | Hardcoded in `on_update()` | Registered strategies with `matches/execute` |

#### EAX Shadow Channel Protection (Custom Implementation)
```lua
-- EAX Shadow: Lines 130-189 in main.lua
local channel_state = {
    is_channeling = false,
    channel_spell = nil,
    channel_start_time = 0,
    channel_duration = 0,
}

local function should_allow_cast(emergency_only)
    if not runtime.channel_state.is_channeling then return true end
    local remaining = get_channel_remaining()
    if remaining <= 0 then stop_channel(); return true end
    if not emergency_only then return false end
    if remaining > 0.5 then return true end  -- Emergency clip threshold
    return false
end

-- Used in try_mind_blast() and try_shadow_word_death()
if not should_allow_cast(true) then return false end
```

#### Flux Shadow: No Explicit Channel Protection
Flux relies on the framework's `AutoShoot` and internal channel handling. Mind Flay is cast via `try_cast()` without explicit clip protection in the rotation logic.

### EAX Healing Specs vs Flux Healing

| Aspect | EAX Disc/Holy | Flux Disc/Holy |
|--------|---------------|----------------|
| **Healing Engine** | `utils.find_lowest_effective_ally()` | `scan_healing_targets()` + structured entries |
| **Tank Detection** | `utils.get_tank_unit()` | `get_tank_target()` |
| **AoE Detection** | `utils.count_below_hp()` | `count_below_hp()` (shared) |
| **Cast Functions** | `utils.cast_target/self()` | `try_heal_cast_fmt()` |

#### EAX Healing Pattern
```lua
local function try_flash_heal(me)
    local threshold = ((menu.flash_heal_hp_pct and menu.flash_heal_hp_pct:get()) or 50) / 100
    local lowest, lowest_hp = utils.find_lowest_effective_ally(me, threshold, false)
    if not lowest or lowest_hp >= threshold then return false end
    
    if utils.cast_target(resolved.flash_heal, me, lowest) then
        note_cast()
        return true
    end
    return false
end
```

#### Flux Healing Pattern
```lua
named("FlashHeal", {
    matches = function(context, state)
        if not context.in_combat then return false end
        if context.is_moving then return false end
        if not state.lowest then return false end
        local flash_hp = context.settings.disc_flash_heal_hp or 50
        return state.lowest_hp < flash_hp
    end,
    execute = function(icon, context, state)
        local target = state.lowest
        return try_heal_cast_fmt(A.FlashHeal, icon, target.unit, "[P5]", "Flash Heal",
            "on %s (%.0f%%)", target.unit, target.effective_hp)
    end,
})
```

---

## 4. TBC Spell Accuracy

### Verified TBC-Only Spells (No WotLK/Cata)

#### Shadow Spec
| Spell | Spell IDs | TBC Rank Range | Status |
|-------|-----------|----------------|--------|
| Vampiric Touch | 34917, 34916, 34914 | Rank 3 (70) | ✅ TBC |
| Shadow Word: Pain | 25368, 25367, ... | Rank 12 (70) | ✅ TBC |
| Mind Blast | 25375, 25372, ... | Rank 13 (70) | ✅ TBC |
| Mind Flay | 25387, 18807, ... | Rank 7 (70) | ✅ TBC |
| Shadow Word: Death | 32996, 32379 | Rank 2 (70) | ✅ TBC |
| Shadowform | 15473 | Single rank | ✅ TBC |
| Shadowfiend | 34433 | Single rank | ✅ TBC |
| Devouring Plague | 25467, ... | Rank 7 (70) | ✅ TBC (Undead racial) |
| Starshards | 19325, ... | Rank 10 (70) | ✅ TBC (Night Elf racial) |

#### Discipline Spec
| Spell | Status | Notes |
|-------|--------|-------|
| Penance | ❌ REMOVED | WotLK spell (3.0.2) - correctly removed from menu.lua line 71 |
| Divine Aegis | ❌ REMOVED | WotLK talent - correctly removed |
| Pain Suppression | ✅ TBC | 33206 - TBC Discipline talent |
| Power Infusion | ✅ TBC | 10060 - TBC Discipline talent |

#### Holy Spec
| Spell | Status | Notes |
|-------|--------|-------|
| Divine Hymn | ❌ REMOVED | WotLK spell - correctly removed (menu.lua line 211) |
| Circle of Healing | ✅ TBC | 34861 - TBC Holy talent |
| Surge of Light | ✅ TBC | Proc from Holy talent tree |
| Holy Concentration | ✅ TBC | Clearcasting proc |

#### Smite Spec
| Spell | Status | Notes |
|-------|--------|-------|
| Holy Fire | ✅ TBC | 15262 - TBC spell |
| Smite | ✅ TBC | 585 - Base spell |
| Mind Blast | ✅ TBC | Optional hybrid talent |

### Spell Accuracy Score: **100%**
All 4 specs correctly use TBC-era spells only. WotLK spells (Penance, Divine Hymn, Divine Aegis) are explicitly commented as removed.

---

## 5. Compliance Scores

### Syntax & LSP Compliance
| Spec | luac -p | LSP Errors | Status |
|------|---------|------------|--------|
| EAXPriestShadow | ✅ Pass | 0 | Clean |
| EAXPriestDiscipline | ✅ Pass | 0 | Clean |
| EAXPriestHoly | ✅ Pass | 0 | Clean |
| EAXPriestSmite | ✅ Pass | 0 | Clean |

### Menu Nil-Guard Compliance
| Spec | Menu Guards | Pattern Used | Status |
|------|-------------|--------------|--------|
| EAXPriestShadow | ✅ Full | `(menu.x and menu.x:get()) or default` | Compliant |
| EAXPriestDiscipline | ✅ Full | Same pattern | Compliant |
| EAXPriestHoly | ✅ Full | Same pattern | Compliant |
| EAXPriestSmite | ✅ Full | Same pattern | Compliant |

### API Caching Compliance
| Spec | Hot-Path Caching | Cached APIs | Status |
|------|------------------|-------------|--------|
| EAXPriestShadow | ✅ Yes | `_core_time`, `_get_local_player`, `_get_gcd`, `_get_spell_cd` | Compliant |
| EAXPriestDiscipline | ✅ Yes | Same pattern | Compliant |
| EAXPriestHoly | ✅ Yes | Same pattern | Compliant |
| EAXPriestSmite | ✅ Yes | Same pattern | Compliant |

### TBC Spell Accuracy
| Spec | WotLK Spells | TBC Only | Status |
|------|--------------|----------|--------|
| All 4 specs | 0 | 100% | ✅ Perfect |

---

## 6. Key Differences: EAX vs Flux

### 1. Channel Protection (Shadow)
- **EAX:** Custom `channel_state` with `should_allow_cast()` logic
- **Flux:** Relies on framework channel handling
- **Winner:** EAX (more explicit control)

### 2. Menu System
- **EAX:** `ps_theme` with space visuals, manual `core.menu` construction
- **Flux:** `profileui` framework with `ps_theme` styling
- **Winner:** Tie (same visual theme, different implementation)

### 3. Rotation Pattern
- **EAX:** Priority-based function calls in `on_update()`
- **Flux:** Strategy registry with `matches/execute` functions
- **Winner:** Flux (more modular, easier to extend)

### 4. Healing Engine
- **EAX:** `utils.find_lowest_effective_ally()` with HP thresholds
- **Flux:** `scan_healing_targets()` with structured target entries
- **Winner:** Flux (more sophisticated target selection)

### 5. State Management
- **EAX:** Manual `runtime` table with spell resolution at load
- **Flux:** Per-frame state builders (`get_shadow_state`, `get_disc_state`)
- **Winner:** Flux (cleaner separation of concerns)

### 6. Middleware
- **EAX:** `middleware_manager.execute_middleware()` for healthstones/potions
- **Flux:** `rotation_registry:register_middleware()` with priority ordering
- **Winner:** Flux (more flexible middleware system)

---

## 7. Recommendations

### For EAX Priest Specs
1. **Keep ps_theme** - Space theme is visually distinctive and consistent
2. **Consider strategy registry** - Would make rotation logic more modular
3. **Channel protection is valuable** - Keep the Mind Flay anti-clipping logic
4. **TBC accuracy is perfect** - No changes needed

### For Flux Priest Specs
1. **Add explicit channel protection** - EAX's Mind Flay logic could be ported
2. **Keep strategy registry** - More maintainable than priority functions
3. **Healing engine is superior** - EAX could adopt Flux's structured target entries

---

## 8. Documentation Corrections

### Original Request Error
> "Compare: EAX simple_ui vs Flux ps_theme"

**Correction:** EAX Priest specs use **ps_theme**, NOT simple_ui. All 4 specs have space-themed menus with animated stars and meteors.

### Evidence
```lua
-- From EAXPriestShadow/libraries/menu.lua (line 7)
local ps = require("libraries/ps_theme")

-- From EAXPriestShadow/libraries/ps_theme.lua (line 2)
-- ║  Eax's Rotations  ·  Space Theme  ·  ps_theme.lua  v4.0       ║
```

---

## 9. Summary Table

| Metric | EAXPriestShadow | EAXPriestDiscipline | EAXPriestHoly | EAXPriestSmite |
|--------|-----------------|---------------------|---------------|----------------|
| **Menu System** | ps_theme | ps_theme | ps_theme | ps_theme |
| **Rotation Type** | Priority functions | Priority functions | Priority functions | Priority functions |
| **Channel Protection** | ✅ Custom | N/A | N/A | N/A |
| **Healing Engine** | N/A | utils-based | utils-based | N/A |
| **TBC Accuracy** | 100% | 100% | 100% | 100% |
| **Syntax Clean** | ✅ | ✅ | ✅ | ✅ |
| **Nil Guards** | ✅ | ✅ | ✅ | ✅ |
| **API Caching** | ✅ | ✅ | ✅ | ✅ |

---

## 10. Conclusion

All 4 EAX Priest specs are **production-ready** with:
- ✅ Perfect TBC spell accuracy
- ✅ Consistent ps_theme menu system (not simple_ui)
- ✅ Proper nil-guarded menu access
- ✅ Hot-path API caching
- ✅ Clean Lua syntax

**Notable Strengths:**
- EAX Shadow's custom channel protection for Mind Flay
- Consistent visual theme across all specs
- Proper WotLK spell exclusions (Penance, Divine Hymn removed)

**Areas for Future Improvement:**
- Could adopt Flux's strategy registry pattern for more modular rotations
- Could port Flux's structured healing target selection
- Consider adding channel protection to other channeling specs (if any)

---

*Review completed by Sisyphus-Junior*  
*Date: 2026-04-08*
