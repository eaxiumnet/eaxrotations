# Fixed Items Batch Archive — 2026-06-29

**Date**: 2026-06-29
**Verified by**: Manual line-by-line source code inspection
**Status**: All items below are confirmed fixed in codebase (master branch, commit 22273e38)

This file consolidates ~20 items previously documented as "gaps" or "bugs" in various
`plans/` files. A thorough verification pass confirmed they are all already implemented.

---

## Warrior

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Arms `stance_swap_safe` typo | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 (2026-06-26) | `arms_sylvanas.lua` — corrected |
| Arms `ARMS_SCHEMA` scoping | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | Schema moved before `build_state` |
| Arms `mortal_strike_matches` dead rage-cap bypass | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | Condition corrected |
| Berserker Rage fear break (all 3 warrior specs) | `phase-5-supremacy-completion-2026-06-29.md` | Phase 5 (2026-06-28) | `arms_sylvanas.lua:728-748`, `fury_sylvanas.lua:660-667` |
| Death Wish fear break (Arms) | `phase-5-supremacy-completion-2026-06-29.md` | Phase 5 | `arms_sylvanas.lua:728-731` |
| Warrior rage pooling | `flux-import-warrior-rage-pooling.md` | Partial (Phase 4) | `rage_manager_sylvanas.lua`, stance auto-switch, HS/Cleave dump |
| Shield Wall / Last Stand / Spell Reflection | `reference-gap-analysis-filtered.md` | Pre-Phase 5 | `protection_sylvanas.lua` has all three with match functions |

## Druid

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Powershifting (Cat) | `reference-gap-analysis-filtered.md` | Pre-existing | `cat_sylvanas.lua` — `should_powershift`, `EnergyTickTracker` |
| Frenzied Regeneration (Bear) | `reference-gap-analysis-filtered.md` | Pre-existing | `bear_sylvanas.lua` |
| Barkskin (Bear) | `reference-gap-analysis-filtered.md` | Pre-existing | `bear_sylvanas.lua` |
| Innervate (smart targeting) | `AGENTS.md` Pattern 13 | Pre-existing | `balance_sylvanas.lua` + `resto_sylvanas.lua` |

## Hunter

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Cliptracker / auto-shot weave | `reference-gap-analysis-filtered.md` | Pre-existing | `hunter_core_sylvanas.lua` (384 lines) — `can_cast_steady()`, `ms_until_auto()` |
| Melee weaving | `flux-import-hunter-adaptive.md` | Pre-existing | All 3 hunter specs inline |
| Bestial Wrath | `reference-gap-analysis-filtered.md` | Pre-existing | BM + MM specs |
| Feign Death | `reference-gap-analysis-filtered.md` | Pre-existing | All 3 hunter specs |

## Mage

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Ice Barrier (all 3 specs) | `reference-gap-analysis-filtered.md` | Pre-existing | All 3 mage specs |
| Counterspell (all 3 specs) | `reference-gap-analysis-filtered.md` | Pre-existing | `middleware_sylvanas.lua:102` — shared interrupt registration |

## Paladin

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Seal twisting (Ret) | `reference-gap-analysis-filtered.md` | Pre-existing | `retribution_sylvanas.lua` — SoB/SoM/SoC rotation |

## Priest

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Fade automation | `phase-5-supremacy-completion-2026-06-29.md` | Phase 4 | All 3 priest specs |

## Rogue

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Vanish / Evasion / Cloak of Shadows | `reference-gap-analysis-filtered.md` | Pre-existing | All 3 rogue specs |

## Warlock

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| Conflagrate / Incinerate (Destro) | `reference-gap-analysis-filtered.md` | Pre-existing | `destruction_sylvanas.lua` |
| Healthstone automation | `phase-5-supremacy-completion-2026-06-29.md` | Phase 4 | All warlock specs + Shadow Priest |

## Core / Shared

| Item | Where documented | Fixed in | Evidence |
|------|-----------------|----------|----------|
| `get_spell_id` per-frame allocation | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | Static buffer |
| `_context.lowest` per-frame allocation | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | Pre-allocated, mutated in place |
| Duplicate `_settings_cache` | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | Single declaration |
| `filter_spell_ids_for_expansion` no-op | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | Real vanilla filtering |
| BM Hunter global leak | `eaxrotations-deep-review-2026-06-29.md` Phase 1 | Phase 1 | `local` added |
| Enemy cache multi-range | `eaxrotations-deep-review-2026-06-29.md` Phase 4 | Phase 4 | Multi-range per-tick cache |
| Immunity buff cache | `eaxrotations-deep-review-2026-06-29.md` Phase 4 | Phase 4 | Cached in `evaluate_cast` |
| `is_hostile_unit` short-circuit | `eaxrotations-deep-review-2026-06-29.md` Phase 4 | Phase 4 | Short-circuits on `can_attack` false |
| `safe()` pcall overhead | `eaxrotations-deep-review-2026-06-29.md` Phase 4 | Phase 4 | Captured at install time |
| Raw unit comparison crashes | `eaxrotations-cross-class-robustness-sweep.md` | Fixed 2026-06-18 | All bare `==`/`~=` on units replaced with `NS.same_unit` or guards |

## Architecture (In Progress)

| Item | Where documented | Status | Evidence |
|------|-----------------|--------|----------|
| `core/strategy_gating.lua` extraction | `eaxrotations-deep-review-2026-06-29.md` Phase 2 | ✅ Done | File exists, deduplicates strategy tables |
| Dead code cleanup (VANILLA_HIGH_SPELL_ALLOWLIST, etc.) | `eaxrotations-deep-review-2026-06-29.md` Phase 2 | ✅ Done | Removed |
| `cc_is_*` / `unit_is_*` bridge generation | `eaxrotations-deep-review-2026-06-29.md` Phase 2 | ✅ Done | Generated from tables |
| `core/auras.lua` extraction | `eaxrotations-deep-review-2026-06-29.md` Phase 2 | ⏳ Pending | Not started |
| `core/spell_safety.lua` extraction | `eaxrotations-deep-review-2026-06-29.md` Phase 2 | ⏳ Pending | Not started |
| `core/pvp.lua` + `core/cc_immunity.lua` extraction | `eaxrotations-deep-review-2026-06-29.md` Phase 2 | ⏳ Pending | Not started |

---

## Test Baseline

- 208/208 rotation suites: PASS
- 11/11 leveling suites: PASS
- 416 Lua files: 0 syntax errors
- Production banned APIs: 0 found
- Production `math.sqrt` violations: 0 found

---

*This archive exists so future agents do not re-investigate fixed items. If you find
a "gap" listed above, verify against source code before treating it as unfixed.*
