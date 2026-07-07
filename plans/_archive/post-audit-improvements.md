# Post-Audit Improvements — Loop-Executable Plan
## Created: 2026-06-24 | Status: pending
## Loop command: paste tasks below into a new session

---

## How to Invoke (Oh My OpenAgent syntax)

```
task(category="<category>", load_skills=["<skill>", ...], run_in_background=true|false, description="<3-5 words>", prompt="Execute <task-id> from .omo/plans/post-audit-improvements.md. ...")
```

**Categories** (domain-optimized model routing): `quick`, `unspecified-high`, `unspecified-low`, `deep`, `ultrabrain`, `visual-engineering`, `artistry`, `writing`

**Subagent types** (specific named agent): `explore`, `librarian`, `oracle`, `plan`, `metis`, `momus`

**Available skills**: `code-review-and-quality`, `test-driven-development`, `debugging-and-error-recovery`, `git-workflow-and-versioning`

---

## Baseline (run once before loop)

```
git status --short --branch && git log --oneline -3
lua EaxRotations/tests/run_rotation_tests.lua 2>&1 | Select-String "Total|Pass|Fail"
lua EaxRotations/tests/run_leveling_tests.lua 2>&1 | Select-String "Total|Pass|Fail"
```

---

## Wave 1 — Fire ALL 3 in parallel

### Task 1.1: Add Readiness (23989) to Hunter
```
task(category="quick", load_skills=["code-review-and-quality", "test-driven-development"], run_in_background=true, description="Add Readiness 23989 hunter", prompt="Execute Task 1.1 from .omo/plans/post-audit-improvements.md. Files: EaxRotations/classes/hunter/class_sylvanas.lua, beast_mastery_sylvanas.lua, marksmanship_sylvanas.lua. Steps: (a) Add Readiness spell action with ID 23989 to class table near RapidFire. (b) Add readiness_ready state field + populate in build_state() via NS.spell_ready — Pattern 14 nil-guard required. (c) Add readiness_matches function: gate on readiness_ready + in_combat + RapidFire CD >= 60s. (d) Add strategy entry after RapidFire in BM strategies table. (e) Repeat for MM. (f) Verify: luac -p on all 3, then lua run_rotation_tests.lua + run_leveling_tests.lua all PASS.")
```

### Task 1.2: Fix Balance Hot-Path require()
```
task(category="quick", load_skills=["code-review-and-quality"], run_in_background=true, description="Fix balance hot-path require", prompt="Execute Task 1.2 from .omo/plans/post-audit-improvements.md. Files: EaxRotations/classes/druid/balance_sylvanas.lua (lines 188,196), balance_vanilla.lua (lines 153,161). Move require('shared/find_dead_party_ally_sylvanas') from per-frame closures to module-level (Pattern 9). Add 'local find_dead_ally = require(...)' at top of file, replace inline calls with module-level variable. Same for vanilla file. Verify: luac -p on both, then 167/167 rotation PASS.")
```

### Task 1.3: Delete 10 Dead Shared Modules
```
task(category="quick", load_skills=["code-review-and-quality", "git-workflow-and-versioning"], run_in_background=true, description="Delete 10 dead shared modules", prompt="Execute Task 1.3 from .omo/plans/post-audit-improvements.md. Delete from EaxRotations/shared/: pvp_trinket_tracker_sylvanas.lua, dr_tracker_sylvanas.lua, sdf_render_sylvanas.lua, reagent_guard_sylvanas.lua, spell_flag_checker_sylvanas.lua, healer_engine_sylvanas.lua, apl_parser.lua, swing_timer_sylvanas.lua, missile_tracker_sylvanas.lua, target_lockout_sylvanas.lua. Remove references from main.lua pcall list and run_rotation_tests.lua. Delete orphaned test files. Verify: luac -p on main.lua, then rotation + leveling tests all PASS.")
```

**Wait for ALL 3 <system-reminder> notifications, then collect with background_output().**

---

## Wave 2 — Fire BOTH in parallel after Wave 1 completes

### Task 2.1: AuraCache Snapshot Module
```
task(category="unspecified-high", load_skills=["code-review-and-quality", "test-driven-development"], run_in_background=true, description="Create AuraCache snapshot module", prompt="Execute Task 2.1 from .omo/plans/post-audit-improvements.md. Create NEW file EaxRotations/shared/aura_cache_sylvanas.lua. Pattern 15 header required. Design: snapshot UnitBuff/UnitDebuff once per frame (50ms TTL), store in hash table by spellID, provide O(1) lookups. Implement M.snapshot(unit), M.find_buff(unit, id), M.find_buffs(unit, ids array), M.find_debuff(unit, id). Wire into core_sylvanas.lua as NS.AuraCache. Verify: luac -p on both files, 167/167 + 11/11 all PASS.")
```

### Task 2.2: HealPredict Shield Absorb Data
```
task(category="quick", load_skills=["code-review-and-quality"], run_in_background=true, description="Add shield absorb data", prompt="Execute Task 2.2 from .omo/plans/post-audit-improvements.md. File: EaxRotations/shared/preemptive_heal_sylvanas.lua. Add M.SHIELD_DATA table with all TBC shield spell ranks (source: HealPredict Core.lua lines 101-200+). PW:S ranks 1-12 (coeff 0.2, school heal), Ice Barrier ranks 1-6 (coeff 0.1, school 5), Mana Shield/Sacrifice/Wards. Add M.calc_shield_absorb(spell_id, spell_power) and M.get_pws_absorb(unit) helpers. Verify: luac -p, 167/167 PASS.")
```

---

## Wave 3 — Sequential (tasks depend on each other)

### Task 3.1: Friendly Target Step 0 (All 5 Healers)
```
task(category="unspecified-high", load_skills=["code-review-and-quality", "test-driven-development"], run_in_background=false, description="Add friendly target healing", prompt="Execute Task 3.1 from .omo/plans/post-audit-improvements.md. Add to core_sylvanas.lua: NS.has_friendly_target() and NS.get_friendly_target_entry(context) using api/game_object.lua signatures. Then add FriendlyTarget strategy as top priority in all 5 healer specs: holy priest (GreaterHeal), discipline (PW:S→FlashHeal), holy paladin (HolyLight), resto druid (Regrowth), resto shaman (LHW/HW). Add schema slider per spec (friendly_target_threshold, default 90). Verify: luac -p on 6 files, 167/167 + 11/11 PASS.")
```

### Task 3.2: Per-Spec Predictive Thresholds
```
task(category="quick", load_skills=["code-review-and-quality"], run_in_background=false, description="Per-spec predictive thresholds", prompt="Execute Task 3.2 from .omo/plans/post-audit-improvements.md. Add schema sliders for: discipline_preemptive_threshold (default 75), holy_preemptive_threshold for paladin (default 80), resto_preemptive_threshold (default 80), restoration_preemptive_threshold (default 75). Verify all 5 healer threshold reads use correct nil-guard pattern. Verify: luac -p on 4 schema files, 167/167 PASS.")
```

---

## Wave 4 — Final Polish

### Task 4.1: Fix PvP Burst Window Hot-Path Garbage
```
task(category="quick", load_skills=["code-review-and-quality"], run_in_background=false, description="Fix PvP burst GC", prompt="Execute Task 4.1 from .omo/plans/post-audit-improvements.md. File: EaxRotations/shared/pvp_burst_window_sylvanas.lua. Replace 'local reasons = {}' + 10x table.insert() with static REASONS_BUF = { n = 0 } at module level (Pattern 4). Update all #reasons → REASONS_BUF.n, reasons[i] → REASONS_BUF[i]. Verify: luac -p, 167/167 PASS.")
```

---

## Final Verification (after all waves)

```
luac -p EaxRotations/shared/*.lua 2>&1 | Select-String "error"
lua EaxRotations/tests/run_rotation_tests.lua 2>&1 | Select-String "Total|Pass|Fail"
lua EaxRotations/tests/run_leveling_tests.lua 2>&1 | Select-String "Total|Pass|Fail"
git status --short
```

---

## Commit Plan (atomic per wave)

| Wave | Commit |
|------|--------|
| 1 | `feat(hunter): add Readiness 23989` + `perf(balance): fix hot-path require()` + `chore: remove 10 dead shared modules` |
| 2 | `feat(shared): add AuraCache snapshot module and HealPredict shield absorb data` |
| 3 | `feat(healers): friendly target Step 0 healing + per-spec predictive thresholds` |
| 4 | `perf(pvp): eliminate table.insert garbage in burst window scoring` |

---

## Task Matrix

| Wave | Task | Category | Skills | Parallel | Files |
|------|------|----------|--------|----------|-------|
| 1 | Readiness (23989) | `quick` | code-review, tdd | ✅ | 3 hunter |
| 1 | Balance require() | `quick` | code-review | ✅ | 2 druid |
| 1 | Dead module cleanup | `quick` | code-review, git-workflow | ✅ | ~12 |
| 2 | AuraCache module | `unspecified-high` | code-review, tdd | ✅ | 2 (1 new) |
| 2 | Shield absorb data | `quick` | code-review | ✅ | 1 |
| 3 | Friendly target | `unspecified-high` | code-review, tdd | — | 6 |
| 3 | Per-spec thresholds | `quick` | code-review | — | 4 |
| 4 | PvP burst GC fix | `quick` | code-review | — | 1 |

**Total**: 8 tasks, ~29 files. Waves 1 & 2 fully parallelizable. Waves 3 & 4 sequential.
