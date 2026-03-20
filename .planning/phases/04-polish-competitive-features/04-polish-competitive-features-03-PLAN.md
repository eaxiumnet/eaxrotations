---
phase: 04-polish-competitive-features
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/vendor_automation.lua
  - eax_shared/consumables_manager.lua
  - eax_shared/mount_manager.lua
autonomous: true
requirements: [AUTO-01, AUTO-02, AUTO-03, AUTO-04]
user_setup: []
must_haves:
  truths:
    - "Vendor automation can repair gear and sell greys safely"
    - "Consumable decisions are centralized in one shared module"
    - "Mount/dismount behavior is combat-state aware"
  artifacts:
    - path: "eax_shared/vendor_automation.lua"
      provides: "Auto-repair + auto-sell logic with throttling"
      contains: "try_auto_repair"
    - path: "eax_shared/consumables_manager.lua"
      provides: "Potion/food/flask policy helpers"
      contains: "try_use_combat_consumable"
    - path: "eax_shared/mount_manager.lua"
      provides: "Auto-mount and combat dismount"
      contains: "update_mount_state"
  key_links:
    - from: "eax_shared/vendor_automation.lua"
      to: "core.input.repair_all_items"
      via: "documented repair API"
      pattern: "repair_all_items"
    - from: "eax_shared/vendor_automation.lua"
      to: "core.inventory"
      via: "vendor bag scan and value checks"
      pattern: "get_total_repair_cost|get_items_in_bag"
---

<objective>
Build the shared automation core for vendor actions, consumable usage, and mount state transitions before bulk spec integration.

Purpose: Deliver AUTO requirements once and avoid 27 independent automation implementations.
Output: Three shared automation modules with stable entry points for spec main loops.
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
@EAXFishing/inventory/vendor.lua
@eax_shared/ooc_manager.lua
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create shared vendor automation module (repair + sell greys)</name>
  <read_first>
    - EAXFishing/inventory/vendor.lua
    - eax_shared/ooc_manager.lua
    - EAXWarriorFury/main.lua
  </read_first>
  <files>eax_shared/vendor_automation.lua</files>
  <behavior>
    - Test 1: insufficient gold prevents repair and returns false.
    - Test 2: available repair cost + gold triggers repair call and returns true.
    - Test 3: grey-item auto-sell iterates bags 0-4 and attempts documented sell action only for quality 0 items.
  </behavior>
  <action>Create `eax_shared/vendor_automation.lua` with public functions `try_auto_repair(me, menu, utils)` and `try_auto_sell_greys(me, menu, utils)`. Use `core.inventory.get_total_repair_cost` and `core.input.repair_all_items(false)` for repair. For auto-sell, scan bag items and sell only grey quality items with item quality `0`; include a 2-3 second throttle to prevent repeated vendor spam calls in one frame window.</action>
  <acceptance_criteria>
    - Module exports both public functions
    - Repair path uses `get_total_repair_cost` and `repair_all_items`
    - Grey-sell path filters by quality `0` and includes throttle state
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "try_auto_repair|try_auto_sell_greys|get_total_repair_cost|repair_all_items|quality" eax_shared/vendor_automation.lua && rtk luac -p eax_shared/vendor_automation.lua</automated>
  </verify>
  <done>Vendor automation module is reusable and syntactically valid.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Create shared consumables and mount managers</name>
  <read_first>
    - eax_shared/ooc_manager.lua
    - EAXWarriorFury/main.lua
    - EAXDruidFeral/main.lua
  </read_first>
  <files>eax_shared/consumables_manager.lua, eax_shared/mount_manager.lua</files>
  <behavior>
    - Test 1: consumables manager respects combat-only potion checks.
    - Test 2: mount manager always dismounts when combat starts.
    - Test 3: mount manager only mounts when out of combat and stationary.
  </behavior>
  <action>Create `eax_shared/consumables_manager.lua` with `try_use_combat_consumable(me, menu, utils)`, `try_use_ooc_food_drink(me, menu, utils)`, and `try_maintain_flask(me, menu, utils)`. Create `eax_shared/mount_manager.lua` with `update_mount_state(me, menu, utils)` implementing concrete gates: if `me:is_in_combat()` and mounted then dismount; if not in combat, not moving, and auto-mount toggle enabled then attempt mount using configured mount spell/item IDs.</action>
  <acceptance_criteria>
    - `consumables_manager.lua` exports all three public functions
    - `mount_manager.lua` exports `update_mount_state`
    - Combat dismount branch and out-of-combat mount branch are both explicit
  </acceptance_criteria>
  <verify>
    <automated>rtk rg -n "try_use_combat_consumable|try_use_ooc_food_drink|try_maintain_flask|update_mount_state|is_in_combat|is_mounted|is_moving" eax_shared/consumables_manager.lua eax_shared/mount_manager.lua && rtk luac -p eax_shared/consumables_manager.lua && rtk luac -p eax_shared/mount_manager.lua</automated>
  </verify>
  <done>AUTO shared modules are complete and ready for spec-wide wiring.</done>
</task>

</tasks>

<verification>
Shared automation checks:
- `rtk luac -p eax_shared/vendor_automation.lua eax_shared/consumables_manager.lua eax_shared/mount_manager.lua`
- `rtk rg -n "repair|sell|mount|dismount|consumable" eax_shared/vendor_automation.lua eax_shared/consumables_manager.lua eax_shared/mount_manager.lua`
</verification>

<success_criteria>
AUTO-01..AUTO-04 shared logic exists in dedicated modules and is ready to be imported by every spec.
</success_criteria>

<output>
After completion, create `.planning/phases/04-polish-competitive-features/04-03-SUMMARY.md`
</output>
