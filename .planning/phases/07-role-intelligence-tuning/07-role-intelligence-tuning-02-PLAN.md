---
phase: 07-role-intelligence-tuning
plan: 02
type: execute
wave: 2
depends_on:
  - 07-role-intelligence-tuning-01
files_modified:
  - eax_shared/healer_triage.lua
  - tests/healer_role_behavior_spec.lua
  - EAXDruidRestoration/main.lua
  - EAXPaladinHoly/main.lua
  - EAXPriestDiscipline/main.lua
  - EAXPriestHoly/main.lua
  - EAXShamanRestoration/main.lua
autonomous: true
requirements: [ROLE-02]
user_setup: []
must_haves:
  truths:
    - "Healer specs save the tank first unless the tank is already stably covered by incoming heals"
    - "Once the tank is stable, healer specs choose the next most urgent ally instead of aimless topping"
    - "Healer anti-overheal logic stops wasteful casts without blocking obvious stabilizing actions"
  artifacts:
    - path: "eax_shared/healer_triage.lua"
      provides: "Shared deterministic target-scoring and anti-overheal rules for healer specs"
      contains: "select_target"
    - path: "EAXPriestHoly/main.lua"
      provides: "Representative direct-heal reactive triage integration"
      contains: "healer_triage"
    - path: "EAXDruidRestoration/main.lua"
      provides: "Representative HoT-heavy tank-first triage integration"
      contains: "healer_triage"
    - path: "tests/healer_role_behavior_spec.lua"
      provides: "Deterministic healer target-selection and stop-cast coverage"
      contains: "tank_save"
  key_links:
    - from: "EAXPriestHoly/main.lua"
      to: "eax_shared/healer_triage.lua"
      via: "life_save_ally and anti_overheal call shared triage helpers"
      pattern: "healer_triage"
    - from: "EAXDruidRestoration/main.lua"
      to: "eax_shared/healer_triage.lua"
      via: "tank-first target resolution feeds existing resto heal helpers"
      pattern: "select_target"
    - from: "tests/healer_role_behavior_spec.lua"
      to: "eax_shared/healer_triage.lua"
      via: "shared helper cases prove target ordering and covered-target holds"
      pattern: "covered_hold"
---

<objective>
Roll one shared healer triage policy into every healer spec so reactive save decisions become tank-first, incoming-heal-aware, and calmly deterministic instead of five slightly different local heuristics.

Purpose: ROLE-02 is fundamentally a family problem. A single healer helper keeps Holy, Discipline, Resto, and Holy Paladin/Shaman aligned on who needs the next real save.
Output: Shared healer triage helper plus integrations in all five healer specs.
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
@.planning/phases/06-27-spec-reactive-wiring/06-01-SUMMARY.md
@eax_shared/role_policy.lua
@EAXDruidRestoration/main.lua
@EAXPaladinHoly/main.lua
@EAXPriestDiscipline/main.lua
@EAXPriestHoly/main.lua
@EAXShamanRestoration/main.lua

<interfaces>
From Plan 01 shared policy contract:
```lua
local actions = role_policy.build_actions(...)
-- healer life_save_ally winners already encode "tank first until stable, then next uncovered urgent ally"
```

Shared helper to create in this plan:
```lua
local healer_triage = {}
function healer_triage.select_target(me, units, opts) end
function healer_triage.should_cancel_overheal(target_snapshot, opts) end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create a shared healer triage helper with deterministic target ordering</name>
  <read_first>
    - eax_shared/role_policy.lua
    - EAXDruidRestoration/main.lua
    - EAXPriestHoly/main.lua
    - tests/reactive_runtime_spec.lua
  </read_first>
  <files>eax_shared/healer_triage.lua, tests/healer_role_behavior_spec.lua</files>
  <behavior>
    - Test 1: `select_target(...)` returns `tank_save` when the tank is unstable and not already sufficiently covered by incoming heals.
    - Test 2: `select_target(...)` returns `triage_save` for the lowest uncovered ally once the tank is stable enough.
    - Test 3: `should_cancel_overheal(...)` returns true for healthy / already-covered targets and false for still-dangerous targets.
    - Test 4: group-collapse inputs produce `group_stabilize` instead of single-target greed.
  </behavior>
  <action>Create `eax_shared/healer_triage.lua` with these exact exports: `select_target(me, units, opts)`, `should_cancel_overheal(target_snapshot, opts)`, and `should_spend_emergency(summary, opts)`. Encode the locked Phase 07 rules with concrete thresholds that downstream healer files share: tank-first if tank `hp_pct <= 0.55` and `incoming_heal_pct < 0.25`; otherwise pick the lowest uncovered ally under `0.35`; mark `group_stabilize` when 3 or more allies are below `0.55`; allow anti-overheal cancel only when target `hp_pct >= 0.85` and `incoming_heal_pct >= 0.50` and collapse risk is false. Keep the helper deterministic: same inputs must return the same target, reason, and emergency flag every time.</action>
  <acceptance_criteria>
    - `eax_shared/healer_triage.lua` contains `select_target`
    - `eax_shared/healer_triage.lua` contains `should_cancel_overheal`
    - `eax_shared/healer_triage.lua` contains `group_stabilize`
    - `tests/healer_role_behavior_spec.lua` contains `tank_save`
    - `tests/healer_role_behavior_spec.lua` contains `covered_hold`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/healer_role_behavior_spec.lua</automated>
  </verify>
  <done>Healer triage and anti-overheal rules are centralized in one shared helper with deterministic, test-backed outputs.</done>
</task>

<task type="auto">
  <name>Task 2: Integrate the shared triage helper into all healer reactive adapters</name>
  <read_first>
    - eax_shared/healer_triage.lua
    - EAXDruidRestoration/main.lua
    - EAXPaladinHoly/main.lua
    - EAXPriestDiscipline/main.lua
    - EAXPriestHoly/main.lua
    - EAXShamanRestoration/main.lua
  </read_first>
  <files>EAXDruidRestoration/main.lua, EAXPaladinHoly/main.lua, EAXPriestDiscipline/main.lua, EAXPriestHoly/main.lua, EAXShamanRestoration/main.lua</files>
  <action>Require `eax_shared/healer_triage` in all five healer `main.lua` files and route reactive adapter behavior through it. Use the helper inside `life_save_ally` and `anti_overheal` with these concrete integrations: `EAXDruidRestoration/main.lua` keeps `pick_tank_unit(...)` / `pick_priority_heal_target(...)` as spell-lane helpers but defers final urgent target choice to `healer_triage.select_target(...)`; `EAXPriestHoly/main.lua` and `EAXPriestDiscipline/main.lua` use the helper to choose between self, tank, and next uncovered ally before calling their existing `try_cast_spell(...)`, `try_pw_shield(...)`, `try_penance(...)`, or big-heal helpers; `EAXPaladinHoly/main.lua` uses the helper before `try_cast_heal(...)` or Holy Shock-style emergency paths; `EAXShamanRestoration/main.lua` uses the helper before `try_natures_swiftness(...)`, `try_chain_heal(...)`, `try_healing_wave(...)`, and `try_lesser_healing_wave(...)`. Preserve the locked behavior: tank survival first, no pointless topping, emergency cooldowns can fire early when collapse is obvious, and anti-overheal must never cancel a still-stabilizing save.</action>
  <acceptance_criteria>
    - `EAXDruidRestoration/main.lua` contains `healer_triage`
    - `EAXPriestHoly/main.lua` contains `healer_triage`
    - `EAXPriestDiscipline/main.lua` contains `healer_triage`
    - `EAXPaladinHoly/main.lua` contains `healer_triage`
    - `EAXShamanRestoration/main.lua` contains `healer_triage`
    - All five healer files keep non-noop `life_save_ally = {`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/healer_role_behavior_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua</automated>
  </verify>
  <done>All healer specs now share the same tank-first, incoming-heal-aware save logic and stop-cast behavior.</done>
</task>

</tasks>

<verification>
Run healer-family checks:
- `rtk lua tests/healer_role_behavior_spec.lua`
- `rtk lua tests/reactive_runtime_wiring_spec.lua`
</verification>

<success_criteria>
Every healer spec chooses urgent save targets from one shared triage policy, respects incoming-heal coverage, and avoids wasteful topping without missing obvious saves.
</success_criteria>

<output>
After completion, create `.planning/phases/07-role-intelligence-tuning/07-02-SUMMARY.md`
</output>
