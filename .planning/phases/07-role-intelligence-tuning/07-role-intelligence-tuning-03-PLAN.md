---
phase: 07-role-intelligence-tuning
plan: 03
type: execute
wave: 2
depends_on:
  - 07-role-intelligence-tuning-01
files_modified:
  - eax_shared/tank_recovery.lua
  - tests/tank_role_behavior_spec.lua
  - EAXDruidFeral/main.lua
  - EAXPaladinProtection/main.lua
  - EAXWarriorProtection/main.lua
autonomous: true
requirements: [ROLE-03, ROLE-04]
user_setup: []
must_haves:
  truths:
    - "Tank specs actively recover aggro from allies instead of treating threat instability as a no-op"
    - "Tank defensives fire proactively as pressure rises, but true self-death still outranks peel greed"
    - "Tank interrupt and control decisions favor the most dangerous caster or peel target, not static target order"
  artifacts:
    - path: "eax_shared/tank_recovery.lua"
      provides: "Shared target-scoring and decision helpers for peel, taunt, and proactive defensive posture"
      contains: "select_recovery_target"
    - path: "EAXWarriorProtection/main.lua"
      provides: "Protection warrior anti-aggro recovery routed through shared tank scoring"
      contains: "tank_recovery"
    - path: "EAXDruidFeral/main.lua"
      provides: "Feral tank/peel posture routed through shared tank scoring"
      contains: "tank_recovery"
    - path: "tests/tank_role_behavior_spec.lua"
      provides: "Deterministic tank recovery vs defensive-priority coverage"
      contains: "threat_instability"
  key_links:
    - from: "EAXWarriorProtection/main.lua"
      to: "eax_shared/tank_recovery.lua"
      via: "anti_aggro and interrupt_control consume shared recovery scoring"
      pattern: "tank_recovery"
    - from: "EAXDruidFeral/main.lua"
      to: "eax_shared/tank_recovery.lua"
      via: "Growl / peel logic uses shared recovery target selection"
      pattern: "select_recovery_target"
    - from: "tests/tank_role_behavior_spec.lua"
      to: "eax_shared/tank_recovery.lua"
      via: "shared helper cases prove peel-vs-defensive ordering"
      pattern: "self_death_imminent"
---

<objective>
Turn tank reactive behavior into active encounter control: shared threat-instability scoring, proactive defensives, and urgency-aware control wired into Warrior Protection, Paladin Protection, and Feral Druid.

Purpose: ROLE-03 fails if tank specs keep treating aggro recovery as unsupported. Tanks need a shared policy for when to peel, when to self-save, and when to do both in controlled order.
Output: Shared tank recovery helper plus integrations in the three tank-capable specs.
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
@EAXDruidFeral/main.lua
@EAXPaladinProtection/main.lua
@EAXWarriorProtection/main.lua

<interfaces>
Shared helper to create in this plan:
```lua
local tank_recovery = {}
function tank_recovery.select_recovery_target(me, opts) end
function tank_recovery.should_prioritize_defensive(snapshot, opts) end
```

Existing tank adapter surface:
```lua
reactive_adapter = {
  actions = {
    life_save_self = { handler = ... },
    interrupt_control = { handler = ... },
    anti_aggro = { noop = "unsupported" },
  }
}
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create a shared tank recovery helper for peel-vs-defensive posture</name>
  <read_first>
    - eax_shared/role_policy.lua
    - EAXWarriorProtection/main.lua
    - EAXDruidFeral/main.lua
  </read_first>
  <files>eax_shared/tank_recovery.lua, tests/tank_role_behavior_spec.lua</files>
  <behavior>
    - Test 1: `select_recovery_target(...)` returns the highest-danger hostile threatening a healer or damager before a lower-risk target.
    - Test 2: `should_prioritize_defensive(...)` returns true only when self death is imminent or pressure is beyond the shared recovery window.
    - Test 3: stable aggro windows do not trigger recovery spam.
  </behavior>
  <action>Create `eax_shared/tank_recovery.lua` with these exact exports: `select_recovery_target(me, opts)`, `should_prioritize_defensive(snapshot, opts)`, and `describe_window(snapshot, opts)`. Encode the locked policy in concrete terms: prefer aggro recovery over personal defensive use when a hostile is on a healer or damager and self death is not imminent; mark self death imminent when `hp_pct <= 0.20` or when normalized incoming damage remains above the safe defensive window; prefer dangerous casters and healer-victim hostiles when choosing a peel target; return no recovery target in stable windows so tanks do not spam taunts or control.</action>
  <acceptance_criteria>
    - `eax_shared/tank_recovery.lua` contains `select_recovery_target`
    - `eax_shared/tank_recovery.lua` contains `should_prioritize_defensive`
    - `eax_shared/tank_recovery.lua` contains `self_death_imminent`
    - `tests/tank_role_behavior_spec.lua` contains `threat_instability`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/tank_role_behavior_spec.lua</automated>
  </verify>
  <done>Tank peel and defensive posture rules are centralized and proven before any spec integration starts.</done>
</task>

<task type="auto">
  <name>Task 2: Wire tank recovery and urgency-aware control into all tank specs</name>
  <read_first>
    - eax_shared/tank_recovery.lua
    - EAXDruidFeral/main.lua
    - EAXPaladinProtection/main.lua
    - EAXWarriorProtection/main.lua
  </read_first>
  <files>EAXDruidFeral/main.lua, EAXPaladinProtection/main.lua, EAXWarriorProtection/main.lua</files>
  <action>Require `eax_shared/tank_recovery` in all three tank-capable `main.lua` files and replace tank `anti_aggro = { noop = "unsupported" }` with real recovery handlers. Use the shared helper to decide whether the branch should peel or self-save first, then route to each spec's legal tools: `EAXWarriorProtection/main.lua` uses its existing taunt / mocking blow / concussion blow / challenging shout / shield bash / recovery-target surface; `EAXDruidFeral/main.lua` uses `try_growl(...)`, `try_taunt_off_party(...)`, `try_challenging_roar(...)`, `try_bash(...)`, and its existing proactive defensive helpers; `EAXPaladinProtection/main.lua` uses its protection defensive lane plus legal control / snap tools already present in the file. Preserve calm posture: tanks should help the party only when the pull remains recoverable, retarget only for urgent peel/control windows, and keep `life_save_self` available when shared recovery marks self death imminent.</action>
  <acceptance_criteria>
    - `EAXWarriorProtection/main.lua` contains `tank_recovery`
    - `EAXWarriorProtection/main.lua` no longer contains `anti_aggro = { noop = "unsupported" }`
    - `EAXDruidFeral/main.lua` contains `tank_recovery`
    - `EAXPaladinProtection/main.lua` contains `tank_recovery`
    - All three tank files keep non-noop `interrupt_control = {`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/tank_role_behavior_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua</automated>
  </verify>
  <done>All tank specs now recover aggro, time defensives proactively, and use urgency-aware control through one shared posture helper.</done>
</task>

</tasks>

<verification>
Run tank-family checks:
- `rtk lua tests/tank_role_behavior_spec.lua`
- `rtk lua tests/reactive_runtime_wiring_spec.lua`
</verification>

<success_criteria>
Protection Warrior, Protection Paladin, and Feral Druid all behave like active tanks: they peel dangerous mobs, keep threat under control, and still self-save immediately when collapse risk becomes real.
</success_criteria>

<output>
After completion, create `.planning/phases/07-role-intelligence-tuning/07-03-SUMMARY.md`
</output>
