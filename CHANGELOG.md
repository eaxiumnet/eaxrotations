# Changelog

All notable changes to the EAX TBC Classic Rotations project.

## [2.7.7] — Maul Queue Spam + Swing Timer Clock Fix (2026-07-16)
- **Druid (Bear)**: Maul no longer re-queues every tick. Skip while `is_current_spell` (already armed next-swing) + 0.5s `min_interval` safety.
- **Core**: `NS.swing_time_until` uses `NS.time_now()` / game-time paths instead of `get_current_combat_core_time()` (that clock produced ~70k-second absurd remains in live logs).
- `get_time_until_swing` / OH swing now delegate to the fixed helper.
- Tests: Maul already-queued gate.
- Version bump 2.7.7; clean `eaxrotations.zip` (lua + md only).

## [2.7.6] — Druid Bear Cast Target + Form Stability (2026-07-16)
- **Druid (Bear)**: Swipe no longer targets the player. TBC Swipe needs a hostile melee target; self-cast was rejected and spam-looped via the spell queue (`Swipe | Target <player>`).
- **Druid (Bear)**: Mark of the Wild / Gift / Thorns never cast while in bear form (caster buffs cancel form and caused BearForm ↔ MotW loops).
- **Druid (Bear)**: Bear Form re-shift post-cast lockout so form buff can apply before re-queue.
- **Druid (Bear leveling / vanilla)**: Same Swipe enemy-target fix.
- **Core**: `NS.swing_time_until` clamps absurd auto_attack_helper remains (live ~69598s) to unknown (999) so Maul/HS gates fail open.
- Tests: Swipe enemy-target regression + MotW/Thorns bear-form block.
- Version bump 2.7.6; clean `eaxrotations.zip` (lua + md only).

## [2.7.5] — Druid Bear Low-Level Spenders (2026-07-16)
- **Druid (Bear)**: Pre-Mangle Maul no longer banks to the endgame 50-rage dump. When Mangle is not learned, Maul threshold auto-scales by level (≈23 at L17), never raised above the menu `bear_maul_rage` slider.
- **Druid (Bear)**: Swipe (2-target cleave) no longer requires 3 Lacerate stacks before Lacerate is learned (L66).
- **Druid (Bear)**: Demoralizing Roar skips dying single-target trash (`target_hp <= 20` or `ttd < 10`). Multi-pack Demo still applies. Fixes late-combat Demo when TTD is unknown (defaults fail-open to 999).
- Tests: `test_bear_custom_matches.lua` (pre-Mangle Maul, pre-Lacerate Swipe, Demo HP/TTD).
- Version bump 2.7.5; clean `eaxrotations.zip` (lua + md only).

## [2.7.4] — Dormant Shared Module Bootstrap (2026-07-16)
- **Bootstrap**: supremacy shared modules that already had nil-guarded call sites are now required at plugin load (`stopcast`, `pet_heal`, `snap_threat`, `stance_manager`, `swing_diagnostics`, `swing_timer`, `dispel_manager`, `rage_manager`, `melee_combat_math`).
- **Healers**: `NS.StopCast` active; `health_pred_helper` exposes `NS.incoming_damage` / `NS.predicted_hp_pct` / `NS.is_tank_role`.
- **Tanks**: Snap threat + Prot Warrior stance manager live.
- **Arms/Fury**: RageManager wired into HS/Cleave matches (threshold-preserving overlay).
- **Melee/Hunter**: SwingDiagnostics + SwingTimer load + per-tick update.
- Version bump 2.7.4; clean `eaxrotations.zip` (lua + md only).
- `luac -p` + module unit tests green; rotation suites 272/273 (pre-existing layout compliance).

## [2.7.3] — Warlock Sustain + Pre-70 AoE (2026-07-13)
- **Warlock (Affliction)**: Low health now forces Drain Life (self-heal) over Drain Soul for survival.
- **Warlock (Affliction)**: Added Rain of Fire AoE for big packs (triggers on 3+ enemies, pre-70 where Seed of Corruption unavailable). Uses proper aoe cast position when possible.
- Confirmed Curse of Agony governance working (no more erroneous Curse of Elements).
- Version bump 2.7.3; clean `eaxrotations.zip` (lua + md only).
- `luac -p` + 260/260 rotation + 17/17 leveling green.

## [2.7.2] — Warlock Final Polish + Strict API (2026-07-12)
- **Warlock**: Curse governance now correctly honors "Agony" mode and assigned curse in all specs (no more Elements overriding).
- **Warlock**: Drain Soul is now strictly TBC shard-capture (ttd-based); removed incorrect execute logic and workaround timers.
- **Warlock**: All code updated to use `.api` / apidocs contracts directly with no workarounds (debuff_remains, is_channeling, GetPet, ttd, try_cast etc.).
- **Warlock**: Stopped OOC Imp spam by removing hardcoded pet summon; specs control pet choice.
- Version bump 2.7.2; clean `eaxrotations.zip` (lua + md only).
- `luac -p` + 260/260 rotation + 17/17 leveling green.

## [2.7.1] — Druid Bear Polish (2026-07-12)

## [2.7.0] — Warlock Curse System Overhaul (2026-07-12)

- **Warlock**: Removed `Curse of Shadow` as a separate rotation option (spell definition retained for safety).
- **Warlock**: Added `Curse of Recklessness` and `Curse of Weakness` curse modes across Affliction, Demonology, and Destruction.
- **Warlock**: Added `Assigned Curse` setting for manual raid coordination.
- **Warlock**: Unified curse refresh thresholds across all three Warlock specs via `shared/warlock_curse_helper_sylvanas.lua`.
- **Warlock**: Fixed Demonology `other_curse_active()` to use state fields instead of the missing `s.target`.
- **Warlock**: Aligned auto-mode curse logic with TBC APL/pro guides:
  - Affliction: `Curse of the Elements` in raid/group.
  - Demonology/Destruction: `Curse of Doom` default, `Curse of the Elements` if assigned/needed.
- Added regression tests for assigned-curse, recklessness, and weakness modes.
- `luac -p` + 257/257 rotation suites + 17/17 leveling green.
- Version bump 2.7.0; clean `eaxrotations.zip`.

## [2.6.1] — Warlock Curse Selection + Life Tap Anti-Spam (2026-07-12)

- **Warlock**: Fixed curse selection so `Curse of Elements`/`Curse of Shadow` no longer override `Curse of Agony` in auto mode.
- **Warlock**: Added `other_curse_active()` guard across Affliction, Demonology, and Destruction to prevent curse overwrites.
- **Warlock**: Added `LIFE_TAP_MIN_INTERVAL = 1.5s` throttle to Affliction, Demonology, and Destruction to stop Life Tap double-cast/spam.
- Added regression tests for curse-mode gating and Life Tap anti-spam in all three Warlock specs.
- `luac -p` + 257/257 rotation suites + 17/17 leveling green.
- Version bump 2.6.1; clean `eaxrotations.zip`.

## [2.6.0] — FSR (Five-Second Rule) Manager + Healer Pause Ordering (2026-07-11)

- **FSR Manager** (`shared/fsr_manager_sylvanas.lua`): hardened `should_pause_for_fsr`, added `fsr_max_pause_seconds` guard (0 = full window), spec_kit setting accessors for the 4 fsr_* controls, improved delta/remaining logic, expanded tests (positive/negative delta, configurable thresholds, e2e with healer strategies).
- **All 5 healers** now correctly place `FSRPause` strategy (after all emergencies/life-saves, before routine fillers):
  - Druid Restoration
  - Paladin Holy
  - Priest Discipline
  - Priest Holy
  - Shaman Restoration
- State population: early hoist of `in_combat`, `lowest_hp_pct`, `mana_pct`, `fsr_*` in `build_state` + declared in schemas (Pattern 14 safe_state).
- `FSRPause.matches`: simplified to pure 3-line delegate to `FsrManager.should_pause_for_fsr(state, context)` (removed duplicated mana/inside/delta pre-filters).
- Menu: 4 common keys added under the appropriate "Mana Conservation" / "Smart Casting" sections (`fsr_enabled`, `fsr_mana_threshold` default 35, `fsr_emergency_hp` default 40, `fsr_max_pause_seconds` default 0).
- Full stack rebased cleanly; all PRs merge-ready.
- `luac -p` + 253/253 rotation suites + 17/17 leveling green.
- Version bump 2.6.0; clean `eaxrotations.zip`.

## [2.5.19] — Warlock CreateHealthstone + OOC Pet Summon Fixes (2026-07-11)

- **Warlock**: Stopped CreateHealthstone spam (multiple 11730 casts on target). Now correctly detects existing healthstones via has_item + inventory fallback before attempting create. Fixed in middleware, destruction (sylvanas + vanilla), and leveling.
- **Warlock**: OOC Summon* (Imp etc) strategies and ooc_manager no longer fire when `has_valid_enemy_target` is true. Extra pet detection (izi, pet_manager).
- ooc_manager pet throttle log is now rate-limited (30s) and message clarified to reduce noise when API lies.
- Version bump 2.5.19; clean eaxrotations.zip; luac + 253/253 tests green.

## [2.5.18] — Active Fight Tracker + Group-Aware Multi-DoT Maintenance (2026-07-11)

- New shared `EaxRotations/shared/active_fight_tracker_sylvanas.lua`: if anyone (you or group/party/raid member or pet) enters combat with a mob, it is added to the "active fights" list.
- DoT maintenance on active fights only when: in range for the spell, mana allows, and `!debuff_up` (no one else has already dotted it up).
- Strict engagement via `multidot_engagement_filter` (prevents patrol dotting).
- Wired for: Shadow Priest (TBC + vanilla), Affliction Warlock (TBC), Balance Druid (Moonfire + Insect Swarm), Elemental Shaman (Flame Shock), Hunter (Serpent Sting), with notes for others.
- Main wiring in `main_sylvanas.lua` for eager updates + reset on combat end.
- Version bump 2.5.18; clean eaxrotations.zip; tests green.

## [2.5.17] — Quick Toggles Playstyle Jitter Fix (2026-07-11)

- Fixed jittery / reverting behavior when clicking playstyle in Quick Toggles.
- Root cause: sync_playstyle_control had a back-sync that read (stale) get_setting cache / manager and called :set() on the combobox, fighting the user's widget change every tick.
- Solution: removed back-sync sets entirely (widget + direct st injection is authoritative); added immediate NS.refresh_settings_cache() after playstyle injection; get_active_playstyle and dispatcher already prefer live widget / context.settings.
- Playstyle changes are now smooth and reliable for all classes/specs.
- Version bump 2.5.17; clean zip; tests green.

## [2.5.16] — Quick Toggles Playstyle Fix (2026-07-11)

- Fixed Playstyle combobox in Quick Toggles: user selections now correctly change the active playstyle/rotation.
- Previously stuck (e.g. always "warlock/autotalent" or auto) due to missing widget-to-setting injection after set_setting removal + dispatcher reading only get_setting.
- Now: combobox value always injected into NS.settings (visible in context.settings); main_sylvanas prefers context.settings.playstyle; get_active_playstyle() helper (prefers live widget) used for all UI (headers, colors, control panel).
- Applies to **all classes and specs** (Warrior, Druid's cat/bear/balance/caster/resto, Priest smite/shadow/etc, Warlock auto+specs, Hunter, Mage, Paladin, Rogue, Shaman).
- Updated changelogs.
- New eaxrotations.zip containing only .lua + .md files.
- Version bump to 2.5.16 in header.lua + changelogs.
- luac -p + 252 rotation + 17 leveling suites all green.

## [2.5.15] — Control Panel Visibility Fix (2026-07-11)

- Control panel entries for rotation, damage, cooldowns, AoE, interrupts, utility, threat drops now always show (fallback to "Unbound"). Switched key defaults from 7 (hidden) to 999 (visible per plugin-helper.md and control-panel.md).
- Removed set_setting writes in syncs to prevent "File name not set" spam; states injected from widgets via get_keybind_toggle_state into settings for gating.
- Verified working with recent changes (injected states used correctly in main_sylvanas, core_sylvanas, strategy_gating etc.; no regressions).
- Version bump to 2.5.15 in all files.
- Clean eaxrotations.zip (only .lua + .md).
- All tests and audits green.

## [2.5.14] — Log File IO Cleanup & Spam Fix (2026-07-10)

## [2.5.13] — Log File IO Cleanup & Spam Fix (2026-07-10)

## [2.5.12] — BT/SWP Dispel Polish (2026-07-10)

- Priest Healing + shared dispel: extended dangerous debuff coverage for Black Temple (Soul Drain) and Sunwell (Polymorph, Flame Buffet, hound poisons/disease).
- Version bump to 2.5.12 in header.lua, VERSION.txt, README, changelogs.
- Clean release zip (only .lua + .md).
- All tests green.

## [2.6.0] — FSR, Downranking & Hit Cap Awareness (2026-07-09)

### Five-Second Rule (FSR) — All 5 Healer Specs
- New shared module: `shared/fsr_manager_sylvanas.lua` — tracks last cast time, FSR window, regen delta
- FSR-aware casting recommendations: pauses casts when regen value > heal urgency
- Integrated into: Druid Resto, Paladin Holy, Priest Discipline, Priest Holy, Shaman Resto
- Each healer spec now exposes `state.fsr_inside`, `state.fsr_seconds`, `state.fsr_regen_delta`
- `FSRPause` strategy added to 4 specs (Druid Resto, Paladin Holy, Priest Disc/Holy, Shaman Resto)

### Downranking Expansion
- **Shaman Resto** — Tiered Healing Wave ranks based on mana %:
  - >30% mana: Rank 12 (max)
  - 15-30% mana: Rank 11 (conserve)
  - <15% mana: Rank 10 (efficient)
- FriendlyTarget Healing Wave also uses tiered ranks
- Existing downranking preserved: Paladin Holy (R4/R7/R9/R11), Priest Discipline (GH 5/6/7), Priest Holy (dynamic via `cast_best_heal_rank`)

### Hit Cap / Expertise / Haste Tracker
- New shared module: `shared/hit_cap_tracker_sylvanas.lua` — static TBC thresholds for all specs
- Hit cap data: 9% (142 rating) melee, 16% (202 rating) casters
- Expertise caps: 26 soft (dodge removal), 56 hard (parry removal)
- Wired into **Arms Warrior** and **Combat Rogue** as proof-of-concept
- State fields: `hit_cap_pct`, `hit_cap_rating_needed`, `expertise_soft_cap`, `expertise_hard_cap`

### Test Updates
- Updated `test_holy_priest_feature_gaps.lua` and `test_discipline_feature_gaps.lua` for FSRPause strategy count
- Full suite: 249/249 rotation + 13/13 leveling suites PASS

## [2.5.0] — Spec Standardization & Polish (2026-07-08)

**All 29 class specializations rebuilt on a shared spec_kit foundation.**
Every spec was migrated to `spec_kit.safe_state` + `define_action_for_class`,
making Pattern 14 nil-guard bugs structurally impossible and standardizing the
spec-file layout across the entire codebase.

### spec_kit Migration — 29 Specs Complete
- 5 fully-migrated classes: Warlock (3/3), Shaman (3/3), Rogue (3/3), Hunter (3/3), Paladin (3/3)
- All 29 TBC specs now use guarded registration + canonical return shape
- `safe_state` proxy eliminates the nil-guard bug class entirely (Pattern 14)
- Over 600 `SPELLS.X` references replaced with `ACTION.X` via `define_action_for_class`

### New Spec Work
- **Druid Bear** — Complete clean rebuild as pure bear-form tank (no form shifting in combat)
- **Paladin Protection** — Wowsims-aligned priority order: Holy Shield > Judgement > Consecration
- **Paladin Holy** — Triage-scored healing, downranked Holy Light (R4/R7/R9/R11), DF+HS burst combo

### New Shared Modules
- `swing_diagnostics_sylvanas.lua` — CLEU-backed swing timer, parry-haste, Overpower dodge proc detection
- `snapshot_sylvanas.lua` — DoT/finisher snapshot upgrade gating (cat Rip/Rake)
- `combat_mode_sylvanas.lua` — ST/AoE/Auto override aligned with wowsims APL

### EaxFishing v2.5.1
- Debug logging gated behind master toggle (no more console spam)
- Stealth suspicion level decays over time in quiet areas (fixes bot freezing)
- Suspicion fully resets when toggling fishing off/on
- Verbose status line shows why the bot paused

### Bug Fixes
- Out-of-range spells fall through to next priority instead of stalling
- Party buffs and dispels skip range checks correctly
- Bear Druid no longer attempts cat/caster spells in combat
- Marksmanship Hunter no longer tries to cast Bestial Wrath
- Target switching correctly resets TTD tracking
- Pets no longer pull neutral mobs unintentionally
- War Stomp (Tauren) correctly gated behind range
- Seal twist diagnostics fixed in Retribution Paladin

### Test Baseline
- 242 rotation suites + 13 leveling suites green (up from 220)
- Spell audit: 61 TBC + 31 Vanilla files clean
- spec_kit compliance: 29 converted, 12 legacy

---

## [2.4.0] — Wowsims APL Alignment Release (2026-07-05)

**The wowsims alignment release.** Every major DPS spec has been audited against authoritative wowsims/tbc-new APL JSON files and either improved to match or verified as already correct. Includes a new shared cooldown planner module and 10+ spec-level fidelity improvements.

### Mage
- **Arcane** — Full burn/conserve rotation: AB3→Frostbolt conserve, PoM at AP end, Serpent-Coil-aware mana gem, Evocation only when AP+IV inactive.
- **Fire** — Combustion aligned with major power windows; prefers 5-stack Scorch before popping.

### Warlock
- **Affliction** — Drain Soul + Shadowburn execute at <5% HP; Immolate moved to correct priority (#8, after Siphon Life).

### Priest
- **Shadow** — Shadowfiend timing (early on short fights, VT-gated on long fights); Starshards moved above Mind Flay filler (was dead code).

### Hunter (all specs)
- Viper/Hawk thresholds aligned to wowsims (enter Viper 5%, exit 25% — was 20%/30%).
- Marksmanship Aimed Shot opener at ≤0.5s combat time.
- Bestial Wrath aligned with major power windows.

### Warrior
- **Fury** — Overpower weaving (opt-in stance dance when BT+WW on CD); Death Wish + Recklessness aligned with major CDs.
- **Arms** — Verified: Slam weaving already implemented.

### Druid
- **Balance** — Starfire is now the primary nuke (was Wrath); mana gem strategy added.
- **Feral Cat** — Powershift threshold raised 20→25.

### Paladin
- **Retribution** — Verified: seal twisting already implemented; Avenging Wrath aligned with major CDs.

### Rogue
- **Combat** — Blade Flurry now requires SnD active; Adrenaline Rush gated to ≤40 energy.

### Shaman
- **Enhancement** — Shamanistic Rage aligned with major power windows.

### New Shared Module
- `shared/cooldown_planner_sylvanas.lua` — Detects Bloodlust/Heroism/Drums/major offensive CDs; `should_fire_offensive()` aligns personal CDs with power windows.

### Bug Fixes
- Hunter Marksmanship no longer attempts Bestial Wrath (BM-only talent).
- Warlock Healthstone respects `use_auto_consumables` / `use_healthstones` master toggles.

### Test Baseline
- 220 rotation suites + 13 leveling suites green (up from 219).

---

## [2.3.16] — Wowsims APL Alignment: Arcane Mage + Affliction Execute (2026-07-05)

### Features

- **Mage Arcane — wowsims-aligned burn/conserve rotation**
  - Conserve phase: AB3→Frostbolt to maintain buff cheaply (matches wowsims `ConserveRotation` group).
  - Mana Gem: fires when `maxMana > currentMana + gemRestore + regen` (3100 with Serpent-Coil Braid, 2500 without).
  - Evocation: fires only when Arcane Power AND Icy Veins are inactive and mana < 20%.
  - Presence of Mind: fires at end of AP window (AP remaining ≤ AB cast time) for one more instant AB.
  - Fire Blast execute: fires when target TTD < AB cast time (instant > casting).
  - Arcane Missiles: Clearcasting consumer ONLY — removed obsolete conserve filler role.

- **Warlock Affliction — wowsims-aligned execute phase**
  - Drain Soul: fires at target HP ≤ 5% (wowsims `remainingTimePercent <= 5%`) alongside existing shard capture.
  - Shadowburn: new execute strategy at target HP ≤ 5%, above Shadow Bolt filler priority.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.17] — Hunter Viper/Hawk Thresholds + Aimed Shot Opener (2026-07-05)

### Features

- **Hunter (all specs) — wowsims-aligned Viper/Hawk thresholds**
  - Aspect of the Viper: enters at 5% mana (was 20%).
  - Aspect of the Hawk: recovers at 25% mana (was 30% or viper_threshold+10).
  - Applies to Beast Mastery, Marksmanship, and Survival.
  - Shared `aspect_manager_sylvanas.lua` defaults updated to match.

- **Hunter Marksmanship — Aimed Shot opener**
  - Fires Aimed Shot at ≤ 0.5s into combat when Serpent Sting is not active.
  - Matches wowsims APL: `currentTime <= 0.5s` + `not dotIsActive(SerpentSting)`.
  - Replaces the old hard-disable (`return false`) that never allowed in-combat Aimed Shot.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.21] — Balance Mana Gem + Feral/Ret Verification (2026-07-05)

### Features
- **Druid Balance — mana gem strategy**
  - New ManaGem strategy fires when `maxMana > currentMana + 2400 + regen` (wowsims-aligned: `currentMana + 1500 < maxMana`).
  - Serpent-Coil Braid-aware restore (3100 vs 2500).
  - Placed before ManaPotion so gem fires first.

### Verification
- **Retribution Paladin**: seal twisting already implemented (`SealTwistBlood` + `SealTwistPrepCommand`) and matches wowsims APL concept.
- **Feral Cat**: Rip/FB/Shred/Mangle/Powershift logic already matches wowsims APL; snapshot tricks exceed wowsims fidelity.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.22] — Balance Nuke Fix + Cat Powershift Threshold (2026-07-05)

### Features
- **Druid Balance — Starfire is now the primary nuke (was Wrath)**
  - Wowsims APL defaults to Starfire (higher DPCT); Wrath is mana-conservation only.
  - Wrath now only fires when mana < `balance_starfire_mana` floor (default 40%).
  - Nature's Grace proc still forces Starfire for burst.
- **Druid Feral Cat — Powershift energy threshold raised from 20 to 25**
  - Wowsims APL powershifts at ≤30 energy; our default was 20 (conservative).
  - New default of 25 is a middle ground that's closer to wowsims without risking
    excessive mana burn on live (configurable via `cat_powershift_energy`).

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.4.1] — Paladin Audit: Protection Priority + Holy/Ret Verified (2026-07-05)

### Features
- **Paladin Protection — wowsims-aligned priority order**
  - Reordered to match wowsims APL: Holy Shield > Judgement/Seal cycle > Consecration > Exorcism > Holy Wrath > Hammer of Wrath > Avenger's Shield.
  - Previous order had Consecration and Avenger's Shield above Judgement, delaying the main threat mechanic.
  - Avenger's Shield moved to last (wowsims treats it as opt-in, lowest priority).

### Verification
- **Paladin Holy**: No wowsims APL (healing not simmed). Verified sophisticated triage: FriendlyTarget, LayOnHands, DivineShield, BlessingOfProtection, Cleanse priority, DivineFavor+HolyShock combo, DivineIllumination, AvengingWrath healing, Light's Grace chain, HolyLight rank downranking.
- **Paladin Retribution**: Seal twisting already implemented (SealTwistBlood, SealTwistPrepCommand); CS priority twist-aware; matches wowsims APL.

### Technical
- All 222 rotation + 13 leveling suites green.

---

## [2.3.23] — Combat Rogue wowsims Alignment (2026-07-05)

### Features
- **Rogue Combat — Blade Flurry now requires Slice and Dice active**
  - Wowsims APL: BF fires only when SnD (6774) AND Expose Armor are active.
  - Our gate now requires SnD so BF time isn't wasted without the attack-speed buff.
- **Rogue Combat — Adrenaline Rush energy gate (≤40)**
  - Wowsims APL: AR fires at ≤40 energy (when energy is needed, not at cap).
  - Prevents AR from firing at high energy where it would mostly overcap.

### Verification
- Audited all three rogue specs against wowsims Combat Swords APL.
- Assassination and Subtlety verified: SnD priority, Rupture, energy pooling present.
- Arms Warrior verified: Slam weaving already implemented.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.20] — Affliction Immolate Priority + Audit Updates (2026-07-05)

### Features
- **Warlock Affliction — wowsims-aligned Immolate priority**
  - Immolate moved from priority #13 to #8 (right after Siphon Life, matching wowsims APL: Corruption > UA > Siphon Life > Immolate).
  - Previously Immolate was buried below Drain Life and curses, causing significant uptime loss.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.19] — Fury Overpower Weaving (2026-07-05)

### Features
- **Warrior Fury — wowsims-aligned Overpower weaving (opt-in)**
  - Added `Overpower` strategy back to Fury (was previously removed as "Arms-only").
  - Wowsims APL includes an "Overpower Weaving" group: swap to Battle Stance when Overpower procs and both BT/WW are on CD ≥1.5s, cast Overpower, swap back.
  - Gated behind `fury_use_overpower` setting (default off) — opt-in for advanced users.
  - Conditions match wowsims: Delay Check (BT+WW ≥1.5s away), not in execute phase, rage 5-100.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.18] — Shadow Priest Shadowfiend Timing (2026-07-05)

### Features

- **Priest Shadow — wowsims-aligned Shadowfiend timing**
  - Short fight (<120s): fire early at <=45% mana for maximum mana return.
  - Long fight (>=120s): fire only when Vampiric Touch is active and remaining >= 1.5s (Shadowfiend GCD).
  - Emergency: always fire at <=15% mana regardless of fight length.
  - Replaces old flat <45% gate that ignored fight context.

### Technical
- All 220 rotation + 13 leveling suites green.

---

## [2.3.15] — Major-CD Window Rollout: Fury, Enhancement, Fire, BM, Shadow, Affliction (2026-07-05)

### Features

- **Warrior Fury**: Death Wish and Recklessness now align with Bloodlust/Heroism/Drums/other major CDs; timeout/TTD fallbacks prevent them from rotting.
- **Shaman Enhancement**: Shamanistic Rage now fires during major power windows in addition to the existing low-mana/low-HP defensive paths.
- **Mage Fire**: Combustion now waits for a major power window; prefers 5-stack Scorch before popping in non-burst mode; burst/manual override skips the Scorch gate.
- **Hunter Beast Mastery**: Bestial Wrath now aligns with major power windows.
- **Priest Shadow**: Racial cooldowns (Berserking, Blood Fury, Arcane Torrent) now align with major power windows.
- **Warlock Affliction**: Racial cooldowns now align with major power windows.

### Bug Fixes

- **Hunter Marksmanship**: Bestial Wrath is now gated on `NS.is_spell_learned` — a MM build can no longer attempt to cast the BM 31-point talent.

### What to Expect

- DPS specs now overlap personal offensive CDs and racials with Bloodlust/Heroism/Drums/windows instead of firing them immediately.
- Each affected CD still fires by timeout (45–60s) or when the target is dying, so nothing is held forever.
- No settings changes needed; behavior upgrades automatically.

---

## [2.3.14] — Cooldown Planner: Stack Trinkets with Bloodlust & Major CDs (2026-07-05)

### Features

- **New shared module: `shared/cooldown_planner_sylvanas.lua`**
  - Detects Bloodlust/Heroism and TBC drums on the player.
  - Detects major offensive cooldowns: Arcane Power, Icy Veins, Avenging Wrath, Bestial Wrath, Shamanistic Rage, Elemental Mastery, Power Infusion, Death Wish, Recklessness.
  - `should_fire_offensive()` aligns offensive trinkets/abilities with these power windows.
  - Timeout fallback (45s into combat) and TTD fallback (≤15s) stop trinkets from being held forever.
  - `trinket_align_with_cds = false` setting restores legacy "fire on cooldown" behavior.

- **Trinket Manager:** added `Berserker's Call` (item 33853) to the offensive on-use database.
- **Mage Arcane:** Arcane Power now also fires when Icy Veins or another major offensive CD is active, not just during bloodlust/burn.
- **Paladin Retribution:** Avenging Wrath now waits for Bloodlust/Drums/major CDs unless the target is dying or 45s timeout has passed.

### What to Expect

- DPS specs will overlap offensive trinkets and major abilities with Bloodlust/Heroism and other temporary power buffs instead of firing them randomly.
- No regression for users who prefer legacy behavior (`trinket_align_with_cds = false`).
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.13] — Hotfix: Hunter Serpent Sting Refresh + Marksmanship Aimed Shot (2026-07-05)

### Bug Fixes

- **Hunter (Beast Mastery / Survival)**: Serpent Sting was applied once and then never refreshed, letting the DoT fall off for the rest of the fight.
  - BM: Added a `SerpentStingRefresh` strategy that re-applies Serpent Sting when it has ≤ 3 seconds remaining.
  - Survival: Added the same `SerpentStingRefresh` behavior using the spec's native debuff tracking.
- **Hunter (Marksmanship)**: Disabled in-combat `AimedShot`. In TBC, Aimed Shot resets the auto-shot timer, so using it after the pull was a DPS loss. It remains available as the pre-pull opener (`AimedShotPrepull`) only.

### What to Expect

- Hunter BM/Survival: Serpent Sting now stays up on long fights and dungeon/raid bosses.
- Hunter Marksmanship: Cleaner Steady Shot / Arcane Shot / Multi-Shot rotation without the auto-shot reset from Aimed Shot.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.12] — Auto-Loot Corpses (All Classes) + Shadow Priest Multi-DoT Fix (2026-07-05)

### Features

- **Auto-Loot Corpses** — Background service that automatically loots nearby corpses while your rotation runs. Humanized timing (random 50–200ms delay), combat-aware (OOC-only by default), burst protection (max 5 per 10s), bag-full pause, player-corpse skip, and configurable range (10–50y). Never blocks rotation casts. Disabled by default — opt-in via new "Auto-Loot" settings tab. Available in **all 9 class schemas** (Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior).
- **Auto-Loot Settings Tab** — 10 configurable options with self-explanatory labels and detailed tooltips: enable toggle, combat mode (OOC/Always), post-combat grace period (0–5s), min/max loot delay (0–300ms / 100–500ms), max loots per 10s (1–10), skip player corpses, stop when bags full, min free slots (0–20), loot range (10–50y).
- **Auto-Loot Stats** — Tracks corpses looted, last target name, and bag-full pause state per session.

### Bug Fixes

- **Shadow Priest**: Multi-DoT spread strategies (SWPSpread, VTSpread, MultiDotSWP, MultiDotVT) now correctly target enemies missing the debuff instead of recasting on the current target.

### What to Expect

- New "Auto-Loot" tab appears in your rotation settings. Enable it if you want automatic corpse looting.
- All settings carry over automatically — no reset needed.
- 219 rotation suites + 13 leveling suites all passing.

---

## [2.3.11] — Hotfix: Shadow Priest Multi-DoT Now Spreads to Real Targets (2026-07-05)

### Bug Fixes

- **Shadow Priest**: The Multi-DoT / Spread strategies (`SWPSpread`, `VTSpread`, `MultiDotSWP`, `MultiDotVT`) were recasting Shadow Word: Pain and Vampiric Touch on your current target instead of spreading them to nearby enemies that were actually missing the debuff. This made cleave and AoE damage fall behind on dungeon/raid packs.
  - Added a target picker that scans nearby enemies and selects one missing the DoT, preferring a target other than your current one.
  - Spread casts now apply their per-target lockout to the chosen enemy so the same target is not double-queued while a cast is in flight.

### What to Expect

- Shadow Priest: In cleave/AoE mode, your DoTs will now genuinely spread across multiple enemies instead of being wasted on the target that already has them.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.10] — Hotfix: Hunter Aspect Manager Missing Middleware Strategies (2026-07-04)

### Bug Fixes

- **Hunter (all specs)**: Fixed `attempt to call field 'viper_middleware_strategy' (a nil value)` that caused the Hunter class module to fail loading entirely. The `aspect_manager_sylvanas.lua` shared module was missing the `viper_middleware_strategy()` and `hawk_middleware_strategy()` functions that the hunter middleware called directly into the strategies array. Added both with proper mana threshold gating, `settings.auto_aspect` guard, buff detection, and `skip_range` casting.

### What to Expect

- Hunter: The rotation loads and runs correctly again. Aspect switching between Hawk and Viper works as intended in combat.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.9] — Hotfix: Shadow Priest Mind Flay Opener Fix (2026-07-03)

### Bug Fixes

- **Shadow Priest**: Fixed Mind Flay firing as the opening spell on fresh targets. Every other damage spell (Shadow Word: Pain, Mind Blast, Shadow Word: Death, Devouring Plague, Vampiric Embrace, Starshards) checks `_engaged_with_player()` to prevent casting on a mob that hasn't targeted you yet. Mind Flay was missing this gate, so it became the default opener when SW:P and MB were blocked. Added the missing check.

### What to Expect

- Shadow Priest: No more "Mind Flay opener" on fresh pulls. The rotation now correctly opens with Shadow Word: Pain → Mind Blast → Mind Flay, or auto-attacks first to establish aggro if needed.
- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.3] — Hotfix: Settings Nil-Guard Sweep (2026-07-03)

### Bug Fixes

- **Priest Holy (TBC + Classic)**: All settings reads now nil-guarded. Previously accessing `context.settings.holy_use_pws`, `holy_use_coh`, `holy_use_binding_heal`, `holy_use_poh`, `holy_use_inner_focus`, `holy_use_lightwell`, `holy_use_desperate_prayer`, `use_party_dispel`, `disc_shield_tank_only`, and `use_shadowfiend` without checking if `context.settings` existed could crash during API hiccups or load race conditions.
- **Priest Smite (TBC + Classic)**: All settings reads now nil-guarded. Fixed `smite_use_shadowfiend`, `smite_use_power_infusion`, `smite_use_inner_focus`, `smite_use_starshards`, `smite_use_devouring_plague`, `smite_use_mb`, and `smite_use_swd`.
- **Priest Discipline (Classic)**: Fixed `disc_use_friendly_target` settings access.
- **Priest Middleware (TBC)**: Fixed `use_threat_drop` settings access.
- **Druid Restoration (Classic)**: Fixed `resto_use_friendly_target` settings access.
- **Druid Middleware (TBC)**: Fixed `use_threat_drop` settings access.
- **Paladin Holy (Classic)**: Fixed `holy_use_friendly_target` settings access.
- **Warlock Middleware (TBC)**: Fixed `use_threat_drop` settings access.

### What to Expect

- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.3.2] — Hotfix: Holy Priest Crash + Dispel Spam (2026-07-03)

### Bug Fixes

- **Holy Priest (TBC + Classic)**: Fixed a crash that spammed the error log during combat. The rotation now runs smoothly without flooding your console.
- **Holy Priest (TBC + Classic)**: Fixed Dispel Magic and Cure Disease firing repeatedly on party members who had no debuffs. Now only casts when someone actually needs cleansing.
- **Shadow Priest (Classic)**: Dispel Magic now only casts when YOU have a magic debuff (Polymorph, Silence, Mind Control, etc.) instead of wasting it on cooldown.
- **Smite Priest (TBC + Classic)**: Fixed the same combat crash as Holy Priest.
- **Kebab Warrior (TBC + Classic)**: Fixed the same combat crash.

### What to Expect

- Drop-in replacement. Delete your old `EaxRotations` folder and replace with this one.
- All your settings carry over automatically.
- No settings reset needed.

---

## [2.2.5] — Leveling Rotation Fixes (2026-07-02)

### Bug Fixes

- **Warrior Classic Leveling**: Shield Bash and Pummel interrupts now work correctly.
- **Mage Classic Leveling**: Removed duplicate logic causing erratic Scorch and Fireball behavior.
- **Shaman Classic Leveling**: Cleaned up duplicate totem checks.
- **Paladin Classic Leveling**: Cleaned up duplicate seal selection.
- **Priest Classic Leveling**: Cleaned up duplicate Mind Flay checks.
- **Rogue Classic Leveling**: Cleaned up duplicate Thistle Tea checks.

### What to Expect

- 214/214 rotation test suites pass.
- 13/13 leveling test suites pass.
- Drop-in replacement over v2.2.4. No settings reset.

---

## [2.2.4] — Classic Leveling Spell Coverage + Stability (2026-07-01)

### New Features

**Hunter Leveling**
- **Raptor Strike**: instant melee attack when enemies close into melee range.
- **Mongoose Bite**: instant melee attack after a dodge proc.

**Mage Leveling**
- **Fireball**: primary fire nuke, respects movement and mana gates.

**Rogue Leveling**
- **Sap**: cast on humanoid targets while stealthed and out of combat.

**Priest Leveling**
- **Vampiric Embrace**: maintained automatically in Shadowform for passive healing.
- **Desperate Prayer**: emergency self-heal below 40% HP (racial, no mana cost).

**Shaman Leveling**
- **Stormstrike**: instant melee attack in melee range.

**Warrior Leveling**
- **Pummel**: Berserker Stance interrupt.
- **Bloodthirst**: Fury talent rage spender (level 40).
- **Shield Slam**: Protection talent threat generator (level 40).

**Paladin Leveling**
- **Holy Shield**: cast when fighting multiple enemies below 70% HP.
- **Retribution Aura**: maintained out-of-combat as alternative to Devotion Aura for solo DPS.

### Fixes

- **EaxAutoQuester**: Fixed crash from merge conflict markers. Better quest dialog detection and NPC rendering.
- **Protection Paladin (TBC)**: Holy Shock no longer wasted offensively when tank health is low.
- **Enhancement Shaman (Classic)**: Fixed crash on spell interrupt check.

### What to Expect

- 214/214 rotation suites pass.
- 13/13 leveling suites pass.
- Drop-in replacement over v2.2.3. No settings reset.
