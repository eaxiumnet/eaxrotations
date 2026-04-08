# EAX Rogue Specs Review — Flux Comparison Analysis

**Review Date:** 2026-04-08  
**Specs Analyzed:** EAXRogueAssassination, EAXRogueCombat, EAXRogueSubtlety  
**Flux Reference:** flux/rotation/source/aio/rogue/*.lua  
**Reviewer:** Sisyphus-Junior  

---

## Executive Summary

| Spec | Lines | Flux Adherence | Energy Tick | Combo Point Handling | Overall Score |
|------|-------|----------------|-------------|---------------------|---------------|
| **Assassination** | 452 | 65% | ✅ Integrated | ⚠️ Inline checks | **B+** |
| **Combat** | 485 | 68% | ✅ Integrated | ⚠️ Inline checks | **B+** |
| **Subtlety** | 515 | 62% | ✅ Integrated | ⚠️ Inline checks | **B** |

**Key Finding:** All three specs successfully integrate Flux libraries (`energy_tick`, `swing_manager`, `combat_forecast`, `force_commands`) but lack the formalized **Strategy Registry pattern** and **state-based pooling** that Flux employs.

---

## 1. File Structure Comparison

### 1.1 EAX Structure (Imperative Pattern)

```
EAXRogue<Spec>/
├── main.lua              # Monolithic on_update() loop
├── libraries/
│   ├── spells.lua        # Spell ID tables
│   ├── utils.lua         # Helper functions
│   ├── menu.lua          # Settings UI
│   ├── energy_tick.lua   # Flux: Energy tick tracking
│   ├── swing_manager.lua # Flux: Swing timing
│   ├── combat_forecast.lua # Flux: TTD prediction
│   ├── force_commands.lua  # Flux: Manual burst
│   ├── burst_manager.lua   # EAX: Auto burst logic
│   ├── trinket_manager.lua # EAX: Trinket automation
│   └── ...
```

**Characteristics:**
- Single `on_update()` function with sequential priority checks
- Runtime spell cache table (`runtime = {}`)
- Individual `try_*` functions per ability
- Direct menu access with nil guards: `(menu.x and menu.x:get()) or default`

### 1.2 Flux Structure (Strategy Registry Pattern)

```
flux/rotation/source/aio/rogue/
├── common.lua            # Constants, ENERGY.*, BUFF_ID.*
├── schema.lua            # Settings schema
├── middleware.lua        # Shared recovery/buff logic
├── class.lua             # register_class() with playstyles
├── assassination.lua     # Strategy table array
├── combat.lua            # Strategy table array
└── subtlety.lua          # Strategy table array
```

**Characteristics:**
- Strategy objects with `matches()` and `execute()` functions
- Pre-allocated state tables (no inline `{}` in combat)
- `context_builder` function for state caching
- `check_prerequisites` for validation gates
- `rotation_registry:register()` for formal registration

---

## 2. Energy Tick Integration Comparison

### 2.1 EAX Implementation

**All 3 specs use identical energy tick integration:**

```lua
-- Library import
local energy_tick = require("libraries/energy_tick")

-- In on_update():
energy_tick:update(me:get_power(3))

-- Before expensive abilities:
if (menu.use_energy_tick and menu.use_energy_tick:get()) then
    if energy_tick:should_delay_action() then return end
end
```

**Energy Cost Checks (Hardcoded):**
| Ability | Assassination | Combat | Subtlety |
|---------|--------------|--------|----------|
| Mutilate | 55 energy | — | — |
| Sinister Strike | 45 energy | 45 energy | 45 energy |
| Backstab | 60 energy | 60 energy | 60 energy |
| Hemorrhage | — | — | 35 energy |
| Shiv | — | 40 energy | — |
| Ghostly Strike | — | — | 40 energy |

### 2.2 Flux Implementation

**Energy is passed via context (handled at core level):**

```lua
-- In strategy matches():
matches = function(context, state)
    return context.energy >= Constants.ENERGY.MUTILATE
end

-- Constants centralized in common.lua:
ENERGY = {
    MUTILATE = 55,
    SINISTER_STRIKE = 45,
    BACKSTAB = 60,
    HEMORRHAGE = 35,
    -- etc.
}
```

**Pooling State Pattern:**
```lua
-- State table tracks pooling flag
local combat_state = {
    pooling = false,
}

-- Builders check pooling gate:
matches = function(context, state)
    if state.pooling then return false end  -- Wait for energy tick
    if context.cp >= 5 then return false end
    return context.energy >= Constants.ENERGY.SINISTER_STRIKE
end

-- Pooling set when finisher can't be executed:
execute = function(icon, context, state)
    if context.energy >= Constants.ENERGY.SLICE_AND_DICE then
        return A.SliceAndDice:Show(icon), "..."
    end
    state.pooling = true  -- Not enough energy, pool for tick
    return nil
end
```

### 2.3 Comparison Matrix

| Aspect | EAX | Flux | Assessment |
|--------|-----|------|------------|
| Energy Tick Library | ✅ Used | ✅ Core-level | Both integrate |
| Delay Mechanism | `should_delay_action()` | `state.pooling` | Different approaches |
| Energy Constants | Hardcoded | Centralized | Flux more maintainable |
| Pooling Logic | Implicit (early return) | Explicit state flag | Flux clearer intent |
| Menu Toggle | `use_energy_tick:get()` | Automatic via pooling | EAX more configurable |

---

## 3. Combo Point Handling Patterns

### 3.1 EAX Implementation

**Runtime tracking:**
```lua
local runtime = {
    combo_points = 0,
    -- ...
}

-- Updated per-frame:
runtime.combo_points = utils.get_combo_points(me)
```

**Finisher threshold checks (per-ability):**
```lua
local function try_slice_and_dice(me, target)
    local required_cp = (menu.snd_combo_points and menu.snd_combo_points:get()) or 1
    if runtime.combo_points < required_cp then return false end
    -- ...
end

local function try_rupture(me, target)
    local required_cp = (menu.rupture_combo_points and menu.rupture_combo_points:get()) or 5
    if runtime.combo_points < required_cp then return false end
    -- ...
end
```

**Menu-configurable thresholds:**
- `snd_combo_points` (default: 1)
- `rupture_combo_points` (default: 5)
- `eviscerate_combo_points` (default: 5)
- `expose_armor_combo_points` (default: 5)
- `kidney_shot_combo_points` (default: 5)

### 3.2 Flux Implementation

**Context-based CP access:**
```lua
-- Passed via context from core:
matches = function(context, state)
    local min_cp = context.settings.assassination_min_cp_finisher or 4
    return context.cp >= min_cp
end
```

**Strategy-level min_cp declaration:**
```lua
local Assassination_Rupture = {
    -- ...
    min_cp = 5,  -- Declarative
}

-- Validated in check_prerequisites:
check_prerequisites = function(strategy, context)
    if strategy.min_cp and context.cp < strategy.min_cp then return false end
    return true
end
```

### 3.3 Comparison Matrix

| Aspect | EAX | Flux | Assessment |
|--------|-----|------|------------|
| CP Storage | `runtime.combo_points` | `context.cp` | Flux cleaner |
| Threshold Config | Per-ability menu items | `min_cp_finisher` setting | EAX more granular |
| Validation | Inline in try_* functions | `check_prerequisites()` | Flux more modular |
| CP Builder Gates | `if runtime.combo_points >= 5` | `if context.cp >= 5` | Equivalent |

---

## 4. Flux Pattern Adherence Analysis

### 4.1 Patterns Successfully Adopted

| Pattern | Implementation | Specs | Quality |
|---------|---------------|-------|---------|
| **energy_tick** | `energy_tick:update()` + `should_delay_action()` | All 3 | ✅ Good |
| **swing_manager** | `swing_manager:update_swing()` + `is_swing_landing_soon()` | All 3 | ✅ Good |
| **combat_forecast** | `combat_forecast:sample()` + TTD checks | All 3 | ✅ Good |
| **force_commands** | `force_commands:init()` + `:is_burst_active()` | All 3 | ✅ Good |
| **burst_manager** | `should_auto_burst()` integration | All 3 | ✅ Good |
| **trinket_manager** | `check_trinkets_v2()` with TTD gating | All 3 | ✅ Good |

### 4.2 Patterns NOT Adopted (Gap Analysis)

| Pattern | Flux Implementation | EAX Gap | Impact |
|---------|---------------------|---------|--------|
| **Strategy Registry** | `rotation_registry:register()` with named strategies | Monolithic `on_update()` | Medium — harder to maintain |
| **State Pre-allocation** | Static state tables, no inline `{}` | Runtime tables created per-frame | Low — GC pressure minimal |
| **Context Builder** | `context_builder` function for state caching | Inline state checks | Medium — redundant lookups |
| **Declarative Prerequisites** | `requires_stealth`, `min_cp`, etc. | Inline boolean checks | Low — equivalent functionality |
| **Pooling State** | `state.pooling` flag gates builders | Early returns on energy check | Low — same outcome |
| **Off-GCD Tagging** | `is_gcd_gated = false` for racials/CDs | Manual GCD checks | Low — `is_gcd_ready()` used |

### 4.3 EAX-Specific Enhancements (Beyond Flux)

| Feature | EAX Implementation | Flux Equivalent | Assessment |
|---------|-------------------|-----------------|------------|
| **Dashboard** | Full dashboard with position/opacity/scale | Basic TMW icon display | EAX superior UX |
| **Anti-Fake** | `anti_fake_manager.get_interrupt_delay()` | Not implemented | EAX PvP advantage |
| **CC Detection** | `cc_detector.should_stop_rotation()` | Not implemented | EAX safety feature |
| **Cloak of Shadows** | `try_cloak_of_shadows_cc_break()` | Not implemented | EAX class-specific |
| **Pending Cast Tracking** | `_pending_casts` table with timeouts | `try_cast()` wrapper | Equivalent |
| **Menu Nil Guards** | `(menu.x and menu.x:get()) or default` | Direct access | EAX more robust |

---

## 5. Compliance Scores

### 5.1 Scoring Rubric

| Category | Weight | Criteria |
|----------|--------|----------|
| Flux Library Integration | 30% | Proper use of energy_tick, swing_manager, combat_forecast, force_commands |
| Code Organization | 25% | Clear separation of concerns, maintainability |
| Rogue Mechanics | 25% | Correct CP/energy handling, finisher priorities |
| TBC Accuracy | 20% | Correct spells, talents, thresholds for TBC era |

### 5.2 Individual Spec Scores

#### EAXRogueAssassination — 82/100 (B+)

| Category | Score | Notes |
|----------|-------|-------|
| Flux Integration | 26/30 | All 4 Flux libs integrated correctly |
| Code Organization | 18/25 | Monolithic but well-structured |
| Rogue Mechanics | 22/25 | Correct Mutilate priority, missing Envenom |
| TBC Accuracy | 16/20 | TBC spells only, good thresholds |

**Strengths:**
- Proper Mutilate → finisher priority
- Cold Blood integration with TTD check
- Energy tick delay before expensive abilities

**Gaps:**
- Missing Envenom (WotLK spell, correctly excluded)
- No Shiv refresh for Deadly Poison (Flux has this)

#### EAXRogueCombat — 85/100 (B+)

| Category | Score | Notes |
|----------|-------|-------|
| Flux Integration | 27/30 | All libs + proper burst/CD integration |
| Code Organization | 19/25 | Clean separation of CD vs builder logic |
| Rogue Mechanics | 23/25 | Correct Blade Flurry/AR handling |
| TBC Accuracy | 16/20 | Riposte included, good thresholds |

**Strengths:**
- Blade Flurry enemy count check
- Adrenaline Rush TTD gating
- Riposte after-parry handling

**Gaps:**
- No Shiv refresh for Deadly Poison (minor for Combat)

#### EAXRogueSubtlety — 78/100 (B)

| Category | Score | Notes |
|----------|-------|-------|
| Flux Integration | 25/30 | All libs present, less burst integration |
| Code Organization | 17/25 | More complex due to stealth openers |
| Rogue Mechanics | 21/25 | Good Premeditation/Ambush handling |
| TBC Accuracy | 15/20 | Shadowstep correctly included |

**Strengths:**
- Proper stealth opener chain (Premed → Shadowstep → Ambush/Garrote)
- Preparation cooldown reset logic
- Hemorrhage as primary builder

**Gaps:**
- Missing Ghostly Strike in priority (present in menu but not main rotation)
- No Find Weakness tracking (Flux has this)

---

## 6. Recommendations

### 6.1 High Priority (Functional Impact)

1. **Add Shiv Refresh for Deadly Poison (Assassination)**
   - Flux pattern: Bypass pooling gate when DP < 2s remaining
   - EAX implementation: Add `try_shiv_refresh()` before builders

2. **Unify Combo Point Threshold Settings**
   - Current: 5 separate menu items for finisher CP
   - Flux pattern: Single `min_cp_finisher` setting (default 4-5)
   - Benefit: Simpler UX, same outcome

3. **Add Find Weakness Tracking (Subtlety)**
   - Flux tracks `find_weakness_active` in state
   - EAX: Add to runtime + buff check for damage window optimization

### 6.2 Medium Priority (Code Quality)

4. **Extract Strategy Tables**
   - Current: Sequential `try_*` calls in `on_update()`
   - Flux pattern: Strategy array with priority ordering
   - Benefit: Easier to reorder, test individual strategies

5. **Pre-allocate State Tables**
   - Current: Some inline table creation
   - Flux pattern: Static tables at module load
   - Benefit: Reduced GC pressure (minor for modern Lua)

6. **Centralize Energy Constants**
   - Current: Hardcoded `55`, `45`, `60` throughout
   - Flux pattern: `Constants.ENERGY.MUTILATE`
   - Benefit: Single source of truth for tuning

### 6.3 Low Priority (Polish)

7. **Add Envenom Comment**
   - Document why Envenom is excluded (WotLK spell)
   - Prevents future "bug" reports

8. **Standardize Menu Access Pattern**
   - Some specs use `:get()`, others `:get_state()`
   - Pick one pattern, apply consistently

---

## 7. Flux vs EAX: Design Philosophy Comparison

| Aspect | Flux | EAX | Winner |
|--------|------|-----|--------|
| **Extensibility** | Strategy registry allows easy reordering | Monolithic requires editing main.lua | Flux |
| **Debuggability** | Strategy names in output | Debug logging via `utils.log_debug()` | Tie |
| **Configuration** | Settings schema in separate file | Menu.lua per spec | EAX (more granular) |
| **Performance** | Pre-allocated state, minimal GC | Slightly more table creation | Flux (marginal) |
| **UX** | TMW icon display only | Full dashboard with positioning | EAX |
| **PvP Features** | Basic | Anti-fake, CC detection, Cloak break | EAX |
| **Maintainability** | Modular strategies | Well-commented monolithic | Tie |

---

## 8. Conclusion

All three EAX Rogue specs successfully integrate the core Flux libraries (energy_tick, swing_manager, combat_forecast, force_commands) and demonstrate correct TBC-era rotation logic. The primary divergence from Flux patterns is architectural:

- **Flux:** Declarative strategy registry with state-based pooling
- **EAX:** Imperative on_update() loop with inline threshold checks

**Neither approach is objectively superior** — Flux offers better modularity for rapid iteration, while EAX provides more granular user configuration and superior PvP features.

**Overall Assessment:** Production-ready implementations with room for minor enhancements (Shiv refresh, unified CP settings, Find Weakness tracking).

---

*End of Review*
