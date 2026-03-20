# Domain Pitfalls

**Domain:** v1.1 combat intelligence for mature Lua rotation suite
**Researched:** 2026-03-20

## Critical Pitfalls

Mistakes that usually cause regressions, rewrite work, or invalid benchmark conclusions.

### Pitfall 1: Tick-Budget Meltdown from Reactive Logic
**What goes wrong:** Reactive AI adds many per-tick scans (incoming damage/heals/threat/auras) and dynamic table creation, causing frame-time spikes and delayed decisions.
**Why it happens:** Existing suite already runs 27 specs with duplicated modules; adding more logic in every tick path multiplies cost quickly.
**Consequences:** Missed interrupts/defensives, delayed casts, unstable DPS/HPS, and "AI feels random" bug reports.
**Prevention:**
- Establish per-tick budget and enforce cheap-first evaluation order.
- Move expensive scans to throttled caches (e.g., 100-250ms windows) instead of every frame.
- Reuse tables/state objects; avoid hot-path allocation churn.
- Instrument and log loop duration percentile (p50/p95/p99) in combat snapshots.
**Detection:** p95 tick time rises after enabling reactive modules; behavior degrades in AoE packs first.

### Pitfall 2: Priority Oscillation (Reactive vs Rotation Layers)
**What goes wrong:** New reactive branches fight base rotation branches, producing cast thrash (start/stop/swap) or cooldown starvation.
**Why it happens:** Reactive behavior is bolted on as ad-hoc if-chains instead of a deterministic decision contract.
**Consequences:** Throughput drops and behavior appears indecisive under pressure (especially heal/tank contexts).
**Prevention:**
- Use a strict decision ladder: `hard-safety -> hard-control -> role throughput -> filler`.
- Emit one explicit reason code per chosen action for traceability.
- Add hysteresis/debounce to state-triggered swaps (threat panic, overheal panic, target switch).
- Require mutually exclusive gates for reactive overrides.
**Detection:** Rapid action reason flips across adjacent ticks; cooldowns repeatedly held then dumped late.

### Pitfall 3: False-Positive Validation (Tooling Checks Wiring, Not Behavior)
**What goes wrong:** Validation passes while combat intelligence is still wrong in real encounters.
**Why it happens:** Current validator is mostly import/syntax checks; benchmark tool has dry-run mock rows and can appear "healthy" without real runtime behavior.
**Consequences:** Teams ship "green" results that fail in-game.
**Prevention:**
- Split validation into three gates: static wiring, deterministic scenario replay, and live manual run.
- Block milestone sign-off unless benchmark rows are runtime-tagged (`real` vs `mock`) and mock rows are excluded from score.
- Add behavior assertions per role (interrupt timeliness, defensive latency, overheal control).
**Detection:** 27/27 pass static checks but manual notes remain pending or contradictory.

### Pitfall 4: Benchmark Contamination and Misinterpretation
**What goes wrong:** DPS/HPS/TPS numbers become incomparable across specs/runs due to mixed contexts, CPU-time timing misuse, and uncontrolled warmup state.
**Why it happens:** Manual-only environment plus no standardized harness isolation.
**Consequences:** Wrong optimization decisions (overfitting to noisy runs, nerfing stable logic for short-term gains).
**Prevention:**
- Standardize benchmark protocol: fixed encounter profile, fixed gear/buffs/consumables, fixed duration, fixed retry count.
- Record metadata alongside metrics (spec, target profile, fight length, mode toggles, version hash).
- Separate CPU-time instrumentation from combat-time throughput metrics.
- Use median + dispersion (IQR/p95), not single-run maxima.
**Detection:** Big metric swings between consecutive runs with unchanged build; "best run" is consistently used as report value.

### Pitfall 5: API Compliance Drift Under Delivery Pressure
**What goes wrong:** Reactive shortcuts introduce non-`@.api` calls or inconsistent wrappers to get data "quickly."
**Why it happens:** Expanding logic surface and duplicated modules increase chances of one-off API usage.
**Consequences:** Hard-gate failures late in milestone, emergency cleanup across many specs.
**Prevention:**
- Add explicit API allowlist lint pass as required pre-merge gate.
- Route all host interactions through shared adapter functions with one ownership point.
- Treat non-compliant calls as blocker severity, not cleanup backlog.
**Detection:** New modules pass `luac` but fail API-gate scan; same forbidden call appears in multiple spec copies.

### Pitfall 6: Error Handling Gaps in Reactive Paths
**What goes wrong:** Nil/invalid runtime data (missing spell rank, missing item requirement, transient API nil) crashes or silently skips important actions.
**Why it happens:** Reactive code touches more edge-state combinations and often assumes data exists.
**Consequences:** Random script stops, "works on my spec" behavior variance, hard-to-reproduce failures.
**Prevention:**
- Wrap non-trivial decision steps with protected execution and explicit fallback action.
- Normalize nil handling contract in shared helpers (`unknown`, `unavailable`, `ready`).
- Track and alert on fallback frequency by module.
**Detection:** Intermittent errors in crowded encounters; same state intermittently resolves to cast/no-cast without code changes.

## Moderate Pitfalls

### Pitfall 1: Cross-Spec Drift from Duplicated Modules
**What goes wrong:** Fix lands in some specs but not all 27 copies.
**Prevention:** Land reactive logic in shared modules first; use generated adoption matrix and fail build if any spec is not wired.

### Pitfall 2: Overfitting to DPS and Regressing Survival
**What goes wrong:** AI chases throughput and delays defensives/utility.
**Prevention:** Score benchmark as weighted objective (throughput + survivability + control accuracy), not DPS-only.

### Pitfall 3: Unbounded Telemetry Volume
**What goes wrong:** Debug/event logs flood runtime and distort performance.
**Prevention:** Add sampling, ring buffers, and log levels; keep high-frequency traces off by default.

## Minor Pitfalls

### Pitfall 1: Ambiguous Reason Labels
**What goes wrong:** Logs say what cast happened, not why it won.
**Prevention:** Enforce structured reason codes and a one-line human label.

### Pitfall 2: Missing Rollback Toggles
**What goes wrong:** New reactive layer cannot be disabled quickly when instability appears.
**Prevention:** Ship feature flags per module (`reactive_damage`, `reactive_heal`, `reactive_threat`) with safe defaults.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1 - Reactive Core Contract | Priority oscillation and nil-state chaos | Define deterministic decision ladder, reason codes, and nil contracts before per-spec tuning |
| Phase 2 - Shared Integration | Cross-spec drift and API compliance drift | Centralize adapters in shared modules, enforce allowlist scan, fail on partial spec wiring |
| Phase 3 - Benchmark Matrix Hardening | Contaminated metrics and false-positive validation | Separate mock vs real runs, standardize benchmark protocol, require dispersion stats |
| Phase 4 - Rollout and Regression | Tick-budget meltdown in high-density fights | Enable per-module flags, monitor p95/p99 loop time, staged rollout by role then all specs |

## Sources

- `C:\newbot\scripts\.planning\PROJECT.md` (project constraints, API gate, 27-spec architecture) - HIGH
- `C:\newbot\scripts\.planning\REQUIREMENTS.md` (v1.1 requirements and quality expectations) - HIGH
- `C:\newbot\scripts\tools\rotation_validation.lua` (current validation scope: syntax/import checks) - HIGH
- `C:\newbot\scripts\tools\dps_benchmark.lua` (dry-run/mock benchmark rows and current output contract) - HIGH
- `C:\newbot\scripts\.planning\phases\04-polish-competitive-features\04-VALIDATION.md` (manual-only verification boundaries) - HIGH
- https://www.lua.org/manual/5.1/manual.html (GC model, `collectgarbage`, `pcall`, `os.clock`) - HIGH
