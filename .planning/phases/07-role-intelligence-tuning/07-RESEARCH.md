# Phase 07: Role Intelligence Tuning - Research

**Date:** 2026-03-20
**Scope:** ROLE-01, ROLE-02, ROLE-03, ROLE-04

## Current Baseline

- `eax_shared/reactive_runtime.lua` still drives winner selection through one shared six-branch contract, but its default branch triggers are generic thresholds (`hp_pct <= 0.35`, `any_ally_critical`, `threat_pct >= 0.90`) rather than role-aware policies.
- `eax_shared/combat_context.lua` already normalizes self health, incoming heals, incoming damage, threat, target cast state, and coarse party/encounter flags, but it does not yet expose enough structure for healer tank-first triage, tank threat-instability recovery, or cast-danger scoring.
- Healer specs already contain strong local building blocks: `EAXDruidRestoration/main.lua` has `pick_tank_unit(...)` and `pick_priority_heal_target(...)`; `EAXPriestHoly/main.lua`, `EAXPriestDiscipline/main.lua`, `EAXPaladinHoly/main.lua`, and `EAXShamanRestoration/main.lua` already expose emergency heal / stop-cast helpers that can be reused instead of inventing new spell lists.
- Tank specs already have recovery-control building blocks: `EAXWarriorProtection/main.lua` has explicit aggro-recovery scoring, retarget helpers, and taunt / bash / control lanes; `EAXDruidFeral/main.lua` already has `try_growl(...)`, `try_taunt_off_party(...)`, `try_challenging_roar(...)`, and multiple proactive defensives; `EAXPaladinProtection/main.lua` already exposes protection cooldown and control helpers.
- `tools/rotation_validation.lua`, `tests/reactive_runtime_wiring_spec.lua`, `tests/rotation_validation_spec.lua`, and `tools/dps_benchmark.lua` already provide the right blocking/reporting surfaces for Phase 07. The repo should extend those instead of creating a parallel validator.

## Findings

### Shared role-policy layer should stay inside the existing six-branch contract

1. **Do not add a second reactive engine**
   - Phase 05 and Phase 06 locked one shared reactive winner contract and one shared runtime entrypoint.
   - Phase 07 should keep `reactive_runtime.update_tick(...)` and the six branch names unchanged, then make the branch conditions role-aware through a shared policy module.
   - Best fit: create one shared module (for example `eax_shared/role_policy.lua`) that owns role thresholds, control urgency, and branch trigger decisions; `reactive_runtime.lua` should consume that module instead of hardcoded generic thresholds.

2. **Enrich the shared combat snapshot before touching spec files**
   - Healer and tank tuning need richer shared inputs than `any_ally_critical` and `interrupt_priority`.
   - The shared snapshot should expose deterministic fields for at least these behaviors:
     - self danger as both raw damage and normalized damage (`incoming_damage_2s`, `incoming_damage_pct_2s`)
     - per-party-member triage inputs (`hp_pct`, `incoming_heal_pct`, role/tank marker)
     - the current best tank target and current best uncovered ally target
     - cast danger hints (`cast_progress_pct`, victim role, encounter priority flag)
     - threat-instability hints for tanks and non-tanks
   - This keeps role decisions shared and testable instead of pushing ad hoc scans into 27 specs.

### Healer behavior should centralize triage instead of duplicating target scoring in five specs

1. **Tank-first triage should be one helper, not five near-matches**
   - `EAXDruidRestoration/main.lua` already proves the shape: identify tank, then compare that target against the lowest ally.
   - Phase 07 should extract a shared healer triage helper that returns one deterministic target plus a reason (`tank_save`, `triage_save`, `group_stabilize`, `covered_hold`).
   - Healer adapters can then call their existing spell helpers against that one target.

2. **Incoming-heal / overheal awareness should gate stop-cast, not block obvious saves**
   - Current healer adapters mostly either hard-cast a big heal or hard-stop on existing stop-cast helpers.
   - The locked decision is: respect incoming heals and avoid pointless topping, but never suppress a clearly stabilizing action.
   - Shared triage should therefore mark a target as covered only when incoming heals are already enough relative to current HP/risk, and anti-overheal should only stop casts on healthy or already-secured targets.

### Tank behavior should treat aggro recovery as a first-class reactive branch

1. **`anti_aggro` should stop being DPS-only**
   - For tanks, the same branch is the right place to express aggro recovery / peel behavior: taunt, retarget, control, then restore order.
   - `EAXWarriorProtection/main.lua` already has the right primitives for target scoring, dangerous caster preference, and retarget discipline.
   - `EAXDruidFeral/main.lua` proves the same behavior family with `Growl` and party-peel logic.
   - Phase 07 should make tank `anti_aggro` real instead of `noop = "unsupported"`.

2. **Personal defensives still need proactive pressure windows**
   - Tanks should not wait for panic-only thresholds.
   - Shared tank helpers should distinguish between `pressure rising`, `threat unstable`, and `self death imminent`, so aggro recovery normally wins but hard defensives still fire when collapse risk is real.

### DPS behavior needs one shared risk helper plus broad rollout across offensive cooldown lanes

1. **Reactive branches alone are not enough**
   - The user locked two DPS behaviors that live outside simple interrupt/defensive reactions: hold major offensives during unstable danger windows, and abandon cast/channel commitment earlier when danger is clearly rising.
   - Existing DPS specs already have offensive cooldown helpers (`try_combustion`, trinkets, racials, burst windows, etc.). Phase 07 should gate those helpers through one shared DPS-risk module instead of hand-tuning each cooldown independently.

2. **Shared DPS risk helper should drive both commit and release decisions**
   - Recommended exports:
     - `should_hold_offense(ctx)`
     - `should_drop_threat(ctx)`
     - `should_abort_commit(ctx, cast_state)`
   - Caster specs should use the abort helper to stop greedily finishing casts when danger is rising.
   - Melee / instant specs should use the same helper to suppress burst cooldowns and threat-sensitive commits.

### Urgency-aware control should stay shared and deterministic

1. **Danger scoring belongs in the shared policy, not scattered in spec files**
   - Phase 07 must choose the single most dangerous event when multiple casts or utility opportunities exist.
   - The shared policy should score dangerous casts using exact inputs already available or easy to derive: interruptibility, cast/channel progress, encounter `interrupt_priority`, victim role (tank/healer/damager/self), and whether control would create avoidable chaos.
   - Spec adapters should only map the winning control branch to legal spells (kick, bash, fear, taunt-side control, stop-cast), not recalculate urgency.

2. **Fear / chaos tools need stricter guards than clean interrupts**
   - The locked decision explicitly rejects chaos-for-convenience.
   - Plans should require fear / scatter / chaos tools only when the shared policy marks the window as worth the disruption; otherwise keep them unsupported or lower-priority.

## Decisions for Planning

- Plan Phase 07 as one shared-core plan, then parallel healer / tank / DPS family rollout plans, then one final validation/reporting plan.
- Keep the six branch names and `reactive_runtime.update_tick(...)` entrypoint intact; make role quality emerge from shared role-policy helpers and richer snapshot data.
- Use one shared healer triage helper for all five healer specs.
- Use one shared tank recovery helper for Protection Warrior, Protection Paladin, and Feral Druid.
- Use one shared DPS risk helper for every non-healer DPS file so offensive cooldown holds and early cast aborts are consistent.
- Extend `tools/rotation_validation.lua` and `tools/dps_benchmark.lua` instead of creating new blocking scripts.

## Risks / Pitfalls

- If Phase 07 edits only representative specs, behavior quality will drift badly across the remaining DPS/healer/tank files; plans must explicitly name the rollout groups.
- If control urgency stays embedded in spec files, different specs will disagree on what counts as the most dangerous cast; this would violate the locked deterministic policy.
- If healer anti-overheal logic is too aggressive, the system will skip stabilizing casts; plans must preserve the rule that obvious saves always beat efficiency.
- If tank aggro-recovery logic reuses `anti_aggro` without explicit tank-only thresholds, tanks may spam taunt/control in stable windows; plans must require recovery only on measurable instability.
- If DPS risk gates only trinkets and racials but not class-specific burst helpers, users will still see greedy commit behavior during danger windows.

## Validation Architecture

- **Wave 0:** existing Lua assert-style scripts are sufficient; no framework install is needed.
- **Per task:** run focused family tests first, then `rtk lua tests/reactive_runtime_wiring_spec.lua` when adapter wiring changes.
- **Per wave:** run the phase suite:
  - `rtk lua tests/combat_context_spec.lua`
  - `rtk lua tests/role_policy_spec.lua`
  - `rtk lua tests/healer_role_behavior_spec.lua`
  - `rtk lua tests/tank_role_behavior_spec.lua`
  - `rtk lua tests/dps_role_behavior_spec.lua`
  - `rtk lua tests/reactive_runtime_spec.lua`
  - `rtk lua tests/reactive_runtime_wiring_spec.lua`
  - `rtk lua tests/rotation_validation_spec.lua`
  - `rtk lua tools/rotation_validation.lua`
  - `rtk lua tools/dps_benchmark.lua --dry-run`

## Sources

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/07-role-intelligence-tuning/07-CONTEXT.md`
- `.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md`
- `.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md`
- `.planning/phases/05-reactive-contract-api-gate/05-05-SUMMARY.md`
- `.planning/phases/06-27-spec-reactive-wiring/06-01-SUMMARY.md`
- `.planning/phases/06-27-spec-reactive-wiring/06-02-SUMMARY.md`
- `.planning/codebase/ARCHITECTURE.md`
- `.planning/codebase/CONVENTIONS.md`
- `.planning/codebase/TESTING.md`
- `eax_shared/combat_context.lua`
- `eax_shared/reactive_engine.lua`
- `eax_shared/reactive_runtime.lua`
- `eax_shared/dps_meter.lua`
- `tools/dps_benchmark.lua`
- `tools/rotation_validation.lua`
- `tests/combat_context_spec.lua`
- `tests/reactive_engine_spec.lua`
- `tests/reactive_runtime_spec.lua`
- `tests/reactive_runtime_wiring_spec.lua`
- `tests/rotation_validation_spec.lua`
- `EAXMageFire/main.lua`
- `EAXPriestHoly/main.lua`
- `EAXPriestDiscipline/main.lua`
- `EAXPaladinHoly/main.lua`
- `EAXDruidRestoration/main.lua`
- `EAXShamanRestoration/main.lua`
- `EAXWarriorProtection/main.lua`
- `EAXPaladinProtection/main.lua`
- `EAXDruidFeral/main.lua`

## RESEARCH COMPLETE

Phase 07 should be planned as 5 execution plans in 3 waves:
- Plan 01: enrich shared context and add one shared role-policy contract.
- Plan 02: roll deterministic triage into all healer specs.
- Plan 03: roll proactive threat-control and defensive posture into all tank specs.
- Plan 04: roll shared DPS risk gating into all non-healer DPS specs.
- Plan 05: add blocking role-parity validation and benchmark-visible role-quality output.
