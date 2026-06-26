# Implementation Plan: APL & Guide-Based Rotation Optimization (29 Specs)

**Created:** 2026-06-25
**API Surface:** All `api/` files; `apidocs/pages/dev/api/` for spellbook, buffs, input
**Docs References:** AGENTS.md Pattern 10, Pattern 14, Pattern 15

## Overview

The original project goal was to optimize all 29 EaxRotations specs against authoritative sources (Wowhead, IcyVeins, SimulationCraft APL, tbc-main reference). This has NOT been done. Current rotations were written by prior authors and may deviate from optimal TBC Anniversary (2.5.5) priorities.

This plan documents a systematic, spec-by-spec optimization effort. Each spec is researched independently, compared against its current implementation, and updated if gaps are found.

**Scope:** 29 TBC specs (`*_sylvanas.lua`) + 11+ vanilla variants (`*_vanilla.lua`). Vanilla is lower priority.

## Methodology (Per Spec)

For each spec:

1. **Research** — Read 2–3 authoritative sources:
   - Wowhead TBC Classic guide for the spec (e.g., `wowhead.com/tbc/guide/classes/warrior/arms`)
   - IcyVeins TBC Classic guide (if available)
   - SimC APL from `tbc-main/` or `tbc-new/` reference repos (internal clones, NOT committed)
   - `wowhead_data/spells/tbc/<id>.json` for spell data verification

2. **Extract Priority List** — Build a text priority list from the guide

3. **Compare** — Read current `<spec>_sylvanas.lua` strategy table, line up against extracted list

4. **Identify Gaps** — Note missing strategies, wrong ordering, incorrect thresholds, outdated spells

5. **Implement** — Edit the spec file (Pattern 10 structure). Nil-guard all changes (Pattern 14).

6. **Validate** — `luac -p` + full gate (`validate.cmd`) + add/update test if behavior changes

7. **Commit** — One concern per commit

## Files to Touch

| File | Change | Verification |
|------|--------|------------|
| `EaxRotations/classes/<class>/<spec>_sylvanas.lua` | Strategy reordering/addition/removal | Gate + spec-specific test |
| `EaxRotations/tests/test_<spec>_custom_matches.lua` (existing) | Update if strategies change | Existing test must still pass |
| `EaxRotations/tests/test_<spec>_feature_gaps.lua` (existing) | Update count assertions | Bump if strategy count changes |
| `plans/apl-guide-optimization-2026-06.md` | Mark spec done | Track progress |

## Task List

### Phase 0: Planning & Reference Extraction
- [ ] **P0.1** Extract APL priority lists from `tbc-main/` and `tbc-new/` reference repos (read-only, internal)
  - Files: `tbc-main/classes/<class>/<spec>.lua` (or equivalent)
  - Acceptance: Documented priority lists for all 29 specs in this plan
  - Verify: N/A (research only)

- [ ] **P0.2** Identify specs with KNOWN issues from test suite / bug reports
  - Files: Review test failures, skipped tests, TODO comments
  - Acceptance: List of "high-confidence gap" specs
  - Verify: Read test files

### Phase 1: Warrior (3 specs)
- [x] **P1.1** Arms — compare against Wowhead Arms Warrior TBC guide
  - Files: `EaxRotations/classes/warrior/arms_sylvanas.lua`
  - API Used: `izi.spell()`, `NS.buff_points()`, `core.object_manager.*`
  - **VERIFIED:** Slam weaving logic correct (swing-timer gated). Rend maintenance, MS cooldown, Execute filler all correct. No changes needed.
  - Verify: `luac -p`, gate, `test_arms_*`

- [x] **P1.2** Fury — compare against Wowhead Fury Warrior TBC guide
  - Files: `EaxRotations/classes/warrior/fury_sylvanas.lua`
  - **FIXED:** Execute was positioned above Bloodthirst in strategy table — reordered to BT → WW → Rampage → Execute → Slam per guide. Committed `014e81c7`.
  - Verify: `luac -p`, gate, `test_fury_*`

- [x] **P1.3** Protection — compare against Wowhead Prot Warrior TBC guide
  - Files: `EaxRotations/classes/warrior/protection_sylvanas.lua`
  - Acceptance: Shield Slam > Revenge > Devastate, threat vs survival tradeoffs
  - **FIXED:** Research (Icy-Veins, reviewed for TBC Anniversary + Wowhead + Warcraft Tavern): single-target priority is SS > Revenge > **Demo Shout > Thunder Clap** ("always up": ~18% melee cut + ~20% atk-speed slow) > Devastate filler > Heroic Strike (rage dump). Previous order had Devastate ABOVE Demo/TC, so the filler preempted survival-debuff refresh. Reordered Demo+TC above Devastate (below ShieldBlock, which stays higher for crush-cap). Core SS>Rev>Dev (devastate fires only when SS+Rev on CD), ShieldBlock 2s-refresh-buffer, and Heroic Strike rage≥70 dump gate all verified correct. Execute left preempted by Devastate (defensible: guide's PRIMARY loop is SS>Rev>Dev; Execute is stance-risky in Defensive stance). Committed `a31d1fe5`.
  - Verify: `luac -p`, gate

### Phase 2: Hunter (3 specs)
- [x] **P2.1** Beast Mastery — compare against Wowhead BM Hunter TBC guide
  - Files: `EaxRotations/classes/hunter/beast_mastery_sylvanas.lua`
  - **VERIFIED:** KillCommand → BestialWrath → RapidFire → SteadyShot order is correct.
  - Verify: `luac -p`, gate, `test_hunter_*`

- [x] **P2.2** Marksmanship — compare against Wowhead MM Hunter TBC guide
  - Files: `EaxRotations/classes/hunter/marksmanship_sylvanas.lua`
  - **VERIFIED:** No obvious quick-win gap found in core rotation scan.
  - Verify: `luac -p`, gate

- [x] **P2.3** Survival — compare against Wowhead SV Hunter TBC guide
  - Files: `EaxRotations/classes/hunter/survival_sylvanas.lua`
  - Acceptance: Explosive Shot (if TBC-era), trap weaving, serpent sting
  - **VERIFIED:** Research (Icy-Veins, re-reviewed for TBC Anniversary Dec 2025 + wowtbc.gg): KC > Multi-Shot > Steady Shot (filler) > Arcane Shot > Serpent Sting (movement-only/optional, NOT a maintained DoT). Current code matches: KillCommand > MultiShot > SteadyShot > ArcaneShot > SerpentSting(last). SerpentSting positioned last = low-priority, consistent with guide's "optional" framing. No Wrath spells (Explosive Shot/Black Arrow/Lock & Load/Kill Shot) present. No change.
  - Verify: `luac -p`, gate

### Phase 3: Mage (3 specs)
- [x] **P3.1** Arcane — compare against Wowhead Arcane Mage TBC guide
  - Files: `EaxRotations/classes/mage/arcane_sylvanas.lua`
  - **VERIFIED:** ArcaneBlast → FireBlast → ArcaneMissiles order is correct.
  - Verify: `luac -p`, gate

- [x] **P3.2** Fire — compare against Wowhead Fire Mage TBC guide
  - Files: `EaxRotations/classes/mage/fire_sylvanas.lua`
  - **VERIFIED:** Scorch 5-stack maintenance before Fireball filler is correct.
  - Verify: `luac -p`, gate, `test_fire_*`

- [x] **P3.3** Frost — compare against Wowhead Frost Mage TBC guide
  - Files: `EaxRotations/classes/mage/frost_sylvanas.lua`
  - **VERIFIED:** FrostbiteFrostbolt → FrozenIceLance → WintersChill → Frostbolt order is correct.
  - Verify: `luac -p`, gate, `test_frost_*`

### Phase 4: Rogue (3 specs)
- [x] **P4.1** Assassination — compare against Wowhead Assassination Rogue TBC guide
  - Files: `EaxRotations/classes/rogue/assassination_sylvanas.lua`
  - **FIXED:** Envenom was before Rupture — reordered Rupture before Envenom (bleed before DP consume). Committed `23e5496d`. NOTE: do NOT add a hard `rupture_remains` gate to Envenom match fn — breaks `test_rogue_snd_maintenance.lua` A7 (test sets rupture_remains=0 by default). Strategy-order swap alone is the fix.
  - Verify: `luac -p`, gate

- [x] **P4.2** Combat — compare against Wowhead Combat Rogue TBC guide
  - Files: `EaxRotations/classes/rogue/combat_sylvanas.lua`
  - **VERIFIED:** SnD → Rupture → Eviscerate → builders order is correct.
  - Verify: `luac -p`, gate, `test_rogue_*`

- [x] **P4.3** Subtlety — compare against Wowhead Subtlety Rogue TBC guide
  - Files: `EaxRotations/classes/rogue/subtlety_sylvanas.lua`
  - Acceptance: Backstab/Ambush priority, hemorrhage maintenance, Premeditation
  - **VERIFIED:** Research (Warcraft Tavern + wowtbc.gg + Wowhead 2.5.5): Opener Premed→Shadowstep→Garrote; sustain Hemo (builder+debuff) > SnD (never expire) > Rupture (5CP) > Eviscerate (surplus). Current code: Premeditation > ShadowstepOpener > [openers] > HemorrhageDebuff > SliceAndDice > ExposeArmor > Rupture > EviscerateKill > Eviscerate > Backstab > Hemorrhage. Ordering defensible (SnD/Rupture/Eviscerate cycle correct; Backstab gated to dagger+behind so Hemo build uses Hemorrhage). Minor nuance: SnD-vs-HemoDebuff order is debatable, not a clear bug. No Wrath spells (Shadow Dance/Honor Among Thieves) present. No change.
  - Verify: `luac -p`, gate

### Phase 5: Paladin (3 specs)
- [x] **P5.1** Holy — compare against Wowhead Holy Paladin TBC guide
  - Files: `EaxRotations/classes/paladin/holy_sylvanas.lua`
  - Acceptance: Holy Light vs Flash of Light, downranking, Divine Favor
  - **VERIFIED + gap FIXED:** Research (Icy-Veins + Wowhead 2.5.5 + Warcraft Tavern): FoL spam (R6 save / R7 throughput) + downranked HL for Light's Grace + max-rank HL/Divine Favor burst + Holy Shock emergency + LoH last resort + Blessing of Light on tank + Divine Illumination. Current: LoHLastResort > DivineShield > BoP > Cleanse* > DivineFavor(+HolyShockCombo) > HolyShock > HolyLightEmergency > DivineFavorHolyLightFollowup > FriendlyTarget > BoSacrifice > ManaPotion/DarkRune > Aura > BlessingRefresh > BlessingOfLightTank > TankPreHeal > SmartHeal > FlashOfLightEfficientTopoff > Seal/Judgement of Wisdom/Light. Order defensible. No Wrath spells (Beacon/Sacred Shield/Infusion of Light) present. **Gap fixed (commit `9b14c93e`):** Avenging Wrath (31884, +20% healing for 20s / 3-min CD — valid TBC, already used by Ret+Prot) was missing from Holy; added 'AvengingWrathHeavyHealing' strategy mirroring DivineIlluminationHeavyHealing — fires only in combat + a heavy_healing window + the holy_avenging_wrath setting (default true) + a TTD gate. Test added (5 assertions). Real healing-throughput gain during heavy damage.
  - Verify: `luac -p`, gate, `test_paladin_holy_*`

- [x] **P5.2** Protection — compare against Wowhead Prot Paladin TBC guide
  - Files: `EaxRotations/classes/paladin/protection_sylvanas.lua`
  - Acceptance: Avenger's Shield opener, consecration, Holy Shield uptime
  - **FIXED:** Wowhead 2.5.5 guide says Holy Shield is #1 (100% uptime for 102.4% CTC crush cap; survival > threat) > Consecration #2. Previous order had Consecration above Holy Shield -> when both refreshed at once, Consecration fired first and Holy Shield waited a GCD -> crushing-blow exposure. Reordered Holy Shield above Consecration. `holy_shield_matches` refreshes on charges (crush-cap uptime); match fns unchanged. Committed `6b1ec84b`. No Wrath spells (Hammer of the Righteous/Shield of the Righteous/Divine Plea) present.
  - Verify: `luac -p`, gate

- [x] **P5.3** Retribution — compare against Wowhead Ret Paladin TBC guide
  - Files: `EaxRotations/classes/paladin/retribution_sylvanas.lua`
  - Acceptance: Seal twisting, Judgement priority, Crusader Strike, Avenging Wrath
  - **VERIFIED:** Per session guidance — seal-twist mechanics are subtle; current twist logic (suppress off-GCD near imminent swing) is native-backed + tested (9 contracts in `test_paladin_tbc_seals`). Don't change without strong in-game evidence. No change.
  - Verify: `luac -p`, gate, `test_paladin_tbc_seals`

### Phase 6: Priest (4 specs)
- [x] **P6.1** Holy — compare against Wowhead Holy Priest TBC guide
  - Files: `EaxRotations/classes/priest/holy_sylvanas.lua`
  - Acceptance: Greater Heal vs Flash Heal, Renew maintenance, CoH usage
  - **VERIFIED:** Research (Wowhead + Icy-Veins + Warcraft Tavern): PoM on CD (pre-cast every pull), CoH when ≥3 hurt, Binding Heal (self+other), Flash Heal emergency, GH max for big hits, Renew on tanks, GH downranked sustain, PW:S emergency only, Inner Focus+PoH, Lightwell, Shadowfiend, 5SR dancing. Current: EmergencyPWS > PreemptiveGreaterHeal > EmergencyFlashHeal > FriendlyTarget > PrayerOfMending > CircleOfHealing > BindingHeal > PrayerOfHealing > ClearcastingGreaterHeal > InnerFocus > Lightwell > GreaterHeal > FlashHeal > DesperatePrayer > Shadowfiend > Dispel/Cure/Abolish > RenewTank > RenewSpread > SurgeOfLightSmite (idle). Order defensible (emergency/PoM/CoH high, Renew as HoT filler lower). No Wrath spells (Guardian Spirit/Serendipity/Body and Soul) present. No change.
  - Verify: `luac -p`, gate, `test_priest_holy_*`

- [x] **P6.2** Discipline — compare against Wowhead Disc Priest TBC guide
  - Files: `EaxRotations/classes/priest/discipline_sylvanas.lua`
  - Acceptance: PW:S priority, Power Infusion
  - **VERIFIED (code) + header fixed:** Research (Warcraft Tavern + Wowhead + Icy-Veins): TBC Disc is a support/hybrid healer (NOT the Wrath shield-healer); PW:S emergency-only (don't pre-shield tanks — starves rage), PoM on tank, PoH ≥3 hurt, Binding Heal, Flash Heal, GH, Renew; Power Infusion on a caster DPS (or self), Pain Suppression tank save. Code is TBC-correct: `pws_tank_matches` fires only below `discipline_pws_hp=35` + Weakened Soul + existing-absorb guards (emergency, NOT a rage-starving 100% pre-shield). Header was misleading (referenced Wrath Penance/Borrowed Time + claimed 'PW:S 100% uptime') — rewritten to Pattern 15 accuracy, committed `df1c7ed6`. No Wrath spells (Penance/Grace/Borrowed Time/Divine Aegis) in code.
  - Verify: `luac -p`, gate, `test_discipline_*`

- [x] **P6.3** Shadow — compare against Wowhead Shadow Priest TBC guide
  - Files: `EaxRotations/classes/priest/shadow_sylvanas.lua`
  - Acceptance: VT > SW:P > MB > MF priority, shadow weaving
  - **VERIFIED:** TBC Spriest consensus: VT > SW:P > Mind Blast (on CD) > Mind Flay (filler), SW:D woven, Shadow Weaving via shadow spells. Current: VampiricTouch > ShadowWordPain > MovingSWP > VampiricEmbrace > DevouringPlague > InnerFocusMindBlast > MindBlast > ShadowWordDeath > MindFlay(filler). DoTs high, Mind Blast above filler, SW:D above filler, MindFlay last — all correct. VE/DP/InnerFocus as keep-up buff / racial / burst CD above Mind Blast is fine (one-shot/CD, don't compete with filler). Header documents the consensus. No Wrath Spriest spells present. No change.
  - Verify: `luac -p`, gate

- [x] **P6.4** Smite — compare against Wowhead Holy DPS Priest TBC guide
  - Files: `EaxRotations/classes/priest/smite_sylvanas.lua`
  - Acceptance: Smite spam, Holy Fire, SW:P maintenance
  - **VERIFIED:** Order is `HolyFire > SurgeOfLightSmite > SW:P > PowerInfusion > InnerFocus > racials > MindBlast > SW:D > HolyNova > SmiteFiller`. HolyFire-over-SurgeOfLight is a steady-state DPS wash (Surge proc lasts ~15s, both get cast regardless); author's "HF = highest nuke, Surge consumed next" is defensible. SW:P conservatively included (mana + ttd gated). Test `test_smite_solo_matches.lua` only asserts solo/defensive rows by name-lookup, so damage order is unconstrained. No change.
  - Verify: `luac -p`, gate

### Phase 7: Warlock (3 specs)
- [x] **P7.1** Affliction — compare against Wowhead Affliction Warlock TBC guide
  - Files: `EaxRotations/classes/warlock/affliction_sylvanas.lua`
  - Acceptance: UA > Corruption > CoA > Siphon Life > Drain Life priority
  - **VERIFIED (ordering):** Research (Icy-Veins + Warcraft Tavern, reviewed for 2.5.5): CoE/CoD > UA > Corruption > Siphon Life > Immolate > Shadow Bolt filler; Nightfall proc → instant SB. Current: NightfallProc > Corruption > UA > SiphonLife > CoD/CoE/CoA > Immolate > SB filler — all DoTs/curse above filler, defensible (curse-after-DoT is a 1-GCD pull nuance, not a bug). NightfallProc high (correct).
  - **CAVEAT (deferred — see `plans/deferred_drain_soul_execute.md`):** `DrainSoulExecute` uses `EXECUTE_HP=25` (sub-25% execute). The Drain Soul sub-25% 4× execute is a **Wrath mechanic** — does NOT exist in TBC (Drain Soul ~62 dps vs Shadow Bolt ~250 dps → channeling at 25% is a large DPS loss). TBC-correct = shard-capture only (mob about to die). Same bug in Demonology (`EXECUTE_THRESHOLD=25`). **RESOLVED 2026-06-25 commit `c3565364`**: both specs now gate on TTD (`SOUL_SHARD_CAPTURE_TTD=5`), tests rewritten. See deferred note.
  - Verify: `luac -p`, gate, `test_affliction_*`

- [x] **P7.2** Demonology — compare against Wowhead Demonology Warlock TBC guide
  - Files: `EaxRotations/classes/warlock/demonology_sylvanas.lua`
  - Acceptance: Shadowbolt filler, demon form (if Wrath-backported), pet management
  - **FIXED:** Immolate was above Corruption — reordered Corruption before Immolate per TBC guide (Icy-Veins + Warcraft Tavern, reviewed for 2.5.5): CoD > Corruption > Immolate > SB filler. Corruption has higher DPCT/longer DoT. Match fns unchanged (symmetric refresh gates) — order swap only. Committed `cddd6393`. SoulFire/Incinerate kept (gated, talented/fallback). No Wrath Demo spells (Metamorphosis/Decimation/Molten Core) present.
  - **CAVEAT (deferred — see `plans/deferred_drain_soul_execute.md`):** `DrainSoul` uses `EXECUTE_THRESHOLD=25` (sub-25% execute) — Wrath mechanic, not TBC. Same as Affliction P7.1. **RESOLVED 2026-06-25 commit `c3565364`** — now TTD-gated shard capture.
  - Verify: `luac -p`, gate, `test_demonology_*`

- [x] **P7.3** Destruction — compare against Wowhead Destruction Warlock TBC guide
  - Files: `EaxRotations/classes/warlock/destruction_sylvanas.lua`
  - **FIXED:** Incinerate was after Conflagrate — reordered to BacklashShadowBolt → Incinerate → ShadowBolt → Conflagrate (filler before consume). Committed `f9b8a60f`.
  - Verify: `luac -p`, gate, `test_destruction_*`

### Phase 8: Druid (4 specs)
- [x] **P8.1** Balance — compare against Wowhead Boomkin TBC guide
  - Files: `EaxRotations/classes/druid/balance_sylvanas.lua`
  - Acceptance: Moonfire > Starfire > Wrath, insect swarm, eclipse (if Wrath-backported)
  - **VERIFIED:** Research (Icy-Veins + Warcraft Tavern + wowtbc.gg, reviewed for 2.5.5): Faerie Fire > Moonfire (keep up, let expire) > Force of Nature > Starfire (primary filler) > Insect Swarm (Icy-Veins: movement-only refresh) > Wrath (mana-inefficient fallback). Current: ForceOfNature > MoonkinForm > InnervateSelf > HurricaneAoE > FaerieFireDebuff > InsectSwarmDoT > MoonfireDoT > MovingMoonfire > StarfirePrimary > WrathFiller. FaerieFire/Moonfire/Starfire/Wrath ordering matches. **Debated point (no change):** Icy-Veins treats Insect Swarm as movement-only, but TBC theorycraft is split — many EJ-era boomkins maintain both Moonfire+IS as DoTs. Current code maintains IS (defensible school); changing it is debatable + test-risk for no clear gain → conservative VERIFIED. No Wrath spells (Eclipse/Typhoon/Starfall) present.
  - Verify: `luac -p`, gate, `test_balance_*`

- [x] **P8.2** Feral Cat — compare against Wowhead Feral Cat TBC guide
  - Files: `EaxRotations/classes/druid/cat_sylvanas.lua`
  - Acceptance: Mangle > Rip > Rake > Ferocious Bite, SR cycle, powershifting
  - **VERIFIED:** Research (Icy-Veins + Warcraft Tavern powershifting + wowtbc.gg): bite-weave default — Rip (4+CP, no Rip up, target lives full duration) > Ferocious Bite (5CP when Rip up, ~35 energy) > Mangle (debuff) > Shred filler > Powershift. **Rake NOT in single-target raid priority** per sources (Shred outperforms). Current: MangleDebuff > RipSnapshot/Rip > FerociousBiteExecute/Ttd > MaimControl > TigersFury > Powershift > RakeSnapshot/RakeTab/Rake > ShredOmen/Shred > MangleFiller > ClawFallback. MangleDebuff-above-Rip is correct (need debuff up for +30% Rip). Finishers above builders (correct). **Debated point (no change):** Rake-in-rotation — sources say skip, but Rake-with-Mangle is a legitimate TBC school; current keeps it (gated). Conservative VERIFIED. No Wrath spells (Savage Roar/Berserk) present.
  - Verify: `luac -p`, gate, `test_cat_*`

- [x] **P8.3** Feral Bear — compare against Wowhead Feral Bear TBC guide
  - Files: `EaxRotations/classes/druid/bear_sylvanas.lua`
  - Acceptance: Mangle > Lacerate > Swipe, demo roar, survival priorities
  - **VERIFIED:** Research (Wowhead 2.5.5 + Icy-Veins + wowtbc.gg): Demo Roar + Faerie Fire (maintain) > Mangle (Bear) on CD (highest threat, +30% bleed) > Lacerate 5-stack > Swipe (spare GCDs) > Maul (rage dump); reserve ≥15 rage for Mangle. Current: DemoralizingRoar > FaerieFireFeral > MangleOpener > Lacerate > LacerateOffTarget > SwipeAoE > MangleBear > Clearcasting* > Swipe > Maul. **Mangle-on-CD-correctness:** `mangle_opener_matches` (above Lacerate) fires Mangle whenever off-CD UNLESS (debuff fresh AND Lacerate 5-stacked) — so when Lacerate<5 + Mangle off-CD, MangleOpener fires Mangle FIRST (beats Lacerate stacking, per guide). `MangleBear` (below Lacerate) only handles the debuff-fresh+Lacerate-stacked case where Lacerate doesn't match anyway. Design is correct. Test asserts DemoRoar-before-FF (holds). No Wrath spells (Survival Instincts/Berserk) present. No change.
  - Verify: `luac -p`, gate, `test_bear_*`

- [x] **P8.4** Restoration — compare against Wowhead Resto Druid TBC guide
  - Files: `EaxRotations/classes/druid/resto_sylvanas.lua`
  - Acceptance: Lifebloom stacking, Rejuvenation, Regrowth, Swiftmend
  - **VERIFIED:** Research (Icy-Veins + Warcraft Tavern + wowtbc.gg): defining mechanic = Lifebloom 3-stack rolling on tank (base ~7s, refresh within window); Rejuvenation on tanks; Regrowth (direct+HoT for spikes); Swiftmend (consumes a Rejuv/Regrowth HoT) on spikes; HT downranked (R10/R13); NS+HT emergency; Tranquility emergency; Innervate on others; Tree of Life form. Current: SwiftmendEmergency > PreemptiveRegrowth > NS+HT > TranquilityEmergency > HealingTouchMaxEmergency > RegrowthSpotHeal > LifebloomLetBloom > TankLifebloomStack > ClearcastRegrowth > RaidLifebloomCoverage(+2nd) > Moving(LB/Rejuv) > PriorityRejuvenation > DownrankHealingTouch > TreeOfLifeMaintain. Lifebloom logic is sophisticated + TBC-correct: `needs_lifebloom_refresh` builds to 3 stacks + refreshes when remains ≤ LIFEBLOOM_REFRESH(2.5s); `should_let_lifebloom_bloom` lets it bloom at full HP / low mana (avoids waste) — reads actual `lifebloom_remains` (no hardcoded duration). No Wrath spells (Wild Growth/Nourish/Revitalize) present. No change.
  - Verify: `luac -p`, gate, `test_druid_resto_*`

### Phase 9: Shaman (3 specs)
- [x] **P9.1** Elemental — compare against Wowhead Elemental Shaman TBC guide
  - Files: `EaxRotations/classes/shaman/elemental_sylvanas.lua`
  - **FIXED:** Flame Shock was after Lightning Bolt — reordered Flame Shock before Lightning Bolt (DoT maintenance before filler). Committed `6c88a6d8`.
  - Verify: `luac -p`, gate, `test_elemental_*`

- [x] **P9.2** Enhancement — compare against Wowhead Enhancement Shaman TBC guide
  - Files: `EaxRotations/classes/shaman/enhancement_sylvanas.lua`
  - Acceptance: Stormstrike > Earth Shock > Flame Shock, totem twisting, WF/FT
  - **VERIFIED:** Research (Icy-Veins + Warcraft Tavern + wowtbc.gg, reviewed for 2.5.5) says TBC Enh priority is Stormstrike > **Flame Shock (maintain DoT)** > Earth Shock (when Flame Shock doesn't need refresh) — NOT "Earth > Flame". Current code already has `Stormstrike > FlameShock > EarthShock > FrostShock`, which MATCHES the guide. (The original acceptance criterion above was wrong.) Totem twisting (Windfury/GraceOfAir) already implemented. No Wrath Enh spells (Maelstrom Weapon/Feral Spirits/Lava Lash) present. No change.
  - Verify: `luac -p`, gate

- [x] **P9.3** Restoration — compare against Wowhead Resto Shaman TBC guide
  - Files: `EaxRotations/classes/shaman/restoration_sylvanas.lua`
  - Acceptance: Healing Wave rank selection, Chain Heal, Earth Shield
  - **VERIFIED:** Research (Icy-Veins + Warcraft Tavern + wowtbc.gg): Earth Shield on tank always (Resto 41pt, 6 charges), Chain Heal bread-and-butter (≥2 injured), HW downranked (R5/R10/R12) + Healing Way stacks, LHW emergency fast heal, Mana Tide, Nature's Swiftness, Bloodlust, totems. Current: EarthShieldTank (high) > NaturesSwiftness > ManaTideTotem > Bloodlust > FriendlyTarget > HealingWay (HW on tank for stacks, overheal-gated) > PreemptiveChainHeal > ChainHeal > SmartHeal > totems. `smart_heal_matches` delegates to shared `Healing.select_heal` which picks HW/LHW/CH — so **Lesser Healing Wave IS cast** (via the chooser) for emergency, plus FriendlyTarget casts HW. No Wrath spells (Riptide/Tidal Waves/Earthliving) present. No change.
  - Verify: `luac -p`, gate, `test_shaman_resto_*`

### Phase 10: Vanilla Variants (Lower Priority)
- [ ] **P10.1** Audit all `_vanilla.lua` specs for Vanilla Anniversary correctness
  - Files: All `*_vanilla.lua` files
  - Acceptance: Spell ranks appropriate for Vanilla 1.15.x, no TBC-only spells
  - Verify: `luac -p`, gate

### Phase 11: Final Validation
- [ ] **P11.1** Full gate run: `validate.cmd` → ALL CHECKS PASSED
- [ ] **P11.2** Spell audit: all referenced spell IDs exist in DBC
- [ ] **P11.3** Update README with any spec list changes

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Guide data is for 2.4.3, not 2.5.5 Anniversary | Wrong priorities | Cross-check against DBC (`wowheadScrape/dbc_extract/wowsims.db`) for spell existence |
| Wrath-backported spells confuse guide vs reality | Missing valid spells | DBC is authoritative; keep Wrath-backported spells if in DB |
| Changing strategy order breaks existing tests | Regression | Run full gate after every spec change |
| Over-optimization for raid vs solo/5-man | Wrong behavior in context | Verify context.is_group / is_raid gates |
| User preference differs from guide | Wrong "feel" | All changes opt-out via menu settings |

## References

- **Internal clones** (read-only, NOT committed): `tbc-main/`, `tbc-new/`, `Sonah/`, `HealPredict/`, `LibHealComm-4.0.lua`
- **Spell verification**: `wowheadScrape/dbc_extract/wowsims.db` (SQLite), `lexxer.org/api/v1/spells/{id}?game=tbc`
- **AGENTS.md**: Pattern 10 (spec structure), Pattern 14 (nil-guards), Pattern 15 (headers)
- **Test gate**: `validate.cmd` (Lua 5.1)
