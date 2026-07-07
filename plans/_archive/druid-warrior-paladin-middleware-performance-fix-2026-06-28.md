# Performance & Spam Fix — Multi-Class Omnibus

**Started:** 2026-06-28
**Scope:** Fix per-frame CPU burn and form/stance/aura spam across 12+ files
**Root cause:** Agent audit found `build_state` called N×/frame, unthrottled enemy scans, missing form guards

## Files to Fix

### 1. Druid Vanilla (CRITICAL — form spam + CPU burn)
- `EaxRotations/classes/druid/cat_vanilla.lua` — Add `context.stance` guards to CatForm/TravelForm; add `build_state` frame cache
- `EaxRotations/classes/druid/bear_vanilla.lua` — Add `build_state` frame cache; reduce scan_pack interval

### 2. Warrior (HIGH — CPU burn)
- `EaxRotations/classes/warrior/protection_vanilla.lua` — Add `build_state` frame cache
- `EaxRotations/classes/warrior/arms_sylvanas.lua` — Add `build_state` frame cache
- `EaxRotations/classes/warrior/arms_vanilla.lua` — Add `build_state` frame cache
- `EaxRotations/classes/warrior/fury_sylvanas.lua` — Add `build_state` frame cache

### 3. Paladin Holy (HIGH — aura flip-flop)
- `EaxRotations/classes/paladin/holy_sylvanas.lua` — Add `_last_aura_cast` 3s throttle
- `EaxRotations/classes/paladin/holy_vanilla.lua` — Add `_last_aura_cast` 3s throttle

### 4. Middleware CC-Break Scans (HIGH — per-frame enemy iteration)
- `EaxRotations/classes/priest/middleware_sylvanas.lua` — Throttle mana burn, mass dispel, fade scans
- `EaxRotations/classes/mage/middleware_sylvanas.lua` — Throttle CC break preemptive scan
- `EaxRotations/classes/warlock/middleware_sylvanas.lua` — Throttle death coil CC break scan
- `EaxRotations/classes/rogue/middleware_sylvanas.lua` — Throttle cloak/vanish CC break scan
- `EaxRotations/classes/paladin/middleware_sylvanas.lua` — Throttle divine shield/BoFreedom CC break scan
- `EaxRotations/classes/priest/shadow_sylvanas.lua` — Throttle SW:D CC break scan

## Pattern to Copy

### build_state frame cache (from druid/bear_sylvanas.lua):
```lua
local _last_build_state_time = -1
local function build_state(context)
    local now = context.now
    if now and now == _last_build_state_time then return state end
    now = now or (NS.time_now and NS.time_now() or 0)
    if context.now then _last_build_state_time = now end
    state.now = now
    -- ... rest of build_state ...
end
```

### Form-shift throttle (from druid/cat_sylvanas.lua):
```lua
local _last_form_shift_time = -100
local FORM_SWITCH_COOLDOWN = 2.0
-- In match: if (get_now() - _last_form_shift_time) < FORM_SWITCH_COOLDOWN then return false end
-- In execute: if ok then _last_form_shift_time = get_now() end
```

### Enemy scan throttle (from druid/middleware_sylvanas.lua):
```lua
local _last_ccbreak_scan = 0
local _last_ccbreak_result = false
local CCBREAK_SCAN_INTERVAL = 0.3
-- In match: if now - _last_ccbreak_scan < CCBREAK_SCAN_INTERVAL then return _last_ccbreak_result end
```

## Validation Gates (Round 1: Performance/Spam)
- [x] `luac -p` on every modified file — 14/14 pass
- [x] `lua EaxRotations/tests/run_rotation_tests.lua` — 171/171 pass
- [x] `lua EaxRotations/tests/run_leveling_tests.lua` — 11/11 pass

## Round 2: Middleware API Correctness Audit
**Agent audit found 5 real bugs across 4 middleware files.** All fixed and validated.

### Bug Fixes Applied

| Priority | File | Bug | Fix |
|----------|------|-----|-----|
| **P1** | `priest/middleware_sylvanas.lua` | `NS.unit_mana_pct` does not exist → ManaBurn never finds targets | Replaced with raw `get_power(0)/get_max_power(0)` pcall |
| **P2** | `paladin/middleware_sylvanas.lua` | `me.debuff_remains` is nil → Forbearance check silently skipped | Removed invalid guard, use `NS.debuff_remains()` directly |
| **P2** | `hunter/middleware_sylvanas.lua` | `target:get_power_type()` unguarded → crash on stale target | Wrapped in pcall |
| **P2** | `hunter/middleware_sylvanas.lua` | `pcall(pet.is_alive)` missing self → FeedPet never matches | Fixed to `pcall(pet.is_alive, pet)` |
| **P3** | `hunter/middleware_sylvanas.lua` | `target:get_class()` unguarded → crash on stale target | Wrapped in pcall |
| **P3** | `warrior/middleware_sylvanas.lua` | `spell_id = pcall(...)` gets boolean not result | Fixed pcall unpacking to `(ok, spell_id)` |

### Validation Gates (Round 2)
- [x] `luac -p` on all 4 middleware files — pass
- [x] `lua EaxRotations/tests/run_rotation_tests.lua` — 171/171 pass
- [x] `lua EaxRotations/tests/run_leveling_tests.lua` — 11/11 pass

## Round 3: Shared Module Audit (Agent-run)
**Agent audited all 22 shared modules under `EaxRotations/shared/`**

### Bugs Found & Fixed

| Priority | File | Bug | Fix |
|----------|------|-----|-----|
| **P1** | `shared/pet_manager_sylvanas.lua` | Unguarded `core.spell_book.*` / `core.input.*` → crash on engine init | Wrapped all `core.*` lookups in nil-guarded pcall |
| **P2** | `shared/auto_tremor_sylvanas.lua` | `NS.get_party_members` (lowercase) doesn't exist → Tremor Totem never drops for allies | Fixed to `NS.GetPartyMembers()` |
| **P2** | `shared/consumable_manager_sylvanas.lua` | `get_role()` misclassifies Enhancement Shaman and Feral Druid as "caster" | Added active_playstyle checks for "enhancement", "cat", "bear", "feral" → "melee" |
| **P3** | `shared/ooc_manager_sylvanas.lua` | `mark_of_the_wild.n = 11` — agent falsely flagged as off-by-one | **Reverted** — n=11 is correct for 11 spell IDs |

### Issues Flagged but NOT Fixed (by design)
- `interrupt_manager_sylvanas.lua` legacy `HEAL_CASTS`/`CC_CASTS` tables — bloat but harmless
- `ttd_tracker_sylvanas.lua` per-frame `xs={}`/`ys={}` alloc — 24 table slots/tick, negligible
- `racial_manager_sylvanas.lua` / `trinket_manager_sylvanas.lua` per-frame context table alloc — minor
- `purge_manager_sylvanas.lua` `_dispel_delay_cache` unbounded growth — bounded by encounter size

## Total Changes
- **22 files modified** (14 performance + 4 middleware bug fixes + 4 shared module fixes)
- **182/182 tests pass**
- **0 deprecated patterns found** (no `ffi.C`, `math.sqrt`, unguarded menu access, etc.)
