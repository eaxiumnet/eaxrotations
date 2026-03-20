---
phase: 02-core-combat
plan: 02
type: execute
wave: 2
depends_on:
  - 02-core-combat-01
files_modified:
  - eax_shared/threat_manager.lua
  - EAXWarlockAffliction/main.lua
  - EAXWarlockDemonology/main.lua
  - EAXWarlockDestruction/main.lua
  - EAXPriestShadow/main.lua
  - EAXDruidBalance/main.lua
  - EAXMageArcane/main.lua
  - EAXMageFire/main.lua
  - EAXMageFrost/main.lua
autonomous: true
requirements:
  - COMBAT-03
must_haves:
  truths:
    - "Threat estimation tracks tank threat and warns/fades before threat pull"
    - "All caster and melee specs integrate fade-before-pull threat checks"
  artifacts:
    - path: "eax_shared/threat_manager.lua"
      provides: "Threat estimation with tank tracking and fade warnings"
      min_lines: 100
      exports: ["get_tank_guid", "get_tank_threat", "get_player_threat", "should_fade", "on_combat_log_event"]
    - path: "eax_shared/threat_manager.lua"
      provides: "THREAT_MULTIPLIERS table for all class abilities"
      contains: "THREAT_MULTIPLIERS"
  key_links:
    - from: "eax_shared/threat_manager.lua"
      to: "All 27 spec main.lua files"
      via: "require + on_combat_log_event + should_fade check"
      pattern: "require.*threat_manager"
---

<objective>
Implement threat estimation and fade-before-pull system across all 27 specs. Creates shared threat_manager.lua in eax_shared/ with tank tracking, threat calculation, and fade warning integration.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@eax_shared/interrupt_manager.lua
@EAXWarlockAffliction/main.lua
@EAXWarlockAffliction/utils.lua

# Reference: No existing threat tracking exists in the codebase.
# This module creates it from scratch using combat log events and Sylvanas API.

# Threat in TBC:
# - Tanks generate ~300% threat per damage point (battle stance / defensive stance)
# - Druids in Bear form generate 300% threat
# - Threat cap at ~130-140% of tank's TPS before pull (130% rule for tanks)
# - Players fade at ~90% of tank threat to prevent pulling
# - Threat multipliers per ability type:
#   - Physical abilities: base damage * 1.0 * threat_multiplier
#   - spells: base damage * 1.0 * spell_threat_multiplier * threat_coeff
#   - Heals: healing * 0.5 * threat_multiplier
#   - Warrior Shield Slam: ~1900-2400 threat flat
#   - Warrior Revenge: ~850 threat flat
#   - Warrior Devastate: ~260 threat per application + 30% of damage
#   - Druid Mangle (Bear): ~400-500 threat
#   - Paladin Righteous Fury: 300% healing threat
</context>

<interfaces>
```lua
-- Key Sylvanas API for threat tracking
core.combat_log.add_event_handler(callback_fn) --> register combat log callback
-- Combat log events include: SWING_DAMAGE, RANGE_DAMAGE, SPELL_DAMAGE, SPELL_HEAL, SPELL_AURA_APPLIED, SPELL_AURA_REMOVED
-- event.source = source unit, event.dest = dest unit, event.spell_id, event.amount, event.threat, event.school

core.object_manager.get_player() --> unit
me:get_target() --> unit
me:get_target_of_target() --> unit (who is targeting me)
unit:get_threat_percent(_) --> number (-1 if no threat)
unit:get_threat(_) --> number (raw threat value)
unit:get_raid_index() --> number
unit:get_party_index() --> number
unit:get_name() --> string
unit:get_guid() --> number
unit:get_class() --> number (1=Warrior, 2=Paladin, 3=Hunter, 4=Rogue, 5=Priest, 6=Druid, 7=Shaman, 8=Mage, 9=Warlock, 11=Death Knight)
unit:get_power(power_type) --> number
unit:has_aura_by_name(name) --> boolean

core.get_fps() --> number (not directly useful but for diagnostics)

-- Constants
COMBAT_LOG_THREAT_EVENTS = {
    "SWING_DAMAGE", "RANGE_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE",
    "SPELL_HEAL", "SPELL_PERIODIC_HEAL",
    "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESHED"
}
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Create eax_shared/threat_manager.lua</name>
  <files>eax_shared/threat_manager.lua</files>
  <read_first>
    - eax_shared/interrupt_manager.lua (existing module pattern — use same style)
    - EAXWarlockAffliction/main.lua (combat_log callback registration if any)
  </read_first>
  <action>
    Create `eax_shared/threat_manager.lua` — a shared threat estimation module.

    This module tracks threat across the party/raid to detect when the player is approaching tank threat levels, enabling fade-before-pull protection.

    Module pattern: `return threat_manager` at end.

    Internal state (module-level, NOT global):
    ```lua
    local threat_data = {}       -- guid -> { threat = number, name = string, class = number }
    local tank_guid = nil        -- guid of the detected tank
    local tank_threat = 0        -- current tank threat
    local player_threat = 0     -- current player (me) threat
    local last_event_time = 0
    local fade_warning_issued = false
    local FADE_THRESHOLD = 0.85  -- 85% of tank threat = warning
    local FADE_ACTIVATE_THRESHOLD = 0.95  -- 95% = activate fade
    ```

    Class constants for tank detection:
    ```lua
    local TANK_CLASSES = {
        [1] = true,   -- Warrior (all specs, but Prot priority)
        [6] = true,   -- Druid (Feral tank)
        [2] = true,   -- Paladin (Prot)
        [11] = true,  -- Death Knight
    }
    local CLASS_NAMES = {
        [1] = "warrior", [2] = "paladin", [3] = "hunter", [4] = "rogue",
        [5] = "priest", [6] = "druid", [7] = "shaman", [8] = "mage",
        [9] = "warlock", [11] = "deathknight",
    }
    ```

    Threat multipliers per class/spec (approximations):
    ```lua
    local THREAT_MULTIPLIERS = {
        -- Warrior
        [6544]  = 2.0,   -- Heroic Strike (150% base)
        [6343]  = 1.5,   -- Shield Slam (flat high threat)
        [11585] = 1.0,   -- Devastate
        [6346]  = 1.0,   -- Revenge
        [7386]  = 1.0,   -- Sunder Armor
        -- Druid
        [6795]  = 1.5,   -- Growl (taunt)
        [33878] = 1.5,   -- Mangle (Bear)
        [33987] = 1.0,   -- Lacerate
        [33745] = 1.5,   -- Swipe (Bear)
        -- Paladin
        [20271] = 1.0,   -- Judgement
        [31899] = 1.5,   -- Holy Shield
        [35395] = 1.5,   -- Crusader Strike
        -- General
        [6603]  = 1.0,   -- Attack (auto attack)
    }
    local DEFAULT_THREAT_MULT = 1.0
    ```

    **Main exported functions:**
    ```lua
    -- Initialize the module — register combat log handler and scan party for tank
    -- Call once from main.lua at startup (in on_update or dedicated init function)
    function threat_manager.init(me)
        --> registers combat log handler
        --> scans party/raid for tank
        --> sets tank_guid if found
    end

    -- Main update: call every tick
    -- Returns true if player should fade (too close to tank threat)
    function threat_manager.should_fade(me, target)
        --> returns boolean
    end

    -- Get current tank threat value (0 if no tank found)
    function threat_manager.get_tank_threat()
        --> returns number
    end

    -- Get player estimated threat on current target
    function threat_manager.get_player_threat()
        --> returns number
    end

    -- Get the tank's GUID
    function threat_manager.get_tank_guid()
        --> returns number or nil
    end

    -- Reset state (call on combat leave)
    function threat_manager.reset()
        --> clears threat_data, resets tank_guid, fade_warning_issued
    end

    -- Handle combat log event — call from combat log callback
    -- @param event table (Sylvanas combat log event)
    -- @param me player unit
    function threat_manager.on_combat_log_event(event, me)
        --> updates internal threat_data
        --> detects tank if not yet found
    end
    ```

    **Implementation of threat_manager.init:**
    1. Register combat log handler: `core.combat_log.add_event_handler(function(event) ... end)`
    2. Scan party: `core.object_manager.get_party_members()` → for each member, check if tank class (Warrior, Druid, Paladin, DK) AND has aggro or is targeting the same target as player
    3. If no party, scan raid: `core.object_manager.get_raid_members()`
    4. Set tank_guid = detected tank's guid

    **Implementation of should_fade:**
    1. If no tank found (tank_guid == nil), return false
    2. If tank is dead, return false
    3. If me is not in combat, return false
    4. Get my threat on target: me:get_target():get_threat(_) or 0
    5. Get tank threat: threat_data[tank_guid].threat or 0
    6. If tank_threat > 0 and my_threat > (tank_threat * FADE_THRESHOLD), return true
    7. Otherwise return false

    **Implementation of on_combat_log_event:**
    1. Extract: event.source (unit), event.dest (unit), event.spell_id, event.amount (damage/heal), event.threat
    2. If event.source == me → update player threat estimate
    3. If event.source is a tank class → update tank threat
    4. Use unit:get_threat(_) on the target to get current threat values
    5. Store in threat_data[guid]

    **Tank detection logic:**
    Priority order:
    1. Party/raid member with tank class AND currently has threat on the player's target
    2. Party/raid member with tank class AND in defensive stance/aura
    3. Warrior with Shield equipped
    4. Druid in Bear Form (has Mangle/Maul ability)
    Use `pcall` for all API calls to avoid crashes on nil/unavailable.

    **Fade action:**
    The should_fade() function returns boolean. Each spec's main.lua calls it and issues a `/script Fade()` macro or equivalent when true. This is a Sylvanas API call — find the equivalent.

    Include a helper for fade:
    ```lua
    function threat_manager.try_fade(me)
        if not me:is_in_combat() then return false end
        -- Use Sylvanas API to issue /fade
        -- Try: core.input.send_key("FADE_KEY") or equivalent
        -- If no direct API, use: pcall(core.input.macro, "/cast Fade")
        return pcall(function()
            core.input.cast_spell_by_name("Fade")
        end)
    end
    ```
  </action>
  <acceptance_criteria>
    - File exists at eax_shared/threat_manager.lua
    - Contains `return threat_manager` at end
    - Exports: `init`, `should_fade`, `get_tank_threat`, `get_player_threat`, `get_tank_guid`, `reset`, `on_combat_log_event`
    - THREAT_MULTIPLIERS table present with all major tank abilities
    - TANK_CLASSES correctly identifies Warrior, Druid, Paladin, DK
    - All API calls wrapped in pcall for safety
    - Returns false from should_fade when no tank found
  </acceptance_criteria>
  <verify>
    grep -l "return threat_manager" eax_shared/threat_manager.lua && grep -l "should_fade" eax_shared/threat_manager.lua && echo "THREAT_MANAGER_OK"
  </verify>
  <done>eax_shared/threat_manager.lua created with tank tracking, threat calculation, and fade protection</done>
</task>

<task type="auto">
  <name>Task 2: Wire threat_manager into all 27 spec main.lua files</name>
  <files>
    EAXWarlockAffliction/main.lua
    EAXWarlockDemonology/main.lua
    EAXWarlockDestruction/main.lua
    EAXPriestShadow/main.lua
    EAXPriestDiscipline/main.lua
    EAXPriestHoly/main.lua
    EAXDruidBalance/main.lua
    EAXDruidFeral/main.lua
    EAXDruidRestoration/main.lua
    EAXMageArcane/main.lua
    EAXMageFire/main.lua
    EAXMageFrost/main.lua
    EAXHunterBeastMastery/main.lua
    EAXHunterMarksmanship/main.lua
    EAXHunterSurvival/main.lua
    EAXRogueAssassination/main.lua
    EAXRogueCombat/main.lua
    EAXRogueSubtlety/main.lua
    EAXWarriorArms/main.lua
    EAXWarriorFury/main.lua
    EAXWarriorProtection/main.lua
    EAXPaladinHoly/main.lua
    EAXPaladinProtection/main.lua
    EAXPaladinRetribution/main.lua
    EAXShamanElemental/main.lua
    EAXShamanEnhancement/main.lua
    EAXShamanRestoration/main.lua
  </files>
  <read_first>
    - EAXWarlockAffliction/main.lua (lines 1-80 for require placement)
    - EAXWarlockAffliction/main.lua (existing rotation loop for placement)
  </read_first>
  <action>
    For EACH of the 27 spec main.lua files, add threat_manager integration.

    **Step 1: Add require near the other shared module requires (after defensive_manager, encounter_manager):**
    ```lua
    ---@type threat_manager
    local threat_manager = require("eax_shared/threat_manager")
    ```

    **Step 2: Add init call in the existing init/resolve_spells function or at startup:**
    ```lua
    -- Initialize threat tracking
    threat_manager.init(me)
    ```

    **Step 3: Add fade check at the START of the main damage rotation (before any damage spells):**
    ```lua
    -- Threat fade protection — don't pull aggro from tank
    local current_target = me:get_target()
    if threat_manager.should_fade(me, current_target) then
        threat_manager.try_fade(me)
        return true
    end
    ```

    Placement: Insert this check right after:
    - Out-of-combat (OOC) check
    - Defensive/healing check
    - Interrupt check
    BEFORE the main damage rotation

    **IMPORTANT NOTES:**
    - Use `pcall` to wrap the `should_fade` call — threat_manager is new and could have bugs
    - Only run threat check when IN COMBAT: `if me:is_in_combat() then ...`
    - Melee specs (Warrior, Rogue, Druid Feral): place check AFTER the opener abilities that build initial threat
    - Healers (Priest Holy, Priest Disc, Druid Resto, Paladin Holy, Shaman Resto): still check threat — healers generate threat from heals too!
    - Tank specs (Warrior Prot, Paladin Prot): skip threat fade — they're supposed to have threat
    - Hunter specs: skip fade (pets don't pull threat from main tank)

    **Exclusions (no fade check needed):**
    - EAXWarriorProtection/main.lua — tank, not DPS
    - EAXDruidFeral/main.lua — tank, not DPS (but verify the spec is Feral DPS, not Feral Tank)
    - Hunters (all 3): pets can pull but the main bot doesn't need to fade

    **For the 5 specs that need fade (high-DPS priority):**
    EAXWarriorArms/main.lua, EAXWarriorFury/main.lua, EAXWarlockAffliction/main.lua, EAXWarlockDemonology/main.lua, EAXWarlockDestruction/main.lua, EAXPriestShadow/main.lua, EAXDruidBalance/main.lua, EAXMageArcane/main.lua, EAXMageFire/main.lua, EAXMageFrost/main.lua

    Actually: ALL 27 specs should have threat tracking enabled (init called), but only specs with significant threat output need the fade check. Include the fade check in ALL non-tank specs.

    Use a sed-style approach: For each file, find the line after the interrupt_manager.try_interrupt check and add the fade block.
  </action>
  <acceptance_criteria>
    - threat_manager.init called in at least 20 of the 27 specs
    - threat_manager.should_fade called in at least 15 of the 27 specs
    - Tank specs (Warrior Prot, Paladin Prot) do NOT call should_fade
    - All requires use proper ---@type annotations
  </acceptance_criteria>
  <verify>
    grep -l "threat_manager.init\|require.*threat_manager" EAXWarlockAffliction/main.lua EAXWarlockDemonology/main.lua EAXPriestShadow/main.lua EAXDruidBalance/main.lua EAXMageArcane/main.lua EAXWarriorArms/main.lua EAXWarriorFury/main.lua EAXWarriorProtection/main.lua | grep -v "EAXWarriorProtection" | wc -l
  </verify>
  <done>threat_manager integrated into all 27 specs for threat fade protection</done>
</task>

</tasks>

<verification>
- eax_shared/threat_manager.lua exists with all exported functions
- threat_manager.init called in at least 20 of 27 specs
- threat_manager.should_fade checked in at least 15 of 27 specs
- Tank specs excluded from fade check
- All API calls wrapped in pcall
</verification>

<success_criteria>
- threat_manager.lua created with combat log handler, tank detection, and threat calculation
- All 27 specs require threat_manager
- Non-tank specs check should_fade before main damage rotation
- Tank specs skip the fade check
- No crashes from threat_manager API calls (all wrapped in pcall)
</success_criteria>

<output>
After completion, create `.planning/phases/02-core-combat/02-core-combat-02-SUMMARY.md`
</output>
