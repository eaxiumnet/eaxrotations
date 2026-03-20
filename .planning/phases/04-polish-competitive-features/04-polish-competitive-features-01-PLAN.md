---
phase: 04-polish-competitive-features
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/dps_meter.lua
  - eax_shared/cooldown_tracker.lua
  - eax_shared/visual_state.lua
autonomous: true
requirements: [VIS-01, VIS-02, VIS-03, VIS-04]
user_setup: []
must_haves:
  truths:
    - "Combat snapshots expose DPS/HPS totals per fight"
    - "HUD data includes cooldown remaining, TTD, and tracked aura states"
    - "Shared visual state can be consumed by every spec without per-spec rewrites"
  artifacts:
    - path: "eax_shared/dps_meter.lua"
      provides: "Fight-level damage/healing accumulation + per-second rates"
      contains: "get_snapshot"
    - path: "eax_shared/cooldown_tracker.lua"
      provides: "Remaining cooldown seconds for next recommended action"
      contains: "seconds_remaining"
    - path: "eax_shared/visual_state.lua"
      provides: "Unified payload for ESP HUD fields"
      contains: "build_snapshot"
  key_links:
    - from: "eax_shared/visual_state.lua"
      to: "eax_shared/dps_meter.lua"
      via: "snapshot composition"
      pattern: "dps_meter\.get_snapshot"
    - from: "eax_shared/visual_state.lua"
      to: "eax_shared/cooldown_tracker.lua"
      via: "cooldown readout"
      pattern: "cooldown_tracker\.seconds_remaining"
---

<objective>
Create the shared telemetry foundation for all Phase 04 visual features so specs can render DPS/HPS, cooldown, TTD, and buff/debuff state from one consistent contract.

Purpose: Prevent 27 divergent HUD implementations and make visual rollout deterministic.
Output: Three shared modules (`dps_meter.lua`, `cooldown_tracker.lua`, `visual_state.lua`) with stable APIs.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/04-polish-competitive-features/04-RESEARCH.md
@EAXWarriorFury/esp_renderer.lua
@EAXWarriorFury/ttd_tracker.lua

<interfaces>
From `EAXWarriorFury/ttd_tracker.lua`:
```lua
function ttd_tracker.update(target)
function ttd_tracker.get(target) -- returns 999 when unknown
function ttd_tracker.is_dying(target, threshold_s)
```

From `EAXWarriorFury/esp_renderer.lua`:
```lua
function esp_renderer.on_cast(spell_id, name, col, target_name)
function esp_renderer.on_render(menu)
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Implement shared DPS/HPS fight meter module</name>
  <read_first>
    - eax_shared/mana_manager.lua
    - eax_shared/threat_manager.lua
    - EAXWarriorFury/main.lua
  </read_first>
  <files>eax_shared/dps_meter.lua</files>
  <behavior>
    - Test 1: Damage and healing events during one combat window accumulate into separate totals.
    - Test 2: Ending combat resets active-window timing and stores final snapshot.
    - Test 3: Empty/idle state returns zeroed snapshot without nil fields.
  </behavior>
  <action>Create `eax_shared/dps_meter.lua` exposing `on_combat_start()`, `on_damage(amount)`, `on_heal(amount)`, `on_combat_end()`, `reset()`, and `get_snapshot()`. `get_snapshot()` must return a table with exact keys `damage_total`, `healing_total`, `duration_s`, `dps`, `hps`, and `in_combat`. Use numeric defaults of `0` and guard divide-by-zero when duration is `< 0.1` seconds.</action>
  <acceptance_criteria>
    - `eax_shared/dps_meter.lua` exports all six public functions
    - `get_snapshot()` returns all required keys with numeric values
    - Module contains explicit divide-by-zero guard for DPS/HPS
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "on_combat_start|on_damage|on_heal|on_combat_end|get_snapshot|duration_s|dps|hps" eax_shared/dps_meter.lua && rtk luac -p eax_shared/dps_meter.lua</automated>
  </verify>
  <done>Shared fight meter is deterministic and syntactically valid.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement cooldown + visual snapshot composition modules</name>
  <read_first>
    - EAXWarriorFury/esp_renderer.lua
    - EAXWarriorFury/ttd_tracker.lua
    - eax_shared/encounter_manager.lua
  </read_first>
  <files>eax_shared/cooldown_tracker.lua, eax_shared/visual_state.lua</files>
  <behavior>
    - Test 1: cooldown tracker returns `0` when no spell is set.
    - Test 2: visual snapshot always includes DPS/HPS, cooldown, TTD, and aura list fields.
    - Test 3: unknown TTD normalizes to display-safe `--` sentinel in snapshot field.
  </behavior>
  <action>Create `eax_shared/cooldown_tracker.lua` with `set_next_spell(spell_id, set_at, cooldown_s)`, `clear()`, and `seconds_remaining(now_s)`. Create `eax_shared/visual_state.lua` with `build_snapshot(args)` that composes `dps_meter.get_snapshot()`, `cooldown_tracker.seconds_remaining(...)`, provided `ttd_seconds`, and provided `tracked_auras`. The returned table must include exact keys: `dps`, `hps`, `cooldown_s`, `ttd_s`, `tracked_auras`.</action>
  <acceptance_criteria>
    - `eax_shared/cooldown_tracker.lua` includes `seconds_remaining`
    - `eax_shared/visual_state.lua` includes `build_snapshot`
    - `build_snapshot` calls both shared trackers and normalizes missing TTD
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "seconds_remaining|build_snapshot|dps_meter\.get_snapshot|cooldown_tracker\.seconds_remaining|ttd" eax_shared/cooldown_tracker.lua eax_shared/visual_state.lua && rtk luac -p eax_shared/cooldown_tracker.lua && rtk luac -p eax_shared/visual_state.lua</automated>
  </verify>
  <done>Shared visual contract exists and is ready for spec-wide HUD wiring.</done>
</task>

</tasks>

<verification>
Run shared-module syntax + contract checks:
- `rtk luac -p eax_shared/dps_meter.lua eax_shared/cooldown_tracker.lua eax_shared/visual_state.lua`
- `rtk rg -n "build_snapshot|get_snapshot|seconds_remaining" eax_shared/*.lua`
</verification>

<success_criteria>
All required VIS data contracts are centralized in shared modules and can be consumed without spec-specific branching.
</success_criteria>

<output>
After completion, create `.planning/phases/04-polish-competitive-features/04-01-SUMMARY.md`
</output>
