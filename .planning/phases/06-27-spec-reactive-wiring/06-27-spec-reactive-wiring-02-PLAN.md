---
phase: 06-27-spec-reactive-wiring
plan: 02
type: execute
wave: 2
depends_on:
  - 06-27-spec-reactive-wiring-01
files_modified:
  - EAX*/main.lua
  - tools/rotation_validation.lua
  - tests/reactive_runtime_wiring_spec.lua
  - tests/rotation_validation_spec.lua
autonomous: true
requirements: [WIRE-01, WIRE-02, WIRE-03]
user_setup: []
must_haves:
  truths:
    - "All 27 canonical specs declare the same shared reactive adapter contract"
    - "Every canonical spec either handles or explicitly no-ops each reactive category without silent gaps"
    - "Blocking validation prints an explicit 27-spec reactive parity pass/fail summary"
  artifacts:
    - path: "EAXWarriorArms/main.lua"
      provides: "Bulk-rollout melee DPS adapter pattern"
      contains: "noop = \"unsupported\""
    - path: "EAXDruidRestoration/main.lua"
      provides: "Bulk-rollout healer adapter pattern"
      contains: "life_save_ally"
    - path: "tools/rotation_validation.lua"
      provides: "Reactive parity report in the blocking validator"
      contains: "reactive parity"
    - path: "tests/reactive_runtime_wiring_spec.lua"
      provides: "27-spec parity assertions for adapter keys and update_tick wiring"
      contains: "life_save_self"
  key_links:
    - from: "EAX*/main.lua"
      to: "eax_shared/reactive_runtime.lua"
      via: "shared `reactive_adapter` tables passed to update_tick"
      pattern: "adapter = reactive_adapter"
    - from: "tests/reactive_runtime_wiring_spec.lua"
      to: "EAX*/main.lua"
      via: "hardcoded 27-spec grep/assert parity checks"
      pattern: "noop = \"unsupported\""
    - from: "tools/rotation_validation.lua"
      to: "tests/rotation_validation_spec.lua"
      via: "PASS:/FAIL: reactive parity summary"
      pattern: "reactive parity 27/27"
---

<objective>
Roll the shared adapter contract across all 27 canonical combat specs and turn parity validation into a blocking 27-spec report.

Purpose: Phase 06 only succeeds when every canonical spec uses the same adapter surface and validation can prove there are no missing branches or silent unsupported categories.
Output: Bulk `main.lua` adapter rollout plus reactive-parity checks inside `tools/rotation_validation.lua` and its tests.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md
@.planning/phases/06-27-spec-reactive-wiring/06-RESEARCH.md
@.planning/phases/06-27-spec-reactive-wiring/06-VALIDATION.md
@.planning/phases/05-reactive-contract-api-gate/05-05-SUMMARY.md
@eax_shared/reactive_runtime.lua
@tools/rotation_validation.lua
@tests/reactive_runtime_wiring_spec.lua
@tests/rotation_validation_spec.lua
@EAXWarriorArms/main.lua
@EAXDruidRestoration/main.lua
@EAXWarriorProtection/main.lua

<interfaces>
From Plan 01 shared contract:
```lua
reactive_runtime.update_tick(me, target, {
  encounter_manager = encounter_manager,
  state = _visual_runtime.reactive_state,
  spec = "EAXWarriorArms",
  adapter = reactive_adapter,
})

local reactive_adapter = {
  spec = "EAXWarriorArms",
  actions = {
    life_save_self = { handler = ... } or { noop = "unsupported" },
    life_save_ally = { handler = ... } or { noop = "unsupported" },
    interrupt_control = { handler = ... } or { noop = "unsupported" },
    anti_overheal = { handler = ... } or { noop = "unsupported" },
    anti_aggro = { handler = ... } or { noop = "unsupported" },
    throughput_resume = { noop = "unsupported" },
  },
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Roll the shared reactive adapter contract across all 27 canonical specs</name>
  <read_first>
    - .planning/phases/06-27-spec-reactive-wiring/06-CONTEXT.md
    - .planning/phases/06-27-spec-reactive-wiring/06-RESEARCH.md
    - eax_shared/reactive_runtime.lua
    - EAXWarriorArms/main.lua
    - EAXDruidRestoration/main.lua
    - EAXWarriorProtection/main.lua
  </read_first>
  <files>EAX*/main.lua</files>
  <action>Update every canonical `EAX*/main.lua` so the existing `reactive_runtime.update_tick(...)` call passes `adapter = reactive_adapter`. Add one `local reactive_adapter = { spec = "<SPEC>", actions = { ... } }` block per file using the exact six action keys from Plan 01. Apply these role-family rules consistently: DPS specs wire `life_save_self` to their existing defensive helper, wire `interrupt_control` when they already have an interrupt/stop/stun helper, wire `anti_aggro` only when the file already has an explicit threat-drop or peel helper, and mark all remaining gaps as `noop = "unsupported"`. Healer specs wire `life_save_self` / `life_save_ally` to existing heal or save helpers, wire `anti_overheal` to existing stop-cast logic when present, and use explicit no-ops for hostile-only categories they do not own. Tank specs wire `life_save_self` and `interrupt_control`, preserve any existing recovery-target logic, and keep urgent-only retarget behavior. Do not add movement automation, deeper role tuning, or new HUD strings; this phase is wiring and explicit parity only.</action>
  <acceptance_criteria>
    - Every canonical `EAX*/main.lua` contains `local reactive_adapter = {`
    - Every canonical `EAX*/main.lua` contains all six action keys: `life_save_self`, `life_save_ally`, `interrupt_control`, `anti_overheal`, `anti_aggro`, `throughput_resume`
    - Every canonical `EAX*/main.lua` contains `adapter = reactive_adapter`
    - Every canonical `EAX*/main.lua` contains at least one exact `noop = "unsupported"` marker unless all six actions have real handlers
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_wiring_spec.lua</automated>
  </verify>
  <done>All 27 canonical specs declare the same adapter contract and expose explicit handled/no-op coverage for every reactive category.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Tighten blocking validation into a 27-spec reactive parity report</name>
  <read_first>
    - tools/rotation_validation.lua
    - tests/reactive_runtime_wiring_spec.lua
    - tests/rotation_validation_spec.lua
    - EAXWarriorArms/main.lua
  </read_first>
  <files>tools/rotation_validation.lua, tests/reactive_runtime_wiring_spec.lua, tests/rotation_validation_spec.lua</files>
  <behavior>
    - Test 1: `tests/reactive_runtime_wiring_spec.lua` fails if any canonical `main.lua` is missing `reactive_adapter`, any required action key, or `adapter = reactive_adapter`.
    - Test 2: `tools/rotation_validation.lua` prints one deterministic parity line per canonical spec and a final summary `PASS: reactive parity 27/27` when all specs satisfy the adapter contract.
    - Test 3: `tests/rotation_validation_spec.lua` fails when a temporary spec fixture omits an adapter key or when the final parity summary is missing.
  </behavior>
  <action>Extend `tests/reactive_runtime_wiring_spec.lua` from import/update substring checks to full adapter parity assertions: each canonical file must contain `local reactive_adapter = {`, all six exact action keys, and `adapter = reactive_adapter`. Update `tools/rotation_validation.lua` so `validate_spec(...)` also checks for the adapter block, the six action keys, and explicit no-op markers where needed, then prints deterministic `PASS:` / `FAIL:` reactive parity lines per spec plus a final summary line `PASS: reactive parity 27/27` or `FAIL: reactive parity X/27`. Update `tests/rotation_validation_spec.lua` so it creates a temporary broken spec fixture missing one adapter key, asserts the validator returns exit code 1 with a reactive parity failure line, and still asserts a clean repo prints the exact summary string `PASS: reactive parity 27/27`.</action>
  <acceptance_criteria>
    - `tests/reactive_runtime_wiring_spec.lua` contains all six action-key substrings
    - `tools/rotation_validation.lua` contains `reactive parity`
    - `tests/rotation_validation_spec.lua` contains `PASS: reactive parity 27/27`
    - `tools/rotation_validation.lua` exits 0 on a clean repo
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_wiring_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk lua tools/rotation_validation.lua</automated>
  </verify>
  <done>The blocking validation command now produces an explicit 27-spec reactive parity report and fails whenever adapter coverage or explicit no-op parity is incomplete.</done>
</task>

</tasks>

<verification>
Run the full Phase 06 parity suite:
- `rtk lua tests/reactive_engine_spec.lua`
- `rtk lua tests/reactive_runtime_spec.lua`
- `rtk lua tests/reactive_runtime_wiring_spec.lua`
- `rtk lua tests/rotation_validation_spec.lua`
- `rtk lua tools/rotation_validation.lua`
</verification>

<success_criteria>
Every canonical combat spec now uses the same shared reactive adapter contract, and the repo's blocking validation command proves 27/27 parity with explicit handled vs no-op coverage.
</success_criteria>

<output>
After completion, create `.planning/phases/06-27-spec-reactive-wiring/06-02-SUMMARY.md`
</output>
