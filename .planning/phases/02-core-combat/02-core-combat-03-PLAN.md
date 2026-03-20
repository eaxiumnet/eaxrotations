---
phase: 02-core-combat
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/interrupt_manager.lua
  - eax_shared/encounter_manager.lua
autonomous: true
requirements:
  - INTER-01
  - INTER-02
  - INTER-03
  - ENCOUNT-01
  - ENCOUNT-02
  - ENCOUNT-03
  - ENCOUNT-04
must_haves:
  truths:
    - "Interrupt manager skips casts with <200ms remaining"
    - "Interrupt target selection prioritizes healing over CC over offensive"
    - "Boss database covers all TBC encounters with correct policies"
    - "AoE safe detection prevents face-pull in dungeons and raids"
    - "Burn phase cooldown hold detected and respected by rotations"
    - "Movement phase awareness implemented for mobile boss encounters"
  artifacts:
    - path: "eax_shared/interrupt_manager.lua"
      provides: "Min-cast-time check, healing priority, expanded spell weights"
      contains: "MIN_CAST_TIME_MS|HEAL_PRIORITY|should_interrupt_target"
    - path: "eax_shared/encounter_manager.lua"
      provides: "AoE safe detection, movement phase, burn phase policies"
      contains: "get_movement_phase|is_aoe_safe|get_aoe_safe_radius"
  key_links:
    - from: "eax_shared/interrupt_manager.lua"
      to: "All 27 spec main.lua"
      via: "try_interrupt already calls should_interrupt and get_priority"
    - from: "eax_shared/encounter_manager.lua"
      to: "All 27 spec main.lua"
      via: "get_policy already called in rotation loop"
---

<objective>
Improve interrupt manager (min-cast-time, target priority, spell weights) and expand encounter manager (AoE safe, movement phase, burn phase) in eax_shared/. No spec main.lua changes needed — these are shared module improvements.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@eax_shared/interrupt_manager.lua
@eax_shared/encounter_manager.lua

# Reference: Existing interrupt_manager.lua has:
# - INTERRUPT_SPELLS by class (9 classes)
# - DANGEROUS_SPELLS table (spell_id -> priority weight)
# - should_interrupt(target) - checks casting + interruptable
# - get_priority(target) - returns DANGEROUS_SPELLS[spell_id] or 25
# - try_interrupt(me, target, class_name, utils) - tries interrupt spells

# Reference: Existing encounter_manager.lua has:
# - BOSS_DB with all TBC dungeon/raid bosses
# - DEFAULT_POLICY with 12 fields
# - get_policy(me) - returns current encounter policy
# - is_in_raid(), is_instanced()
</context>

<interfaces>
```lua
-- Key Sylvanas API for these improvements
target:is_casting_spell() --> boolean
target:get_active_spell_id() --> number
target:get_spell_cast_time_remaining() --> number (ms) -- for min-cast-time check
target:get_spell_cast_time() --> number (ms) -- total cast time
target:is_channeling_spell() --> boolean
target:get_channel_cast_time_remaining() --> number (ms) -- for channel checks
target:get_target() --> unit -- who is the casting target (for heal priority)
target:get_class() --> number -- class ID for interrupt target selection
unit:get_health_percentage() --> number -- for healer detection
core.object_manager.get_enemies_in_range(unit, yards) --> table of units
core.object_manager.get_units_in_range(unit, yards) --> table of units
core.navigation.is_moving() --> boolean -- if player is moving
core.navigation.get_distance_to(unit) --> number -- yards to target
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Improve interrupt_manager.lua — min-cast-time + target priority</name>
  <files>eax_shared/interrupt_manager.lua</files>
  <read_first>
    - eax_shared/interrupt_manager.lua (full file — modify in place)
  </read_first>
  <action>
    Improve `eax_shared/interrupt_manager.lua` with three changes:

    **Change A — Add minimum cast time check (INTER-02):**

    Find the `should_interrupt` function and add a check:
    ```lua
    -- Minimum cast time remaining to bother interrupting (ms)
    local MIN_CAST_TIME_MS = 200

    function interrupt_manager.should_interrupt(target)
        if not target then return false end
        if not target:is_casting_spell() and not target:is_channeling_spell() then return false end
        if target:is_casting_spell() and not target:is_active_spell_interruptable() then return false end
        
        -- INTER-02: Don't interrupt if cast finishes in < 200ms
        -- (server latency means it will land before we can react)
        local remaining_ms = 0
        if target:is_casting_spell() then
            local ok_rem, rem = pcall(function() return target:get_spell_cast_time_remaining() end)
            if ok_rem and rem then remaining_ms = rem end
        elseif target:is_channeling_spell() then
            local ok_rem, rem = pcall(function() return target:get_channel_cast_time_remaining() end)
            if ok_rem and rem then remaining_ms = rem end
        end
        if remaining_ms > 0 and remaining_ms < MIN_CAST_TIME_MS then
            return false
        end
        
        return true
    end
    ```

    **Change B — Expand DANGEROUS_SPELLS (INTER-01):**

    Add missing dangerous spell IDs from TBC encounters. Extend the existing DANGEROUS_SPELLS table:

    ```lua
    local DANGEROUS_SPELLS = {
        -- [existing entries... keep them all]

        -- Healing spells (Priority 90-95 — interrupt healers first)
        -- Prayer of Healing (33076), Chain Heal (25423), Holy Light (27135), Flash of Light (19943)
        -- Greater Heal (25314), Nourish (5040), Healing Touch (26980), Regrowth (20787)
        -- Nature's Swiftness healing (well, that's a proc)
        
        -- Dungeon/raid dangerous casts (from boss databases)
        -- Shadow Priest Vampiric Touch (34917) — high priority
        -- Warlock Shadow Bolt (27209), Conflagrate (27210), Shadowburn (29722)
        -- Mage Pyroblast (27213), Fireball (27070), Frostbolt (25306)
        -- Shaman Chain Lightning (25442), Lava Burst (60099), Lightning Bolt (25448)
        
        -- Crowd Control that should NOT be interrupted (stun/incapacitate)
        -- Polymorph, Hibernate, Shackle, Fear, etc. — these have LOW priority
        -- The interrupt manager only deals with DAMAGING casts
        
        -- Boss encounters from TBC:
        -- Magtheridon: Shadow Nova (30511) - 92 priority (raid healer interrupt)
        -- Kael'thas: Fireball (27070), Arcane Missiles (31389), Phoenix (36718)
        -- Lady Vashj: Tainted Core (38194) - 95 (must interrupt to prevent raid damage)
        -- Void Reaver: Pounding (26555) - 88 (melee range)
        -- High Astromancer Solarian: Wrath of the Titans (28211) - 90
        -- Prince Malchezaar: Infernal (砸不烂) - skip, not cast
        -- Brutallus: Fel Stomp (39192) - 88
        -- M'uru: Void Blast (36092) - 95
        -- Kil'jaeden: Flame Spike (45742), Shadow Spike (46672) - 95
        
        -- Healer spells by class (for target priority)
        -- Priest: Greater Heal (25314, 25210, 2060, 2050, 605, 1094) = 80 priority
        -- Druid: Nourish (5040), Healing Touch (26980, 21865, 17401, 12999, 1126, 5189, 5188, 5187), Regrowth (20787, 9634, 774), Rejuvenation (26981, 9849, 5502, 7745, 1096, 2090) = 75-80
        -- Paladin: Holy Light (27135, 25263, 19939, 10439, 635, 19943), Flash of Light (19943, 10291, 10290, 10289, 15417) = 80
        -- Shaman: Chain Heal (25423, 25419, 10960, 7999, 6123, 6124), Healing Wave (26981, 25396, 25391, 8370, 25357, 25396, 25908), Lesser Healing Wave (7788, 10466) = 80
        -- Mage: (mostly damage, heal only with talents)
    }
    ```

    Actually, add these specific spell IDs to the existing DANGEROUS_SPELLS table:
    - [30511] = 92 (Magtheridon Shadow Nova)
    - [36092] = 95 (M'uru Void Blast)
    - [45742] = 95 (Kil'jaeden Flame Spike)
    - [34917] = 90 (Vampiric Touch — shadow priest)
    - [27135] = 92 (Holy Light rank 13)
    - [25314] = 88 (Greater Heal rank 8)
    - [25423] = 88 (Chain Heal rank 4)
    - [45770] = 92 (Kil'jaeden Shadow Spike)
    - [26555] = 85 (Void Reaver Pounding)

    **Change C — Add interrupt target priority function (INTER-03):**

    Add a new function that picks the best interrupt target from nearby enemies:
    ```lua
    -- Class IDs for healer detection
    local HEALER_CLASSES = {
        [5] = true,   -- Priest
        [6] = true,   -- Druid
        [2] = true,   -- Paladin
        [7] = true,   -- Shaman
    }

    function interrupt_manager.get_best_interrupt_target(me)
        --> returns unit or nil (best target to interrupt)
        
        -- Implementation:
        -- 1. Get all enemies in range (core.object_manager.get_enemies_in_range or get_units_in_range)
        -- 2. Filter: only targets that are casting/channeling and interruptable
        -- 3. Score each:
        --    - is casting a healer spell (targeting a player)? +50 points
        --    - DANGEROUS_SPELLS[spell_id] priority score
        --    - is_casting() and not too short (< MIN_CAST_TIME_MS) = eligible
        -- 4. Return highest-scoring eligible target
        -- 5. Use pcall for all API calls
    end

    function interrupt_manager.should_interrupt_target(target)
        --> returns boolean, number (should_interrupt, priority_score)
        --> Second return is the priority score for comparison
    end
    ```

    **Change D — Add healing spell priority to DANGEROUS_SPELLS:**

    Add these healer spell IDs with high priority:
    ```lua
    -- Healing spells (interrupted by priority)
    [27135] = 90,  -- Holy Light rank 13
    [25314] = 88,  -- Greater Heal rank 8
    [25423] = 88,  -- Chain Heal rank 4
    [5040]  = 85,  -- Nourish
    [26980] = 85,  -- Healing Touch rank 13
    [20787] = 80,  -- Regrowth rank 9
    [26981] = 80,  -- Rejuvenation rank 13
    [34917] = 90,  -- Vampiric Touch
    ```
  </action>
  <acceptance_criteria>
    - MIN_CAST_TIME_MS = 200 present in interrupt_manager.lua
    - should_interrupt returns false when cast has < 200ms remaining
    - DANGEROUS_SPELLS contains at least 5 new healing/boss spell IDs
    - get_best_interrupt_target exported and returns a unit
    - HEALER_CLASSES table present
    - All pcall wrappers on API calls
  </acceptance_criteria>
  <verify>
    grep "MIN_CAST_TIME_MS" eax_shared/interrupt_manager.lua && grep "get_best_interrupt_target" eax_shared/interrupt_manager.lua && grep "HEALER_CLASSES" eax_shared/interrupt_manager.lua && echo "INTERRUPT_IMPROVED"
  </verify>
  <done>interrupt_manager.lua improved with min-cast-time, healing priority, and best-target selection</done>
</task>

<task type="auto">
  <name>Task 2: Expand encounter_manager.lua — AoE safe, movement phase, burn phase</name>
  <files>eax_shared/encounter_manager.lua</files>
  <read_first>
    - eax_shared/encounter_manager.lua (full file — modify in place)
  </read_first>
  <action>
    Expand `eax_shared/encounter_manager.lua` with encounter awareness improvements:

    **Change A — Add AoE safe detection (ENCOUNT-02):**

    The encounter_manager already has `aoe_safe` in the policy. Add a helper function to detect AoE:
    ```lua
    -- AoE detection — scan for nearby enemies
    -- Returns estimated number of hostile targets within range of player
    local function count_nearby_enemies(me, range_yards)
        local count = 0
        local enemies = core.object_manager.get_units_in_range(me, range_yards or 10)
        if enemies then
            for _, unit in ipairs(enemies) do
                if unit and unit:is_valid() and not unit:is_dead() and me:can_attack(unit) then
                    count = count + 1
                end
            end
        end
        return count
    end

    -- Override aoe_safe if too many enemies nearby (face-pull detection)
    function encounter_manager.is_aoe_safe(me)
        local policy = encounter_manager.get_policy(me)
        if not policy.aoe_safe then
            local nearby = count_nearby_enemies(me, 10)
            if nearby > 3 then
                return false  -- Multiple targets, AoE encounter
            end
        end
        return true
    end
    ```

    **Change B — Add movement phase awareness (ENCOUNT-04):**

    Add movement phase detection:
    ```lua
    -- Movement phase encounters
    -- These bosses have movement phases where the player should move/pre-position:
    local MOVEMENT_PHASE_BOSSES = {
        ["prince malchezaar"]   = { min_range = 20 },
        ["gruul the dragonkiller"] = { min_range = 18 },
        ["magtheridon"]         = { min_range = 15 },
        ["alar"]                = { min_range = 20 },
        ["void reaver"]         = { min_range = 20 },
        ["high astromancer solarian"] = { min_range = 20 },
        ["teron gorefiend"]     = { aoe_safe = false },  -- shadows move
        ["illidan stormrage"]   = { movement_phase = true },
        ["lady vashj"]          = { movement_phase = true },
        ["brutallus"]          = { movement_phase = true },
        ["felmyst"]            = { movement_phase = true },
    }

    -- Check if current encounter has a movement phase
    function encounter_manager.is_movement_phase(me)
        local policy = encounter_manager.get_policy(me)
        if not policy or not policy.encounter_id then return false end
        local entry = MOVEMENT_PHASE_BOSSES[policy.encounter_id]
        if entry and entry.movement_phase then
            -- Check if player is currently moving
            local ok_moving, is_moving = pcall(function() return core.navigation.is_moving() end)
            if ok_moving and is_moving then
                return true
            end
            -- Check if boss is at min_range
            local ok_dist, dist = pcall(function()
                return core.navigation.get_distance_to(me:get_target())
            end)
            if ok_dist and dist and policy.min_range and dist < policy.min_range then
                return true
            end
        end
        return false
    end

    -- Get minimum range for current encounter
    function encounter_manager.get_min_range(me)
        local policy = encounter_manager.get_policy(me)
        if policy and policy.min_range then
            return policy.min_range
        end
        return nil
    end
    ```

    **Change C — Add burn phase cooldown awareness (ENCOUNT-03):**

    Add burn phase detection:
    ```lua
    -- Burn phase encounters — hold cooldowns until 20-30% HP
    local BURN_PHASE_BOSSES = {
        ["gruul the dragonkiller"] = { burn_until_pct = 0.30 },
        ["magtheridon"]            = { burn_until_pct = 0.35 },
        ["selin fireheart"]        = { burn_until_pct = 0.30 },
        ["the curator"]            = { burn_until_pct = 0.15 },
        ["brutallus"]             = { burn_until_pct = 0.30 },
        ["m'uru"]                 = { burn_until_pct = 0.20 },
        ["kal'jaeden"]            = { burn_until_pct = 0.30 },
        ["teron gorefiend"]        = { burn_until_pct = 0.30 },
        ["gurtogg bloodboil"]     = { burn_until_pct = 0.25 },
    }

    -- Check if player should hold cooldowns for burn phase
    -- @param me player unit
    -- @return boolean, number (hold_cds, burn_until_pct or 0)
    function encounter_manager.should_hold_cooldowns(me)
        local policy = encounter_manager.get_policy(me)
        if not policy then return false, 0 end
        if not policy.hold_cooldowns then return false, 0 end
        
        -- Check target HP
        local target = me:get_target()
        if not target or not target:is_valid() then return false, 0 end
        
        local hp_pct = target:get_health_percentage() / 100
        
        -- Get burn threshold for this boss
        local burn_entry = BURN_PHASE_BOSSES[policy.encounter_id]
        local burn_until_pct = burn_entry and burn_entry.burn_until_pct or 0.30
        
        if hp_pct > burn_until_pct then
            return true, burn_until_pct
        end
        return false, burn_until_pct
    end

    -- Get burn phase target HP percentage
    function encounter_manager.get_burn_threshold(encounter_id)
        local entry = BURN_PHASE_BOSSES[encounter_id]
        return entry and entry.burn_until_pct or 0.30
    end
    ```

    **Change D — Expand BOSS_DB with missing encounters (ENCOUNT-01):**

    Add missing TBC encounters. The existing BOSS_DB is comprehensive but check for gaps:

    Check for missing entries and add if not present (grep to verify before adding):
    ```bash
    grep -i "brutallus\|felmyst\|eredar twins\|m'uru\|kil'jaeden" eax_shared/encounter_manager.lua
    ```
    If found, they're already there. If not, add them.

    Also add Sunwell Plateau entries if missing:
    ```lua
    -- Sunwell Plateau (Phase 3 TBC)
    ["brutallus"]   = { is_boss=true, burn_phase=true, tank_damage_heavy=true, hold_cooldowns=true },
    ["felmyst"]     = { is_boss=true, raid_aoe_heavy=true, avoid_close_range=true, force_dispel=true },
    ["eredar twins"]= { is_boss=true, raid_aoe_heavy=true, force_decurse=true },
    ["m'uru"]       = { is_boss=true, raid_aoe_heavy=true, healer_mana_call=true, hold_cooldowns=true, aoe_safe=false },
    ["kil'jaeden"]  = { is_boss=true, hold_cooldowns=true, avoid_close_range=true, pet_follow=true, disable_pet_attack=true, raid_aoe_heavy=true, healer_mana_call=true },
    ```
  </action>
  <acceptance_criteria>
    - encounter_manager.lua contains `is_aoe_safe`, `is_movement_phase`, `should_hold_cooldowns`, `get_min_range`
    - AoE safe detection checks nearby enemy count > 3
    - Movement phase detection uses core.navigation.is_moving()
    - Burn phase uses target HP percentage check
    - Sunwell Plateau bosses added to BOSS_DB
    - All API calls wrapped in pcall
  </acceptance_criteria>
  <verify>
    grep "is_movement_phase\|should_hold_cooldowns\|is_aoe_safe\|brutallus" eax_shared/encounter_manager.lua && echo "ENCOUNTER_EXPANDED"
  </verify>
  <done>encounter_manager.lua expanded with AoE safe, movement phase, burn phase, and Sunwell bosses</done>
</task>

</tasks>

<verification>
- interrupt_manager.lua has MIN_CAST_TIME_MS = 200 check
- interrupt_manager.lua has get_best_interrupt_target exported
- interrupt_manager.lua has HEALER_CLASSES table
- encounter_manager.lua has is_movement_phase, should_hold_cooldowns, is_aoe_safe
- Sunwell bosses in BOSS_DB
- No syntax errors introduced (luac -p on both files)
</verification>

<success_criteria>
- interrupt_manager.lua: should_interrupt returns false for <200ms remaining casts
- interrupt_manager.lua: get_best_interrupt_target returns best healer/interrupt target
- interrupt_manager.lua: All 9 class interrupt spell lists intact
- encounter_manager.lua: AoE safe detection active for dungeon encounters
- encounter_manager.lua: Movement phase detected and surfaced
- encounter_manager.lua: Burn phase holds cooldowns until threshold HP
- encounter_manager.lua: Sunwell Plateau boss entries added
- Both files pass luac -p syntax check
</success_criteria>

<output>
After completion, create `.planning/phases/02-core-combat/02-core-combat-03-SUMMARY.md`
</output>
