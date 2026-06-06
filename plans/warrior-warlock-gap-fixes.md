# Warrior & Warlock Gap Fixes — Implementation Plan

**Created:** 2026-06-06 | **Status:** COMPLETE (all 6 phases verified 2026-06-06)
**Source:** Missing Abilities Audit + Warrior Discrepancies

---

## Phase 0: Documentation Discovery (Complete)

### Sources Consulted
- `EaxRotations/classes/warrior/arms_sylvanas.lua` (697 lines)
- `EaxRotations/classes/warrior/arms_vanilla.lua` (620 lines)
- `EaxRotations/classes/warrior/protection_sylvanas.lua` (664 lines)
- `EaxRotations/classes/warrior/class_sylvanas.lua` (461 lines)
- `EaxRotations/classes/warlock/destruction_sylvanas.lua` (413 lines)
- `EaxRotations/shared/interrupt_manager_sylvanas.lua` (391 lines)
- `EaxRotations/shared/targeting_sylvanas.lua` (line 163: `get_enemies()`)
- `EaxRotations/core_sylvanas.lua` (line 5141: `creature_types` filter)
- `EaxRotations/tests/test_destruction_shadowburn.lua` (127 lines)
- `api/game_object.lua` (line 244: `get_threat_situation()`)
- `api/core.lua` (enemy list, object manager)

### Key Finding: Shadowburn Already Implemented
**Shadowburn for Destro Warlock is FULLY IMPLEMENTED.** Remove from plan.
- Spell IDs in `class_sylvanas.lua:198-207`
- Execute-range match function in `destruction_sylvanas.lua:146-152`
- Soul Shard gate (item 6265) enforced
- Strategy priority position 16
- `destro_shadowburn_hp` slider in schema (default 20%)
- 4 test cases passing in `test_destruction_shadowburn.lua`

### Available APIs for Implementation
| API | Purpose | Source |
|-----|---------|--------|
| `core.object_manager.get_enemy_list()` | Multi-target cycling | core.lua |
| `target:get_creature_type()` | Creature type detection | game_object.lua |
| `action.creature_types` | Built-in creature filter | core_sylvanas.lua:5141 |
| `NS.spell_ready(id, target)` | Cooldown check | core_sylvanas.lua |
| `NS.try_cast(id, target)` | Cast attempt | core_sylvanas.lua |
| `NS.is_execute_phase(hp, threshold)` | Execute range check | core_sylvanas.lua |
| `NS.get_setting(key, fallback)` | Menu settings | core_sylvanas.lua |
| `NS.rotation_registry:register()` | Strategy registration | core_sylvanas.lua |

### Anti-Patterns to Avoid
- No `math.sqrt()` for distance — use squared distance
- No bare `state.field < X` without nil-guard
- No `menu.x:get()` without nil guard
- Cache hot-path APIs at module load
- Use `pcall(require, ...)` for optional shared modules
- All spells valid on Wrath 3.3.5 client (TBC Classic Anniversary)

---

## Phase 1: Prot TBC Threat Tab Targeting (CRITICAL)

**Goal:** Tank should cycle Taunt/MockingBlow/ChallengingShout across multiple targets, not just current target.

### Current State (verified 2026-06-06)
- **Strategy positions:** Taunt(#7), MockingBlow(#8), ChallengingShout(#9) — correctly ordered after threat-gen core
- **Taunt match logic (lines 308-312):** Trivially simple — only checks `taunt_ready` and `enemy_count >= 2`
- **MockingBlow match (lines 314-318):** Same — only `mocking_ready` and `enemy_count >= 2`
- **ChallengingShout match (lines 320-324):** Only `challenging_ready` and `enemy_count >= 3`
- **No enemy_list scanning** — `get_enemy_list()` / `get_visible_objects()` NOT called anywhere in file
- **No threat awareness** — `get_threat_situation()` not used
- **No TTD gates** on any taunt/cooldown abilities

### 1A: Multi-Target Taunt Cycling

**File:** `EaxRotations/classes/warrior/protection_sylvanas.lua`

**What to implement:**
- Add `local _get_enemy_list = core.object_manager.get_enemy_list` at module load (cache)
- In `build_state()`: scan enemies within range, store `prot_state.nearby_enemies` (list of {unit, dist_sq})
- Add `TauntSecondary` match function: picks closest enemy NOT already being tanked (no threat debuff, alive, within range)
- Add `MockingBlowAoE` match: fires when 3+ enemies in melee range (not just `enemy_count >= 2`)
- Wire into strategy table AFTER primary Taunt/Revenge/ShieldSlam

**APIs available:**
- `core.object_manager.get_enemy_list()` — returns all enemies
- `game_object:get_threat_situation(player)` — returns `{is_tanking, status (0-3), threat_percent}` (api/game_object.lua:244)
- `NS.debuff_remains(unit, debuff_ids)` — check if already taunted
- `me:distance_to(enemy)` — squared distance (NO math.sqrt)

**Pattern reference:** `shared/targeting_sylvanas.lua:163` — `get_enemies(range)` with `NS.GetEnemiesInRange` fallback

**Implementation sketch:**
```lua
local _get_enemy_list = core.object_manager.get_enemy_list

-- In build_state():
local me = context.me or NS.GetPlayer()
local nearby = {}
if me and context.in_combat then
    local enemies = _get_enemy_list and _get_enemy_list() or {}
    for _, enemy in ipairs(enemies) do
        if enemy ~= context.target and enemy:is_alive() then
            local dist_sq = me:distance_to(enemy)
            if dist_sq < 400 then  -- 20yd
                nearby[#nearby + 1] = { unit = enemy, dist = dist_sq }
            end
        end
    end
    table.sort(nearby, function(a, b) return a.dist < b.dist end)
end
prot_state.nearby_enemies = nearby
prot_state.nearby_count = #nearby
```

**Strategy entries to add:**
1. `TauntSecondary` — Taunt closest nearby enemy not currently being tanked
2. `MockingBlowAoE` — MockingBlow when 3+ enemies in melee range

**Settings to add (in `schema_sylvanas.lua`):**
- `prot_tab_targeting` (checkbox, default true) — enable multi-target cycling
- `prot_tab_range` (slider, default 20, range 10-40) — tab targeting range

### 1B: Improved Taunt Logic

**What to implement (enhance existing `taunt_matches_fn` at lines 308-312):**
- Check target health: don't Taunt targets at < 10% HP (waste of cooldown)
- Check target TTD: don't Taunt targets about to die (if ttd_ema available)
- Check if target already has Taunt debuff (already taunted = skip)
- Check threat situation: only Taunt if target is NOT already being tanked by us (`get_threat_situation().is_tanking == false`)

**Anti-pattern guard:** Do NOT add WoW-native `UnitDetailedThreatInformation()` calls — use `get_threat_situation()` from api/game_object.lua only.

### Verification Checklist
- [ ] `luac -p protection_sylvanas.lua` passes
- [ ] `lua EaxRotations/tests/run_rotation_tests.lua` — all suites pass
- [ ] Grep for `get_enemy_list` in protection file — confirms cycling works
- [ ] Grep for `get_threat_situation` in protection file — confirms threat awareness added
- [ ] Strategy table priority: Taunt(#7) > MockingBlow(#8) > ChallengingShout(#9) > TauntSecondary (new, after #9)
- [ ] No WoW-native API calls (grep for `UnitDetailedThreat`, `UnitThreat`)
- [ ] Menu references nil-guarded
- [ ] `prot_state.nearby_enemies` populated in build_state when in_combat

---

## Phase 2: Arms Overpower Priority Alignment (MEDIUM)

**Goal:** Align Overpower priority between Sylvanas and Vanilla Arms rotations.

### Current State
- **Sylvanas Arms:** Overpower at position #21 (after Execute) — too low priority
- **Vanilla Arms:** Overpower at position #15 (before MortalStrike) — correct for Classic

### What to implement

**File:** `EaxRotations/classes/warrior/arms_sylvanas.lua`

- Move Overpower to higher priority (position ~10-12, before Execute) to match Classic Arms behavior
- Add rage protection: don't use Overpower if rage < 5 (already has min 5 gate)
- Add TTD gate: don't use Overpower on targets about to die (already exists)
- Keep Battle Stance check (already exists)

**File:** `EaxRotations/classes/warrior/arms_vanilla.lua`

- Add stance lockout check: `stance_lockout_active()` before Overpower stance switches
- Stance lockout: 2.0s after stance cast, prevent double-swap

**Anti-pattern guard:** Overpower in Battle Stance is the correct behavior — do NOT add Defensive Stance Overpower.

### Verification Checklist
- [ ] `luac -p arms_sylvanas.lua` passes
- [ ] `luac -p arms_vanilla.lua` passes
- [ ] All rotation tests pass
- [ ] Overpower priority: higher than Execute, lower than MortalStrike/Slam
- [ ] Stance lockout check present in Vanilla rotation

---

## Phase 3: Rend Creature Type Filtering (MEDIUM)

**Goal:** Don't Rend mechanical/undead targets that can bleed (if applicable).

### What to implement

**File:** `EaxRotations/classes/warrior/arms_vanilla.lua`

- Add `creature_types` filter to Rend action spec, OR
- Add `get_creature_type()` check in `rend_matches()` function

**Creature type filtering options:**
1. **Action spec filter** (core_sylvanas.lua:5141): `action.creature_types = { ["Beast"]=true, ["Humanoid"]=true, ... }` — use string keys matching `get_creature_type()` return value. Excludes "Mechanical" and "Undead" (can't bleed).
2. **Match function check**: `if target:get_creature_type() == "Undead" then return false end`

**Recommendation:** Use option 1 (action spec filter) — it's built into the framework and doesn't require match function changes.

**Note:** `get_creature_type(target)` has never been used in any existing spec — this would be the first usage. Verify return type (likely WoW-standard string: "Beast", "Dragonkin", "Humanoid", "Mechanical", "Undead", etc.) before implementation. The framework at core_sylvanas.lua:5141 uses `action.creature_types[creature_type]` as a lookup table.

**File:** `EaxRotations/classes/warrior/arms_sylvanas.lua`

- Apply same creature type filtering for Rend

### Anti-pattern guard: `get_creature_type(target)` return type is UNVERIFIED — could be string or number. Verify at implementation time by checking the API definition in `api/game_object.lua`. TBC Classic runs on Wrath client — "Mechanical" is a valid creature type. Use `action.creature_types` table (core_sylvanas.lua:5141) which does `action.creature_types[creature_type]` lookup — works with either string or number keys.

### Verification Checklist
- [ ] `luac -p` on both arm files passes
- [ ] All rotation tests pass
- [ ] `creature_types` field present on Rend action specs
- [ ] Correct creature type list (no Mechanical, no Undead for bleed effects)

---

## Phase 4: Rage Pooling & Cap Protection (MEDIUM)

**Goal:** Prevent rage waste — don't use abilities when rage is near cap (100).

### What to implement

**Files:** `arms_sylvanas.lua`, `arms_vanilla.lua`, `protection_sylvanas.lua`

- Add rage cap check in match functions for rage spenders:
  ```lua
  local function rage_cap_check(state)
      return (state.rage or 0) >= 90  -- Near cap, spend freely
  end
  ```
- For Sweeping Strikes: pool rage before use (check rage will be enough for follow-up abilities)
- For Execute: don't use if rage < 30 and target is near death (save for next fight)

**Pattern:** Similar to mana tier system in `shared/mana_tier_sylvanas.lua` — resource-aware ability gating.

**Anti-pattern guard:** Don't add rage pooling logic that changes the fundamental priority order — it should only gate abilities when rage is insufficient.

### Verification Checklist
- [ ] `luac -p` on all warrior files passes
- [ ] All rotation tests pass
- [ ] Rage cap check present in spender match functions
- [ ] Sweeping Strikes rage pool check present

---

## Phase 5: Bug Fix — Disarm Strategy Missing `state` Parameter

**File:** `protection_sylvanas.lua`

**Bug:** The Disarm strategy's match function (line 622) only takes `(context)` but calls `disarm_matches_fn(context, state)` at line 631. `state` is undefined → `state.disarm_ready` (line 372) crashes at runtime.

**Fix:** Add `state` parameter to the Disarm match function:
```lua
-- Line 622: change
matches = function(context) return ... end,
-- to
matches = function(context, state) return ... end,
```

**Verification:**
- [ ] `luac -p protection_sylvanas.lua` passes
- [ ] Grep for `function(context) return disarm` — should find 0 matches

---

## Phase 6: Verification (Final)

### Full Test Suite
```bash
rtk luac -p EaxRotations/classes/warrior/*.lua
rtk luac -p EaxRotations/classes/warlock/destruction_sylvanas.lua
rtk lua EaxRotations/tests/run_rotation_tests.lua
rtk lua EaxRotations/tests/run_leveling_tests.lua
```

### Anti-Pattern Audit
- [ ] No `math.sqrt()` in new code
- [ ] No bare `state.field < X` without nil-guard
- [ ] No `menu.x:get()` without nil guard
- [ ] No WoW-native API calls (grep for `UnitDetailedThreat`, `GetThreatStatusColor`)
- [ ] All new spells valid on Wrath 3.3.5 client
- [ ] Hot-path APIs cached at module load
- [ ] Static table reuse in tight loops

### Files Changed
| File | Changes |
|------|---------|
| `protection_sylvanas.lua` | Multi-target Taunt cycling, improved Taunt logic, Disarm `state` fix, settings |
| `arms_sylvanas.lua` | Overpower priority (#21→~#15), Rend creature type filter, rage pooling |
| `arms_vanilla.lua` | Rend creature type filter, rage pooling |
| `shared/targeting_sylvanas.lua` | Reference only — `get_enemies(range)` pattern |
| `schema_sylvanas.lua` | New settings (prot_tab_targeting, prot_tab_range) |

### Cross-References
- **Interrupt Manager** (`shared/interrupt_manager_sylvanas.lua`): Multi-target cycling pattern — copy from here
- **Creature Type Filter** (`core_sylvanas.lua:5141`): Built-in mechanism — use this
- **Mana Tier System** (`shared/mana_tier_sylvanas.lua`): Resource-aware gating pattern — reference for rage pooling
