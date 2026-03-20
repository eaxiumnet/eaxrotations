# Project Research Summary

**Project:** EAX TBC Classic Rotations (milestone v1.1 Combat Intelligence)
**Domain:** TBC Classic PvE reactive rotation AI (movement-excluded)
**Researched:** 2026-03-20
**Confidence:** HIGH

## Executive Summary

This milestone is not a greenfield rotation rewrite; it is a reliability and intelligence upgrade for a mature 27-spec Lua suite running on Sylvanas APIs. The strongest expert pattern across all research is a shared reactive decision pipeline (context snapshot -> role policy -> preemptive override -> action arbitration) inserted ahead of existing per-spec lanes, rather than bespoke per-spec reactive engines.

The recommended approach is to centralize v1.1 behavior into shared modules (`combat_context`, `reactive_engine`, `reactive_policies`, `benchmark_probe`) and keep per-spec `main.lua` files thin adapters. In parallel, enforce a strict `@.api` hard gate and promote benchmarking from throughput-only checks to a 27-spec matrix that includes behavior quality (interrupt timing, defensive latency, threat and overheal outcomes).

The highest risks are performance regression in tick hot paths, false confidence from static-only validation, and API-compliance drift under delivery pressure. Mitigation is explicit: cached context reads with tick-budget instrumentation, a three-layer validation model (static + deterministic scenario + live), fail-closed allowlist enforcement, and matrix sign-off that excludes mock rows.

## Key Findings

### Recommended Stack

v1.1 should stay pure Lua with no runtime dependency changes, but add shared runtime modules plus stricter local tooling. Plugin code remains Lua 5.x-compatible for Sylvanas runtime; tooling scripts target local Lua 5.4.5 for deterministic validation and benchmark artifact generation.

**Core technologies:**
- `common/eax_shared/combat_context.lua`: normalized per-tick snapshot builder - prevents repeated ad-hoc data reads and scale mismatches.
- `common/eax_shared/reactive_engine.lua` + `common/eax_shared/reactive_policies.lua`: deterministic role-aware arbitration - enables consistent reactive behavior across all 27 specs.
- `common/eax_shared/benchmark_probe.lua` / `eax_shared/benchmark_metrics.lua`: reactive KPI capture - extends raw DPS into behavior-quality scoring.
- `tools/api_surface_extract.lua` + `tools/api_hard_gate.lua`: API allowlist extraction and hard fail gate - enforces `@.api` contract as a blocker, not a warning.
- `tools/dps_benchmark.lua --matrix` + `tools/benchmark_matrix.lua`: standardized 27-spec matrix output - required for cross-spec regression control.

### Expected Features

Research converges on one definition of "combat intelligence": role-aware reactions layered onto existing rotation throughput, with strict legal-call validation and measurable cross-spec quality.

**Must have (table stakes):**
- Role-aware decision loop (DPS/HPS/Tank) with one-action arbitration per tick.
- Interrupt + defensive + utility preemption driven by context, not HP% only.
- Threat safety/recovery and healer triage with overheal-aware decisions.
- Encounter-phase cooldown policy (hold/burn/release).
- Strict `@.api` hard-gate enforcement.
- 27-spec benchmark matrix with DPS/HPS/TPS plus behavior checks.

**Should have (competitive):**
- Unified reactive kernel with per-spec policy profiles.
- Predictive reaction windows (cast-end, spike, threat decay).
- Intent lock / anti-thrash controls.
- Explainable decision telemetry (reason codes/branch IDs).

**Defer (v2+):**
- Deep encounter-specific predictive tuning beyond baseline parity.
- Movement/pathing AI and PvP logic (explicitly out of scope).

### Architecture Approach

Keep `EAX*/main.lua` as orchestration only, insert a shared context-first pipeline, and preserve existing rotation lanes as fallback. The architecture should separate "what to do" (shared engine/policies) from "how to cast" (spec adapters), then instrument every reactive decision for matrix-grade validation.

**Major components:**
1. `main.lua` (27 specs) - wiring, guard checks, shared pipeline invocation, fallback to existing lanes.
2. `common/eax_shared/combat_context.lua` - build a single normalized tick context (`self`, `target`, `party`, `encounter`).
3. `common/eax_shared/reactive_engine.lua` - enforce precedence (`life_save > interrupt > anti-overheal > anti-aggro > burst policy`).
4. `common/eax_shared/reactive_policies.lua` - central thresholds per role/spec to avoid drift.
5. `common/eax_shared/benchmark_probe.lua` - runtime reasoned event counters merged into matrix reporting.
6. `tools/api_hard_gate.lua` and updated `tools/rotation_validation.lua` - static compliance gate.
7. Updated `tools/dps_benchmark.lua` matrix mode - standardized cross-spec verdict output.

### Critical Pitfalls

1. **Tick-budget meltdown** - prevent with cheap-first checks, cached scans (100-250ms), table reuse, and p95/p99 loop telemetry.
2. **Priority oscillation / cast thrash** - prevent with strict decision ladder, mutual exclusivity, hysteresis, and reason-coded actions.
3. **False-positive validation** - prevent by separating static wiring checks from deterministic scenario replay and live runtime verification.
4. **Benchmark contamination** - prevent with fixed protocol + metadata, real-vs-mock tagging, and median/IQR-based interpretation.
5. **API compliance drift** - prevent with mandatory allowlist gate and shared adapter ownership of host/API calls.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Reactive Contract and API Gate Foundations
**Rationale:** Everything depends on a stable context schema and legal API surface before behavior tuning.
**Delivers:** `combat_context` schema, nil contracts, reason-code standard, `api_surface_extract` + `api_hard_gate` integrated into `rotation_validation`.
**Addresses:** API hard gate, state snapshot layer, action arbitration contract.
**Avoids:** API compliance drift, nil-state crashes, false-green validation.

### Phase 2: Shared Reactive Engine and Policy Wiring Across 27 Specs
**Rationale:** Central engine must be wired uniformly before per-role tuning can be trusted.
**Delivers:** `reactive_engine` + `reactive_policies`, adapter insertion in all `EAX*/main.lua`, backward-compatible manager context hints.
**Uses:** New shared modules from stack recommendations.
**Implements:** Architecture pattern of shared intent + spec execution adapters.

### Phase 3: Role Intelligence Pass (DPS/HPS/Tank Behavior Quality)
**Rationale:** After universal wiring, tune role-specific logic where intelligence quality is actually felt.
**Delivers:** Interrupt urgency, defensive timing from predicted damage, healer triage/overheal controls, tank threat recovery and cooldown phase policy.
**Addresses:** Core table-stakes reactive features.
**Avoids:** Throughput-only optimization and oscillation under pressure.

### Phase 4: Benchmark Matrix Hardening and Regression Enforcement
**Rationale:** v1.1 sign-off requires proof across all specs, not anecdotal performance.
**Delivers:** Matrix mode outputs with reactive KPIs, real-vs-mock run tagging, dispersion stats, fail thresholds, checklist sync.
**Addresses:** 27-spec benchmark requirement and release confidence.
**Avoids:** contaminated metrics and false-positive milestone completion.

### Phase Ordering Rationale

- Start with contracts and gates because every downstream phase can otherwise produce non-compliant or non-comparable results.
- Wire all specs before deep tuning to avoid tuning against partial adoption and cross-spec drift.
- Tune role intelligence before matrix hardening so KPIs capture intended behavior quality.
- End with enforcement to lock regressions and support repeatable release criteria.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3:** healer effective-heal triage thresholds and tank spike prediction calibration are domain-sensitive and need targeted scenario research.
- **Phase 4:** benchmark protocol calibration (encounter profiles, retry counts, dispersion thresholds) needs phase-level rigor to avoid noisy verdicts.

Phases with standard patterns (can likely skip `/gsd-research-phase`):
- **Phase 1:** API allowlist extraction + fail-closed lint gate is well-bounded and source-backed.
- **Phase 2:** shared-engine + adapter-boundary integration pattern is clear and already documented in architecture findings.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strong internal-source alignment (`PROJECT.md`, existing tools/modules, explicit version constraints). |
| Features | HIGH | Milestone requirements and shared-manager baseline clearly define must-haves; only fine-grain thresholds need tuning. |
| Architecture | HIGH | Directly grounded in current repo structure and concrete integration points across shared + per-spec code. |
| Pitfalls | HIGH | Pitfalls map to known Lua/runtime/tooling failure modes and match current validation/benchmark gaps. |

**Overall confidence:** HIGH

### Gaps to Address

- Healer and tank threshold calibration: finalize concrete trigger values via scenario-based replay + live runs before locking pass/fail KPI targets.
- Benchmark standardization details: confirm exact encounter presets, fight duration, retries, and allowable variance bands for matrix gating.
- Telemetry volume controls: validate default sampling/ring-buffer strategy so instrumentation does not degrade tick latency.

## Sources

### Primary (HIGH confidence)
- `.planning/research/STACK.md` - module/tooling recommendations, compatibility rules, integration sequence.
- `.planning/research/FEATURES.md` - table-stakes vs differentiators, anti-features, dependency chain.
- `.planning/research/ARCHITECTURE.md` - component boundaries, data flow, dependency-safe build order.
- `.planning/research/PITFALLS.md` - critical/moderate/minor risk patterns and phase warnings.
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `tools/rotation_validation.lua`, `tools/dps_benchmark.lua` (as cited in research files).

### Secondary (MEDIUM confidence)
- SimulationCraft APL action-list reference - baseline priority-loop model.
- Hekili priority adaptation notes - practical runtime translation patterns.

### Tertiary (LOW confidence)
- None required for core v1.1 conclusions.

---
*Research completed: 2026-03-20*
*Ready for roadmap: yes*
