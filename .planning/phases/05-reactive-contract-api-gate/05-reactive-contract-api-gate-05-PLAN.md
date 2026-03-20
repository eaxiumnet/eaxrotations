---
phase: 05-reactive-contract-api-gate
plan: 05
type: execute
wave: 2
depends_on:
  - 05-reactive-contract-api-gate-03
files_modified:
  - EAX*/main.lua
  - tests/reactive_runtime_wiring_spec.lua
autonomous: true
requirements: [REACT-01, REACT-02, REACT-03]
user_setup: []
gap_closure: true
must_haves:
  truths:
    - "Every canonical spec evaluates the shared combat snapshot and reactive engine once per tick in runtime code"
    - "Reactive telemetry wiring reuses the existing visual snapshot lane instead of changing cast lanes before Phase 06"
    - "Cross-spec parity checks prove all 27 canonical specs import and call the same reactive runtime bridge"
  artifacts:
    - path: "EAXWarriorArms/main.lua"
      provides: "Representative spec runtime wiring for the shared reactive bridge"
      contains: "reactive_runtime.update_tick"
    - path: "EAXDruidRestoration/main.lua"
      provides: "Representative healer spec runtime wiring for the shared reactive bridge"
      contains: "reactive_runtime.update_tick"
    - path: "tests/reactive_runtime_wiring_spec.lua"
      provides: "Parity coverage across all 27 canonical spec main.lua files"
      contains: "EAXWarriorProtection"
  key_links:
    - from: "EAX*/main.lua"
      to: "eax_shared/reactive_runtime.lua"
      via: "visual_update_snapshot(me, target)"
      pattern: "reactive_runtime\.update_tick"
    - from: "tests/reactive_runtime_wiring_spec.lua"
      to: "EAX*/main.lua"
      via: "27-spec parity assertions"
      pattern: "require\(\"eax_shared/reactive_runtime\"\)"
---

<objective>
Close the remaining Phase 05 runtime-consumer gap by wiring the shared reactive bridge into every canonical spec's existing per-tick visual telemetry lane.

Purpose: Verification showed the reactive contract existed only in isolated modules; this plan makes all 27 runtime loops consume it without prematurely changing spell-priority/cast-lane behavior that belongs to Phase 06.
Output: Reactive bridge imports and per-tick calls in all 27 canonical `main.lua` files plus one parity regression spec.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/05-reactive-contract-api-gate/05-CONTEXT.md
@.planning/phases/05-reactive-contract-api-gate/05-VERIFICATION.md
@.planning/phases/05-reactive-contract-api-gate/05-01-SUMMARY.md
@.planning/phases/04-polish-competitive-features/04-02-SUMMARY.md
@eax_shared/reactive_runtime.lua
@EAXWarriorArms/main.lua
@EAXDruidRestoration/main.lua
@EAXWarriorProtection/main.lua

<interfaces>
From `eax_shared/reactive_runtime.lua`:
```lua
function reactive_runtime.update_tick(me, target, deps)
  -- writes reactive telemetry to dps_meter and returns ctx/result tables
end
```

From representative spec `main.lua` files:
```lua
local _visual_runtime = {
  in_combat = false,
  last_me_hp_pct = nil,
  last_target_hp_pct = nil,
}

local function visual_update_snapshot(me, target)
  -- existing per-tick telemetry lane
end
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Wire the shared reactive bridge into every canonical spec main loop</name>
  <read_first>
    - .planning/phases/05-reactive-contract-api-gate/05-VERIFICATION.md
    - .planning/phases/05-reactive-contract-api-gate/05-01-SUMMARY.md
    - .planning/phases/04-polish-competitive-features/04-02-SUMMARY.md
    - eax_shared/reactive_runtime.lua
    - EAXWarriorArms/main.lua
    - EAXDruidRestoration/main.lua
    - EAXWarriorProtection/main.lua
  </read_first>
  <files>EAX*/main.lua</files>
  <action>In every canonical combat spec `main.lua`, add `local reactive_runtime = require("eax_shared/reactive_runtime")` next to the existing shared visual telemetry imports. Extend each `_visual_runtime` table with `reactive_state = {}` so the bridge can preserve `hold_until_s`, `reason_code`, and `action_id` between ticks. Inside `local function visual_update_snapshot(me, target)`, insert one call before `visual_state.build_snapshot(...)`: `reactive_runtime.update_tick(me, target, { encounter_manager = encounter_manager, state = _visual_runtime.reactive_state, spec = "<SPEC_FOLDER_NAME>" })`. Use the actual folder name string for each file (for example `EAXWarriorArms`, `EAXDruidRestoration`, `EAXMageArcane`). Do not route the returned action into any cast helper, interrupt lane, or core rotation branch yet; this plan is telemetry/runtime wiring only so existing next-action behavior stays unchanged until Phase 06.</action>
  <acceptance_criteria>
    - Every canonical `EAX*/main.lua` contains `require("eax_shared/reactive_runtime")`
    - Every canonical `EAX*/main.lua` contains `reactive_state = {}` inside `_visual_runtime`
    - Every canonical `EAX*/main.lua` contains `reactive_runtime.update_tick(me, target, {`
    - No canonical `EAX*/main.lua` contains new `reason_code` HUD-rendering strings or debug-UI rows
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_wiring_spec.lua && rtk rg -n "require\(\"eax_shared/reactive_runtime\"\)|reactive_state = \{\}|reactive_runtime\.update_tick\(me, target, \{" EAX*/main.lua</automated>
  </verify>
  <done>All 27 canonical spec runtime loops consume the Phase 05 reactive snapshot and evaluation bridge once per tick without altering spell-cast behavior.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add a 27-spec parity regression for reactive runtime wiring</name>
  <read_first>
    - tools/rotation_validation.lua
    - EAXWarriorArms/main.lua
    - EAXDruidRestoration/main.lua
    - EAXWarriorProtection/main.lua
  </read_first>
  <files>tests/reactive_runtime_wiring_spec.lua</files>
  <behavior>
    - Test 1: the spec enumerates the same 27 canonical folders used by `tools/rotation_validation.lua`.
    - Test 2: every listed `main.lua` contains the reactive bridge require, the `reactive_state` hold table, and the `reactive_runtime.update_tick(...)` call.
    - Test 3: the spec fails if any canonical file adds Phase 05 debug-UI rendering strings such as `reason_code` or `reactive_action` to HUD output.
  </behavior>
  <action>Create `tests/reactive_runtime_wiring_spec.lua` that hardcodes the 27 canonical spec folders from `tools/rotation_validation.lua`, reads each `main.lua`, and asserts all of these exact substrings are present: `require("eax_shared/reactive_runtime")`, `reactive_state = {}`, and `reactive_runtime.update_tick(me, target, {`. Also assert those files do not add `reason_code` or `reactive_action` to renderer-facing HUD snapshot calls so the deferred in-client debug UI remains out of scope for Phase 05.</action>
  <acceptance_criteria>
    - `tests/reactive_runtime_wiring_spec.lua` contains `EAXWarriorProtection`
    - `tests/reactive_runtime_wiring_spec.lua` contains `require("eax_shared/reactive_runtime")`
    - `tests/reactive_runtime_wiring_spec.lua` exits 0
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/reactive_runtime_wiring_spec.lua && rtk rg -n "EAXWarriorProtection|require\(\"eax_shared/reactive_runtime\"\)|reactive_runtime\.update_tick" tests/reactive_runtime_wiring_spec.lua</automated>
  </verify>
  <done>One automated parity spec proves the reactive runtime bridge is wired uniformly across all 27 canonical spec main loops and Phase 05 still avoids in-client debug UI scope creep.</done>
</task>

</tasks>

<verification>
Run the cross-spec runtime wiring checks:
- `rtk lua tests/reactive_runtime_spec.lua`
- `rtk lua tests/dps_benchmark_spec.lua`
- `rtk lua tests/reactive_runtime_wiring_spec.lua`
</verification>

<success_criteria>
Every canonical spec imports and calls the shared reactive runtime bridge in the existing visual telemetry lane, so Phase 05 no longer ships combat/reactive modules that are orphaned from runtime code.
</success_criteria>

<output>
After completion, create `.planning/phases/05-reactive-contract-api-gate/05-05-SUMMARY.md`
</output>
