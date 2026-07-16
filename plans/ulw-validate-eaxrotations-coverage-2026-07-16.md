# EaxRotations Coverage Hardening Campaign

**Started:** 2026-07-16
**Goal:** Validate EaxRotations as the best rotation system by closing coverage gaps, adding missing tests, fixing low-scoring specs, and ensuring all 305+ tests pass with `luac -p` clean.

## Baseline (confirmed)

- 285/285 rotation suites PASS
- 20/20 leveling suites PASS
- 305/305 total tests PASS
- Scorecard overall average: 4.26/5
- Baseline commit: `436190c9`

## Scenarios (The Contract)

### Scenario 1: Interrupt Mastery
**What:** Every spec that has a kick/interrupt spell uses `shared/interrupt_manager_sylvanas.lua` (or equivalent class middleware) and has a registered interrupt strategy tested.

**Binary Pass Conditions:**
- [x] All interrupt-capable specs have at least one interrupt strategy registered
- [x] `interrupt_manager_sylvanas.lua` has 100% module coverage (all public functions tested)
- [x] `test_interrupt_manager.lua` or equivalent passes
- [x] No spec uses a hardcoded interrupt when `interrupt_manager` could be reused

### Scenario 2: Dispel Mastery
**What:** Defensive dispels are wired into all healer/hybrid specs; offensive dispels are tested for all specs that can purge/enrage-dispel.

**Binary Pass Conditions:**
- [x] `shared/dispel_manager_sylvanas.lua` is consumed by at least 5 specs (paladin/priest/shaman/druid middleware + warlock)
- [x] Every healer spec (paladin holy, priest holy/disc, shaman resto, druid resto) has a defensive dispel strategy
- [ ] Offensive dispel tests exist for mage, shaman, hunter, priest, warlock
- [x] `test_dispel_manager.lua` passes

### Scenario 3: Healer Spell-School Coverage
**What:** All healer specs cover their primary spell schools and emergency triage logic under realistic combat state.

**Binary Pass Conditions:**
- [ ] Paladin Healing (TBC) score improves from 3 to ≥4
- [ ] Priest Healing (TBC) score improves from 3 to ≥4
- [ ] Shaman Healing (TBC) score improves from 3 to ≥4
- [x] `healer_deficit_sylvanas.lua` is consumed by all 11+ healer specs (12 files verified)
- [ ] Every healer spec has a test for triage target selection and emergency heal

### Scenario 4: Tank Threat & Survival
**What:** All tank specs maintain snap threat on pull and use defensive cooldowns intelligently.

**Binary Pass Conditions:**
- [x] Warrior Protection uses `snap_threat_sylvanas.lua`
- [x] Paladin Protection uses `snap_threat_sylvanas.lua`
- [x] Druid Bear uses `snap_threat_sylvanas.lua` (bear_sylvanas + bear_vanilla)
- [x] Every tank spec has a test for snap-threat on combat entry
- [ ] Every tank spec has a test for defensive cooldown threshold

### Scenario 5: Adaptive Leveling Integrity
**What:** All leveling rotations adapt spell availability by level and have no duplicate/buggy helper functions.

**Binary Pass Conditions:**
- [x] All 28 leveling files expose `strategies` and `build_state` (compliance expanded)
- [x] Duplicate `scorch_matches` in `classes/mage/leveling_vanilla.lua` removed
- [x] Every class leveling rotation has a ladder test (TBC + Vanilla + WotLK)
- [x] `run_leveling_tests.lua` reports **21/21 PASS** (was 20; +TBC ladder suite)

## In-Scope vs Out-of-Scope

### In-Scope
- Shared module hardening: `interrupt_manager`, `dispel_manager`, `healer_deficit`, `snap_threat`
- Low-scoring spec fixes: paladin healing TBC, priest healing TBC, shaman healing TBC, druid caster vanilla, warlock destruction vanilla
- Vanilla test coverage for the 15 specs with `tests == 0`
- Leveling adaptive ladder fixes and duplicate function cleanup
- Test registration for staged/unregistered tests in `EaxRotations/tests/_staging/`
- Scorecard update and `plans/_active.md` refresh
- `luac -p` clean on every modified file

### Out-of-Scope
- Editing `api/` or `.api/` (strictly forbidden)
- Big-bang `spec_kit` migrations (convert only when already editing a spec)
- Removing spells classified as "WotLK-only" without DBC + lexxer.org verification
- New expansion support beyond TBC/Vanilla/WotLK DK skeleton
- Marketing/community tasks (Discord, plugin page, free trial)
- Non-rotation modules (EaxAutoQuester, EaxESP, EaxFishing)

## Task Dependency Graph

| Task | Depends On | Reason |
|------|------------|--------|
| T1: Baseline audit & gap report | None | Starting point; read-only inventory of current state |
| T2: Stabilize working tree | None | Uncommitted changes must be resolved before campaign changes |
| T3: Shared module hardening (interrupt/dispel/heal/tank) | T1, T2 | Needs audit findings and clean baseline |
| T4: Low-scoring spec fixes | T1, T2, T3 | Uses hardened shared modules |
| T5: Vanilla test coverage | T1, T2 | Independent of shared module changes; can run in parallel with T3 |
| T6: Leveling adaptive fixes | T1, T2 | Independent of spec fixes; can run in parallel |
| T7: Scorecard update & final validation | T3, T4, T5, T6 | Needs all changes complete |
| T8: Plan archive & _active.md update | T7 | Final bookkeeping |

## Wave-by-Wave Execution

### Wave 1 (Complete)
- [x] T1: Baseline audit & gap report
- [x] T2: Stabilize working tree

### Wave 2 (Complete — verified 303 rotation + 21 leveling PASS)
- [x] T3: Shared module hardening (interrupt/dispel/healer_deficit/snap_threat)
- [x] T5: Vanilla test coverage (15 `*_vanilla_strategies.lua` suites)
- [x] T6: Leveling adaptive fixes (scorch dedupe, 28-file compliance, TBC ladder)

### Wave 3
- [ ] T4: Low-scoring spec fixes (in progress)

### Wave 4
- [ ] T7: Scorecard update & final validation

### Wave 5
- [ ] T8: Plan archive & _active.md update

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Uncommitted changes conflict with campaign edits | Medium | High | T2 stabilizes the tree first; baseline committed |
| Shared module changes break multiple specs | Medium | High | T3 ships with full regression tests; run full suite after every shared change |
| Low-scoring specs require large refactors | Medium | Medium | Scope each fix to one spec per commit; stop if >2 attempts and write a debugging note |
| Vanilla tests reveal latent nil-guard bugs | High | Medium | Use TDD; add failing test first, then fix; follow Pattern 14 |
| Leveling duplicate function removal changes behavior | Low | High | Add test covering both call sites before removing duplicate |
| Test count inflation without quality | Medium | Low | Require each new test to exercise a real strategy or API boundary |

## Final Acceptance Criteria

- [ ] All 5 scenarios pass their binary pass conditions
- [ ] `luac -p` passes on every modified file
- [ ] `lua EaxRotations/tests/run_rotation_tests.lua` passes (target: 300+ suites)
- [ ] `lua EaxRotations/tests/run_leveling_tests.lua` passes (20/20)
- [ ] `lsp_diagnostics` shows 0 errors on changed files
- [ ] Scorecard average improves from 4.26 to ≥4.40
- [ ] No `api/` or `.api/` files modified
- [ ] No banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`) introduced
- [ ] Plan archived and `plans/_active.md` updated
