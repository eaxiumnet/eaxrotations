# EAXHunterBeastMastery

**Spec:** Hunter Beast Mastery  
**Complexity:** HIGH — Unique pet AI system  
**Entry:** `main.lua` → `on_update()` → pet state machine

## Unique Components

| File | Purpose | Size |
|------|---------|------|
| `pet_manager.lua` | Pet AI state machine | 342 lines |
| `talent_manager.lua` | Talent-based adjustments | ~50 lines |
| `kiting_manager.lua` | Ranged positioning | ~60 lines |

## Pet Manager Architecture

```lua
pet_manager.lua  # State machine: idle/attack/assist/defensive
├── Pet state tracking (engaged, distance, health)
├── Kill Command timing (only when pet engaged)
├── Bestial Wrath coordination
└── Mend Pet auto-cast logic
```

**Critical:** Kill Command must only fire when `pet.is_engaged == true`

## Where to Look

| Task | File |
|------|------|
| Pet behavior issues | `libraries/pet_manager.lua` |
| Kill Command timing | `main.lua` (search `kill_command`) |
| Pet health monitoring | `pet_manager.lua` (search `health_pct`) |
| Talent adjustments | `libraries/talent_manager.lua` |

## BM-Specific Conventions

- **Pet engagement check** required before Kill Command
- **Pet autocast** managed via `core.input.enable_pet_autocast()`
- **Bestial Wrath** synced with pet health/distance

## Anti-Patterns (BM)

- NEVER cast Kill Command without pet engagement check
- NEVER ignore pet health in defensive decisions
- ALWAYS verify pet exists before issuing commands

---

See root `AGENTS.md` for common conventions and git workflow.
