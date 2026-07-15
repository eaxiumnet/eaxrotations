# Implementation Plan: Integrate Advanced Sylvanas Modules into EAX Rotations

**Created:** 2026-07-13
**Scope:** TBC (29 specs) + WotLK (41 files) + Classic/Vanilla variants
**Docs Cache:** `scraped_docs_md/` (gitignored, safeguarded — see `scraped_docs_md/INDEX.md`)
**API Stubs:** `.api/common/modules/` (8 modules: buff_manager, combat_forecast, health_prediction, profiler, settings_manager, spell_prediction, spell_queue, target_selector)

---

## Overview

The 8 advanced Sylvanas modules at `.api/common/modules/` provide combat
forecasting, health prediction, spell prediction (AoE positioning), target
selection, buff management, settings persistence, spell queueing, and profiling.
EAX currently uses **6 of 8** modules but **entirely indirectly** — via NS
helpers and context fields. No spec file calls any module directly.

**This plan converts indirect/wrapper usage into direct, module-aware
integrations** — one spec at a time, one commit per spec, each gated by
`luac -p` + full test suite. The goal: make EAX rotations the most
module-integrated rotation system on Project Sylvanas.

## Current State (from explore agent usage map — 2026-07-13)

| Module | Required at | NS exposure | Specs using directly | Specs using indirectly | Gap |
|--------|------------|-------------|:-------------------:|:---------------------:|-----|
| buff_manager | `core_sylvanas.lua:109` | Not exposed | 0 | All 29 (via `NS.has_buff`→`_aura_query`→`_buff_manager`) | No spec uses bulk aura cache directly |
| combat_forecast | `main_sylvanas.lua:35` | Not exposed (via `context.combat_length_forecast`) | 1 (`destruction_sylvanas:300` via `NS.should_use_long_cd`) | All 29 (context field available but unread) | 24+ specs with ≥60s CDs not gating |
| health_prediction | `main_sylvanas.lua:45` | `NS.health_prediction` | 0 | All 29 (via `context.is_pvp`, `context.party_tanks`) | 7 healer + 3 tank specs missing direct `get_incoming_damage` |
| profiler | **None** | **None** | **0** | **0** | **Universal gap — zero adoption** |
| settings_manager | `core_sylvanas.lua:153` | Not exposed (via `core/settings.lua`→`NS.get_setting`) | 0 | All 29 (via `spec_kit.setting`→`NS.get_setting`) | No adoption gap; advanced features unused |
| spell_prediction | Lazy via `NS.GetAPIModule` | `NS.get_aoe_cast_position()` | 7 (destruction, demonology, affliction, frost, fire, BM, survival) | — | 12+ specs with AoE/heal-AoE not using it |
| spell_queue | `core_sylvanas.lua:130`, `main_sylvanas.lua:126` | `NS.spell_queue` | 0 | All 29 (via `NS.try_cast`) | No spec uses queue priority/label/movement directly |
| target_selector | `main_sylvanas.lua:38` | Not exposed (via `NS.get_targets_heal`) | 0 | All 29 (via `context.enemies`, `context.heal_targets`) | No spec uses `get_targets()`/`get_targets_heal()` directly |

**Shared wrappers that exist:**
- `shared/combat_forecast_gate_sylvanas.lua` → `NS.should_use_long_cd(context, cd)` (wraps combat_forecast)
- `core/settings.lua` → `NS.get_setting`/`NS.set_setting` (wraps settings_manager)
- `core_sylvanas.lua` `NS.get_aoe_cast_position()` (wraps spell_prediction)
- `core_sylvanas.lua` `NS.try_cast()`/`NS.try_cast_position()` (wraps spell_queue)
- `core_sylvanas.lua` `NS.get_targets_heal()` (wraps target_selector)
- `main_sylvanas.lua` `throttled_enemies()` (wraps target_selector for enemy list)

**No shared healer module** (incoming_heal_predictor, preemptive_heal, triage, healer_deficit, hot_tick_tracker, pet_heal) wraps any of the 8 modules directly.

## Docs Reference (scraped 2026-07-13)

| Module | Dev API doc | User guide |
|--------|------------|------------|
| combat_forecast | `scraped_docs_md/dev/libraries/modules/combat-forecast.md` | `scraped_docs_md/modules/combat-forecast.md` |
| health_prediction | `scraped_docs_md/dev/libraries/modules/health-prediction.md` | `scraped_docs_md/modules/health-prediction.md` |
| spell_prediction | `scraped_docs_md/dev/libraries/modules/spell-prediction.md` | — |
| target_selector | `scraped_docs_md/dev/libraries/modules/target-selector.md` | `scraped_docs_md/modules/target-selector.md` |
| buff_manager | `scraped_docs_md/dev/modules/buff-manager.md` | — |
| settings_manager | `scraped_docs_md/dev/modules/settings-manager.md` | — |
| spell_queue | `scraped_docs_md/dev/modules/spell-queue.md` | `scraped_docs_md/modules/spell-queue.md` |
| profiler | (stub only at `.api/common/modules/profiler.lua`) | — |

---

## Phased Task List

### Phase 1: Universal CD Gating (combat_forecast) — HIGHEST IMPACT

**Why first:** 24+ specs have long-cooldown abilities that fire regardless of
fight length. The wrapper `NS.should_use_long_cd(context, cd_seconds)` already
exists and is proven by `destruction_sylvanas:300`. Each integration is a
1-3 line gate added before an existing CD cast — minimal risk, maximal value.

**Template (corrected after Oracle review — the helper takes the SPELL's actual cooldown, not a min-TTD):**
```lua
if NS.should_use_long_cd and not NS.should_use_long_cd(context, SPELL_CD_SECONDS) then
    return false
end
```

**⚠️ Oracle correction (2026-07-13):** The helper `should_use_long_cd(context, spell_cooldown_seconds)` uses the spell's ACTUAL cooldown to determine thresholds:
- `>= 180s` CD → blocked if forecast < 60s
- `>= 120s` CD → blocked if forecast < 45s
- `>= 60s` CD → blocked if forecast < 30s
- `< 60s` CD → never blocked (trivial)

**Also:** abilities already gated by `gate_cooldown_boss_only` are redundant with the forecast gate (bosses always return `true`). Only add the gate to NON-boss-gated offensive CDs.

**Tasks (one per spec, one commit each):**

| Task | Spec file | Spell to gate | Spell CD (s) | Already boss-gated? | Status |
|------|-----------|---------------|:------------:|:-------------------:|:------:|
| 1.1 | `warrior/arms_sylvanas.lua` | Retaliation | 1800 | No | ✅ DONE |
| 1.2 | `warrior/fury_sylvanas.lua` | Recklessness | 1800 | Yes — skip (redundant) | N/A |
| 1.3 | `warrior/protection_sylvanas.lua` | Shield Wall | 1800 | No (defensive) | ✅ DONE |
| 1.4 | `paladin/retribution_sylvanas.lua` | Avenging Wrath | 180 | No | ✅ DONE |
| 1.5 | `paladin/holy_sylvanas.lua` | Divine Illumination | 180 | No | ✅ DONE |
| 1.6 | `paladin/protection_sylvanas.lua` | Avenging Wrath | 180 | No | ✅ DONE |
| 1.7 | `hunter/beast_mastery_sylvanas.lua` | Rapid Fire | 300 | No | ✅ DONE |
| 1.8 | `hunter/marksmanship_sylvanas.lua` | Rapid Fire | 300 | No | ✅ DONE |
| 1.9 | `hunter/survival_sylvanas.lua` | Rapid Fire | 300 | No | ✅ DONE |
| 1.10 | `mage/arcane_sylvanas.lua` | Arcane Power | 180 | Yes — skip | N/A |
| 1.11 | `mage/fire_sylvanas.lua` | Combustion | 180 | Yes — skip | N/A |
| 1.12 | `mage/frost_sylvanas.lua` | Icy Veins | 180 | Yes — skip | N/A |
| 1.13 | `warlock/destruction_sylvanas.lua` | Curse of Doom | 120 | Yes — skip | N/A |
| 1.14 | `priest/shadow_sylvanas.lua` | Shadowfiend | 300 | No | ✅ DONE |
| 1.15 | `priest/discipline_sylvanas.lua` | Power Infusion | 180 | No | ✅ DONE |
| 1.16 | `rogue/subtlety_sylvanas.lua` | Preparation | 600 | No | ✅ DONE |
| 1.17 | `shaman/restoration_sylvanas.lua` | Bloodlust | 600 | No | ✅ DONE |
| 1.18 | `shaman/enhancement_sylvanas.lua` | Bloodlust | 600 | No | ✅ DONE |
| 1.19 | `shaman/elemental_sylvanas.lua` | Bloodlust | 600 | Yes — skip | N/A |

**Verify per task:** `luac -p <spec_file>` + `lua EaxRotations/tests/run_rotation_tests.lua` (all suites pass)

### Phase 2: Health Prediction Direct API (healer + tank specs)

**Why:** Healer specs currently rely on context fields (`is_pvp`, `party_tanks`)
but never call `health_prediction:get_incoming_damage(target, deadline)`
directly. This limits predictive healing to the coarse context-level data. Direct
access enables per-target incoming-damage-aware heal sizing.

**New shared wrapper needed:** `shared/health_pred_helper_sylvanas.lua`
- Exposes `NS.incoming_damage(unit, seconds)` → wraps `NS.health_prediction:get_incoming_damage`
- Exposes `NS.predicted_hp_pct(unit, seconds)` → computes future HP % after incoming damage
- Exposes `NS.is_tank_role(unit)` → wraps `NS.health_prediction:is_tank`
- Nil-guarded (returns 0 / 100 / false if module unavailable)

| Task | Spec file | Integration | Status |
|------|-----------|-------------|:------:|
| 2.0 | `shared/health_pred_helper_sylvanas.lua` | Create shared helper wrapping `NS.health_prediction` | ✅ DONE |
| 2.1 | `priest/holy_sylvanas.lua` | `HealthPred.predicted_hp_pct` in EmergencyFlashHeal | ✅ DONE |
| 2.2 | `priest/discipline_sylvanas.lua` | `HealthPred.predicted_hp_pct` in pws_tank_matches | ✅ DONE |
| 2.3 | `paladin/holy_sylvanas.lua` | Use `NS.incoming_damage` for FoL vs HL selection | TODO |
| 2.4 | `druid/resto_sylvanas.lua` | Use `NS.predicted_hp_pct` for Lifebloom refresh | TODO |
| 2.5 | `shaman/restoration_sylvanas.lua` | `HealthPred.predicted_hp_pct` in smart_heal_matches | ✅ DONE |
| 2.6 | `warrior/protection_sylvanas.lua` | Use `NS.incoming_damage` for Shield Block pre-cast | TODO |
| 2.7 | `paladin/protection_sylvanas.lua` | Use `NS.incoming_damage` for Holy Shield pre-cast | TODO |
| 2.8 | `druid/bear_sylvanas.lua` | Use `NS.incoming_damage` for Frenzied Regen | TODO |

### Phase 3: Spell Prediction for Healer AoE + Missing DPS AoE

**Why:** 7 DPS specs already use `NS.get_aoe_cast_position` for AoE positioning.
12+ specs with AoE abilities (including all healers with positional AoE heals
like Chain Heal, Prayer of Healing) do NOT. The `is_heal=true` parameter is
ready but unused.

| Task | Spec file | Spell | Integration | Status |
|------|-----------|-------|-------------|:------:|
| 3.1 | `shaman/restoration_sylvanas.lua` | Chain Heal | Chain Heal is smart-targeted (jumps), not ground-positioned — N/A | N/A |
| 3.2 | `priest/holy_sylvanas.lua` | Prayer of Healing | PoH is party-based (targets your own party), not ground-positioned — N/A | N/A |
| 3.3 | `priest/discipline_sylvanas.lua` | Prayer of Healing | Same as 3.2 — party-based, N/A | N/A |
| 3.4 | `druid/balance_sylvanas.lua` | Hurricane | `NS.get_aoe_cast_position` in Hurricane execute for optimal ground positioning | ✅ DONE |
| 3.5 | `priest/shadow_sylvanas.lua` | Mind Sear | Not in TBC (Mind Sear is WotLK-only) — N/A | N/A |
| 3.6 | `shaman/elemental_sylvanas.lua` | Fire Nova Totem | Totem placement is player-centered, not ground-targeted — N/A | N/A |
| 3.7 | `shaman/enhancement_sylvanas.lua` | Fire Nova Totem | Same as 3.6 — N/A | N/A |

**Phase 3 Note:** Most healer AoE heals in TBC are party-based (PoH) or smart-jumping (Chain Heal), not ground-targeted. Only balance Hurricane was a valid integration target. The `is_heal=true` parameter in `get_aoe_cast_position` is available for future ground-targeted healing spells (e.g., WotLK Wild Growth area selection).

### Phase 4: Target Selector Direct Queries (multi-DoT + healer triage)

**Why:** No spec calls `target_selector:get_targets()` or `:get_targets_heal()`
directly. Multi-DoT specs (affliction, shadow, balance) could use custom enemy
filtering by TTD/HP. Healer specs could use `get_targets_heal(threshold)` for
triage-targeted healing instead of relying on the generic context.heal_targets.

**New shared wrapper needed:** `shared/ts_helper_sylvanas.lua`
- Exposes `NS.get_dps_targets(limit)` → wraps `target_selector:get_targets(limit)` (requires require in spec or via NS)
- Exposes `NS.get_heal_targets(limit)` → wraps `target_selector:get_targets_heal(limit)` (already exists as `NS.get_targets_heal`)

| Task | Spec file | Integration | Acceptance |
|------|-----------|-------------|------------|
| 4.1 | `warlock/affliction_sylvanas.lua` | Use direct target query for multi-DoT priority (lowest HP target gets Agony first) | Test: DoT priority by HP; suite passes |
| 4.2 | `priest/shadow_sylvanas.lua` | Use direct target query for SW:P/VT multi-DoT | Test: DoT priority by HP; suite passes |
| 4.3 | `druid/balance_sylvanas.lua` | Use direct target query for Moonfire/IS multi-DoT | Test: DoT priority by HP; suite passes |
| 4.4 | `priest/holy_sylvanas.lua` | Use `NS.get_targets_heal(3)` for custom triage target selection | Test: triage picks lowest HP target; suite passes |
| 4.5 | `shaman/restoration_sylvanas.lua` | Use `NS.get_targets_heal(3)` for Chain Heal target selection | Test: Chain Heal targets lowest HP cluster; suite passes |

### Phase 5: Buff Manager Bulk Aura Access (multi-DoT + party buff scanning)

**Why:** All specs use `buff_manager` indirectly via `NS.has_buff` (per-unit,
per-buff). For multi-DoT tracking (affliction: Corr/Agony/SL on N targets),
`buff_manager:get_debuff_cache(target)` returns ALL debuffs in one call —
faster than N separate `NS.has_target_debuff` calls.

| Task | Spec file | Integration | Acceptance |
|------|-----------|-------------|------------|
| 5.1 | `warlock/affliction_sylvanas.lua` | Use `buff_manager:get_debuff_cache(target)` to scan all DoTs in one call for multi-DoT refresh logic | Test: DoT refresh checks all debuffs in 1 call; suite passes |
| 5.2 | `priest/shadow_sylvanas.lua` | Use `buff_manager:get_debuff_cache(target)` for SW:P/VT scan | Test: DoT scan uses bulk cache; suite passes |
| 5.3 | `paladin/holy_sylvanas.lua` | Use `buff_manager:get_buff_cache(unit)` for party-wide buff check (Fortitude, Spirit, Fear Ward) | Test: buff scan uses bulk cache; suite passes |

### Phase 6: Profiler Integration (performance diagnostics)

**Why:** `profiler` has **zero adoption** — not required anywhere. It provides
`profiler.start(key)` / `profiler.stop(key, is_failed)` for per-strategy timing.
Useful for diagnosing which strategies are expensive in heavy specs.

**This is opt-in diagnostics, not rotation behavior.** Gate behind a debug flag.

| Task | Spec file | Integration | Acceptance |
|------|-----------|-------------|------------|
| 6.0 | `shared/profiler_helper_sylvanas.lua` | Create shared helper: `NS.profile_start(key)`, `NS.profile_stop(key, ok)` — nil-guarded, no-op if module unavailable | `luac -p` passes |
| 6.1 | `warlock/affliction_sylvanas.lua` | Wrap top 3 heaviest strategies with profiler start/stop behind `NS.setting(context, "debug_profile", false)` flag | Test: profiler no-op when flag off; suite passes |
| 6.2 | `priest/holy_sylvanas.lua` | Wrap healing target scan with profiler | Test: same; suite passes |

### Phase 7: Spell Queue Direct Access (interrupts + shot rotation + Slam weave)

**Why:** All specs use `spell_queue` indirectly via `NS.try_cast`. Direct access
to `spell_queue:queue_spell_target(id, target, priority, message, allow_movement)`
enables:
- Interrupt middlewares with explicit priority labels
- Shot rotation with movement-allow flags
- Slam weaving with swing-timer-aware queue labels

| Task | Spec file | Integration | Acceptance |
|------|-----------|-------------|------------|
| 7.1 | `warrior/middleware_sylvanas.lua` (or class-level) | Use `NS.spell_queue:queue_spell_target_fast(pummel_id, target, 7, "Pummel interrupt")` for interrupt priority | Test: interrupt queues at priority 7; suite passes |
| 7.2 | `hunter/marksmanship_sylvanas.lua` | Use `NS.spell_queue:queue_spell_target(shot_id, target, 1, "Auto-Shot", true)` with `allow_movement=true` for shot rotation | Test: shot queue allows movement; suite passes |
| 7.3 | `warrior/arms_sylvanas.lua` | Use `NS.spell_queue:queue_spell_target(slam_id, target, 1, "Slam weave", false)` with `allow_movement=false` for Slam timing | Test: Slam queue blocks movement during swing window; suite passes |

### Phase 8: WotLK Spec Module Integration

**Why:** 41 WotLK spec files exist. They follow the same `spec_kit` pattern as
TBC but also do NOT use any of the 8 modules directly. The same gaps apply.

**Approach:** After TBC phases 1-7 are proven, apply the same templates to WotLK
specs. The WotLK specs have different spell IDs but the same module integration
patterns. Priority: combat_forecast gating on all WotLK DPS specs with long CDs.

| Task | Spec file | Integration | Acceptance |
|------|-----------|-------------|------------|
| 8.1 | `warrior/arms_wotlk.lua` | Add `should_use_long_cd` gate to Bladestorm (90s CD) | `luac -p` + `run_wotlk_tests.lua` pass |
| 8.2 | `paladin/retribution_wotlk.lua` | Add `should_use_long_cd` gate to Avenging Wrath | `luac -p` + wotlk tests pass |
| 8.3 | `mage/arcane_wotlk.lua` | Add `should_use_long_cd` gate to Arcane Power + Presence of Mind | wotlk tests pass |
| 8.4 | `deathknight/blood_wotlk.lua` | Add `should_use_long_cd` gate to Dancing Rune Weapon | wotlk tests pass |
| 8.5 | `deathknight/frost_wotlk.lua` | Add `should_use_long_cd` gate to Hungering Cold | wotlk tests pass |
| 8.6 | `deathknight/unholy_wotlk.lua` | Add `should_use_long_cd` gate to Summon Gargoyle | wotlk tests pass |
| 8.7-8.X | Remaining WotLK specs | Apply combat_forecast + spell_prediction + health_prediction per spec need | Per-spec wotlk tests pass |

### Phase 9: Classic/Vanilla Variant Module Integration

**Why:** Vanilla variant files (`*_vanilla.lua`) have the same module gaps.
Apply combat_forecast gating to vanilla specs with long CDs.

**Lower priority** — vanilla variants are secondary to TBC/WotLK.

---

## Shared Module Creation Summary

| New shared module | Phase | Wraps | Purpose |
|-------------------|:-----:|-------|---------|
| `shared/health_pred_helper_sylvanas.lua` | 2 | health_prediction | `NS.incoming_damage`, `NS.predicted_hp_pct`, `NS.is_tank_role` |
| `shared/ts_helper_sylvanas.lua` | 4 | target_selector | `NS.get_dps_targets`, (extends `NS.get_targets_heal`) |
| `shared/profiler_helper_sylvanas.lua` | 6 | profiler | `NS.profile_start`, `NS.profile_stop` (nil-guarded no-op) |

## Verification Protocol (every task)

1. `luac -p <modified_file>` — syntax check
2. `lua EaxRotations/tests/run_rotation_tests.lua` — all rotation suites pass (TBC)
3. `lua EaxRotations/tests/run_leveling_tests.lua` — all leveling suites pass
4. `lua EaxRotations/tests/run_wotlk_tests.lua` — all WotLK suites pass (for WotLK tasks)
5. `lsp_diagnostics <modified_file>` — 0 errors
6. Verify the integration is nil-guarded (module unavailable → graceful fallback to existing behavior)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Module unavailable at runtime (API stub vs real) | High | ALL integrations must be nil-guarded: `if NS.health_prediction and NS.health_prediction:get_incoming_damage then ... end` — fallback to existing context-field logic |
| Test mocks don't have module objects | Medium | Tests already mock `NS.health_prediction`, `NS.spell_queue` etc. — verify mock coverage before adding direct calls |
| Performance regression from direct module calls | Low | Modules are cached; `buff_manager` has built-in cache; `health_prediction` is O(1); `spell_prediction` already lazy-loaded |
| WotLK specs use different spell IDs | Medium | Each WotLK task verifies spell IDs against WotLK data before integration |
| Profiler overhead when enabled | Low | Gate behind debug flag; no-op when disabled; `profiler.start/stop` is lightweight |

## Priority Order (by impact × ease)

1. **Phase 1** (combat_forecast CD gating) — 24 tasks, 1-3 lines each, proven template. START HERE.
2. **Phase 2** (health_prediction direct API) — 8 tasks, requires 1 new shared helper. Highest value for healers.
3. **Phase 3** (spell_prediction for missing AoE) — 7 tasks, extends proven `NS.get_aoe_cast_position`.
4. **Phase 8** (WotLK combat_forecast) — parallel to Phase 1, different test runner.
5. **Phase 4** (target_selector direct) — 5 tasks, requires 1 new shared helper.
6. **Phase 5** (buff_manager bulk scan) — 3 tasks, performance optimization.
7. **Phase 7** (spell_queue direct) — 3 tasks, specialized use cases.
8. **Phase 6** (profiler) — 2 tasks, diagnostics only. Lowest priority.
9. **Phase 9** (vanilla variants) — lowest priority.

## Follow-Up

Each phase produces atomic commits. After all Phase 1 tasks, run full regression:
`lua EaxRotations/tests/run_rotation_tests.lua` + `run_leveling_tests.lua` +
`run_wotlk_tests.lua` — all must pass. Update `plans/_active.md` after each phase
completion.
