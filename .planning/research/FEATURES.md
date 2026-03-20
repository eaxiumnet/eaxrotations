# Feature Landscape

**Domain:** TBC Classic PvE combat rotation AI (movement-excluded)
**Researched:** 2026-03-20

## How Full Reactive Combat AI Typically Works

Reactive combat AI systems in WoW-like ecosystems are usually implemented as a **priority decision loop** (snapshot state -> evaluate conditions -> pick highest-value legal action -> execute -> re-evaluate next tick/GCD). This matches SimulationCraft APL behavior and modern recommendation engines that adapt APL logic for live runtime decisions.

For this milestone, "full reactive" means role-specific decisions on top of normal DPS rotation:

- **DPS:** maximize throughput while reacting to interrupts, threat spikes, defensives, and encounter policy (hold/use cooldowns).
- **HPS:** triage targets by risk (incoming damage, current HP, expected overheal), choose efficient heal vs emergency heal, and reserve panic tools for lethal windows.
- **Tank:** maintain threat lead and mitigation uptime, react to spike windows, and prioritize survivability/GCD safety over raw DPS.

The common structure is:

1. **State Snapshot Layer** (API-safe reads only)
2. **Role Evaluators** (DPS/HPS/Tank scoring)
3. **Reactive Overrides** (interrupt/defensive/utility preemption)
4. **Action Arbitration** (one winner per decision frame, anti-thrash rules)
5. **Execution + Telemetry** (cast result + benchmark/diagnostic outputs)

---

## Table Stakes

Features users expect in v1.1 reactive combat AI. Missing any of these will make "combat intelligence" feel incomplete.

| Feature | Why Expected | Complexity | Dependencies on Existing System | Notes |
|---------|--------------|------------|----------------------------------|-------|
| Role-aware decision loop (DPS/HPS/Tank evaluators) | Core definition of "reactive AI"; static rotation is not enough | High | `main.lua` per spec, `spells.lua`, `utils.lua`, shared managers in `eax_shared/` | Must support preemption and one-action arbitration per tick |
| Interrupt orchestration with cast-time and spell danger scoring | Standard in serious PvE automation | Medium | `eax_shared/interrupt_manager.lua`, encounter policy flags | Existing interrupt core is strong; needs tighter role/encounter integration |
| Defensive ladder using incoming damage context (not HP% alone) | HP-only defensives are too late in spikes | High | `eax_shared/defensive_manager.lua`, encounter flags, threat data | Extend current threshold model with incoming-cast and burst-window awareness |
| Utility reaction layer (dispel/decurse/purge/CC break/control) | Expected in dungeon/raid automation parity | High | `eax_shared/encounter_manager.lua`, class utility spell tables, API-safe debuff reads | Should be gated by encounter policy to avoid random utility spam |
| Tank threat safety + aggro recovery behavior | Required for tank + high-output DPS stability | Medium | `eax_shared/threat_manager.lua`, taunt/fade/feint/salv logic per class | Threat manager exists; needs role-specific reaction policies |
| Healing triage with overheal-aware spell selection | HPS quality depends on efficiency and target risk, not spam | High | Per-healer spec logic, mana manager, encounter policy | Requires explicit "effective heal" logic to avoid chronic overheal |
| Cooldown policy by encounter phase (hold/burn/release) | Users expect boss-aware CD timing, not on-cooldown spam | Medium | `eax_shared/encounter_manager.lua`, per-spec cooldown lists | Burn-phase support exists; extend consistency across all 27 specs |
| Strict `@.api` hard-gate enforcement for runtime calls | Explicit milestone requirement | High | `.api/` contracts, wrappers in `utils.lua`, validation tooling | Must fail fast on non-compliant calls; no soft warnings |
| 27-spec benchmark matrix for DPS/HPS/TPS + behavior checks | Needed to prove parity and prevent regressions | Medium | `tools/dps_benchmark.lua`, `tools/rotation_validation.lua`, per-spec harness data | Current benchmark tooling is a base, needs behavior metrics beyond throughput |

---

## Differentiators

Features that move v1.1 from "good rotation pack" to "#1 combat intelligence suite".

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Unified reactive kernel + per-spec policy profiles | One decision architecture across 27 specs reduces drift and enables consistent behavior quality | High | Keep per-spec flavor, but centralize arbitration/preemption rules |
| Predictive reaction windows (cast-end, spike, threat lead decay) | Reacts before failure events (late kicks, late defensives, late fades) | High | Uses near-future estimates from cast timers, threat trend, encounter flags |
| Intent lock / anti-thrash arbitration | Prevents AI from oscillating between utility, defensive, and DPS actions every frame | Medium | Stabilizes output and improves human-like behavior |
| Explainable decisions in telemetry ("why this action fired") | Faster tuning and trust; benchmark failures are diagnosable | Medium | Extend benchmark output with reason codes and policy branch IDs |
| Role quality metrics, not just throughput | Distinguishes "high DPS but griefs group" from true intelligence | Medium | Track kick success quality, defensive timing quality, overheal %, threat incidents |

---

## Anti-Features

Features to explicitly NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Movement/pathing combat AI | Out of scope for this milestone; huge complexity explosion | Keep movement-excluded contract and maximize in-place decision quality |
| PvP/reactive arena logic | Different objective function and control model | Keep PvE-only combat intelligence focus |
| Direct memory or non-`@.api` access shortcuts | Violates hard-gate requirement and increases ban/risk profile | Enforce API wrapper layer and fail closed |
| Per-spec bespoke reactive engines | 27-way logic drift, impossible maintenance | Shared kernel + spec policy tables |
| "Perfect sim" overfitting | Runtime combat is noisy; hardcoded perfect scripts fail in real fights | Use robust priority + risk-aware heuristics with benchmark validation |

---

## Feature Dependencies

```text
API-safe State Snapshot
  -> Role Evaluators (DPS/HPS/Tank)
  -> Reactive Overrides (interrupt/defensive/utility)
  -> Action Arbitration (priority + anti-thrash + legality)
  -> Action Execution
  -> Telemetry + 27-Spec Benchmark Matrix

Encounter Policy + Threat + Cooldown State
  -> modifies Role Evaluators and Reactive Overrides at every decision point
```

Key dependency chain for this milestone:

1. `@.api` hard-gate wrappers
2. Shared reactive decision kernel
3. Role evaluators (DPS/HPS/Tank)
4. Interrupt/utility/defensive preemption layer
5. Benchmark matrix with behavior metrics

---

## MVP Recommendation (v1.1)

Prioritize:

1. **Reactive arbitration core + role evaluators**
2. **Interrupt/defensive/utility preemption integration**
3. **API hard-gate + benchmark matrix behavior pass across all 27 specs**

Defer:

- **Deep predictive tuning per encounter**: valuable differentiator, but only after baseline reactive parity passes the 27-spec matrix.

---

## Sources

- Internal project context: `.planning/PROJECT.md` (HIGH)
- Internal baseline requirements: `.planning/REQUIREMENTS.md` (HIGH)
- Current shared behavior modules: `eax_shared/interrupt_manager.lua`, `eax_shared/defensive_manager.lua`, `eax_shared/threat_manager.lua`, `eax_shared/encounter_manager.lua` (HIGH)
- Current benchmarking/validation tooling: `tools/dps_benchmark.lua`, `tools/rotation_validation.lua` (HIGH)
- SimulationCraft Action Priority List model (priority-loop baseline): https://github.com/simulationcraft/simc/wiki/ActionLists (MEDIUM, current page edit Mar 13, 2026)
- Hekili priority translation notes (live runtime adaptation of SimC priorities): https://github.com/Hekili/hekili/wiki/Priorities-and-Optimization (MEDIUM, current page edit Oct 25, 2024)

Confidence note: role-specific reactive heuristics (especially HPS effective-heal and tank spike anticipation) are based on ecosystem practice plus internal architecture evidence, but without a single authoritative TBC-era "standard" spec document; treat fine-grain threshold tuning as phase-level calibration work.
