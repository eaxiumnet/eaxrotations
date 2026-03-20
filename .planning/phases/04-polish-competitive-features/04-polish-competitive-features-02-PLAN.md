---
phase: 04-polish-competitive-features
plan: 02
type: execute
wave: 2
depends_on:
  - 04-polish-competitive-features-01
files_modified:
  - EAX*/esp_renderer.lua
  - EAX*/main.lua
autonomous: true
requirements: [VIS-01, VIS-02, VIS-03, VIS-04]
user_setup: []
must_haves:
  truths:
    - "Each spec HUD displays DPS/HPS, cooldown timer, and TTD"
    - "Each spec HUD shows tracked buff/debuff statuses"
    - "Visual telemetry updates live during combat without breaking existing next-action rendering"
  artifacts:
    - path: "EAXWarriorFury/esp_renderer.lua"
      provides: "Reference implementation of expanded HUD sections"
      contains: "DPS/HPS"
    - path: "EAXWarriorFury/main.lua"
      provides: "Reference integration of visual_state payload"
      contains: "visual_state.build_snapshot"
    - path: "EAX*/esp_renderer.lua"
      provides: "Consistent HUD contract across all specs"
      contains: "TTD"
  key_links:
    - from: "EAX*/main.lua"
      to: "eax_shared/visual_state.lua"
      via: "HUD payload construction"
      pattern: "require\(\"common/eax_shared/visual_state\"\)"
    - from: "EAX*/esp_renderer.lua"
      to: "main.lua"
      via: "new render payload function"
      pattern: "set_visual_snapshot|update_visual_snapshot"
---

<objective>
Roll out the Phase 04 visual telemetry contract to all specs, adding the required competitive HUD elements while preserving current ESP behavior.

Purpose: Deliver user-visible VIS requirements uniformly instead of leaving visual polish per-spec.
Output: All spec `esp_renderer.lua` and `main.lua` files wired to the new shared visual modules.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/04-polish-competitive-features/04-polish-competitive-features-01-PLAN.md
@EAXWarriorFury/esp_renderer.lua
@EAXWarriorFury/main.lua
</context>

<tasks>

<task type="auto">
  <name>Task 1: Expand ESP renderer contract and HUD layout for Phase 04 metrics</name>
  <read_first>
    - EAXWarriorFury/esp_renderer.lua
    - EAXMageArcane/esp_renderer.lua
    - EAXShamanRestoration/esp_renderer.lua
    - eax_shared/visual_state.lua
  </read_first>
  <files>EAX*/esp_renderer.lua</files>
  <action>Update all `EAX*/esp_renderer.lua` files to accept a visual snapshot payload containing `dps`, `hps`, `cooldown_s`, `ttd_s`, and `tracked_auras`. Add explicit HUD rows labeled `DPS`, `HPS`, `CD`, and `TTD`. Add a compact aura strip rendering up to 4 entries from `tracked_auras`. Keep existing next-action icon/name area intact; do not remove `on_cast` behavior.</action>
  <acceptance_criteria>
    - Every `EAX*/esp_renderer.lua` contains labels `DPS`, `HPS`, `CD`, and `TTD`
    - Every `EAX*/esp_renderer.lua` contains a function handling `tracked_auras`
    - Existing `on_cast` function still exists in every renderer
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "DPS|HPS|TTD|tracked_auras|function esp_renderer\.on_cast" EAX*/esp_renderer.lua && rtk luac -p EAX*/esp_renderer.lua</automated>
  </verify>
  <done>All renderers expose the same expanded HUD contract and remain parse-valid.</done>
</task>

<task type="auto">
  <name>Task 2: Wire shared visual snapshot generation into all spec main loops</name>
  <read_first>
    - EAXWarriorFury/main.lua
    - EAXMageArcane/main.lua
    - EAXRogueCombat/main.lua
    - eax_shared/dps_meter.lua
    - eax_shared/visual_state.lua
  </read_first>
  <files>EAX*/main.lua</files>
  <action>For each spec `main.lua`, require `common/eax_shared/dps_meter`, `common/eax_shared/cooldown_tracker`, and `common/eax_shared/visual_state`. In the update loop, feed combat events into `dps_meter`, compute `ttd_s` from existing local `ttd_tracker.get(target)` when available, and pass `visual_state.build_snapshot(...)` into the renderer via `esp_renderer.update_visual_snapshot(...)` (or a newly added equivalent setter). Ensure cooldown data comes from the currently recommended spell and its cooldown value.</action>
  <acceptance_criteria>
    - Every `EAX*/main.lua` requires the three shared visual modules
    - Every `EAX*/main.lua` updates renderer snapshot each tick
    - TTD fallback behavior is present when no estimator exists
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "common/eax_shared/(dps_meter|cooldown_tracker|visual_state)|build_snapshot|update_visual_snapshot|ttd_tracker\.get" EAX*/main.lua && rtk luac -p EAX*/main.lua</automated>
  </verify>
  <done>All specs stream live visual telemetry to the HUD through the shared contract.</done>
</task>

</tasks>

<verification>
Bulk rollout checks:
- `rtk luac -p EAX*/esp_renderer.lua EAX*/main.lua`
- `rtk rg -n "DPS|HPS|TTD|common/eax_shared/visual_state" EAX*/esp_renderer.lua EAX*/main.lua`
</verification>

<success_criteria>
VIS-01..VIS-04 are visibly represented across all spec HUDs and wired through shared modules.
</success_criteria>

<output>
After completion, create `.planning/phases/04-polish-competitive-features/04-02-SUMMARY.md`
</output>
