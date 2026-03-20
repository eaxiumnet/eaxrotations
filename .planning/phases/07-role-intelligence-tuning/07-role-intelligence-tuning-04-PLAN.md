---
phase: 07-role-intelligence-tuning
plan: 04
type: execute
wave: 2
depends_on:
  - 07-role-intelligence-tuning-01
files_modified:
  - eax_shared/dps_risk.lua
  - tests/dps_role_behavior_spec.lua
  - EAXDruidBalance/main.lua
  - EAXHunterBeastMastery/main.lua
  - EAXHunterMarksmanship/main.lua
  - EAXHunterSurvival/main.lua
  - EAXMageArcane/main.lua
  - EAXMageFire/main.lua
  - EAXMageFrost/main.lua
  - EAXPaladinRetribution/main.lua
  - EAXPriestShadow/main.lua
  - EAXRogueAssassination/main.lua
  - EAXRogueCombat/main.lua
  - EAXRogueSubtlety/main.lua
  - EAXShamanElemental/main.lua
  - EAXShamanEnhancement/main.lua
  - EAXWarlockAffliction/main.lua
  - EAXWarlockDemonology/main.lua
  - EAXWarlockDestruction/main.lua
  - EAXWarriorArms/main.lua
  - EAXWarriorFury/main.lua
autonomous: true
requirements: [ROLE-01, ROLE-04]
user_setup: []
must_haves:
  truths:
    - "DPS specs stay throughput-first when safe, but visibly hold burst and self-protect during real danger or threat windows"
    - "Caster DPS specs stop greedily finishing casts when rising danger clearly makes the commit wasteful or lethal"
    - "Interrupt and control reactions stay aggressive for wipe-risk casts even in a throughput-first DPS posture"
  artifacts:
    - path: "eax_shared/dps_risk.lua"
      provides: "Shared danger / threat / commit gates for DPS specs"
      contains: "should_hold_offense"
    - path: "EAXMageFire/main.lua"
      provides: "Representative caster DPS burst-hold and stop-cast integration"
      contains: "dps_risk"
    - path: "EAXWarriorFury/main.lua"
      provides: "Representative melee DPS burst-hold integration"
      contains: "dps_risk"
    - path: "tests/dps_role_behavior_spec.lua"
      provides: "Deterministic proof of danger-window burst holds and cast aborts"
      contains: "should_abort_commit"
  key_links:
    - from: "EAXMageFire/main.lua"
      to: "eax_shared/dps_risk.lua"
      via: "burst helpers and cast-abort checks call shared risk helpers"
      pattern: "dps_risk"
    - from: "EAXWarriorFury/main.lua"
      to: "eax_shared/dps_risk.lua"
      via: "burst helpers and anti_aggro use shared danger/threat gates"
      pattern: "should_hold_offense"
    - from: "tests/dps_role_behavior_spec.lua"
      to: "eax_shared/dps_risk.lua"
      via: "shared helper cases prove when DPS should hold, drop threat, or abort casts"
      pattern: "should_drop_threat"
---

<objective>
Apply one shared DPS danger/threat policy across every non-healer DPS spec so throughput remains aggressive when safe but disciplined under real danger, threat spikes, and urgent control windows.

Purpose: ROLE-01 needs a broad family rollout, not just one showcase spec. A shared helper keeps cooldown holds, threat drops, and early cast aborts consistent across the DPS roster.
Output: Shared DPS risk helper plus integrations in every non-healer DPS spec.
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
@eax_shared/role_policy.lua
@EAXMageFire/main.lua
@EAXWarriorFury/main.lua
@EAXWarlockAffliction/main.lua
@EAXRogueCombat/main.lua
@EAXHunterMarksmanship/main.lua

<interfaces>
Shared helper to create in this plan:
```lua
local dps_risk = {}
function dps_risk.should_hold_offense(snapshot, opts) end
function dps_risk.should_drop_threat(snapshot, opts) end
function dps_risk.should_abort_commit(snapshot, cast_state, opts) end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create a shared DPS risk helper for burst holds, threat drops, and cast aborts</name>
  <read_first>
    - eax_shared/role_policy.lua
    - EAXMageFire/main.lua
    - EAXWarriorFury/main.lua
  </read_first>
  <files>eax_shared/dps_risk.lua, tests/dps_role_behavior_spec.lua</files>
  <behavior>
    - Test 1: `should_hold_offense(...)` returns true when danger is unstable, threat is high, or a wipe-risk control window is active.
    - Test 2: `should_drop_threat(...)` returns true before death only in real threat windows, not during routine safe throughput.
    - Test 3: `should_abort_commit(...)` returns true for a rising-danger cast/channel window and false for marginal or already-safe commits.
  </behavior>
  <action>Create `eax_shared/dps_risk.lua` with these exact exports: `should_hold_offense(snapshot, opts)`, `should_drop_threat(snapshot, opts)`, and `should_abort_commit(snapshot, cast_state, opts)`. Encode the locked DPS posture with concrete rules: keep throughput-first by default; hold offense when `incoming_damage_pct_2s >= 0.30`, when `threat_pct >= 0.85`, when shared policy marks a dangerous control window, or when the target is unstable enough that spending burst is wasteful; drop threat when `threat_pct >= 0.90` or when a rising pressure window combines `threat_pct >= 0.80` with high incoming damage; abort a cast/channel only when danger is clearly rising and the lost damage is marginal relative to the risk. Keep interrupts aggressive by never letting `should_hold_offense(...)` suppress `interrupt_control` winners.</action>
  <acceptance_criteria>
    - `eax_shared/dps_risk.lua` contains `should_hold_offense`
    - `eax_shared/dps_risk.lua` contains `should_drop_threat`
    - `eax_shared/dps_risk.lua` contains `should_abort_commit`
    - `tests/dps_role_behavior_spec.lua` contains `danger window`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/dps_role_behavior_spec.lua</automated>
  </verify>
  <done>The repo has one shared definition of when DPS should keep sending, hold burst, drop threat, or abandon a risky commit.</done>
</task>

<task type="auto">
  <name>Task 2: Roll the shared DPS risk helper across all non-healer DPS specs</name>
  <read_first>
    - eax_shared/dps_risk.lua
    - EAXDruidBalance/main.lua
    - EAXHunterMarksmanship/main.lua
    - EAXMageFire/main.lua
    - EAXRogueCombat/main.lua
    - EAXWarlockAffliction/main.lua
    - EAXWarriorFury/main.lua
  </read_first>
  <files>EAXDruidBalance/main.lua, EAXHunterBeastMastery/main.lua, EAXHunterMarksmanship/main.lua, EAXHunterSurvival/main.lua, EAXMageArcane/main.lua, EAXMageFire/main.lua, EAXMageFrost/main.lua, EAXPaladinRetribution/main.lua, EAXPriestShadow/main.lua, EAXRogueAssassination/main.lua, EAXRogueCombat/main.lua, EAXRogueSubtlety/main.lua, EAXShamanElemental/main.lua, EAXShamanEnhancement/main.lua, EAXWarlockAffliction/main.lua, EAXWarlockDemonology/main.lua, EAXWarlockDestruction/main.lua, EAXWarriorArms/main.lua, EAXWarriorFury/main.lua</files>
  <action>Require `eax_shared/dps_risk` in every non-healer DPS `main.lua` file and use it in two exact places: (1) offensive cooldown / trinket / burst-window helpers must bail early when `dps_risk.should_hold_offense(...)` returns true, and (2) threat-drop or cast-abort surfaces must use `dps_risk.should_drop_threat(...)` or `dps_risk.should_abort_commit(...)`. For caster specs (`EAXMage*`, `EAXWarlock*`, `EAXPriestShadow`, `EAXShamanElemental`, `EAXDruidBalance`) wire early stop-cast behavior through their existing cast lanes or `SpellStopCasting()` only when the helper says the commit is no longer worth it. For melee / instant specs (`EAXWarriorArms`, `EAXWarriorFury`, `EAXRogue*`, `EAXHunter*`, `EAXShamanEnhancement`, `EAXPaladinRetribution`) gate burst cooldown helpers and threat-sensitive commits through `should_hold_offense(...)`. Preserve the locked philosophy: DPS remains leaderboard-oriented and only yields throughput for clear self-death, wipe-prevention, or clearly lower-chaos alternatives with marginal damage loss.</action>
  <acceptance_criteria>
    - `EAXMageFire/main.lua` contains `dps_risk`
    - `EAXWarriorFury/main.lua` contains `dps_risk`
    - `EAXWarlockAffliction/main.lua` contains `dps_risk`
    - `EAXRogueCombat/main.lua` contains `dps_risk`
    - `EAXHunterMarksmanship/main.lua` contains `dps_risk`
    - `EAXMageFire/main.lua` or another caster file contains `should_abort_commit`
  </acceptance_criteria>
  <verify>
    <automated>rtk lua tests/dps_role_behavior_spec.lua && rtk lua tests/reactive_runtime_wiring_spec.lua</automated>
  </verify>
  <done>All non-healer DPS specs now share the same danger-window hold, threat-drop, and early-abort posture instead of greedily sending through unsafe windows.</done>
</task>

</tasks>

<verification>
Run DPS-family checks:
- `rtk lua tests/dps_role_behavior_spec.lua`
- `rtk lua tests/reactive_runtime_wiring_spec.lua`
</verification>

<success_criteria>
Every non-healer DPS spec stays aggressive when safe, but clearly holds burst, drops threat, and abandons doomed commits when danger or wipe-risk windows justify it.
</success_criteria>

<output>
After completion, create `.planning/phases/07-role-intelligence-tuning/07-04-SUMMARY.md`
</output>
