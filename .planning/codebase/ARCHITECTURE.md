# ARCHITECTURE - System Design

## Overall Pattern

**Modular plugin architecture** with per-spec isolation and shared utilities.

```
┌─────────────────────────────────────────────────────┐
│              EAX Plugin (per spec)                  │
│  ┌─────────┐ ┌──────────┐ ┌─────────────────────┐  │
│  │ main.lua│ │spells.lua│ │ Shared Managers     │  │
│  │         │ │ (data)   │ │ interrupt_manager   │  │
│  │ Rotation│ │          │ │ defensive_manager   │  │
│  │ Logic   │ │          │ │ encounter_manager  │  │
│  │         │ │          │ │ ooc_manager        │  │
│  │         │ │          │ │ leveling_manager    │  │
│  │         │ │          │ │ racial_manager      │  │
│  │         │ │          │ │ ttd_tracker         │  │
│  │         │ │          │ │ esp_renderer        │  │
│  └─────────┘ └──────────┘ └─────────────────────┘  │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│              Sylvanas Core API                      │
│  core.object_manager, core.spell_book, core.input  │
└─────────────────────────────────────────────────────┘
```

## Per-Spec Module Structure

Each of the 27 spec folders contains:

| File | Purpose |
|------|---------|
| `main.lua` | Entry point, rotation logic, event registration |
| `spells.lua` | Spell ID rank tables, buff/debuff tables |
| `menu.lua` | ImGui configuration UI |
| `utils.lua` | Spec-specific helpers (casting, targeting) |
| `eax_utils.lua` | Shared EAX utilities |
| `interrupt_manager.lua` | Priority interrupt system |
| `defensive_manager.lua` | HP-threshold defensives |
| `encounter_manager.lua` | Boss encounter awareness |
| `ooc_manager.lua` | Out-of-combat utilities |
| `leveling_manager.lua` | 1-70 leveling support |
| `racial_manager.lua` | Racial ability system |
| `ttd_tracker.lua` | Time-to-death estimation |
| `esp_renderer.lua` | Visual overlay (HUD/ESP) |
| `plugin_info.lua` | Plugin metadata |
| `header.lua` | Header banner |
| `color.lua` | Color utilities |
| `ps_theme.lua` | UI theme |

## Data Flow

```
Sylvanas Tick → on_update()
    │
    ├── Toggle Check (early exit if disabled)
    │
    ├── OOC Manager → Drink/Eat/Buff/Rez
    │
    ├── Focus Target Priority
    │
    ├── Mode Detection (solo/dungeon/raid)
    │
    ├── Set Bonus Update
    │
    ├── Target Finding (priority: attacking_me > party > any)
    │
    ├── Defensive Manager
    │
    ├── Utility Lane (interrupt, racial, buffs, sunder)
    │
    └── Core Rotation Lane (spec-specific priority)
```

## Key Abstractions

### Spell Resolution
```lua
utils.resolve_spell_id(rank_table)  -- Returns highest learned rank
```

### Casting Interface
```lua
utils.cast_target(spell_id, target)  -- Queued target cast
utils.cast_self(spell_id, me)        -- Queued self cast
utils.cast_target_fast(spell_id, target)  -- GCD-bypassing cast
```

### Encounter Policy
```lua
encounter_manager.get_policy(me) → {
    hold_cooldowns,    -- Save CDs for burst
    aoe_safe,          -- Safe to AoE
    interrupt_priority,-- High-priority interrupt target
    tank_damage_heavy, -- Tank taking heavy damage
    ...
}
```

### Interrupt Priority
```lua
interrupt_manager.should_interrupt(target) → boolean
interrupt_manager.try_interrupt(me, target, class_name, utils) → boolean
```

## Shared State

### Spec Conflict Detection
Each main.lua registers at `_G.__EAX_LOADED[class][spec]` and warns if multiple specs enabled for same class.

### ESP State Isolation
`esp_renderer` uses `state_by_spec` table keyed by spec name to prevent cross-spec interference.

## Entry Points

```lua
core.register_on_update_callback(on_update)      -- Main tick
core.register_on_render_callback(fn)            -- Render (ESP)
core.register_on_render_menu_callback(menu.render)  -- Menu UI
core.register_on_render_control_panel_callback(fn)  -- Control panel
```
