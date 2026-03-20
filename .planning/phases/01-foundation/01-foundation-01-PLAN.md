---
phase: 01-foundation
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - common/eax_shared/interrupt_manager.lua
  - common/eax_shared/defensive_manager.lua
  - common/eax_shared/encounter_manager.lua
  - common/eax_shared/ooc_manager.lua
  - common/eax_shared/racial_manager.lua
autonomous: true
requirements:
  - FOUND-01
must_haves:
  truths:
    - "All 5 managers exist in common/eax_shared/ with working module.exports"
    - "Each manager has all public functions from per-spec versions"
    - "Class-specific data (INTERRUPT_SPELLS, DEFENSIVE_TIERS, etc.) preserved"
  artifacts:
    - path: "common/eax_shared/interrupt_manager.lua"
      provides: "Priority-based interrupt system"
      min_lines: 200
      exports: ["should_interrupt", "try_interrupt"]
    - path: "common/eax_shared/defensive_manager.lua"
      provides: "HP-threshold layered defensive system"
      min_lines: 60
      exports: ["get_defensives", "get_defensive", "try_defensive"]
    - path: "common/eax_shared/encounter_manager.lua"
      provides: "Boss encounter awareness with policy system"
      min_lines: 350
      exports: ["get_policy"]
    - path: "common/eax_shared/ooc_manager.lua"
      provides: "Out-of-combat automation"
      min_lines: 300
      exports: ["on_update", "try_drink", "try_eat", "try_buff", "try_rez"]
    - path: "common/eax_shared/racial_manager.lua"
      provides: "Racial ability management"
      min_lines: 140
      exports: ["try_racial", "try_burst_racial"]
  key_links:
    - from: "common/eax_shared/ooc_manager.lua"
      to: "common/modules/buff_manager"
      via: "require statement"
      pattern: "require.*buff_manager"
---

<objective>
Extract 5 shared manager modules from per-spec duplicates into common/eax_shared/. Each manager becomes a reusable module with class-specific data preserved.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@EAXDruidBalance/interrupt_manager.lua
@EAXDruidBalance/defensive_manager.lua
@EAXDruidBalance/encounter_manager.lua
@EAXDruidBalance/ooc_manager.lua
@EAXDruidBalance/racial_manager.lua
@.planning/codebase/CONVENTIONS.md
</context>

<interfaces>
<!-- Key types and contracts the executor needs. Extracted from codebase. -->

From any spec's utils.lua:
```lua
function utils.resolve_spell_id(rank_table) --> number|nil
function utils.cast_self(spell_id, me) --> boolean
function utils.cast_target(spell_id, target) --> boolean
function utils.can_cast_self(spell_id, me) --> boolean
```

From Sylvanas API:
```lua
core.spell_book.is_spell_learned(spell_id) --> boolean
core.spell_book.get_spell_cooldown(spell_id) --> number
core.spell_book.is_usable_spell(spell_id) --> boolean
core.object_manager.get_player() --> unit
core.time() --> number
me:get_health_percentage() --> number
me:is_in_combat() --> boolean
me:is_moving() --> boolean
me:has_item(item_id) --> boolean
me:get_item_cooldown(item_id) --> number
unit:is_valid() --> boolean
unit:is_dead() --> boolean
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Create interrupt_manager.lua</name>
  <files>common/eax_shared/interrupt_manager.lua</files>
  <read_first>
    - EAXDruidBalance/interrupt_manager.lua (source pattern)
    - EAXWarriorArms/interrupt_manager.lua (if exists, for warrior interrupts)
    - EAXMageFire/interrupt_manager.lua (if exists, for mage interrupts)
  </read_first>
  <action>
    Create `common/eax_shared/interrupt_manager.lua` by consolidating all class-specific INTERRUPT_SPELLS tables from existing per-spec versions.

    Required exports:
    ```lua
    local interrupt_manager = {}
    
    -- Main check: should we interrupt this target?
    function interrupt_manager.should_interrupt(target)
        --> returns boolean
    end
    
    -- Main action: try to interrupt target
    function interrupt_manager.try_interrupt(me, target, class_name, utils_module)
        --> returns boolean (true if interrupt cast attempted)
    end
    
    return interrupt_manager
    ```

    Data structure (preserve all existing data):
    - INTERRUPT_SPELLS table keyed by class_name
    - Each class entry has array of {id, name, type} entries
    - Types: "fast" (true interrupt), "stun" (pseudo-interrupt via stun)

    Include from existing per-spec files:
    - warrior: Pummel (6552, 6554)
    - rogue: Kick (1766, 8959, 17699)
    - hunter: Counter Shot (14768), Silencing Shot (34490)
    - paladin: Rebuke (31935), Hammer of Justice (20066)
    - shaman: Earth Shock ranks (all ranks)
    - mage: Counterspell (2139)
    - priest: Silence (15487)
    - druid: Bash ranks (8983, 1822, 5211), Cyclone (33786)
    - warlock: Felhunter's Spell Lock (19647)
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/interrupt_manager.lua
    - Contains `return interrupt_manager` at end
    - Exports: `should_interrupt`, `try_interrupt`
    - All 9 class entries present in INTERRUPT_SPELLS
  </acceptance_criteria>
  <verify>
    grep -l "function interrupt_manager.try_interrupt" common/eax_shared/interrupt_manager.lua && echo "INTERRUPT_OK"</verify>
  <done>interrupt_manager.lua exports try_interrupt and should_interrupt with all 9 classes</done>
</task>

<task type="auto">
  <name>Task 2: Create defensive_manager.lua</name>
  <files>common/eax_shared/defensive_manager.lua</files>
  <read_first>
    - EAXDruidBalance/defensive_manager.lua (source pattern)
    - EAXWarriorArms/defensive_manager.lua (for warrior defensives)
    - EAXRogueAssassination/defensive_manager.lua (for rogue defensives)
  </read_first>
  <action>
    Create `common/eax_shared/defensive_manager.lua` by consolidating all class-specific DEFENSIVE_TIERS from existing per-spec versions.

    Required exports:
    ```lua
    local defensive_manager = {}
    
    function defensive_manager.get_defensives(class_name)
        --> returns table of defensive tier entries
    end
    
    function defensive_manager.get_defensive(hp_pct, class_name)
        --> returns single defensive entry for this HP threshold
    end
    
    function defensive_manager.try_defensive(me, class_name, utils_module)
        --> returns boolean
    end
    
    return defensive_manager
    ```

    Preserve data from all classes:
    - warrior: Last Stand (12975), Berserker Rage (18499), Shield Wall (871/8538/8539)
    - rogue: Cloak of Shadows (31224), Evasion (5277), Vanish (1856)
    - hunter: Feign Death (5384)
    - paladin: Hand of Freedom (1044), Divine Shield (642), Blessing of Sacrifice (20217)
    - druid: Barkskin (22812), Survival Instincts (61336)
    - mage: Ice Block (11958, 27619)
    - priest: Pain Suppression (33206)
    - shaman: Shamanistic Rage (30823)
    - warlock: Drain Life (all ranks)
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/defensive_manager.lua
    - Contains `return defensive_manager` at end
    - Exports: `get_defensives`, `get_defensive`, `try_defensive`
    - All 9 class entries present in DEFENSIVE_TIERS
  </acceptance_criteria>
  <verify>
    grep -l "function defensive_manager.try_defensive" common/eax_shared/defensive_manager.lua && echo "DEFENSIVE_OK"</verify>
  <done>defensive_manager.lua exports get_defensives, get_defensive, try_defensive with all 9 classes</done>
</task>

<task type="auto">
  <name>Task 3: Create encounter_manager.lua</name>
  <files>common/eax_shared/encounter_manager.lua</files>
  <read_first>
    - EAXDruidBalance/encounter_manager.lua (source - largest version with all bosses)
  </read_first>
  <action>
    Create `common/eax_shared/encounter_manager.lua` by copying the most complete existing version (EAXDruidBalance has 359 lines covering all TBC dungeons/raids).

    Required exports:
    ```lua
    local encounter_manager = {}
    
    function encounter_manager.get_policy(me)
        --> returns encounter_policy table with fields:
        -->   encounter_id, is_boss, hold_cooldowns, burn_phase,
        -->   avoid_close_range, min_range, aoe_safe, interrupt_priority,
        -->   force_decurse, force_dispel, pet_follow, disable_pet_attack,
        -->   tank_damage_heavy, raid_aoe_heavy, healer_mana_call
    end
    
    return encounter_manager
    ```

    Copy the complete BOSS_DB from EAXDruidBalance/encounter_manager.lua including:
    - All Hellfire Citadel bosses
    - All Coilfang Reservoir bosses
    - All Tempest Keep bosses
    - All Auchindoun bosses
    - All Caverns of Time bosses
    - All Blade's Edge Mountains bosses
    - All Netherstorm bosses
    - All Zone: Eye of the Storm bosses
    - DEFAULT_POLICY table
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/encounter_manager.lua
    - Contains `return encounter_manager` at end
    - Exports: `get_policy`
    - BOSS_DB covers all TBC dungeon/raid zones
    - DEFAULT_POLICY has all required fields
  </acceptance_criteria>
  <verify>
    grep -l "function encounter_manager.get_policy" common/eax_shared/encounter_manager.lua && grep -c "\[" common/eax_shared/encounter_manager.lua</verify>
  <done>encounter_manager.lua exports get_policy with full boss database</done>
</task>

<task type="auto">
  <name>Task 4: Create ooc_manager.lua</name>
  <files>common/eax_shared/ooc_manager.lua</files>
  <read_first>
    - EAXDruidBalance/ooc_manager.lua (source pattern - 308 lines)
    - EAXPriestShadow/ooc_manager.lua (if exists, for priest rez spells)
  </read_first>
  <action>
    Create `common/eax_shared/ooc_manager.lua` by copying the most complete existing version.

    Required exports:
    ```lua
    local ooc_manager = {}
    
    -- Main update function - call each tick when OOC
    function ooc_manager.on_update(me, menu, utils)
    end
    
    -- Individual subsystems
    function ooc_manager.try_drink(me, menu, utils) --> boolean
    function ooc_manager.try_eat(me, menu, utils) --> boolean
    function ooc_manager.try_buff(me, menu, utils) --> boolean
    function ooc_manager.try_rez(me, party_members, utils) --> boolean
    
    return ooc_manager
    ```

    Copy complete implementation including:
    - DRINK_BUFF_IDS and EAT_BUFF_IDS arrays
    - find_consumable_of_type helper
    - Party resurrection logic
    - Group buff application
    - All internal state variables (last_drink_attempt, etc.)
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/ooc_manager.lua
    - Contains `return ooc_manager` at end
    - Exports: `on_update`, `try_drink`, `try_eat`, `try_buff`, `try_rez`
  </acceptance_criteria>
  <verify>
    grep -l "function ooc_manager.on_update" common/eax_shared/ooc_manager.lua && echo "OOC_OK"</verify>
  <done>ooc_manager.lua exports on_update, try_drink, try_eat, try_buff, try_rez</done>
</task>

<task type="auto">
  <name>Task 5: Create racial_manager.lua</name>
  <files>common/eax_shared/racial_manager.lua</files>
  <read_first>
    - EAXDruidBalance/racial_manager.lua (source pattern - 150 lines)
  </read_first>
  <action>
    Create `common/eax_shared/racial_manager.lua` by copying the existing implementation (it's already well-structured).

    Required exports:
    ```lua
    local racial_manager = {}
    
    -- Try to fire a single racial by name
    function racial_manager.try_racial(me, name) --> boolean
    end
    
    -- Try burst racials (Blood Fury, Berserking) - sync with opener/burst
    function racial_manager.try_burst_racial(me) --> boolean
    end
    
    return racial_manager
    ```

    Preserve existing:
    - RACIALS table with all racial spell IDs
    - OFFENSIVE table marking burst racials
    - resolve() function for spell ID resolution
    - pcall_bool() wrapper for safe API calls
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/racial_manager.lua
    - Contains `return racial_manager` at end
    - Exports: `try_racial`, `try_burst_racial`
    - RACIALS table has all 8 racial abilities
  </acceptance_criteria>
  <verify>
    grep -l "function racial_manager.try_racial" common/eax_shared/racial_manager.lua && echo "RACIAL_OK"</verify>
  <done>racial_manager.lua exports try_racial and try_burst_racial with all racial abilities</done>
</task>

</tasks>

<verification>
All 5 shared managers exist and export their public functions. Each can be required and used independently.
</verification>

<success_criteria>
- common/eax_shared/interrupt_manager.lua exists with should_interrupt and try_interrupt
- common/eax_shared/defensive_manager.lua exists with get_defensives, get_defensive, try_defensive
- common/eax_shared/encounter_manager.lua exists with get_policy
- common/eax_shared/ooc_manager.lua exists with on_update, try_drink, try_eat, try_buff, try_rez
- common/eax_shared/racial_manager.lua exists with try_racial, try_burst_racial
- All managers use module pattern (return table at end)
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-SUMMARY.md`
</output>
