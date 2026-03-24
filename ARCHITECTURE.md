# EAX TBC Classic Rotations - Architecture Documentation

## Overview

This is a comprehensive World of Warcraft: The Burning Crusade (TBC) rotation framework addon for the Sylvanas bot ecosystem. It supports all 9 classes with multiple specs each.

## Directory Structure

```
scripts/
├── eax_shared/                    # SHARED CORE LIBRARIES (canonical)
│   ├── combat_context.lua        # Combat state snapshot builder
│   ├── reactive_engine.lua       # Priority-based emergency action system
│   ├── reactive_runtime.lua      # Reactive engine integration
│   ├── interrupt_manager.lua     # Priority interrupt system
│   ├── defensive_manager.lua     # HP-threshold defensive tiers
│   ├── dps_meter.lua           # DPS/HPS tracking
│   ├── dps_runtime.lua         # DPS snapshot builder
│   ├── dps_risk.lua            # Threat/fade risk assessment
│   ├── mana_manager.lua        # Mana potion usage
│   ├── dot_manager.lua         # DoT tracking and refresh
│   ├── set_bonus.lua           # T4/T5/T6 set detection (60+ sets)
│   ├── threat_manager.lua      # Threat tracking and fade
│   ├── encounter_manager.lua    # Boss encounter policies
│   ├── racial_manager.lua       # Racial abilities
│   ├── ooc_manager.lua         # Out-of-combat automation
│   ├── vendor_automation.lua    # Auto repair/sell
│   ├── consumables_manager.lua  # Food/drink/flasks
│   ├── mount_manager.lua       # Auto mount/dismount
│   ├── totem_manager.lua        # Shaman totem handling
│   ├── cooldown_tracker.lua     # Spell cooldown tracking
│   ├── spell_resolver.lua      # Spell ID caching
│   ├── healer_triage.lua        # Healer party triage
│   ├── role_policy.lua         # Tank/DPS/Healer role policies
│   ├── tank_recovery.lua       # Tank emergency recovery
│   ├── swing_timer.lua         # Melee swing timing
│   ├── visual_state.lua        # Visual telemetry state
│   ├── smart_cast_manager.lua   # Smart GCD/throttle management (NEW)
│   └── settings_framework.lua   # Unified settings framework (NEW)
│
├── EAXDruidBalance/             # Balance Druid spec
│   ├── main.lua                # Rotation logic + callbacks
│   ├── menu.lua               # ImGui control panel
│   ├── spells.lua             # Spell ID tables (all TBC ranks)
│   ├── utils.lua              # Target finding, buff/debuff helpers
│   ├── esp_renderer.lua        # HUD overlay
│   ├── ttd_tracker.lua        # Time-to-death tracking
│   ├── [re-export stubs]      # Delegates to eax_shared/
│   └── ...
│
├── EAXDruidFeral/              # Feral Druid spec
├── EAXDruidRestoration/        # Restoration Druid spec
├── EAXHunterBeastMastery/      # BM Hunter spec
├── EAXHunterMarksmanship/       # MM Hunter spec
├── EAXHunterSurvival/           # Survival Hunter spec
├── EAXMageArcane/              # Arcane Mage spec
├── EAXMageFire/                # Fire Mage spec
├── EAXMageFrost/              # Frost Mage spec
├── EAXPaladinHoly/             # Holy Paladin spec
├── EAXPaladinProtection/        # Protection Paladin spec
├── EAXPaladinRetribution/       # Retribution Paladin spec
├── EAXPriestShadow/            # Shadow Priest spec
├── EAXPriestHoly/              # Holy Priest spec
├── EAXPriestDiscipline/        # Discipline Priest spec
├── EAXRogueAssassination/      # Assassination Rogue spec
├── EAXRogueCombat/             # Combat Rogue spec
├── EAXRogueSubtlety/           # Subtlety Rogue spec
├── EAXShamanElemental/         # Elemental Shaman spec
├── EAXShamanEnhancement/       # Enhancement Shaman spec
├── EAXShamanRestoration/       # Restoration Shaman spec
├── EAXWarlockAffliction/       # Affliction Warlock spec
├── EAXWarlockDemonology/       # Demonology Warlock spec
├── EAXWarlockDestruction/      # Destruction Warlock spec
├── EAXWarriorArms/             # Arms Warrior spec
├── EAXWarriorFury/             # Fury Warrior spec
├── EAXWarriorProtection/       # Protection Warrior spec
│
├── tools/                      # Development tools
│   ├── api_hard_gate.lua      # API allowlist enforcement
│   ├── api_allowlist.lua      # Whitelist of allowed APIs
│   ├── api_surface_extract.lua # Extract API surface from code
│   ├── dps_benchmark.lua      # DPS benchmarking
│   ├── benchmark_matrix.lua   # Benchmark comparison
│   └── rotation_validation.lua # Rotation correctness checks
│
└── tests/                     # Busted test suite
    ├── reactive_engine_spec.lua
    ├── reactive_runtime_spec.lua
    ├── dps_meter_spec.lua
    ├── combat_context_spec.lua
    └── ...
```

## Architecture Patterns

### 1. Shared Library Pattern

All 27 specs share common functionality through `eax_shared/` modules. Each spec has lightweight re-export stubs that delegate to the canonical root modules:

```lua
-- racial_manager.lua (per-spec stub)
return require("eax_shared/racial_manager")
```

This pattern:
- Eliminates 702 duplicate module files
- Ensures all specs use identical shared logic
- Allows centralized bug fixes and improvements

### 2. Reactive Engine Pattern

The reactive engine provides a priority-based action system that overlays the main rotation:

```
Priority Order:
1. life_save_self     - Emergency self-heal
2. life_save_ally     - Emergency ally-heal (healers)
3. interrupt_control  - Interrupt dangerous casts
4. anti_overheal     - Prevent overhealing (healers)
5. anti_aggro        - Threat fade (tanks)
6. throughput_resume - Resume damage after danger
```

Each spec provides handlers for these actions:

```lua
reactive_adapter = {
    spec = "EAXDruidBalance",
    actions = {
        life_save_self = {
            handler = function(_, action_deps)
                return defensive_manager.try_defensive(action_deps.me, "druid", utils)
            end,
        },
        life_save_ally = { noop = "unsupported" },
        interrupt_control = { ... },
        -- etc
    },
}
```

### 3. Combat Context Pattern

The combat context builds a centralized snapshot of combat state:

```lua
ctx = {
    meta = { now_s, valid, fail_safe },
    self = { hp_pct, incoming_heal_pct, threat_pct, role },
    target = { exists, hp_pct, is_casting, is_channeling },
    party = { lowest_hp_pct, tank, urgent_ally },
    encounter = { hold_cooldowns, burn_phase, interrupt_priority },
}
```

This is throttled to 2-second refresh for performance.

### 4. Smart Cast Management (NEW)

The new `smart_cast_manager.lua` addresses rotation feel issues:

**Features:**
- Smart GCD detection (not hardcoded 1.5s)
- Intelligent action throttling between similar abilities
- Adaptive pending cast timeouts
- Cast success/failure feedback loop

**Usage:**
```lua
-- Initialize
smart_cast_manager.init({ core_time = _core_time, get_gcd = _get_gcd })

-- Check GCD readiness
if not smart_cast_manager.is_gcd_ready() then return false end

-- Throttle similar abilities
if smart_cast_manager.should_throttle("moonfire", "dots") then return false end

-- Mark cast with category
smart_cast_manager.on_cast_attempt(spell_id, "moonfire", { category = "dots" })
```

**Throttle Categories:**
- `dots` (0.15s) - DoT refreshes, more responsive
- `filler` (0.2s) - Filler abilities
- `cooldown` (0.1s) - Cooldown abilities
- `aoe` (0.25s) - AoE abilities

### 5. Settings Framework (NEW)

The new `settings_framework.lua` provides standardized control panel organization:

**Standard Categories:**
1. Controls - Enable/disable, toggle key, mode, debug
2. Rotation - Main combat rotation settings
3. Defensive - Self-preservation and defensive cooldowns
4. Targeting - Target selection and priority
5. AoE & Multi-Target - Area-of-effect settings
6. Cooldowns - Offensive and defensive cooldown usage
7. Racial Abilities - Racial ability usage
8. Consumables - Potions, food, flasks
9. Out of Combat - Non-combat automation
10. Display & HUD - Visual overlay settings

## File Usage Mapping

### Core (Always Loaded)
- `main.lua` - Core rotation logic, callbacks
- `menu.lua` - ImGui control panel
- `spells.lua` - Spell ID tables
- `utils.lua` - Target finding, helpers
- Re-export stubs → `eax_shared/*`

### Per-Spec (Used by Specific Specs)
- `esp_renderer.lua` - All specs (HUD overlay)
- `leveling_manager.lua` - All specs (wand/mana conservation)
- ` Racial_manager.lua` - All specs (via eax_shared)
- `totem_manager.lua` - Shaman specs only

### Development (Not Runtime)
- `tools/*.lua` - Dev scripts, not loaded in-game
- `tests/*.lua` - Test suite, not loaded in-game

## TBC Accuracy Guidelines

All rotations must be TBC accurate:

### GCD
- Base GCD: 1.5 seconds
- Minimum GCD: 1.0 seconds (with ~27% haste)

### Spell Data
- Use correct TBC cast times
- Use correct TBC cooldowns
- Use correct TBC mana costs

### Prohibited (Wrath+ Mechanics)
- ❌ Holy Power (Wrath)
- ❌ Combo Points rework (Cata)
- ❌ Blood/Death Strike (Wrath)
- ❌ Eclipse system (Cata)
- ❌ Fireball! proc (MoP)
- ❌ etc.

## Performance Considerations

### Hot Path Optimizations
- Local API caching (`_core_time`, `_get_gcd`)
- Combat context throttling (2s)
- Spell resolution caching (persistent)
- Static table reuse for visual state

### Anti-Patterns
- Avoid per-frame `is_spell_learned()` calls (use spell_resolver)
- Avoid per-frame combat context rebuild (use throttled cache)
- Avoid per-frame object scans (use throttled target finding)

## Testing

### Validation Tools
```bash
# Check rotation validation
lua tools/rotation_validation.lua

# Check API surface
lua tools/api_hard_gate.lua

# Syntax check all specs
for f in EAX*/*.lua; do luac -p "$f"; done
```

### Manual Testing
1. Enable each spec individually
2. Test in solo, dungeon, raid modes
3. Verify no console errors
4. Verify rotation feels smooth (no spam, no sluggishness)

## Migration Guide

### Adding a New Spec

1. Copy existing spec folder (e.g., `EAXDruidBalance`)
2. Update `.toc` file
3. Update `plugin_info.lua`
4. Update `header.lua` class check
5. Update spell IDs in `spells.lua`
6. Rewrite rotation logic in `main.lua`
7. Update menu options in `menu.lua`

### Updating Shared Modules

When updating `eax_shared/` modules:
1. Changes are automatically available to all specs
2. Test with at least 3 different specs
3. Verify no breaking changes

## Troubleshooting

### "Spell not found" errors
- Check spell ID is correct for TBC
- Check spell is learned by character
- Check `spell_resolver` cache (may need invalidation)

### Rotation feels sluggish
- Enable debug logging to see decisions
- Check GCD is clearing properly
- Verify no conflicting addons

### Rotation feels spammy
- Adjust throttle intervals in `smart_cast_manager`
- Check pending cast timeouts

## Credits

Original framework by Eax's Rotations
TBC rewrite by the community
