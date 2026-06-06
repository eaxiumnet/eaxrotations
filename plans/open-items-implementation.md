# Open Items Implementation Plan
**Created:** 2026-06-05 | **Status:** Ready to execute

---

## Phase 0: Corrections

### Shadowburn — ALREADY IMPLEMENTED (remove from backlog)
The missing abilities audit listed "Shadowburn for Destro Warlock" as High priority. This is **stale** — Shadowburn is fully implemented:
- Match function: `destruction_sylvanas.lua:146-152` (soul shard gate, HP threshold, spell_ready)
- Strategy entry: `destruction_sylvanas.lua:303`
- Spell IDs defined: `class_sylvanas.lua:198-207`
- Schema setting: `destro_shadowburn_hp` (default 20%)
- Test file: `tests/test_destruction_shadowburn.lua`

**Action:** Update `memory/project/competitor-crossref-missing-abilities-2026-06.md` to mark Shadowburn as FIXED.

---

## Phase 1: Protection Warrior — Threat Tab Targeting (Critical)

### Problem
`protection_sylvanas.lua:308-312` — `taunt_matches_fn` only checks `enemy_count >= 2`. No threat awareness, no enemy list scanning, no tab-targeting logic. Taunt fires on whatever `context.target` happens to be, which may already have full threat.

### Root Invariants
- Tank must hold aggro on all nearby enemies
- Tab-targeting cycles through enemies to apply threat where needed
- Taunt should only fire on enemies NOT already targeting the tank
- MockingBlow and ChallengingShout follow the same trivial pattern

### Implementation

**File: `EaxRotations/classes/warrior/protection_sylvanas.lua`**

1. **Add enemy list scanning** in `build_state()` (after line 126):
   ```lua
   -- Scan nearby enemies for threat assessment
   local enemies = {}
   local enemy_count = 0
   local no_threat_count = 0
   local no_threat_target = nil
   -- Use NS.pick_enemy or core.object_manager scan
   -- For each enemy: check if unit的目标 is NOT me (low/no threat)
   -- Store: prot_state.enemies = enemies, prot_state.no_threat_count, prot_state.no_threat_target
   ```

2. **Enhance `taunt_matches_fn`** (lines 308-312):
   ```lua
   local function taunt_matches_fn(context, state)
       if not state.taunt_ready then return false end
       if (state.enemy_count or 0) < 2 then return false end
       -- Priority: taunt an enemy that isn't targeting us
       if state.no_threat_target then
           -- Set context.target to the no-threat enemy for this cast
           context._taunt_target = state.no_threat_target
           return true
       end
       -- Fallback: taunt current target if we have multiple enemies
       return true
   end
   ```

3. **Update Taunt execute** (line 474) to use `_taunt_target`:
   ```lua
   execute = function(context)
       local target = context._taunt_target or context.target
       return NS.try_cast(SPELLS.Taunt, target, "[PROT] Taunt")
   end
   ```

4. **Enhance `mocking_blow_matches_fn`** similarly — fallback when Taunt on CD.

5. **Enhance `challenging_shout_matches_fn`** — fire when 3+ enemies lack threat (AoE pull).

### Reference Pattern
- Enemy scanning: `core_sylvanas.lua:3696-3706` (`get_enemy_list_around`)
- Interrupt manager multi-target: `shared/interrupt_manager_sylvanas.lua` — cycles enemies for interrupt priority

### Anti-Pattern Guards
- Do NOT use `core.object_manager.get_enemy_list()` directly — use the NS-wrapped pattern from core
- Do NOT scan every frame — cache in build_state() with 2s throttle
- Do NOT use `math.sqrt` for distance — use squared distance

### Verification
- `luac -p EaxRotations/classes/warrior/protection_sylvanas.lua`
- Manual test: 3-target pack, verify taunt cycles to unaggroed targets
- Existing tests pass: `lua EaxRotations/tests/run_rotation_tests.lua`

---

## Phase 2: Arms Warrior — Overpower Priority Fix (Medium)

### Problem
In `arms_sylvanas.lua`, Overpower is at strategy position **#21** (after Execute at #20). In `arms_vanilla.lua`, Overpower is at position **#14** (before MortalStrike at #15). TBC meta correctly prioritizes Overpower higher — it's an instant, low-rage reactive ability that should fire as soon as it procs.

### Current Sylvanas Strategy Order (relevant excerpt)
```
#17 MortalStrike
#18 Whirlwind
#19 Slam
#20 Execute
#21 Overpower     ← TOO LOW
#22 SweepingStrikes
#23 Rend
```

### Current Vanilla Strategy Order (STRATEGY_SPECS table, line 553+)
```
#14 Overpower     ← CORRECT POSITION
#15 MortalStrike
#16 Execute
#17 Whirlwind
#18 Slam
#19 Cleave
```

### Implementation

**File: `EaxRotations/classes/warrior/arms_sylvanas.lua`**

Move Overpower from position #21 to between Whirlwind and Slam (~#18.5), matching the logic that:
- Overpower is instant (no cast time, no swing timer dependency)
- Low rage cost (5 rage)
- Procced by enemy dodges — window is time-limited
- Should fire before Slam (which requires swing timer alignment)

New order: MortalStrike > Whirlwind > **Overpower** > Slam > Execute > SweepingStrikes > Rend

### Verification
- `luac -p EaxRotations/classes/warrior/arms_sylvanas.lua`
- Test: Overpower proc triggers immediately after Whirlwind, before Slam
- Existing tests pass

---

## Phase 3: Arms Warrior — Rage Pooling / Cap Protection (Medium)

### Problem
Neither `arms_sylvanas.lua` nor `arms_vanilla.lua` has rage cap protection. When rage hits 100, it's wasted. Warriors should dump excess rage via HeroicStrike (queued on next swing) when approaching cap.

### Implementation

**File: `EaxRotations/classes/warrior/arms_sylvanas.lua`**

1. **Add rage dump threshold constant** (near other constants):
   ```lua
   local RAGE_DUMP_THRESHOLD = 85  -- Queue HeroicStrike when rage exceeds this
   ```

2. **Add HeroicStrike dump strategy** at LOW priority (below SunderArmor, above Healthstone):
   ```lua
   {
       name = "RageDump",
       matches = function(context, state)
           if (state.rage or 0) < RAGE_DUMP_THRESHOLD then return false end
           if state.execute_phase then return false end  -- Execute is better rage spender
           return true
       end,
       execute = function(context)
           return NS.try_cast(SPELLS.HeroicStrike, context.target, "[ARMS] RageDump")
       end,
   },
   ```

3. **Same for `arms_vanilla.lua`** — add equivalent at low priority.

### Verification
- `luac -p` on both files
- Test: rage at 90, no Execute available → HeroicStrike fires
- Existing tests pass

---

## Phase 4: Vanilla Arms — Rend Creature Type Filtering (Medium)

### Problem
Rend is a bleed — it does nothing against Undead, Mechanical, and Elemental creature types. `arms_vanilla.lua` has no creature type filter on Rend. Neither does `arms_sylvanas.lua` (bonus fix).

### Reference Pattern
Priest and Paladin use this safe detection pattern (`priest/discipline_sylvanas.lua:25-30`, `paladin/protection_sylvanas.lua:88-89`):
```lua
local function target_creature_type(unit)
    if not unit or not unit.get_creature_type then return nil end
    local ok, value = pcall(function() return unit:get_creature_type() end)
    return ok and value or nil
end
```

Creature type IDs: 1=Humanoid, 2=Dragonkin, 3=Demon, 4=Elemental, 5=Giant, 6=Undead, 7=Beast, 8=Mechanical, 9=NotSpecified

### Implementation

**File: `EaxRotations/classes/warrior/arms_vanilla.lua`**

1. **Add creature type helper** (copy from Paladin pattern):
   ```lua
   local function target_creature_type(unit)
       if not unit or not unit.get_creature_type then return nil end
       local ok, value = pcall(function() return unit:get_creature_type() end)
       return ok and value or nil
   end
   local BLEED_IMMUNE_TYPES = { [4]=true, [6]=true, [8]=true }  -- Elemental, Undead, Mechanical
   ```

2. **Add filter in `rend_matches`** (after TTD check):
   ```lua
   -- Skip Rend on bleed-immune creatures
   local ctype = target_creature_type(context.target)
   if ctype and BLEED_IMMUNE_TYPES[ctype] then return false end
   ```

3. **Same for `arms_sylvanas.lua`** — add identical filter in `rend_matches` (line 397-405).

### Anti-Pattern Guards
- Always pcall `get_creature_type` — some units may not support it
- Use safe default (nil) — if creature type unknown, allow the spell
- Don't hardcode creature type names — use numeric IDs

### Verification
- `luac -p` on both files
- Test: target is Undead (type 6) → Rend blocked; target is Beast (type 7) → Rend allowed
- Existing tests pass

---

## Phase 5: Protection Taunt Enhancement (High)

### Problem
`protection_sylvanas.lua:308-312` — Taunt only checks `enemy_count >= 2`. No check for:
- Whether current target is already targeting us (full aggro)
- Whether Taunt is actually needed (maybe we're off-tanking and main tank has aggro)
- Taunt on cooldown tracking

This is partially addressed in Phase 1 (threat tab targeting), but the core taunt logic needs its own improvements independent of the tab-targeting system.

### Implementation

**File: `EaxRotations/classes/warrior/protection_sylvanas.lua`**

Enhance `taunt_matches_fn` to check target threat status:
```lua
local function taunt_matches_fn(context, state)
    if not state.taunt_ready then return false end
    if (state.enemy_count or 0) < 2 then return false end
    -- Check if target is already targeting us (has aggro)
    local target = context.target
    if target then
        local target_target = target.get_target and target:get_target()
        if target_target then
            local me = context.me or NS.GetPlayer()
            if target_target == me then return false end  -- Already has aggro, don't waste Taunt
        end
    end
    return true
end
```

This ensures Taunt only fires when the current target is NOT already targeting us.

### Verification
- `luac -p`
- Test: target targeting us → Taunt blocked; target not targeting us → Taunt fires
- Existing tests pass

---

## Execution Order

| Phase | Item | Priority | Files Changed | Estimate |
|-------|------|----------|---------------|----------|
| 1 | Prot threat tab targeting | Critical | protection_sylvanas.lua | Core change |
| 5 | Prot Taunt enhancement | High | protection_sylvanas.lua | Bundled with Phase 1 |
| 2 | Arms Overpower priority | Medium | arms_sylvanas.lua | Quick reorder |
| 3 | Arms rage pooling | Medium | arms_sylvanas.lua, arms_vanilla.lua | Add strategy |
| 4 | Rend creature type filter | Medium | arms_sylvanas.lua, arms_vanilla.lua | Add helper + gate |

Phases 1+5 are bundled (same file). Phases 2+3+4 can be done in any order after.

---

## Verification Checklist

- [ ] `luac -p` passes on all modified files
- [ ] `lua EaxRotations/tests/run_rotation_tests.lua` — all 95 suites pass
- [ ] `lua EaxRotations/tests/run_leveling_tests.lua` — all 11 suites pass
- [ ] Manual review: no `math.sqrt` in distance comparisons
- [ ] Manual review: all new state fields nil-guarded
- [ ] Manual review: no expensive API calls without throttle
- [ ] Memory updated: Shadowburn marked FIXED, new completions logged
