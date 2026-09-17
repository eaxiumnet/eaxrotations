# Per-Class Research & Reconciliation

> **Date:** 2026-09-06
> **Purpose:** The durable answer to *"have you actually researched the rotations — will they work flawlessly?"* lives here, not in chat. This page records what was researched, where the research lives, what was re-verified against the shipping code, what is honestly still open, and why "flawless" is a word this project refuses to use without a live-client + sim end-to-end pass.

---

## 1. Provenance — where the research lives

| Source | Location | What it is |
|---|---|---|
| **ClassResearchTBC corpus** | `scripts-backup-20250630/ClassResearchTBC/` (backup tree, *outside* the live repo) | Per-class/per-spec research for all 9 TBC classes × every spec — DPS, tanking, AND healing — source-linked to Wowhead / Icy Veins / Warcraft Tavern and the wowsims Go source (coefficients checked at `sim/druid/starfire.go`, `sim/druid/mangle.go`, etc.). Includes niche-mechanic timing docs (seal twisting, totem twisting, powershifting, slam/swing-timer, downrank healing, threat playbooks), `ACTIONABLE_GAPS.md`, `VERIFY_LIST.md`, `S_PLUS_COVERAGE_TRACKER.csv`, and `VETTING_LOG.md`. |
| **wowsims/wotlk APL fixtures** | `tools/evidence/apl/*.apl.json` + `SOURCES.md` | 27 WotLK specs pinned against the simulator's own published APL rotations at commit `563e4a08cb15729f1fdcbcf68e6d68224553bfef`, each fixture's upstream path recorded in the provenance manifest. |
| **Conformance manifest** | `tools/apl_status.lua` | 50/50 specs pass; a `verify_all` component that auto-fills the scorecard's APL column — machine-checked, cannot rot silently. |
| **Behavioral battery** | `EaxRotations/tests/` (584 suites) | 3,573 decision rules across 172 specs prove every rule *fires* in some state; never-triage gates strict across all 5 eras (scorecard: tbc 11 · wotlk 0 · vanilla 9 · sod 14 · forever 9). |

> ⚠️ **Structural note:** the research corpus sits in a **backup tree**, so no CI can re-verify a researched mechanic against the code that ships. The reconciliation below was done by hand on 2026-09-06; the drift it caught (the imp-machine-gun "MISSING" item — see §2) is the proof that this link needs a gate of its own.

---

## 2. Re-verified mechanic registry (2026-09-06)

Every mechanic the June 2026 corpus listed was checked against the **live** tree, and every registry row now names a **behavioral pin** (fire + don't-fire through the REAL file under a mock NS — the 2026-09-06 pin audit that generalizes the imp-machine-gun lesson: grep presence is not proof).

| Mechanic | Live symbol / file | Behavioral pin (fire + don't-fire through the real file) |
|---|---|---|
| Druid powershifting | `cat_sylvanas.lua` (energy tick tracker, Wolfshead detection, `should_powershift`, `powershift_matches`) | ✅ **pin-added 2026-09-06** — `test_cat_pool_for_builder_tick.lua`: `Powershift` fires at ≤25 energy (CP ≤4, mana ok, tick not imminent); `EmergencyPowershift` fires at ≤10 energy; both hold at 30 energy / disabled / <8 mana / tick ≤0.35 — real `cat_sylvanas.lua` loaded against a mock NS |
| Paladin seal twisting | `retribution_sylvanas.lua` (`SealTwistBlood`, `SealTwistPrepCommand`, `twist_window`, `prep_start`) | ✅ already pinned — `test_paladin_retribution_twist_diagnostics.lua` (fires in the twist window + execute), `test_paladin_tbc_seals.lua` (CrusaderStrike skipped in the prep window / fires outside it), `test_seal_twist_lane_regression.lua` (fire + negative through the real audit read path). All drive real `retribution_sylvanas.lua` |
| Shaman totem twisting | `enhancement_sylvanas.lua` (`totem_state`, `windfury_twist_matches`, `grace_air_twist_matches`, mana floor) | ✅ already pinned — `test_shaman_enhancement_totem_twist.lua` (real `enhancement_sylvanas.lua`; C1–C4 fire + don't-fire on both twist lanes) plus the execute-capture lanes proven via the P0-3 harness |
| Hunter shot timing | `beast_mastery_sylvanas.lua` / `marksmanship_sylvanas.lua` / `survival_sylvanas.lua` + shared shot buffer / `cliptracker_sylvanas.lua` | ✅ already pinned — `test_hunter_shot_timer_integration.lua` (real BM/MM/SV files: `SteadyShot` fires when the shot buffer is safe, HELD when the shot timer says delay) + `test_shot_timer.lua` for the shared module |
| Warrior slam timing | `arms_sylvanas.lua`: `slam_matches` swing-timer gate (`SLAM_CAST_TIME` 0.5 + `SLAM_SAFETY` 0.2 window, MS/OP starvation guards) | ✅ **pin-added 2026-09-06** — `test_arms_custom_matches.lua`: real `arms_sylvanas.lua`; `Slam` FIRES at mh_until 1.2 (inside the (0.7, 1.5] window, Battle stance, target); HOLDS at mh_until 0.5 (swing imminent), 5 (too far), <15 rage, MS cd 0.5, or `slam_weave_enabled=false` |
| Rogue energy/poison | `combat_sylvanas.lua`: `get_next_tick_in`, `should_pool_energy`, `should_spend_energy`, `get_energy_cap` | ✅ already pinned — `test_combat_energy_pooling.lua` (real `combat_sylvanas.lua`: builder fires at 51+ energy / affordable, HELD at 50/30/25 with TTD gating) + `test_rogue_vanilla_live_fixes.lua` (vanilla-era pooling) |
| Healing downrank | `NS.cast_best_heal_rank` (`core_sylvanas.lua`) + per-spec rank tiers (resto `HEALING_WAVE_MAX`/`CONSERVE`/`EFFICIENT`, holy/discipline tables) | ✅ lane-level already pinned — `test_healer_encounter_profiles.lua` (real TBC healer files: first-match/action/target asserts incl. `DownrankHealingTouch → 26978` conserve tier; no-fire on full-health party / out-of-range) + per-spec healer suites. ⚠️ Residue: the **core `cast_best_heal_rank` sort itself** only runs in the boot path (no unit suite loads real `core_sylvanas.lua`) — conserve-tier *choice* is pinned at the lane level, not the core sort |
| Tanking playbook | Bear (`bear_sylvanas.lua` taunt throttle, snap threat), paladin + warrior protection (active mitigation, defensives) | ✅ already pinned — `test_snap_threat.lua` (real `shared/snap_threat_sylvanas.lua`: fires once on combat entry, hold on repeat/OOC/disabled, fallback spell), `test_paladin_protection_jow_mode.lua` (real prot paladin), `test_warrior_defensive_threshold_wiring.lua` (real prot warrior: ShieldWall at ≤ threshold, held above). ⚠️ Residue: the bear **Growl throttle lane** has no dedicated unit suite — proven by TBC era-battery reachability only |
| **Warlock imp machine gun** | `shared/pet_manager_sylvanas.lua` — imp Firebolt refires **every idle frame** when the imp is not casting (closes the ~0.5s engine idle gap); non-imp warlock pets (VW/Succubus/Felguard/Felhunter) throttled to 2s | **`test_warlock_live_fixes.lua`** — behavioral pin added 2026-09-06 driving the REAL module: TBC-client rank resolves 27267, full-ladder resolves 39023, idle refire each tick, **no double-fire mid-cast**, refire on cast completion, VW taunt 2s throttle |
| **School lockout (engine LoC signal)** | `shared/spell_school_gate_sylvanas.lua` + `main_sylvanas.lua` `context.school_lockout` (from `unit:get_loss_of_control_info().lockout_school`, a `schools_flag` bitmask) | ✅ **pin-added 2026-09-11** — the signal had ZERO callers before this wave. `test_mage_frost_wotlk_strategies.lua`: FireBlast fires ONLY under a frost lock while Frostbolt/IceLance/DeepFreeze/FrostfireBolt hold. `test_druid_balance_wotlk_strategies.lua`: arcane lock → Wrath fires with no Eclipse while Starfire/Moonfire hold; nature lock → Starfire fires even during solar Eclipse while Wrath/InsectSwarm/FaerieFire/Hurricane hold. Both drive the REAL `_wotlk.lua` files against a mock NS; battery scenarios `school_locked_frost/nature/arcane` make each lock observable |
| **Cast/channel end time (engine timing signal)** | `shared/cast_timing_sylvanas.lua` + `main_sylvanas.lua` `context.target_cast_remaining` (from `unit:get_channeling_or_casting_remaining_sec()` / `get_cast_remaining_sec()` / `get_channel_remaining_sec()`), consumed by `interrupt_manager_sylvanas.cast_has_interrupt_window` | ✅ **pin-added 2026-09-12** — the accessors had ZERO callers before this wave; the only proxy was cast *percent*, which is duration-relative. `test_interrupt_manager.lua` +11 assertions (0.05s holds, 0.30s on-floor holds, 0.31s fires, `settings.interrupt_lead_sec` re-closes, channel accessor honoured, zero = fail-open); `test_mage_frost_wotlk_strategies.lua` (Counterspell) and `test_priest_shadow_wotlk_strategies.lua` (Silence) add fire/hold pins driving the REAL `_wotlk.lua` files; 17 WotLK interrupt lanes gated; battery scenario `target_cast_finishing` (0.05s left) makes the hold observable |

The June corpus rated the imp Firebolt pacing **MISSING** (no warlock spec referenced it). The 2026-08 pet-manager rewrite implemented it; this pass proved it live under the real module and pinned it so a regression cannot silently delete the machine gun again.

---

## 3. Classified partials (not defects — honest residue)

| Area | State | One-line reason |
|---|---|---|
| PvP branches in ranged DPS specs | Engine-wide machinery present (`is_pvp` zone context populated per spec; shared burst-window / racial / dispel managers); explicit per-spec PvP branches are concentrated in melee/support specs and **thin in ranged casters** — BM hunter has zero `pvp_` refs | ✅ engine machinery pinned — `test_pvp_burst_window.lua` drives the REAL `shared/pvp_burst_window_sylvanas.lua` under a fresh mock NS; generic `is_pvp` gating plus the shared managers covers the basics engine-wide. Per-spec PvP priority refinements remain a coverage gap, not a broken lane (mirrors ACCURACY.md known limits) |
| Encounter-specific overrides | `encounter_reactions` exists only in holy priest (TBC + vanilla, e.g. Karazhan 532) | Holy's real file is driven by `test_healer_encounter_profiles.lua`; DPS/tank specs already gate on CC (`is_cc_target`) and AoE volume (`enemy_count`), covering the concrete skip-AoE/CC-safe scenarios. ⚠️ Residue: the Karazhan map-id override layer itself has no dedicated unit pin (mock map context not modeled) — the holy-only scope claim is verified by reference, the reactions by era-battery reachability; per-boss overrides for 30+ DPS specs remain speculative without live encounter data |

---

## 4. VERIFY_LIST items — disposition

All eight items from the corpus' `VERIFY_LIST.md` require **wowsims execution or raid logs**, neither of which is runnable in this workspace (no Go toolchain, no sim runner, no live client). None showed a code defect against the live tree; each stays OPEN with its required source:

| Item | Disposition |
|---|---|
| Druid Balance SP 800/1000/1200 breakpoints | Sim-pending — coefficients verified against sim Go source (Starfire 1.0, Wrath 0.571); thresholds remain heuristics |
| Druid Feral AP 1500/2000/2500 breakpoints | Sim-pending — AP formulas confirmed (Toskk); gear-set-specific thresholds need sim runs |
| Bear taunt recovery during an in-flight form swap | Live-client runtime validation pending |
| Bear encounter priority per boss | Raid-log confirmation pending (priority implemented) |
| VT → Life Tap mana chain frequency | Needs group data / sim — Life Tap mana gating implemented; shadow-priest-party frequency reduction unconfirmed |
| Judgement assignment by group composition (JoC/JoW/JoL) | Needs raid/party census — per-spec judgement lanes implemented (ret `Ret_JudgeCrusader`, prot JoW emergency mode, holy JoW/JoL twist) |
| Totem range impact on melee specs | Encounter-specific testing pending (twist implementation pinned; range reads depend on engine distance) |
| Armor-pen Feb-2026 hotfix re-run | Documented ACTIONABLE in `VETTING_LOG.md`; requires sim re-run for physical specs |

---

## 5. The honest answer to "will they work flawlessly?"

**No — and anyone who says yes is lying.** What is proven and what is not:

**Proven:** cast *order* per spec against the sims' published rotations (50/50 APL conformance, WotLK 27 specs pinned to `wowsims/wotlk` + 23 TBC against reference orders), and rule *reachability* (0 dead lanes in every era, 584-suite battery). That is the bulk of what a rotation is.

**The five gaps between "conformant" and "flawless":**

1. **No end-to-end DPS sim of EaxRotations' actual decisions.** Conformance checks order; it does not run this rotation inside a damage sim and compare output. A priority order can be conformant yet lose a few percent to a subtle interaction (a refresh window a fraction too wide, a proc window not held for).
2. **TBC has no executed simulator here** — those specs are validated against community reference orders, not a sim engine's output. Weaker than WotLK's ceiling.
3. **No healer has a comparative sim benchmark.** Only WotLK holy/disc priest have APL fixtures (the sim repos ship no implemented rotation for any other healer — `tools/evidence/apl/SOURCES.md`), which is why roadmap P2 stays OPEN by design. The *validation* gap is closed, though: the 2026-09-09 healer wave expanded every WotLK healer to its published guide priority (resto druid 7→11, holy paladin 5→9, resto shaman 7→10, discipline 4→6 lanes — see “WotLK healer tier re-rate” below), and the SoD healer tier joined it the same day (resto shaman 7→12, resto druid 7→11 against the Wowhead SoD rune guides — see the SoD healer pass note below), with TBC druid/caster reaching guide depth too (8→11).
4. **Vanilla + SoD have no sim project at all** — they reach S (every rule fires), never S+.
5. **No live-client verification.** Everything runs against mocked WoW state; a state-read bug (wrong debuff ID, wrong power type) shared by the mocks and the code would pass everything here and only surface in game.

### WotLK healer tier re-rate (2026-09-09)

The healer expansion wave moved the WotLK healer tier from the pre-wave state (thin priority skeletons, 4–7 lanes per file) to full guide-priority depth. Current state per spec:

| Healer | Lanes | What the wave added | Evidence |
|---|---|---|---|
| Resto druid | 7 → 11 | Nature's Swiftness+HT emergency pair, Rebirth battle-rez (`find_dead_party_ally`), Tranquility (3+ injured, ≤50% band, 8-min CD) | Icy-Veins WotLK resto druid rotation page; TBC sibling idiom; fire/hold pins in `test_resto_wotlk_dsl_priority` (24→32) |
| Holy paladin | 5 → 9 | Seal of Wisdom upkeep, Judgement-on-CD (≤90% mana, JoW uptime), Divine Favor+Holy Light combo, Divine Plea (≤50% mana) | Icy-Veins WotLK holy paladin rotation page; pins in `test_holy_wotlk_dsl_priority` (14→22) |
| Resto shaman | 7 → 10 | Nature's Swiftness+HW emergency pair (NS id 16188), Tidal Waves 2-stack → Healing Wave priority | Icy-Veins WotLK resto shaman rotation page; pins in the restoration suite |
| Discipline priest | 4 → 6 | Pain Suppression (≤30% save, leads the order), Power Infusion (≤45% pressure) | wowsims `disc.apl.json` `autocastOtherCooldowns` made concrete; pins in `test_discipline_wotlk_dsl_priority` (8→12) |
| Holy priest | unchanged | already the tier's strongest (A− pre-wave: pinned wowsims order, CoH party gates, Guardian Spirit) | existing pins |

All ten new spell ids are Wowhead-verified and pinned in the WotLK spell-audit allowlist (+10 → 194); the battery's strict never=0 gate holds across all 41 WotLK specs. Remaining honest ceiling: the five gaps above — guide-conformance is not sim-conformance, and nothing here is live-client verified. Deliberate exclusions, unchanged: Tremor/Cleansing Totem and Mass Dispel responses stay in the dispel middleware (one owner per decision), and holy priest was not re-touched.

### SoD healer guide pass (2026-09-09)

Same-day companion to the WotLK re-rate: the two SoD healer files were the era's last 7-lane triage specs; both now match their published playstyle priority.

| Healer | Lanes | What the pass added | Evidence |
|---|---|---|---|
| Resto shaman | 7 → 12 | Earth Shield upkeep (408514 leg-rune cast; 408519 is the proc heal, NOT a cast — DBC SkillLineAbility + Wowhead), Nature's Swiftness+HW emergency pair (16188; druid uses 17116 — SLA rows prove the split), Mana Tide (held while a water totem occupies the slot) | Wowhead SoD shaman-healer best-runes guide; pins in `test_sod_rogue_shaman_rotations` + matrix rows |
| Resto druid | 7 → 11 | Swiftmend (18562 — the Efflorescence rune 417149 is the passive rider, no separate lane), NS+HT pair (17116), Innervate (29166 only; 29167 is the item-indexed buff id, audit-caught), Rebirth (30-min CD at 60, NOT the WotLK 10-min) | Wowhead SoD druid-healer rune guide; pins in `test_sod_druid_hunter` + matrix rows |

Both fire in the battery's SoD-scoped `sod_ns_burst` scenario, never-fires=0; new rune ids pinned in SOD_RUNE_IDS (65). Same honest ceiling as the WotLK wave — guide-conformance is not sim-conformance, and no SoD sim project exists (gap 4 above).

So the honest ranking of the 172 rated specs: ~27 are order-pinned to a real sim **and** behavior-pinned; ~50 more are behavior-pinned against references; healers beyond WotLK priest, vanilla, and SoD are behavior-pinned with no external benchmark. That is a very high floor — and exactly why "flawless" is refused.

*Gates at record time: 563/563 suites green, verify_all exit 0, luac clean, scorecard in sync. Rotation wave + healer expansion shipped via PR #14; holy-priest guide-gap lanes via PR #15 (both merged 2026-09-09); SoD healer pass + TBC druid/caster completion committed locally as `3205ca00` (not yet merged). This page updated 2026-09-09.*
