# eax_shared

**Purpose:** Cross-spec shared runtime (minimal)  
**Current State:** Only 2 files at root level

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `pull_optimizer.lua` | ~85 | Trivial target detection, instant-cast-only mode |
| `pvp_manager.lua` | ~129 | Enemy targeting, cooldowns, arena/BG logic |

## Architecture Note

**Most "shared" code is NOT here.** The bulk of shared modules (combat_context, interrupt_manager, defensive_manager, etc.) are **duplicated per-spec** in each `EAX*/libraries/` folder.

This directory only contains:
- Spec-agnostic runtime helpers
- Modules that must be shared across all specs at runtime

## Per-Spec Copies Pattern

Each `EAX<Class><Spec>/libraries/` contains copies of:
- `combat_context.lua` — Throttled combat state (2s refresh)
- `interrupt_manager.lua` — Priority interrupt system
- `defensive_manager.lua` — HP-threshold defensive tiers
- `spell_resolver.lua` — Spell ID resolution cache
- `esp_renderer.lua` — Visual overlay system
- And 30+ other modules

## Where to Look

| Task | Location |
|------|----------|
| Pull speed optimization | `pull_optimizer.lua` |
| PvP enemy targeting | `pvp_manager.lua` |
| Shared module drift audit | `tools/audit_shared_duplicates.py` |
| Per-spec library copy | `EAX*/libraries/<module>.lua` |

## Conventions

- Specs require via: `require("eax_shared/pull_optimizer")`
- Per-spec stubs bridge: `return require("eax_shared/spell_resolver")`
- Never put spec-specific logic here

---

See root `AGENTS.md` for common conventions and git workflow.
