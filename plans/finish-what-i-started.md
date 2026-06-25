# Consolidated Finish Plan — EaxRotations Optimization

**Created:** 2026-06-25
**Author:** triage session (synthesizes `glm-5.2-optimization-session.md`, `eax-external-improvements.md`, `post-audit-improvements.md`, `refactor-developer-experience-2026-06.md`, `wowsims-apl-cross-reference.md`)
**Status:** ACTIVE — supersedes the scattered plans above (which are reconciled into this file)
**Baseline (verified 2026-06-25, Lua 5.1.5):** 161 rotation suites PASS / 0 fail · 11 leveling suites PASS / 0 fail

> This is the **one** active plan for "finish what I started." The prior plans overlap, contradict,
> and mark done-work as pending. This file reconciles them against the **actual working tree**.
> Per AGENTS.md: one active plan per effort; one concern per commit; `validate.cmd` gates every task.

---

## The Key Insight (read this first)

The reference repos (`tbc-main/`, `tbc-new/`, `Sonah/`, `HealPredict/`, `LibHealComm-4.0.lua`,
`NAG/`, `NextActionTBC/`) were written for **other bot platforms** that lack native helpers. They
reimplement infrastructure (swing timers, aura caches, heal-communication, shield tracking) from
scratch. **Project Sylvanas already ships most of that infrastructure natively.** Verified native API
(`apidocs/pages/dev/api/game-object.md`, `auto-attack-helper.md`):

| Need | Reference approach | **Sylvanas native (use this)** |
|------|-------------------|-------------------------------|
| Swing timer / weave | Sonah `SwingTimer`, deleted `swing_timer_sylvanas.lua` | `require("common/utility/auto_attack_helper")` → `get_next_attack_game_time(unit)`, `get_last_attack_game_time(unit)`, `get_attack_speed()` |
| Incoming heals from others | LibHealComm-4.0 comms layer | `unit:get_incoming_heals_from(source)` + `unit:get_incoming_heals()` |
| Shield absorb remaining | HealPredict hardcoded spell tables | `unit:get_total_shield()` + `unit:get_total_heal_absorbs()` |
| Aura snapshot | Sonah 100ms cache | `NS.AuraCache` (50ms TTL, already wired) |
| TTD | NAG/NextActionTBC port | `ttd_tracker_sylvanas.lua` (exists) |

**Rule going forward:** mine references for **strategy/APL logic** (priority lists, seal-twist
windows, weaving rules, opener sequences), NOT for infrastructure. If a reference module's job is
already done by a `core.*` or `common/*` API, do not port it — call the native API.

---

## Verified State Matrix (what's actually done vs what the plans claimed)

Legend: ✅ verified done · 🔶 half-done · ❌ not done · ⛔ out of scope (native API supersedes)

### Refactor (`refactor-developer-experience-2026-06.md`)
- ✅ Phase 1 — single source of truth (AGENTS.md canonical; CLAUDE.md → pointer)
- 🔶 Phase 2 — core split **4 of 8 modules** extracted: `core/settings.lua`, `items.lua`, `cooldowns.lua`, `units.lua`. `core_sylvanas.lua` is **5,984 lines** (down from 6,431). Missing: `ttd.lua`, `talents.lua`, `diagnostics.lua`, `casting.lua`, `init.lua`
- 🔶 Phase 3.1 — `validate.cmd` exists **but has a Lua-version bug** (calls `lua` = 5.4.5, not 5.1) → Track A1
- ✅ Phase 4.1 — `shared/spec_kit_sylvanas.lua` exists + `test_spec_kit.lua` passes
- ✅ Phase 4.2 — `arms_sylvanas.lua` converted to `spec_kit.safe_state` + `define_action_for_class` (6 refs verified)

### Post-audit (`post-audit-improvements.md`)
- ✅ Task 1.1 — Readiness 23989 wired to hunter (MM: `readiness_matches` + strategy entry at line 403; BM/SV/class/schema/leveling all reference it)
- ✅ Task 1.2 — Balance hot-path require fixed (module-level `_find_dead_helper`, closures use `_find_dead`)
- 🔶 Task 1.3 — 10 dead modules deleted **but dangling refs remain in live code** → Track A3
- ✅ Task 2.1 — AuraCache created + wired (`NS.AuraCache`, core_sylvanas.lua:205-207)
- ❌ Task 2.2 — HealPredict shield absorb (do via **native `get_total_shield()`** → Track B3)
- ❌ Task 3.1 — Friendly target healing (5 healers) → Track B6 (candidate)
- ❌ Task 3.2 — Per-spec predictive thresholds → Track B6 (bundled)
- ❌ Task 4.1 — PvP burst GC garbage (static `REASONS_BUF`) → Track B5

### GLM 5.2 session (`glm-5.2-optimization-session.md`)
- ❌ Task 1.1 — try_cast raw fallback. **Design decision, not a blind fix:** code comment (core_sylvanas.lua:2177) says the fallback is *intentional* for off-GCD abilities where `cast_safe` is overly conservative. Removing it risks breaking interrupts/racials/trinkets. → defer unless a real bypass bug is observed; if so, add an off-GCD whitelist instead of removing the fallback.
- 🔶 Task 1.2 — dead `NS.DRTracker`/`NS.EnemyCDTracker` refs in `pvp_burst_window_sylvanas.lua` → **already stubbed** (lines 93-94, 128: "module was deleted; stub returns false/unknown"). Stubs are safe but DR-immunity checks always miss. → Track A4
- ❌ Task 1.3 — 35 DEBUG/placeholder entries in data bridges → Track D1
- ❌ Task 1.4 — spell ID 28176 conflict (Fel Armor / Spellstone) → Track D2
- ✅ Task 1.5 — orphan tests registered (`test_affliction_summon_felhunter`, `test_hunter_adaptive_nil_globals`, `test_enemy_count_hysteresis` all registered + passing)
- ❌ Task 2.1 — pvp_burst GC (= post-audit 4.1) → Track B5
- ✅ Task 2.2 — Balance require (= post-audit 1.2) → done
- ✅ Task 2.3 — Hunter Readiness (= post-audit 1.1) → done
- 🔶 Task 2.4 — validate.cmd (exists, has Lua bug) → Track A1
- ⛔ Wave 3 reference porting — TTD/swing/aura/hysteresis: **native API or already exist** (see Key Insight)
- ⛔ Wave 4 LibHealComm — **native `get_incoming_heals_from()` supersedes**; do the *logic* (subtract others' heals from deficit) via native API → Track B4
- 🔶 Task 5.1/5.2 — core/ttd.lua + core/talents.lua extraction → Track C

### eax-external (`eax-external-improvements.md`)
- ✅ Phase 1.1/1.2 — `enemy_count_hysteresis_sylvanas.lua` (73 lines) + `test_enemy_count_hysteresis.lua` (80 lines) created, registered, passing
- ❌ Phase 1.3 — hysteresis **NOT wired into any spec** (module exists, unused) → Track A2
- ❌ Phase 2 — seal twist: `swing_timer_sylvanas.lua` was **deleted** mid-flight. **Resurrected as feasible** via native `auto_attack_helper` → Track B1

### Explicitly OUT OF SCOPE (do not do — documented here so we stop relitigating)
- ⛔ LibHealComm-4.0 comms layer — native `get_incoming_heals_from()` supersedes
- ⛔ NAG DRM system / `loadstring()` rotations — banned + zero value
- ⛔ NAG assignment/toggle system — raid-coordination, different product; revisit only if user asks
- ⛔ NextActionTBC APL lookahead — incompatible with strategy-registry architecture
- ⛔ Sonah aura-cache / swing-timer / heal-predict ports — native API supersedes (ours is equal/better)
- ⛔ TTD / energy-tick / DR standalone ports — already exist inline or in shared modules
- ⛔ Stat weights / gear advisor (wowsims tbc-new) — different product, not a rotation

---

## Execution Tracks (ordered by risk ↑ / ROI ↓)

Every task: one commit, gated by `validate.cmd` (after A1 fixes it). Lua 5.1.5 is the test runtime.

### Track A — Finish In-Flight (lowest risk; literally "finish what I started")

- [x] **A1 — Fix `validate.cmd` Lua version.** ✅ DONE 2026-06-25. Pinned test runs to `C:\Program Files (x86)\Lua\5.1\lua.exe` (single-line `if` form — the `(x86)` parens break multi-line `if/else` blocks in cmd.exe). Gate now reports `ALL CHECKS PASSED` on Lua 5.1. This was the reliability foundation and exposed that prior "green" runs used Lua 5.4.

- [x] **A2 — Wire enemy-count hysteresis into specs.** ✅ DONE 2026-06-25. Engine wiring was already complete (`main_sylvanas.lua` lines 589-606 feed `EnemyCountHysteresis.update()` per frame, expose `context.enemy_count_smoothed`, tune from `settings.hysteresis`, reset on combat exit; line 17-18 has a nil-safe stub fallback). **Fixed a latent bug:** `configure()` reset `_state.rise_until`/`drop_until` to 0 every frame, defeating the drop-hold window when called per-frame (confirmed empirically: drop fell to 0 at t=1100 instead of holding 3 until t=3000). Removed the timer-reset from `configure()` (tests call `reset()` explicitly for isolation, so it was redundant AND harmful). Verified: repro now holds correctly; `test_enemy_count_hysteresis.lua` passes; full gate green. **Skipped:** `NS.EnemyCountHysteresis` registration (specs read `context.enemy_count_smoothed` — not needed, avoids growing the god-file). **Deferred:** flipping AoE specs to gate on `enemy_count_smoothed` is a deliberate tuning/behavior decision (DROP_HOLD 2s delays AoE→ST switch) — left as opt-in per spec, not mass-flipped.

- [~] **A3 — Clean dead references to deleted modules.** PARTIAL 2026-06-25.
  - [x] **missile_tracker** — removed dead `pcall(require)` from `core_sylvanas.lua` (zero consumers; `_mt_ok` never used). luac + gate green.
  - [x] **swing_timer** — removed dead commented require from `main.lua` + dead `swing_timer_ok` state field from `fury_vanilla.lua` (never read). Left: historical "replaces" comment in core_sylvanas:159 (documentation) + stale `package.preload` mock in `test_fury_custom_matches.lua` (tab-indented, low value, harmless — skipped to avoid edit-mismatch risk).
  - [x] **reagent_guard** — ✅ DONE 2026-06-25. Removed dead `pcall(require)` + nil-guarded no-op usage sites from 5 production files: `core_sylvanas.lua` (require block + try_cast "4. Reagent guard" block), `discipline_sylvanas.lua` (require + divine_spirit_matches + pof_matches), `discipline_vanilla.lua` (require + divine_spirit_matches), `affliction_sylvanas.lua` (require + SelfSoulstone), `affliction_vanilla.lua` (require + SelfSoulstone). All usage was `local reagent = NS.ReagentGuard or _reagent_guard; if reagent and reagent.check_reagent then ...` → block never ran (module deleted). Zero behavior change. Verified: zero dangling `_reagent_guard`/`NS.ReagentGuard` refs in production. Left: 4 harmless dead branches in 2 test `require`-override scaffolds (never fire now; test-scaffolding, low value to prune).
  - [x] **spell_flag_checker** — ✅ DONE 2026-06-25 (cosmetic only). Removed the dead 4-line registration block from `core_sylvanas.lua` (the `pcall(require)` of a deleted module returned false, so `NS.SpellFlagChecker` was never set — pure dead code). **Behavior unchanged:** druid form-restriction checking remains DISABLED — `middleware_sylvanas.lua:54` `if not NS.can_cast_in_form then return true end  -- Module not loaded` correctly handles the nil case (returns "can cast in any form"). The middleware's own comment documents this. Reimplementing form-restriction via native `core.spell_book` form checks is a separate FEATURE (behavior change), deferred to an explicit ask — not part of this cleanup.
  - Intentionally left: historical "replaces X" comments (core_sylvanas:159,170,1078; triage:5) — useful documentation, not dead code. `target_lockout` hits are a false positive (local var `_manual_target_lockout_until`, live functional code).

- [x] **A4 — Decide pvp_burst DR/EnemyCD stubs.** ✅ RESOLVED (option b — documented limitation) 2026-06-25. `pvp_burst_window_sylvanas.lua` already documents the stubs in-code: line 93 "DRTracker module was deleted; stub returns false until DR tracking is reimplemented" and line 128 "EnemyCDTracker module was deleted; stub returns 'unknown' until enemy CD tracking is reimplemented." The DR-immunity check always misses, but this is PvP-only and the limitation is explicitly documented at the stub sites. Wiring `arena_priority_sylvanas.lua`'s DR logic (option a) is a behavior change needing PvP/arena in-game validation — deferred until someone actively tunes arena burst. No code change needed; the documentation IS the resolution.

### Track B — High-ROI Native-API Features (use Sylvanas native, NOT reference ports)

- [x] **B1 — Seal twisting for Ret Paladin** (eax-external Phase 2). ✅ DONE (infra) + TEST-COVERED 2026-06-25. **Discovered the infrastructure was already implemented and backed by native `auto_attack_helper`:** `core_sylvanas.lua:159` loads `common/utility/auto_attack_helper`; `NS.get_time_until_swing()` (core:3814) bridges to `get_next_attack_core_time`/`get_next_attack_game_time`; `retribution_sylvanas.lua:221` reads it into `state.swing_remains`; twist match-gates (lines 433/476/493/503) suppress off-GCD abilities (CrusaderStrike/Consecration/Exorcism/HolyWrath) when `can_twist` + Command-without-Blood + swing imminent (`swing_remains <= twist_window+0.75`). Opt-in via `seal_twisting_enabled` + `retri_twist_mana_floor`. **The gap was zero test coverage** — `test_paladin_tbc_seals.lua` was a 6-line stub. Filled it with 9 contracts (suppress near swing / allow when far / inactive when disabled / Blood-bypass / boundary / Consecration+Exorcism gates / TBC Anniversary SoB 31892 + SoM 348700 + SoC 27170 ID preservation / Blood-Martyr-Command strategies registered). Passes standalone + in-suite (161/161) + full gate. **Deferred (bigger behavior change, needs in-game validation):** the *classic active* Blood↔Command seal-swap twist (swap to Blood ~600ms pre-swing, back to Command post-swing for double procs). Current behavior is the suppress-variant — safe, opt-in, native-backed. Active-swap risks mana/GCD-spam and needs live tuning, so left as a documented future enhancement, not added autonomously.

- [x] **B2 — Ability weaving via `auto_attack_helper`**. ✅ DONE (already wired) 2026-06-25. Native swing timer IS adopted: `NS.get_time_until_swing()` (native-backed) is consumed by `retribution_sylvanas` (seal twist), `kebab_sylvanas`/`kebab_vanilla` (Slam weave, `[#28] auto_attack_helper` comment). Hunter steady-shot weave uses an **intentional wowsims-parity DPS model** (`hunter_adaptive_sylvanas.lua` — `steadyDPS`/clip buckets), tested by `test_hunter_steady_shot_weave.lua` (passing). **Did NOT replace the hunter model with naive swing-timer gating** — that would regress tested wowsims-parity behavior. Native `auto_attack_helper` is the right tool for melee Slam/seal-twist (done); the hunter model is a different, higher-fidelity approach (kept).

- [x] **B3 — HealPredict shield absorb via native `get_total_shield()`.** ✅ DONE (already implemented + tested) 2026-06-25. `healer_deficit_sylvanas.lua:262-269` uses native `unit.get_total_shield()` in `predicted_deficit`; `preemptive_heal_sylvanas.lua` has `SHIELD_DATA`/`calc_shield_absorb`/`get_pws_absorb` helpers (HealPredict-style spell-rank absorbs) AND fast-paths to `HealerDeficit.predicted_deficit`. `test_restoration_shield_tracking.lua` + `test_healer_deficit_overheal.lua` (Tests 9-10) assert shield absorbs reduce deficit. Both pass.

- [x] **B4 — "Others' heals" deficit accounting via native `get_incoming_heals_from()`.** ✅ DONE (core) 2026-06-25. `healer_deficit_sylvanas.lua:252-260` uses native `unit.get_incoming_heals()` (subtracted in `predicted_deficit`); `incoming_heal_predictor_sylvanas.lua:536` uses `get_incoming_heals()`; `heal_would_overheal` gates on it. `test_healer_deficit_overheal.lua` Test 7 asserts incoming heals (4000) covering deficit (3000) → overheal detected. Passes. **Deferred (marginal, untested):** the `get_incoming_heals_from(source)` "exclude self" refinement. Not needed — `get_incoming_heals()` returns in-flight heals from others who already cast; my pending decision isn't in-flight, so the current subtraction is correct. Adding exclude-self would be an untested behavior change for an edge case that's already handled correctly.

- [x] **B5 — PvP burst GC fix** (post-audit 4.1 / GLM 2.1). ✅ DONE 2026-06-25. The static `REASONS_BUF = { n = 0 }` accumulation (Pattern 4, no `table.insert`) was **already in place** from a prior partial fix — but that fix left a **dangling bug**: `M.score()` ended with `context.burst_score_reasons = reasons` where `reasons` was never defined (renamed to `REASONS_BUF`), so `context.burst_score_reasons` was always nil and `M.reason()` always returned "no burst factors detected". Fixed: snapshot `REASONS_BUF` into `context.burst_score_reasons` (tiny array, only when n>0) so `M.reason()` works and the hot-path `table.insert` elimination stays intact. Verified empirically (reason string now populated) + `validate.cmd` green. No test constrained `burst_score_reasons` (debugging-only; specs read `context.should_burst`).

- [ ] **B6 — Friendly-target healing + per-spec predictive thresholds** (post-audit 3.1/3.2). **Candidate — larger change; design first.**
  - Add `NS.has_friendly_target()` + `NS.get_friendly_target_entry(context)`; FriendlyTarget strategy as top priority in 5 healers; schema sliders per spec.
  - **Verify:** `validate.cmd`; 6 files green.

### Track C — Refactor Finish (core_sylvanas split, one commit per extraction)

- [x] **C1 — Extract `core/ttd.lua`** ✅ ALREADY DONE (verified 2026-06-25). TTD is already extracted to `shared/ttd_tracker_sylvanas.lua` (265 lines) + `shared/ttd_ema_tracker_sylvanas.lua`. The only TTD code remaining in core_sylvanas is a small inline computation block (~lines 4757-4776) that computes `time_to_die` from incoming_dps and feeds `NS.TTDEmaTracker` — interleaved with the combat-context builder, NOT a clean extractable domain. Extracting it would be risky surgery for ~20 lines of organizational gain. `test_ttd_tracker.lua` + `test_ttd_normalization.lua` pass.
- [x] **C2 — Extract `core/talents.lua`** ✅ ALREADY DONE (verified 2026-06-25). Talent inference is already extracted — `context.talent_build` is built in `main_sylvanas.lua`; `NS.resolve_talent_spell` / `NS.get_base_spell_id` self-register from `shared/spell_resolver_sylvanas.lua` (core_sylvanas:107 just pcall-requires it). Only 2 references remain in core_sylvanas, both comments/log lines. Nothing to move. `test_talent_context.lua` passes.
- [x] **C3 — Extract `core/diagnostics.lua`** ✅ DONE 2026-06-25 (commit 80128541). Moved `emit` + `NS.log`/`log_warning`/`log_error` + API-health stubs (`is_api_health_broken`/`reset_api_health`) + `NS.dump_class_spells` out of core_sylvanas into `core/diagnostics.lua` (169 lines, `M.install(NS)` pattern matching the existing settings/units/items/cooldowns extracts). Install block replaces the inline defs at the same source location (~line 497) so `NS.log` stays available to core_sylvanas's own load-time logging; hard fallback defines minimal log fns if the module ever fails to load. Behavior identical. core_sylvanas: 5965 → 5857 lines (−108). Gate green.
- [~] **C4 — (Optional, highest risk) Extract `core/casting.lua`** ⛔ DEFERRED 2026-06-25 (deliberate, with evidence). The 8 casting functions (`spell_action`@1254, `spell_id_is_known`@1464, `spell_ready`@1816, `evaluate_cast`@1887, `try_cast`@1990, `try_cast_position`@2075, `action_matches`@5117, `action_execute`@5475) are **scattered across a 4200-line span** (1254–5475), interleaved with ~30 other domains' functions and shared upvalues (`safe_field`, `emit`, buff helpers). A clean contiguous extraction is impossible; moving 8 non-contiguous hot-path functions + their shared upvalues is the kind of god-file surgery that risks looping (AGENTS Rule 5). The plan itself flagged C4 as "highest risk, leave for Phase 4 if needed." The file-split's value is organizational only — tests pass regardless of which file a function lives in. Revisit only as part of a larger whole-file reorganization, not as an isolated extract.
- [~] **C5 — `core/init.lua` facade + size audit.** PARTIAL. 5 of 8 planned core/ modules now exist (settings, units, items, cooldowns, diagnostics). core_sylvanas is 5857 lines (target was <1500, but that target assumed C4 casting extraction which is deferred). No `core/init.lua` facade yet — core_sylvanas still pcall-requires each domain inline. A facade is low-value while core_sylvanas remains the load entrypoint; defer until more domains are extracted or the entrypoint moves.

### Track D — Data Cleanup (mechanical, low risk)

- [~] **D1 — Strip 35 DEBUG/placeholder entries** from `wowhead_data_bridge_*.lua` (pattern `DEBUG`/`XXXX`/`ALEX BUG`/`QR XXXX`). ⛔ DEFERRED 2026-06-25 (wrong layer). The DEBUG entries live in `wowhead_data_bridge_sylvanas.lua` — a **~66K-line generated file** produced from the DBC by `build_tools/json_to_lua_data.py`. The DEBUG spells (QA Frost Spell, Debug Samophlange Manual, Sober Up - DEBUG, etc.) are **genuine internal Blizzard QA spells that exist in the DBC**; no rotation code references them (verified: IDs 17122/32965/33288 have zero rotation refs). Hand-editing 35 entries in a generated file is an anti-pattern — the next regeneration overwrites the edits. The correct fix is a **generator filter** in `build_tools/json_to_lua_data.py` (exclude spell names matching `DEBUG`/`QA Debug`/`XXXX` during emission), which is out of the rotation test gate's scope. The `_index_` variants are gitignored anyway. Documented here so the build-pipeline fix is the next step when the data bridge is regenerated.
- [x] **D2 — Fix spell ID 28176 conflict** (Fel Armor / Spellstone) in `offensive_dispel_sylvanas.lua`. ✅ DONE 2026-06-25 (commit c377750f). DBC-verified (`wowheadScrape/dbc_extract/wowsims.db`): spell 28176 is unambiguously **Fel Armor Rank 1** (description: "Surrounds the caster with fel energy, increasing health generated... increasing spell damage... Only one type of Armor spell can be active on the Warlock"). There is **no Spellstone conflict** — the NOTE claiming one was factually wrong. The entire codebase already treats 28176 as Fel Armor consistently (all 4 warlock specs `FEL_ARMOR_BUFF = {28189, 28176}`, ooc_manager, purge_manager, tbc_data, bridge indices). The HIGH_DISPEL_BUFFS entry is correct. Corrected the misleading NOTE; no table or behavior change. Verified against DBC per AGENTS.md (DBC is authoritative).

---

## Verification Gate (every task)

1. `luac -p` on changed files (5.1 luac — already correct in PATH)
2. `EaxRotations\validate.cmd` exits 0 (after A1, this runs tests under Lua 5.1)
3. No reference-system clone modified (`tbc-main/`, `tbc-new/`, `Sonah/`, `HealPredict/`, `LibHealComm-4.0.lua`, `NAG/`, `NextActionTBC/`, `_flux_tbc_explore/`, `eax_refactor/`)
4. AGENTS.md updated if a new pattern is adopted

## Recommended Starting Order

**A1 → A2 → A3** (finish in-flight, establish reliable gate, wire the half-built hysteresis, remove
dead code). These are the literal "finish what I started" items and are all low-risk + test-gated.
Then **B3 + B4** (native-API healing improvements — high ROI, small). Then **B1** (seal twist —
flagship feature, now feasible). Track C refactor extractions interleaved opportunistically.

## Loop Guard (AGENTS Rule 5)

If any task loops >2 attempts: STOP. Write a debugging note in `plans/` instead of retrying.
