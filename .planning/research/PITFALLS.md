# Pitfalls Research

**Domain:** Druid reliability fixes in a mature Lua bot rotation framework (TBC 2.4.3)
**Researched:** 2026-03-21
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Group-Context Drift Causes Healer DPS Leaks

**What goes wrong:**
Resto enters DPS behavior in party/raid content because combat context is stale or misdetected for a few ticks.

**Why it happens:**
Mode is cached on a throttle, not recomputed every decision tick, and strict role policy is not enforced as a global guard at the top of every hostile action path.

**How to avoid:**
- Build one `is_group_healer_lock` gate (single source of truth) and check it before any hostile cast/attack path.
- Evaluate mode/group context at rotation decision time, not just in a 5s cache refresh.
- Fail closed: if mode/context is uncertain, treat Resto as no-DPS.

**Warning signs:**
- Logs show `mode=solo` spikes during dungeon/raid pulls.
- Resto HUD shows offensive casts shortly after group joins, zoning, or combat start.
- Repro appears "intermittent" and often lasts 1-3 GCDs.

**Phase to address:**
Phase 1 - Role Policy Hard Lock (context + gating contract before spell-priority edits).

---

### Pitfall 2: Side-Channel Offense Bypasses the No-DPS Policy

**What goes wrong:**
Even when main DPS fallback is disabled for groups, other modules still perform hostile actions (e.g., wand fallback, offensive racials, shared utility hooks).

**Why it happens:**
Policy gating is added only in the main rotation branch, while other subsystems (leveling helpers, racials, utility managers, callbacks) can still trigger damage.

**How to avoid:**
- Add a policy check wrapper around every hostile-capable helper (`cast_unit`, `cast_target`, wand/melee, offensive racial hooks).
- Maintain an explicit allowlist for healer-group-hostile actions (usually empty, except explicit user override for emergencies if desired).
- Add structured reason codes to all hostile actions so policy violations are observable.

**Warning signs:**
- No-DPS branch looks correct in review, but combat logs still show white swings/wand/racial-triggered damage.
- Violations occur when no healing target exists ("idle windows").
- Bug only appears with specific toggles (`use_wand`, racials, utility options).

**Phase to address:**
Phase 2 - Integration Hardening (cross-module policy enforcement).

---

### Pitfall 3: UI/Mode Overrides Undercut Reliability Guarantees

**What goes wrong:**
Strict no-DPS guarantees are broken by user mode overrides (forced solo/dungeon/raid) that conflict with real context.

**Why it happens:**
"Auto" and forced mode controls are useful for debugging, but production behavior promises are expressed as hard guarantees. Without precedence rules, UI can silently defeat policy.

**How to avoid:**
- Define precedence explicitly: safety policy > role lock > user throughput preferences.
- Restrict overrides in grouped healer contexts (or require explicit "unsafe override" toggle with warning).
- Display active policy state on HUD/menu (e.g., `Resto Lock: GROUP HEAL-ONLY`).

**Warning signs:**
- "Can not repro" disagreements between users with different mode settings.
- Support reports that fix works on one profile but not another.
- Bug disappears when mode is set back to Auto.

**Phase to address:**
Phase 1 - Role Policy Hard Lock (policy precedence and UX guardrails).

---

### Pitfall 4: Incorrect Finisher Energy Math Starves Feral CP Spending

**What goes wrong:**
Feral reaches 5 combo points but never bites (or bites far too rarely) because energy requirements are modeled incorrectly.

**Why it happens:**
Ferocious Bite energy pooling is frequently misimplemented. In TBC it is a base cost plus optional extra-energy conversion, not an always-required `35 * combo_points` gate.

**How to avoid:**
- Encode TBC finisher mechanics as constants from expansion-specific references, with comments tied to source.
- Separate "minimum cast cost" from "optional bonus-energy spending" in logic.
- Add an assertion metric: "time at CP>=5 and in-melee while no finisher cast" threshold must stay below target.

**Warning signs:**
- Long CP cap windows (`CP=5`) with repeated builders/powershifts and no finisher cast.
- Bite appears only in low-CP killshot paths.
- DPS dips specifically on execute/finisher-heavy pulls.

**Phase to address:**
Phase 2 - Feral Finisher State Machine (mechanics-correct spender logic).

---

### Pitfall 5: Combo Point Ownership Regressions (Player vs Target Semantics)

**What goes wrong:**
CP counter desyncs (stuck at 0, ghost CP, or random resets) and spenders misfire.

**Why it happens:**
Refactors reintroduce old mistakes: reading CP from target object, resetting on combat-flag flicker, or not reconciling API reads with cast-callback fallback.

**How to avoid:**
- Keep CP as a dedicated state machine with explicit inputs: `api_read`, `cast_event`, `target_change`, `target_death`.
- Prefer player power API as source of truth; cast-callback counter is fallback only.
- Reset CP only on confirmed target-change/death events, never on transient `is_in_combat` flips.

**Warning signs:**
- CP jumps backward/forward without builder or finisher event.
- CP wipes during target downtime while the same target remains valid.
- Reproduces more on laggy/private-server ticks.

**Phase to address:**
Phase 2 - Feral Finisher State Machine (CP sync and reset rules).

---

### Pitfall 6: Target Selection Fights CP Preservation

**What goes wrong:**
At finisher threshold, targeting systems switch targets (focus/smart targeting), wasting built combo points and delaying spenders.

**Why it happens:**
Target selection and finisher execution are often implemented independently; CP-preservation lock is bypassed by special targeting modes.

**How to avoid:**
- Make CP-lock a first-class targeting rule when CP >= min finisher threshold.
- Apply lock consistently across normal, smart-target, and focus-target paths (or make bypass explicit and logged).
- Add "target switched at CP cap" telemetry counter.

**Warning signs:**
- Frequent logs showing target swaps at CP 4-5.
- Finisher casts occur on a different mob than builders.
- Damage profile shows excess builder casts per finisher.

**Phase to address:**
Phase 3 - Targeting + Rotation Integration (lock semantics across selectors).

---

### Pitfall 7: Pending-Cast/Priority Deadlocks Starve Finishers

**What goes wrong:**
Spender conditions are technically met, but finisher keeps getting skipped due to stale pending-cast flags, overstrict refresh guards, or competing utility priorities.

**Why it happens:**
Reliability fixes add many guards (`pending`, refresh windows, killshot checks, snapshot holds). Without bounded hold time and priority invariants, finishers can be deferred indefinitely.

**How to avoid:**
- Define a max deferral window for spenders at CP cap.
- Expire pending-cast state aggressively on miss/fail/no-GCD confirmation.
- Add deterministic priority rule: at CP cap in melee and valid target, spender must preempt non-critical builders/utility.

**Warning signs:**
- Repeated "hold" log reasons with no eventual finisher.
- CP cap uptime remains high despite in-range uptime.
- Players report "rotation feels busy but never cashes out."

**Phase to address:**
Phase 2 - Feral Finisher State Machine (bounded hold + preemption rules).

---

### Pitfall 8: Validation Scope Misses Behavior Regressions

**What goes wrong:**
Fixes pass syntax/import checks and spot tests but still fail real reliability goals (no-DPS in groups, CP spend consistency).

**Why it happens:**
Current environment is manual-only; without scenario checklists and counters, teams validate "code paths exist" instead of "behavior stayed correct over time."

**How to avoid:**
- Add milestone-specific manual validation matrix:
  - Resto: party/raid transitions, forced mode permutations, no-heal idle windows.
  - Feral: CP cap scenarios, target swap stress, execute/killshot windows.
- Track objective metrics (`group_hostile_cast_count`, `cp_cap_seconds`, `finishers_per_5cp_window`).
- Require benchmark evidence before milestone close.

**Warning signs:**
- "Looks fixed" PRs with no scenario logs.
- Regressions reappear after unrelated refactors.
- Verification notes rely on one short fight sample.

**Phase to address:**
Phase 4 - Validation and Benchmark Gate (evidence-based sign-off).

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Per-file ad-hoc role checks instead of one shared policy gate | Fast local fix | Policy drift and repeated leaks in other modules/specs | Never for healer no-DPS guarantees |
| Hardcoding finisher thresholds without expansion mechanics notes | Quick tuning | Silent mechanic regressions in future refactors | Only as temporary hotfix with explicit TODO and source link |
| Using cast-callback CP counters as primary truth | Works when API flaky | Desync under duplicate/missed events | Only fallback mode when API read fails |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `leveling_manager` + healer role logic | Wand/melee fallback runs in grouped healer contexts | Route all offensive fallback through role-policy gate |
| `racial_manager` + strict no-DPS policy | Offensive racials fire globally regardless role context | Split offensive/utility racials and gate offensive path by policy |
| Target selector + CP finisher lock | Focus/smart-target overrides bypass CP lock | Apply CP lock before selector output is finalized |
| Mode detection + throttling | 5s cached mode used as truth during transitions | Recheck critical policy context at decision time (fail closed) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Recomputing full group scans for every gate in hot path | Frame spikes in large pulls | Cache with short TTL and share snapshot per tick | 5-man packs with frequent target churn |
| Excessive CP debug logging in combat | Input lag and noisy logs | Structured counters + sampled debug mode | Long dungeon sessions |

## "Looks Done But Is Not" Checklist

- [ ] **Resto no-DPS lock:** Verified zero hostile casts/attacks in party and raid, including idle/no-heal windows.
- [ ] **Resto policy precedence:** Forced mode overrides cannot silently bypass healer-group lock.
- [ ] **Feral CP reliability:** Finisher fires within bounded window when CP cap + in-melee conditions are met.
- [ ] **Feral target integrity:** No target swap at CP cap unless explicit, logged override.
- [ ] **Integration safety:** Wand/racials/shared helpers honor role policy gates.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Healer DPS leak in groups | MEDIUM | Hot-disable hostile helpers via master policy gate, then patch leaked modules one by one with regression checklist |
| CP spend starvation | HIGH | Patch finisher energy model + CP state machine, run CP-cap scenario validation, retune builder/hold guards |
| Target-swap CP waste | MEDIUM | Enforce CP-lock target pinning and add telemetry alarm for CP-cap swaps |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Group-context drift (Resto DPS leak) | Phase 1 - Role Policy Hard Lock | 0 hostile casts in grouped healer scenarios across transition tests |
| Side-channel offense bypass | Phase 2 - Integration Hardening | Hostile-action reason logs show all actions passing policy gate |
| UI/mode override conflicts | Phase 1 - Role Policy Hard Lock | Forced-mode tests cannot bypass healer-group lock without explicit unsafe toggle |
| Finisher energy math errors | Phase 2 - Feral Finisher State Machine | CP-cap dwell time and finisher latency stay within thresholds |
| CP ownership/state desync | Phase 2 - Feral Finisher State Machine | CP traces show consistent builder+spender accounting in stress tests |
| CP lock vs targeting conflict | Phase 3 - Targeting + Rotation Integration | `target_switched_at_cp_cap` counter near zero in benchmark set |
| Pending-cast deadlocks | Phase 2 - Feral Finisher State Machine | No repeated hold-reason loops without eventual spender |
| Validation blind spots | Phase 4 - Validation and Benchmark Gate | Milestone sign-off includes scenario matrix + metric evidence |

## Sources

- `C:\newbot\scripts\.planning\PROJECT.md` - project scope, milestone goals, constraints (HIGH)
- `C:\newbot\scripts\EAXDruidRestoration\main.lua` - mode detection, DPS fallback, wand/racial integration paths (HIGH)
- `C:\newbot\scripts\EAXDruidRestoration\menu.lua` - mode/solo-DPS controls and defaults (HIGH)
- `C:\newbot\scripts\EAXDruidFeral\main.lua` - CP sync, target lock, finisher order, energy pooling implementation (HIGH)
- `C:\newbot\scripts\eax_shared\role_policy.lua` - policy model expectations and role-action contract shape (HIGH)
- https://warcraft.wiki.gg/wiki/Ferocious_Bite (retrieved 2026-03-21; BC Classic section for cost semantics) (MEDIUM)
- https://warcraft.wiki.gg/wiki/Combo_point (retrieved 2026-03-21; historical target-bound semantics in pre-6.0 context) (MEDIUM)

---
*Pitfalls research for: Druid reliability fixes (Resto no-DPS policy + Feral CP spending reliability)*
*Researched: 2026-03-21*
