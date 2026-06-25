# Implementation Plan: Enemy Count Hysteresis + Seal Twisting Swing Timer

**Created:** 2026-06-25
**Source:** Hyperplan adversarial analysis (5 analysts × 3 rounds) — see `_active.md` for synthesis
**API Surface:** `api/object_manager.lua`, `api/game_object.lua`, `api/spell-helper.lua`, `api/menu.lua`
**Docs References:** `apidocs/pages/dev/api/object-manager.md`, `apidocs/pages/dev/api/game-object.md`

## Overview

Two surgical additions to EaxRotations that fill gaps the hyperplan cross-validated as real and uncontested.

**Why these two and nothing else:** TTD, energy tick tracking, 50ms aura cache, heal prediction, DR tracker, and PvP burst scoring already exist (verified via filesystem). NAG's DRM system, NAG's `loadstring` rotation pattern, LibHealComm comms layer, Sonah's aura cache, and NextActionTBC APL lookahead were cross-attacked as **do-not-port** by ≥2 analysts. The only gaps that survived cross-validation without confirmation-bias pushback are:

1. **Enemy count hysteresis** — shared module, opt-in via menu, zero behavior change for non-opt-in users. Fixes the AoE↔ST oscillation problem that multi-target specs suffer when an enemy spikes in/out of range.
2. **Swing timer integration for seal twisting** — Ret Paladin only, builds on existing TBC Anniversary 2.5.5 data (Seal of Blood 31892, Seal of Martyr 348700 already backported and verified per AGENTS.md).

## API Integration

| Function | File | Purpose |
|---|---|---|
| `core.object_manager.get_enemy_list()` | `api/object_manager.lua` | Source enemy list for hysteresis |
| `core.time()` | `api/core.lua` | TTL + frame stamp |
| `core.spell_book.is_spell_learned(id)` | `api/spell-helper.lua` | Capability gate |
| `me:get_time_to_die(ms)` (existing) | `EaxRotations/shared/ttd_tracker_sylvanas.lua` | Wire into DoT refresh decisions |
| `NS.get_setting(key, default)` | `EaxRotations/core_sylvanas.lua` | Menu read with fallback |

## Files to Touch

| File | Change | API Used |
|---|---|---|
| `EaxRotations/shared/enemy_count_hysteresis_sylvanas.lua` | NEW: sliding-window enemy count with omen/drop hysteresis | `core.object_manager.get_enemy_list()`, `core.time()` |
| `EaxRotations/shared/swing_timer_sylvanas.lua` | NEW: swing timer tracking with main-hand/ranged detectors | `core.time()`, unit attack-speed methods |
| `EaxRotations/classes/paladin/retribution_sylvanas.lua` | Add seal twisting using swing timer | New `SwingTimer` module |
| `EaxRotations/tests/test_enemy_count_hysteresis.lua` | NEW: test rapid emergence/disappearance scenarios | mock enemies over fake clock |
| `EaxRotations/tests/test_seal_twisting.lua` | NEW: test twist detection logic | mock swing times |

## Task List

### Phase 1: Enemy Count Hysteresis (highest ROI, lowest risk)

- [ ] **Task 1.1**: Create `EaxRotations/shared/enemy_count_hysteresis_sylvanas.lua`
  - **Contract:**
    - `_module.init(ns)` registers a per-frame cache entry on `NS`
    - `_module.smoothed_count()` returns integer ≥ 0, never nil
    - Internal state: `current_count`, `last_drop_at`, `last_rise_at`, `drop_hold_ms=2000`, `rise_hold_ms=500`
    - All state in static `_t = {}` to avoid on_update allocations (AGENTS Pattern 4)
    - Throttled to 2 second polling per AGENTS Pattern 6
  - **API Used:** `core.object_manager.get_enemy_list()` returns list; `core.time()` returns ms
  - **Acceptance:**
    1. Rapid emergence (0→3→0 within 1s) reports `0` for the next 2s
    2. Rapid disappearance (3→0) reports `3` for 2s before settling
    3. Nil/empty enemy list returns `0`, not crash
  - **Verify:** `luac -p <file>` && `lua EaxRotations/tests/run_rotation_tests.lua`

- [ ] **Task 1.2**: Create `EaxRotations/tests/test_enemy_count_hysteresis.lua`
  - **Test cases:**
    - "Rapid emergence filters spike": inject [0,3,0] over 1s, expect smoothed stays 0 for >500ms
    - "Sustained presence settles": inject [3,3,3,3] over 5s, expect smoothed = 3 immediately
    - "Drop hold prevents oscillation": inject [3,0,3,0] over 2s, expect smoothed = 3 for full window
    - "Nil enemy list safe": both list=nil and list={} return smoothed=0
  - **Verify:** `lua EaxRotations/tests/run_rotation_tests.lua` — test included in test runner registration

- [ ] **Task 1.3**: Wire into gear_aoe_threshold across multi-target specs
  - **Files:** only spec files that already gate on `get_enemy_count()` or `enemy_count`
  - **Pattern:** replace `enemy_count` direct read with `EnemyHysteresis.smoothed_count()` as fallback, e.g. `state.enemy_count or EnemyHysteresis.smoothed_count() or 0`
  - **Acceptance:** All 127 test suites still pass
  - **Verify:** `lua EaxRotations/tests/run_rotation_tests.lua` && `lua EaxRotations/tests/run_leveling_tests.lua`

### Phase 2: Seal Twisting Swing Timer

- [ ] **Task 2.1**: Create `EaxRotations/shared/swing_timer_sylvanas.lua`
  - **Tracks:**
    - `main_hand_next_swing_at`: ms timestamp from `GetTime() * 1000` (AGENTS: never `math.sqrt`, but standard `GetTime`/`core.time` are fine)
    - Use existing Sylvanas swing timer if exposed; if not, compute via last-cast timestamp + 2.0s estimate
  - **Public API:**
    - `SwingTimer:next_mh_swing_ms()` — returns epoch ms for next main-hand swing
    - `SwingTimer.time_to_mh_swing_ms()` — returns ms remaining
  - **API Used:** `core.time()` (epoch ms), unit attack-speed methods from `api/game_object.lua`
  - **Verify:** `luac -p <file>`

- [ ] **Task 2.2**: Add seal twisting match function in `classes/paladin/retribution_sylvanas.lua`
  - **Condition:** Judgement should fire when:
    - Current weapon swing is >400ms away AND
    - Player has Blood/Martyr seal active AND
    - Player has learned Seal of Command (verified against DBC `wowheadScrape/dbc_extract/wowsims.db`)
  - **Seal swap pattern:**
    - On Judgement with focused seal (Command/Spell): swap to Blood/Martyr
    - At ~600ms before MH swing: swap back to Command/Spell seal
  - **Nil-guard:** `(state.swing_timer_ms or 0) >= 600` per AGENTS Pattern 14
  - **Acceptance:**
    1. Twist fires only when Blood/Martyr is set in menu
    2. Twist respects swing window (no fire at 0ms before swing)
    3. Twist disabled if Seal of Command is unlearned
  - **Verify:** `lua EaxRotations/tests/run_rotation_tests.lua` and ret spec test passes

- [ ] **Task 2.3**: Create `tests/test_seal_twisting.lua`
  - **Test cases:**
    - "Twist doesn't fire inside 400ms window"
    - "Twist fires at 800ms with Blood seal + Command learned"
    - "Twist disables when Command unlearned"
    - "Twist respects Blood/Martyr seal requirement"
  - **Verify:** test passes in `run_rotation_tests.lua`

### Phase 3: Validation

- [ ] **Final check**
  - `luac -p` on all modified files
  - All 95 rotation suites pass
  - All 11 leveling suites pass
  - LSP/`lsp_diagnostics`: 0 errors on changed files
  - No regressions in any of the 29 specs

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Enemy hysteresis adds latency to enemy reads | Wrong timer reads | TTL: 2s throttle per AGENTS Pattern 6 |
| Seal twisting fires late by 50ms | DPS loss <1% | 600ms pre-swing window is conservative; tune in-game |
| Swing timer data missing from Sylvanas API | Module returns nil | Fallback: compute from last attack timestamp; nil-guarded |
| Existing specs gate on `enemy_count` directly | Hysteresis bypassed | Task 1.3 wires via `state.enemy_count or Hysteresis.smoothed_count()` fallback |
| New shared modules require AGENTS review | Plan gated on "ask first" | Explicitly listed in `Files to Touch` — minor additions, no API surface changes |

## Out of Scope (per hyperplan cross-validation)

These were **recommended but cross-attacked into irrelevance**:
- TTD estimation — already in `ttd_tracker_sylvanas.lua` (265 lines, verified)
- Heal prediction — already in `incoming_heal_predictor_sylvanas.lua` (638 lines, verified)
- Energy tick tracking — already in `energy_tick_tracker_sylvanas.lua`
- Aura cache — existing 50ms TTL is BETTER than Sonah's 100ms
- DR tracker — already exists for PvP specs
- APC / PvP burst scoring — already exists
- spec_kit.safe_state — already in `EaxRotations/shared/`
- NAG DRM system (1,500 lines) — zero value (anti-cheat + version checks), also DESLOP-DEFEND
- NAG loadstring() rotations — banned pattern, security anti-pattern
- LibHealComm comms layer — C_ChatInfo incompatible with Sylvanas's IZI SDK (port algorithms only, not transport)
- NextActionTBC APL lookahead — incompatible with strategy-registry architecture
- Stat weights from wowsims (tbc-new) — gear advisor is a different product, not a rotation
- Trinket ICD "learning" — ICDs are static; tmog/uicd data tables (if generated) are the right answer
- DoT snapshot tracking — TBC uses dynamic update, not snapshot
- Exclusive debuffs — raid coordination out of framework scope
