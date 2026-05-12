# EaxRotations Project Context

**Project:** EaxRotations TBC Classic Rotation Framework  
**Version:** 2.0.0-Tier4  
**Platform:** Project Sylvanas API  
**Last Updated:** 2026-05-11

---

## Quick Overview

EaxRotations is a comprehensive rotation automation framework for World of Warcraft: The Burning Crusade Classic. It runs on the Project Sylvanas platform and provides optimized ability sequencing for all 9 classes across 29+ playstyle specializations.

**Key Stats:**
- 100 Lua files (~55K lines)
- 40 regression tests (all passing)
- Tier 2-4 complete (15 new shared modules)

---

## Architecture at a Glance

```
EaxRotations/
├── header.lua              # Load validation
├── main.lua                # Bootstrap
├── core_sylvanas.lua       # NS.* runtime boundary (~2300 lines)
├── main_sylvanas.lua       # Dispatcher with combat detection
├── load_order_sylvanas.lua # Module load order
│
├── shared/                 # Cross-class helpers
│   ├── Tier 2: dr_tracker, enemy_cd_tracker, arena_priority, pvp_burst_window
│   ├── Tier 2: strategy_factory, custom_rotation
│   ├── Tier 3: profile_manager, combat_stats, gear_score, swing_timer, weapon_imbue
│   ├── Tier 4: spell_validation, talent_inference, idle_suggestion, benchmarks
│   └── Core: burst_logic, dot_refresh, execute_phase, interrupt_manager, ooc_manager, trinket_manager, racial_manager
│
├── classes/                # Per-class modules
│   └── <class>/
│       ├── class_sylvanas.lua      # Class registration
│       ├── schema_sylvanas.lua     # Settings UI
│       ├── middleware_sylvanas.lua # Shared class behavior
│       └── <spec>_sylvanas.lua     # Playstyle strategies
│
└── tests/                  # Regression tests (40 files)
```

---

## Tier 2-4 Feature Summary

### Tier 2 - PvP Foundation & Rotation Infrastructure

**DR Tracker** (`shared/dr_tracker_sylvanas.lua`)
- Tracks diminishing returns per target/category
- 18-second reset timer
- Returns multipliers: 1.0 → 0.5 → 0.25 → 0.0 (immune)

**Enemy CD Tracker** (`shared/enemy_cd_tracker_sylvanas.lua`)
- Monitors enemy spell casts
- Predicts cooldown availability
- Integrates with interrupt decisions

**Arena Priority** (`shared/arena_priority_sylvanas.lua`)
- Score-based target selection for arenas
- Considers class threat, HP, role

**PvP Burst Window** (`shared/pvp_burst_window_sylvanas.lua`)
- Detects Bloodlust/Heroism, Drums
- Provides `context.should_burst` flag

**Strategy Factory** (`shared/strategy_factory_sylvanas.lua`)
- Consistent strategy creation API
- Types: combat, self_buff, debuff, cooldown
- Callbacks: matches(context, state), execute(context, state)

**Custom Rotation** (`shared/custom_rotation_sylvanas.lua`)
- User-defined strategy sets
- Profile-based rotation switching

### Tier 3 - Profiles & Metrics

**Profile Manager** (`shared/profile_manager_sylvanas.lua`)
- Per-character setting profiles
- Save/load via NS.core.read/write_data_file
- JSON format storage

**Combat Stats** (`shared/combat_stats_sylvanas.lua`)
- APM tracking
- Downtime calculation
- DoT uptime monitoring
- Requires NS.register_on_combat_start/end

**Gear Score** (`shared/gear_score_sylvanas.lua`)
- Equipment quality estimation from item IDs
- Tier classification (preraid → T4 → T5 → T6 → Sunwell)
- Uses NS.EQUIPMENT_SLOTS constants

**Swing Timer** (`shared/swing_timer_sylvanas.lua`)
- Auto-attack timing
- Next swing prediction

**Weapon Imbue** (`shared/weapon_imbue_sylvanas.lua`)
- Tracks weapon buffs (poisons, oils, sharpening stones, shaman imbues)
- TBC-correct spell IDs
- Recommendations per class/spec

### Tier 4 - UX & Optimization

**Spell Validation** (`shared/spell_validation_sylvanas.lua`)
- Pre-cast validation checks
- Returns detailed failure reasons

**Talent Inference** (`shared/talent_inference_sylvanas.lua`)
- Detects talent build from learned spells
- No direct GetTalentInfo() API available
- Uses signature spell presence

**Idle Suggestion** (`shared/idle_suggestion_sylvanas.lua`)
- Out-of-combat action recommendations
- Integrates with OOC Manager

**Benchmarks** (`shared/benchmarks_sylvanas.lua`)
- Performance timing utilities
- Function execution profiling

---

## Key APIs Added in Tier 2-4

```lua
-- Focus target (for Misdirection, etc.)
NS.GetFocus()  -- Returns focus unit or nil

-- Party members (for heals, dispels)
NS.GetPartyMembers()  -- Returns table of party units

-- Combat events (for CombatStats)
NS.register_on_combat_start(callback)
NS.register_on_combat_end(callback)
```

**Implementation location:** `core_sylvanas.lua:258-527`

---

## Class Middleware Updates

| Class | File | Tier 2-4 Features |
|-------|------|-------------------|
| Hunter | `classes/hunter/middleware_sylvanas.lua` | Misdirection on focus target |
| Rogue | `classes/rogue/middleware_sylvanas.lua` | Emergency toolkit: Evasion, Cloak of Shadows, Vanish, Thistle Tea |
| Priest | `classes/priest/middleware_sylvanas.lua` | Party Dispel, Abolish Disease, Shadowfiend, Enhanced Fade |
| Warrior | `classes/warrior/middleware_sylvanas.lua` | Spell Reflection, Cancel External Buff, PvP Defensive Stance |
| Shaman | `classes/shaman/schema_sylvanas.lua` | Purge/self-dispel settings |

---

## Dispatcher Flow with Tier 2-4

`main_sylvanas.lua` dispatcher now:

1. **Context build** - Gather player/target/state
2. **Combat detection** - Track was_in_combat, fire callbacks on transitions
3. **CombatStats update** - Call CombatStats.on_update() during combat
4. **Middleware execution** - Run class middleware (includes Tier 2-4 features)
5. **Playstyle strategies** - Execute active playstyle
6. **Action recording** - Track for CombatStats.on_action()

---

## Code Patterns

### Standard File Header

All new files must include:

```lua
-- ============================================================================
-- Module Name
-- ============================================================================
-- Readability notes:
--   What: [what this module does]
--   When: [when it runs]
--   Why: [why this approach]
--   Safety: [safety considerations]
-- 
-- Decision notes:
--   [explain non-obvious choices]
--   [performance trade-offs]
--   [API limitations worked around]
-- ============================================================================
```

### Strategy Pattern

```lua
-- Using Strategy Factory
local strategy = NS.StrategyFactory.create_combat_strategy(spell_id, {
    setting_key = "use_spell_name",
    label = "[Class] Spell Name",
    target_pct = { min = 0, max = 100 },
})

-- Dispatcher calls:
-- strategy.matches(context, state) -> boolean
-- strategy.execute(context, state) -> boolean
```

### Tier 2-4 Feature Usage

```lua
-- DR check before CC
local multiplier = NS.DRTracker.get_dr_multiplier(target, "stun")
if multiplier == 0 then
    -- Target immune, skip
end

-- Profile save
NS.ProfileManager.save_profile("PvE", context.settings)

-- Talent check
local is_arms = NS.TalentInference.has_talent("warrior", "mortal_strike")

-- Combat stats
NS.CombatStats.on_action(spell_id, success, context)
```

---

## Testing

**Run all tests:**
```powershell
Get-ChildItem EaxRotations\tests -Filter test_*.lua | ForEach-Object {
    lua $_.FullName
}
```

**Expected: 40 tests pass**

---

## Documentation Files

| File | Purpose | Audience |
|------|---------|----------|
| `README.md` | Project overview, usage guide | Community users |
| `AGENTS.md` | Architecture, module reference | AI agents, maintainers |
| `CLAUDE.md` | This file - project context | Claude Code sessions |
| `docs/` | Additional detailed docs | Contributors |

---

## Common Tasks

### Adding a New Tier 2-4 Module

1. Create file in `shared/<name>_sylvanas.lua`
2. Add header with What/When/Why/Safety/Decision notes
3. Register in `load_order_sylvanas.lua`
4. Add test in `tests/test_<name>.lua`
5. Update `README.md` and `AGENTS.md`

### Updating Class Middleware

1. Edit `classes/<class>/middleware_sylvanas.lua`
2. Add Tier 2-4 feature integration
3. Ensure nil-safety for NS.* calls
4. Test with class-specific scenarios

### Adding Combat Event Handling

1. Use `NS.register_on_combat_start(callback)` in module init
2. Store callback reference for cleanup
3. Update `main_sylvanas.lua` dispatcher if needed

---

## Constraints & Limitations

- **TBC-only spells** - Never add WotLK/Cata abilities
- **API availability** - Some features depend on Sylvanas API presence (check with pcall)
- **Performance** - Hot paths must avoid per-frame allocations
- **Nil safety** - All NS.* calls must be guarded
- **Settings** - Read from context.settings, not cached at load

---

## Project Links

- **README.md** - Start here for project overview
- **AGENTS.md** - Detailed architecture reference
- **load_order_sylvanas.lua** - Module loading order
- **tests/** - Regression test suite

---

## Status: Tier 4 Complete

All Tier 2, 3, and 4 modules implemented and integrated.
All 40 tests passing.
Documentation updated.

Ready for verification and release.
