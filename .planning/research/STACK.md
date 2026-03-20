# Technology Stack (v1.1 Additions Only)

**Project:** EAX TBC Classic Rotations (v1.1 Combat Intelligence)
**Researched:** 2026-03-20
**Scope:** Stack additions/changes for reactive combat AI, 27-spec benchmark matrix, and strict `@.api` hard-gate validation

## Baseline Constraints (Keep As-Is)

| Constraint | Value | Why It Matters |
|---|---|---|
| Runtime | Project Sylvanas embedded Lua (`core`, `game_object`, `menu`) | Hard-gate must validate against this exact API surface |
| Language | Pure Lua 5.x | No external runtime dependencies allowed in plugins |
| Game target | WoW TBC Classic 2.4.3 | Spell/talent/set logic must stay expansion-locked |
| Delivery model | Direct Lua file copy, no build step | New tooling must be optional/offline and non-invasive |

## Recommended Stack Changes

### Core Runtime Modules (new internal modules)
| Module | Version/Compat | Purpose | Integration Point | Why |
|---|---|---|---|---|
| `eax_shared/reactive_state.lua` | v1.1, Lua 5.x | Per-tick combat snapshot (incoming heals, threat state, cast windows, role context) | Called once per rotation tick in each `EAX*/main.lua` before action selection | Centralizes signal collection; prevents 27 diverging implementations |
| `eax_shared/reactive_policy.lua` | v1.1, Lua 5.x | Role-aware decision policy (DPS/HPS/Tank urgency scoring) | Consumes `reactive_state`, `encounter_manager`, `threat_manager`, `defensive_manager` | Gives deterministic reactive behavior without rewriting every spec from scratch |
| `eax_shared/reactive_actions.lua` | v1.1, Lua 5.x | Shared action executors (panic defensive, pre-emptive heal, utility interrupt, control break) | Invoked by spec `main.lua` after policy outputs action intent | Keeps spell execution logic consistent while preserving per-spec spell IDs |
| `eax_shared/benchmark_metrics.lua` | v1.1, Lua 5.x | Unified combat metric schema (`dps`, `hps`, `tps`, survival/utility counters) | Wrap existing `eax_shared/dps_meter.lua` | `dps_meter` alone is insufficient for v1.1 matrix gates |

### Validation and Benchmark Tooling (new/extended scripts)
| Script | Version/Compat | Purpose | Integration Point | Why |
|---|---|---|---|---|
| `tools/api_hard_gate.lua` (new) | v1.1, CLI Lua 5.4.5+ | Failing validator for non-`@.api` calls and forbidden globals | Run from `tools/rotation_validation.lua` and CI/pre-release checklist | Enforces milestone requirement, not just documentation comments |
| `tools/api_surface_extract.lua` (new) | v1.1, CLI Lua 5.4.5+ | Builds allowlist from `.api/core.lua`, `.api/game_object.lua`, `.api/menu.lua`, `.api/common/**/*.lua` | Input to `api_hard_gate.lua` | Avoids stale hand-maintained allowlists when `.api` changes |
| `tools/benchmark_matrix.lua` (new) | v1.1, CLI Lua 5.4.5+ | Executes/aggregates 27-spec matrix and emits CSV/Markdown artifact | Extends `tools/dps_benchmark.lua` flow; writes `.planning/benchmarks/*.csv` | Current benchmark script is single-spec/live or dry-run only |
| `tools/rotation_validation.lua` (extend) | existing + v1.1 checks | One command for syntax + required imports + API gate + benchmark schema sanity | Existing team entrypoint | Keeps release gate simple (`one command, hard fail`) |

## Compatibility and Version Rules

| Area | Required Version/Rule | Rationale |
|---|---|---|
| Plugin runtime code (`EAX*/`, `eax_shared/`) | Lua 5.x syntax only; avoid runtime-specific extensions | Must execute inside Sylvanas runtime, not just local CLI Lua |
| Tool scripts (`tools/*.lua`) | Tested on local Lua/luac 5.4.5 | Current environment is 5.4.5; keep tooling deterministic |
| API contract source | `.api/*` in this repo is source-of-truth | Hard-gate must validate against local authoritative API snapshot |
| Hard-gate behavior | Any violation = non-zero exit code | "Warn only" gates will be ignored; milestone needs strict fail-close behavior |

## Required Integration Sequence

1. Add `reactive_state` + `reactive_policy` + `reactive_actions` to `eax_shared/`.
2. Wire one shared call path into each `EAX*/main.lua`: collect state -> score policy -> execute intent -> fallback to existing rotation.
3. Add `api_surface_extract.lua` and `api_hard_gate.lua`; call them from `tools/rotation_validation.lua`.
4. Add `benchmark_metrics.lua` and `benchmark_matrix.lua`; extend `tools/dps_benchmark.lua` to emit matrix-compatible rows.
5. Keep `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` as human-readable mirror of the generated matrix artifact.

## What NOT to Add

| Do Not Add | Why |
|---|---|
| Any non-Lua runtime dependency in plugin path (Python/Node/binary sidecars) | Breaks zero-build deployment and Sylvanas plugin portability |
| External Lua package manager dependency at runtime (LuaRocks modules in rotations) | Violates pure Lua/no-external-deps project constraint |
| New movement/pathfinding subsystem | Milestone explicitly excludes movement; adds complexity with no v1.1 value |
| Broad WoW API emulation beyond `.api/common/wow_api_clone.lua` compatibility shim | Increases API surface and weakens hard-gate signal |
| Spec-local copies of new reactive modules | Reintroduces 27x drift and maintenance burden |

## Sources

- `./.planning/PROJECT.md` (v1.1 goals, constraints, required hard gate + benchmark matrix)
- `./tools/rotation_validation.lua` (current validation entrypoint)
- `./tools/dps_benchmark.lua` (current benchmark limitations)
- `./eax_shared/dps_meter.lua` (current metric scope)
- `./eax_shared/defensive_manager.lua` (existing defensive integration target)
- `./eax_shared/threat_manager.lua` (existing threat integration target)
- `./eax_shared/encounter_manager.lua` (existing encounter-policy integration target)
- `./.api/core.lua`, `./.api/game_object.lua`, `./.api/menu.lua`, `./.api/common/wow_api_clone.lua` (authoritative API allowlist input)
- Local toolchain check on 2026-03-20: `lua -v` and `luac -v` -> `5.4.5`
