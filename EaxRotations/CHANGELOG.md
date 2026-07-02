# Changelog

## 2.3.1 - 2026-07-02

### PvP DR Gating Fixes
**Affected specs:** Holy Paladin, Protection Paladin, Combat Rogue, Subtlety Rogue

Added `NS.DRTracker.is_dr_immune()` checks to stun abilities that were casting into immune targets:

- **Hammer of Justice** (Holy + Protection Paladin) — now gated on `stun` DR
- **Cheap Shot** (Combat Rogue) — now gated on `stun` DR
- **Kidney Shot** (Combat + Subtlety Rogue) — now gated on `stun` DR

This prevents wasting a full-duration stun on a target that is already DR-immune, which is the single biggest PvP efficiency gain in the framework.

### Warrior Death Wish Fear Break
**Affected spec:** Fury Warrior

`death_wish_matches` now checks `is_feared_sapped_or_incapacitated()` before the normal burst CD logic. If the player is feared, Death Wish fires immediately as a reactive break (it grants fear immunity in any stance, unlike Berserker Rage which requires Berserker Stance).

### Druid Barkskin Configurability
**Affected spec:** Restoration Druid

Replaced the hardcoded `55%` HP threshold in `BarkskinSelfPreservation` with `settings.barkskin_hp or 55`. The schema already exposed this slider; the rotation now respects it.

### Shaman Tremor Totem PvP Coverage
**Affected spec:** Enhancement Shaman

`auto_tremor_sylvanas.lua` previously only dropped Tremor Totem when targeting one of 17 known fear-casting boss NPCs. It now also checks `detect_fear_on_ally()` — if any nearby party member has a fear debuff (Warlock Fear, Priest Psychic Scream, etc.), the totem drops automatically.

### PvP Feature Page Accuracy
Rewrote `docs/PVP_FEATURE_PAGE.md` from a full code audit. Removed false claims (e.g., abilities listed as DR-gated that were not). Documented actual behavior with file references. Added "Known Gaps" section so players know what is and is not implemented.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.0 - 2026-07-02

### Server-Authoritative Swing Timer (CLEU)
**Affected specs:** Retribution Paladin, Enhancement Shaman, Arms Warrior, Fury Warrior, Kebab Warrior

Replaced frame-polling swing prediction with direct Combat Log Event (CLEU) tracking. The rotation now reads the exact server swing timestamp instead of estimating it.

- Seal twisting is judged against real server data — no more phantom twists from latency or haste drift
- Diagnostics report `PERFECT`, `LATE`, or `PHANTOM` with millisecond precision
- Enhancement Shaman Stormstrike alignment and Warrior Heroic Strike trick timing both use the same authoritative source
- Falls back automatically to native prediction if the CLEU API is unavailable

### Instant Snap Threat on Pull
**Affected specs:** Protection Paladin, Protection Warrior

Snap Threat now hooks the `PLAYER_REGEN_DISABLED` event, firing your opener the exact frame combat begins. This gives Judgement / Shield Slam a ~50-100ms head start before DPS opens, reducing early aggro loss on trash and boss pulls.

### Light's Grace Chaining
**Affected spec:** Holy Paladin

When Light's Grace has less than 2.5 seconds remaining, the rotation automatically queues another Holy Light to keep the 0.5-second cast-time reduction rolling. Only fires in combat, only when a tank target exists, and remains below Divine Favor + Holy Shock on priority so emergency combos still win.

### Blessing of Kings Party Buff
**Affected spec:** Protection Paladin

New out-of-combat strategy scans party members and applies Blessing of Kings to anyone missing the buff. Gated by a setting (default enabled).

### Configurable DoT Refresh Windows
**Affected spec:** Shadow Priest

Replaced hardcoded refresh thresholds with user-configurable sliders:

| Setting | Range | Default |
|---------|-------|---------|
| VT Refresh Window | 0.5s – 3.0s | 1.5s |
| SW:P Refresh Window | 0.5s – 3.0s | 1.5s |

Lower values clip closer to expiration (better for low latency). Higher values refresh earlier (safer for movement-heavy encounters). Fully backward compatible.

### Quality & Reliability
- **219 rotation test suites** — all passing
- **13 leveling rotation suites** — all passing
- All changes are additive with safe fallbacks. No breaking changes, no settings reset required.

## 2.2.2 - 2026-06-29

### Critical Runtime Fixes
- **`core_sylvanas.lua`**: Removed unresolved git merge conflict markers (`<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes`) that caused runtime load failure—"Failed to load core_sylvanas: file is not found". The Lua parser rejected the file at require-time.

### Engine & Trace Hardening
- **`main_sylvanas.lua`**: Per-list trace throttle—`_trace_strat_last` was a single global shared by ALL strategy lists. AutoConsumable (first match every tick) claimed the one 2-second log slot, silencing ALL spec strategy traces. Changed to table keyed by list name (`_trace_strat_last[list_name]`).

### Consumable Manager Fix
- **`shared/consumable_manager_sylvanas.lua`**: Added in-combat threshold guard to `should_check()`. Now only returns `true` when `hp <= 60` or `mana_pct <= 50`. Previously returned `true` on every combat tick regardless of HP/mana, causing `matched=true, executed=false` trace spam and wasted CPU.
- All 9 class middleware files (`druid`, `hunter`, `mage`, `paladin`, `priest`, `rogue`, `shaman`, `warlock`, `warrior`) now use `consumable_manager.should_check()` instead of raw `context.in_combat`.

### Test Results
- **208/208 rotation suites pass**
- **11/11 leveling suites pass**
- **423 files syntax-checked (luac -p)**
- **61/61 DBC spell audit clean** (all spell IDs exist in WoW 2.5.5.68101 client)

## 2.2.1 - 2026-06-29

### Warrior Fear Break + Arms Polish
- **Arms**: Added `BerserkerRage` strategy—was tracked in state but never cast. Breaks fear, sap, and incapacitate via static debuff ID lists.
- **Arms**: `DeathWish` now also breaks fear (enrage effect).
- **Fury**: Enhanced `BerserkerRage` to auto-cast when feared/sapped/incapacitated.
- **Protection**: Same fear-break enhancement for `BerserkerRage`.
- All 208 rotation suites + 11 leveling suites pass.

## 2.2.0 - 2026-06-27

### Architecture: Strategy Gating Deduplication
- Created `core/strategy_gating.lua` as single source of truth for strategy category classification.
- Eliminated duplicated `HEALING_PLAYSTYLES`, `HEALING_NAMES`, `DAMAGE_NAMES`, `COOLDOWN_NAMES`, `UTILITY_NAMES`, `DEFENSIVE_NAMES`, `contains_any`, `strategy_category`, and `strategy_allowed` between `core_sylvanas.lua` and `main_sylvanas.lua` (~200 lines of duplicated code).
- Standardized `strategy_allowed` return signature to 3 values (allowed, reason, category) in both files.
- Both files now `require("core/strategy_gating")` with fallback definitions.

### Performance Hardening
- Enemy cache: upgraded from single-range to multi-range per-tick cache—eliminates cache thrashing when specs query melee(5), AoE(8), and scan(40) ranges in the same tick. Supports up to 8 cached ranges with LRU eviction.
- Immunity buff cache: `evaluate_cast` now caches target immunity buffs (Divine Shield, Ice Block, BOP, Cloak, WotF, Berserker Rage) per (target, tick)—eliminates 6 redundant `buff_up` calls per cast attempt.
- `collect_healing_units`: eliminated per-call table allocation—now uses a static output buffer.
- `is_item_equipped`: upgraded from O(19 × N) slot scans per call to O(N) set lookup using a per-tick equipped items set cache.
- `count_equipped_set`: now uses the same per-tick cache instead of re-scanning all 19 slots.
- `core/items.lua`: eliminated per-function `pcall(function() safe = NS.safe end)` allocations—`safe`/`safe_field` now captured once at install time as upvalues (saves 2 pcall allocations per function call).

### Critical Bug Fixes
- Arms Warrior: fixed `stance_swap_safe` typo (`preserved_rage_after_swapstate.rage` → `preserved_rage_after_swap(state.rage or 0)`)—stance swaps were crashing on every call.
- Arms Warrior: moved `ARMS_SCHEMA` declaration before `build_state` function—`safe_state` was receiving nil schema, making all custom defaults dead code.
- Arms Warrior: fixed `mortal_strike_matches` dead rage-cap bypass—both branches returned identical actions; rage-cap branch now omits `min_rage` gate.
- Core: fixed `get_spell_id` per-frame table allocation—was passing `{}` to `collect_ids` on every call instead of using the static buffer.
- Core: wrapped `spell_helper_castable` native API call in pcall—a single throw was aborting the entire rotation tick.
- Core: removed duplicate `_settings_cache` declarations (lines 151 + 353)—second set was dead state.
- Core: fixed `filter_spell_ids_for_expansion` no-op (`if true then` guard)—now actually filters TBC-only spell IDs (level > 60) on Vanilla.
- Core: removed dead `if false then return true end` branch in `NS.spell_exists`.
- Core: fixed `cooldown_remains` dead expression `false and 0.15 or 1.0` → `1.0` with explanatory comment.
- Core: renamed `NS.isfalse()` to `NS.is_api_health_broken()` (alias preserved for backward compat).

### Spec Fixes
- Balance Druid: fixed `_choose_nuke` dead Nature's Grace logic—fallback now returns "wrath" (mana efficiency) instead of "starfire", making the Nature's Grace check meaningful.
- Frost Mage: gated Fire Blast, Scorch, and Arcane Missiles behind explicit opt-in settings (`frost_use_fire_blast`, `frost_use_scorch`, `frost_use_arcane_missiles`)—were firing as unintended fillers.
- Discipline Priest: removed duplicate `PowerWordShieldLowest` strategy (identical to `EmergencyPowerWordShield`).
- Enhancement Shaman: removed debug logging (`_enh_lb_count` + `NS.log`) left in `lightning_bolt_matches`.
- Fury Warrior: removed dead `thunder_ready` state field and its `spell_ready` API call (Thunder Clap not used by Fury).
- Beast Mastery Hunter: fixed `is_item_ready` global function leak (missing `local` keyword).
- Affliction Warlock: added nil-guard to snapshot mutations (`if ok and aff_state.spell_damage then`).
- Balance Druid: standardized namespace alias from `_G_E` to `NS` (82 references replaced).

### Performance
- Core: `get_spell_id` no longer allocates a per-call table—uses existing `_collect_buf` static buffer.
- Main: `_context.lowest` table pre-allocated at module level instead of per-frame allocation.
- Main: removed dead `pre_aoe` variable assignments.

### Code Cleanup
- Core: removed `VANILLA_HIGH_SPELL_ALLOWLIST` (dead table, never referenced).
- Core: removed `_last_cast_time_cooldown` dead function (zero callers).
- Core: removed `_settings_manager` disabled pcall(require)—result was immediately discarded.
- Core: removed `EnemyCDTracker.has_major_offensive_active_or_recent` and `get_enemy_cds` stubs (zero callers).
- Core: removed `get_spell_damage` and `match_fail` stubs (zero callers).
- Core: removed `if true then` dead guards in `collect_ids` (3 sites).
- Core: added `-- Stub: extension point for future modules` comments to `player_control_locked` and `has_breakable_cc_nearby` (have callers, kept as extension points).
- Core: generated `cc_is_*` bridge functions (13 functions) from a table—eliminated ~80 lines of identical boilerplate.
- Core: generated `unit_is_*` bridge functions (7 functions) from a table—eliminated ~50 lines of identical boilerplate.
- Core: `is_hostile_unit` now short-circuits on definitive `can_attack` false result—eliminates up to 6 redundant API path checks per call.

### Shared Modules
- `potion_helper_sylvanas.lua`: added `HEALTHSTONE_IDS` table and `find_ready_healthstone()` function for cross-spec reuse.
- `match_helpers_sylvanas.lua`: added shared `cooldowns_enabled(context, opts)` helper—eliminates 16 duplicate `cooldowns_allowed`/`cooldowns_enabled` functions across spec files. Supports default-on, opt-in, require-combat, and state-table calling conventions.

### Warrior Shared Helpers
- Created `classes/warrior/shared_helpers_sylvanas.lua`—extracted 9 duplicated helper functions from Fury and Arms (`setting`, `bool_call`, `execute_phase`, `desired_stance`, `preserved_rage_after_swap`, `stance_swap_safe`, `action`, `cast`, `build_action`).
- Both `fury_sylvanas.lua` and `arms_sylvanas.lua` now require the shared module with fallback definitions.

### Test Infrastructure
- Fixed hardcoded Windows path in `test_leveling_druid.lua`—replaced with relative `package.path` pattern.
- Wired 14 orphaned test files into `run_rotation_tests.lua` (12 leveling + 2 reset_api_health).
- Added shared `assert_true` and `assert_eq` helpers to `test_runner_lib.lua`.
- Created `test_arms_critical_fixes.lua`—regression tests for the 3 Arms Warrior critical bugs (stance_swap_safe typo, ARMS_SCHEMA scoping, mortal_strike dead bypass). All pass.

### Documentation
- Updated `TECHNICAL_GUIDE.md` version from 1.0.15 to 1.1.1.
- Updated line number references in technical guide to use descriptive text instead of stale line numbers.
- Added staleness note to `status_audit.md`.
- Created `docs/CONTRIBUTING.md` with codebase overview, spec creation guide, test instructions, and coding conventions.

## 2.1.0 - 2026-06-06

- Debug cleanup: removed all developer debug infrastructure (debug_mode, trace, force_flags) from public codebase; 7 commits across main_sylvanas, main, enhancement, and shaman schema.
- Buff rank upgrade system: `NS.buff_rank()` in core_sylvanas.lua detects active buff rank position; `shared/buff_upgrade_sylvanas.lua` scans self + party for lower-rank buffs and auto-casts upgrades; OOC integration via middleware; 10 dedicated tests.
- Shadow priest fixes: DispelMagic returns false (middleware handles friendly cast), Fade requires party members, ManaBelow5Wand guards target existence.
- Warrior gap fixes: Prot threat cycling (Devastate/Revenge/Shield Slam priority), creature type filter fix, rage pooling for Execute phase, Disarm fix for PvP.
- API compliance audit: 9 context fields implemented across 34 spec files (target_hp, target_hp_pct, enemy_count, etc.).
- Core infrastructure audit: 5 dead/stub functions removed, 3 missing school locks added, get_spell_damage fixed to return actual values.
- Spell ID corrections: lexxer-verified spell IDs across all specs; cross-expansion Vanilla rank data added to SpellRankResolver.
- APL registry bridge: shared/apl_parser.lua wired into dispatcher (unused by specs, infrastructure ready).
- Vanilla cleanup: removed TBC-only spell IDs (level > 60) from _vanilla.lua rotation files.
- Flux references removed from public repo.
- Test count: 111/111 rotation + 11/11 leveling + 10/10 buff upgrade = 132 total tests passing.

## 1.1.0 - 2026-05-26

- Debug Log: fixed `ScrollDebugLogBottom` crash when `debug_window` size returns nil (nil-guard added).
- Debug Log: fixed `handle_resize` crash when `get_size()` returns nil during resize drag.
- Debug Log: guarded `core.game_ui.get_wow_cursor_position` access behind type-check to prevent crash on missing API.
- Debug Log: reconciled `ALWAYS_AUTO_RESIZE` flag with manual resize logic—manual resize now works predictably without window system conflicts.
- Debug Log: removed orphaned duplicate resize end-check blocks that caused syntax errors.
- Healer Engine: verified `cast_duration > 0` guard exists at line 92 before division; no change needed.
- Core: fixed `NS.action_execute` skip-GCD paths to route through `NS.evaluate_cast` (was bypassing cooldown/resource/range/anti-flicker/reagent checks).
- Warrior Protection: fixed stance-swap return to use `NS.try_cast(...) == true` (was `~= nil` which treated `false` as success).
- Debug Log: added `get_debug_window_size()` helper; all callers now guarded against nil size.
- All 291 Lua files pass `luac -p`.
- All 106 rotation suites + 11 leveling suites pass with zero failures.
- Release package: only `.lua` and `.md` files under `EaxRotations/`. Version bumped to 1.1.0.
- Core: `cast_unit_spell` and `cast_position_spell` now fail-closed when IZI `cast_safe` rejects a cast—previously fell through to raw `core.input.cast_target_spell`, allowing spell spam.
- Core: healing scan now falls back to visible friendly units when party APIs return only self, preventing healers from ignoring group allies.
- Elemental Shaman: Lightning Shield strategy now mirrors Enhancement charge-throttle, skipping recast when charges remain.
- Elemental Shaman: state builder now tracks `has_lightning_shield`, `lightning_shield_charges`, and `lightning_shield_ready`.
- Tests: fixed `run_rotation_tests.lua` exit-code detection to properly surface failures; removed duplicate `test_execute_phase.lua` entry.

## 1.0.17 - 2026-05-21

- Druid Balance: SP breakpoint research completed—TBC spell coefficients verified (Starfire ~1.0, Wrath ~0.571/0.671, Moonfire ~0.15 direct + ~0.52 DoT, Insect Swarm ~0.76) against Elitist Jerks, Wowhead, and wowsims sources.
- Druid Balance: 800/1000/1200 SP breakpoints confirmed—these thresholds are DoT GCD-value decisions, not Starfire vs Wrath filler preference; Starfire wins at all SP levels on mana efficiency and crit synergy.
- Docs: all three `[VERIFY]` tags in `Research.md` Angle 4 resolved to `verified`.
- Docs: `SP_Breakpoints_Druid_Balance.md` blocker file rewritten with comprehensive coefficient analysis, corrected mathematical proof, and deferred-implementation recommendation (Option B).
- Docs: `Druid_Balance_CHECKLIST.md` SP breakpoint row updated to verified status.

## 1.0.16 - 2026-05-21

- Druid Balance: smart Innervate targeting—party scan identifies healer-class units (Paladin/Priest/Shaman/Druid) and picks the lowest-effective-HP target for InnervateHealer strategy; InnervateSelf fallback when no suitable healer found.
- Druid Balance: Hurricane Barkskin automation—Hurricane now defers when Barkskin is ready (not on cooldown), letting PreHurricaneBarkskin handle the Barkskin→Hurricane sequence for 20% damage reduction synergy.
- Discipline: PW:S absorb tracking via `Healing.pws_absorb_remaining`—skips PW:S recast when remaining absorb exceeds 200 (prevents wasting mana and triggering Weakened Soul unnecessarily).
- Core: `NS.buff_points`/`NS.debuff_points` read the `points` array from aura data, enabling variable-value tracking (Holy Shield charges, PW:S absorb remaining, etc.).
- Tests: fixed `test_balance_custom_matches.lua` Hurricane cooldown mock for Barkskin-ready deferral logic.
- Docs: AGENTS.md updated with Patterns 11–13 (buff_points, PW:S absorb tracking, smart Innervate targeting); all stale per-spec library references cleaned up for flat-file architecture.
- Queue: 001_Druid_Balance moved from `blocked/` to `completed/` (2 of 3 blockers resolved); remaining SP breakpoints tracked in `SP_Breakpoints_Druid_Balance.md`.
- All 106 regression suites (95 rotation + 11 leveling) pass with zero failures.

## 1.0.15 - 2026-05-16

- Improved TBC spell and aura coverage for racials, common crowd control, Druid utility, and Hunter abilities.
- Improved Hunter leveling stability, including safer API fallbacks and correct Serpent Sting refresh timing.
- Improved Warrior buff-cancel and Shaman totem handling through safer shared helpers.
- Cleaned the release package so it contains only Lua source and Markdown documentation.
- Added audit documentation for spell IDs, archive comparisons, and static behavior checks.
- Verified release health: Lua syntax passes, all 106 regression suites pass, online TBC ID audit passes, and package file-type checks pass.

## 1.0.14 - 2026-05-15

- Made menu playstyle selection authoritative: Leveling no longer overrides Elemental, Enhancement, or Restoration for under-70 players.
- Fixed Enhancement self-heals so Lesser Healing Wave and Chain Heal do not fire at full health.
- Added Enhancement self-heal HP controls and throttled fallback Lightning Shield refreshes in the Leveling playstyle.

## 1.0.13 - 2026-05-15

- Added Shaman leveling weapon imbue support with auto Windfury/Rockbiter/Flametongue selection.
- Added Shaman leveling Searing, Strength of Earth, and water totem support with refresh throttles.
- Added missing TBC Shaman spell entries used by leveling: weapon imbues, Searing Totem, Stoneclaw Totem, and Healing Stream Totem.

## 1.0.12 - 2026-05-15

- Fixed Shaman Leveling loading but not registering with the dispatcher, which left the selected Leveling playstyle with no actions to run.
- Fixed Shaman Leveling using the legacy empty `NS.SPELLS` table instead of `NS.ShamanSpells`.
- Fixed Druid, Rogue, and Warrior Leveling dispatcher registration; all class leveling modules now register the `leveling` playstyle.
- Under-70 characters now run the Leveling playstyle as a pre-pass before the selected spec, so leveling support works automatically instead of requiring manual playstyle selection.
- Improved broken `spell_book.is_spell_learned` fallback to choose the best rank allowed by player level when spell metadata includes rank levels.
- Fixed low-level Shaman OOC buff fallback so Water Shield is not attempted before level 60 and Lightning Shield can be maintained below that level.

## 1.0.11 - 2026-05-15

- Fixed "trying to pop up spell which isnt learned": when spell_book API is broken, `NS.get_spell_id` now returns the lowest rank (`ids[#ids]`) instead of the highest (`ids[1]`). This ensures low-level players always get a castable spell rank.
- Both the normal resolution path and the fallback path now use lowest-rank-safe logic when API health is broken

## 1.0.10 - 2026-05-15

- Fixed `[DIAG] buff_up` printing table addresses instead of spell IDs (now shows `27044,25296,...`)
- Fixed `rotation callback failed` spamming every frame: rate-limited to once per 2s, changed from log_error to log
- Fixed `NS.get_spell_id` cache poisoning: clear spell cache when API health break is detected so previously cached fallback IDs get re-resolved
- Fixed rotation running in character menu/dead: added guards for `core.is_main_menu_open()`, `player:is_alive()`, and player existence check in `main.lua on_update`

## 1.0.9 - 2026-05-15

- Full system audit: 195 Lua files, 46 shared modules, 65 tests checked
- All files pass luac -p and LSP with zero errors
- Zero banned API violations confirmed
- All hot-path NS.log calls gated behind debug_system (74 guards)
- README synced to v1.0.9, status set to Stable
- Shared module audit: no duplicate overlap with core_sylvanas.lua
- Spec audit: druid/caster identified as thin (7 strategies)
- Retribution uses add_strategy (38 calls), Arms uses STRATEGY_SPECS (29 entries)

## 1.0.8 - 2026-05-15

- Properly compared archive modules vs new system: deleted `dot_manager_sylvanas.lua` (duplicate of existing `dot_refresh.lua` + `NS.should_refresh_dot`), `threat_manager_sylvanas.lua` (duplicate of existing `NS.should_drop_threat`/`NS.threat_status`), `dispel_engine_sylvanas.lua` (duplicate of `NS.has_dispel_type_debuff`/`NS.healing_get_cleanse_target`, used raw WoW API), `mana_conservator_sylvanas.lua` (duplicate of `NS.mana_pct`/`action.min_mana`)
- Rewrote `pet_manager_sylvanas.lua` to match archive's full state machine (per-spec tracking, pet spell scanning, growl/claw/special rotation with cooldown gating)
- Fixed `consumable_manager_sylvanas.lua` typo (`griffed` -> `grilled_mudfish`)
- Removed unused `SCROLLS` table from consumable_manager (no callers)
- Verified all remaining shared modules (`totem_manager`, `pvp_manager`, `pet_manager`, `consumable_manager`) have no duplicates in the existing system

## 1.0.7 - 2026-05-15

- Ported 3 shared modules from archive: `pet_manager_sylvanas.lua`, `totem_manager_sylvanas.lua`, `pvp_manager_sylvanas.lua`
- Pet manager: pet attack/follow/passive controls, growl/claw/bite/special ability casting, HP monitoring
- Totem manager: bag scanning for totem items, per-spec totem placement (elemental/enhancement/restoration), full TBC spell ID tables
- PvP manager: arena/BG map detection, enemy player targeting with healer priority, PvP trinket detection, arena frame support

## 1.0.6 - 2026-05-15

- Added diagnostic logging to `NS.buff_up`: logs when all buff detection methods fail (enable debug_system to see)
- Added `min_interval` support to action rows and `NS.action_matches`—prevents recast of buff actions within N seconds
- Added per-spell 5s rate limiter in `NS.try_cast` via `_last_spell_cast[id]` tracker—prevents same spell from being cast more than once per 5s regardless of code path
- Set `min_interval = 60` for Aspect of the Hawk and `min_interval = 30` for Aspect of the Viper across all 3 hunter specs
- Added `_last_action_exec` / `_last_spell_cast` timestamps at all cast success paths

## 1.0.5 - 2026-05-15

- Added comprehensive auto-consumable system: shared `consumable_manager_sylvanas.lua` manages flasks, potions, elixirs, food, scrolls, weapon buffs, drums, healthstones, and runes for all 9 classes
- Wired consumable strategies into all class middleware (warrior, mage, druid, hunter, warlock, paladin, shaman, priest, rogue)
- Consumables auto-detect class role for optimal item selection
- Throttled to 3s checks; logging behind debug_system only

## 1.0.4 - 2026-05-15

- Gated remaining un-gated logs behind `debug_system`: Druid Bear item usage, Druid middleware consumables, Warrior middleware (HS dequeue, PW:S/BoP cancel), Mage middleware mana gem
- Cross-spec audit complete: all `NS.log()` calls in hot paths now gated behind `debug_system` setting

## 1.0.3 - 2026-05-15

- Fixed Hunter rotation ability spam: KillCommand and AspectOfTheHawk no longer spammed every frame
- Added 0.3s anti-flicker protection to `skip_gcd` cast path in `core_sylvanas.lua`—covers all skip_gcd actions across all classes (KillCommand, Bloodrage, Powershift, etc.)
- Gated all action execution debug logs behind `debug_system` setting in `NS.action_execute`, `NS.try_cast`, and `NS.try_cast_position`
- Gated Paladin Holy item usage logs behind `debug_system`
- Gated Druid Resto mana potion log behind `debug_system`
- Restored `exporter.lua` from broken state (malformed table syntax, undefined variable reference)
- All version refs synced across header.lua, exporter.lua, optimizer_bridge.lua

## 1.0.2 - 2026-05-15

- Full diagnostic audit across all 29 specs: verified spell IDs, buff checks, nil safety, API compliance
- Fixed version inconsistencies across exporter.lua, optimizer_bridge.lua, and header.lua
- All 62 tests passing; luac -p passes on all .lua files; zero banned API usage
- Verified zip contains only .lua and .md files

## 1.0.1 - 2026-05-15

- Fixed Hunter Aspect of the Hawk rank IDs to prevent repeated Hawk recasts.

## 1.0.0 - 2026-05-15

- Initial release
