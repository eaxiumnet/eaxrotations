# Phase 5: Supremacy Completion + Process Fixes
## Completing gap closure + building intelligence pipeline

**Date**: 2026-06-29 
**Status**: Phases 1-4 complete (208/208 suites green) 
**Goal**: Close remaining gaps from post-mortem + build process to prevent future misses

---

## Part A: Remaining Code Gaps (Priority Order)

### 1. 🔴 Hunter Cliptracker Port (HIGHEST)
**File**: `tbc-main/tbc-main/rotation/source/aio/hunter/cliptracker.lua` (1361 lines) 
**Target**: `EaxRotations/shared/cliptracker_sylvanas.lua` + wiring into 3 Hunter specs 
**Impact**: Hunters are the most played class; cliptracker is the #1 DPS gain 
**What it does**:
- Auto-shot / Steady Shot weave mathematics (exact timing)
- Multi-Shot clipping prevention (check auto-shot timer before casting)
- Ranged swing prediction (latency compensation)
- Kill Command timing (fire within auto-shot window)
- Feign Death + trap weaving timing
**Why we missed it**: We had a 39-line stub that "worked" (passed tests) but was functionally useless
**Effort**: High (1,361 lines to port, understand, simplify, test)

### 2. 🟠 Druid Healthstone + Auto-Dispel
**Files**: `EaxRotations/classes/druid/balance_sylvanas.lua`, `cat_sylvanas.lua`, `bear_sylvanas.lua`, `resto_sylvanas.lua` 
**What to add**:
- Healthstone automation (same pattern as Warlock/Priest)
- Auto-dispel: Remove Curse (all specs), Abolish Poison (Resto)
**Why we missed it**: tbc-main had it in druid/middleware.lua but we never extracted it 
**Effort**: Low (copy pattern from existing specs)

### 3. 🟠 Combat Mode for Rogue/Mage/Druid
**Files**: Rogue (3 specs), Mage (3 specs), Druid (3 specs) 
**What to add**:
- Read `combat_mode` setting in build_state
- Adjust enemy_count thresholds or skip AoE strategies in ST mode
- Skip ST-only strategies in AoE mode
**Why we missed it**: Phase 4 agent reported "verified/extended" but grep shows no references 
**Effort**: Medium (9 spec files to modify)

### 4. 🟡 Paladin Healthstone + Auto-Dispel
**Files**: `EaxRotations/classes/paladin/*_sylvanas.lua` 
**What to add**:
- Healthstone automation (already have Cleanse in middleware)
- Auto-dispel for Holy/Prot (already partially implemented)
**Effort**: Low

---

## Part B: Process Fixes (Critical for Future)

### 5. 🔴 Feature Extraction Pipeline
**File**: `tools/extract_features_from_reference.py` (NEW) 
**What it does**:
```python
# 1. Scan tbc-main/**/*.lua for feature patterns
patterns = [
 r'auto_\w+',  # auto_healthstone, auto_aspect, etc.
 r'smart_\w+',  # smart_shield, smart_rage, etc.
 r'use_\w+',  # use_healthstone, use_interrupt, etc.
 r'\bsettings\.\w+', # all configurable settings
]

# 2. Build feature matrix: spec → feature → source_file:line
# 3. Compare against EAX spec files
# 4. Output gap report: features in reference but NOT in EAX
```
**Run**: `python tools/extract_features_from_reference.py tbc-main/ EaxRotations/` 
**Output**: `reports/reference_gaps_YYYY-MM-DD.md` 
**Frequency**: Weekly (or on-demand when new reference drops)

### 6. 🟠 Competitor Intelligence Dashboard
**File**: `tools/competitor_dashboard.py` (NEW) 
**What it does**:
```python
# 1. Read marketplace scrape JSON
# 2. Extract feature keywords from plugin descriptions
# 3. Build matrix: competitor → plugin → features
# 4. Compare against EAX feature list
# 5. Output: ranked gap list by user impact
```
**Run**: `python tools/competitor_dashboard.py marketplace_plugins_detail.json` 
**Output**: `reports/competitor_gaps_YYYY-MM-DD.md` 
**Frequency**: Monthly

### 7. 🟡 Middleware Integration Layer
**File**: `EaxRotations/shared/auto_wire_sylvanas.lua` (NEW) 
**What it does**:
```lua
-- Auto-wire shared modules based on spec role
-- Called from spec initialization, not per-frame
local ROLE_MODULES = {
 healer = { "stopcast", "pet_heal", "triage", "dispel_manager" },
 tank = { "snap_threat", "combat_mode", "stance_manager" },
 dps = { "combat_mode", "dot_ttd_gating" },
 hunter = { "shot_timer", "aspect_manager", "combat_mode" },
 warlock = { "dot_ttd_gating", "combat_mode" },
}
```
**Why**: Prevents "spec forgets to wire module" bugs 
**Effort**: Low

---

## Implementation Order

| # | Task | Effort | Owner | Deadline |
|---|------|--------|-------|----------|
| 1 | Cliptracker port | High | Agent | 2026-06-30 |
| 2 | Feature extraction pipeline | Medium | Script | 2026-06-30 |
| 3 | Druid healthstone + dispel | Low | Agent | 2026-06-30 |
| 4 | Combat mode for Rogue/Mage/Druid | Medium | Agent | 2026-07-01 |
| 5 | Paladin healthstone | Low | Agent | 2026-07-01 |
| 6 | Competitor dashboard | Medium | Script | 2026-07-02 |
| 7 | Middleware auto-wire | Low | Agent | 2026-07-02 |

---

## Test Strategy
- Every new spec wiring gets at least 1 test
- Cliptracker gets dedicated test suite (shot timing math)
- Feature extraction pipeline gets unit tests
- All changes: `luac -p` + full rotation suite + leveling suite

---

## Success Criteria
- [ ] Hunter cliptracker: 1361 lines → ~400 lines EAX quality
- [ ] All Druid specs have healthstone + dispel
- [ ] All Rogue/Mage/Druid specs have combat_mode
- [ ] Feature extraction pipeline runs weekly without agent intervention
- [ ] Competitor dashboard runs monthly
- [ ] 208+ rotation suites pass (0 failures)
- [ ] No new allocations in hot paths

---

*Plan created: 2026-06-29* 
*Next review: 2026-06-30 (after cliptracker port)*
