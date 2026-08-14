# NEVER-Strategy Triage — WotLK Era (2026-08-09, first inventory)

First run of the behavioral battery against the **WotLK era** after Phase 1
parameterization (`behavioral_audit.lua` now takes an era argument: default
`sylvanas` = the 31 TBC-era files; `wotlk` = the 41 WotLK files including
Death Knight blood/frost/unholy + leveling). This document records the
**baseline** inventory — the starting point for the WotLK triage campaign,
which will mirror the TBC campaign (304 → 105 and counting).

## How to reproduce

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # report-only, exit 0
lua EaxRotations/tests/run_verify_all.lua            # component "behavioral battery (wotlk)" pins 41/0/149
```

## Baseline numbers

| Metric | Value |
|--------|-------|
| Spec files loaded | **41 / 41** (0 load failures) |
| Never-firing strategies | **149** |
| Era flag | `NS.is_wotlk` is a **function** (`function() return true end`) for wotlk — DK specs and `presence_manager` call it as `NS.is_wotlk()` |
| Class ID | `DEATHKNIGHT = 6` added to `CLASS_IDS`; Death Knight profile = `runic_power` resource |
| Spell tables | `NS.DeathKnightSpells = {}` + `NS.DeathKnightConstants` (Frost Fever 55095, Blood Plague 55078, Horn of Winter 57623/57330) |

The TBC battery is untouched: still **31/31 / 0 failures / 100 never-firing**
(verify_all component "behavioral battery" pins that contract).

## Per-spec inventory (149 never-firing)

### deathknight (18)
| Spec | never | Lanes |
|------|-------|-------|
| blood | 7 | DancingRuneWeapon, DeathStrike, IceboundFortitude, MindFreeze, Pestilence, Presence, VampiricBlood |
| frost | 4 | EmpowerRuneWeapon, FrostPresence, MindFreeze, UnbreakableArmor |
| leveling | 5 | DeathCoil, DeathStrike, EmpowerRuneWeapon, Pestilence, RuneStrike |
| unholy | 7 | DeathCoil, DeathCoilDump, EmpowerRuneWeapon, MindFreeze, Pestilence, Presence, SummonGargoyle |

### druid (26)
| Spec | never | Lanes |
|------|-------|-------|
| balance | 0 | — |
| bear | 4 | Lacerate, MangleBear, Maul, SwipeBear |
| cat | 7 | FerociousBite, MangleCat, Rake, Ravage, Rip, SavageRoar, Shred |
| leveling | 14 | CatForm, Claw, DireBearForm, EntanglingRoots, FerociousBite, HealingTouch, Lacerate, MangleBear, MangleCat, Rake, Rejuvenation, Rip, Shred, Swipe |
| resto | 1 | Swiftmend |

### hunter (9)
| Spec | never | Lanes |
|------|-------|-------|
| beast_mastery | 2 | AspectOfTheViper, BestialWrath |
| leveling | 4 | AspectOfTheViper, BestialWrath, MendPet, RevivePet |
| marksmanship | 1 | AspectOfTheViper |
| survival | 2 | AspectOfTheViper, ExplosiveShotProc |

### mage (11)
| Spec | never | Lanes |
|------|-------|-------|
| arcane | 3 | Evocation, ManaGem, PresenceOfMind |
| fire | 1 | FireBlast |
| frost | 1 | ColdSnap |
| leveling | 6 | Blink, ConjureManaGem, Evocation, IceBarrier, ManaShield, Shoot |

### paladin (8)
| Spec | never | Lanes |
|------|-------|-------|
| holy | 0 | — |
| leveling | 0 | — |
| protection | 0 | — |
| retribution | 8 | AvengingWrath, Consecration, CrusaderStrike, DivinePlea, DivineStorm, Exorcism, HammerOfWrath, Judgement |

### priest (3)
| Spec | never | Lanes |
|------|-------|-------|
| discipline | 0 | — |
| holy | 0 | — |
| leveling | 3 | FlashHeal, Shadowform, Shoot |
| shadow | 0 | — |

### rogue (20)
| Spec | never | Lanes |
|------|-------|-------|
| assassination | 4 | Envenom, Mutilate, Rupture, SliceAndDice |
| combat | 5 | BladeFlurry, Eviscerate, KillingSpree, SinisterStrike, SliceAndDice |
| leveling | 8 | Ambush, Eviscerate, FanOfKnives, Gouge, Kick, Rupture, SinisterStrike, SliceAndDice |
| subtlety | 3 | Ambush, Backstab, Eviscerate |

### shaman (11)
| Spec | never | Lanes |
|------|-------|-------|
| elemental | 4 | Bloodlust, ElementalMastery, FireElemental, Thunderstorm |
| enhancement | 4 | Bloodlust, CallOfTheElements, FeralSpirit, LightningBolt |
| leveling | 1 | HealingWave |
| restoration | 2 | ChainHeal, ManaTideTotem |

### warlock (3)
| Spec | never | Lanes |
|------|-------|-------|
| affliction | 0 | — |
| demonology | 0 | — |
| destruction | 0 | — |
| leveling | 3 | DrainLife, LifeTap, Shoot |

### warrior (29)
| Spec | never | Lanes |
|------|-------|-------|
| arms | 18 | BattleStance, BerserkerStance, Bladestorm, Charge, DemoralizingShout, Execute, Hamstring, HeroicStrike, Intercept, MortalStrike, Overpower, Pummel, Rend, Retaliation, ShieldWall, Slam, SweepingStrikes, ThunderClap |
| fury | 5 | Bloodthirst, DeathWish, Execute, Slam, Whirlwind |
| leveling | 6 | Cleave, Execute, HeroicStrike, Pummel, ThunderClap, Whirlwind |
| protection | 6 | Devastate, HeroicStrike, Revenge, ShieldBlock, ShieldSlam, ThunderClap |

## First-pass observations

- **All 41 files load with zero failures** — the DK specs (blood/frost/unholy)
  load through the `DeathKnightSpells` table + `is_wotlk()` function form +
  the rune/presence/interrupt manager stubs preloaded in `load_spec`.
- **Clean specs already**: druid/balance, paladin holy/leveling/protection,
  priest discipline/holy/shadow, warlock affliction/demonology/destruction —
  all 0 never-firing under the same permissive battery.
- **Warrior is the hardest hit (29 lanes)**: stance-based strategies
  (`BattleStance`/`BerserkerStance`), `Charge`/`Intercept` (out-of-combat),
  `Execute` (target_hp gate — the battery has TBC `execute` scenario but the
  WotLK matchers may read different fields), `HeroicStrike` (rage dump
  gates), and `ThunderClap`/`Cleave`/`Whirlwind` (multi-target) — likely a
  mix of (b) OOC/PvP and (c) battery-scenario gaps. The WotLK warrior files
  are a **separate codebase from the TBC arms/fury/protection** — the TBC
  campaign's warrior fixes do not apply.
- **Druid cat (7) + bear (4)**: mirrors the TBC-era shapes (bleed/energy/
  combo gates) — many lanes were cleared in the TBC campaign via scenarios;
  the WotLK files will need the same era-appropriate scenarios.
- **Rogue (20)**: SnD/Eviscerate/Rupture lanes + combo/energy gates — same
  families as the TBC campaign's (c) buckets.
- **DK lanes (18)**: rune-power/resource gating — the battery's rune manager
  stub may not populate rune state; likely a new (c) bucket specific to the
  era ("rune availability not modeled").
- **Retribution (8)**: seal/judgement state (AvengingWrath/DivinePlea/
  DivineStorm/CrusaderStrike/Judgement/Consecration/Exorcism/HammerOfWrath) —
  the TBC campaign cleared retri seal lanes via seal-state scenarios; the
  WotLK retri file has a distinct state surface.
- **Leveling files carry a large share** (14 druid / 8 rogue / 6 warrior /
  6 mage / 5 DK / 4 hunter / 3 priest / 3 warlock / 1 shaman = **50 of 149**)
  — leveling lanes gate on `is_leveling`/`player_level` which the battery
  only sets in the `leveling_execute`-style scenarios.

## Next steps (mirror the TBC campaign)

1. Run the focused-triage pass per spec (probe each never lane's matcher +
   build_state field) and classify (a)/(b)/(c)/(d).
2. Add era-appropriate scenarios: rune-state for DK, stance/OOC for warrior,
   seal-state for retri, leveling/player-level combos for the leveling files.
3. Watch for genuine (d) dead lanes (build_state never assigns a field) —
   the first real catch of the WotLK era.
4. Pin cleared lanes in a `test_wotlk_battery_upgrade_regression.lua`
   mirroring the TBC regression suites.

_Generated from `lua EaxRotations/tests/behavioral_audit.lua wotlk` (2026-08-09)._

---

# Addendum 2026-08-13 — W3.4 mock-tightening, Backdraft decision, eclipse_lunar
(with W3.5 resolution notes 2026-08-14 — residual rows/bullets in §1 updated to RESOLVED)

Final battery wave of the Phase-3 parsing campaign (Wave 3.4). Supersedes the
W3.1-era masking posture: the lenient mock members that hid production
never-lanes are removed or fail-closed, and the battery is re-verified in all
three eras.

## 1. Mock-tightening results (masks removed vs. blocked)

Repo-wide grep audit of `behavioral_audit.lua`'s W3.1-documented mock-only
injections (production = `classes/`, `shared/`, `main_sylvanas.lua`,
`core_sylvanas.lua`):

| Member (battery injection) | Production hits (live reads) | Verdict |
|---|---|---|
| `action:cooldown_remaining()` | none (12 comment-only mentions) | **removed → fail-on-use tripwire** |
| `:cast_safe()` | none in specs (core_sylvanas:2165 reads the REAL `izi.spell` member) | clean — no battery mask ever existed |
| `me:get_energy()` | none | **removed → fail-on-use tripwire** |
| `me:get_combo_points()` | cat_sylvanas:363/366 pcall-guarded tail fallback (real paths precede: combo_points_reader + `context.combo_points`) | **removed → fail-on-use tripwire** |
| `context.bloodlust_ready` / `elemental_mastery_ready` / `fire_elemental_ready` / `mana_tide_ready` / `water_totem_remains` | none (W3.3 moved to `NS.spell_ready` / `NS.get_totem_info`) | **removed** (scenario overrides, bank keys, whitelist) |
| `context.injured_count` | restoration_sod.lua:29 (SoD-era file — never loaded by the sylvanas/wotlk/vanilla battery) | **removed** from battery; SoD read is out-of-era |
| `context.is_boss` | legacy compat reads at arms_wotlk:143 and unholy_wotlk:127 (both kept "for battery mocks") | battery support **removed**; scenarios `arms_retaliation`/`dk_boss` now drive the REAL `context.target_is_boss`; **both legacy reads DELETED (arms W3.4 / unholy W3.5, 2026-08-14)** |
| `me:get_rage()` | arms_wotlk:176, fury_wotlk:102, protection_wotlk:115, leveling_wotlk:93 — formerly SOLE rage source, no real-API fallback | **RESOLVED (2026-08-14, W3.4 residual fixer): all 4 files read `context.rage` / `me:get_power(NS.POWER_RAGE)` first; battery injection removed → fail-on-use tripwire (pinned by test_warrior_wotlk_live_fixes.lua)** |
| `me:get_mana_percentage()` | paladin wotlk holy:69/leveling:67/retri:97/prot:66 (formerly SOLE mana source); priest/shaman/warlock wotlk + affliction_sylvanas + druid middleware (tail fallbacks) | **RESOLVED (2026-08-14, W3.4 residual fixer): paladin 4 files read `context.mana_pct` → `me:mana_pct()` → `NS.unit_mana_pct` first; battery injection removed → fail-on-use tripwire; surviving tail fallbacks sit behind real reads (pinned by test_paladin_wotlk_live_fixes.lua)** |

**Lanes surfaced by tightening: none.** The battery re-ran in all three eras
after the removals with identical never-lists (see §4). Every removed member had
zero live production reads, exactly as the audit table predicted; the two kept
injections were the residuals below, both RESOLVED by the W3.4 residual fixers
and verified by the W3.5 integration wave (2026-08-14).

**Residual production reads — fixer defects, reported for targeted fixes
(NOT re-masked). Both entries below are now RESOLVED (2026-08-14):**

- **Warrior wotlk rage (4 files) — RESOLVED (2026-08-14, W3.4 residual fixer)**:
  the SOLE-source `me:get_rage()` read was replaced with `(context and
  context.rage) or (me and me.get_power and me:get_power(NS.POWER_RAGE)) or 0`
  (arms_wotlk:184, fury_wotlk:107, protection_wotlk:121, leveling_wotlk:98 —
  mirroring bear_wotlk.lua:57-59); the battery's mock-only `get_rage` injection
  is removed → fail-on-use tripwire. Pinned by `test_warrior_wotlk_live_fixes.lua`
  (registered in run_rotation_tests.lua, W3.5).
- **Paladin wotlk mana (4 files) — RESOLVED (2026-08-14, W3.4 residual fixer)**:
  the SOLE-source `me:get_mana_percentage()` read was replaced with `(context
  and context.mana_pct) or (me and me.mana_pct and me:mana_pct()) or
  (NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100` (holy_wotlk:71,
  leveling:69, retribution:99, protection:68 — mirroring arcane_wotlk.lua:61-64);
  the battery's mock-only `get_mana_percentage` injection is removed →
  fail-on-use tripwire. Pinned by `test_paladin_wotlk_live_fixes.lua` (registered
  in run_rotation_tests.lua, W3.5).
- **`context.is_boss` legacy reads** (arms_wotlk:143, unholy_wotlk:127) —
  **RESOLVED (2026-08-14)**: both legacy lines DELETED (arms in W3.4, unholy in
  the W3.5 integration wave) once the battery stopped driving them; the real
  field is `context.target_is_boss` (main_sylvanas.lua:1287), read first in
  both files.
- **restoration_sod.lua:29** reads `context.injured_count` — SoD-era file,
  outside the three battery eras; verify against the SoD engine field set
  separately.

## 2. Backdraft decision (deferred from the W3.3 warlock fixer)

Backdraft (55379/55380) is absent from the wotlk spell-index bridge
(`shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua` — 0 hits; the
bridge is extracted from the 2.5.5-client DBC, and Backdraft is a WotLK
talent). Any wotlk file referencing it fails `run_wotlk_audit_tests.lua` —
documented evidence (17962 Conflagrate / 47811 Immolate are present; 55379/
55380 are not). The wotlk destruction rotation (`destruction_wotlk.lua`) does
not track the Backdraft proc, and the pinned wowsims APL fixture
(`tools/evidence/apl/wl_destro_wotlk.apl.json`, 10 lines) does not model it
either — the rotation is conformant as pinned.

**Classification: NOT a never-lane — a missing mechanic (documented
limitation).** There is no lane to classify; the scorecard already reflects the
decision (wotlk/destruction: 6 strategies, 0 never, APL-conformant, S+). If
Backdraft tracking is ever added, it must first land in the bridge / wotlk
audit allowlist.

## 3. eclipse_lunar state-field resolution (balance_wotlk.lua)

The state-field audit flagged `balance_wotlk.lua:71 eclipse_lunar` (1 write
site, no read). Resolution: the field **is** meaningful — the pinned wowsims
APL (`druid_balance_wotlk.apl.json`) gates Starfire on LUNAR eclipse **48518**
and Wrath on SOLAR eclipse **48517**. `balance_wotlk.lua` now reads
`eclipse_lunar` in the Starfire gate (`OR { eclipse_lunar truthy, eclipse_solar
falsy }` + mana >= 15) — an explicit lunar branch mirroring the APL's 48518
gate, with the not-solar fallback preserving the no-eclipse filler (behavior
unchanged). New battery scenario `balance_eclipse_lunar`
(`buff_remains_map { [48518] = 5 }`) proves the lunar-phase lane fires when
`eclipse_lunar` is up — the mirror of the solar-phase Wrath pin — plus two new
unit tests in `test_balance_wotlk_dsl_priority.lua`.

**Interpretation note on the wave brief's "lunar-phase Wrath":** the
lunar-phase spell is **Starfire**, not Wrath — solar eclipse (48517) buffs
Wrath, lunar eclipse (48518) buffs Starfire (WotLK mechanic, confirmed by the
pinned APL). "Lunar-phase Wrath fires when eclipse_lunar is up" was therefore
implemented as "the lunar-phase lane (Starfire) fires when eclipse_lunar is
up"; Wrath remains solar-only (verified: Wrath does not match during lunar).

## 4. Battery before / after (all three eras, verbatim)

BEFORE (2026-08-13 baseline, pre-tightening):

```
TBC     never=16: FaerieFirePull, FeralChargePull, PrePullEnrage, RakeSnapshot,
                  RipSnapshot, TrackHumanoids, TravelForm, ManaGemConjure (fire),
                  ManaGemConjure (frost), Ret_SealMartyr_Primary,
                  EncounterReactions, MountedProtection, DispelMagic,
                  ExposeArmor, Sap, FireNovaReplacement   (a=1 b=10 c=5 d=0)
WotLK   never=0
Vanilla never=13: FaerieFirePull, PrePullEnrage, ManaGemConjure x2,
                  ConjureManaGem, EncounterReactions, MountedProtection, Fade,
                  MagmaTotem, WrathOfAirTotem, FireNovaReplacement,
                  GraceOfAirTotemTwist, RacialArcaneTorrent
```

AFTER (mock-tightening + eclipse_lunar fix + balance_eclipse_lunar scenario):

```
TBC     never=16 — identical lane list (a=1 b=10 c=5 d=0)
WotLK   never=0
Vanilla never=13 — identical lane list
```

No reclassifications were required: no lane surfaced, so the a/b/c/d pins and
the `LANE_CLASS` entries in `tools/spec_scorecard.lua` are untouched. The only
new pins are the two lunar-eclipse tests and the `balance_eclipse_lunar`
battery scenario (lane already fired pre-scenario via the not-solar branch;
the scenario makes the lunar branch explicit and non-vacuous).

