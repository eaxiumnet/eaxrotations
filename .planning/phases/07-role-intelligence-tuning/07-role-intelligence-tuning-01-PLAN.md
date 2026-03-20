---
phase: 07-role-intelligence-tuning
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/combat_context.lua
  - eax_shared/role_policy.lua
  - eax_shared/reactive_runtime.lua
  - tests/combat_context_spec.lua
  - tests/role_policy_spec.lua
  - tests/reactive_runtime_spec.lua
autonomous: true
requirements: [ROLE-01, ROLE-02, ROLE-03, ROLE-04]
user_setup: []
must_haves:
  truths:
    - "Shared reactive winners use role-aware danger, triage, threat, and control logic instead of generic one-size-fits-all thresholds"
    - "Healer, tank, and DPS plans can consume one stable shared policy contract without inventing separate winner logic"
    - "Urgent control windows are scored deterministically from cast danger and victim context before any spec-specific spell mapping"
  artifacts:
    - path: "eax_shared/combat_context.lua"
      provides: "Richer normalized inputs for role-aware triage, threat, and cast-danger decisions"
      contains: "incoming_damage_pct_2s"
    - path: "eax_shared/role_policy.lua"
      provides: "Shared role-aware branch trigger contract for the six reactive action families"
      contains: "build_actions"
    - path: "eax_shared/reactive_runtime.lua"
      provides: "Role-policy-backed default action selection inside the existing shared runtime entrypoint"
      contains: "role_policy"
    - path: "tests/role_policy_spec.lua"
      provides: "Deterministic proofs for healer, tank, DPS, and control urgency decisions"
      contains: "interrupt_control"
  key_links:
    - from: "eax_shared/reactive_runtime.lua"
      to: "eax_shared/role_policy.lua"
      via: "default branch actions are built from the shared role policy"
      pattern: "role_policy\.build_actions"
    - from: "eax_shared/role_policy.lua"
      to: "eax_shared/combat_context.lua"
      via: "role scoring reads normalized danger, party, target, and threat fields"
      pattern: "incoming_damage_pct_2s"
    - from: "tests/role_policy_spec.lua"
      to: "eax_shared/role_policy.lua"
      via: "role-policy unit cases assert branch decisions directly"
      pattern: "build_actions"
---

<objective>
Build the shared role-intelligence foundation that Phase 07 family plans will execute against: richer combat-context inputs, one shared role-policy module, and deterministic tests proving healer triage, tank threat recovery, DPS risk gating, and urgency-aware control decisions.

Purpose: If Phase 07 starts by editing spec files only, 27 adapters will drift into different ideas of danger and urgency. One shared contract keeps all role tuning consistent.
Output: `combat_context` enrichments, a new `role_policy` module, and focused tests for the shared policy surface.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/07-role-intelligence-tuning/07-CONTEXT.md
@.planning/phases/07-role-intelligence-tuning/07-RESEARCH.md
@.planning/phases/07-role-intelligence-tuning/07-VALIDATION.md
@.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md
@.planning/phases/06-27-spec-reactive-wiring/06-02-SUMMARY.md
@eax_shared/combat_context.lua
@eax_shared/reactive_engine.lua
@eax_shared/reactive_runtime.lua
@tests/combat_context_spec.lua
@tests/reactive_engine_spec.lua
@tests/reactive_runtime_spec.lua

<interfaces>
From `eax_shared/reactive_engine.lua`:
```lua
local ORDER = {
  { name = "life_save_self", reason_code = reactive_engine.reason_codes.LIFE_SAVE_SELF },
  { name = "life_save_ally", reason_code = reactive_engine.reason_codes.LIFE_SAVE_ALLY },
  { name = "interrupt_control", reason_code = reactive_engine.reason_codes.INTERRUPT_DANGER },
  { name = "anti_overheal", reason_code = reactive_engine.reason_codes.ANTI_OVERHEAL },
  { name = "anti_aggro", reason_code = reactive_engine.reason_codes.ANTI_AGGRO },
  { name = "throughput_resume", reason_code = reactive_engine.reason_codes.THROUGHPUT_RESUME },
}
```

From `eax_shared/reactive_runtime.lua`:
```lua
function reactive_runtime.update_tick(me, target, deps)
  -- keep this entrypoint and the existing six branch names
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Enrich the shared snapshot and add a role-policy module</name>
  <read_first>
    - eax_shared/combat_context.lua
    - eax_shared/reactive_engine.lua
    - eax_shared/reactive_runtime.lua
    - tests/combat_context_spec.lua
    - tests/reactive_engine_spec.lua
  </read_first>
  <files>eax_shared/combat_context.lua, eax_shared/role_policy.lua, eax_shared/reactive_runtime.lua, tests/combat_context_spec.lua, tests/role_policy_spec.lua</files>
  <behavior>
    - Test 1: the shared snapshot exposes role-tuning fields for normalized damage pressure, richer party triage, and cast-danger context without breaking fail-safe behavior.
    - Test 2: healer policy returns `life_save_ally` for an unstable tank before a slightly lower non-tank ally, unless incoming heals already cover the tank.
    - Test 3: tank policy returns `anti_aggro` for threat-instability recovery before throughput, unless self-death is the higher-priority emergency.
    - Test 4: control policy returns `interrupt_control` for the single most dangerous cast using victim-role plus encounter-priority inputs.
  </behavior>
  <action>Create `eax_shared/role_policy.lua` and export `build_actions(opts)` plus any small pure helpers it needs. Keep the exact six branch names already locked by Phases 05 and 06. Update `eax_shared/combat_context.lua` to surface these exact normalized fields for the policy layer: `self.incoming_damage_pct_2s`, `party.members`, `party.tank`, `party.urgent_ally`, `party.group_collapse_risk`, `target.cast_progress_pct`, `target.victim_role`, and `target.victim_is_self`. Preserve existing fail-safe semantics: missing reads must still zero danger hints and set `ctx.meta.fail_safe = true` instead of guessing. Update `eax_shared/reactive_runtime.lua` so its default actions come from `role_policy.build_actions(...)` rather than the current inline generic thresholds. Implement concrete policy rules from the locked decisions: DPS sacrifices throughput only for clear self-death or wipe-preventing windows; healer `life_save_ally` is tank-first until the tank is stably covered, then lowest urgent ally; tank `anti_aggro` fires on unstable aggro / party peel windows and beats personal defensive use unless self death is imminent; `interrupt_control` scores cast danger from interruptibility, progress, encounter priority, and victim role so the single most dangerous cast wins.</action>
  <acceptance_criteria>
    - `eax_shared/combat_context.lua` contains `incoming_damage_pct_2s`
    - `eax_shared/combat_context.lua` contains `party.urgent_ally`
    - `eax_shared/combat_context.lua` contains `target.cast_progress_pct`
    - `eax_shared/role_policy.lua` contains `build_actions`
    - `eax_shared/reactive_runtime.lua` contains `role_policy.build_actions`
    - `tests/role_policy_spec.lua` contains `tank policy` or `life_save_ally`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/combat_context_spec.lua && rtk lua tests/role_policy_spec.lua</automated>
  </verify>
  <done>The shared runtime can derive role-correct branch winners from one policy module fed by richer normalized snapshot data.</done>
</task>

<task type="auto">
  <name>Task 2: Lock runtime proofs for shared role-policy winners</name>
  <read_first>
    - eax_shared/reactive_runtime.lua
    - eax_shared/role_policy.lua
    - tests/reactive_runtime_spec.lua
    - tests/role_policy_spec.lua
  </read_first>
  <files>tests/reactive_runtime_spec.lua, tests/role_policy_spec.lua</files>
  <action>Extend `tests/reactive_runtime_spec.lua` so the shared runtime proves it still preserves adapter execution and telemetry while sourcing its default branch triggers from the new role-policy module. Add explicit runtime cases for: healer tank-first `life_save_ally`, tank `anti_aggro` recovery, DPS threat-drop / self-save gating, and one urgency-aware control winner. Do not weaken the Phase 06 handled / noop / skipped-unsafe assertions; add Phase 07 expectations on top of them. Keep tests fast, pure Lua, and grep-friendly.</action>
  <acceptance_criteria>
    - `tests/reactive_runtime_spec.lua` contains `anti_aggro`
    - `tests/reactive_runtime_spec.lua` contains `interrupt_control`
    - `tests/reactive_runtime_spec.lua` contains `life_save_ally`
    - `tests/reactive_runtime_spec.lua` still contains `noop_unsupported`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/combat_context_spec.lua && rtk lua tests/role_policy_spec.lua && rtk lua tests/reactive_runtime_spec.lua</automated>
  </verify>
  <done>The Phase 07 shared contract is proven before any healer, tank, or DPS family rollout begins.</done>
</task>

</tasks>

<verification>
Run the shared role-policy suite:
- `rtk lua tests/combat_context_spec.lua`
- `rtk lua tests/role_policy_spec.lua`
- `rtk lua tests/reactive_runtime_spec.lua`
</verification>

<success_criteria>
The repo now has one shared, test-backed definition of role-aware danger, triage, threat recovery, and control urgency, and every later Phase 07 plan can build on that contract instead of inventing its own thresholds.
</success_criteria>

<output>
After completion, create `.planning/phases/07-role-intelligence-tuning/07-01-SUMMARY.md`
</output>
