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


---

# Addendum 2026-09-06 — Warrior WotLK era-appropriate scenario suites (W6.1)

The WotLK battery already enforced `never == 0` for all 41 specs (see the
COMPLETE note at run_verify_all.lua), but the warrior `_wotlk.lua` files'
**decision behavior** was only statically pinned (priority order + the arms
match gates in `test_arms_wotlk_dsl_priority.lua`). Fury, protection and the
leveling file had no era-appropriate "which lane fires under which state"
coverage. This addendum records the mirror-of-TBC-campaign pass:

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests /
run_leveling_tests as applicable; rotation battery 524 -> 527 suites)

| Suite | File under test | Era-appropriate lanes pinned |
|---|---|---|
| `test_fury_wotlk_strategies.lua` | `fury_wotlk.lua` | Berserker-stance dance-back (in-combat only, no-op when already Berserker / OOC); Execute <20% + 15 rage; Bloodthirst 30-rage CD gate; Whirlwind **Berserker-only** (blocked in Battle, WotLK); **Bloodsurge-gated Slam** (no filler hard-cast without the proc); Pummel Berserker-only interrupt; Death Wish long-CD policy suppression; Battle Shout maintenance |
| `test_protection_wotlk_strategies.lua` | `protection_wotlk.lua` | Last Stand <30% hp emergency band; swing-**queued** Heroic Strike (blocked when the auto is >1 s out); need-gated Shield Block (fires under 70% hp or 2+ targets, held otherwise so it can't starve Shield Slam/Devastate); Berserker dance for the Berserker-only Pummel (not when nothing to interrupt); Shield Slam/Revenge/ThunderClap/Devastate CD+rage gates |
| `test_warrior_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | OOC-only Battle Stance/Battle Shout; Charge 8-25 yd range (melee / >25 yd / in-combat blocked); proc-gated Victory Rush + dodge-window Overpower (Battle-stance-only); Execute range; hit-volume ThunderClap/Whirlwind (self 8 yd) + Cleave (target 8 yd); Rend refresh window; Heroic Strike dump; Pummel interrupt |

All three load the real `_wotlk.lua` file against a mock NS (same harness shape
as the TBC/vanilla strategy suites) and pin both the fire and the don't-fire
side of each gate. Two era mechanics exercised here had no prior assertion:
the WotLK queued-swing HS/Cleave gates (`swing_time_until <= 1 s`) and the
stance-dance lanes that keep Berserker-only abilities reachable from the
default Battle/Defensive stances.

## Gate status after the pass

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 41 specs / 0 load failures / 0 never
lua EaxRotations/tests/run_rotation_tests.lua        # 527 suites / 0 failed
lua EaxRotations/tests/run_wotlk_tests.lua           # 48 suites / 0 failed
lua EaxRotations/tests/run_verify_all.lua            # all green (scorecard regenerated: suites 527)
```

No `LANE_CLASS` / never pins changed (the battery never-count was already 0);
the scorecard count columns were refreshed by the documented regeneration.


---

# Addendum 2026-09-06 — Death Knight WotLK era-appropriate scenario suites + rune-gate audit (W6.2)

The warrior pass (above) left the four DK `_wotlk.lua` files partially pinned:
blood had only disease/Death-Strike basics, frost/unholy/leveling had static
priority-order checks plus a handful of live-fix pins, and **no suite drove the
real rune_manager** — the frost `Obliterate` gate was asserted against a
wrong-shaped rune stub. This addendum records the DK era-content pass:

## Rune-state verdict (survey claim settled)

The claim that the rune-state manager "does not model rune state" is **refuted
as an architecture defect**: `shared/rune_manager_sylvanas.lua` is a thin
query layer over the engine's per-slot API (`get_rune_type` / `get_rune_info`
per slot 1..6), and era-correct recharge (slot `ready=false` drops the ready
count) and death-rune conversion (slot type 4 counts toward `ready.death`)
flow through it. The refutation exercise, however, exposed a **genuine
era-correctness bug** in `frost_wotlk.lua`: the Obliterate gate computed
`frost >= 1 and unholy >= 1` by adding the same death-rune pool into both
requirements, so a **lone ready death rune (0 frost, 0 unholy) double-counted
one slot and fired an uncastable Obliterate**. Fixed to require `slots >= 2`
across the frost+unholy+death families (2026-09-06); verified at every
boundary (1 frost + 1 unholy, 1 frost + 1 death, 2 death, lone death blocked).

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests /
run_leveling_tests as applicable; rotation battery 527 -> 531 suites)

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_deathknight_blood_wotlk_strategies.lua` | `blood_wotlk.lua` | Icebound Fortitude <40% / Vampiric Blood <50% hp bands; Horn of Winter upkeep; Dancing Rune Weapon commit gate (combat + target hp + 60 RP + long-CD); disease maintenance (Icy Touch / Plague Strike refresh <3s); Pestilence refresh (one disease <3s, both up); Death Strike disease-uptime guard (blocked when Frost Fever down or <3s); unconditional Heart Strike; Death Coil 40-RP spend |
| `test_frost_deathknight_wotlk_strategies.lua` | `frost_wotlk.lua` | **Real rune_manager driven through the engine slot API**: Obliterate slot accounting (incl. the lone-death-rune fix), Blood Strike blood-family rune gate; Killing Machine Frost Strike (window + 40 RP); plain 40-RP Frost Strike; Rime proc + 3-target AoE Howling Blast; Horn of Winter; Unbreakable Armor (buff/CD/long-CD/combat); Empower Rune Weapon (all-runes-recharging only); Frost Presence auto-switch |
| `test_deathknight_unholy_wotlk_strategies.lua` | `unholy_wotlk.lua` | Horn of Winter / Bone Shield upkeep; Raise Dead (pet absent only); Summon Gargoyle (boss + 60 RP + long-CD); Empower Rune Weapon via the real rune snapshot (0-ready only); disease refresh; Pestilence pack spread (2 targets, both diseases); Death Coil 100 / DeathCoilDump 40 RP gates; Death and Decay 2-target AoE; Scourge Strike (both diseases); unconditional Blood Strike; Ghoul Gnaw (casting target) / Ghoul Leap (8 yd); Unholy Presence auto-switch |
| `test_deathknight_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | Mind Freeze interrupt (combat + enemy cast); Blood Presence / Horn of Winter upkeep; disease refresh (combat-gated); hit-volume AoE gates (Pestilence spread 2, Death and Decay 3, Blood Boil self-2, Howling Blast 2); Death Strike <80% hp band; the in-combat-only strike core (Obliterate / Scourge Strike / Heart Strike / Blood Strike); Death Coil 40-RP dump; Empower Rune Weapon (CD + long-CD + combat) |

All four load the real `_wotlk.lua` file against a mock NS (same harness shape
as the warrior/TBC strategy suites), and the frost/unholy suites drive the
**real** `rune_manager_sylvanas` against a mutable 6-slot engine model so the
rune gates are asserted against genuine slot counts rather than a stub.

## Gate status after the pass

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 41 specs / 0 load failures / 0 never (DK 4 specs 0/0)
lua EaxRotations/tests/run_rotation_tests.lua        # 531 suites / 0 failed
lua EaxRotations/tests/run_wotlk_tests.lua           # 52 suites / 0 failed
lua EaxRotations/tests/run_leveling_tests.lua        # 34 suites / 0 failed
lua EaxRotations/tests/run_verify_all.lua            # all green (scorecard regenerated: suites 531)
```

No `LANE_CLASS` / never pins changed (the battery never-count was already 0);
the scorecard count columns were refreshed by the documented regeneration.


---

# Addendum 2026-09-06 — Rogue WotLK era-appropriate scenario suites (W6.3)

Mirror of the DK pass (W6.2). The four rogue `_wotlk.lua` files' decision
lanes were already pinned **gate-both-sides** by the dsl_priority suites and a
handful of real-read lanes by `test_rogue_wotlk_live_fixes.lua`, but the
dsl_priority suites mutate `build_state` output **post-hoc** (`state.snd_remains
= 1` after one zero-state build), so no suite drove the real state plumbing —
`ctx.energy`/`ctx.combo_points`, `NS.buff_remains`/`buff_up`, `debuff_remains`,
`get_debuff_stacks`, the equipped-item dagger check through the real
`dagger_set`, real `NS.cooldown_remains`, `target:is_casting`, and the real
hit-volume gate. This addendum records the era-appropriate real-read pass:

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests /
run_leveling_tests as applicable; rotation battery 531 -> 535 suites)

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_rogue_assassination_wotlk_strategies.lua` | `assassination_wotlk.lua` | Kick (enemy cast, real `target:is_casting`); Slice and Dice refresh <3s at >=1 CP (real `buff_remains`); Rupture refresh <3s at >=1 CP (real `debuff_remains`); Hunger for Blood upkeep (buff-down only); Tricks of the Trade <=50-energy APL gate (real `ctx.energy`); **Envenom commit**: >=4 CP + >=3 Deadly Poison stacks (real `get_debuff_stacks`) + buff-down-or-energy>=85 refresh rule incl. the 84/85 boundary; Mutilate >=60-energy + both-hand dagger gate through the real dagger_set map |
| `test_rogue_combat_wotlk_strategies.lua` | `combat_wotlk.lua` | Kick; Slice and Dice <=1s refresh boundary (1.0 fires, 1.01 held) at >=1 CP; Eviscerate >=4 CP; **Blade Flurry APL alignment** (real `cooldown_remains` on 13877 + SnD-up + >=2 enemies + long-CD, incl. single-target / no-SnD / on-CD / OOC / long-CD don't-fires); Killing Spree <=50-energy APL gate at >=1 CP (incl. 51-energy, on-CD, OOC, long-CD don't-fires); Sinister Strike >=45 energy |
| `test_rogue_subtlety_wotlk_strategies.lua` | `subtlety_wotlk.lua` | Kick; Premeditation unconditional opener (fires even OOC); Shadow Dance upkeep (buff-down only); **Ambush**: Shadow Dance up + strict behind + >=60 energy (incl. dance-down / in-front / 59-energy don't-fires); Eviscerate >=4 CP; **Backstab**: behind + dagger-eligible + >=60 energy (incl. in-front / no-dagger / 59-energy don't-fires) |
| `test_rogue_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | Stealth enter (OOC + not stealthed); Stealth Ambush opener (>=60 energy); Kick (enemy cast + >=25 energy); Slice and Dice (combat + <3s + >=1 CP); **Fan of Knives** (>=50 energy + 3 targets via the real hit gate incl. 2-target don't-fire); **Rupture** (>=4 CP + bleed <3s + target >25% hp incl. the 25%-hp don't-fire); Gouge / Eviscerate / Sinister Strike combat + energy/CP gates incl. OOC don't-fires |

All four load the real `_wotlk.lua` file against a mock NS and assert through
`build_state` (the real read path), so each assert proves the wiring from the
mocked engine API to the DSL state field as well as the gate itself.

## File-inventory note (deliverable motifs absent from the WotLK files)

The pass pinned every lane the WotLK files actually contain. Requested motifs
with **no lane in these files** were not invented: Expose Armor is absent from
`assassination_wotlk.lua` (no armor-reduction lane); Adrenaline Rush and Hemo
are absent from `combat_wotlk.lua` / `subtlety_wotlk.lua` (combat has no
positional strike; the finisher is Eviscerate in both). The generic
"sinister/backstab by position" motif resolves to: combat = energy-gated
Sinister Strike (no position gate), subtlety = behind+dagger Backstab.

## Gate status after the pass

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 41 specs / 0 load failures / 0 never (rogue 4 specs 0/0)
lua EaxRotations/tests/run_rotation_tests.lua        # 535 suites / 0 failed
lua EaxRotations/tests/run_wotlk_tests.lua           # 56 suites / 0 failed
lua EaxRotations/tests/run_leveling_tests.lua        # 35 suites / 0 failed
lua EaxRotations/tests/run_verify_all.lua            # all green (scorecard regenerated: suites 535)
```

No `LANE_CLASS` / never pins changed (the battery never-count was already 0);
the scorecard count columns were refreshed by the documented regeneration.


---

# Addendum 2026-09-06 — Hunter WotLK era-appropriate scenario suites (W6.4)

The three hunter `_wotlk.lua` files' decision lanes were already pinned
**gate-both-sides** by the dsl_priority suites, but those suites mutate
`build_state` output post-hoc, so no suite exercised the real read plumbing.
This addendum records the era-appropriate real-read pass:

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests;
rotation battery 535 -> 545 suites across the hunter+druid+paladin pass)

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_hunter_beast_mastery_wotlk_strategies.lua` | `beast_mastery_wotlk.lua` | Aspect of the Viper <10% mana / Dragonhawk >=30% upkeep (real `buff_up` + `ctx.mana_pct`); Hunters Mark <3s refresh incl. the 2.9/3.0 boundary; Bestial Wrath in-combat + real `NS.cooldown_remains` on 19574 (incl. on-CD); Kill Shot <20% execute band; Explosive Trap re-drop <1s; in-combat Kill Command; Serpent Sting <3s + TTD >6s (incl. the short-lived-target don't-fire); Aimed/Steady in-combat; MultiShot 2-target; Arcane Shot >=20% mana |
| `test_hunter_marksmanship_wotlk_strategies.lua` | `marksmanship_wotlk.lua` | Aspects; Silencing Shot in-combat use; Hunters Mark; Kill Shot; Serpent Sting <3s refresh with **no TTD gate** (MM refreshes on short-lived targets — pinned as different from BM/SV); Explosive Trap; Chimera Shot / Aimed / Steady in-combat; MultiShot 2-target; Arcane Shot mana |
| `test_hunter_survival_wotlk_strategies.lua` | `survival_wotlk.lua` | Aspects; Hunters Mark; Kill Shot; **Lock and Load window split**: ExplosiveShotProc fires during the proc (real `buff_up` on 56344) and the plain ExplosiveShot lane is excluded during it (fires outside, blocked in-window, OOC-blocked both); Explosive Trap; Serpent Sting with the >6s TTD gate; Black Arrow <3s upkeep; Aimed/Multi/Steady core |

All three load the real `_wotlk.lua` file against a mock NS and assert through
`build_state` (the real read path), proving the engine-API-to-DSL-state wiring
as well as each gate. The MM-vs-BM/SV Serpent Sting divergence (no TTD gate)
is explicitly pinned so a future copy-paste can't silently unify them.

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 41 specs / 0 load failures / 0 never (hunter 4 specs 0/0)
lua EaxRotations/tests/run_rotation_tests.lua        # 545 suites / 0 failed (final, all classes)
lua EaxRotations/tests/run_wotlk_tests.lua           # 66 suites / 0 failed (final, all classes)
lua EaxRotations/tests/run_verify_all.lua            # all green (scorecard regenerated: suites 545)
```


---

# Addendum 2026-09-06 — Druid WotLK era-appropriate scenario suites (W6.5)

The earlier survey flagged druid **cat and bear as having zero behavioral
coverage**; verification confirmed that plus balance/resto having only
synthetic post-hoc-state dsl_priority coverage. This addendum records the
real-read pass for all four:

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests;
rotation battery 535 -> 545 suites across the hunter+druid+paladin pass)

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_druid_cat_wotlk_strategies.lua` | `cat_wotlk.lua` | **First behavioral pins** (was zero): Faerie Fire <3s upkeep; Ravage stealth opener (stealth + behind + >=60 energy); Tiger's Fury CD + energy-fit (<=40) + 5-CP finisher protection; Berserk below 5 CP; Savage Roar / Rip 5-CP finisher refresh incl. the 4-CP don't-fire; Ferocious Bite execute-band (<25% hp) dump + healthy-window (Rip AND Roar >=3s) + both banked-CP don't-fires; Mangle bleed-vuln refresh >=45 energy; Rake refresh >=40 energy; behind-gated Shred >=50 energy; Omen-of-Clarity ShredOmen (proc + behind + <5 CP) |
| `test_druid_bear_wotlk_strategies.lua` | `bear_wotlk.lua` | **First behavioral pins** (was zero): Lacerate stack refresh <3s at >=15 rage (incl. 14-rage / fresh / OOC don't-fires); Swipe 2-target AoE at >=15 rage; Mangle bleed-vuln refresh; Faerie Fire upkeep (no rage gate); Maul >=30-rage dump; Frenzied Regeneration panic heal (<=40% hp + >=10 rage + real spell_ready on 26999) |
| `test_druid_balance_wotlk_strategies.lua` | `balance_wotlk.lua` | Moonkin form in-combat upkeep; Starfall single-target-legal (long-CD consent + real spell_ready on 48505); Moonfire / Insect Swarm <3s DoT upkeep; **the Eclipse state machine through real buff reads**: Wrath fires during solar (48517), blocked in no-Eclipse and lunar; Starfire fires during lunar (48518) AND as the no-Eclipse filler, blocked during solar; both gated at >=15% mana |
| `test_druid_resto_wotlk_strategies.lua` | `resto_wotlk.lua` | Real friendly-unit model (ctx.lowest.unit + buff_remains/buff_stacks on the HoT ids): Wild Growth on 2+ injured allies >=25% mana; Swiftmend HoT-consumption rule (Rejuv OR Regrowth up) at <=50% hp; **Lifebloom 3-stack roll discipline** (free roll <3s below 3 stacks; at 3 stacks only inside the 1.2s window — 2s-left don't-fire pinned); Rejuvenation <=88% / Regrowth <=70% triage thresholds; Nourish <=60% direct heal; Innervate <=30% mana |

All four load the real `_wotlk.lua` file against a mock NS and assert through
`build_state` (the real read path): combo/energy/rage/mana via ctx, debuff/
buff remains via NS aura reads, procs (Omen / Eclipse) via `buff_up`, charges
(Lifebloom stacks) via `buff_stacks`, and CD gates via real `NS.spell_ready`.

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 41 specs / 0 load failures / 0 never (druid 5 specs 0/0)
lua EaxRotations/tests/run_rotation_tests.lua        # 545 suites / 0 failed (final, all classes)
lua EaxRotations/tests/run_wotlk_tests.lua           # 66 suites / 0 failed (final, all classes)
lua EaxRotations/tests/run_verify_all.lua            # all green (scorecard regenerated: suites 545)
```


---

# Addendum 2026-09-06 — Paladin WotLK era-appropriate scenario suites (W6.6)

The earlier survey flagged retribution as having zero behavioral coverage;
verification confirmed that (static priority-only), with protection/holy
synthetic-pinned. This addendum records the real-read pass:

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests;
rotation battery 535 -> 545 suites across the hunter+druid+paladin pass)

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_paladin_retribution_wotlk_strategies.lua` | `retribution_wotlk.lua` | **First behavioral pins** (was zero): seal choice by pack size (SoV single-target / SoC 2+; both blocked while any seal is up); Divine Plea <40% mana recovery (buff-up + on-CD don't-fires); Avenging Wrath burst (real `cooldown_remains` on 31884 + long-CD consent + OOC); Hammer of Wrath <20% execute; the Judgement / Crusader Strike / Divine Storm CD cycle (real CD reads on 20271/35395/53385); Exorcism Art-of-War-proc-only (real `buff_up` on 59578, incl. proc-on-CD); Consecration 2-target hit-volume gate at >=30% mana (real CD on 48819); **the SoV<->SoC seal-switch** (drop SoV when adds arrive, drop SoC back single-target; never when the active seal matches; anti-loop clock advanced between fire scenarios) |
| `test_paladin_protection_wotlk_strategies.lua` | `protection_wotlk.lua` | In-combat tank strike core (Avenger's Shield / Shield of Righteousness / Hammer of the Righteous / Judgement incl. OOC don't-fires); Consecration <3s refresh at >=25% mana; Righteous Fury buff-down upkeep through the real 3s anti-loop throttle; **Holy Shield proactive charge management** (fires buff-down / at the 2-charge floor / at 0 charges; held with 3 charges; real `spell_ready` on 48927; OOC-blocked) |
| `test_paladin_holy_wotlk_strategies.lua` | `holy_wotlk.lua` | **Beacon of Light on the dedicated tank member** (real party_members + get_group_role="tank" resolution — never the lowest-HP ally); self-only Sacred Shield upkeep; Holy Shock <80% / Holy Light <50% (>=30% mana) / Flash of Light <70% (>=20% mana) triage to the lowest-HP friendly, all with boundary don't-fires |

All three load the real `_wotlk.lua` file against a mock NS and assert through
`build_state` (the real read path): seals/procs/auras via `buff_up`, CDs via
real `NS.cooldown_remains` / `NS.spell_ready`, Holy Shield charges via
`buff_points`, Consecration via the real hit-volume gate, and heals via the
friendly-unit model.

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 41 specs / 0 load failures / 0 never (paladin 4 specs 0/0)
lua EaxRotations/tests/run_rotation_tests.lua        # 545 suites / 0 failed (final, all classes)
lua EaxRotations/tests/run_wotlk_tests.lua           # 66 suites / 0 failed (final, all classes)
lua EaxRotations/tests/run_verify_all.lua            # all green (scorecard regenerated: suites 545)
```

---

# Addendum 2026-09-06 — Mage WotLK era-appropriate scenario suites (W6.7)

The four-class closing pass (mage/warlock/shaman/priest). Mage coverage was sparse
live-fix pins (DoT/debuff families, Hot Streak) plus synthetic dsl_priority
matches; this addendum records the real-read pass over the three spec files and
the leveling file.

## New behavioral suites (registered in run_rotation_tests / run_wotlk_tests /
run_leveling_tests; rotation battery 545 -> 561 across this four-class pass)

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_mage_arcane_wotlk_strategies.lua` | `arcane_wotlk.lua` | Arcane Blast 4-stack dump cycle (4-stack Barrage fires / 1-stack holds), Missile Barrage proc-consumer Arcane Missiles (proc fires, no-proc holds), mana-gem / Evocation <20% recovery band, Counterspell interrupt through the real `target:is_casting` read, Arcane Intellect/Mage Armor upkeep, Arcane Explosion hit-volume |
| `test_mage_fire_wotlk_strategies.lua` | `fire_wotlk.lua` | Counterspell interrupt; Combustion long-CD (180s) consent incl. refusal; Improved-Scorch debuff refresh boundary (4s fires / 4.1s holds); **Hot Streak Pyroblast proc lane** (real 44448 buff read — proc fires, no-proc holds, OOC-blocked); Living Bomb with the TTD >12 payback gate (13 fires / 12 holds); FireBlast TTD-anticipation vs the resolved Scorch cast time; ScorchFinal execute-speed filler at TTD<=4; Fireball filler |
| `test_mage_frost_wotlk_strategies.lua` | `frost_wotlk.lua` | Counterspell; **Fingers of Frost Ice Lance proc lane** (real 44545 read, proc fires / no-proc holds), Deep Freeze (frozen target + ready), Water Elemental pet-absent summon with long-CD consent, Frostbolt/Ice Lance filler + mana gates, Ice Barrier emergency band |
| `test_mage_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | Counterspell; Arcane Intellect/Mage Armor upkeep; Ice Barrier <50% / Mana Shield <40% emergency absorbs (buff-up + OOC don't-fires); Evocation <20% / Blink <30% emergencies; OOC Mana Gem stock; **the AoE trio through the real hit-volume gate** (Cone of Cold 2 / Arcane Explosion 3 / Blizzard 4, each with volume don't-fires); Water Elemental (pet-down + 180s long-CD consent + OOC); Living Bomb <3s refresh; the mana-gated nuke ladder (Pyroblast 20 / Fireball-Frostbolt-FrostfireBolt 15 / Barrage 20 / Missiles 25 / FireBlast 10 / IceLance 5 / DeepFreeze 10) and the <10% Shoot OOM fallback |

All four load the real `_wotlk.lua` file against a mock NS and assert through
`build_state` (the real read path): procs/auras via `buff_up`, debuff refresh via
`debuff_remains`, CDs via `NS.spell_ready`/`NS.should_use_long_cd`, interrupts via
the real `target:is_casting`, AoE via the real hit-volume gate
(`ctx._aoe_hit_count`), and the leveling pet state through the real pet_manager.

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 0 never (mage specs 0/0)
```


---

# Addendum 2026-09-06 — Warlock WotLK era-appropriate scenario suites + Backdraft implementation (W6.8)

Warlock coverage before this pass was synthetic dsl_priority matches only. This
addendum records (a) the real-read pass over affliction/demonology/destruction
and the leveling file, and (b) the **Backdraft implementation** the roadmap had
tracked as untracked.

## Backdraft implementation (step 3 of the deliverable)

Conflagrate grants the caster the Backdraft haste aura (reduces the cast time
and GCD of the next three Destruction spells). Implementation notes:

- **Spell-index ids corrected during the pass**: the roadmap/triage doc cited
  55379/55380, but those are *Skyflare Swiftness* (a jewelcrafting meta-gem
  haste proc), verified against wowhead and wotlkdb.com (3.3.5a). The real
  Conflagrate-granted Backdraft auras are per talent rank **54274 (-10%) /
  54276 (-20%) / 54277 (-30%)**. The three real ids were added to
  `shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua` (the index bridge
  carries a manual-entry note documenting the 55379/55380 correction); the
  wrong numbers never entered the spec — they appeared only in the earlier doc.
- **Rotation wiring** in `classes/warlock/destruction_wotlk.lua`: a new
  `SoulFireBackdraft` consumer lane (in combat + `has_backdraft` buff read via
  `NS.buff_up` over 54274/54276/54277 + mana >= 30) sits above Incinerate and
  consumes the haste window on Soul Fire's long cast — mirroring the repo's
  proc-consumer convention (e.g. the TBC BacklashShadowBolt lane). The plain
  SoulFire lane below Incinerate remains for non-Backdraft builds. WotLK
  destruction has no Immolate-family haste interaction; the proc is cast-time
  haste only, so consuming it on the longest cast in the kit is the
  era-appropriate use.
- **WotLK spell-id audit**: the spell index passes its sortedness/reference
  audit with the three additions (run via `run_rotation_tests.lua`, which
  includes the WotLK id-audit suite).

## New behavioral suites

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_warlock_affliction_wotlk_strategies.lua` | `affliction_wotlk.lua` | Haunt / Corruption / UA / CoA refresh boundaries through the real `debuff_remains` read (2.9s fires / 3.0s holds); DrainSoul <25% target-hp execute band (24 fires / 25 holds); ShadowBolt >=20% mana filler; the appended LifeTap sustain (in combat + mana <40 + hp >50, incl. both floors). (Soul Swap: absent from this file — the WotLK affliction kit here is the DoT-priority + drain core, documented not invented.) |
| `test_warlock_demonology_wotlk_strategies.lua` | `demonology_wotlk.lua` | **Metamorphosis long-CD lane** (in combat + aura down + 180s consent, incl. transformed / OOC / refused don't-fires); Corruption / Immolate <3s refresh; SoulFire 30 / ShadowBolt 20 mana fillers; LifeTap (mana <65 + hp >55 + combat) |
| `test_warlock_destruction_wotlk_strategies.lua` | `destruction_wotlk.lua` | Conflagrate (Immolate-live gate, incl. sliver-remaining fire); Immolate refresh at the 2.0s cast-window boundary; ChaosBolt 20 / Incinerate 20 fillers; **the Backdraft pin** — proc-up SoulFireBackdraft fires through the real 54277 aura read (also at the 30-mana boundary) and holds with no proc / 29 mana / OOC, while the plain SoulFire lane stays available out-of-window; LifeTap (mana <30 + hp >50) |
| `test_warlock_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | SpellLock interrupt through the real helper read (cast / idle / 4-mana don't-fires); SummonPet OOC preference ladder (missing-or-dead pet fires, alive pet holds); OOC Soulstone/Healthstone/FelArmor upkeep (incl. the Demon-Armor-up hold); Haunt/UA/Corruption/Immolate/CoA <3s refresh with OOC holds; **Seed of Corruption / Rain of Fire through the real hit-volume gate** (3 targets fire / 2 hold, mana floors); Conflagrate's >3s Immolate gate; DrainSoul 25% / DrainLife 60% / LifeTap (mana <30 + hp >40) bands; the mana-gated filler ladder + <10% Shoot OOM fallback |

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 0 never (warlock specs 0/0)
```


---

# Addendum 2026-09-06 — Shaman WotLK era-appropriate scenario suites (W6.9)

Shaman coverage before this pass was synthetic dsl_priority matches only. This
addendum records the real-read pass over elemental/enhancement/restoration and
the leveling file.

## New behavioral suites

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_shaman_elemental_wotlk_strategies.lua` | `elemental_wotlk.lua` | WindShear + WotLK EarthShock (kick removed 3.0.2 — instant-damage while the target casts) via the real `target:is_casting`; **CD windows through the real `NS.spell_ready`** for Bloodlust / Fire Elemental / Elemental Mastery (each with the on-CD hold); Totem of Wrath drop (aura down + air slot free via real `NS.get_totem_info`, incl. occupied-slot hold); Searing Totem (in combat + no Fire Elemental + fire slot free); FlameShock <3s refresh (2.9/3.0 boundary); **LavaBurst's guaranteed-crit pairing** — fires while Flame Shock is live at >=1s, holds with the debuff down (no crit) or at <1s; Chain Lightning 2-target cleave; Thunderstorm <50% mana return; Lightning Bolt filler |
| `test_shaman_enhancement_wotlk_strategies.lua` | `enhancement_wotlk.lua` | Feral Spirit / Bloodlust (in combat + real spell_ready); **Maelstrom Weapon Lightning Bolt proc lane** (real 53817 stack read — 5+ fires, 4/no-proc holds); Stormstrike / EarthShock / LavaLash ungated fillers pinned as always-match; FlameShock <3s; Call of the Elements water-slot re-drop; Magma Totem 2-target + fire-slot gate; **Fire Nova's WotLK fire-totem requirement** (2+ enemies AND an active fire totem — holds with the slot empty); Lightning Shield aura-down upkeep; Shamanistic Rage (in combat + mana <40 + real 120s-CD read); **the OOC weapon-imbue window** (Windfury/Flametongue on the ~29.8-min freshness comparison — expired window fires, fresh window holds via the clock, in-combat and 4-mana holds) |
| `test_shaman_restoration_wotlk_strategies.lua` | `restoration_wotlk.lua` | Friendly-unit model (context.lowest.unit) like the priest/resto-druid passes: Mana Tide (real 300s-CD read + mana <30); **charge-aware Earth Shield refresh** (down applies / 1 charge refreshes / 2+ holds / unreadable-charges fails closed); Riptide HoT <3s refresh (2.9/3.0); Chain Heal (2+ injured via ctx.party_injured_count + lowest <85% + mana); LHW <90% / Healing Wave <70% triage with mana gates; Water Shield mana sustain (in combat + down + mana <50 + ready) |
| `test_shaman_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | WindShear interrupt; Healing Wave <50% hp emergency band; Lightning Shield aura-down upkeep; Searing Totem (1+ enemies + fire slot) / Magma Totem (3+ enemies + fire slot) sharing the slot-occupancy gate; Chain Lightning 2-target cleave; FlameShock <3s + LavaBurst Flame-Shock-live pairing; the Stormstrike 10 / EarthShock 15 / LightningBolt 15 mana-gated filler ladder with OOC holds |

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 0 never (shaman specs 0/0)
```


---

# Addendum 2026-09-06 — Priest WotLK era-appropriate scenario suites (W6.10)

Priest coverage before this pass was sparse live-fix pins (Penance/PoM trainer
ladders, define_action_for_class shadowing) plus synthetic dsl_priority matches.
This addendum records the real-read pass over shadow/discipline/holy and the
leveling file — the last WotLK classes without era suites.

## New behavioral suites

| Suite | File under test | Era-appropriate lanes pinned (both fire + don't-fire sides) |
|---|---|---|
| `test_priest_shadow_wotlk_strategies.lua` | `shadow_wotlk.lua` | Silence interrupt; VT / SW:P / DP <3s refresh (2.9/3.0) through the real `debuff_remains`; **the Mind Flay channel-interaction gates through the real mf_tick_compute** — the DoT lanes hold during a fresh MF channel (0-1 ticks never clips), clip MF at 2 ticks when their debuff is inside the refresh window or Mind Blast is ready, and hold at 2 ticks when nothing is urgent; Mind Blast (mana >=20, fresh-channel hold, 2-tick clip fire); Mind Flay filler; Shadowfiend <60% mana-return band. (Shadow Word: Death: absent from this file — the WotLK shadow kit here is DoT + Mind Blast/Flay + Shadowfiend, documented not invented.) |
| `test_priest_discipline_wotlk_strategies.lua` | `discipline_wotlk.lua` | Friendly-unit model: **Power Word: Shield Weakened-Soul triage** (applies with no lockout via real `debuff_up` on 6788, holds during it); Penance / Prayer of Mending ungated fillers pinned as always-match; Renew HoT <3s refresh (2.9/3.0) |
| `test_priest_holy_wotlk_strategies.lua` | `holy_wotlk.lua` | Friendly-unit model: Guardian Spirit emergency (aura down + lowest <30%, incl. the 30 boundary and already-up hold); Greater Heal <50% + mana >=30; **Circle of Healing raid heal** (2+ injured via ctx.party_injured_count + lowest <85% + mana >=20, each side); Renew <3s; Prayer of Mending ungated; Flash Heal <70% + mana >=20 |
| `test_priest_leveling_wotlk_strategies.lua` | `leveling_wotlk.lua` | Fortitude / Inner Fire OOC upkeep (buff-up + in-combat holds); **the opt-in Shadowform lane** (setting-gated — fires OOC only when `eaxpriestlvl_use_shadowform` is set, holds without it / already formed / in combat); Power Word: Shield (in combat + absorb down + no Weakened Soul + mana); Flash Heal <50% emergency; SW:P <3s refresh; the Penance 15 / Mind Blast 20 / Mind Flay 20 / Smite 15 mana-gated nuke ladder; <10% Shoot OOM fallback |

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 0 never (priest specs 0/0)
```

---

## Addendum 2026-09-09 — WotLK healer expansion wave (guide-driven lanes, zero new never-lanes)

The four WotLK healer rotations were expanded to their published Icy-Veins priorities (the DPS specs got this treatment in the SoD/TBC waves; healers had not). All lanes load through the real read path (buff_up/buff_remains/buff_stacks/spell_ready on the real engine fields `party_injured_count`, `lowest_hp`, `mana_pct`); all ids Wowhead-verified this pass and pinned in the wotlk spell audit allowlist (+10, now 194). Battery: all 41 WotLK specs never-fires=0, strict gate held; no lane lost a firing window.

| File | Lanes before -> after | New lanes (guide mechanic) |
|---|---|---|
| `classes/druid/resto_wotlk.lua` | 7 -> 11 | **NaturesSwiftness + NaturesSwiftnessHealingTouch** emergency pair (aura-present spend / aura-absent enable, <=30% band, mirrors TBC sibling); **Rebirth** battle rez (group-utility guard + real `find_dead_party_ally` dead-player discovery — battery scenario `rebirth_dead_ally` proves the fire side); **Tranquility** (3+ injured, lowest <=50%, 8 min CD, Wowhead) |
| `classes/paladin/holy_wotlk.lua` | 5 -> 9 | **SealOfWisdom** upkeep (real self-aura read 20216/20166); **JudgementOfWisdom** (judge-on-CD <=90% mana = era-correct JoW uptime; debuff-id read deliberately avoided — effect id varies by seal cast); **DivineFavorHolyLight** (crit buff before the big HL, <75% band); **DivinePlea** (<=50% mana, 54428 already ret-pinned) |
| `classes/shaman/restoration_wotlk.lua` | 7 -> 10 | **NaturesSwiftness + NaturesSwiftnessHealingWave** emergency pair (shaman id 16188, 2 min CD, Wowhead); **TidalWavesHealingWave** (the file already tracked Tidal Waves stacks but never used them — now the 2-stack window hard-prioritizes the big nuke; battery scenario `resto_tidal_waves`) |
| `classes/priest/discipline_wotlk.lua` | 4 -> 6 | **PainSuppression** (<=30% save, Wowhead 33206) leading the order; **PowerInfusion** (<=45% pressure band, 10060) — the wowsims pinned APL's `autocastOtherCooldowns` action made concrete. MassDispel stays middleware-owned (dispel_manager `magic_mass`), recorded as deliberate |

Deliberate exclusions (honest residue): Tremor/Cleansing Totem debuff-response is middleware territory in this repo (main_sylvanas.lua:958 party-dispel ownership, dispel_manager) — a rotation lane would double-own the decision; SoD-era Binding Heal/Aura Mastery lessons applied (no passive/debuff-id reads without a live cast surface).

Suite pins extended (no new suites; 563 stable): `test_resto_wotlk_dsl_priority` (24->32), `test_holy_wotlk_dsl_priority` (14->22), `test_restoration_wotlk_dsl_priority` (+1 order/assert renames, 15), `test_discipline_wotlk_dsl_priority` (8->12), `test_shaman_wotlk_live_fixes` count pin. Two suite-local DSL-stub comparators gained real-semantics `truthy/falsy`/`<=` support (mirrors strategy_dsl evaluators, not vacuous passes). Battery scenarios added: `druid_wotlk_tranquility`, `druid_wotlk_ns_burst`, `resto_tidal_waves` (all spec-scoped in effect).

```bash
lua EaxRotations/tests/behavioral_audit.lua wotlk   # 0 never across all 41 specs
```

## Addendum 2026-09-09 (b) — holy priest guide-gap lanes: Desperate Prayer + Lightwell

The healing deep-rate's last two holy-priest omissions closed. `classes/priest/holy_wotlk.lua` 6 -> 8 strategies:

- **DesperatePrayer** (ladder 25437 max / 19243..13908, talent spell so the ladder is TBC-capped; 2-min CD): self-save at <= 30% own hp (inclusive band, matching the PainSuppression idiom), slotted directly under GuardianSpirit — you cannot heal anyone while dead. Reads the real engine field `context.player_hp` (engine alias of `context.hp`, main_sylvanas.lua:807), not a phantom read.
- **Lightwell** (ladder 48087 r6 max / 48086 / TBC-era 28275/27871/27870/7001; 3-min CD): sustained raid pressure at 3+ `party_injured_count`, slotted before CircleOfHealing (raid-sustain placement, not a spike response).

Order: GuardianSpirit -> DesperatePrayer -> GreaterHeal -> Lightwell -> CircleOfHealing -> Renew -> PrayerOfMending -> FlashHeal. Sim-APL block (GreaterHeal/CoH/Renew/PoM) unchanged and still conformance-mapped (test_apl_conformance 153/153).

Pins: `test_priest_holy_wotlk_strategies` +7 fire/hold sides (inclusive 30% band, cooldown holds via a keyed spell_ready mock); `test_holy_priest_wotlk_dsl_priority` order array + positional GreaterHeal execute pin updated (17/17). Battery: priest/holy 8 strategies never-fires=0 in druid_wotlk_wildgrowth (3 injured) / druid_wotlk_tranquility (4 injured) / low_self-family (player_hp 15) windows — no new scenarios needed. Spell audit: +14 Wowhead-verified VALID_RANK_ALIAS entries (allowlist 194 -> 208; note 48084/48085 are the Lightwell Renew buffs, excluded), size pin updated. Scorecard/badges/era-pair seed regenerated; suite count unchanged (no new suites).

## Addendum 2026-09-09 (c) — DPS/tank guide-pass lanes: frost mage, combat rogue, shadow priest, three tanks

The DPS/tank mirror of the healer waves. Six files expanded against their published playstyles (Wowhead/Icy-Veins class guides; every new id Wowhead-WotLK-verified):

| File | Lanes | New lanes (guide-driven) |
|---|---|---|
| `mage/frost_wotlk.lua` | 6 -> 8 | **IcyVeins** (12472, 3-min haste CD, long-CD consent) and **SummonWaterElemental** (31687, re-summon held while the pet is alive via real `NS.has_pet`) |
| `rogue/combat_wotlk.lua` | 7 -> 8 | **AdrenalineRush** (13750 — single rank, era-shared with TBC, initially misclassified TBC_ID_IN_WOTLK; 3-min CD, long-CD consent) |
| `priest/shadow_wotlk.lua` | 9 -> 11 | **ShadowWordDeath** (48158 max / 48157 / 32379 / 2944, <=25% execute band — recoil damage makes it strictly an execute finisher) and **MindSear** (53023 max / 49821, 3+ enemy AoE filler) |
| `warrior/protection_wotlk.lua` | 9 -> 10 | **Shockwave** (46968, 20s CD AoE stun, 2+ enemies at 15+ rage) |
| `paladin/protection_wotlk.lua` | 7 -> 9 | **HolyWrath** (48817 / 37897 / 31898, 2+ enemies vs creature-type 3=demon / 6=undead) and **DivinePlea** (54428, <50% mana return — bridge-carried) |
| `druid/bear_wotlk.lua` | 8 -> 9 | **SurvivalInstincts** (61336, 3-min CD emergency defensive at <35% hp) |

Pins: six existing behavioral suites extended with fire/hold sides through each file's real `build_state` (`test_mage_frost_wotlk_strategies` +9, `test_rogue_combat_wotlk_strategies` +4, `test_priest_shadow_wotlk_strategies` +5, `test_protection_wotlk_strategies` +4, `test_paladin_protection_wotlk_strategies` +9, `test_druid_bear_wotlk_strategies` +4 — the bear and prot-paladin mocks gained the `cooldown_remains` read they previously lacked; their new lanes fail closed without it). Battery: all eight lanes fire in existing shared scenarios (prot_cd_window/battle_ready, shadow_cleave, undead_target, low_mana/low_self) — WotLK totals 447 -> 455 strategies, never-fires=0, strict gate holds. Spell audit: +13 Wowhead-verified VALID_RANK_ALIAS entries (allowlist 208 -> 221). Scorecard/badges/era-pair seed regenerated; suite count unchanged.

Deliberate exclusions (honest residue): Bloodlust/Heroism already lane-owned by enhancement_wotlk (engine-wide hero window covers the rest); Commanding Shout deliberately absent from fury per the fury APL battle-shout policy (BattleShout lane exists; the two shout ids never stack in-era).


## Addendum 2026-09-10 — full spell-coverage sweep (utility/AoE/rez close-out)

A name-level matrix of every class spell in the WotLK bridge vs all 43 spec
files (plus the era-shared class/middleware files) found four real gaps and one
dead capability; all closed with the era-shared patterns:

| File | Lanes | New lanes (coverage-driven) |
|---|---|---|
| `mage/fire_wotlk.lua` | 8 -> 9 | **BlastWaveAoE** (42945 — Wowhead-verified WotLK max rank, 10y radius, 30s CD; audit alias pinned): 3+ enemies via the real `aoe_target_meets` SELF_10 gate, slot between FireBlast and ScorchFinal |
| `warlock/affliction_wotlk.lua` | 8 -> 9 | **SeedOfCorruptionAoE** (47836/27243 — leveling file's audit-proven ladder): 4+ enemy multi-DoT, unholy Pestilence volume idiom |
| `druid/cat_wotlk.lua` | 11 -> 12 | **MaimInterrupt** (49802, audit alias pinned): mirrors the TBC cat_sylvanas MaimInterrupt — 1+ CP, 35 energy, target casting |
| `mage/arcane_wotlk.lua` | — | none: Spellsteal is middleware-owned (mage/middleware_sylvanas.lua ranked OffensiveDispelDB scan) — matrix false positive |
| `priest/class_sylvanas.lua` + middleware | — | **OOCResurrect** middleware strategy (era-shared ladder 20770/10881/10880/2010/2006; WotLK 48171 max rank kept in the era-shared middleware fallback per the shadow-ladder architecture): dead party scan between pulls |
| `paladin/class_sylvanas.lua` + middleware | — | **OOCRedeem** middleware strategy (Redemption ladder 20773 max — 25898 was disproven as GBOK and removed before landing) |
| `druid/class_sylvanas.lua` + middleware | — | **ReviveOOC** middleware strategy (Revive 50769 WotLK max / 24341 TBC rank, era-resolved by `get_spell_id` first-learned-id) — OOC counterpart of the Rebirth battle-rez lane |

Battery: all three new combat lanes fire in existing shared scenarios
(target_casting/wotlk_interrupts, hurricane_aoe) — WotLK 455 -> 458
strategies, never-fires=0. Pins: `test_mage_fire_wotlk_strategies` +4
(fire/volume-hold/fail-closed/OOC-hold), `test_warlock_affliction_wotlk_
strategies` +3, `test_druid_cat_wotlk_strategies` +4 (fire/no-cast/0-CP/
energy-hold; the suite mock gained a bank-aware `is_casting` target). Static
suites re-baselined: fire 9, cat 12, affliction 9 (BlastWaveAoE/SoC AoE/
MaimInterrupt inserted into each expected_order). Spell audit: WotLK
allowlist 221 -> 223 (Maim 49802, Blast Wave 42945); sylvanas audit clean
(the era-shared class files stay TBC-valid — WotLK-only ranks live in the
middleware fallbacks, validated by `get_spell_id` first-learned-id
resolution). Scorecard/ACCURACY/era-pair seed (1355 names) regenerated.

## Addendum 2026-09-10 (b) — healer deep-rate close-out: hymns, Lay on Hands, disc fillers

The healing deep-rate's final four graded gaps, same guide discipline (all single-rank/new ids Wowhead-verified before landing):

- **Holy priest** `classes/priest/holy_wotlk.lua` 8 -> 10: **DivineHymn** (64901, single rank — 64902/64903 verified as unrelated ids on Wowhead; 3+ `party_injured_count`, lowest < 60, Tranquility idiom, channeled self-cast) and **HymnOfHope** (64904, single rank; mana < 40 — casting while wounded wastes the heal half). Slotted under the self-save band, ahead of target triage.
- **Holy paladin** `classes/paladin/holy_wotlk.lua` 9 -> 10: **LayOnHands** (era-shared 633, already TBC-bridge-accepted) as the <= 20% mana-free full-heal save on the DEDICATED beacon target (stable-target idiom, never the lowest-HP member), leading the order.
- **Discipline priest** `classes/priest/discipline_wotlk.lua` 6 -> 8: the direct-heal filler band the file lacked — **GreaterHeal** (< 50%, mana >= 30) and **FlashHeal** (< 70%, mana >= 20) after Renew, before PowerInfusion; `build_state` now reads `mana_pct` the way its sibling healer files do.

Battery: new shared scenario **healer_save_window** (lowest 15, mana-neutral) makes the tight <= 20 save band observable; all 41 WotLK specs hold never-fires=0 (priest/holy 10, priest/discipline 8, paladin/holy 10 in-battery). Spell audit: +2 VALID_RANK_ALIAS (64901/64904, allowlist 221 -> 223). Suites extended in place: three dsl_priority order/count updates (`test_holy_wotlk_dsl_priority` 9 -> 10 + index shift, `test_holy_priest_wotlk_dsl_priority` order + GreaterHeal slot 3 -> 5, `test_discipline_wotlk_dsl_priority` order) and three behavioral suites extended with fire/hold sides (`test_priest_holy_wotlk_strategies` +7, `test_priest_discipline_wotlk_strategies` +6 incl. a scenario mana variable, `test_paladin_holy_wotlk_strategies` +4 incl. the spell_ready mock the paladin suite previously lacked). Scorecard/ACCURACY/era-pair seed regenerated; suite count unchanged (563).
## Addendum 2026-09-10 (c) — DPS thin-spec close-out: subtlety, demonology, balance

The healer deep-rate's DPS counterpart: the scorecard's thinnest WotLK DPS
rows (subtlety 6 lanes — the era's lowest DPS rating — demonology 6, balance
6) were re-read against the published WotLK priorities and expanded.

- **rogue/subtlety_wotlk.lua 6 -> 10**: Hemorrhage 48660 universal builder
  (no positional/dagger gate — also replaces the stale "fallback builder"
  comment that pointed at nothing), Slice and Dice + Rupture uptime
  (assassination sibling thresholds), Preparation 14185 spell_ready-gated
  reset (fails closed). Pinned in test_rogue_subtlety_wotlk_strategies.lua
  (Hemo 4 pins, SnD 3, Rupture 2, Prep 2) and the dsl_priority suite
  (count/order/index updates).
- **warlock/demonology_wotlk.lua 6 -> 8**: Molten Core proc window
  (buff 71165/47246/47245) hard-prioritizes Incinerate 47838; Decimation
  (buff 63165) fires instant shard-free Soul Fire in the sub-35% band. The
  plain SoulFire filler and its 30% mana gate are restored/kept intact.
  Pinned in test_warlock_demonology_wotlk_strategies.lua (7 new fire/hold).
- **druid/balance_wotlk.lua 6 -> 8**: Faerie Fire upkeep (caster ladder,
  26993 max — no WotLK rank exists; 3% spell hit) and Hurricane 48467
  channeled 10y AoE (3+ enemies; custom-fn channel idiom from
  resto_wotlk Tranquility since the DSL has no channel action type).
  Pinned in test_druid_balance_wotlk_strategies.lua (8 new fire/hold).
- Ids 48467 / 71165 / 47246 / 47245 / 63165 / 14185 pinned in the WotLK
  spell audit (Wowhead-verified); allowlist 225 -> 231. 48660 was already
  pinned (sim/rogue/hemorrhage.go). The Hemorrhage ladder was trimmed to the
  single WotLK rank — the audit rejected the TBC-era lower ranks
  (26864/17348/17347/16511) as TBC_ID_IN_WOTLK, correctly.
- Battery: all three specs never-fires = 0 (era total still 0). The new
  lanes fire in existing scenarios (mana 100/in_combat for the procs and
  FF; Hurricane needs no new scenario — in_combat + aoe defaults true cover
  the 3-enemy volume gate via the `aoe` scenario).
