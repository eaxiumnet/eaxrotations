# Shared Subtree Guidance

## Purpose
`shared/` holds cross-class helpers extracted for reuse and testability.

## Files (11 total)

| File | Role |
| --- | --- |
| `dot_refresh.lua` / `dot_refresh_sylvanas.lua` | DoT refresh gate logic (pure + Sylvanas wrapper) |
| `execute_phase.lua` / `execute_phase_sylvanas.lua` | Execute phase threshold detection |
| `mf_tick_compute.lua` / `mf_tick_compute_sylvanas.lua` | Mind Flay tick interval computation |
| `burst_logic_sylvanas.lua` | Cross-class burst cooldown logic |
| `find_dead_party_ally_sylvanas.lua` | Dead party member detection |
| `test_dot_refresh.lua` | Co-located test for dot_refresh |
| `test_execute_phase.lua` | Co-located test for execute_phase |

## Preferred Shape
- Pure or mostly pure functions first.
- No unnecessary `NS` / runtime coupling.
- Safe to execute via `dofile(...)` in standalone Lua tests when possible.
- Register back onto `_G.EaxRotations` only as a thin export layer.

## Existing Pattern
- Module table `M`
- Implementation functions
- `NS` registration for production use
- `_G` fallback for test harnesses
- `return M`

## Good Candidates For `shared/`
- Execute thresholds
- DoT refresh gates
- Tick / channel computations
- Cross-class burst or scan helpers

## Bad Candidates For `shared/`
- Class-specific playstyle logic
- UI rendering code
- Settings-schema details
- Runtime bootstrap or menu wiring

## Testing Contract
- If a helper is designed for standalone testing, keep its dependencies injectable.
- Co-located tests like `test_*.lua` are acceptable here when tightly bound to the helper.
- Preserve source comments that explain oracle / sim semantics.

## Critical Conventions
- TBC semantics matter more than generic MMO terminology.
- Avoid misleading wording like “Pandemic” for TBC refresh rules.
- If constants come from a simulator extract, document the source rather than hand-waving it.
