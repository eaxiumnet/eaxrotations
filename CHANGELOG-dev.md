# Developer Changelog — EaxRotations v2.6.0

**Date:** 2026-07-09
**Branch:** main
**Commits:** FSR integration, downranking expansion, hit cap tracker

---

## Architecture Changes

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
