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
