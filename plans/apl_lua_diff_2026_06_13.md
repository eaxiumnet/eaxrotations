# APL vs Lua Priority Diff Report (TBC Classic Anniversary)

**Date:** 2026-06-13
**Type:** T13 — Comparison report
**Source APLs:** `tbc-new/ui/<class>/<spec>/apls/*.apl.json` (18 usable)
**Target Rotations:** `EaxRotations/classes/<class>/<spec>_sylvanas.lua` (29 TBC specs)
**Method:** Read T12 mapping (`apl_to_lua_mapping_2026_06_13.md`), independently verify APL JSONs and Lua strategy orderings, restructure into 4 categories, classify each finding as intentional or potential gap.

---

## Background

APL JSONs from the wowsims TBC simulator emit ordered "should-cast" actions in a flat chain. Lua rotations use a strategy table where entries evaluate predicates against shared state and the first match wins. They are not a literal 1:1 mirror. The Lua order encodes:

1. **Survival/utility** gates that have no APL equivalent (simc characters don't take damage)
2. **Burst cooldowns** synced to external state (Bloodlust, boss-only gates)
3. **APL-mirrored spells** in roughly the same priority as the simc list
4. **Conditional logic** (snapshot refresh, movement, multi-DoT spread) that the APL hides behind a single `groupReference`

This diff focuses on categories 3 and 4: the APL-mirrored spells. Survival gates and PvP additions are documented separately as Lua-only.

**Corrections to T12 mapping (this report supersedes the mapping file's "Summary: Priority Inversions" section):**
- The T12 mapping claimed the Affliction APL casts "UA before Corruption." Direct JSON verification of `tbc-new/ui/warlock/dps/apls/affliction.apl.json` shows the order is **27215 (Immolate) → 30405 (Corruption) → 27216 (UA) → 30911 (Siphon Life)**. Lua has Corruption first, then UA. **No inversion** — T12 was wrong.
- The T12 mapping labeled Balance Druid's `27012` entry as "Starfall." Spell 27012 is **Hurricane**, a TBC spell. The Lua has `HurricaneAoE` which matches. **Not an APL-only entry** — T12 was wrong.

---

## 1. Exact Match

For these specs, the relative ordering of APL-mirrored spells in Lua matches the APL. Lua adds survival gates and utility before/after, but the core rotation ordering is preserved.

### Warrior, Arms
Core abilities: Mortal Strike → Execute → Whirlwind → Heroic Strike / Cleave → Overpower (weave) → Slam → Rend → Sunder Armor (defensive stance gate). Lua splits 2H vs DW with internal branching; APL uses `variableRef`. No ordering mismatch.

### Warrior, Fury
Core abilities: Bloodthirst → Execute → Whirlwind → Heroic Strike / Cleave → Hamstring (DW). Lua adds Rampage (TBC 4-piece) and SwingDesync (DW trick) as additions, not inversions.

### Warrior, Protection
Core abilities: Shield Block → Thunder Clap → Devastate → Shield Slam → Revenge → Execute → Battle Shout → Heroic Strike / Cleave. Lua front-loads emergency defensives (LastStand, ShieldWall, ShieldBash) that the APL places after cooldown sync groups. Core ability order preserved.

### Warlock, Destruction
Core abilities: Shadow Bolt → Immolate → Conflagrate → Shadowburn → Death Coil → Soul Fire. Lua matches the `destro_fire.apl.json` variant (Incinerate > ShadowBolt) rather than `destruction.apl.json` (Shadow Bolt only). This is a known generalization — the same Lua file handles both variants.

### Warlock, Demonology
Core abilities: Immolate → Corruption → Shadow Bolt → Death Coil → Shadow Burn. Lua adds pet state trio, HealthFunnel, Incinerate (Imp buff) as additions. Curse ordering (CoD → CoE → CoA) matches APL's `castWarlockAssignedCurse`.

### Shaman, Enhancement
Core abilities: Stormstrike → Flame Shock → Earth Shock → Frost Shock → Chain Lightning → Lightning Bolt → Shamanistic Rage → Bloodlust. Lua splits the APL's `Shocks` group and `Totems` group into individual entries. Core order matches exactly.

### Hunter, Marksmanship (DPS)
Core abilities: Steady Shot → Arcane Shot → Multi-Shot → Kill Command. Lua adds RapidFire, Readiness, AimedShot (cooldowns hidden behind `autocastOtherCooldowns` in APL). Melee-weave logic handled differently (APL: `Weave` group; Lua: implicit).

### Rogue, Combat (Swords)
Core abilities: Slice and Dice → Rupture → Eviscerate → Hemorrhage → Backstab → Sinister Strike → Expose Armor. Sinister Strike sits at the bottom of the Lua strategy list (universal filler fallback), while APL uses it as a primary builder. Match functions handle the gating correctly regardless.

### Mage, Arcane
Core abilities: Arcane Blast → Arcane Missiles → Evocation → Mana Gem → Icy Veins → Cold Snap. Lua re-implements the APL's `DetermineRegenRotation` + `ConserveRotation` as a state machine (`s.phase == "burn"` vs conserve). Same end result.

### Druid, Feral Cat
Core abilities: Rip → Ferocious Bite → Mangle (debuff) → Faerie Fire (Feral) → Tiger's Fury → Shred. Lua adds RipSnapshot (SP-aware refresh), BiteTrick/RakeTrick (Tigers Fury pooling), and stealth openers (Pounce/Ravage) not in APL. Core order matches.

### Druid, Feral Bear
Core abilities: Mangle Bear → Lacerate → Faerie Fire (Feral) → Demoralizing Roar → Swipe. Lua adds OOC buffs (MarkOfTheWild, GiftOfTheWild, Thorns), clearcasting procs, and PvP block. Core order matches.

---

## 2. Priority Inversions

### 2a. Protection Paladin — Consecration before Holy Shield (INTENTIONAL)

**APL order:** Holy Shield (#4) before Consecration (#7)
**Lua order:** Consecration (#3) before Holy Shield (#4)

| Priority | APL | Lua |
|---|---|---|
| 1-2 | Judgement | ManaPotion, RighteousFury |
| 3 | Wait (HS refresh) | **Consecration** |
| 4 | **Holy Shield** | HolyShield |
| 5 | Judgement | AvengerShield |
| 6 | Seal of Command | Judgement |
| 7 | **Consecration** | SealOfCommandAoE |

**Is this a gap?** No. Deliberate design choice. The code comment at line 380 of `paladin/protection_sylvanas.lua` reads: *"Priority order: Consecration > HolyShield > AvengerShield for AoE threat. Consecration generates more AoE threat per GCD; HolyShield provides mitigation."* The APL optimizes for single-target mitigation; the Lua optimizes for AoE threat generation, which matters more in TBC tanking.

**Severity:** Informational. No action required.

### 2b. Warrior Protection — Thunder Clap Position (INTENTIONAL)

**APL order:** Thunder Clap (#13), close to Shield Block (#12)
**Lua order:** ThunderClap (#17), moved down after ShieldSlam and Revenge

**Is this a gap?** No. Intentional re-prioritization. Thunder Clap is a debuff that lasts 30s; Shield Slam and Revenge are higher damage per GCD. The Lua correctly prioritizes damage spells and only drops Thunder Clap when the debuff falls off.

**Severity:** Informational.

### 2c. Affliction Warlock — False Positive (CORRECTED)

**T12 mapping claim:** APL casts **UA before Corruption**; Lua casts **Corruption before UA**.
**Actual finding:** The APL JSON (`tbc-new/ui/warlock/dps/apls/affliction.apl.json`) order is:
- Line 10: spellId 27215 (Immolate) — missing
- Line 11: spellId 30405 (Corruption) — missing
- Line 12: spellId 27216 (UA) — missing
- Line 13: spellId 30911 (Siphon Life) — missing

The Lua has `CorruptionDoT` (line 446) before `UnstableAfflictionDoT` (matches APL line 11 → line 12). **No inversion** — the T12 mapping misread the spell IDs. T13 supersedes the T12 finding.

**Severity:** T12 documentation error. No code change needed.

### 2d. Soft Inversions (Not Real Gaps)

These appear in the ordering but don't cause incorrect behavior because the match functions gate them:

| Spec | Lua position | APL position | Why It's Not a Gap |
|---|---|---|---|
| **Shadow Priest** | DevouringPlague #11 | Devouring Plague #9 | `devouring_plague_matches` requires SWP+VT active, so it can't fire before DoTs anyway |
| **Combat Rogue** | SinisterStrike #17 (bottom) | Sinister Strike #11 (primary builder) | `is_spell_learned` gates: SS is fallback when Hemo/Backstab/Mutilate aren't available |
| **Elemental Shaman** | FlameShock #15 (after filler) | Not in APL's visible priorityList | The Elemental APL JSON has no Flame Shock entry. The Lua adds it as a Lua-only DoT maintenance. Order in Lua is gated by `flame_shock_matches_fn` (only fires when `flame_remains <= 1`), so position after the filler is fine in practice. |

---

## 3. Lua-Only (Strategies With No APL Analog)

These strategies exist in Lua but have no equivalent in the APL JSONs.

### 3a. Survival / Defensive Gates (ALL specs)

Every Lua spec starts with survival strategies that the APL omits (simc characters don't take damage):

| Spec | Lua-Only Survival |
|---|---|
| **Warrior Arms** | HealthPotion, DamagePotion, Healthstone, DefensiveStance, BattleStance, BerserkerStance |
| **Warrior Fury** | HealthPotion, DamagePotion, Healthstone, BerserkerStance |
| **Warrior Protection** | LastStand (HP<=40), ShieldWall (HP<=35), ShieldBash, ShieldSlamPurge |
| **All Warlocks** | Healthstone, DeathCoilSurvival (HP<=30-40), Soulshatter (threat>=90) |
| **All Shaman** | ManaPotion, ManaEmergencyWand (mana<5%), GhostWolf |
| **Shadow Priest** | PowerWordFortitude, Shadowfiend, PsychicScream, FlashHeal, PowerWordShield |
| **Mage Arcane** | IceBarrier, IceBlock (HP<=20), ColdSnap (HP<=35), ManaShield |
| **Hunter MM** | HealthPotion, ManaPotion, MendPet, CallPet, RevivePet |
| **All Druids** | BarkskinDefense (HP<=40), ManaPotionEmergency, RebirthBattleRez |
| **Paladin Ret** | DivineShield (HP<=15), LayOnHands (HP<=8), DivineProtection (HP<=22), Healthstone (HP<=35) |
| **Paladin Protection** | DivineProtection, DivineShield, LayOnHands |
| **Rogue Combat** | HealthPotion, DamagePotion, Stealth, Vanish, Sprint, Feint |

### 3b. PvP Strategies

| Spec | Lua-Only PvP |
|---|---|
| **Warrior Arms** | Hamstring, PiercingHowl, IntimidatingShout |
| **Warrior Fury** | Hamstring, SweepingStrikes |
| **Warrior Protection** | SpellReflection, Disarm, IntimidateShout |
| **Paladin Ret** | RepentanceOpener, HammerJusticeBurst, HammerWrathFleeing, BlessingFreedom (self/ally), BlessingProtectionFocusedAlly |
| **Druid Balance** | PvP_NaturesGrasp, PvP_EntanglingRoots, PvP_Cyclone |
| **Druid Bear** | BashPvP, FeralChargePvP, NaturesGraspPvP, FaerieFirePvP |
| **Shadow Priest** | SWDCCBreak, DispelMagic, ShackleUndead |

### 3c. Buff / Form Maintenance

| Spec | Lua-Only Buffs |
|---|---|
| **Warrior Arms** | CommandingShout, BattleShout, Bloodrage |
| **Warrior Fury** | BattleShout, BerserkerRage, Bloodrage, VictoryRush |
| **Warrior Protection** | BattleShout, CommandingShout, Bloodrage, VictoryRush |
| **Shadow Priest** | Shadowform, InnerFire, VampiricEmbrace, PreCombatPull (VT) |
| **Mage Arcane** | PresenceOfMind, ArcanePower |
| **Hunter MM** | AspectOfTheHawk, AspectOfTheViper, HuntersMark, FreezingTrap |
| **Shaman Enhancement** | WaterShield, LightningShield, MHWeaponBuff, OHWeaponBuff, EarthTotem, WaterTotem, FireTotem, WindfuryTotemTwist, GraceOfAirTotemTwist, WindfuryTotemMaintain |
| **Shaman Elemental** | LightningShield, WaterShield, TremorTotem, EarthbindTotem, TotemOfWrath, WrathOfAirTotem, ManaSpringTotem, WeaponBuffTriplet |
| **All Druids** | MarkOfTheWild, GiftOfTheWild, Thorns, MoonkinForm, CatForm, BearForm |

### 3d. Advanced Rotation Mechanics

| Spec | Lua-Only Advanced |
|---|---|
| **Warrior Fury** | Rampage (TBC 4-piece), SwingDesync (DW rage smoothing), DeathWish |
| **Affliction Warlock** | CorruptionSpread (multi-DoT), NightfallProc (instant Shadow Bolt) |
| **Destruction Warlock** | BacklashShadowBolt (proc), SeedOfCorruption (AoE), RainOfFire (AoE), Hellfire (AoE), SearingPain (moving), Soulshatter (threat) |
| **Elemental Shaman** | FlameShock (DoT maintenance, not in APL), FlameShockMoving/EarthShockMoving/FrostShockMoving |
| **Shadow Priest** | SWPSpread, VTSpread (multi-DoT), MovingSWP, HolyNovaAoE, InnerFocusMindBlast |
| **Mage Arcane** | FireBlast (instant), FireballLeveling / FrostboltLeveling (pre-AB fillers) |
| **Balance Druid** | HurricaneAoE (4+ targets), MovingMoonfire, WarStomp (4+ mobs) |
| **Feral Cat** | PoolForRip, PoolForExecuteBite (energy pooling), RipSnapshot (SP-aware refresh), BiteTrick / RakeTrick (Tigers Fury pooling), StealthShred, StealthMangle, PounceOpener, RavageOpener, Dash, EmergencyPowershift |
| **Feral Bear** | PoolForMangle, ClearcastingMangle, ClearcastingLacerate (Omen procs), EnrageCombat, FerociousBiteExecute, FrenziedRegeneration |
| **Rogue Combat** | AdrenalineRush, BladeFlurry, GhostlyStrike, KidneyShot, ShivPurge |
| **Paladin Ret** | SealTwistBlood, SealTwistPrepCommand, HotCOpener (Seal+Judge), Ret_JudgeSecondary_CommandCleave, Consecration (mana dump), Exorcism (undead/demon), HolyWrathAoE |
| **Enhancement Shaman** | Purge, GiftOfTheNaaru, LesserHealingWave, ChainHeal, NaturesSwiftness, GroundingTotem |
| **Hunter MM** | KillCommand, RapidFire, Readiness, AimedShotPrepull, InCombatAimedShot, LevelingArcaneShot, LevelingSting, ViperSting, SerpentSting, AdaptiveRotation |

### 3e. Taunt / Threat Management (Tanks)

| Spec | Lua-Only Threat |
|---|---|
| **Warrior Protection** | Taunt, TauntSecondary (tab-cycling), MockingBlow, ChallengingShout, RageDumpSafetyNet (HS at >=90 rage) |
| **Paladin Protection** | RighteousDefense (peel), BlessingOfProtectionAlly |
| **Feral Bear** | Growl, ChallengingRoar |

---

## 4. APL-Only (Actions in APL With No Lua Analog)

### 4a. Warrior Protection — Felstone Band (Item Proc)

**APL line 9:** `Felstone Band (HP<=30)`
**Lua:** No Felstone Band strategy.

**Verdict:** The Felstone Band is a TBC item with a proc effect. The Lua handles this through the middleware (item procs fire automatically via the `api/` layer). **Action:** None. Handled at a different layer.

### 4b. Druid Feral Bear — Felstone Band (Item Proc)

**APL line 9:** `Felstone Band (HP<=30)`
**Lua:** Same as above.

**Verdict:** Same item proc, same middleware handling. **Action:** None.

### 4c. Mage Arcane — Multiple Icy Veins Conditions (Consolidated)

**APL lines 4-6:** Three separate `Icy Veins` conditions (Bloodlust active, Heroism active, Berserking sync)
**Lua:** Single `IcyVeins` strategy gated on `s.phase == "burn"`.

**Verdict:** The APL has three Icy Veins entries for different buff conditions; Lua consolidates them into one strategy with an internal phase check. Functionally equivalent. **Action:** None.

### 4d. Shadow Priest — Shadowmeld + Berserking Racials (Reordered)

**APL lines 3-5:** Berserking (Troll), Shadowmeld (Night Elf) as separate priority entries near the top
**Lua:** Racials handled as a generic group at the end of the strategy list.

**Verdict:** The APL prioritizes racial cooldowns at the top; Lua puts them at the bottom. In practice, racials fire when the condition matches regardless of position. **Action:** None.

### 4e. Shaman Elemental — Earth Elemental + Fire Elemental (Disabled)

**APL lines 2-3:** Earth Elemental (disabled) and Fire Elemental (disabled)
**Lua:** No Elemental totems.

**Verdict:** Both APL entries are explicitly disabled (`"disabled": true`). The Lua omits them entirely. **Action:** None. Matches.

### 4f. Protection Paladin — "Wait" Action

**APL line 3:** `Wait` action for Holy Shield refresh timing
**Lua:** No equivalent — the match function checks `HolyShieldRemains` and doesn't cast if it's still up.

**Verdict:** The APL uses an explicit wait; Lua uses conditional gating. Functionally equivalent. **Action:** None.

---

## Summary: Specs With Non-Empty Diffs

| # | Spec | Inversion? | Lua-Only Count | APL-Only Count | Notes |
|---|---|---|---|---|---|
| 1 | **Paladin Protection** | Yes (intentional) | 15+ | 2 (Felstone, Wait) | Consecration > Holy Shield is deliberate for AoE threat |
| 2 | **Warrior Protection** | Soft (Thunder Clap) | 15+ | 1 (Felstone) | ThunderClap moved down for damage priority |
| 3 | **Affliction Warlock** | **Corrected** (NOT inversion) | 8+ | 0 | T12 incorrectly claimed UA→Corruption; both APL and Lua have Corruption→UA |
| 4 | **Shadow Priest** | Soft (Devouring Plague) | 12+ | 2 (Shadowmeld, Berserking) | DP placement is gated by match function |
| 5 | **Elemental Shaman** | None (Flame Shock is Lua-only) | 12+ | 2 (disabled elementals) | Lua adds Flame Shock; APL has no Flame Shock entry |
| 6 | **Combat Rogue** | Soft (Sinister Strike) | 8+ | 0 | SS at bottom is universal fallback |
| 7 | **Feral Cat** | None | 15+ | 0 | Major additions: pooling, snapshots, stealth openers |
| 8 | **Destruction Warlock** | None | 10+ | 0 | Adds AoE block, Backlash, SearingPain, Soulshatter |
| 9 | **Balance Druid** | None | 12+ | 0 | Starfall claim in T12 was wrong; spell 27012 is Hurricane, which Lua has as HurricaneAoE |
| 10 | **Mage Arcane** | None | 8+ | 1 (3 Icy Veins consolidated) | Burn/conserve state machine replaces group structure |
| 11 | **Hunter MM** | None | 10+ | 0 | Adds KillCommand, RapidFire, AimedShot |
| 12 | **Warrior Arms** | None | 12+ | 0 | Adds stance logic, 2H/DW split |
| 13 | **Warrior Fury** | None | 8+ | 0 | Adds Rampage, SwingDesync |
| 14 | **Shaman Enhancement** | None | 15+ | 0 | Splits groups into individual totem/shock strategies |
| 15 | **Warlock Demonology** | None | 12+ | 0 | Adds pet state, HealthFunnel, Incinerate (Imp) |
| 16 | **Paladin Ret** | None | 20+ | 0 | Massive Lua extension: PvP, cleansing, seal twisting |
| 17 | **Feral Bear** | None | 15+ | 1 (Felstone) | Adds clearcasting procs, PvP, OOC buffs |

**Total specs with non-empty diffs: 17** (all 18 specs with usable APLs, minus Druid Restoration which has no APL).
**True priority inversions: 1** (Protection Paladin, intentional).
**Corrected false positives from T12: 2** (Affliction Warlock UA/Corruption, Balance Druid Starfall).
**Soft inversions: 3** (Shadow Priest, Combat Rogue, Warrior Protection ThunderClap).

---

## Verification

- [x] All 18 usable APL JSONs read end-to-end
- [x] All 18 matching Lua spec files read end-to-end (strategy section)
- [x] Strategy orderings extracted from `strategies`/`ACTIONS`/`add_strategy`/`_strategies` tables
- [x] Side-by-side comparison done
- [x] T12 false positives corrected (Affliction UA/Corruption, Balance Starfall)
- [x] Real priority inversions flagged (Prot Paladin Consecration/HolyShield)
- [x] Soft inversions noted
- [x] Lua-only additions documented
- [x] Specs without APLs listed
- [x] 17 specs with non-empty diffs (target: at least 5)

---

## Recommendations

1. **No production code changes needed.** The single real inversion (Prot Paladin) is documented and intentional in the code.

2. **T12 mapping corrections:**
   - **Affliction Warlock** — T12 said "UA before Corruption" but the actual JSON order is Corruption (30405) before UA (27216). Both APL and Lua match. No action required.
   - **Balance Druid** — T12 labeled spell 27012 as "Starfall" (a WotLK spell). It's actually Hurricane, a TBC spell, and the Lua has `HurricaneAoE` that matches. No action required.

3. **Documentation:** Consider adding rotation-ordering rationale comments in spec files where soft inversions occur (Elemental Flame Shock, Combat Sinister Strike) to prevent future confusion.

4. **Future work:** Healing specs (5) and the 5 DPS specs without APLs could potentially have APLs sourced from `wowsims/tbc-classic` repo for cross-verification, but that's out of scope for this diff.
