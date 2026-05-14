# ULW Prompt — EAX Rotations Enhancement Cycle

## Mission

Audit, fix, optimize, and extend the EAXRotations TBC rotation framework under `C:\newbot\scripts\EaxRotations\`. All work must use **only** the Project Sylvanas API surface documented in `C:\newbot\scripts\api\` and `C:\newbot\scripts\apidocs\`. No external libraries, no banned APIs (`ffi.C`, `io.popen`, `os.execute`, `debug.*`), no `.toc` files, and no references to any non-Sylvanas codebase.

## Context: Current State of EAXRotations

- **Architecture**: Unified framework under `EaxRotations/` with `core_sylvanas.lua` (shared runtime, 1584 lines), `main_sylvanas.lua` (dispatcher), `common_sylvanas.lua` (schema helpers), class folders under `classes/<class>/` with `class_sylvanas.lua`, `middleware_sylvanas.lua`, `schema_sylvanas.lua`, and per-playstyle files (e.g., `fire_sylvanas.lua`).
- **Settings**: Schema-driven; consumed by `main.lua` and `ui_sylvanas.lua`.
- **Tests**: 29 Lua tests under `tests/` covering API lint, gating, regressions, healing, and role behavior.
- **Shared helpers**: `shared/execute_phase_sylvanas.lua`, `shared/dot_refresh_sylvanas.lua`, `shared/burst_logic_sylvanas.lua`, `shared/mf_tick_compute_sylvanas.lua`, `shared/find_dead_party_ally_sylvanas.lua`.
- **Dispatcher flow** (`main_sylvanas.lua`): `build_context()` → run class middleware → run active playstyle strategies → first successful action wins. Strategies have `matches(context, state)` + `execute(context, state)` closures.

## CRITICAL GAPS IDENTIFIED (Fix Phase)

### [FIX-1] Spell Resolution Caching
**Problem**: `NS.get_spell_id()` in `core_sylvanas.lua` calls `core.spell_book.is_spell_learned()` on every invocation with zero caching. At 20–50ms update ticks resolving 10–30 spells per tick, this wastes hundreds of API calls per second.
**Fix**: Add a `spell_resolver` module (or inline into `core_sylvanas.lua`) that caches resolved spell IDs in a static table. Invalidate on `SPELLS_CHANGED`-equivalent events (use `core.register_on_spell_cast_callback` or a 30s TTL). Ensure TBC rank-downgrade support (newest learned rank wins).
**Sylvanas APIs**: `core.spell_book.is_spell_learned()`, `core.register_on_spell_cast_callback()`, `core.time()`.
**Success Criteria**: `luac -p` passes; `NS.get_spell_id()` returns cached result on second call for same input within 30s.

### [FIX-2] Empty Middleware — Warrior & Mage
**Problem**: `classes/warrior/middleware_sylvanas.lua` and `classes/mage/middleware_sylvanas.lua` register zero strategies. This means no class-wide defensive, interrupt, or utility automation exists for two major classes.
**Fix**: Populate both middleware files with at least the following shared concerns, gated by `context.settings`:
- **Defensive**: Auto-use survival cooldowns when player HP < configurable threshold.
- **Interrupt**: Cast interrupt spell when target is casting an interruptible spell and interrupt is enabled in settings.
- **Self-buff**: Maintain required stances/forms/armor buffs when out-of-combat or in-combat.
- **Threat drop**: Fade/Feign Death/Soulshatter equivalents if threat situation >= 2 and group combat ally detected.
**Sylvanas APIs**: `core.spell_book.is_spell_learned()`, `core.input.cast_target_spell()`, `unit:is_casting()`, `unit:get_casting_spell_id()`, `unit:is_channeling()`, `unit:get_health_percentage()`, `unit:get_threat_situation()`, `core.menu.checkbox()` for settings.
**Success Criteria**: Both files register ≥3 middleware strategies each; `test_middleware_matches_gate.lua` passes.

### [FIX-3] Burst Logic Helper Is Dead Code
**Problem**: `shared/burst_logic_sylvanas.lua` exists but is imported by **zero** playstyles. It provides `should_auto_burst()` for bloodlust/drums alignment, but every spec that uses cooldowns does so manually with `context.settings.use_cooldowns` only.
**Fix**:
1. Import `burst_logic_sylvanas` in `core_sylvanas.lua` (or ensure it is required during framework load).
2. Inject burst-context fields into `build_context()` in `main_sylvanas.lua`: `should_burst`, `burst_reason`.
3. Update at least **3** burst-capable playstyles (e.g., Fire Mage, Fury Warrior, Destruction Warlock) to check `context.should_burst` before casting major offensive CDs.
**Sylvanas APIs**: `core.spell_book.get_global_cooldown()`, `core.time()`, `unit:has_buff()`, `buff_manager.get_buff()`, `buffs.BLOODLUST` from `common/buff_db.lua`.
**Success Criteria**: At least 3 playstyle files reference burst context; tests confirm burst gating works.

### [FIX-4] DoT Refresh Helper Is Dead Code
**Problem**: `shared/dot_refresh_sylvanas.lua` exists but no playstyle imports it. Affliction Warlock, Shadow Priest, and Feral Druid all hardcode DoT refresh thresholds inline.
**Fix**:
1. Make the DoT refresh helper loadable from any playstyle.
2. Standardize at least **3** DoT-dependent playstyles to use the shared refresh gate instead of inline `debuff_remains < X` checks.
**Sylvanas APIs**: `unit:debuff_remains()`, `unit:buff_remains()`, `core.time()`.
**Success Criteria**: 3+ playstyles use shared helper; no regression in DoT uptime.

### [FIX-5] Execute Phase Helper Underused
**Problem**: Only `kebab_sylvanas.lua` uses `NS.is_execute_phase()`. Arms Warrior, Retribution Paladin, Destruction Warlock, and Shadow Priest all hardcode `target_hp <= 20` inline.
**Fix**: Convert all 4+ execute-phase-capable playstyles to use `shared/execute_phase_sylvanas.lua`.
**Sylvanas APIs**: `unit:get_health_percentage()`, `core.time()`.
**Success Criteria**: All execute-phase specs use shared helper.

## OPTIMIZATION PHASE

### [OPT-1] Centralized Settings Cache with TTL
**Problem**: `context.settings` is rebuilt every tick via schema iteration in some paths, causing table churn.
**Fix**: Implement a 50ms TTL settings cache in `core_sylvanas.lua`. Store `cached_settings` with `last_update`. On tick, only refresh if `core.time() - last_update > 0.05`. Expose `NS.refresh_settings()`.
**Sylvanas APIs**: `core.time()`, `core.game_time()`.
**Success Criteria**: Settings read latency < 1ms; no per-frame table allocation.

### [OPT-2] Reusable State Tables for Middleware
**Problem**: Middleware functions that scan enemies or build healing entries create temporary tables per invocation.
**Fix**: Convert `NS.GetEnemiesInRange()`, `NS.build_healing_entries()`, and `NS.collect_healing_units()` to use pre-allocated static tables with `{ n = 0 }` reuse pattern, resetting `n = 0` instead of creating new tables.
**Sylvanas APIs**: `core.object_manager.get_enemy_list()`, `core.object_manager.get_local_player()`.
**Success Criteria**: No `table.insert` or `{}` allocation in hot middleware paths; `test_api_lint.lua` passes.

### [OPT-3] Combat Context Throttle
**Problem**: `build_context()` in `main_sylvanas.lua` rebuilds the full context every tick. Some fields (enemy count, visible units, party allies) could be throttled.
**Fix**: Add a 100ms throttle to `NS.get_visible_units()`, `NS.GetEnemiesInRange()`, `NS.has_group_combat_ally_40()`, and `NS.build_healing_entries()`. Store cached results with timestamp.
**Sylvanas APIs**: `core.time()`, `core.game_time_ms()`.
**Success Criteria**: Context build time < 1ms average; no functional regression.

### [OPT-4] Spell Queue Integration
**Problem**: Rotations currently call `core.input.cast_target_spell()` directly in `NS.try_cast()`. This does not respect Sylvanas spell queue priority or positioning.
**Fix**: Update `NS.try_cast()` in `core_sylvanas.lua` to optionally use `spell_queue.queue_spell()` when available. Add a setting `use_spell_queue` (default false) so users can opt-in.
**Sylvanas APIs**: `require("common/modules/spell_queue")`, `spell_queue.queue_spell(spell_id, target)`, `spell_queue.is_empty()`.
**Success Criteria**: `use_spell_queue=true` routes casts through queue; `use_spell_queue=false` preserves direct casting.

### [OPT-5] IZI SDK Direct Usage for Buff/Debuff Events
**Problem**: Aura checks in `core_sylvanas.lua` (`NS.buff_up`, `NS.debuff_up`, `NS.buff_remains`) poll unit methods every tick. For persistent auras this is wasteful.
**Fix**: Register `izi.on_buff_gain()` and `izi.on_buff_lose()` callbacks in `core_sylvanas.lua` to maintain a lightweight dirty-set. Strategies that check common auras (bloodlust, forms, shields) can read from the dirty-set with near-zero cost. Full poll remains as fallback.
**Sylvanas APIs**: `require("common/izi_sdk")`, `izi.on_buff_gain(cb)`, `izi.on_buff_lose(cb)`, `izi.on_debuff_gain(cb)`, `izi.on_debuff_lose(cb)`.
**Success Criteria**: Buff checks in hot paths use dirty-set first; fallback poll still works.

## IMPROVEMENT PHASE

### [IMP-1] Interrupt Manager (Shared Module)
**Problem**: Interrupt logic is inlined in individual playstyles (e.g., kebab warrior) or missing entirely (mage, priest). No centralized interrupt priority system exists.
**Fix**: Create `shared/interrupt_manager_sylvanas.lua` with:
- Interrupt spell registration per class.
- Target casting detection via `unit:is_casting()`, `unit:is_channeling()`, `unit:get_casting_spell_id()`.
- Priority scoring for casting spells (heals > CC > damage > other).
- Configurable `interrupt_threshold` (default: interrupt anything >1.5s remaining).
- GCD and range safety checks.
Middleware in each class registers its interrupt strategy via the manager.
**Sylvanas APIs**: `core.input.cast_target_spell()`, `core.spell_book.is_spell_learned()`, `core.spell_book.get_spell_cooldown()`, `unit:is_casting()`, `unit:is_channeling()`, `unit:get_casting_spell_id()`, `unit:get_casting_percent()`, `unit:can_attack()`, `core.menu.slider_float()`.
**Success Criteria**: All 9 classes have interrupt middleware if their class has an interrupt; interrupt tests pass.

### [IMP-2] Racial Manager (Shared Module)
**Problem**: Offensive racials (Blood Fury, Berserking) and defensive racials (Will of the Forsaken, Stoneform, Escape Artist) are never automated.
**Fix**: Create `shared/racial_manager_sylvanas.lua` that:
- Detects player race via `core.character` or `unit:get_race_id()`.
- Registers offensive racial as a burst middleware strategy.
- Registers defensive racial as a defensive middleware strategy (e.g., break CC, dispel disease/poison).
- Respects settings `use_racial_offensive` and `use_racial_defensive`.
**Sylvanas APIs**: `core.spell_book.is_spell_learned()`, `core.input.cast_target_spell()`, `core.time()`, `unit:has_buff()`, `unit:has_debuff()`, `unit:get_health_percentage()`.
**Success Criteria**: At least 3 races have automated racial usage; no racial cast while global cooldown is active.

### [IMP-3] Trinket Manager (Shared Module)
**Problem**: No trinket automation exists. Cooldown-bearing trinkets are never used automatically.
**Fix**: Create `shared/trinket_manager_sylvanas.lua` that:
- Scans equipped trinkets via `NS.get_equipped_item_id(NS.EQUIPMENT_SLOTS.TRINKET1/TRINKET2)`.
- Detects trinket item IDs with known effects (build a whitelist of TBC trinkets).
- Registers offensive trinket middleware (priority during burst windows).
- Registers defensive trinket middleware (priority when HP < threshold).
- Uses `core.input.use_item()` or `izi.item(id):use()`.
**Sylvanas APIs**: `core.input.use_item()`, `izi.item(item_id)`, `core.time()`, `unit:get_health_percentage()`, `core.menu.checkbox()` for `use_trinket_1`, `use_trinket_2`.
**Success Criteria**: At least 5 TBC trinkets recognized; offensive/defensive middleware both fire when conditions met.

### [IMP-4] OOC Manager (Shared Module)
**Problem**: No out-of-combat rotation system exists. Pre-buffing, pre-healing, and pre-summoning are entirely manual.
**Fix**: Create `shared/ooc_manager_sylvanas.lua` that:
- Runs in `on_update` when `not context.in_combat`.
- Maintains self-buffs (buffs with `>30s remaining` ignored, `<=30s` refreshed).
- Summons pets if missing and class has a pet.
- Applies food/flask if configured (optional, default off).
- Respects `ooc_mana_threshold` so healers don't waste mana on pre-buffs.
**Sylvanas APIs**: `core.register_on_update_callback()`, `core.time()`, `unit:has_buff()`, `unit:buff_remains()`, `core.input.cast_target_spell()`, `core.object_manager.get_local_player()`.
**Success Criteria**: OOC buffs refresh automatically; no OOC action while in combat.

### [IMP-5] PvP Situational Awareness
**Problem**: No PvP-specific logic exists. Enemy burst detection, defensive usage under focus fire, and CC immunity checks are absent.
**Fix**: Enhance `core_sylvanas.lua` with:
- `NS.is_target_bursting()` — scans target buffs for known PvP burst CDs (Recklessness, Arcane Power, Bestial Wrath, etc.) via `unit:has_buff()` against `common/buff_db.lua`.
- `NS.should_kite()` — returns true if player HP < 50%, target is melee, and target HP > 30%.
- `NS.is_safe_to_cast(cast_time)` — checks if target is CC'd longer than cast time, or if player has defensive buff.
- Middleware in each class auto-defensive when `should_kite` or `is_safe_to_cast` fails.
**Sylvanas APIs**: `unit:has_buff()`, `unit:has_debuff()`, `unit:buff_remains()`, `unit:debuff_remains()`, `unit:get_health_percentage()`, `unit:is_in_combat()`, `core.menu.checkbox()` for PvP settings.
**Success Criteria**: At least 3 classes have PvP-aware defensive automation.

### [IMP-6] Dashboard / HUD Enhancements
**Problem**: Current dashboard (`dashboard_sylvanas.lua`) is minimal. No swing timer overlay, no DoT tracker, no burst window indicator.
**Fix**: Extend dashboard with:
- Swing timer bar using `NS.get_time_until_swing()` and `core.graphics.rect_2d_filled()`.
- Active DoT tracker: show remaining time on target debuffs using `core.graphics.text_2d()`.
- Burst window indicator: green overlay when `context.should_burst` is true.
- Threat bar: show player threat percentage via `unit:get_threat_situation()`.
**Sylvanas APIs**: `core.graphics.text_2d()`, `core.graphics.rect_2d_filled()`, `core.graphics.line_2d()`, `core.graphics.get_screen_size()`, `unit:get_threat_situation()`, `unit:debuff_remains()`.
**Success Criteria**: Dashboard renders all 4 new elements without errors; render callback only.

### [IMP-7] Combat Forecast / TTD Integration
**Problem**: `context.ttd` is computed via `unit:time_to_die()` which may be unreliable. No combat-length forecasting is used for cooldown timing.
**Fix**: Integrate `combat_forecast` module into context builder:
- `require("common/modules/combat_forecast")`
- Add `context.combat_length_forecast` using `combat_forecast.get_forecast_single(target)`.
- Gate long-CD usage (e.g., 3-min CDs) on `combat_length_forecast >= 60` or `target:is_boss()`.
**Sylvanas APIs**: `require("common/modules/combat_forecast")`, `combat_forecast.get_forecast_single(unit)`, `unit:is_boss()`.
**Success Criteria**: Long CDs respect TTD/combat forecast; no wasteful CD usage on dying trash.

## FILE TARGETS & ARCHITECTURE

### Shared Modules (create if missing, edit if existing)
- `EaxRotations/core_sylvanas.lua` — Add spell resolver cache, settings TTL cache, IZI dirty-set, PvP helpers.
- `EaxRotations/main_sylvanas.lua` — Add burst context injection, combat forecast integration, throttle gates.
- `EaxRotations/shared/spell_resolver_sylvanas.lua` — **NEW** spell ID cache.
- `EaxRotations/shared/interrupt_manager_sylvanas.lua` — **NEW** interrupt logic.
- `EaxRotations/shared/racial_manager_sylvanas.lua` — **NEW** racial automation.
- `EaxRotations/shared/trinket_manager_sylvanas.lua` — **NEW** trinket automation.
- `EaxRotations/shared/ooc_manager_sylvanas.lua` — **NEW** out-of-combat rotation.
- `EaxRotations/shared/burst_logic_sylvanas.lua` — **EXISTING** integrate into context + 3+ playstyles.
- `EaxRotations/shared/dot_refresh_sylvanas.lua` — **EXISTING** integrate into 3+ playstyles.
- `EaxRotations/shared/execute_phase_sylvanas.lua` — **EXISTING** integrate into all execute specs.
- `EaxRotations/dashboard_sylvanas.lua` — Extend with swing, DoT, burst, threat overlays.

### Class Middleware (populate empty ones)
- `EaxRotations/classes/warrior/middleware_sylvanas.lua`
- `EaxRotations/classes/mage/middleware_sylvanas.lua`
- All other classes: integrate interrupt_manager, racial_manager, trinket_manager registrations.

### Playstyle Files (update 3+ for burst, 3+ for DoT, all execute specs)
- `EaxRotations/classes/mage/fire_sylvanas.lua`
- `EaxRotations/classes/warrior/fury_sylvanas.lua`
- `EaxRotations/classes/warlock/destruction_sylvanas.lua`
- `EaxRotations/classes/priest/shadow_sylvanas.lua`
- `EaxRotations/classes/druid/feral_sylvanas.lua` (for DoT refresh)
- `EaxRotations/classes/warrior/arms_sylvanas.lua` (for execute)
- `EaxRotations/classes/paladin/retribution_sylvanas.lua` (for execute)

### Tests (add new tests)
- `EaxRotations/tests/test_spell_resolver_cache.lua`
- `EaxRotations/tests/test_interrupt_manager.lua`
- `EaxRotations/tests/test_racial_manager.lua`
- `EaxRotations/tests/test_trinket_manager.lua`
- `EaxRotations/tests/test_ooc_manager.lua`
- `EaxRotations/tests/test_burst_logic_integration.lua`
- `EaxRotations/tests/test_dot_refresh_integration.lua`

## VERIFICATION CRITERIA

### Build
- `luac -p` passes on **every** modified `.lua` file.
- `lsp_diagnostics` returns 0 errors on changed files.

### Tests
- All existing 29 tests must still pass: `lua EaxRotations\tests\test_*.lua`.
- New tests must pass: at minimum the 7 new tests listed above.

### Functional QA
- Spell resolver caching: log shows resolution time drop (use `debug_system` setting).
- Burst logic: enable `use_cooldowns`, enter combat with bloodlust active, verify offensive CDs fire.
- Interrupt: target a training dummy casting a healable spell, verify interrupt fires when ready.
- Racial: create an orc/troll/undead/dwarf/gnome character, verify racial fires under conditions.
- Trinket: equip a known TBC offensive trinket, verify it fires in burst window.
- OOC: stand out of combat with missing self-buff, verify buff is recast.
- Dashboard: verify swing bar, DoT tracker, burst indicator, and threat bar render without Lua errors.

## COMPLIANCE RULES

1. **No banned APIs**: Never use `ffi.C`, `io.popen`, `os.execute`, `debug.*`.
2. **No `.toc` files**: Do not create or modify `.toc` files.
3. **TBC-only spells**: Only spells valid in TBC Classic (up to patch 2.4.3).
4. **No external platform references**: Only `api/` and `apidocs/` APIs.
5. **Nil guards**: Every menu/widget access must be guarded: `(menu.x and menu.x:get()) or default`.
6. **Static table reuse**: Hot paths must use `{ n = 0 }` pattern, not allocate new tables per frame.
7. **API caching**: Cache `core.*` function references at module load.
8. **Squared distance**: If implementing custom range checks, use `dx*dx + dy*dy`, never `math.sqrt()`.
9. **No type suppression**: Do not use `as any`, `@ts-ignore`, or equivalent.
10. **No WotLK/Cata spells**: Strictly TBC-era spell IDs only.
11. **No references**: Do not mention, hint at, or allude to any non-Sylvanas codebase, project name, or author in code, comments, or commit messages.

## SUGGESTED IMPLEMENTATION ORDER

1. **Spell resolver cache** (FIX-1) — performance foundation.
2. **Settings cache + context throttle** (OPT-1, OPT-3) — reduce tick overhead.
3. **Burst logic integration** (FIX-3) — DPS impact.
4. **DoT refresh + execute phase standardization** (FIX-4, FIX-5) — consistency.
5. **Interrupt manager** (IMP-1) — safety/utility for all classes.
6. **Racial manager** (IMP-2) — DPS/HPS gain.
7. **Trinket manager** (IMP-3) — DPS gain.
8. **OOC manager** (IMP-4) — quality of life.
9. **PvP awareness** (IMP-5) — defensive automation.
10. **Dashboard enhancements** (IMP-6) — UX.
11. **Combat forecast** (IMP-7) — CD efficiency.
12. **Fill empty Warrior/Mage middleware** (FIX-2) — completeness.
13. **Tests + QA**.

---

**Deliverable**: A branch or set of commits that passes all verification criteria above. Report which files were changed, which tests were added, and which functional QA scenarios were executed with observed results.
