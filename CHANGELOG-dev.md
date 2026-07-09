# Developer Changelog — EaxRotations v2.6.2

**Date:** 2026-07-09
**Branch:** main
**Commits:** API standardization audit — Pattern 15 headers, Pattern 2 caching fix

---

## API Standardization Audit (Phase 0)

### Pattern 15 Headers Added

| File | Header Added |
|------|-------------|
| `main.lua` | WHAT/WHEN/WHY/SAFETY |
| `common_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |
| `helpers_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |

### Pattern 2 API Caching Fix

| File | Fix |
|------|-----|
| `druid/cat_sylvanas.lua:46` | Cached `core.spell_book.get_shapeshift_form_id` at module load (was raw inline call) |

### Phase 0 Grep Audit Results

| Audit | Result |
|-------|--------|
| Banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`) | ✅ Zero in production |
| `math.sqrt` | ✅ Zero in production |
| Bare `menu.x:get()` | ✅ Zero in spec/middleware/shared |
| `buff_points` without nil guard | ✅ All guarded |
| State bare comparisons (legacy) | ✅ Zero |
| Static table allocation in loops | ✅ Zero |
| Test raw `core.*` mocks | ✅ All legitimate |

### Files Changed
- `EaxRotations/main.lua` — Pattern 15 header
- `EaxRotations/common_sylvanas.lua` — Pattern 15 header
- `EaxRotations/helpers_sylvanas.lua` — Pattern 15 header
- `EaxRotations/classes/druid/cat_sylvanas.lua` — Pattern 2 API caching

### Verification
- `luac -p`: 476/476 PASS
- Rotation tests: 249/249 PASS
- Leveling tests: 13/13 PASS
- Vanilla audit: 31/31 clean
- Sylvanas audit: 296/296 clean

---

# Developer Changelog — EaxRotations v2.6.1

**Date:** 2026-07-09
**Branch:** main
**Commits:** Oracle round 4 verification — gate_overheal downrank penalty, comprehensive spec audits

---

## Verification Fixes (Oracle Round 4)

### gate_overheal Downrank Penalty

**Problem:** `NS.gate_overheal()` did not pass the actual `spell_id` to `HealerDeficit.gate_spell_overheal()`, so the downrank penalty was never applied to overheal calculations. All 13 call sites were passing 4 arguments instead of 5.

**Fix:**
- `core_sylvanas.lua:134`: Added `spell_id` parameter to `NS.gate_overheal()` wrapper
- `healer_deficit_sylvanas.lua:358-363`: Apply `PreemptiveHeal.get_penalty_adjusted_heal(spell_id, size)` when `spell_id` is provided
- Updated all 13 call sites across 4 specs:
  - **Shaman Resto** (2): Pass tiered Healing Wave spell_id (max/mid/low)
  - **Priest Holy** (3): Pass tiered Greater Heal / Flash Heal spell_id
  - **Priest Discipline** (6): Pass tiered GH or fixed spell_id (FH, BH, CoH, PoH)
  - **Paladin Holy** (7): Pass ranked Holy Light / Holy Shock / Flash of Light spell_id

**Safe spell-ID extraction:** Added `_spell_id()` helper to `discipline_sylvanas.lua` and `holy_sylvanas.lua` to handle both production `spell_action` objects (with `:id()` method) and test stubs (plain numbers/tables).

**Test impact:** All 249 rotation + 13 leveling suites pass.

---

## Comprehensive Spec Audits

### 1. Five-Second Mana Rule (FSR)

| Spec | Status | Notes |
|------|--------|-------|
| Priest Holy | ✅ | FSRPause strategy; combat, <35% mana, inside FSR, positive delta |
| Priest Discipline | ✅ | Same pattern; positioned after GreaterHeal |
| Paladin Holy | ✅ | Same pattern; positioned after SmartHeal |
| Shaman Restoration | ✅ | Same pattern; positioned after ChainHeal |
| Druid Restoration | ✅ | Same pattern; positioned after NS+HT |

**Gaps identified:**
- `fsr_manager.choose_downrank()` exists but is **unused** — downranking is inline in each spec
- `fsr_manager.get_cast_opportunity_cost()` exists but is **unused**
- No FSR-aware downranking integration (when FSRPause fires, rotation skips casting instead of falling back to cheaper instant heals)

### 2. APL / wowsims / SimC Alignment

| Category | Count | Status |
|----------|-------|--------|
| DPS specs with wowsims APL alignment | 18/18 | ✅ All aligned |
| Healer specs with APL source | 0/5 | ⚠️ No wowsims healer APLs exist; guide-sourced |
| Formal APL verification docs | 3/29 | ⚠️ Only Arms, Combat, Shadow have `docs/apl-verification-*.md` |
| Broken docs entry | 1 | ✅ Fixed Fury TBC priority list in `docs/rotations/warrior.md` |

**Key finding:** wowsims/tbc-new has **no APL directories for healer specs** — healing is not APL-modeled. Healer specs are sourced from Icy Veins / Warcraft Tavern / class Discord guides.

### 3. API / apidocs Compliance

| Check | Result |
|-------|--------|
| `menu.x:get()` unguarded | ✅ **Zero matches** across all files |
| `math.sqrt` in production | ✅ **Zero matches** |
| Banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`) | ✅ **Zero matches** in production |
| `core.object_manager.get_local_player` in specs | ✅ **Zero matches** — only in framework/shared fallbacks |
| Pattern 14 (nil-guarded state) | ✅ All 29 specs use `spec_kit.safe_state()` |
| Pattern 15 (file headers) | ✅ All 29 specs have WHAT/WHEN/WHY/SAFETY headers |
| Pattern 16 (spec_kit adoption) | ✅ All 29 specs use `spec_kit.define_action_for_class()` |

**Gaps:** 4 helper modules lack Pattern 15 headers (non-critical).

### 4. IZI SDK Usage

| Check | Result |
|-------|--------|
| Specs with direct `require("common/izi_sdk")` | 2/29 (warlock/affliction, warlock/demonology) |
| Specs using `NS.try_cast()` | 29/29 ✅ |
| Specs using raw `core.input.cast_target_spell()` | 0/29 ✅ |

**Key finding:** All casting goes through `NS.try_cast()`, which internally uses IZI as its primary backend (per `core_sylvanas.lua:2288-2301`). Specs do not need to import IZI directly unless using specialized features like `izi.pet()` or `izi.spread_dot()`.

---

## Files Changed

### Modified Spec Files
- `EaxRotations/classes/shaman/restoration_sylvanas.lua` — gate_overheal spell_id
- `EaxRotations/classes/priest/holy_sylvanas.lua` — gate_overheal spell_id
- `EaxRotations/classes/priest/discipline_sylvanas.lua` — gate_overheal spell_id + `_spell_id()` helper
- `EaxRotations/classes/paladin/holy_sylvanas.lua` — gate_overheal spell_id + `_spell_id()` helper

### Modified Core/Shared
- `EaxRotations/core_sylvanas.lua` — `gate_overheal` signature adds `spell_id`
- `EaxRotations/shared/healer_deficit_sylvanas.lua` — downrank penalty application

### Modified Docs
- `docs/rotations/warrior.md` — fixed Fury TBC priority list (was "1. Fury:")

---

## Verification Checklist

- [x] `luac -p` passes on all modified files
- [x] `lua EaxRotations/tests/run_rotation_tests.lua` — 249/249 PASS
- [x] `lua EaxRotations/tests/run_leveling_tests.lua` — 13/13 PASS
- [x] No deprecated API usage introduced
- [x] All menu references nil-guarded
- [x] Pattern 14 compliance verified (spec_kit.safe_state)

---

*Generated: 2026-07-09*

### New Shared Modules

#### `shared/fsr_manager_sylvanas.lua` (149 lines)
- Tracks last mana-consuming cast time
- Provides `is_inside_fsr()`, `seconds_until_fsr()`, `get_regen_delta()`
- `should_pause_for_fsr(state, context)` — recommends casting pause when regen value exceeds heal urgency
- `get_cast_opportunity_cost(cast_time)` — quantifies mana lost by staying inside FSR
- `choose_downrank(ranks, target_deficit, state)` — mana-based rank selection helper
- Lazy-loads `core.spell_book.get_base_power_regen` / `get_casting_power_regen` APIs
- Exported as `NS.FsrManager`

#### `shared/hit_cap_tracker_sylvanas.lua` (96 lines)
- Static TBC hit/expertise/haste thresholds (no dynamic API queries)
- `get_hit_cap(spec_key)` — returns pct_needed, rating_needed for 12 spec roles
- `get_expertise_cap()` — soft (26 expertise) and hard (56 expertise) caps
- `is_hit_capped()`, `is_expertise_soft_capped()`, `should_caution_missable()` — boolean helpers
- `summary()` — human-readable debug string
- Exported as `NS.HitCapTracker`

---

## Spec Changes

### Healer Specs — FSR Integration

All 5 healer specs modified:

| Spec | Schema Fields Added | FSRPause Strategy | Notes |
|------|--------------------|--------------------|-------|
| Druid Resto | `fsr_inside`, `fsr_seconds`, `fsr_regen_delta` | Yes | Inserted after emergency healing tier |
| Paladin Holy | `fsr_inside`, `fsr_seconds`, `fsr_regen_delta` | Yes | Before SmartHeal strategy |
| Priest Discipline | `fsr_inside`, `fsr_seconds`, `fsr_regen_delta` | Yes | Before GreaterHeal strategy |
| Priest Holy | `fsr_inside`, `fsr_seconds`, `fsr_regen_delta` | Yes | Before FlashHeal strategy |
| Shaman Resto | `fsr_inside`, `fsr_seconds`, `fsr_regen_delta` | Yes | Before SmartHeal strategy |

**Pattern:** Each spec:
1. Requires `shared/fsr_manager_sylvanas.lua` at module load
2. Adds FSR fields to schema (RESTO_SCHEMA / HOLY_SCHEMA / DISC_SCHEMA)
3. Populates fields in `build_state()` via `FsrManager.is_inside_fsr()` etc.
4. Adds `FSRPause` strategy with emergency-safe gating (mana < 35%, inside FSR, regen delta > 0)

### Shaman Resto — Downranking Expansion

**New constants:**
```lua
HEALING_WAVE_MAX = 25396       -- Rank 12
HEALING_WAVE_CONSERVE = 25391  -- Rank 11
HEALING_WAVE_EFFICIENT = 25357 -- Rank 10
LESSER_HEALING_WAVE_MAX = 25420
LESSER_HEALING_WAVE_CONSERVE = 10468
```

**Modified functions:**
- `healing_way_execute()` — tiered rank selection based on `state.mana_pct`
- FriendlyTarget execute — tiered rank selection based on `state.mana_pct`

### DPS Specs — Hit Cap Tracker Wiring

**Arms Warrior:**
- Requires `shared/hit_cap_tracker_sylvanas.lua`
- Schema fields: `hit_cap_pct`, `hit_cap_rating_needed`, `expertise_soft_cap`, `expertise_hard_cap`
- `build_state()` populates from `HitCap.get_hit_cap("warrior_melee")` and `HitCap.get_expertise_cap()`

**Combat Rogue:**
- Same pattern as Arms Warrior
- Uses `HitCap.get_hit_cap("rogue_melee")`

---

## Test Changes

### Updated Test Files

| File | Change | Reason |
|------|--------|--------|
| `test_holy_priest_feature_gaps.lua` | expected_count 33 → 34 | FSRPause strategy added |
| `test_discipline_feature_gaps.lua` | expected_count 33 → 34 | FSRPause strategy added |

### Test Results
```
Rotation Tests:  249/249 PASS
Leveling Tests:   13/13 PASS
Total:           262/262 PASS
```

---

## API Usage Verification

### Verified API Patterns

| Pattern | File | Status |
|---------|------|--------|
| `core.spell_book.get_base_power_regen` | `fsr_manager_sylvanas.lua` | Lazy-loaded via pcall |
| `core.spell_book.get_casting_power_regen` | `fsr_manager_sylvanas.lua` | Lazy-loaded via pcall |
| `spec_kit.safe_state(state, schema)` | All modified specs | Correct usage |
| `spec_kit.define_action_for_class(SPELLS)` | All modified specs | Correct usage |
| `NS.try_cast(spell, target, label)` | All modified specs | Correct usage |

### Deprecated API Audit

No new deprecated API usage introduced in this change set.

---

## Files Changed

### New Files
- `EaxRotations/shared/fsr_manager_sylvanas.lua`
- `EaxRotations/shared/hit_cap_tracker_sylvanas.lua`

### Modified Spec Files
- `EaxRotations/classes/druid/resto_sylvanas.lua`
- `EaxRotations/classes/paladin/holy_sylvanas.lua`
- `EaxRotations/classes/priest/discipline_sylvanas.lua`
- `EaxRotations/classes/priest/holy_sylvanas.lua`
- `EaxRotations/classes/shaman/restoration_sylvanas.lua`
- `EaxRotations/classes/warrior/arms_sylvanas.lua`
- `EaxRotations/classes/rogue/combat_sylvanas.lua`

### Modified Test Files
- `EaxRotations/tests/test_holy_priest_feature_gaps.lua`
- `EaxRotations/tests/test_discipline_feature_gaps.lua`

### Modified Documentation
- `CHANGELOG.md`

---

## Known Limitations

1. **FSR `on_cast()` not yet wired to spell cast events** — the manager tracks cast time but is not yet called from the actual cast path. This is a future enhancement.
2. **Hit cap tracker uses static thresholds** — does not query actual gear stats. Future enhancement: integrate with `core.spell_book` or item inspection APIs.
3. **Hit cap tracker only wired to 2 DPS specs** — remaining 17 DPS/ caster specs need similar wiring. Arms Warrior and Combat Rogue serve as reference implementations.
4. **Downranking not yet added to Druid Resto** — existing `DownrankHealingTouch` (rank 4 only) preserved; dynamic tiered ranks deferred.

---

## Verification Checklist

- [x] `luac -p` passes on all modified files
- [x] `lua EaxRotations/tests/run_rotation_tests.lua` — 249/249 PASS
- [x] `lua EaxRotations/tests/run_leveling_tests.lua` — 13/13 PASS
- [x] No deprecated API usage introduced
- [x] All menu references nil-guarded
- [x] Pattern 14 compliance verified (spec_kit.safe_state)

---

*Generated: 2026-07-09*
