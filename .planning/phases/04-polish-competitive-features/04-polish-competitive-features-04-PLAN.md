---
phase: 04-polish-competitive-features
plan: 04
type: execute
wave: 2
depends_on:
  - 04-polish-competitive-features-03
files_modified:
  - EAX*/main.lua
  - EAX*/menu.lua
autonomous: true
requirements: [AUTO-01, AUTO-02, AUTO-03, AUTO-04]
user_setup: []
must_haves:
  truths:
    - "Every spec can run auto-repair and auto-sell at vendor"
    - "Every spec can use shared consumables policy"
    - "Every spec supports auto-mount/dismount toggles"
  artifacts:
    - path: "EAXWarriorFury/main.lua"
      provides: "Reference automation manager integration"
      contains: "require(\"common/eax_shared/vendor_automation\")"
    - path: "EAXWarriorFury/menu.lua"
      provides: "Reference automation toggles"
      contains: "auto_repair"
    - path: "EAX*/main.lua"
      provides: "Shared automation manager calls in update loop"
      contains: "mount_manager.update_mount_state"
  key_links:
    - from: "EAX*/main.lua"
      to: "eax_shared/vendor_automation.lua"
      via: "vendor updates"
      pattern: "vendor_automation\.try_auto_repair"
    - from: "EAX*/main.lua"
      to: "eax_shared/consumables_manager.lua"
      via: "combat and ooc consumable lane"
      pattern: "consumables_manager\.try_"
---

<objective>
Integrate shared automation modules into all spec execution and menu surfaces so automation features are actually usable in gameplay.

Purpose: Complete AUTO feature delivery by wiring managers into the 27 production loops.
Output: All `main.lua` and `menu.lua` files gain automation requires, toggles, and update-lane calls.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
@C:/Users/Support/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/04-polish-competitive-features/04-polish-competitive-features-03-PLAN.md
@EAXWarriorFury/main.lua
@EAXWarriorFury/menu.lua
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add shared automation toggles to all spec menus</name>
  <read_first>
    - EAXWarriorFury/menu.lua
    - EAXMageArcane/menu.lua
    - EAXShamanRestoration/menu.lua
  </read_first>
  <files>EAX*/menu.lua</files>
  <action>Add these concrete menu controls to every `EAX*/menu.lua` with defaults: `auto_repair` (true), `auto_sell_greys` (true), `auto_mount` (true), `auto_dismount` (true), `auto_combat_potions` (false), `auto_ooc_food_drink` (true), `auto_flask` (false). Render them in the existing OOC/utility panel section using current `ps.render_*` patterns.</action>
  <acceptance_criteria>
    - Every spec menu defines all seven automation controls
    - Every spec menu renders all seven controls with labels
    - Control keys use unique per-spec key strings (no collisions)
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "auto_repair|auto_sell_greys|auto_mount|auto_dismount|auto_combat_potions|auto_ooc_food_drink|auto_flask" EAX*/menu.lua && rtk luac -p EAX*/menu.lua</automated>
  </verify>
  <done>All menus expose AUTO feature toggles consistently.</done>
</task>

<task type="auto">
  <name>Task 2: Wire shared automation managers into all spec update loops</name>
  <read_first>
    - EAXWarriorFury/main.lua
    - EAXDruidBalance/main.lua
    - EAXWarlockAffliction/main.lua
    - eax_shared/vendor_automation.lua
    - eax_shared/consumables_manager.lua
    - eax_shared/mount_manager.lua
  </read_first>
  <files>EAX*/main.lua</files>
  <action>In each `EAX*/main.lua`, require `common/eax_shared/vendor_automation`, `common/eax_shared/consumables_manager`, and `common/eax_shared/mount_manager`. In the out-of-combat lane call `mount_manager.update_mount_state(...)` and `consumables_manager.try_use_ooc_food_drink(...)`. In vendor-available/utility lane call `vendor_automation.try_auto_repair(...)` then `vendor_automation.try_auto_sell_greys(...)`. In combat lane call `consumables_manager.try_use_combat_consumable(...)` and optional `try_maintain_flask(...)` behind menu toggles.</action>
  <acceptance_criteria>
    - Every `EAX*/main.lua` requires all three shared automation modules
    - Every `EAX*/main.lua` calls at least one function from each module
    - Calls are gated by matching menu toggles
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "common/eax_shared/(vendor_automation|consumables_manager|mount_manager)|try_auto_repair|try_auto_sell_greys|update_mount_state|try_use_combat_consumable|try_use_ooc_food_drink" EAX*/main.lua && rtk luac -p EAX*/main.lua</automated>
  </verify>
  <done>All specs actively use shared automation managers in runtime loops.</done>
</task>

</tasks>

<verification>
Integration checks:
- `rtk luac -p EAX*/menu.lua EAX*/main.lua`
- `rtk rg -n "vendor_automation|consumables_manager|mount_manager" EAX*/main.lua EAX*/menu.lua`
</verification>

<success_criteria>
AUTO-01..AUTO-04 are available and wired across the full spec set with user-facing toggles.
</success_criteria>

<output>
After completion, create `.planning/phases/04-polish-competitive-features/04-04-SUMMARY.md`
</output>
