---
phase: 05-reactive-contract-api-gate
plan: 04
type: execute
wave: 1
depends_on: []
files_modified:
  - tools/api_hard_gate.lua
  - tests/api_hard_gate_spec.lua
  - tests/rotation_validation_spec.lua
autonomous: true
requirements: [APIG-01, APIG-02]
user_setup: []
gap_closure: true
must_haves:
  truths:
    - "Validation fails on runtime calls that are not present in the generated @.api allowlist"
    - "Allowlist enforcement checks both rooted calls like core.input.use_item and colon methods like me:get_health"
    - "Unified validation still reports deterministic file:line -> call failures for API-gate violations"
  artifacts:
    - path: "tools/api_hard_gate.lua"
      provides: "Allowlist-backed runtime API scanner"
      contains: "scan_paths"
    - path: "tests/api_hard_gate_spec.lua"
      provides: "Regression coverage for banned patterns plus disallowed roots/methods"
      contains: "core.not_real_api"
    - path: "tests/rotation_validation_spec.lua"
      provides: "Unified validation proof that API-gate failures stay blocking"
      contains: "FAIL: api hard gate ::"
  key_links:
    - from: "tools/api_hard_gate.lua"
      to: "tools/api_allowlist.lua"
      via: "allowlist.roots and allowlist.methods lookups"
      pattern: "allowlist\.roots|allowlist\.methods"
    - from: "tools/rotation_validation.lua"
      to: "tools/api_hard_gate.lua"
      via: "blocking validation summary"
      pattern: "FAIL: api hard gate ::"
---

<objective>
Close the fail-closed API-gate gap by enforcing the generated allowlist against real runtime call shapes instead of only scanning for four banned string patterns.

Purpose: Phase 05 cannot claim strict `@.api` compliance until runtime files fail on disallowed rooted calls and disallowed object methods, not just obviously dangerous libraries.
Output: An allowlist-backed `api_hard_gate`, stronger regression specs, and proof that unified validation still blocks on gate failures.
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
@.planning/phases/05-reactive-contract-api-gate/05-02-SUMMARY.md
@tools/api_surface_extract.lua
@tools/api_allowlist.lua
@tools/api_hard_gate.lua
@tools/rotation_validation.lua
@.api/core.lua
@.api/game_object.lua
@.api/menu.lua

<interfaces>
From `tools/api_allowlist.lua`:
```lua
local allowlist = {
  roots = { ["core.log"] = true, ["core.input.use_item"] = true },
  methods = { ["get_health"] = true, ["get_state"] = true },
}
```

From `tools/api_hard_gate.lua`:
```lua
function M.scan_paths(paths)
  -- returns ok:boolean, violations:{ path, line, call }[]
end
```

From `tools/rotation_validation.lua`:
```lua
function M.main()
  -- prints PASS:/FAIL: lines and returns non-zero on validation failure
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Enforce the generated allowlist against rooted calls and colon methods</name>
  <read_first>
    - .planning/phases/05-reactive-contract-api-gate/05-VERIFICATION.md
    - .planning/phases/05-reactive-contract-api-gate/05-02-SUMMARY.md
    - tools/api_surface_extract.lua
    - tools/api_allowlist.lua
    - tools/api_hard_gate.lua
    - tests/api_hard_gate_spec.lua
  </read_first>
  <files>tools/api_hard_gate.lua, tests/api_hard_gate_spec.lua</files>
  <behavior>
    - Test 1: rooted calls like `core.log(...)` pass only when present in `allowlist.roots`; rooted calls like `core.not_real_api(...)` fail.
    - Test 2: colon methods like `me:get_health()` pass only when present in `allowlist.methods`; methods like `me:get_secret_value()` fail.
    - Test 3: banned patterns (`ffi.`, `io.popen`, `os.execute`, `debug.`) still fail with the same `FAIL: path:line -> call` format.
  </behavior>
  <action>Update `tools/api_hard_gate.lua` so `scan_file(...)` keeps the current comment/string stripping and banned-pattern checks, then also extracts runtime call tokens from stripped lines. Add rooted-call extraction using the exact Lua pattern `([%a_][%w_]*%.[%a_][%w_%.]*)%s*%(` and colon-method extraction using `:%s*([%a_][%w_]*)%s*%(`. Exclude function definitions (`function name(`, `local function name(`) and table function literals (`name = function(`) from violation reporting. Treat a rooted call as allowed only when the full token exists in `allowlist.roots`; treat a colon call as allowed only when the method name exists in `allowlist.methods`. Keep local helper calls like `try_execute(...)` out of scope; only enforce rooted globals/tables and colon methods. Report disallowed rooted calls with the full token (example: `core.not_real_api`) and disallowed methods with the method name prefixed as `:get_secret_value` so the output remains `FAIL: <path>:<line> -> <call>`.</action>
  <acceptance_criteria>
    - `tools/api_hard_gate.lua` contains `allowlist.roots`
    - `tools/api_hard_gate.lua` contains `allowlist.methods`
    - `tests/api_hard_gate_spec.lua` contains `core.not_real_api`
    - `tests/api_hard_gate_spec.lua` exits 0
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/api_hard_gate_spec.lua && rtk rg -n "allowlist\.roots|allowlist\.methods|core\.not_real_api|:get_secret_value|ffi\.|io\.popen|os\.execute|debug\." tools/api_hard_gate.lua tests/api_hard_gate_spec.lua</automated>
  </verify>
  <done>The hard gate fails closed on disallowed rooted calls and colon methods by consulting the generated allowlist instead of relying on banned-string scans alone.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Prove unified validation still blocks on allowlist violations</name>
  <read_first>
    - tools/rotation_validation.lua
    - tools/api_hard_gate.lua
    - tests/rotation_validation_spec.lua
    - tests/api_hard_gate_spec.lua
  </read_first>
  <files>tests/api_hard_gate_spec.lua, tests/rotation_validation_spec.lua</files>
  <behavior>
    - Test 1: the API hard-gate spec creates a runtime fixture containing one banned call, one disallowed rooted call, and one disallowed method, then asserts all three violations are reported.
    - Test 2: the rotation-validation spec proves `script.main()` returns non-zero when a temporary runtime fixture is syntactically valid but contains an allowlist violation.
    - Test 3: the clean-repo validation path still returns `0` after the temporary fixture is removed.
  </behavior>
  <action>Extend `tests/api_hard_gate_spec.lua` so the temporary `EAXApiGateSpec/main.lua` fixture includes `core.not_real_api()`, `me:get_secret_value()`, `ffi.C.printf('boom')`, and `os.execute('dir')`, then assert the joined output contains `FAIL: EAXApiGateSpec/main.lua:... -> core.not_real_api`, `FAIL: EAXApiGateSpec/main.lua:... -> :get_secret_value`, `FAIL: EAXApiGateSpec/main.lua:... -> ffi.C`, and `FAIL: EAXApiGateSpec/main.lua:... -> os.execute`. Extend `tests/rotation_validation_spec.lua` with a second captured-print scenario that writes a temporary `EAXApiGateSpec/main.lua` containing the required import strings (`visual_state`, `vendor_automation`, `consumables_manager`, `mount_manager`) plus one disallowed rooted call `core.not_real_api()`, runs `script.main()`, asserts the return code is `1`, and asserts the printed output contains `FAIL: api hard gate ::`. Remove the temporary fixture before the existing clean-repo success assertion completes.</action>
  <acceptance_criteria>
    - `tests/api_hard_gate_spec.lua` contains `core.not_real_api`
    - `tests/api_hard_gate_spec.lua` contains `:get_secret_value`
    - `tests/rotation_validation_spec.lua` contains `FAIL: api hard gate ::`
    - `tests/rotation_validation_spec.lua` exits 0
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/api_hard_gate_spec.lua && rtk lua tests/rotation_validation_spec.lua && rtk rg -n "core\.not_real_api|:get_secret_value|FAIL: api hard gate ::" tests/api_hard_gate_spec.lua tests/rotation_validation_spec.lua</automated>
  </verify>
  <done>The standard validation entrypoint is proven to remain blocking when allowlist-backed API violations are present in runtime behavior files.</done>
</task>

</tasks>

<verification>
Run the API allowlist enforcement checks:
- `rtk lua tests/api_hard_gate_spec.lua`
- `rtk lua tests/rotation_validation_spec.lua`
- `rtk lua tools/api_hard_gate.lua`
- `rtk lua tools/rotation_validation.lua`
</verification>

<success_criteria>
The repo fails on rooted and colon-form runtime API calls that are not present in `tools/api_allowlist.lua`, and unified validation still treats those failures as blocker severity.
</success_criteria>

<output>
After completion, create `.planning/phases/05-reactive-contract-api-gate/05-04-SUMMARY.md`
</output>
