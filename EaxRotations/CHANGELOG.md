# Changelog

## 2.19.0 — 2026-08-08

### Customer Changelog
- **Full rotation audit complete (304 → 100 never-firing strategies)**: a
  behavioral test battery now runs every strategy in every spec across 135
  realistic combat scenarios (all 31 specs, 0 load failures) and flags any
  strategy that never fires. 204 strategies that were unreachable in the
  battery were triaged — most were correctly silent (opt-in settings,
  PvP/stealth/OOC-only, or cooldown-state gating) — but **13 were genuine
  dead lanes fixed in live play**, including:
  - **Protection Warrior Intervene**: the party-scan + matcher truncated the
    vec3 position API (read `{x,y,z}` fields instead of multi-value capture),
    so Intervene could never fire in live play; also fixed the same
    position-read family across the codebase (audit doc:
    `docs/position_contract_audit_2026-08-08.md`).
  - **Warlock Destruction pet summons**: `SummonFelhunter`/
    `SummonVoidwalker`/`SummonFelguard` were hardcoded off in
    `summon_pet_matches`; all three preference branches now work.
  - **Mage**: arcane/frost `healthstone_ready` + `mana_gem_available` and
    fire `hp_pct` build_state assignments unblocked Healthstone/IceBarrier/
    ManaShield/Mana Gem lanes.
  - **Priest/Druid/Hunter**: holy `mana_pct` (ManaPotion), resto
    `healthstone_ready` (Healthstone), MM `BestialWrath` spell_exists gate,
    and disc/holy/resto `Preemptive*Heal` state wiring.
- **33 battery regression suites** pin every unblocked lane family so a
  future edit can't silently re-hide them.
- Version **2.19.0**.
- Tests: 469 rotation + 33 leveling suites registered (461 rotation passing at
  runtime; 5 pre-existing env/data-file gaps).

### Developer Notes
- **Campaign**: 304 → 254 → 249 → 224 → 219 → 218 → 217 → 216 → 215 → 213 →
  207 → 194 → 183 → 180 → 176 → 173 → 161 → 152 → 151 → 145 → 144 → 140 →
  133 → 130 → 125 → 118 → 112 → 111 → 110 → 109 → 108 → 106 → 105 → **100**
  (DPS 13 + non-DPS 87); final split **(b) 38 · (c) 62 · (a) 0 · (d) 0** —
  zero opt-in and zero dead lanes remain.
- **Battery upgrades** (all in `tests/behavioral_audit.lua`, now 135
  scenarios): unit-aware `buff_up`/`debuff_up`/`debuff_remains` maps,
  `setting_overrides` fixture (covers direct `ctx.settings`,
  `spec_kit.setting`, and DSL setting conditions), `not_learned` map,
  `on_cd`/`swing_until`/`combat_time`/`target_cast_pct`/`hit_rating`
  overrides, friend mocks with `get_class`/`get_position`/`get_owner`,
  heal-scan deficit fix, per-buff scenarios (lights_grace, seal-twist,
  affliction/dispel), party-frame `get_friendly_target_entry`, scenario-aware
  `FsrManager` + `TrinketManager`-style stubs, elite/undead/pvp/stealth/
  boss creature-type + threat scenarios.
- **Spec fixes (13 dead lanes)**: fire/arcane/frost mage, holy priest,
  resto druid, MM hunter, disc/holy/resto Preemptive heal-state, destro
  warlock summons ×3, prot warrior Intervene (real live bug — multi-value
  `get_position` truncation, reclassified (b)→(d) during the sweep).
- **Triage docs**: `docs/never_strategy_triage_dps_2026-08-07.md` +
  `docs/never_strategy_triage_non_dps_2026-08-07.md` (per-lane probe
  evidence + campaign summary); `docs/position_contract_audit_2026-08-08.md`
  (full codebase position-read audit).

## 2.18.1 — 2026-07-29

### Customer Changelog
- **EaxESP attachment API crash fix**: Resolved the critical bug where `get_attachment_position()` and `get_attachment_name_position()` caused hard client crashes (native access violations). All attachment API calls have been eliminated — the renderer now uses `pos.z + offset` fallback for all height calculations. Diagnostic tools are gated behind an explicit opt-in global.
- Version **2.18.1**.
- All tests passing: 398 rotation + 31 leveling suites (429 total).

### Developer Notes
- **Attachment API resolution**: Both `get_attachment_position(id)` and `get_attachment_name_position()` cause native access violations on Sylvanas Core 1.981+ that `pcall` cannot intercept. Resolution: eliminate all API invocations.
- `EaxESP/attachment_safe.lua` — `probe_once()` does existence-only checks (`type() == "function"`); `name_pos()` and `attachment_pos()` always return `nil`; `head_position()` uses `get_position() + offset`; dead code (`vec3_ok`, `copy_vec`, `M._ok_ids`) cleaned.
- `EaxESP/diagnostic_attachment_only.lua` — API calls gated behind `_G.EAXESP_ALLOW_ATTACHMENT_CALLS=true`.
- `EaxESP/diagnostic_api_crash.lua` — Attachment entries gated behind `EAXESP_ALLOW_ATTACHMENT_CALLS`; non-attachment methods still run.
- `EaxESP/tests/test_attachment_safe_module.lua` — Assertions updated for always-nil behavior.
- `EaxESP/tests/test_attachment_safe_probe.lua` — `probe()` and `probe_target()` gated behind `EAXESP_ALLOW_ATTACHMENT_CALLS`.
- **Full audit**: `reader.lua`, `main.lua`, `renderer.lua` confirmed zero direct calls to attachment APIs — all go through `attachment_safe.lua`.
- **Planning notes archived**: Both bug reports + crash hardening notes archived.
- EaxESP files are `.gitignored` (local-only); changes applied locally.

## 2.18.0 — 2026-07-29

### Customer Changelog
- **9-class audit complete**: ~32 bugs fixed across all 9 class directories (Paladin, Warrior, Hunter, Rogue, Mage, Warlock, Priest, Shaman, Druid). Fixed unguarded registrations (crash on nil registry), missing state arguments in AoE gating calls, duplicate strategies, dead code, and nil field references.
- **All 40 vanilla spec files migrated to safe_state**: Every Classic Era (Vanilla) spec file now uses `spec_kit.safe_state()` for structural nil-guard enforcement, making the Pattern 14 nil-guard bug structurally impossible across the entire codebase.
- **WotLK DSL adoption 100% complete**: All 41 WotLK spec files now use the declarative strategy DSL (was previously reported as 19/41 — actually already 100%).
- Version **2.18.0**.
- All tests passing: 398 rotation + 31 leveling suites (429 total).

### Developer Notes
- **9-class audit**: Comprehensive audit of all 9 class directories checking for `luac -p` compilation, banned APIs, `broken_api_throttled` remnants, unguarded `menu:get()`, unguarded `NS.rotation_registry:register()`, missing `state` args in `aoe_target_meets()`, duplicate strategies/assignments, dead code, and `safe_state` adoption.
- **Bug severity**: 7 Medium (crashes on nil registry, nil field access, broken AoE gating, cache-hit nil-guard bypass), ~25 Low (unguarded registrations, dead code, duplicate strategies/assignments, missing imports).
- **safe_state migration**: Each of the 40 vanilla files received a `SCHEMA` table with Pattern 14 nil-guard defaults and `spec_kit.safe_state(state, SCHEMA)` wrapping on all `build_state` return paths.
- **Warrior cache-hit fix**: `arms_sylvanas.lua` — `safe_state` was not applied on the `build_state` cache-hit early-return path, causing nil-guard bypass on cache hits. Fixed by wrapping the cache-hit return.
- **Hunter fixes**: `leveling_vanilla.lua` — malformed strategy table nesting (strategies were nested inside another table). `leveling_wotlk.lua` — missing `state` argument in strategy match function. `beast_mastery_vanilla.lua` — broken pcall registration pattern that crashes if `NS.rotation_registry` is nil.
- **Rogue fixes**: `assassination_sylvanas.lua` — `blind_ready` field referenced in match function but never populated in `build_state` (nil access). Dead code removed across multiple files.
- **Mage fix**: `frost_vanilla.lua` — duplicate Frostbolt strategy entry (dead code).
- **Warlock fix**: `leveling_wotlk.lua` — missing `state` arg in `SeedOfCorruption` `aoe_target_meets()` call (AoE gating broken).
- **Priest fix**: `leveling_vanilla.lua` — duplicate strategy entries.
- **Shaman fix**: `leveling_vanilla.lua` — duplicate `tremor_totem_ready` state field assignment.
- **Druid fix**: `balance_sylvanas.lua` — missing `state` (s) arg in 2 `aoe_target_meets()` calls (`PreHurricaneBarkskin` + `HurricaneAoE`). `balance_vanilla.lua` — missing `spec_kit` require (using `spec_kit.setting_bool` without importing).
- **Paladin cleanup**: Removed dead `post_swing_judge_gate` function and unused `prot_post_swing_judge` schema setting.
- **Planning notes cleanup**: Archived 26 completed notes, removed 10 duplicate plan files.
- **WotLK DSL adoption**: Verified all 41 WotLK files have `DSL_DEFS` tables + `dsl.compile_strategy` substitution. 43/43 WotLK test suites pass. Plan marked COMPLETE and archived.
- **Documentation**: Agent instruction file updated (Pattern 14 + Pattern 16 migration status), README.md updated (migration state table + badges + version).
- **.gitignore cleanup**: Binary directories (`common`, `core_lua`) and temp files excluded from git tracking.

## 2.17.0 — 2026-07-26

### Customer Changelog
- **Schema settings sync fix**: All class settings (checkboxes, sliders, dropdowns) now properly sync to the rotation engine. Previously, settings like Auto Prowl, Auto Taunt, and Curse Mode were purely cosmetic — toggling them did nothing. Toggling Auto Prowl OOC off now correctly disables auto-prowl.
- **Warlock (Destruction)**: Auto curse mode now picks Curse of Doom for long fights (≥60s TTD) and Curse of Agony for short fights (<60s), instead of always defaulting to Doom.
- **Warlock (Destruction)**: New **Immolate toggle** checkbox — disable for speed-kill guilds that skip Immolate for pure Shadow Bolt spam.
- **Warlock (Destruction)**: **Life Tap while moving** — replaces Searing Pain as the movement filler. When moving and mana isn't full, the rotation taps for mana instead of casting Searing Pain. Safety-gated on HP so you don't kill yourself.
- **Warlock (Destruction)**: **Configurable Life Tap thresholds** — mana threshold slider (default 20%) and HP safety gate slider (default 50%) replace the old hardcoded 35%/40% values.
- Version **2.17.0**.
- Clean `eaxrotations.zip` (lua + md only).
- All tests passing: 391 rotation + 31 leveling suites.

### Developer Notes
- `main.lua` — `create_schema_widget` dropdown sync: replaced `or`-chained lookups (`vals[i] or vals[i+1]`) with `resolve_index`/`resolve_label` helpers using explicit nil-checks (`if v ~= nil then return v end`). Fixes Lua truthiness bug where option values of `0` or `false` would silently fall through `or` to the wrong index. No current schema uses value=0/false but priest `shadow_multidot_mode` uses numeric values 1,2,3.
- `main.lua` — schema widget sync loop now writes settings directly to the settings table (`st[key] = value`) instead of only syncing hardcoded quick-toggle keybinds + playstyle. This is the fix that made Auto Prowl, Auto Taunt, Curse Mode, and all other class settings actually work.
- `classes/warlock/destruction_sylvanas.lua` — `select_curse()` auto mode: Doom for TTD ≥ 60s, Agony for TTD < 60s.
- `classes/warlock/destruction_sylvanas.lua` — Immolate DSL: added `destro_use_immolate` checkbox gate as first condition.
- `classes/warlock/destruction_sylvanas.lua` — LifeTap DSL: configurable `destro_life_tap_mana` (default 20%) / `destro_life_tap_min_hp` (default 50%) via `spec_kit.setting_number`. Added `LifeTapMoving` strategy to ACTIONS table (positioned before SearingPain) so DSL substitution picks it up.
- `classes/warlock/schema_sylvanas.lua` — 3 new Destruction tab settings: `destro_use_immolate`, `destro_life_tap_mana`, `destro_life_tap_min_hp`.
- `tests/test_schema_widget_sync.lua` — new regression guard: 6 parts (static scan, functional mock, setting_bool consumer, nil-sync guard, set_setting spam guard, dropdown edge-case audit with 8 cases covering 1-based/0-based indices, value=0/false truthiness, out-of-bounds, label resolution).
- `tests/test_destruction_dsl_priority.lua` — updated LifeTap test values to match new defaults (mana 15% instead of 30%); added coverage for Immolate toggle, curse TTD switch, configurable LifeTap threshold, and LifeTapMoving strategy.
- `shared/declarative_menu_sylvanas.lua` — declarative `_G.menu` builder (feature-flagged behind `eax_use_declarative_menu`, default false). Infrastructure for future menu migration.

## 2.16.1 — 2026-07-25

### Developer Notes
- Internal fix: schema widget sync hardening (precursor to the v2.17.0 full sync fix).

## 2.11.0 — 2026-07-22

### Customer Changelog
- **100% strategy DSL coverage** — all 29 specs now use the declarative strategy DSL.
- Final 3 adopters: Caster Druid (6 strategies), Smite Priest (17 strategies), Kebab Warrior (16 strategies).
- Pre-commit badge-drift check — prevents stale test-count badges from reaching commits.
- 373 rotation + 21 leveling = 394 total test suites, all green.
- Version **2.11.0**.

### Developer Notes
- `shared/strategy_dsl_sylvanas.lua` — declarative strategy compiler used by all 29 specs.
- `shared/lazy_context_sylvanas.lua` — per-tick dependency-aware context proxy.
- Pre-commit hook step [4/4] runs `lua tools/update_badges.lua --check`.
- Badge drift caught at commit time, matching CI's `run_all_checks.sh` step [4/4].
- All spec-to-spec variations validated: rage, energy/combo, mana (caster/tank/healer),
  focus/pet, shadow DoT, frost/arcane/fire proc, melee/totem, warlock curse/execute,
  bear tank, feral cat powershift across all 10 classes.
- 373 rotation suites + 21 leveling suites = 394 total, all green.

## 2.10.0 - 2026-07-16

### Customer Changelog
- TBC Phase 2: **all 9 classes** 1–70 spell-ladder + solo/group/dungeon/raid(70) matches tests.
- Cat: Mangle debuff soft-gated until talent learned.
- Version **2.10.0**.

### Developer Notes
- `tbc_ladder_helper.lua` + `test_tbc_spell_ladders.lua` (**281** cases)
- Matrix: `tbc-deep-audit-matrix-2026-07-16.md`
- Prior TBC gap-matrix “aligned” is **not** re-claimed as Phase-2 done

## 2.9.2 - 2026-07-16

### Customer Changelog
- Fury: group-safe Sunder/Demo settings; Affliction: assigned curse / curse mode.

### Developer Notes
- Ladder suite **236** cases; per-class settings + curse/seal/shout overwrite + paladin raid prio
- Version **2.9.2**

## 2.9.1 - 2026-07-16

### Developer Notes
- Phase 2 skeptic: hard AoE/settings/raid-prio tests; full S/G/D/R matrix
- 190 ladder cases green

## 2.9.0 - 2026-07-16

### Customer Changelog
- Phase 2: **all 9 classes** Classic 1–60 spell-ladder tests (fillers when high talents unlearned).
- Version **2.9.0**. Tests: 279 rotation + 18 leveling.

### Developer Notes
- `vanilla_ladder_helper.lua` + `test_vanilla_spell_ladders.lua` (175 cases)
- Deep matrix updated with per-class evidence
- `cat_vanilla` CP threshold default level 60

## 2.8.0 - 2026-07-16

### Customer Changelog
- Deep Classic audit: all **40** Vanilla combat + leveling modules load-tested.
- Classic level defaults fixed (no accidental TBC “level 70” assumptions).
- Hunter Classic pre-Aimed fillers when Aimed unavailable.
- Version **2.8.0**. Tests: 278 rotation + 18 leveling.

### Developer Notes
- Matrix: `vanilla-deep-audit-matrix-2026-07-16.md`
- `test_vanilla_content_coverage.lua` + `vanilla_level_from_context`
- Hunter MM/Survival pre-Aimed ladder; druid/rogue level default 60

## 2.7.9 - 2026-07-16

### Customer Changelog
- **All 31 Classic Vanilla combat specs re-verified**.
- **Hunter BM/Survival (Classic)**: Aimed Shot is now the primary cast (wowsims classic hunter APL).
- **Destruction (Classic)**: Soul Fire no longer spams with any soul shard; execute-gated like Shadowburn.
- Version bumped to 2.7.9.
- Tests: 277 rotation + 18 leveling suites green.

### Developer Notes
- Gap matrix: `vanilla-rotation-gap-matrix-2026-07-16.md`
- `beast_mastery_vanilla.lua` / `survival_vanilla.lua`: AimedShot strategy + matches
- `destruction_vanilla.lua`: `soul_fire_matches` execute gate; Shadowburn before SoulFire
- Tests: `test_hunter_vanilla_aimed_shot.lua`, `test_destruction_vanilla_soul_fire_execute.lua`

## 2.7.8 - 2026-07-16

### Customer Changelog
- **All 29 TBC specs re-verified** against wowsims APLs, SimC/wowapls patterns, Wowhead, Icy Veins, and Warcraft Tavern.
- **Warlock (Destruction)**: Shadowburn now correctly fires in execute (≤20% HP) instead of being blocked by Shadow Bolt / Incinerate filler while standing still. Matches wowsims destro_fire APL execute priority.
- **Druid (Feral)**: Low-level cats (level 42-49) can now use Shred, Rip, Ravage, and Ferocious Bite without being blocked by the Mangle (Cat) debuff requirement that only applies once Mangle is learned at level 50.
- **Druid (Feral)**: Rip now tracks all rank IDs correctly, so low-level Rip casts no longer silently fail.
- **Druid (Bear)**: Maul rage threshold scales down when Mangle (Bear) is not yet learned, so low-level bears spend rage earlier.
- **Druid (Bear)**: Swipe cleave works before Lacerate is available.
- **Druid (Bear)**: Demoralizing Roar no longer wastes a GCD on a single target that is about to die.
- Version bumped to 2.7.8.
- Clean `eaxrotations.zip` (lua + md only).
- Tests: 274 rotation + 18 leveling suites green.

### Developer Notes
- Gap matrix: `tbc-rotation-gap-matrix-2026-07-16.md` — per-spec logic/settings verdict for all 29 combat specs; tie-breakers documented (wowsims APL > contested guide opinion).
- `destruction_sylvanas.lua`: reorder ACTIONS so `Shadowburn` sits above `Incinerate` / `ShadowBolt` / `SoulFire` (was dead while stationary because fillers always matched first).
- `test_destruction_shadowburn.lua`: asserts strategy index order (Shadowburn < Incinerate and < ShadowBolt) in addition to execute HP / soul-shard match gates.
- `cat_sylvanas.lua`: `shred_matches` and `stealth_shred_matches` now gate the Mangle-debuff requirement on `spell_exists(ACTION.MangleCat)`; `RIP_DEBUFF` expanded to `{ 27008, 9896, 9894, 9752, 9493, 9492, 1079 }`.
- `leveling_sylvanas.lua`: `shred_matches` gates Mangle-debuff requirement on `mangle_cat_ready`; `RIP_DEBUFF` and `RAKE_DEBUFF` expanded with missing ranks.
- `bear_sylvanas.lua`: pre-Mangle Maul uses level-scaled threshold; Swipe cleave Lacerate-stack gate only when `spell_exists(ACTION.Lacerate)`; Demo Roar skips single-target on `target_hp <= 20` or `ttd < 10`; `state.level` populated from context.
- Added regression tests: `test_druid_feral_level_42.lua`, `test_druid_feral_l42_mangle_gate.lua`.
- Updated `test_leveling_druid.lua` FerociousBite mock IDs.
- Material gaps found this pass: **1** (Destruction Shadowburn). All other specs **aligned** or **source-disagreement** with documented tie-break.

## 2.7.7 - 2026-07-16

### Customer Changelog
- **Druid (Bear)**: Maul no longer re-queues every frame once armed for the next swing.
- **Melee timing**: Swing timer uses the correct clock (no more ~70k-second garbage values / debug spam).
- Version bumped to 2.7.7.
- Clean `eaxrotations.zip` (lua + md only).

### Developer Notes
- Maul: `is_current_spell` gate + `min_interval=0.5` execute.
- `swing_time_until`: `NS.time_now()` / game-time; stop using `get_current_combat_core_time`.

## 2.7.6 - 2026-07-16

### Customer Changelog
- **Druid (Bear)**: Swipe targets enemies again (was self-targeting the player and spam-looping).
- **Druid (Bear)**: Mark / Gift / Thorns no longer cast in bear form (they cancel form and caused shift loops).
- **Druid (Bear)**: Cleaner Bear Form re-shift after a cast attempt.
- **Melee timing**: Absurd swing-timer fallback values are ignored.
- Version bumped to 2.7.6.
- Clean `eaxrotations.zip` (lua + md only).

### Developer Notes
- Swipe: remove `target="self"` / `requires_target=false`; cast via `context.target`.
- OOC buffs: `if s.is_bear then return false end` on MotW/Gift/Thorns.
- `NS.swing_time_until`: clamp `remains > 12` → 999 (unknown).
- Regression tests in `test_bear_custom_matches.lua`.

## 2.7.5 - 2026-07-16

### Customer Changelog
- **Druid (Bear)**: Low-level bears spend rage much earlier. Before Mangle, Maul no longer waits for ~50 rage — the threshold scales with level (about 23 rage around level 17). Your Maul Rage menu setting remains the maximum once you have the full tank kit.
- **Druid (Bear)**: Swipe works on 2+ targets before Lacerate is available (no more waiting on stacks you cannot apply yet).
- **Druid (Bear)**: Demoralizing Roar no longer wastes GCD/rage on a single mob that is about to die. Multi-pull Demo is unchanged.
- Version bumped to 2.7.5.
- Clean `eaxrotations.zip` (lua + md only).

### Developer Notes
- `bear_sylvanas.lua`: pre-Mangle Maul uses `min(menu maul_rage, level_scaled)`; Swipe cleave applies Lacerate-stack gate only when `spell_exists(Lacerate)`; Demo Roar single-target skip on `target_hp <= 20` or `ttd < 10`; `state.level` from context.
- `schema_sylvanas.lua`: `bear_maul_rage` tooltip documents pre-Mangle auto-scale.
- `test_bear_custom_matches.lua`: pre-Mangle Maul, pre-Lacerate Swipe, Demo HP/TTD multi vs single.

## 2.7.4 - 2026-07-16

### Customer Changelog
- **Healers**: Smart stop-cast is now active at runtime (cancels heals that would overheal once the target recovers mid-cast).
- **Healers / pets**: Injured party pets can enter triage scoring when pet healing is enabled.
- **Tanks (Prot Warrior / Prot Paladin)**: Snap-threat openers fire on combat start again (Shield Slam / Judgement paths).
- **Prot Warrior**: Stance manager is live (auto Battle / Defensive / Berserker when settings allow).
- **Arms / Fury Warrior**: Shared rage-dump manager drives Heroic Strike / Cleave starvation and dump-mode decisions.
- **Melee / Hunters**: CLEU swing diagnostics and swing-timer tracking load at startup (seal registration, hunter adaptive timing).
- **Warlock**: Shared dispel manager is available for friendly Devour Magic group help.
- Version bumped to 2.7.4.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (272 rotation suites; 1 pre-existing layout registration failure unrelated).

### Developer Notes
- Bootstrap-load supremacy modules in `main.lua` `load_modules` **before** class load so `NS.StopCast`, `NS.PetHeal`, `NS.SnapThreat`, `NS.StanceManager`, `NS.SwingDiagnostics`, `NS.SwingTimer`, `NS.DispelManager`, `NS.RageManager`, and `NS.MeleeCombatMath` are populated when specs evaluate.
- `main_sylvanas.lua`: load `shared/health_pred_helper_sylvanas` after `NS.health_prediction`; tick `NS.SwingTimer.on_update` each rotation update.
- `health_pred_helper`: lazy-resolve platform module; expose `NS.incoming_damage` / `NS.predicted_hp_pct` / `NS.is_tank_role`.
- Arms/Fury: prefer `NS.RageManager.should_heroic_strike` / `should_cleave` with threshold overlay preserving existing dump defaults.
- Plan: `wire-dormant-shared-modules-2026-07-16`.

## 2.7.3 - 2026-07-13

### Customer Changelog
- **Warlock (Affliction)**: When low on health, Drain Life is now forced over Drain Soul for self-healing sustain.
- **Warlock (Affliction)**: Rain of Fire AoE added for large packs in dungeons (uses enemy count threshold, works pre-level 70 before Seed of Corruption). Proper position targeting for ground AoE.
- Curse of Agony now reliably applies without Curse of Elements overriding.
- Version bumped to 2.7.3.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (260 rotation + 17 leveling suites).

## 2.7.2 - 2026-07-12

### Customer Changelog
- **Warlock**: Fixed Curse Governance for the last time — setting "Curse Mode" to Agony and/or "Assigned Curse" to Agony now reliably prevents Curse of Elements (11722) and other non-Agony curses. All three specs (affliction/demonology/destruction) now use strict early `assigned_curse_blocks` + `select_curse` delegation.
- **Warlock**: Drain Soul hardened to pure TBC shard-capture behavior (only when `context.ttd <= 5s`); removed non-TBC "hp <=5 execute" path and all custom per-spell interval timers.
- **Warlock**: Removed all added workarounds (no new `dot_recently_cast`, no extra `_last_*` throttles for dots/drains). Code now relies exactly on the documented API surface: `NS.debuff_remains` (via `get_debuff_data`), `context.is_channeling` (from `is_channelling_spell`), `context.ttd` / `context.target_hp_pct`, `NS.GetPet()` / `has_pet()`, `NS.try_cast`, `spec_kit.setting`, etc. Matches `.api` + apidocs expectations with zero layering.
- **Warlock**: OOC Summon Imp spam eliminated — `ooc_manager_sylvanas.lua` no longer hardcodes Imp for Warlock. Pet choice fully delegated to spec OOC strategies (correctly picks Felhunter etc. when appropriate and respects current pet state).
- **Warlock**: Repeated same-target Corruption/UA/Immolate/Siphon/Curse casts fixed by trusting the API remains checks + existing throttle paths.
- Version bumped to 2.7.2.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (260 rotation + 17 leveling suites).

## 2.7.1 - 2026-07-12

### Customer Changelog
- **Druid (Bear)**: Fixed erroneous out-of-form shift to use a Healthstone / Healing Potion even when those consumables are disabled in settings. Consumables are now handled Druid-class-wide via middleware, not per-spec.
- **Druid (Bear)**: Fixed missing bear-form re-shift — if the rotation is ever shifted out of Bear Form (e.g. Enrage on cooldown), it now immediately returns to Bear Form (3s throttle to avoid thrash).
- **Druid (Bear)**: Fixed chain-pulling — Faerie Fire (pull) is now gated to out-of-combat only; it no longer auto-pulls the next nearest mob in range while already fighting.
- **Druid (Bear)**: Fixed Demo Roar range / immunity handling — Demo Roar now only applies within 10yd and tracks per-target cast failures (immune) with an 8s throttle, instead of spamming at invalid or immune targets.
- Version bumped to 2.7.1.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (257 + 17 suites).

## 2.7.0 - 2026-07-12

### Customer Changelog
- **Warlock**: Removed `Curse of Shadow` as a separate rotation option (spell definition retained for safety).
- **Warlock**: Added `Curse of Recklessness` and `Curse of Weakness` curse modes across Affliction, Demonology, and Destruction.
- **Warlock**: Added `Assigned Curse` setting for manual raid coordination.
- **Warlock**: Unified curse refresh thresholds across all three Warlock specs via `shared/warlock_curse_helper_sylvanas.lua`.
- **Warlock**: Fixed Demonology `other_curse_active()` to use state fields instead of the missing `s.target`.
- **Warlock**: Aligned auto-mode curse logic with TBC APL/pro guides:
  - Affliction: `Curse of the Elements` in raid/group.
  - Demonology/Destruction: `Curse of Doom` default, `Curse of the Elements` if assigned/needed.
- Version bumped to 2.7.0.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (257 + 17 suites).

## 2.6.1 - 2026-07-12

### Customer Changelog
- **Warlock**: Fixed curse selection so `Curse of Elements`/`Curse of Shadow` no longer override `Curse of Agony` in auto mode.
- **Warlock**: Added `other_curse_active()` guard across Affliction, Demonology, and Destruction to prevent curse overwrites.
- **Warlock**: Added `LIFE_TAP_MIN_INTERVAL = 1.5s` throttle to Affliction, Demonology, and Destruction to stop Life Tap double-cast/spam.
- Version bumped to 2.6.1.
- Clean `eaxrotations.zip` (lua + md only).
- All tests remain passing (257 + 17 suites).

## 2.6.0 - 2026-07-11

### Customer Changelog
- FSR (Five-Second Rule) support across all healers: correct pause placement after emergencies before fillers (Greater Heal, Chain Heal, SmartHeal, Regrowth, etc.).
- New shared FSR manager with configurable thresholds via menu (enabled, mana threshold, emergency HP, max pause seconds).
- State wiring (in_combat, lowest HP, fsr inside/delta) + simplified delegates in rotations.
- Version bumped to 2.6.0.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (253 + 17 suites).

## 2.5.19 - 2026-07-11

### Customer Changelog
- **Warlock**: Fixed repeated CreateHealthstone spam (11730 and ranks) while in combat or with target selected. Added proper "already have healthstone" ownership checks (with core.inventory fallback) in middleware, destruction, vanilla, and leveling rotations.
- **Warlock**: OOC pet summons (Summon Imp etc.) now strictly respect `has_valid_enemy_target` (prevents casting pet summon on your DPS target). Added extra pet detection fallbacks.
- Reduced noisy "[OOC] Summon Imp throttled (broken API)" log spam (rate limited + clarified message).
- Version bumped to 2.5.19.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (253 suites).

## 2.5.18 - 2026-07-11

### Customer Changelog
- Active Fight Tracker: mobs that you or your group enter combat with are tracked as "active fights".
- DoT maintenance on those fights (if in range + mana + not already dotted by someone else).
- Wired for Shadow, Affliction, Balance (Moonfire+IS), Elemental (Flame Shock), Hunter Serpent Sting (TBC + Vanilla).
- Version bumped to 2.5.18.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (252 + 17 suites).

## 2.5.17 - 2026-07-11

### Customer Changelog
- Fixed jitter / snapping back when clicking Playstyle in Quick Toggles (and cases where selection didn't stick smoothly).
- Widget is now the only source of truth; removed fighting back-sync logic that used stale settings cache; added cache refresh on injection.
- Changes are now smooth and reliable across all classes/specs.
- Version bumped to 2.5.17.
- Clean eaxrotations.zip (lua + md only).
- All tests remain passing (253 + 17 suites).

## 2.5.16 - 2026-07-11

### Customer Changelog
- Fixed Playstyle selector inside Quick Toggles. Selecting a playstyle (e.g. Affliction, Destruction, Cat, Arms, etc.) now actually switches the active rotation.
- Was previously stuck on the initial value (such as "Auto (Talent)" for Warlock). Now works for all classes and all 29 specs.
- Version bumped to 2.5.16.
- Clean eaxrotations.zip (lua + md files only).
- All tests remain passing (252 + 17 suites).

## 2.5.15 - 2026-07-11

### Customer Changelog
- Control panel quick toggles (Rotation, Healing, Damage, Cooldowns, AoE, Interrupts, Utility, Threat Drops) now always visible with fallback to "Unbound" (no keybind needed). Changed from 7 (hidden) to 999 (visible per docs).
- Removed set_setting writes during sync to fix host "File name not set" spam on reload; widget states injected directly into settings for correct gating.
- Verified toggles work as intended with recent IO removal and other changes (states used in gating logic).
- Version bumped to 2.5.15.
- All tests remain passing (252 + 17 suites).

## 2.5.14 - 2026-07-10

### Customer Changelog
- Removed manual log and data file IO saving (create_log_file, write_log_file, early set_setting calls, grace periods) that caused "File name not set. Please specify a valid file name before saving" spam from the host.
- Logging now prefers izi.log (recommended in Sylvanas docs) instead of manual file management.
- All rotation and leveling tests remain passing (252 + 17 suites).
- Version bumped to 2.5.14.

## 2.5.13 - 2026-07-10

### Customer Changelog
- Removed manual log and data file IO saving (create_log_file, write_log_file, early set_setting calls, grace periods) that caused "File name not set. Please specify a valid file name before saving" spam from the host.
- Logging now prefers izi.log (recommended in Sylvanas docs) instead of manual file management.
- All rotation and leveling tests remain passing (252 + 17 suites).
- Version bumped to 2.5.13.

## 2.5.12 - 2026-07-10

### Customer Changelog
- Priest Healing + shared dispel manager: added BT/SWP high-tier debuffs (Soul Drain 41303, Polymorph 46280, Flame Buffet 46279, Disease Buffet, hound poisons) for improved raid dispel priority and clears.
- All rotation and leveling tests remain passing (252 + 17 suites).
- Version bumped to 2.5.12 across header, docs, and packaging.

## 2.5.11 - 2026-07-10

### Customer Changelog
- Destruction Warlock: Conflagrate now prioritizes above Incinerate after Immolate application (consume for burst damage, then filler). Matches standard TBC destruction priorities from simulator APLs and guides.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.9 - 2026-07-10

### Customer Changelog
- Continued fidelity improvements for remaining specs per sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.8 - 2026-07-10

### Customer Changelog
- Elemental Shaman: main totems now higher priority to match simulator APL.
- Frost Mage: audited for fidelity; strong Frostbolt spam with burst CDs and shatter Ice Lance per guides.
- Enhancement Shaman: audited; strong Stormstrike, totem twisting, shock priority per APL.
- Combat Rogue: switched primary finisher to Envenom with deadly poison per sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.10 - 2026-07-10

### Customer Changelog
- Continued Tier 3 fidelity for Frost, Enhancement, Combat Rogue per sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.7 - 2026-07-10

### Customer Changelog
- Tier 2 Resto specs (Druid, Shaman, Priest) fidelity pass complete with downrank and audit updates per guides.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.6 - 2026-07-10

### Customer Changelog
- Resto Druid: added downrank Regrowth support for mana conservation in spot healing, per TBC guides.
- Resto Shaman: added downrank Chain Heal for mana sustainability in group healing, per TBC guides.
- Resto Priest: audited; strong Renew/PW:S/Greater Heal/CoH with downrank support per guides.
- Elemental Shaman: raised priority of main totems (Totem of Wrath, Wrath of Air, Mana Spring) to match wowsims APL.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.5 - 2026-07-10

### Customer Changelog
- Holy Paladin: added proactive Light's Grace build using downranked Holy Light to proc the cast-time reduction cheaply before heavy healing (per TBC guides).
- Resto Druid: added downrank Regrowth support for mana conservation in spot healing, per TBC guides.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.4 - 2026-07-10

### Customer Changelog
- Continued fidelity improvements across tank and caster specs per simulator and guide sources.
- All rotation and leveling tests remain passing (252 suites).

## 2.5.3 - 2026-07-10

### Customer Changelog
- Retribution Paladin: seal twisting now enabled by default, following the Command rank 1 into Blood or Martyr twist before swings for Crusader Strike and Judgement to match priority lists from simulators and guides.
- Hunter: improved auto-shot timing with dynamic buffer calculations (adapts to weapon swing speed) for safer Steady/Multi/Arcane weaving without clipping autos.
- Warrior Protection: added multi-target Whirlwind support and raised Shield Block priority to better match simulator APLs for threat and mitigation.
- Balance Druid: documentation updated for accurate TBC priorities (Moonfire/Insect Swarm dots, Faerie Fire, Starfire filler, Starfall, treants); no incorrect references.
- Protection Paladin: audited for fidelity; priorities align with guides and simulator for Holy Shield, Consecration, Judgement, and defensives.
- Holy Paladin: added proactive Light's Grace build using downranked Holy Light to proc the cast-time reduction cheaply before heavy healing (per TBC guides).
- All rotation and leveling tests remain passing (252 suites).

## 2.5.2 - 2026-07-10

### Customer Changelog
- Improved Arms Warrior Sunder Armor priority and battle stance support, aligned with authoritative SimC APLs and guides from Wowhead and Icy Veins for better raid contribution.
- Improved Feral Cat (Druid) with proper Berserk usage during burst windows (pull/BL), aligning with SimC/wowsims/icyveins for higher DPS in CDs.
- Improved Retribution Paladin seal twisting behavior: now enabled by default to follow Command rank 1 to Blood/Martyr twist for Crusader Strike and Judgement, matching simulator and guide priorities.
- Updated version to 2.5.2 with customer-facing documentation and text cleanup (plain formatting, no special symbols).
- All rotation and leveling tests remain passing.

Full development details and prior releases below (for internal use).

Full development details and prior releases below (for internal use).

## 2.3.15 - 2026-07-05

### Comprehensive Competitor Ecosystem Analysis

Researched 30+ providers across the entire WoW automation ecosystem. Key findings:

#### TBC Healer Competitors Found

| Provider | Type | TBC Healer Support | EAX vs Them |
|----------|------|--------------------|-------------|
| **BlistX (blistrogue.com)** | Lua framework | ✅ Holy Priest, Disc Priest PvP, Resto Shaman, Holy Pally, Resto Druid PvP | 80K lines, 17 rotations, PvP situation fields, BuddyMode. Direct competitor. |
| **MaxDPS Assistant (maxdps.pro)** | Pixel/Memory | ❌ TBC Priest = Shadow only (no healer) | EAX far ahead |
| **WRobot Fight Class** | Private server internal | ✅ Disc Priest PvP (6.50 EUR) | Dynamic rotation, SW:Death polymorph, frame lock. EAX matches spell usage. |
| **Tempest (wowtempest.gg)** | Pixel bot | ✅ All specs including healers | $49-499, SimC APL, pixel-based. Cannot scrape logic. |
| **Rice Rotations** | Pixel bot | ✅ All specs (Midnight + MoP) | Pixel-based, PvE only, no PvP. Does not list TBC Anniversary. |
| **PixelRotation** | Pixel bot | ❌ Midnight + MoP only | Not applicable to TBC |
| **OptiStrike** | Pixel bot | ⚠️ All versions, uses Hekili/HeroRotation | Pixel wrapper around Hekili — no own healer logic |
| **Morpheus** | Custom bot | ✅ Any expansion, any class | Custom 1-to-1 development. Cannot scrape. |
| **Sonah** | CurseForge addon | ✅ All 27 specs TBC | EAX exceeds — stop-cast, absorb tracking, chain heal targeting |
| **HealPredict TBC** | CurseForge addon | ✅ UI-only heal prediction | EAX matches core logic; HealPredict is visualization only |
| **HealIQ** | GitHub addon | ✅ Resto Druid only | EAX adopted Swiftmend expire-preference + tick-cadence |
| **ConROC** | CurseForge addon | ❌ Explicitly no healer rotation | EAX has full healer support |
| **Hekili** | GitHub addon | ❌ Healer = DPS only | EAX far ahead |
| **MaxDps (kaminaris)** | GitHub addon | ❌ TBC Resto Shaman = DPS only | EAX far ahead |
| **PrismmRot** | GitHub addon | ❌ JSON-driven DPS queue | No healer logic |
| **HekiliHealers** | CurseForge addon | ⚠️ Retail only | Not applicable to TBC |

#### Lua Unlocker / Rotation Framework Ecosystem (no public healer logic)

| Provider | Type | Notes |
|----------|------|-------|
| NilName | Lua Unlocker + Rotations | 403 blocked, closed source |
| WGG | Lua Unlocker | — |
| Lunar | Mac Lua Unlocker + Framework | — |
| Daemonic | Lua Unlocker | — |
| Project Sylvanas | Internal Framework | **EAX's platform** |
| SIN/WS/GDR/TJX/Funlua/TCXCore | Chinese Lua Unlockers | Closed source |
| Clipper | PvP Rotations | Retail-focused |
| Ascended/Phoenix/SYNQ/Opal/Dominus/Makulu/Magic | Combat Rotations | GGLoader-based, closed source |
| EpicSync | Custom Hekili Rotations | Hekili wrapper |
| GGLoader/Inferno | Combat Pixel Bots | Closed source |
| Rotation Lab/Byster/Univer | Private Server Rotations | Memory-based, closed source |
| SquireBot/Warden Grider/Bottie/PixelWoWBot/Wrobot | Farming/Multi-use | Not healer rotation relevant |

#### Key Insights

1. **BlistX is the most direct competitor** — 80K lines, 17 rotations, TBC healer support including Holy Priest "Smart 5-man healing, triage scoring", Disc Priest PvP, Resto Shaman, Holy Pally, Resto Druid PvP. Has "PvP Situation Fields" and "BuddyMode" (follow/assist/healer peel). However, BlistX is closed-source and Lua-based — EAX is also Lua-based and on Project Sylvanas (internal framework, more capable than pixel bots).

2. **No competitor has stop-cast engine** — EAX's mid-cast cancellation at 25/50/75% progress is unique across all 30+ providers researched.

3. **No competitor has PW:S absorb-aware refresh** — EAX's `buff_points()` >200 skip is unique.

4. **No competitor has Chain Heal cluster targeting** — EAX's O(n²) 12.5yd radius finder is unique.

5. **Pixel bots (Tempest, Rice, OptiStrike, PixelRotation)** cannot access internal game state — they read screen pixels. EAX runs inside the game via Project Sylvanas, giving full access to unit health, buffs, threat, cast info, combat log, etc. This is a fundamental architectural advantage.

6. **MaxDPS Assistant** has TBC Priest but only Shadow — no healer rotation. EAX has Holy + Disc + Shadow.

7. **WRobot Disc Priest PvP profile** (6.50 EUR, 2.4.3) uses: Fear, Dispel, PvP Trinket, Shadowfiend, Pain Suppression, Mass Dispel, SW:Death polymorph interrupt. EAX's Disc Priest has all of these except SW:Death polymorph interrupt and Mass Dispel.

8. **BlistX BuddyMode** (follow, assist, healer peel awareness) is a feature EAX doesn't have — but it's a leveling/follow bot feature, not a rotation quality feature.

### Features to Consider from Competitors

| Feature | Source | Priority | Status |
|---------|--------|----------|--------|
| SW:Death polymorph interrupt | WRobot Disc Priest | Medium | Not in EAX |
| Mass Dispel (PvP) | WRobot Disc Priest | Low | Not in EAX |
| BuddyMode (follow/assist) | BlistX | Low | Out of scope for rotation engine |
| PvP Situation Fields | BlistX | Medium | EAX has PvP via context.is_pvp + spec-specific logic |
| 80K lines scale | BlistX | — | EAX is ~50K+ lines across 29 specs + shared modules |

### Quality & Reliability
- 219 rotation test suites — all healer tests passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible.

## 2.3.14 - 2026-07-05

### Healer Deep-Dive: External Research + Tick-Cadence HoT Refresh

#### Resto Druid: Tick-Cadence-Aware HoT Refresh (from tbc-rdruid-simulator)
- `needs_lifebloom_refresh()`: now checks `HotTickTracker.next_tick_in()` — if next Lifebloom tick is within 0.5s, waits for it to land before refreshing. Prevents tick clipping.
- `needs_rejuvenation()` and `needs_regrowth()`: same tick-cadence check.
- `choose_swiftmend_prefer_rejuv()`: now prefers HoTs about to expire (<2.0s remaining) — consumes before clipping (from HealIQ approach).
- All changes nil-guarded: HotTickTracker is optional, falls back to fixed threshold.

#### External Research: Competitor Analysis
- **HealPredict TBC Anniversary** (CurseForge): Has absorb presence indicator bar, death prediction, cluster detection, AoE heal target advisor, health trajectory marker, heal reduction indicator, raid cooldown tracker, overheal statistics. EAX already has most of these via `healer_deficit_sylvanas.lua` + `triage_sylvanas.lua`.
- **Sonah** (CurseForge): Has predictive healing, HoT tracking, dispel recommendations, tank priority. EAX matches or exceeds all of these.
- **HealIQ** (GitHub): Resto Druid-specific — HoT duration tracking, Swiftmend combo, Clearcasting. EAX now wired HotTickTracker for tick-cadence-aware refresh.
- **MaxDps** (GitHub): TBC Restoration Shaman = DPS only, no healing logic. EAX far ahead.
- **ConROC** (CurseForge): Explicitly states "Healers due to the nature of the role will not offer a heal rotation." EAX has full healer support.
- **HekiliHealers** (CurseForge): Retail only, mouseover-based. Not applicable to TBC.
- **Tempest** (wowtempest.gg): Closed-source pixel bot, $49-499. Claims SimC-accurate rotations for all classes including healers. Uses pixel detection, not internal API. Cannot scrape logic.
- **PrismmRot** (GitHub): JSON-driven rotation queue, no healer-specific logic found.
- **tbc-rdruid-simulator** (GitHub): Python simulator for optimal HoT rotations. EAX adopted tick-cadence-aware refresh from this source.
- **archon.gg**: Top Holy Priest parses show CoH 31.5%, Renew 30.1% (73% uptime), Flash Heal 15.5%, PoM 10.4%. EAX priority order matches.

### Quality & Reliability
- 219 rotation test suites — all healer tests passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.13 - 2026-07-05

### Healer Gap Fixes (Deep-Dive Audit)

#### Holy Priest
- **DispelMagic now fires**: `Healing.has_dangerous_dispel()` and `Healing.has_disease()` were referenced but never defined in `priest/healing_sylvanas.lua`. The `DispelMagic`, `CureDisease`, and `AbolishDisease` strategies were dead code — they silently skipped because the gate functions returned nil. Now defined with `NS.has_dispel_type_debuff` fast path + debuff ID scan fallback.
- **ManaPotion strategy added**: Holy Priest was the only healer without a Mana Potion strategy (Pally, Shaman, and Druid all had one). Fires at <20% mana, gated by `use_mana_potions` setting.

#### Discipline Priest
- **Shadowfiend strategy added**: Discipline had the spell but no strategy to cast it (only Holy had one). Fires at <30% mana, gated by `use_shadowfiend` setting. `shadowfiend_ready` added to `build_state`.
- **ManaPotion strategy added**: Same gap as Holy Priest — now has mana potion at <20%.

#### Resto Shaman
- **Solo DPS now fires**: `idle_dps_strategies` (EarthShock, FlameShock, ChainLightning, LightningBolt) were exported but NOT in the `healing_strategies` table passed to `rotation_registry:register`. Solo Shaman did zero DPS. Now merged into the registered rotation.
- **Earth Shock interrupt now fires**: Was in the unregistered `idle_dps_strategies` — target-casting interrupt logic was dead code. Now active.
- **Bloodlust PvP burst window**: `bloodlust_matches` now also fires during PvP burst-heal windows via `NS.PvPBurstWindow.should_burst()`, not just when group is fully healthy.

#### Holy Paladin
- **Avenging Wrath PvP burst window**: `AvengingWrathHeavyHealing` now also fires during PvP burst-heal windows via `NS.PvPBurstWindow.should_burst()`, not just during `heavy_healing` flag.

#### Shared Modules
- **`chain_heal_target()` added to `triage_sylvanas.lua`**: Resto Shaman referenced `NS.AoEHeal.chain_heal_target()` but it was never defined — the call was nil-guarded so it silently fell back to lowest-HP targeting. Now the 12.5yd cluster finder activates, improving Chain Heal bounce optimization.
- **`PetHeal` verified**: `core_sylvanas.lua:4876` already calls `NS.PetHeal.append_entries` — no fix needed.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.9 - 2026-07-03

### Bug Fixes
- **Shadow Priest**: Fixed Mind Flay opening on fresh targets. `mind_flay_matches` was missing the `_engaged_with_player()` safety gate that every other damage spell uses. This caused Mind Flay to fire before Shadow Word: Pain and Mind Blast on targets at 100% HP that hadn't yet targeted the player. Now correctly waits for engagement (via auto-attack or party member pull) before casting.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

## 2.3.8 - 2026-07-03

### Bug Fixes
- **Mage — Fire**: `state.has_clearcasting` now populated in `build_state`; Clearcasting proc is consumed on Fireball.
- **Warrior — Arms**: `state.is_boss` + `target_hp_pct` populated in `ARMS_SCHEMA`/`build_state`; Death Wish boss-burst gate (target >20% HP) now fires.
- **Druid — Bear**: `state.is_rooted`/`is_snared` populated via `safe_method`; Nature's Grasp PvP peel now triggers when CC'd.
- **Warlock — Demonology**: `demo_state.in_combat` populated; Pet state matchers no longer rely on stale reference.

### API Compliance
- **is_boss**: All call sites now prefer `context.target_is_boss` (accurate, via `unit_helper:is_boss()`) and fall back to `NS.unit_is_boss()`, never the raw inaccurate `target:is_boss()`.
- **is_tank**: `core_sylvanas:is_tank_unit` now prefers accurate `NS.unit_is_tank()` (`unit_helper:is_tank()`) before falling back to raw `unit:is_tank()` + role heuristic.

### Healer Dispel Throttle (v2.3.7)
- All 4 healer specs throttle dispels/cleanses to 3-second intervals, preventing rapid-fire casts on stale debuff data.

### Quality & Reliability
- 219 rotation test suites — all passing
- 13 leveling rotation suites — all passing
- All changes are backward compatible. No settings reset required.

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
- Docs: Agent instruction file updated with Patterns 11–13 (buff_points, PW:S absorb tracking, smart Innervate targeting); all stale per-spec library references cleaned up for flat-file architecture.
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

