# Developer Changelog — EaxRotations v2.10.0

**Date:** 2026-07-16  
**Scope:** TBC Anniversary Phase 2 — 1–70 spell ladders + Solo/Group/Dungeon/Raid-70 for all 9 classes

### Infrastructure
- **New** `tests/tbc_ladder_helper.lua` — TBC LEARN map (Steady 50, KC 66, BT/MS 40, Mangle 50, VT 50, SF 66, SS 40, AB 64, …) + level-aware `spell_ready`/`spell_exists`/`is_spell_learned`
- **New** `tests/test_tbc_spell_ladders.lua` — **281** cases at L10/25/40/60/70; content modes; ≥3–5 settings/class; group overwrite; raid-70 strategy index
- Registered in `run_rotation_tests.lua`
- Matrix: `plans/tbc-deep-audit-matrix-2026-07-16.md`

### Production
- `cat_sylvanas`: **FIX** `MangleDebuff` soft-gate via `spell_exists(ACTION.MangleCat)` so L10–40 cat is not dead when Mangle unlearned

---
# Developer Changelog — EaxRotations v2.9.2

**Date:** 2026-07-16  
**Scope:** Phase 2 skeptic — per-class settings (3–5 keys) + group overwrite + paladin raid-60 prio

### Production
- `fury_vanilla`: Sunder/Demo honor `sunder_armor_mode` / `use_sunder_armor` / `maintain_demo_shout`
- `affliction_vanilla`: `warlock_curse_mode` + `warlock_assigned_curse` gates CoE/Agony/Doom (group overwrite)

### Tests
- `test_vanilla_spell_ladders` **236** cases: ≥3–5 settings per class; curse/seal/shout overwrite; paladin ret/prot/holy prio
- Matrix G cells cite real test names (warrior Sunder/Demo no longer claim-only)

---
# Developer Changelog — EaxRotations v2.9.1

**Date:** 2026-07-16  
**Scope:** Skeptic hardening for Phase 2 content modes / settings / raid-60 prio

### Tests
- Dungeon AoE cases **required** (MultiShot, Cleave/SS, Consecration must match)
- Fury Cleave asserts `res == true`
- Settings flip: use_cooldowns, multishot_mode, use_scorch_debuff, aff_use_amplify_curse, prot_consecration
- Raid-60 strategy index order vs wowsims classic (9 classes)
- spec_kit mock honors `context.settings`

### Matrix
- All S/G/D/R cells filled (no "—"); Mage/Rogue complete

---
# Developer Changelog — EaxRotations v2.9.0

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** Classic Vanilla Phase 2 — all 9 classes 1–60 spell ladders

### Infrastructure
- **New** `tests/vanilla_ladder_helper.lua` — LEARN min-level map (Classic Era) + `spell_ready`/`spell_exists`/`is_spell_learned` filter; captures `get_state` via registry; class-gated loaders
- **New** `tests/test_vanilla_spell_ladders.lua` — **175** cases across Hunter/Warrior/Warlock/Mage/Rogue/Shaman/Priest/Paladin/Druid at L10/25/40/60

### Ladder proofs
- At L10 with endgame talents unlearned: at least one combat filler matches (real `matches` / `build_state`)
- Negative controls: Aimed L10, Bloodthirst L25, Conflagrate L25, Stormstrike L25, HolyShield L25, SW:D/Shadowfiend L60 blocked
- Content smokes: hunter pet Mend, fury multi Cleave, no FelArmor on Classic destro
- Cat ladder starts L25 (Cat Form L20) — documented WATCH for B1

### Code
- `cat_vanilla.lua`: CP threshold uses `level or 60` (not 70)

### Verification
- 279 rotation + 18 leveling suites green
- Matrix: `plans/vanilla-deep-audit-matrix-2026-07-16.md` updated

---

# Developer Changelog — EaxRotations v2.8.0

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** Deep Classic Vanilla 1–60 audit harness + level-default / pre-Aimed fixes

### Why this release
v2.7.9 was an endgame-priority pass only. v2.8.0 starts the **deep 1–60 + content-mode** audit: all **40** Vanilla ships (`*_vanilla.lua` combat + leveling), API-aware loading via class gates (`.api` / `scraped_docs_md` contracts), and material silent-gate fixes.

### Matrix
- `plans/vanilla-deep-audit-matrix-2026-07-16.md` — 40-file inventory, level bands, content modes

### Code
| File | Change |
|------|--------|
| `shared/leveling_helpers_sylvanas.lua` | `vanilla_level_from_context` (default **60**) |
| `hunter/marksmanship_vanilla.lua` | Pre-Aimed filler ladder (no Steady; default level 60) |
| `hunter/survival_vanilla.lua` | Same pre-Aimed ladder |
| `druid/cat|bear|caster_vanilla.lua` | Level default 70→60 |
| `rogue/assassination_vanilla.lua` | Level default 70→60 |

### Tests
- **New** `test_vanilla_content_coverage.lua` — loads all 40 Vanilla modules under class-correct mocks; BM/Destro band smokes
- 278 rotation + 18 leveling suites green

### API
- No new runtime APIs; mocks align with class-gated loaders (`get_class` / `CLASS_ID`) and `get_spell_id` used by kebab/holy paths.

---

# Developer Changelog — EaxRotations v2.7.9

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** Classic Vanilla (1.15) 31-spec guide/APL re-verification + material fixes

### Gap matrix
- New: `plans/vanilla-rotation-gap-matrix-2026-07-16.md` (all 31 combat `*_vanilla.lua` specs)

### Material code fixes
| File | Change |
|------|--------|
| `classes/hunter/beast_mastery_vanilla.lua` | Aimed Shot primary (wowsims classic hunter p1); Arcane yields when Aimed ready |
| `classes/hunter/survival_vanilla.lua` | Aimed Shot before Multi/Arcane |
| `classes/warlock/destruction_vanilla.lua` | SoulFire execute-gated (shard + HP); Shadowburn above SoulFire/ShadowBolt |

### Tests
- `test_hunter_vanilla_aimed_shot.lua` — priority index + matches
- `test_destruction_vanilla_soul_fire_execute.lua` — execute gate + order
- Updated nil-guard strategy lists for hunter/warlock vanilla

### Verification
- `luac -p` on changed Lua
- `run_rotation_tests.lua` → 277/277
- `run_leveling_tests.lua` → 18/18
- Version: **2.7.9** (header, VERSION.txt, README badge)

---

# Developer Changelog — EaxRotations v2.7.8

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** TBC 29-spec guide/APL re-verification + Destruction Shadowburn priority fix

### Gap matrix
- New: `plans/tbc-rotation-gap-matrix-2026-07-16.md`
- Covers all 29 TBC combat specs vs wowsims `data/tbc-new` APLs, prior research report, Icy Veins / Wowhead / Warcraft Tavern for healers + Fire/Frost
- Tie-breakers: DBC spell truth; wowsims APL for PvE DPS priority when present

### Material code fix
| File | Change |
|------|--------|
| `classes/warlock/destruction_sylvanas.lua` | Move `Shadowburn` above `Incinerate`/`ShadowBolt` fillers (wowsims `destro_fire.apl.json`) |
| `tests/test_destruction_shadowburn.lua` | Assert strategy priority index + existing execute gates |

### Verification
- `luac -p` on changed Lua
- `lua EaxRotations/tests/run_rotation_tests.lua` → 275/275
- `lua EaxRotations/tests/run_leveling_tests.lua` → 18/18
- Version surfaces: `header.lua` / `VERSION.txt` → **2.7.8**

---

# Developer Changelog — EaxRotations v2.7.7

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** `fix(bear)` Maul next-swing re-queue spam + swing timer correct clocks

### Root causes (live logs after v2.7.6)

| Symptom | Cause |
|---------|--------|
| `Maul \| Target …` every frame | No `is_current_spell` gate; next-swing re-queued each dispatcher tick |
| `absurd remains≈72691 clamped` | `swing_time_until` used `get_current_combat_core_time()` (combat-relative) vs absolute `get_next_attack_core_time` |

### Code

| File | Change |
|------|--------|
| `core_sylvanas.lua` | `swing_time_until` / `swing_time_since` / `swing_progress`: core now via `NS.time_now`, game-time fallback, absurd clamp; `get_time_until_swing` delegates |
| `classes/druid/bear_sylvanas.lua` | `maul_is_queued()` via `is_current_spell` ranks; `maul_execute` with `min_interval=0.5` |
| `tests/test_bear_custom_matches.lua` | Maul already-queued assertion |
| version / zip | **2.7.7** |

### Verification

- `luac -p` + `test_bear_custom_matches` + `test_melee_cleu_wiring` + 275 rotation suites

---

# Developer Changelog — EaxRotations v2.7.6

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** `fix(bear)` Swipe self-target spam, form-breaking OOC buffs, swing timer sanity + release

### Root causes (live logs)

| Symptom | Cause |
|---------|--------|
| `Swipe \| Target Rarbarber` spam | `Swipe`/`SwipeAoE` used `target="self"`; `execute_action` cast on player; client reject → rematch loop |
| `BearForm` / `MotW` / `Thorns` thrash | MotW/Thorns OOC matches did not check `is_bear`; caster buffs cancel form |
| `[SwingTimer] FALLBACK … remains=69598` | `auto_attack_helper` next/now on mismatched time bases |

### Code

| File | Change |
|------|--------|
| `classes/druid/bear_sylvanas.lua` | Swipe on enemy target; MotW/Gift/Thorns blocked in bear; BearForm post-cast lockout |
| `classes/druid/bear_vanilla.lua` | Same Swipe + MotW/Thorns guards |
| `classes/druid/leveling_sylvanas.lua` | Swipe `try_cast(..., context.target)` (nil → self in core) |
| `classes/druid/leveling_vanilla.lua` | Same Swipe target fix |
| `core_sylvanas.lua` | `swing_time_until` clamp remains > 12s → 999 |
| `tests/test_bear_custom_matches.lua` | Enemy-target Swipe + MotW/Thorns bear block |
| `header.lua` / `VERSION.txt` / README badge | Version **2.7.6** |
| `eaxrotations.zip` | Rebuild: **.lua + .md only** from `EaxRotations/` |

### Verification

- `luac -p` on changed Lua
- `lua EaxRotations/tests/test_bear_custom_matches.lua` PASS
- `lua EaxRotations/tests/run_rotation_tests.lua` 274/274
- `lua EaxRotations/tests/run_leveling_tests.lua` 18/18

---

# Developer Changelog — EaxRotations v2.7.5

**Date:** 2026-07-16  
**Branch:** master  
**Scope:** `fix(bear)` low-level spender gates + release artifact

### Code

| File | Change |
|------|--------|
| `classes/druid/bear_sylvanas.lua` | Pre-Mangle Maul: `min(menu maul_rage, level_scaled)`; Swipe cleave: Lacerate stack gate only if `spell_exists(Lacerate)`; Demo Roar: skip single-target trash when `target_hp <= 20` or `ttd < 10`; `state.level` from context |
| `classes/druid/schema_sylvanas.lua` | `bear_maul_rage` tooltip for auto-scale |
| `tests/test_bear_custom_matches.lua` | Pre-Mangle / pre-Lacerate / Demo HP+TTD cases |
| `header.lua` / `VERSION.txt` / README badge | Version **2.7.5** |
| `eaxrotations.zip` | Rebuild: **.lua + .md only** from `EaxRotations/` |

### Design notes

- Endgame tank APL unchanged when Mangle is learned (`bear_maul_rage` default 50, Lacerate stack before Swipe cleave).
- TTD-only Demo skip fails open (`ttd` defaults 999); HP gate closes the execute-window waste case.
- Zip layout: contents of `EaxRotations/` at archive root.

### Verification

- `luac -p` on changed Lua
- `lua EaxRotations/tests/test_bear_custom_matches.lua` PASS

---

# Developer Changelog — EaxRotations v2.7.4

**Date:** 2026-07-16
**Branch:** master
**Commits:** Wire dormant shared supremacy modules + health_pred_helper bootstrap

---

## Dormant Shared Module Bootstrap

### Problem
Modules shipped with unit tests and nil-guarded `NS.*` call sites, but were never
`require`d at bootstrap. Runtime always took the "module missing" path.

### Files changed

| File | Change |
|------|--------|
| `EaxRotations/main.lua` | `load_modules` list: stopcast, pet_heal, snap_threat, stance_manager, swing_diagnostics, swing_timer, dispel_manager, rage_manager, melee_combat_math (before class load) |
| `EaxRotations/main_sylvanas.lua` | `require health_pred_helper` after `NS.health_prediction`; tick `NS.SwingTimer.on_update` |
| `EaxRotations/shared/health_pred_helper_sylvanas.lua` | New/shipped: lazy HP module resolve + `NS.incoming_damage` / `predicted_hp_pct` / `is_tank_role` |
| `EaxRotations/classes/warrior/arms_sylvanas.lua` | RageManager HS/Cleave with threshold overlay |
| `EaxRotations/classes/warrior/fury_sylvanas.lua` | RageManager HS/Cleave; keep local HS-trick path |
| `EaxRotations/header.lua` | version `2.7.4` |
| `VERSION.txt` | `v2.7.4` |

### Still deferred
- Healer/tank *call sites* for `NS.predicted_hp_pct` (integrate-advanced Phase 2.3–2.8)
- `wotlk_data_sylvanas` consumable merge
- `_dbc_spell_ids` audit-test consumer
- Arms/Fury StanceManager (still use `WH.desired_stance`)

### Verification
- `luac -p` on all touched Lua files
- Module tests: stopcast, pet_heal, snap_threat, stance, rage, dispel, melee_math, swing_diagnostics
- Rotation suite: 272/273 (pre-existing `test_spec_layout_compliance` unregistered feral file)

### Plan
- `plans/wire-dormant-shared-modules-2026-07-16.md`

---

# Developer Changelog — EaxRotations

## v2.7.4 — 2026-07-16

**Scope:** `fix(bear)` low-level spender gates + release artifact  
**Branch:** master

### Code

| File | Change |
|------|--------|
| `classes/druid/bear_sylvanas.lua` | Pre-Mangle Maul: `min(menu maul_rage, level_scaled)`; Swipe cleave: Lacerate stack gate only if `spell_exists(Lacerate)`; Demo Roar: skip single-target trash when `target_hp <= 20` or `ttd < 10`; `state.level` from context |
| `classes/druid/schema_sylvanas.lua` | `bear_maul_rage` tooltip for auto-scale |
| `tests/test_bear_custom_matches.lua` | Pre-Mangle / pre-Lacerate / Demo HP+TTD cases |
| `header.lua` / `VERSION.txt` / README badge | Version **2.7.4** |
| `eaxrotations.zip` | Rebuild: **.lua + .md only** from `EaxRotations/` |

### Design notes

- Endgame tank APL unchanged when Mangle is learned (`bear_maul_rage` default 50, Lacerate stack before Swipe cleave).
- TTD-only Demo skip fails open (`ttd` defaults 999); HP gate closes the execute-window waste case.
- Zip layout: contents of `EaxRotations/` at archive root (not nested under an extra folder name beyond that).

### Verification

- `luac -p` on changed Lua
- `lua EaxRotations/tests/test_bear_custom_matches.lua` PASS

---

# Developer Changelog — EaxRotations v2.6.2

**Date:** 2026-07-09
**Branch:** main
**Commits:** API standardization audit — Pattern 15 headers, Pattern 2 caching fix, compliance test extension

---

## API Standardization Audit (Phase 0-3 Complete)

### Pattern 15 Headers Added (14 files total)

| File | Header Added |
|------|-------------|
| `main.lua` | WHAT/WHEN/WHY/SAFETY |
| `common_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |
| `helpers_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |
| `header.lua` | WHAT/WHEN/WHY/SAFETY |
| `core/cooldowns.lua` | WHAT/WHEN/WHY/SAFETY |
| `core/diagnostics.lua` | WHAT/WHEN/WHY/SAFETY |
| `core/items.lua` | WHAT/WHEN/WHY/SAFETY |
| `core/settings.lua` | WHAT/WHEN/WHY/SAFETY |
| `core/units.lua` | WHAT/WHEN/WHY/SAFETY |
| `classes/hunter/cliptracker_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |
| `classes/priest/healing_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |
| `classes/shaman/healing_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |
| `classes/warrior/shared_helpers_sylvanas.lua` | WHAT/WHEN/WHY/SAFETY |

### Pattern 2 API Caching Fix

| File | Fix |
|------|-----|
| `druid/cat_sylvanas.lua:46` | Cached `core.spell_book.get_shapeshift_form_id` at module load (was raw inline call) |

### Compliance Test Extension (Phase 2)

- `test_spec_layout_compliance.lua` extended to cover 103 shared/core/middleware files
- Checks: Pattern 15 header, banned APIs, math.sqrt, bare menu access
- Fixed false-positive handling: comment lines skipped for all checks
- Result: 29 converted specs + 12 legacy + 103 shared/core/middleware PASS

### Phase 0-3 Audit Results

| Audit | Result |
|-------|--------|
| Banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`) | Zero in production |
| `math.sqrt` | Zero in production |
| Bare `menu.x:get()` | Zero outside schema files |
| `buff_points` without nil guard | All guarded |
| State bare comparisons (legacy) | Zero |
| Static table allocation in loops | Zero |
| Test raw `core.*` mocks | All legitimate |
| Legacy spec conversion (Wave 1A) | All 11 specs already use spec_kit |
| Shared module API caching (Wave 1B) | Defensive pcall fallbacks only |
| Core file audit (Wave 1C) | No hot-path violations |
| Class infrastructure (Wave 1D) | No bare menu access in middleware |
| Test file audit (Wave 1E) | Proper NS mocking |

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

