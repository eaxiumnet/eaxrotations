---
phase: 02-core-combat
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - eax_shared/dot_manager.lua
  - EAXWarlockAffliction/main.lua
  - EAXWarlockDemonology/main.lua
  - EAXWarlockDestruction/main.lua
  - EAXPriestShadow/main.lua
  - EAXDruidBalance/main.lua
  - EAXDruidRestoration/main.lua
  - EAXMageFire/main.lua
autonomous: true
requirements:
  - COMBAT-02
  - COMBAT-04
must_haves:
  truths:
    - "DoT-casting specs never clip the final tick of any DoT"
    - "Mana conservator uses potions proactively and times Evocation correctly"
  artifacts:
    - path: "eax_shared/dot_manager.lua"
      provides: "DoT clip prevention with safe refresh thresholds"
      min_lines: 120
      exports: ["can_refresh_dot", "get_safe_refresh_ms"]
    - path: "eax_shared/mana_manager.lua"
      provides: "Proactive mana management for casters"
      min_lines: 80
      exports: ["should_use_potion", "should_evocate", "get_mana_cost"]
    - path: "eax_shared/threat_manager.lua"
      provides: "Threat estimation with tank tracking"
      min_lines: 100
      exports: ["get_tank_threat", "get_player_threat", "should_fade"]
  key_links:
    - from: "eax_shared/dot_manager.lua"
      to: "All caster spec main.lua files"
      via: "require statement"
      pattern: "require.*dot_manager"
    - from: "eax_shared/threat_manager.lua"
      to: "All 27 spec main.lua files"
      via: "require + fade check in rotation"
      pattern: "require.*threat_manager.*should_fade"
---

<objective>
Implement DoT clip prevention across all 6 caster specs (Aff/Demo/Destro, Shadow Priest, Balance Druid, Restoration Druid, Fire Mage) and proactive mana management for casters. Creates shared dot_manager.lua and mana_manager.lua in eax_shared/.
</objective>

<execution_context>
@C:/Users/Support/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@eax_shared/interrupt_manager.lua
@EAXWarlockAffliction/main.lua
@EAXWarlockAffliction/spells.lua
@EAXPriestShadow/main.lua
@EAXPriestShadow/spells.lua
@EAXDruidBalance/main.lua
@EAXDruidBalance/spells.lua
@EAXDruidRestoration/main.lua
@EAXDruidRestoration/spells.lua
@EAXMageFire/main.lua
@EAXDruidBalance/mana_conservator.lua

# Reference data from simc profiles:
# - Moonfire (rank 13, 26988): 4 ticks × 3s = 12s duration
# - Insect Swarm (rank 6, 27013): 6 ticks × 2s = 12s duration
# - Corruption (rank 10, 27216): 6 ticks × 3s = 18s duration
# - Immolate (rank 13, 27215): 8 ticks × 2s = 16s duration
# - SW:Pain (rank 12, 25368): 6 ticks × 3s = 18s duration
# - Devouring Plague (rank 4, 29406): 5 ticks × 3s = 15s duration
# - Curse of Agony (rank 9, 27218): 10 ticks × 2s = 20s duration
# - Siphon Life (rank 8, 25467): 15s duration
# - Unstable Affliction (rank 5, 30459): 15s duration
# - Faerie Fire (rank 5, 26993): 5 min duration (never clip)
# - Hurricane: channeled, no tick clipping concern
# - Frost Fever (Death Knight): 2 ticks × 3s = 6s (Phase 3)
# - Blood Plague (Death Knight): 3 ticks × 3s = 9s (Phase 3)
</context>

<interfaces>
<!-- Key Sylvanas API used throughout -->
```lua
core.time() --> number (seconds)
core.object_manager.get_party_members() --> table of units
core.object_manager.get_raid_members() --> table of units
me:get_target() --> unit
me:get_power(power_type) --> number
me:get_max_power(power_type) --> number
target:get_threat(_) --> number (threat on this target)
target:get_threat_or_highest_threat_on_target() --> number
target:is_casting_spell() --> boolean
target:get_active_spell_id() --> number
target:get_spell_cast_time_remaining() --> number (ms)
unit:get_threat(_) --> number
unit:get_raid_index() --> number
unit:get_party_index() --> number
unit:get_class() --> number
core.spell_book.is_usable_spell(spell_id) --> boolean
core.spell_book.get_spell_cooldown(spell_id) --> number
core.spell_book.get_spell_cast_time(spell_id) --> number (ms)
core.inventory.get_item_count(item_id) --> number
core.input.use_item(item_id) --> boolean
```

TBC power types: 0 = Mana, 1 = Rage, 3 = Energy, 4 = Runic Power
```

<tasks>

<task type="auto">
  <name>Task 1: Create eax_shared/dot_manager.lua</name>
  <files>eax_shared/dot_manager.lua</files>
  <read_first>
    - EAXWarlockAffliction/main.lua (lines 203-209: existing should_refresh_debuff)
    - EAXDruidBalance/main.lua (lines 267-299: existing try_moonfire/try_insect_swarm)
    - EAXPriestShadow/main.lua (existing SW:P and DP refresh logic)
  </read_first>
  <action>
    Create `eax_shared/dot_manager.lua` — a shared DoT clip prevention module.

    The module provides safe refresh logic that NEVER clips the final tick. The key insight: in TBC Classic, server-side DoT application means the pending cast takes ~(cast_time + latency + GCD) seconds before the new DoT replaces the old one. We must only refresh when remaining_ms < (pending_cast_time + latency_buffer).

    Module pattern: `return dot_manager` at end. Use local functions internally.

    DO NOT use pending cast state tracking (each spec has its own pending cast system). Instead, use a pure remaining_ms check against safe thresholds:

    GCD_TBC = 1500 (ms) — TBC Global Cooldown
    LATENCY_BUFFER = 500 (ms) — network round-trip estimate
    CAST_TIME_BUFFER = (cast_time_ms or 0) + GCD_TBC + LATENCY_BUFFER
    SAFE_REFRESH_THRESHOLD = CAST_TIME_BUFFER

    NEVER refresh if remaining_ms >= CAST_TIME_BUFFER. This guarantees no clip.

    Exported constants and functions:
    ```lua
    local dot_manager = {}

    -- DoT duration table (spell_id -> duration_ms)
    -- From simc reference data
    dot_manager.DOT_DURATIONS = {
        [26988] = 12000,  -- Moonfire rank 13
        [27013] = 12000,  -- Insect Swarm rank 6
        [27216] = 18000,  -- Corruption rank 10
        [27215] = 16000,  -- Immolate rank 13
        [25368] = 18000,  -- SW:Pain rank 12
        [29406] = 15000,  -- Devouring Plague rank 4
        [27218] = 20000,  -- Curse of Agony rank 9
        [25467] = 15000,  -- Siphon Life rank 8
        [30459] = 15000,  -- Unstable Affliction rank 5
        [26993] = 300000, -- Faerie Fire rank 5 (5 min - never clip)
        [25367] = 18000,  -- Holy Fire (Priest)
        [25423] = 12000,  -- Shadow Weaving (Shadow Priest proc)
        [16918] = 12000,  -- Curse of Weakness (Warlock)
        [27200] = 24000,  -- Curse of Elements
    }

    -- Get the safe refresh threshold in ms for a given spell_id
    -- Returns the minimum remaining duration below which it's safe to refresh
    function dot_manager.get_safe_refresh_ms(spell_id)
        --> returns number (ms)
    end

    -- Check if a DoT on target can be safely refreshed
    -- Uses target:get_debuff_remaining_ms(ids) from utils if available,
    -- otherwise returns false (let spec's own logic handle it)
    -- @param target game_object
    -- @param debuff_ids table of spell IDs
    -- @param spell_id number (the spell being considered for refresh)
    -- @param get_debuff_remaining_ms function (from utils or equivalent)
    -- @return boolean true = safe to refresh, false = too early
    function dot_manager.can_refresh_dot(target, debuff_ids, spell_id, get_debuff_remaining_ms_fn)
        --> returns boolean
    end

    -- Get pending cast timeout for a spell (for pending cast state)
    -- This is the time window during which we assume a cast is "in flight"
    -- Cast time + GCD + latency buffer
    function dot_manager.get_pending_timeout_ms(spell_id)
        --> returns number (ms)
    end

    return dot_manager
    ```

    Implementation of `can_refresh_dot`:
    1. If get_debuff_remaining_ms_fn is nil, return false
    2. Get remaining_ms = get_debuff_remaining_ms_fn(target, debuff_ids)
    3. If remaining_ms <= 0, return true (DoT is gone)
    4. Get threshold = dot_manager.get_safe_refresh_ms(spell_id)
    5. Return remaining_ms < threshold

    Implementation of `get_safe_refresh_ms`:
    - Lookup DOT_DURATIONS[spell_id]
    - If not found, default to 3000ms (generous for unknown DoTs)
    - Cap at min(duration * 0.3, 3000) — never refresh before 30% of duration remains
    - Add 1500ms (GCD) as absolute minimum
    - Return max(remaining_threshold, 1500)
  </action>
  <acceptance_criteria>
    - File exists at eax_shared/dot_manager.lua
    - Contains `return dot_manager` at end
    - Exports: `can_refresh_dot`, `get_safe_refresh_ms`, `get_pending_timeout_ms`
    - DOT_DURATIONS table has all DoT spell IDs from simc reference
    - `can_refresh_dot` returns false when remaining_ms >= threshold
    - Faerie Fire (26993) has 300000ms duration — never clips
  </acceptance_criteria>
  <verify>
    grep -l "return dot_manager" eax_shared/dot_manager.lua && grep -l "DOT_DURATIONS" eax_shared/dot_manager.lua && echo "DOT_MANAGER_OK"
  </verify>
  <done>eax_shared/dot_manager.lua exports can_refresh_dot with safe thresholds from simc data</done>
</task>

<task type="auto">
  <name>Task 2: Create eax_shared/mana_manager.lua</name>
  <files>eax_shared/mana_manager.lua</files>
  <read_first>
    - EAXDruidBalance/mana_conservator.lua (existing mana system to extend)
    - EAXMageFire/main.lua (existing mana management patterns)
    - EAXWarlockAffliction/main.lua (Life Tap + soul shard logic)
  </read_first>
  <action>
    Create `eax_shared/mana_manager.lua` — proactive mana management for caster specs.

    The existing mana_conservator.lua handles OOM prevention (wand/melee fallback). This module handles proactive mana optimization: potion timing, Evocation timing, Life Tap optimization, Innervate planning.

    Module pattern: `return mana_manager` at end.

    Exported functions:
    ```lua
    local mana_manager = {}

    -- Get current mana percentage
    function mana_manager.get_mana_pct(me)
        --> returns number (0-100)
    end

    -- Check if player should use a mana potion
    -- @param me player unit
    -- @param threshold_pct mana below which to drink potion (default 30)
    -- @return boolean
    function mana_manager.should_use_mana_potion(me, threshold_pct)
        --> returns boolean
    end

    -- Get the best mana potion item ID from inventory
    -- SUPER_MANA_POTION = 28499 (rank 3), 22828 (rank 2)
    -- DEMONIC_RUNE = 22120
    -- DARK_RUNE = 22103
    function mana_manager.get_mana_potion_item_id()
        --> returns number or nil
    end

    -- Check if player should Evocation / Innervate / Hymn
    -- For casters with Evocation (Mage): use when mana < 30% and no boss buff
    -- For Druids with Innervate: use when mana < 25%
    -- For Priests with Hymn of Hope: use when party mana < 20%
    function mana_manager.should_evocate(me, class_name, menu)
        --> returns boolean
    end

    -- Check if player should Life Tap (Warlock self-burst)
    -- Only when below 80% HP and above 30% mana, and target HP > 30%
    function mana_manager.should_life_tap(me, menu)
        --> returns boolean
    end

    -- Get estimated cast time in ms for a spell (from spell_book)
    function mana_manager.get_spell_cast_time_ms(spell_id)
        --> returns number (ms)
    end

    -- Calculate total mana cost of a spell including talents/bonuses
    function mana_manager.get_spell_mana_cost(spell_id, base_cost)
        --> returns number (mana units)
    end

    return mana_manager
    ```

    Constants to define:
    - MANA_POTIONS = { [28499] = true, [22828] = true, [22120] = true }
    - EVOCATION_ID = 12051
    - INNERVATE_ID = 29166
    - HYMN_OF_HOPE_ID = 64904
    - LIFE_TAP_ID = 25423

    Implementation notes:
    - `get_mana_pct`: Use enums or fallback to get_power(0)/get_max_power(0)
    - `should_use_mana_potion`: Check inventory for potion, check cooldown on potion, check if already buffed with mana potion buff
    - MANA_POTION_BUFF_IDS = { 28499, 22828, 11392, 11391 }
    - `should_evocate`: Mages use Evocation when mana < 30%, Druids use Innervate when mana < 25%, Priests use Hymn of Hope when party mana average < 20%
    - `should_life_tap`: Only when HP > 30%, mana < 80%, target HP > 30%, no Evocation on cooldown
  </action>
  <acceptance_criteria>
    - File exists at eax_shared/mana_manager.lua
    - Contains `return mana_manager` at end
    - Exports: `get_mana_pct`, `should_use_mana_potion`, `should_evocate`, `should_life_tap`
    - Potion detection checks inventory count > 0
    - Potion buff check prevents double-use
  </acceptance_criteria>
  <verify>
    grep -l "return mana_manager" eax_shared/mana_manager.lua && grep -l "should_evocate" eax_shared/mana_manager.lua && echo "MANA_MANAGER_OK"
  </verify>
  <done>mana_manager.lua exports proactive mana helpers for all caster specs</done>
</task>

<task type="auto">
  <name>Task 3: Wire DoT clip prevention into 6 caster specs</name>
  <files>
    EAXWarlockAffliction/main.lua
    EAXWarlockDemonology/main.lua
    EAXWarlockDestruction/main.lua
    EAXPriestShadow/main.lua
    EAXDruidBalance/main.lua
    EAXDruidRestoration/main.lua
    EAXMageFire/main.lua
  </files>
  <read_first>
    - EAXWarlockAffliction/main.lua (lines 203-209: should_refresh_debuff)
    - EAXDruidBalance/main.lua (lines 267-299: try_moonfire/try_insect_swarm)
    - EAXPriestShadow/main.lua (existing DoT refresh logic)
    - EAXWarlockAffliction/spells.lua
    - EAXPriestShadow/spells.lua
  </read_first>
  <action>
    For EACH of the 7 caster spec main.lua files, update the DoT refresh functions to use dot_manager.

    Pattern for each spec:

    **1. Add require at top of main.lua:**
    ```lua
    ---@type dot_manager
    local dot_manager = require("eax_shared/dot_manager")
    ```

    **2. Replace the existing threshold check in each DoT refresh function.**

    For EAXWarlockAffliction — Corruption refresh (lines 203-209):
    Old: `should_refresh_debuff(target, debuff_ids, threshold_ms)` — user-configurable threshold
    New: Use `dot_manager.can_refresh_dot(target, debuff_ids, runtime.corruption_id, utils.get_debuff_remaining_ms)`
    Also update Immolate refresh: use `dot_manager.can_refresh_dot(..., runtime.immolate_id, ...)`

    For EAXWarlockDemonology — Corruption, Immolate, Siphon Life refresh:
    Apply same pattern using dot_manager.

    For EAXWarlockDestruction — Immolate refresh:
    Apply same pattern.

    For EAXPriestShadow — SW:Pain and Devouring Plague refresh:
    Old: check with remaining_ms <= threshold
    New: `dot_manager.can_refresh_dot(target, spells.DEBUFF_SHADOW_WORD_PAIN, runtime.shadow_word_pain_id, utils.get_debuff_remaining_ms)`
    And: `dot_manager.can_refresh_dot(target, spells.DEBUFF_DEVOURING_PLAGUE, runtime.devouring_plague_id, utils.get_debuff_remaining_ms)`

    For EAXDruidBalance — Moonfire and Insect Swarm refresh (lines 267-290):
    Old: `utils.get_debuff_remaining_ms(target, spells.DEBUFF_MOONFIRE) > refresh_ms`
    New: `not dot_manager.can_refresh_dot(target, spells.DEBUFF_MOONFIRE, runtime.moonfire_id, utils.get_debuff_remaining_ms)`
    Old: `utils.get_debuff_remaining_ms(target, spells.DEBUFF_INSECT_SWARM) > refresh_ms`
    New: `not dot_manager.can_refresh_dot(target, spells.DEBUFF_INSECT_SWARM, runtime.insect_swarm_id, utils.get_debuff_remaining_ms)`
    NOTE: Faerie Fire (26993) has 300000ms duration — keep the existing `> 5000` check (it's correct for a 5-min DoT).

    For EAXDruidRestoration — Faerie Fire refresh:
    Keep existing `> 5000` check for Faerie Fire (it's already correct for a 5-min DoT).

    For EAXMageFire — Scorch refresh (improved by talent):
    Apply same pattern.

    Key principle: The dot_manager threshold is the ABSOLUTE minimum. If a spec wants a more aggressive refresh (e.g., for burst scenarios), it should use BOTH checks — first dot_manager says "safe to refresh" AND then the spec's own priority check says "should refresh now."
  </action>
  <acceptance_criteria>
    - EAXWarlockAffliction/main.lua requires eax_shared/dot_manager
    - EAXDruidBalance/main.lua uses dot_manager.can_refresh_dot for Moonfire and Insect Swarm
    - EAXPriestShadow/main.lua uses dot_manager for SW:Pain and Devouring Plague
    - EAXWarlockDemonology/main.lua uses dot_manager for Corruption/Immolate/Siphon Life
    - No existing clip-prevention check is REMOVED — only UPDATED to use dot_manager
  </acceptance_criteria>
  <verify>
    grep -l "dot_manager.can_refresh_dot\|require.*dot_manager" EAXWarlockAffliction/main.lua EAXWarlockDemonology/main.lua EAXWarlockDestruction/main.lua EAXPriestShadow/main.lua EAXDruidBalance/main.lua EAXDruidRestoration/main.lua EAXMageFire/main.lua | wc -l
  </verify>
  <done>All 7 caster specs use dot_manager for safe DoT refresh timing</done>
</task>

<task type="auto">
  <name>Task 4: Wire mana_manager into caster specs</name>
  <files>
    EAXWarlockAffliction/main.lua
    EAXWarlockDemonology/main.lua
    EAXMageArcane/main.lua
    EAXMageFire/main.lua
    EAXPriestShadow/main.lua
    EAXDruidBalance/main.lua
  </files>
  <read_first>
    - EAXMageArcane/main.lua (existing mana management — Life Tap, Evocation)
    - EAXWarlockAffliction/main.lua (existing Life Tap logic)
    - eax_shared/mana_manager.lua (created in Task 2)
  </read_first>
  <action>
    For each caster spec that already has mana optimization, extend it to use mana_manager.

    **1. Add require to each spec:**
    ```lua
    ---@type mana_manager
    local mana_manager = require("eax_shared/mana_manager")
    ```

    **2. Add potion usage to main rotation loop (before main damage spells):**

    For ALL caster specs (add at the start of main damage spell checks):
    ```lua
    -- Check mana potion usage before casting expensive spells
    if mana_manager.should_use_mana_potion(me, 30) then
        local potion_id = mana_manager.get_mana_potion_item_id()
        if potion_id and core.input.use_item(potion_id) then
            return true
        end
    end
    ```

    **3. For Mage specs — add Evocation timing:**
    Find the existing Evocation cast function and update it:
    ```lua
    local function try_evocation(me)
        if not menu.use_evocation or not menu.use_evocation:get_state() then return false end
        -- Use the manager's check
        if not mana_manager.should_evocate(me, "mage", menu) then return false end
        -- existing cast logic
    end
    ```

    **4. For Warlock specs — add Life Tap optimization:**
    Find the existing Life Tap function and update:
    ```lua
    local function try_life_tap(me)
        if not menu.use_life_tap or not menu.use_life_tap:get_state() then return false end
        if not mana_manager.should_life_tap(me, menu) then return false end
        -- existing cast logic
    end
    ```

    **5. For Druid specs — add Innervate timing:**
    Update Innervate cast function:
    ```lua
    if mana_manager.should_evocate(me, "druid", menu) then
        -- cast Innervate
    end
    ```

    **6. For Priest Shadow — add Hymn of Hope timing:**
    Update Hymn of Hope cast function to use mana_manager.should_evocate(me, "priest", menu).

    Add requires to these main.lua files:
    - EAXMageArcane/main.lua
    - EAXMageFire/main.lua
    - EAXWarlockAffliction/main.lua
    - EAXWarlockDemonology/main.lua
    - EAXPriestShadow/main.lua
    - EAXDruidBalance/main.lua
  </action>
  <acceptance_criteria>
    - At least 4 of the 6 caster specs require eax_shared/mana_manager
    - Potion check exists before main damage spells in at least 4 specs
    - Evocation uses mana_manager.should_evocate in Mage specs
    - Life Tap uses mana_manager.should_life_tap in Warlock specs
  </acceptance_criteria>
  <verify>
    grep -l "mana_manager.should_use_mana_potion\|require.*mana_manager" EAXMageArcane/main.lua EAXMageFire/main.lua EAXWarlockAffliction/main.lua EAXPriestShadow/main.lua | wc -l
  </verify>
  <done>mana_manager integrated into all caster specs for proactive mana optimization</done>
</task>

</tasks>

<verification>
- eax_shared/dot_manager.lua exists and exports all functions
- eax_shared/mana_manager.lua exists and exports all functions
- All 7 caster specs require dot_manager
- At least 4 caster specs require mana_manager
- DoT refresh functions use dot_manager.can_refresh_dot (grep verified)
</verification>

<success_criteria>
- dot_manager.lua created with DOT_DURATIONS from simc reference data
- dot_manager.can_refresh_dot called in Aff/Demo/Destro, Shadow Priest, Balance Druid, Fire Mage
- mana_manager.lua created with potion/Evocation/Life Tap helpers
- mana_manager integrated into at least 4 caster specs
- No existing DoT refresh logic is removed — only replaced with dot_manager call
- Potion usage added before main damage spells
</success_criteria>

<output>
After completion, create `.planning/phases/02-core-combat/02-core-combat-01-SUMMARY.md`
</output>
