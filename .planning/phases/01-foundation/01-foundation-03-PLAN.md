---
phase: 01-foundation
plan: 03
type: execute
wave: 2
depends_on:
  - 01-foundation-01
files_modified:
  - EAX*/main.lua
  - EAX*/interrupt_manager.lua
  - EAX*/defensive_manager.lua
  - EAX*/encounter_manager.lua
  - EAX*/ooc_manager.lua
  - EAX*/racial_manager.lua
autonomous: true
requirements:
  - FOUND-02
must_haves:
  truths:
    - "All 27 specs require shared managers from common/eax_shared/"
    - "Per-spec manager files updated to require from common/"
    - "All 27 specs continue to function after refactoring"
  artifacts:
    - path: "EAXDruidBalance/main.lua"
      provides: "Updated to require from common/eax_shared/"
    - path: "EAXWarriorArms/main.lua"
      provides: "Updated to require from common/eax_shared/"
    - (all 27 specs)
  key_links:
    - from: "EAXDruidBalance/main.lua"
      to: "common/eax_shared/interrupt_manager.lua"
      via: "require statement"
      pattern: "require.*eax_shared.*interrupt_manager"
---

<objective>
Refactor all 27 specs to require shared managers from common/eax_shared/ instead of using per-spec duplicates. The per-spec manager files become thin wrappers that require from common/.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/01-foundation/01-foundation-01-PLAN.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update all main.lua files</name>
  <files>
    - EAXDruidBalance/main.lua
    - EAXDruidFeral/main.lua
    - EAXDruidRestoration/main.lua
    - EAXHunterBeastMastery/main.lua
    - EAXHunterMarksmanship/main.lua
    - EAXHunterSurvival/main.lua
    - EAXMageArcane/main.lua
    - EAXMageFire/main.lua
    - EAXMageFrost/main.lua
    - EAXPaladinHoly/main.lua
    - EAXPaladinProtection/main.lua
    - EAXPaladinRetribution/main.lua
    - EAXPriestDiscipline/main.lua
    - EAXPriestHoly/main.lua
    - EAXPriestShadow/main.lua
    - EAXRogueAssassination/main.lua
    - EAXRogueCombat/main.lua
    - EAXRogueSubtlety/main.lua
    - EAXShamanElemental/main.lua
    - EAXShamanEnhancement/main.lua
    - EAXShamanRestoration/main.lua
    - EAXWarlockAffliction/main.lua
    - EAXWarlockDemonology/main.lua
    - EAXWarlockDestruction/main.lua
    - EAXWarriorArms/main.lua
    - EAXWarriorFury/main.lua
    - EAXWarriorProtection/main.lua
  </files>
  <read_first>
    - EAXDruidBalance/main.lua (template - see how managers are currently required)
  </read_first>
  <action>
    Update ALL 27 main.lua files to:
    
    1. Change require statements from local to common/eax_shared/:
    ```lua
    -- BEFORE (per-spec):
    local interrupt_manager = require("interrupt_manager")
    local defensive_manager = require("defensive_manager")
    local encounter_manager = require("encounter_manager")
    local ooc_manager = require("ooc_manager")
    local racial_manager = require("racial_manager")
    
    -- AFTER (shared):
    local interrupt_manager = require("common/eax_shared/interrupt_manager")
    local defensive_manager = require("common/eax_shared/defensive_manager")
    local encounter_manager = require("common/eax_shared/encounter_manager")
    local ooc_manager = require("common/eax_shared/ooc_manager")
    local racial_manager = require("common/eax_shared/racial_manager")
    ```

    2. For each spec folder:
       - Read the main.lua file
       - Find all require statements for manager modules
       - Update to use common/eax_shared/ prefix
       - Write the updated file

    Important: Only change the require paths. Do NOT change any other code in main.lua files.
  </action>
  <acceptance_criteria>
    - All 27 main.lua files updated
    - Each contains require("common/eax_shared/interrupt_manager")
    - Each contains require("common/eax_shared/defensive_manager")
    - Each contains require("common/eax_shared/encounter_manager")
    - Each contains require("common/eax_shared/ooc_manager")
    - Each contains require("common/eax_shared/racial_manager")
  </acceptance_criteria>
  <verify>
    for dir in EAX*/; do
      if ! grep -q "common/eax_shared" "$dir/main.lua" 2>/dev/null; then
        echo "MISSING: $dir"
      fi
    done | head -5</verify>
  <done>All 27 main.lua files require shared managers from common/eax_shared/</done>
</task>

<task type="auto">
  <name>Task 2: Update per-spec manager wrappers</name>
  <files>
    - EAXDruidBalance/interrupt_manager.lua
    - EAXDruidBalance/defensive_manager.lua
    - EAXDruidBalance/encounter_manager.lua
    - EAXDruidBalance/ooc_manager.lua
    - EAXDruidBalance/racial_manager.lua
    - (similar for all 27 specs)
  </files>
  <action>
    For each per-spec manager file, replace with a thin wrapper that re-exports from common/:

    For interrupt_manager.lua:
    ```lua
    -- interrupt_manager.lua
    -- DEPRECATED: Re-exports from common/eax_shared/
    -- Will be removed in future version
    return require("common/eax_shared/interrupt_manager")
    ```

    For defensive_manager.lua:
    ```lua
    -- defensive_manager.lua
    -- DEPRECATED: Re-exports from common/eax_shared/
    -- Will be removed in future version
    return require("common/eax_shared/defensive_manager")
    ```

    For encounter_manager.lua:
    ```lua
    -- encounter_manager.lua
    -- DEPRECATED: Re-exports from common/eax_shared/
    -- Will be removed in future version
    return require("common/eax_shared/encounter_manager")
    ```

    For ooc_manager.lua:
    ```lua
    -- ooc_manager.lua
    -- DEPRECATED: Re-exports from common/eax_shared/
    -- Will be removed in future version
    return require("common/eax_shared/ooc_manager")
    ```

    For racial_manager.lua:
    ```lua
    -- racial_manager.lua
    -- DEPRECATED: Re-exports from common/eax_shared/
    -- Will be removed in future version
    return require("common/eax_shared/racial_manager")
    ```

    Note: The wrapper approach maintains backward compatibility during transition. Any code that still requires the local file will transparently get the shared module.
  </action>
  <acceptance_criteria>
    - All 27 interrupt_manager.lua files updated to wrapper
    - All 27 defensive_manager.lua files updated to wrapper
    - All 27 encounter_manager.lua files updated to wrapper
    - All 27 ooc_manager.lua files updated to wrapper
    - All 27 racial_manager.lua files updated to wrapper
  </acceptance_criteria>
  <verify>
    for dir in EAX*/; do
      for f in interrupt_manager defensive_manager encounter_manager ooc_manager racial_manager; do
        if ! grep -q "common/eax_shared" "$dir/$f.lua" 2>/dev/null; then
          echo "MISSING: $dir$f.lua"
        fi
      done
    done | head -10</verify>
  <done>All per-spec manager files are thin wrappers re-exporting from common/eax_shared/</done>
</task>

<task type="auto">
  <name>Task 3: Verify all specs still function</name>
  <files>
    - EAXDruidBalance/main.lua
    - EAXWarriorArms/main.lua
    - (any file to verify - manual test required)
  </files>
  <action>
    Manual verification check for all 27 specs:

    1. Verify no Lua syntax errors in any main.lua:
    ```bash
    for dir in EAX*/; do
      luac -p "$dir/main.lua" 2>&1 || echo "SYNTAX ERROR: $dir"
    done
    ```

    2. Verify no syntax errors in shared modules:
    ```bash
    luac -p common/eax_shared/*.lua 2>&1 || echo "SYNTAX ERROR in shared"
    ```

    3. Verify all requires resolve:
    - Check that each main.lua can find its required modules
    - Any missing module will cause runtime errors

    Note: Full functional testing requires running each spec in-game. This step only verifies syntax and require paths.

    Report: List any files with syntax errors or missing requires.
  </action>
  <acceptance_criteria>
    - All main.lua files pass luac syntax check
    - All common/eax_shared/*.lua files pass luac syntax check
    - No require statements reference missing files
  </acceptance_criteria>
  <verify>
    luac -p EAXDruidBalance/main.lua 2>&1 && echo "SYNTAX_OK"</verify>
  <done>All 27 specs have valid Lua syntax and require paths</done>
</task>

</tasks>

<verification>
All 27 specs updated to use shared modules. Manual in-game testing required for full verification.
</verification>

<success_criteria>
- All 27 main.lua files require from common/eax_shared/
- All 135 per-spec manager files (5 managers × 27 specs) are updated to wrappers
- No Lua syntax errors in any updated file
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation/01-foundation-03-SUMMARY.md`
</output>
