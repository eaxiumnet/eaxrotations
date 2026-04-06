# EAXWarriorProtection

**Spec:** Warrior Protection  
**Complexity:** HIGH — Refactored stance/burst systems  
**Entry:** `main.lua` → `on_update()` → table-driven burst actions  

## Architecture (Post-Refactor 2026-04-02)

```
main.lua  # ~3,174 lines (was ~3,702)
├── BURST_ACTIONS table      # Defines all burst abilities
├── STANCE_ACTION_VALIDATORS # Per-action validation logic
├── Defensive consumables     # CONSUMABLE_DEFS table
└── Emergency defensive lane  # DEF_ABILITIES table
```

## Refactor Wins

| System | Before | After |
|--------|--------|-------|
| Burst window | 336 lines (if-blocks) | ~170 lines (table-driven) |
| Stance staging | Inline duplication | Helper functions |
| Shield Slam | Duplicated blocks | Single consolidated block |
| File size | 3,702 lines | 3,174 lines (-14%) |

## Table-Driven Patterns

```lua
local BURST_ACTIONS = {
  death_wish = { check = can_death_wish, exec = exec_death_wish },
  recklessness = { check = can_reck, exec = exec_reck },
  -- ... etc
}
```

## Where to Look

| Task | Location |
|------|----------|
| Burst logic | Search `BURST_ACTIONS` in main.lua |
| Stance swaps | Search `execute_stance_swap()` |
| Shield Slam | Search consolidated Shield Slam block |
| Defensive CDs | Search `DEF_ABILITIES` table |
| Rotation docs | `README.md` (mode behaviors) |

## Prot-Specific Conventions

- **Prepull Holy Shield** — cast before pull when enabled
- **Shield Block charges** — tracked and consumed intelligently
- **Revenge proc priority** — proc active = highest priority
- **Devastate integration** — Sunder refresh via Devastate
- **Mode-aware behavior** — Solo/Dungeon/Raid shift priorities

## Anti-Patterns (Prot)

- NEVER hardcode stance action sequences
- ALWAYS use table-driven burst action definitions
- NEVER duplicate Shield Slam logic (now consolidated)
- NEVER burst (Death Wish/Recklessness) in Dungeon/Raid modes

---

See root `AGENTS.md` for common conventions and git workflow.
