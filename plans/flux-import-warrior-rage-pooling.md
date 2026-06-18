# Implementation Plan: Flux Warrior Rage Pooling + Swing Desync for EaxRotations

**Created:** 2026-06-11
**Source:** `tbc-main/tbc-main/rotation/source/aio/warrior/arms.lua`, `fury.lua`, `middleware.lua` (Flux AIO)
**Target:** `EaxRotations/classes/warrior/arms_sylvanas.lua`, `fury_sylvanas.lua`, `middleware_sylvanas.lua` (EaxRotations)
**API Surface:** `NS.spell_ready`, `NS.try_cast`, `NS.cooldown_remains`, `NS.swing_time_until`, `NS.is_current_spell`, `NS.cancel_spells`, `NS.buff_up`, `NS.debuff_remains`, `NS.time_now`

---

## Overview

Port 6 specific warrior rotation improvements from Flux AIO to EaxRotations. These are battle-tested rage management patterns that improve DPS through smarter resource pooling and swing timing optimization. Each change is self-contained and verified by existing test suites.

---

## Gap Analysis (Current EaxRotations vs Flux)

| Feature | Eax Arms | Eax Fury | Flux Arms | Flux Fury |
|---------|----------|----------|-----------|-----------|
| Core ability imminent holding | ❌ | ✅ (partial, Slam only) | ✅ | ✅ |
| HS/Cleave starvation prevention | ❌ | ❌ | ✅ | ✅ |
| SS rage reservation | ✅ | ❌ | ✅ | ✅ |
| Overpower rage protection | ❌ | N/A | ✅ | N/A |
| Slam swing timing check | ❌ | ✅ | ✅ | ✅ |
| Proactive HS queue (OH swing) | ❌ | ❌ | ✅ | ✅ |
| Interrupt rage reserve (HS) | ❌ | ❌ | ✅ | ✅ |
| Hamstring weave (Sword Spec) | N/A | ❌ | N/A | ✅ |
| Swing desync (MH/OH offset) | N/A | ❌ | N/A | ✅ |
| HS trick (lower DW threshold) | N/A | ❌ | N/A | ✅ |

---

## Files to Touch

| File | Change | Lines Added |
|------|--------|-------------|
| `EaxRotations/classes/warrior/arms_sylvanas.lua` | Add 3 pool functions + Slam swing check + Overpower protection + HS starvation check | ~80 |
| `EaxRotations/classes/warrior/fury_sylvanas.lua` | Add Swing Desync strategy + Hamstring weave + HS trick + starvation check | ~100 |
| `EaxRotations/classes/warrior/middleware_sylvanas.lua` | Enhance SmartHSDequeue with proactive queue timing | ~30 |

---

## Task List

### Phase 1: Arms Rage Pooling

#### Task 1.1 — Add `should_pool_for_core_arms()` (Eax: arms_sylvanas.lua)

**What**: Hold filler GCDs when Mortal Strike is imminent and rage is tight.

**Flux source**: `arms.lua:83-91`
```lua
-- Pool filler (Slam) when MS coming off CD within 1.5s and we can't afford both
local FILLER_HOLD_WINDOW = 1.5
local RAGE_COST_MS = 30
local RAGE_COST_SLAM = 15

local function should_pool_for_core_arms(context, state)
    if (state.rage or 0) < RAGE_COST_SLAM then return false end
    if (state.ms_cd or 99) > 0 and (state.ms_cd or 99) <= FILLER_HOLD_WINDOW then
        if ((context.rage or 0) - RAGE_COST_SLAM) < RAGE_COST_MS then return true end
    end
    return false
end
```

**Eax integration**: Add to arms_sylvanas.lua after existing constants (line ~80). Call from `slam_matches()` as an additional gate.

#### Task 1.2 — Add `would_starve_core_arms()` (Eax: arms_sylvanas.lua)

**What**: Prevent Heroic Strike / Cleave from queuing when their rage cost would starve imminent MS or WW.

**Flux source**: `arms.lua:116-129`
```lua
local function would_starve_core_arms(context, state, cost)
    cost = cost or 15
    if (state.ms_cd or 99) >= 0 and (state.ms_cd or 99) <= 1.5 and context.in_melee_range then
        if ((context.rage or 0) - cost) < RAGE_COST_MS then return true end
    end
    if context.settings.arms_use_whirlwind then
        if (state.ww_cd or 99) >= 0 and (state.ww_cd or 99) <= 1.5 and context.in_melee_range then
            if ((context.rage or 0) - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end
```

**Eax integration**: Call from `heroic_strike_matches()` and `cleave_matches()` as additional gate. Also add interrupt rage reserve: if target casting and pummel_ready, hold enough rage for Pummel (10).

#### Task 1.3 — Add Overpower rage protection (Eax: arms_sylvanas.lua)

**What**: Before stance-dancing to Battle Stance for Overpower, check that we won't starve MS/WW/Execute.

**Flux source**: `arms.lua:159-197`

**Eax integration**: Enhance `overpower_matches()` (or the match function called from STRATEGY_SPECS) with the same `should_use_overpower()` logic that checks:
1. Basic affordability after TM cap
2. Don't OP at very high rage (>50)
3. Don't starve MS if imminent
4. Don't starve WW if imminent
5. Don't starve Execute in execute phase

#### Task 1.4 — Add Slam swing timing check (Eax: arms_sylvanas.lua)

**What**: Only Slam if cast fits before next melee swing (prevents delaying auto-attack).

**Flux source**: `arms.lua:433-434`
```lua
local swing_remain = NS.get_time_until_swing()
if swing_remain < SLAM_MIN_WINDOW then return false end
```

**Eax integration**: Add to `slam_matches()` as additional gate. Use `NS.swing_time_until()` (already available in Eax).

**API Reference**: `NS.swing_time_until(unit)` — returns seconds until next MH swing
**Anti-pattern**: Do NOT use `math.sqrt()` for distance. Use `NS.swing_time_until()` directly.

**Verification**: 
- `luac -p EaxRotations/classes/warrior/arms_sylvanas.lua`
- `lua EaxRotations/tests/test_arms_custom_matches.lua`
- `lua EaxRotations/tests/run_rotation_tests.lua`

---

### Phase 2: Fury Rage Pooling + New Features

#### Task 2.1 — Add `would_starve_core_fury()` (Eax: fury_sylvanas.lua)

**What**: Prevent HS/Cleave from queuing when it would starve BT or WW.

**Flux source**: `fury.lua:118-131`
```lua
local function would_starve_core_fury(context, state, cost)
    cost = cost or 15
    if (state.bt_cd or 99) >= 0 and (state.bt_cd or 99) <= 1.5 and context.in_melee_range then
        if ((context.rage or 0) - cost) < RAGE_COST_BT then return true end
    end
    if context.settings.fury_use_whirlwind then
        if (state.ww_cd or 99) >= 0 and (state.ww_cd or 99) <= 1.5 and context.in_melee_range then
            if ((context.rage or 0) - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end
```

**Eax integration**: Same pattern as Task 1.2 but for Fury. Call from `heroic_strike_matches()` and `cleave_matches()`. Add interrupt rage reserve.

#### Task 2.2 — Add SS rage reservation for Fury (Eax: fury_sylvanas.lua)

**What**: Pools rage for Sweeping Strikes in AoE (same pattern already exists in arms).

**Flux source**: `fury.lua:105-113`

**Eax integration**: Add `should_reserve_for_sweeping()` to fury_sylvanas.lua. Call from `whirlwind_matches()` and `heroic_strike_matches()`.

#### Task 2.3 — Add Hamstring weave for Sword Spec (Eax: fury_sylvanas.lua)

**What**: At high rage, weave Hamstring to proc Sword Specialization extra attacks.

**Flux source**: `fury.lua:361-376`
```lua
local function should_hamstring_weave(context, state)
    local min_rage = context.settings.fury_hamstring_rage or 50
    if (context.rage or 0) < min_rage then return false end
    return A.Hamstring:IsReady(TARGET_UNIT)
end
```

**Eax integration**: 
1. Add `hamstring_weave_matches()` function to fury_sylvanas.lua
2. Add new STRATEGY_SPECS entry after "Bloodthirst" (so it fires when BT is on CD and rage is high)
3. Add `fury_hamstring_weave` setting and `fury_hamstring_rage` slider to EaxRotations/classes/warrior/schema_sylvanas.lua
4. Guard with setting check: only active if `setting(context, "fury_use_hamstring", false)` and rage >= threshold

#### Task 2.4 — Add HS trick with lower DW threshold (Eax: fury_sylvanas.lua)

**What**: When dual-wielding, lower the HS rage threshold (queue proactively) since the dequeue middleware catches unsafe casts.

**Flux source**: `fury.lua:447-448`
```lua
if context.settings.hs_trick and context.has_offhand then
    threshold = 30  -- keep enough for BT (30 rage) — dequeue middleware handles safety
end
```

**Eax integration**: In `heroic_strike_matches()`, if `hs_trick` setting enabled and dual-wielding, use lower threshold (30 instead of 60). The existing SmartHSDequeue middleware handles dequeue safety.

#### Task 2.5 — Add WW priority over BT by enemy count (Eax: fury_sylvanas.lua)

**What**: Skip Bloodthirst when enough enemies are nearby and WW is ready (yield AoE priority to WW).

**Flux source**: `fury.lua:174-179`
```lua
local ww_prio = context.settings.fury_ww_prio_count or 2
if ww_prio > 0 and (state.enemy_count or 0) >= ww_prio
    and (context.rage or 0) >= 25
    and context.settings.fury_use_whirlwind
    and ww_ready then
    return false
end
```

**Eax integration**: In `bt_matches()`, add WW priority gate. Add `ww_priority_count` setting to schema.

#### Task 2.6 — Add Swing Desync for Fury (Eax: fury_sylvanas.lua)

**What**: When dual-wielding with matching weapon speeds, inject a Slam to offset MH/OH swing timers. This smooths rage generation and lets Flurry/WF procs benefit both hands.

**Flux source**: `fury.lua:378-419`
```lua
local DESYNC_SPEED_TOLERANCE = 0.2
local DESYNC_SYNC_THRESHOLD = 0.3
local DESYNC_COOLDOWN = 10
local DESYNC_SLAM_WINDOW = 1.6
local desync_last_attempt = 0

local function should_swing_desync(context, state)
    -- Setting gate
    if not context.settings.fury_swing_desync then return false end
    -- Must be dual-wielding
    if not context.has_offhand then return false end
    -- Can't Slam while moving
    if context.is_moving then return false end
    -- Cooldown between desync attempts
    local now = NS.time_now()
    if (now - desync_last_attempt) < DESYNC_COOLDOWN then return false end
    -- Weapon speeds must be similar
    -- [requires NS.get_swing_speed() or equivalent API]
    -- Both hands must be actively swinging and synced
    -- [requires NS.swing_time_until(me) for MH + OH]
    -- Enough swing time for base Slam
    if (state.mh_until or 999) < DESYNC_SLAM_WINDOW then return false end
    -- Don't starve BT/WW
    if should_pool_for_core_fury(context, state) then return false end
    return NS.spell_ready(ACTION.Slam, context.target)
end
```

**Note**: This requires OH swing timer API. If `NS.swing_time_until(me, "offhand")` or equivalent is not available, we may need to access it via the raw `core.object_manager` API. Defer implementation until API availability is confirmed.

**Eax integration**: 
1. Add `fury_swing_desync` setting (checkbox) to schema
2. Add `Fury_SwingDesync` strategy: after Hamstring weave, before Slam
3. Track `desync_last_attempt` per Fury spec
4. Guard with `setting(context, "fury_swing_desync", false)`

**API Requirements**: 
- `NS.swing_time_until(me)` — ✅ exists
- OH swing time — needs verification in `api/game_object.lua`
- `NS.get_swing_speed()` or weapon speed access — needs verification

**Verification**:
- `luac -p EaxRotations/classes/warrior/fury_sylvanas.lua`
- `lua EaxRotations/tests/test_fury_custom_matches.lua`
- `lua EaxRotations/tests/run_rotation_tests.lua`

---

### Phase 3: Middleware Enhancements

#### Task 3.1 — Add proactive HS queue timing (Eax: middleware_sylvanas.lua)

**What**: When HS trick is enabled and OH swing is imminent (≤0.4s remaining) while MH swing is further out, allow HS queue before the normal rage threshold. The dequeue middleware (SmartHSDequeue) will catch unsafe casts.

**Note**: This is the proactive side of the HS trick — it goes in the spec files (heroic_strike_matches), not middleware. The middleware (`SmartHSDequeue`) already handles the dequeue side. No middleware changes needed if HS trick is already working.

**Flux source**: `fury.lua:436-443`, `arms.lua:456-463`

**Eax integration**: In `heroic_strike_matches()` (both arms and fury), add HS trick proactive queue before the normal rage threshold check:
```lua
-- Proactive HS queue: when OH swing is imminent and MH swing is further out
if context.settings.hs_trick and context.has_offhand then
    local oh_remaining = NS.swing_time_until(me, "offhand") or 999
    local mh_remaining = NS.swing_time_until(me) or 999
    if oh_remaining > 0 and oh_remaining <= 0.4 then
        if mh_remaining > oh_remaining + 0.3 then
            return action(...)  -- queue HS now; dequeue middleware handles MH safety
        end
    end
end
```

**API dependency**: `NS.swing_time_until(me, "offhand")` — confirm existence.

---

### Phase 4: Schema Updates

#### Task 4.1 — Add new settings to warrior schema (Eax: schema_sylvanas.lua)

New settings needed:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `arms_use_whirlwind` | checkbox | true | Enable Whirlwind in Arms rotation |
| `fury_use_whirlwind` | checkbox | true | Enable Whirlwind in Fury rotation |
| `fury_use_hamstring` | checkbox | false | Enable Hamstring weave for Sword Spec |
| `fury_hamstring_rage` | slider (30-100, step 5) | 50 | Minimum rage for Hamstring weave |
| `fury_swing_desync` | checkbox | false | Enable swing desync for DW Fury |
| `fury_ww_prio_count` | slider (0-5) | 2 | Enemy count threshold for WW priority over BT |
| `hs_trick` | checkbox | false | Enable HS queue trick (already exists) |

---

## Verification

| Check | Command |
|-------|---------|
| Syntax | `luac -p EaxRotations/classes/warrior/arms_sylvanas.lua` |
| Syntax | `luac -p EaxRotations/classes/warrior/fury_sylvanas.lua` |
| Syntax | `luac -p EaxRotations/classes/warrior/middleware_sylvanas.lua` |
| Syntax | `luac -p EaxRotations/classes/warrior/schema_sylvanas.lua` |
| Arms rotation tests | `lua EaxRotations/tests/test_arms_custom_matches.lua` |
| Fury rotation tests | `lua EaxRotations/tests/test_fury_custom_matches.lua` |
| Kebab rotation tests | `lua EaxRotations/tests/test_kebab_general_use_matches.lua` |
| Middleware tests | `lua EaxRotations/tests/test_warrior_middleware_nil_guard.lua` |
| Full rotation suite | `lua EaxRotations/tests/run_rotation_tests.lua` |
| Full leveling suite | `lua EaxRotations/tests/run_leveling_tests.lua` |
| LSP diagnostics | `lsp_diagnostics` on all changed files |

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| OH swing timer API missing | Blocks HS trick proactive queue + swing desync | Research API first; fall back to HS trick without proactive queue |
| `NS.swing_time_until(me, "offhand")` doesn't exist | Same as above | Check `api/game_object.lua` for `get_swing(2)` or similar |
| Nil state fields in new functions | Match functions silently skip | Guard ALL comparisons: `(state.ms_cd or 99) > 0` not `state.ms_cd > 0` |
| New settings break existing test fixtures | Tests fail | Update test fixtures with new setting defaults |
| Execute phase interactions wrong | Incorrect DPS | Add `not state.execute_phase` gates where appropriate |
| HS trick + dequeue race condition | Missed OH yellow hit | Verify SmartHSDequeue handles the race window correctly |

---

## Ordering Dependencies

```
Phase 4 (Schema) → Phase 1 (Arms) → Phase 2 (Fury) → Phase 3 (Middleware)
                            ↓                       
                    Parallel arms + fury spec changes
                            ↓
                      Phase 4 first (schema needs to exist before tests
                      reference new settings)
```

Actually: Schema MUST be updated first (or at least settings must exist before spec files reference them). Do schema changes first, then spec files in parallel.
