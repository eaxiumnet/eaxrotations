# Project Research Summary

**Project:** EAX TBC Classic Rotations (milestone v1.2 Druid Reliability)
**Domain:** TBC Classic Druid rotation reliability (Restoration role policy + Feral finisher consistency)
**Researched:** 2026-03-21
**Confidence:** HIGH

## Executive Summary

This research describes a targeted reliability milestone in a mature Lua rotation framework, not a stack rewrite. The product goal is strict behavior correctness in two high-trust paths: Restoration must never leak offensive behavior in grouped healer contexts, and Feral must spend combo points consistently with TBC-accurate finisher rules. Expert implementation pattern is to enforce policy gates at clear choke points in existing spec lanes while keeping shared runtime contracts stable.

The recommended approach is to add two focused shared/internal reliability modules (`group_context_gate` and `feral_finisher_state`) and wire them into `EAXDruidRestoration/main.lua` and `EAXDruidFeral/main.lua` before offensive/filler branches execute. Use API-first truth (`get_power(COMBOPOINTS_TBC)` and `get_combo_points_target`) for Feral state, and fail-closed grouped-healer lock semantics for Resto. Reuse current validation and benchmark tooling with new druid-specific assertions/counters rather than introducing new frameworks.

The biggest risks are context drift, side-channel offense bypassing the healer no-DPS promise, and CP/energy logic deadlocks that starve finishers. Mitigation is explicit and evidence-based: single-source policy gating across all hostile-capable helpers, deterministic finisher gate before builders, bounded deferral rules, and benchmark-backed sign-off metrics (`group_hostile_cast_count`, CP-cap dwell, finisher latency/throughput).

## Key Findings

### Recommended Stack

Keep the existing Lua 5.x Sylvanas runtime and current shared runtime architecture; this milestone should be solved with internal modules and stricter policy/state handling, not new dependencies.

**Core technologies:**
- `Lua 5.x` in Sylvanas plugins: existing runtime boundary; reliability fixes remain deterministic in current tick loop.
- Sylvanas API surface (`game_object`, `core`): authoritative context and CP reads (`is_party_member`, `get_group_role`, `get_power`, `get_combo_points_target`).
- `eax_shared` runtime path: reuse `combat_context`, `reactive_runtime`, `role_policy`, and `encounter_manager` integration points.
- `eax_shared/group_context_gate.lua` (new): centralized grouped-vs-solo classification and healer DPS lock authority.
- `eax_shared/feral_finisher_state.lua` (new): deterministic CP ownership/target/energy state and finisher gating.

Critical compatibility requirement: use API-first CP reads (`COMBOPOINTS_TBC` + CP target) and treat cast-callback CP accounting as fallback only.

### Expected Features

**Must have (table stakes):**
- Resto hard lock: no intentional DPS in party/raid/dungeon/boss healer contexts.
- Resto solo-safe DPS: offensive fallback only under safe HP/mana/threat/no-emergency-heal conditions.
- Feral finisher reliability: correct CP source, Rip/Bite selection by fight state, and anti-overcap spend timing.
- Repeatable validation loop with druid-specific checks in existing validation/benchmark tools.

**Should have (competitive):**
- Context-aware solo DPS aggressiveness (beyond raw `mode == solo`).
- Finisher reason telemetry (`why rip/bite/hold`) for fast tuning and trust.
- Desync fail-safe recovery when CP state appears stuck.

**Defer (v2+):**
- Per-encounter druid policy packs.
- Cross-spec generalized extraction of healer/melee reliability policy after druid model proves stable.

### Architecture Approach

The architecture recommendation is spec-local behavior fixes with shared runtime stability: keep `reactive_runtime` and branch ordering unchanged, and inject explicit policy gates right before throughput actions (`do_dps_fallback` for Resto, builder lane entry for Feral). Extend `menu.lua` defaults toward conservative reliability, and extend `tools/rotation_validation.lua`/`tools/dps_benchmark.lua` for objective milestone evidence.

**Major components:**
1. `EAXDruidRestoration/main.lua` - grouped-healer lock and solo-safe DPS gate before offensive paths.
2. `EAXDruidFeral/main.lua` - deterministic finisher gate (CP target affinity, spend-before-build, anti-overcap).
3. `eax_shared/reactive_runtime.lua` - unchanged integration bus and action sequencing contract.
4. `eax_shared/group_context_gate.lua` (new) - single source of truth for Resto DPS eligibility.
5. `eax_shared/feral_finisher_state.lua` (new) - CP/energy/target state machine for finisher decisions.
6. `tools/rotation_validation.lua` and `tools/dps_benchmark.lua` - evidence gates for reliability sign-off.

### Critical Pitfalls

1. **Group-context drift leaks healer DPS** - enforce one fail-closed `is_group_healer_lock` evaluated at decision time.
2. **Side-channel offense bypass** - gate all hostile-capable helpers (wand/melee/racial/utility) through the same policy wrapper.
3. **UI override precedence breaks guarantees** - codify precedence as safety policy > role lock > user throughput preferences.
4. **Wrong Ferocious Bite energy model** - separate minimum cast cost from optional extra-energy conversion; do not use CP*35 gating.
5. **CP ownership/target desync and deadlocks** - API-first CP state machine, bounded finisher deferral, and CP-lock-aware targeting.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Role Policy Hard Lock Foundation
**Rationale:** Trust-critical Resto no-DPS guarantee must be established before any tuning work.
**Delivers:** `group_context_gate`, policy precedence rules, grouped-healer hard lock before all offensive paths, strict default toggles.
**Addresses:** Resto grouped lock + solo dependency chain from FEATURES.
**Avoids:** context drift and override-induced policy leaks from PITFALLS 1 and 3.

### Phase 2: Feral Finisher State Machine and Integration Hardening
**Rationale:** CP correctness and spender arbitration are the highest complexity/risk block and depend on stable phase-1 policy boundaries.
**Delivers:** `feral_finisher_state`, API-first CP ownership/target rules, bite/rip decision correctness, bounded hold/preemption, cross-module hostile-gate consistency.
**Uses:** stack recommendations for API-first reads and shared module integration.
**Implements:** architecture pattern of finisher gate before builders.
**Avoids:** finisher starvation, CP desync, and side-channel bypass pitfalls (2, 4, 5, 7).

### Phase 3: Targeting and CP-Preservation Cohesion
**Rationale:** After core finisher logic is stable, resolve target-selection conflicts that waste capped CP.
**Delivers:** CP-lock-aware selector behavior across normal/smart/focus targeting, explicit logged bypass paths, swap-at-cap telemetry.
**Addresses:** finisher consistency under real encounter target churn.
**Avoids:** target-switch waste pitfall (6).

### Phase 4: Validation and Benchmark Gate
**Rationale:** Milestone should close only with evidence, not code-path confidence.
**Delivers:** druid scenario matrix, objective counters, repeated benchmark runs, acceptance thresholds for grouped no-DPS and feral spend cadence.
**Addresses:** validation-loop table stake from FEATURES.
**Avoids:** regression blind spots and "looks fixed" false positives (pitfall 8).

### Phase Ordering Rationale

- Put policy lock first because solo rules and integration hardening are unsafe without a fail-closed grouped-healer baseline.
- Put finisher state machine second because CP truth and spender arbitration are prerequisites for meaningful targeting refinements.
- Isolate targeting cohesion after finisher correctness to avoid conflating two root causes of spend failures.
- End with evidence gate so sign-off reflects behavior across transitions, not one-off success cases.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Ferocious Bite edge semantics and lag-tolerant CP reconciliation behavior need scenario-level calibration.
- **Phase 3:** Target-selector interactions across smart/focus modes are integration-heavy and historically fragile.

Phases with standard patterns (skip `/gsd-research-phase`):
- **Phase 1:** Role lock + policy precedence is strongly documented and directly grounded in current code paths.
- **Phase 4:** Validation workflow structure is already established; only druid-specific metrics/checklists need extension.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strong internal-source backing and no dependency churn; recommendations align with existing APIs/runtime. |
| Features | HIGH | Table-stakes and priority mapping are clear and consistent with milestone objectives. |
| Architecture | HIGH | Concrete component boundaries, data flow, integration points, and validation points are explicit. |
| Pitfalls | HIGH | Risks are specific, reproducible, and mapped to prevention phases with measurable warning signals. |

**Overall confidence:** HIGH

### Gaps to Address

- Exact threshold values for solo-safe DPS and finisher deferral windows still need empirical tuning in benchmark scenarios.
- Side-channel hostile path inventory (wand/racial/utility helpers) should be fully enumerated during implementation to avoid missed gates.
- CP anomaly handling under high-latency/private-server tick jitter needs explicit stress validation before final defaults are locked.

## Sources

### Primary (HIGH confidence)
- `.planning/research/STACK.md` - stack constraints, module recommendations, API compatibility, telemetry suggestions.
- `.planning/research/FEATURES.md` - table stakes, differentiators, anti-features, and dependency graph.
- `.planning/research/ARCHITECTURE.md` - component boundaries, patterns, integration points, phase-aware validation points.
- `.planning/research/PITFALLS.md` - critical pitfalls, phase mapping, warning signs, and recovery strategies.
- `.planning/PROJECT.md`, `.api/game_object.lua`, `.api/common/enums.lua`, `EAXDruidRestoration/main.lua`, `EAXDruidFeral/main.lua`, `tools/rotation_validation.lua`, `tools/dps_benchmark.lua` (as cited in research docs).

### Secondary (MEDIUM confidence)
- Icy Veins TBC Restoration and Feral rotation references - role expectations and Rip/Bite usage norms.
- Warcraft Wiki and WowClassicDB Ferocious Bite/Combo Point references - expansion mechanics semantics and historical CP behavior.

### Tertiary (LOW confidence)
- None required for primary roadmap direction; low-confidence conclusions were not used as hard requirements.

---
*Research completed: 2026-03-21*
*Ready for roadmap: yes*
