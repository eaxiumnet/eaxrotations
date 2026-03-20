---
phase: 01-foundation
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - common/eax_shared/set_bonus.lua
  - common/eax_shared/swing_timer.lua
autonomous: true
requirements:
  - FOUND-03
  - COMBAT-01
must_haves:
  truths:
    - "set_bonus.lua dynamically scans equipped gear for T4/T5/T6 set items"
    - "set_bonus.lua provides 2pc and 4pc bonus multipliers"
    - "swing_timer.lua tracks melee swing timing for all weapon types"
    - "swing_timer.lua provides safe queue check before ability casts"
  artifacts:
    - path: "common/eax_shared/set_bonus.lua"
      provides: "Dynamic set bonus detection for all T4/T5/T6 sets"
      min_lines: 150
      exports: ["update", "has_set_bonus", "get_set_count"]
    - path: "common/eax_shared/swing_timer.lua"
      provides: "Melee swing timing for Warriors, Rogues, Hunters"
      min_lines: 100
      exports: ["get_next_swing_time", "is_swing_safe", "get_time_to_swing"]
  key_links:
    - from: "common/eax_shared/set_bonus.lua"
      to: "core.object_manager"
      via: "me:get_inventory()"
      pattern: "get_inventory.*ITEM"
    - from: "common/eax_shared/swing_timer.lua"
      to: "core.spell_book"
      via: "get_melee_attack_time"
      pattern: "get_melee_attack_time"
---

<objective>
Create two new shared modules: set_bonus.lua for dynamic gear scanning, and swing_timer.lua for melee timing. Both address critical gaps identified in the codebase.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/research/PITFALLS.md
@.planning/research/STACK.md
</context>

<interfaces>
From Sylvanas API (from codebase research):
```lua
core.object_manager.get_player() --> unit
me:get_inventory() --> table of equipped items
item:get_item_id() --> number
core.spell_book.get_melee_attack_time(unit) --> number (ms)
unit:get_attack_time() --> number
unit:get_offhand_attack_time() --> number
core.spell_book.get_spell_cast_time(spell_id) --> number (seconds)
core.time() --> number (seconds)
```

Reference implementation pattern from Pitfalls:
```lua
-- Pattern for checking remaining duration before recast
local remaining = utils.get_debuff_remaining_ms(target, spells.CORRUPTION)
local cast_time = core.spell_book.get_spell_cast_time(corruption_id) * 1000
if remaining < cast_time then
    utils.cast_target(corruption_id, target)
end
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Create set_bonus.lua</name>
  <files>common/eax_shared/set_bonus.lua</files>
  <read_first>
    - EAXDruidBalance/main.lua (to see how TBC_SETS is currently used)
    - EAXWarriorArms/main.lua (for warrior set bonuses)
  </read_first>
  <action>
    Create `common/eax_shared/set_bonus.lua` to dynamically detect set bonuses from equipped gear.

    **Background from PROJECT.md:**
    - Current code has hardcoded TBC_SETS table with only 3 sets (Warbringer, WarbringerBattlegear, Ymirjar)
    - This needs to be replaced with dynamic gear scanning for ALL T4/T5/T6 sets

    **Implementation approach:**

    1. Define all TBC Classic set item IDs organized by set:
    ```lua
    local SET_ITEMS = {
        -- T4 Sets (Karazhan, Gruul, Magtheridon)
        ["t4"] = {
            ["warrior"] = { [set_id] = "warbringer_battlegear", ... },
            ["paladin"] = { ... },
            -- etc for all classes
        },
        -- T5 Sets (Serpentshrine, Tempest Keep)
        ["t5"] = { ... },
        -- T6 Sets (Black Temple, Sunwell)
        ["t6"] = { ... },
    }
    ```

    2. Track equipped items via me:get_inventory()

    3. Required exports:
    ```lua
    local set_bonus = {}
    
    -- Call each tick to update cached set bonuses
    function set_bonus.update(me)
        -- Scans equipped items, updates cache
    end
    
    -- Check if player has N pieces of a set
    function set_bonus.get_set_count(me, set_name)
        --> returns number (0-5)
    end
    
    -- Check if specific set bonus is active
    function set_bonus.has_set_bonus(me, set_name, pieces_needed)
        --> returns boolean
    end
    
    -- Get damage multiplier for set bonuses (used in rotation)
    function set_bonus.get_damage_multiplier(me)
        --> returns number (e.g., 1.05 for 5% boost)
    end
    
    return set_bonus
    ```

    Key item ID ranges to include (from sim core/item_sets.go pattern):
    - T4: ~30217-30223 range (check actual IDs from sim data)
    - T5: ~30224-30230 range
    - T6: ~32473-32487 range and 34165-34172 range

    Note: Item IDs will need verification against actual sim data at `/c/618497f1/scripts/tbc/sim/core/item_sets.go`
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/set_bonus.lua
    - Contains `return set_bonus` at end
    - Exports: `update`, `get_set_count`, `has_set_bonus`, `get_damage_multiplier`
    - SET_ITEMS table covers T4, T5, T6 for all 9 classes
    - Uses me:get_inventory() to scan equipped gear
  </acceptance_criteria>
  <verify>
    grep -l "function set_bonus.update" common/eax_shared/set_bonus.lua && grep -c "t4\|t5\|t6" common/eax_shared/set_bonus.lua</verify>
  <done>set_bonus.lua dynamically scans gear and provides has_set_bonus check</done>
</task>

<task type="auto">
  <name>Task 2: Create swing_timer.lua</name>
  <files>common/eax_shared/swing_timer.lua</files>
  <read_first>
    - .planning/research/PITFALLS.md (for swing timer pitfall details)
  </read_first>
  <action>
    Create `common/eax_shared/swing_timer.lua` for robust melee swing timing.

    **Background from PITFALLS.md:**
    - Slam Clip / Swing Timer Desync: Casting Slam too early delays auto-attack, net DPS loss
    - Prevention: Check swing timer before Slam with configurable safety buffer
    - Affected specs: Arms Warrior, Fury Warrior
    - Also needed for: Auto Shot clip prevention (Hunters)

    **Implementation approach:**

    1. Track next swing time for main hand and offhand:
    ```lua
    local swing_timer = {}
    
    -- State tracking
    local state = {
        mainhand_next = 0,    -- timestamp of next main hand swing
        offhand_next = 0,     -- timestamp of next offhand swing
        last_update = 0,      -- when state was last refreshed
        mainhand_speed = 0,   -- weapon speed in seconds
        offhand_speed = 0,
    }
    ```

    2. Required exports:
    ```lua
    -- Initialize/update state from current combat state
    function swing_timer.update(me)
        -- Get current swing times from Sylvanas API
        -- Update state.mainhand_next and state.offhand_next
    end
    
    -- Get time until next main hand swing (seconds)
    function swing_timer.get_time_to_swing(me)
        --> returns number (0 if swinging now)
    end
    
    -- Check if it's safe to queue an ability (won't delay swing)
    function swing_timer.is_swing_safe(me, safety_buffer_s)
        --> returns boolean
        --> safety_buffer_s: extra buffer before swing (default 0.1)
    end
    
    -- Get next swing timestamp
    function swing_timer.get_next_swing_time(me)
        --> returns number (timestamp)
    end
    
    -- Check if swing is imminent (for auto shot alignment in Hunters)
    function swing_timer.is_swing_imminent(me, threshold_s)
        --> returns boolean
        --> threshold_s: consider imminent if swing within this time
    end
    
    return swing_timer
    ```

    Use Sylvanas API:
    - me:get_attack_time() for main hand speed
    - me:get_offhand_attack_time() for offhand speed
    - Track last swing via state and calculate next from attack time
    - Use core.time() for timestamps
  </action>
  <acceptance_criteria>
    - File exists at common/eax_shared/swing_timer.lua
    - Contains `return swing_timer` at end
    - Exports: `update`, `get_time_to_swing`, `is_swing_safe`, `get_next_swing_time`, `is_swing_imminent`
    - Handles both main hand and offhand swings
    - Has configurable safety buffer parameter
  </acceptance_criteria>
  <verify>
    grep -l "function swing_timer.is_swing_safe" common/eax_shared/swing_timer.lua && echo "SWING_OK"</verify>
  <done>swing_timer.lua provides safe queue check for melee abilities</done>
</task>

</tasks>

<verification>
Both modules exist and can be required. set_bonus scans equipped gear, swing_timer tracks swing timing.
</verification>

<success_criteria>
- common/eax_shared/set_bonus.lua exists with dynamic gear scanning for T4/T5/T6
- common/eax_shared/swing_timer.lua exists with safe queue check for melee abilities
- Both modules use standard module pattern (return table at end)
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-02-SUMMARY.md`
</output>
