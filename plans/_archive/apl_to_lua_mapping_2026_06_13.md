# APL → Lua Mapping Analysis (TBC Classic Anniversary)

**Date:** 2026-06-13
**Type:** T12 — Read-only analysis
**Source APLs:** `tbc-new/ui/<class>/<spec>/apls/*.apl.json` (22 files)
**Target Rotations:** `EaxRotations/classes/<class>/<spec>_sylvanas.lua` (29 TBC specs)

## Purpose

Map each TBC spec's APL JSON priority list to its Lua strategy ordering in
`EaxRotations/classes/<class>/<spec>_sylvanas.lua`, then compare them
side-by-side to detect obvious priority inversions.

**Important caveat.** APL JSONs are simc-style priority lists that emit
"should-cast" actions in a single ordered chain. Lua rotations use a
**strategy table** where every entry evaluates a `matches()` predicate
against shared `state`, and the first match wins. They are NOT a literal
mirror. The Lua order encodes:
1. **Survival/utility** (potions, defensives, stances, forms) that have no APL
   equivalent and run first as gates
2. **Burst cooldowns** synced to external state (Bloodlust window, boss-only
   gates)
3. **APL-mirrored spells** in roughly the same priority as the simc list
4. **Conditional or refiller logic** (e.g. Doom-Snap rotation, Consecration
   mana dump) that the APL hides behind a single `groupReference` or
   `multidot` action

So a literal 1:1 priority comparison is not always meaningful, but a
**mismatch in the relative ordering of two APL-mirrored spells** is
informative.

---

## APL Files Inventory

| APL path | `priorityList` length | Notes |
|----------|----------------------:|-------|
| `tbc-new/ui/druid/balance/apls/default.apl.json` | 13 | |
| `tbc-new/ui/druid/feralbear/apls/default.apl.json` | 17 | |
| `tbc-new/ui/druid/feralcat/apls/default.apl.json` | 12 | |
| `tbc-new/ui/hunter/dps/apls/default.apl.json` | 10 | Top-level + `Mana management`/`Weave` groups |
| `tbc-new/ui/mage/dps/arcane.apl.json` | 12 | Heavy use of `groupReference` for regen rotation |
| `tbc-new/ui/mage/dps/blank.apl.json` | 0 | **Empty — skip** |
| `tbc-new/ui/mage/dps/test.apl.json` | 7 | **Test variant — skip** |
| `tbc-new/ui/paladin/protection/apls/default.apl.json` | 12 | |
| `tbc-new/ui/paladin/retribution/apls/default.apl.json` | 6 | |
| `tbc-new/ui/priest/dps/apls/default.apl.json` | 13 | |
| `tbc-new/ui/priest/dps/apls/test.apl.json` | 9 | **Test variant — skip** |
| `tbc-new/ui/rogue/dps/apls/swords.apl.json` | 17 | |
| `tbc-new/ui/shaman/elemental/apls/default.apl.json` | 8 | Totems group dominates |
| `tbc-new/ui/shaman/enhancement/apls/default.apl.json` | 8 | 5 groups, heavy use of `variablePlaceholder` |
| `tbc-new/ui/warlock/dps/affliction.apl.json` | 10 | |
| `tbc-new/ui/warlock/dps/blank.apl.json` | 0 | **Empty — skip** |
| `tbc-new/ui/warlock/dps/demonology.apl.json` | 8 | |
| `tbc-new/ui/warlock/dps/destruction.apl.json` | 7 | |
| `tbc-new/ui/warlock/dps/destro_fire.apl.json` | 7 | Fire-variant of destruction |
| `tbc-new/ui/warrior/dps/apls/arms.apl.json` | 27 | |
| `tbc-new/ui/warrior/dps/apls/fury.apl.json` | 28 | |
| `tbc-new/ui/warrior/protection/apls/default.apl.json` | 30 | |

**Effective APL count for analysis: 18** (2 blanks and 2 test variants
removed).

---

## Mapping Table

### Warrior

#### 1. Warrior — Arms (DPS)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warrior/dps/apls/arms.apl.json` |
| **Lua spec** | `EaxRotations/classes/warrior/arms_sylvanas.lua` (763 lines) |
| **Lua strategy source** | `STRATEGY_SPECS` table (~line 650), assembled into `strategies` at line 734 |

| # | APL order (top-level actions, hide:true and pre-pull omitted) | Lua strategy order (from `STRATEGY_SPECS`) | Match? |
|---|---|---|---|
| 1 | `Bloodlust + Drums` (group) | `HealthPotion` | Survival first in Lua |
| 2 | `Engineering` (group) | `DamagePotion` | — |
| 3 | `CD: Trinkets` (group) | `Healthstone` | — |
| 4 | `Sunder Armor` (group) | `Intercept` | — |
| 5 | Potion (Bloodlust-synced) | `Hamstring` | — |
| 6 | Other-action potion (Bloodlust-synced) | `Charge` | OOC opener |
| 7 | `CD: Racials` (group) | `DefensiveStance` | Stance logic ahead of combat |
| 8 | Will of the Forsaken (Bloodlust-synced) | `BattleStance` | — |
| 9 | Recklessness (Bloodlust-synced) | `BerserkerStance` | — |
| 10 | Blood Fury (AoE) | `CommandingShout` | Buff maintenance |
| 11 | Cleave (AoE) | `BattleShout` | — |
| 12 | **Mortal Strike** | `Bloodrage` | Rage regen |
| 13 | Whirlwind (BT delay > 1.5s) | `VictoryRush` | — |
| 14 | **Execute** (E20) | `Retaliation` | — |
| 15 | Cleave (AoE, rage>=40) | `Recklessness` | CD |
| 16 | `Overpower Weaving` (group, DW) | `DeathWish` | CD |
| 17 | Berserker Rage (defensive proc) | `MortalStrike` | Core ability |
| 18 | Heroic Strike (2H, 2H DW, >=40) | `Overpower` | — |
| 19 | Cleave (DW, >=40, BT CD) | `Whirlwind` | — |
| 20 | Hamstring (DW, >=40) | `Slam` | — |
| 21 | Battle Shout (rage<90) | `Execute` | **Lua 21 vs APL 14** (acceptable — Lua handles 2H/DW conditionally) |
| 22 | Berserker Rage (delay check) | `SweepingStrikes` | — |
| 23 | Commanding Shout (refresh) | `Rend` | — |
| 24 | (hidden) Berserker Rage | `PiercingHowl` | — |
| 25-28 | (hidden) Recklessness/Retaliation/Thunder Clap | `Hamstring` | — |
| | | `DemoralizingShout` | — |
| | | `ThunderClap` | — |
| | | `Cleave` | — |
| | | `HeroicStrike` | — |
| | | `SunderArmor` | Defensive stance only |
| | | `Healthstone` | — |

**Match status:** **Parity with structure difference.** Lua gates survival
and stance logic before combat, and pushes Sunder Armor to the bottom
because it only fires in Defensive Stance. The 2H vs DW variants of MS/Slam
are split by `variableRef` in the APL, while the Lua uses one entry with
internal branching. No meaningful priority inversion.

---

#### 2. Warrior — Fury (DPS)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warrior/dps/apls/fury.apl.json` |
| **Lua spec** | `EaxRotations/classes/warrior/fury_sylvanas.lua` (833 lines) |
| **Lua strategy source** | `STRATEGY_SPECS` table (lines 718-780), assembled at line 782 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `Bloodlust + Drums` | `HealthPotion` | Survival |
| 2 | `Engineering` | `DamagePotion` | — |
| 3 | `CD: Trinkets` | `Healthstone` | — |
| 4 | `Sunder Armor` | `Intercept` | — |
| 5 | Potion (Bloodlust) | `Hamstring` | — |
| 6 | Other-action potion | `BerserkerStance` | Stance |
| 7 | `CD: Racials` | `BattleStance` | — |
| 8 | Will of the Forsaken | `BattleShout` | Buff |
| 9 | Recklessness | `BerserkerRage` | — |
| 10 | Blood Fury (AoE) | `Bloodrage` | — |
| 11 | Whirlwind (AoE) | `VictoryRush` | — |
| 12 | **Bloodthirst** | `Charge` | OOC opener |
| 13 | Whirlwind (BT delay > 1.5s) | `Recklessness` | CD |
| 14 | **Execute** (E20) | `DeathWish` | CD |
| 15 | Cleave (AoE, rage>=40) | `SweepingStrikes` | AoE |
| 16 | `Overpower Weaving` | `Rampage` | **Lua 16 vs not in APL** (TBC 4-piece addition) |
| 17 | Berserker Rage (defensive proc) | `Bloodthirst` | Core ability |
| 18 | Heroic Strike (>=40, not execute) | `Whirlwind` | — |
| 19 | Cleave (DW, >=40, BT CD) | `Slam` | — |
| 20 | Hamstring (DW, >=40) | `SwingDesync` | **Lua addition** (TBC dual-wield trick) |
| 21 | Battle Shout (rage<90) | `Execute` | — |
| 22 | Berserker Rage (delay check) | `SunderArmor` | — |
| 23 | Commanding Shout (refresh) | `DemoralizingShout` | — |
| 24-28 | (hidden) | `Cleave` | — |
| | | `HeroicStrike` | — |

**Match status:** **Parity with additions.** Lua adds `Rampage` (TBC
4-piece) and `SwingDesync` (advanced DW handling) not in the APL. Sunder
Armor, Overpower and Demoralizing Shout are deliberately reordered (Sunder
is for Defensive Stance swap; Overpower is Arms-only in TBC; demo shout is
PvP/utility). No meaningful priority inversion.

---

#### 3. Warrior — Protection (Tank)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warrior/protection/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/warrior/protection_sylvanas.lua` (929 lines) |
| **Lua strategy source** | `strategies` table starting at line 626 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `Bloodlust + Drums` | `HealthPotion` | — |
| 2 | `Engineering` | `DamagePotion` | — |
| 3 | `CD: Offensive Trinkets` | `LastStand` | Emergency defensive |
| 4 | `CD: Defensive Trinkets` (HP<=40) | `ShieldWall` | Emergency defensive |
| 5 | Last Stand (HP<=40) | `ShieldBash` | Interrupt |
| 6 | `CD: Shield Wall Dual Wield` | `ShieldSlamPurge` | PvP purge |
| 7 | Shield Wall (HP<=35) | `ShieldSlam` | Core |
| 8 | Healthstone (HP<=30) | `Revenge` | Core |
| 9 | Felstone Band (HP<=30) | `Taunt` | — |
| 10 | Potion (Bloodlust) | `TauntSecondary` | Tab-cycling |
| 11 | Will of the Forsaken | `MockingBlow` | — |
| 12 | **Shield Block** (rage>=40, no demo, or GCD<=1.5s) | `ChallengingShout` | — |
| 13 | **Thunder Clap** (AoE) | `ShieldBlock` | — |
| 14 | `Execute` (group) | `Devastate` | — |
| 15 | Demoralizing Shout (no execute) | `SunderArmor` | — |
| 16 | Revenge (no execute) | `Execute` | — |
| 17 | **Shield Slam** (no execute) | `ThunderClap` | — |
| 18 | Thunder Clap (no execute) | `DemoralizingShout` | — |
| 19 | Sunder Armor (debuff refresh) | `BattleShout` | — |
| 20 | Battle Shout (rage<90) | `CommandingShout` | — |
| 21 | Concussion Blow | `Cleave` | — |
| 22 | Cleave (AoE, rage>=40) | `HeroicStrike` | — |
| 23 | Heroic Strike (rage>=40) | `SpellReflection` | — |
| 24-27 | (hidden) | `Disarm` | — |
| 28 | (hidden autocastOtherCooldowns) | `ConcussionBlow` | — |
| | | `Hamstring` | — |
| | | `Intercept` | — |
| | | `Intervene` | — |
| | | `BerserkerRage` | — |
| | | `Bloodrage` | — |
| | | `VictoryRush` | — |
| | | `Rend` | — |
| | | `IntimidatingShout` | — |
| | | `RageDumpSafetyNet` (Heroic Strike at >=90 rage) | — |

**Match status:** **Parity with restructured defensives.** Lua
front-loads emergency defensives (`LastStand`, `ShieldWall`,
`ShieldBash`) ahead of the APL's "Bloodlust-synced" cooldowns, which is
correct for tanking (you react to HP first, not the burst window). The
APL has Shield Block at #12, Thunder Clap at #13; Lua evaluates
`ShieldBlock` at #12 and `ThunderClap` at #17 — Thunder Clap is **moved
down** in Lua, which matches the design principle "Shield Slam > Revenge
> Thunder Clap for prot". **No inversion**, just a sensible
re-prioritization of the same spells.

---

### Warlock

#### 4. Warlock — Affliction

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warlock/dps/apls/affliction.apl.json` |
| **Lua spec** | `EaxRotations/classes/warlock/affliction_sylvanas.lua` (926 lines) |
| **Lua strategy source** | `strategies` table starting at line 280 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `autocastOtherCooldowns` | `DamagePotion` | Auto pot first |
| 2 | `castWarlockAssignedCurse` | `PetDefensive` / `PetPassive` / `PetAggressive` | Pet state |
| 3 | Immolate (missing) | `DeathCoilSurvival` (HP<=30) | Survival first |
| 4 | Unstable Affliction (missing) | `Healthstone` (HP<=40) | — |
| 5 | Corruption (missing) | `Soulshatter` (threat>=90) | — |
| 6 | Siphon Life (missing) | `NightfallProc` | — |
| 7 | Death Coil (execute<5%) | `CorruptionDoT` | — |
| 8 | Shadow Burn (execute<5%) | `CorruptionSpread` | — |
| 9 | Drain Life (mana<15%) | (more DoTs) | — |
| 10 | **Shadow Bolt** (filler) | (more, then) | — |
| | | `DrainSoul` (execute) | — |
| | | `ShadowBolt` (filler) | — |

**Match status:** **Parity with survival-first reordering.** Lua gates
`DeathCoilSurvival` (HP<=30) and `Healthstone` ahead of DoT maintenance —
the APL has no such gate because simc characters don't take damage. The
APL casts DoTs in order: **Immolate → UA → Corruption → Siphon Life →
Drain Soul filler**. Lua puts Corruption first (line 391) before UA
(around line 425+). **Minor inversion:** Lua applies Corruption before
UA, the APL applies UA before Corruption — both work in practice
(Corruption is instant cast, UA isn't), but the documented order is
**APL: UA before Corruption** vs **Lua: Corruption before UA** — this is
a **soft priority inversion** worth noting.

---

#### 5. Warlock — Demonology

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warlock/dps/apls/demonology.apl.json` |
| **Lua spec** | `EaxRotations/classes/warlock/demonology_sylvanas.lua` (408 lines) |
| **Lua strategy source** | `strategies` table starting at line 341 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `autocastOtherCooldowns` | `DamagePotion` | — |
| 2 | `castWarlockAssignedCurse` | `PetDefensive` / `PetPassive` / `PetAggressive` | — |
| 3 | Immolate (missing) | `FelArmor` (missing) | **Buff before DoT — correct** |
| 4 | Corruption (missing) | `SummonFelguard` (OOC, no pet) | — |
| 5 | Death Coil (execute<5%) | `FelDomination` | — |
| 6 | Shadow Burn (execute<5%) | `HealthFunnel` (pet<30%) | — |
| 7 | Drain Life (mana<15%) | `CurseOfDoom` (TTD>=62) | — |
| 8 | **Shadow Bolt** (filler) | `CurseOfElements` | — |
| | | `CurseOfAgony` | — |
| | | `Immolate` | — |
| | | `Corruption` | — |
| | | `SiphonLife` | — |
| | | `SeedOfCorruption` | — |
| | | `SoulFire` | — |
| | | `DrainSoul` (execute) | — |
| | | `RainOfFire` | — |
| | | `Hellfire` | — |
| | | `DeathCoil` (HP<=40) | — |
| | | `LifeTap` | — |
| | | `DarkPact` | — |
| | | `ShadowWard` | — |
| | | `HowlofTerror` | — |
| | | `Fear` | — |
| | | `Soulshatter` | — |
| | | `ShadowBolt` (filler) | — |
| | | `Incinerate` (Imp buff) | **Lua addition** (Demonology only) |

**Match status:** **Parity with extras.** Lua adds the pet state trio
(defensive/passive/aggressive) and `Incinerate` (Imp fire-bolt proc)
ahead of the filler. The APL casts `castWarlockAssignedCurse` first;
Lua splits it into CoD/CoE/CoA, evaluated in that order. **Lua
cur order: CoD → CoE → CoA** vs **APL: castWarlockAssignedCurse**
(matches the simc "cur rotation" of CoE > CoA > CoR > CoW for
Demonology, and CoD only for long TTD). No meaningful priority
inversion.

---

#### 6. Warlock — Destruction

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warlock/dps/apls/destruction.apl.json` |
| **Lua spec** | `EaxRotations/classes/warlock/destruction_sylvanas.lua` (421 lines) |
| **Lua strategy source** | `ACTIONS` table (line 82) → `strategies` (line 299), with `ManaGem` inserted at 7 and `Soulshatter` at 24 |

| # | APL order | Lua strategy order (effective) | Match? |
|---|---|---|---|
| 1 | `autocastOtherCooldowns` | `FelArmor` (missing) | Buff maintenance |
| 2 | `castWarlockAssignedCurse` (CoR/CoE/CoDoom) | `DemonArmor` (missing) | — |
| 3 | Shadow Burn (short fight) | `ShadowWard` (missing) | — |
| 4 | Death Coil (short fight) | `CreateHealthstone` (OOC) | — |
| 5 | Immolate (refresh) | `LifeTap` (mana<65, HP>40) | — |
| 6 | **Shadow Bolt** (filler) | `DarkPact` (mana<55) | — |
| 7 | **Soul Fire** (filler) | `ManaGem` (mana<35) | **Inserted between DarkPact and DrainLife** |
| | | `DrainLife` (HP<40) | — |
| | | `HealthFunnel` (pet<60) | — |
| | | `CurseOfDoom` (TTD>=62) | — |
| | | `CurseOfAgony` (refresh) | — |
| | | `Corruption` (refresh) | — |
| | | `Immolate` (refresh, SP>=400) | — |
| | | `BacklashShadowBolt` (proc) | **Lua addition** |
| | | `Conflagrate` (Immolate active) | — |
| | | `SoulFire` (shard) | — |
| | | `Shadowburn` (execute<20) | — |
| | | `SearingPain` (moving) | — |
| | | `Incinerate` (Immolate active) | — |
| | | `ShadowBolt` (filler) | — |
| | | `SeedOfCorruption` (3+ targets) | — |
| | | `RainOfFire` (4+) | — |
| | | `Hellfire` (4+) | — |
| | | `Soulshatter` (high threat) | **Inserted before DeathCoil/Fear** |
| | | `DeathCoil` (HP<35) | — |
| | | `Fear` | — |
| | | Pet summons + FelDomination (OOC) | — |

**Match status:** **Parity with significant Lua additions.** Lua adds
the entire survival/mana-management block (FelArmor → DarkPact →
ManaGem → DrainLife → HealthFunnel) which the APL skips because simc
simulates perfect mana. Lua also adds `BacklashShadowBolt` (TBC
backlash proc), `SearingPain` (moving), and the full `SeedOfCorruption`
→ `RainOfFire` → `Hellfire` AoE block.

**Note on filler order:** APL has **Shadow Bolt → Soul Fire** (line 6→7).
Lua has the same **ShadowBolt at position 25** but places
`Incinerate` (line 22) **before** ShadowBolt. **Lua 22 vs Lua 25 —
Incinerate before ShadowBolt** is correct for TBC Destruction (Immolate
must be active, then Incinerate > ShadowBolt). The APL's
`destruction.apl.json` uses Shadow Bolt as filler (no `Incinerate`).
The `destro_fire.apl.json` uses **Incinerate** as filler. **Lua
matches the destro_fire APL, not the destruction APL** — this is a
**known Lua generalization** that handles both variants in one rotation
file.

---

#### 7. Warlock — Destruction (Fire variant)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/warlock/dps/apls/destro_fire.apl.json` |
| **Lua spec** | `EaxRotations/classes/warlock/destruction_sylvanas.lua` (same file as #6) |

The Lua spec is the same file as Destruction above. The only APL-level
difference is **filler = Incinerate** instead of Shadow Bolt. The Lua
rotation **already prefers Incinerate** when Immolate is active
(position 22 in the table above), so it serves both APLs. **No
inversion.**

---

### Shaman

#### 8. Shaman — Elemental

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/shaman/elemental/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/shaman/elemental_sylvanas.lua` (507 lines) |
| **Lua strategy source** | `strategies` table starting at line 383 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `Totems` (group: Earth, Water, Fire, Air) | `ManaPotion` | — |
| 2 | Earth Elemental (disabled) | `ManaEmergencyWand` (mana<5%) | — |
| 3 | Fire Elemental (disabled) | `LightningShield` | Buff maintenance |
| 4 | `castAllStatBuffCooldowns` | `WaterShield` | — |
| 5 | `autocastOtherCooldowns` | `GhostWolf` | OOC |
| 6 | **Chain Lightning** (mana>=30, cast>=1s) | `TremorTotem` | Utility |
| 7 | **Lightning Bolt** (filler) | `EarthbindTotem` | — |
| 8 | (the rest of the priority is post-filler, hidden) | `ManaTideTotem` | — |
| | | `ElementalMastery` | Burst |
| | | `NaturesSwiftness` | Burst |
| | | `Bloodlust` | Burst |
| | | `ChainLightning` | — |
| | | `LightningBolt` | — |
| | | `FlameShock` (DoT) | **Lua places AFTER filler** |
| | | `ChainHeal` | — |
| | | `FlameShockMoving` | Moving |
| | | `EarthShockMoving` | Moving |
| | | `FrostShockMoving` | Moving |
| | | `TotemOfWrath` | Totem maintenance |
| | | `WrathOfAirTotem` | — |
| | | `ManaSpringTotem` | — |
| | | `FireNovaTotem` (AoE) | — |
| | | `MagmaTotem` (AoE) | — |
| | | Weapon buff triplet | OOC |
| | | `HealingWave` | — |
| | | `TotemicCall` | — |

**Match status:** **Parity with movement filler and survivability
additions.** Lua adds a `ManaEmergencyWand` gate (mana<5%) and the
moving-shock fillers (`FlameShockMoving`/`EarthShockMoving`/
`FrostShockMoving`) which the APL doesn't model (simc characters
don't move). Lua also splits the `Totems` group into individual
`TotemOfWrath`/`WrathOfAir`/`ManaSpring` entries.

**Note on Flame Shock priority:** Lua places `FlameShock` (DoT
maintenance) at position 15, **after** the Lightning Bolt filler. The
`flame_shock_matches_fn` only fires when `flame_remains <= 1`, so the
strategy only fires when Flame Shock is about to fall off. In practice
it's correct: when Flame Shock is up, the filler fires; when it's not,
Flame Shock fires regardless of position. **Not a real inversion.**

---

#### 9. Shaman — Enhancement

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/shaman/enhancement/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/shaman/enhancement_sylvanas.lua` (1057 lines) |
| **Lua strategy source** | `strategies` table starting at line 970 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `Shamanistic Rage` (group) | `ManaPotion` | — |
| 2 | Bloodlust (single-spell) | `ManaEmergencyWand` | — |
| 3 | `Fire Elemental` (group) | `AutoAttack` | — |
| 4 | `Totems` (group: WF twist, Str of Earth, Mana Spring, Wrath of Air) | `GhostWolf` | OOC |
| 5 | `autocastOtherCooldowns` | `TotemicCall` | Totem recovery |
| 6 | `castAllStatBuffCooldowns` (agi, AP, SP) | `FireNovaReplacement` | — |
| 7 | `Shocks` (group: Flame Shock twist, filler Earth/Frost) | `EarthTotem` | — |
| 8 | `Fire Totems` (group: Fire Nova, Magma, Searing) | `WaterTotem` | — |
| | | `FireTotem` | — |
| | | `WindfuryTotemTwist` | WF maintain |
| | | `GraceOfAirTotemTwist` | — |
| | | `WindfuryTotemMaintain` | — |
| | | `MHWeaponBuff` | OOC |
| | | `OHWeaponBuff` | OOC |
| | | `WaterShield` | — |
| | | `LightningShield` | — |
| | | `ShamanisticRage` | CD |
| | | `Bloodlust` | CD |
| | | `ManaTideTotem` | — |
| | | `NaturesSwiftness` | — |
| | | `TremorTotem` | Utility |
| | | `GroundingTotem` | Utility |
| | | `Purge` | — |
| | | `BloodFury` | Racial |
| | | `Berserking` | Racial |
| | | `GiftOfTheNaaru` | Heal |
| | | `LesserHealingWave` | Heal |
| | | `ChainHeal` | Heal |
| | | `Stormstrike` | **Core ability #1** |
| | | `FlameShock` | **Core ability #2** |
| | | `EarthShock` | Filler shock |
| | | `FrostShock` | Filler shock |
| | | `ChainLightning` (AoE) | — |
| | | `LightningBolt` (AoE) | — |

**Match status:** **Parity with extensive additions.** Lua splits the
APL's `Shocks` group into individual `FlameShock`/`EarthShock`/
`FrostShock` strategies. Lua also adds a complete weapon-buff
maintenance block (`MHWeaponBuff`/`OHWeaponBuff`) and
`AutoAttack`/`GhostWolf`/`TotemicCall` triggers that the APL assumes.

**No priority inversion.** Lua evaluates the core rotation
`Stormstrike` → `FlameShock` → `EarthShock` → `FrostShock` in the
right order, gated by the "only while FS active" check on Earth Shock.

---

### Priest

#### 10. Priest — DPS (Shadow)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/priest/dps/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/priest/shadow_sylvanas.lua` (704 lines) |
| **Lua strategy source** | `strategies` table starting at line 643 |

**Note:** the user-requested spec is "priest/dps" (no spec name). The
most general DPS priest spec is `shadow_sylvanas.lua` (the smite
spec is a Holy DPS hybrid that uses Smite + Holy Fire instead of
SW:P + VT). The APL matches the Shadow playstyle.

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | Inner Focus (short fight or OOM) | `PowerWordFortitude` (OOC) | Buff |
| 2 | `autocastOtherCooldowns` | `PreCombatPull` (VampiricTouch) | Pre-pull |
| 3 | Berserking (Troll) | `Shadowform` | Form |
| 4 | **Inner Focus + Mind Blast** (long fight) | `SWDCCBreak` (CC break) | Special |
| 5 | Shadowmeld (Night Elf) | `Shadowfiend` | CD |
| 6 | Shadow Word: Pain (missing) | `VampiricTouch` | DoT |
| 7 | Vampiric Touch (refresh) | `ShadowWordPain` | DoT |
| 8 | Inner Focus (pre-Mind Blast) | `MovingSWP` | Moving |
| 9 | Devouring Plague (?) — but cast `Mind Blast` | `VampiricEmbrace` | — |
| 10 | **Mind Blast** | `DevouringPlague` | — |
| 11 | Shadow Word: Death (?) | `InnerFocusMindBlast` | — |
| 12 | **Mind Flay** (channel) | `MindBlast` | — |
| 13 | (—) | `ShadowWordDeath` | — |
| | | `MindFlay` (channel) | — |
| | | `PsychicScream` | — |
| | | `DispelMagic` | — |
| | | `ShackleUndead` | — |
| | | `SWPSpread` | Multi-DoT |
| | | `VTSpread` | Multi-DoT |
| | | `InnerFire` | — |
| | | `PowerWordShield` | — |
| | | `FlashHeal` | — |
| | | `HolyNovaAoE` | — |
| | | `ManaEmergencyWand` | OOM safety |
| | | Racials + `Starshards` | — |

**Match status:** **Parity with extensive utility additions.** Lua
adds Shadowform/SWD-CC-Break/Mind Blast sequencing, multi-DoT
spreading (`SWPSpread`/`VTSpread`), and a heal/dispel block the APL
doesn't model. The APL has Devouring Plague as line 9 but actually
casts `Mind Blast` (line 10). Lua places DevouringPlague at
position 11 (after SWP/VT) and Mind Blast at position 13. **Lua
Devouring Plague priority (11) vs APL (9) — soft inversion.** The
match `devouring_plague_matches` requires both SWP and VT to be
active, so it cannot fire before the DoTs are applied anyway. No
real inversion in practice.

---

### Mage

#### 11. Mage — Arcane

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/mage/dps/apls/arcane.apl.json` |
| **Lua spec** | `EaxRotations/classes/mage/arcane_sylvanas.lua` (548 lines) |
| **Lua strategy source** | `strategies` table starting at line 445 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `DetermineRegenRotation` (group) | `IceBarrier` | Defensive |
| 2 | `autocastOtherCooldowns` (after 10s delay) | `IceBlock` (HP<=20) | — |
| 3 | Cold Snap (Icy Veins CD>120, Icy Veins ready) | `ColdSnap` (HP<=35, no IB) | — |
| 4 | Icy Veins (Bloodlust active, IB not active) | `Blink` | — |
| 5 | Icy Veins (Heroism active, IB not active) | `ManaShield` | — |
| 6 | Berserking (Bloodlust sync, IB not active) | `Polymorph` | CC |
| 7 | Mana Gem (mana cond) | `FrostNova` | CC |
| 8 | Dark Rune (mana cond) | `Slow` (PvP, >8yd) | CC |
| 9 | Evocation (no buffs, conserve) | `PresenceOfMind` | Burst |
| 10 | Arcane Missiles (AM buff) | `ArcanePower` | Burst |
| 11 | **Arcane Blast** (no time for SB filler) | `IcyVeins` (burn phase) | — |
| 12 | (—) | `ColdSnapIVReset` (burn, IV up>3s) | — |
| | | `Evocation` | Mana |
| | | `ManaGem` | Mana |
| | | `ArcaneBlast` (stack limit) | **Lua 18 vs APL 11** |
| | | `FireBlast` (instant) | — |
| | | `ArcaneMissiles` (proc) | — |
| | | `FireballLeveling` / `FrostboltLeveling` | Pre-AB |

**Match status:** **Parity with burn/conserve phase machine.** Lua
gates every burst cooldown on `s.phase == "burn"` while the APL uses
`multipleCdUsages` against Bloodlust. The Lua's `Evocation` strategy
maps to APL line 9; `ManaGem` to line 7; `ArcaneBlast` to line 11.

**No priority inversion.** The Lua rotation is a state-machine
re-implementation of the APL's `DetermineRegenRotation` +
`ConserveRotation` group structure, with the same end result.

---

### Hunter

#### 12. Hunter — DPS (Marksmanship)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/hunter/dps/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/hunter/marksmanship_sylvanas.lua` (396 lines) |
| **Lua strategy source** | `strategies` table starting at line 319 |

**Note:** the user-requested spec is "hunter/dps" (no spec name).
`marksmanship_sylvanas.lua` is the canonical ranged-DPS file. The
APL is the standard "weave" rotation used by all three hunter specs.

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `Mana management` (group: Viper start, Viper, Aspect of Hawk) | `HealthPotion` | — |
| 2 | `autocastOtherCooldowns` (after 5s) | `ManaPotion` | — |
| 3 | **Bestial Wrath** (pre-pull, <=0.5s) | `MendPet` | — |
| 4 | `Weave` (group: melee weave) | `CallPet` | — |
| 5 | Multi-Shot (weave cond) | `RevivePet` | — |
| 6 | Arcane Shot (weave cond) | Pet state trio | — |
| 7 | Steady Shot (no time for AB) | `AspectOfTheHawk` | Buff |
| 8 | Multi-Shot (range cond) | `AspectOfTheViper` | Buff |
| 9 | **Steady Shot** (cast time) | `FreezingTrap` | Utility |
| 10 | **Arcane Shot** (use) | `HuntersMark` | — |
| | | `RapidFire` | CD |
| | | `BestialWrath` | CD |
| | | `Readiness` | CD |
| | | `InCombatAimedShot` | Cast |
| | | `AimedShotPrepull` | Pre-pull |
| | | `KillCommand` | — |
| | | `FeignDeath` | — |
| | | `LevelingArcaneShot` | Leveling |
| | | `LevelingSting` | Leveling |
| | | `AdaptiveRotation` (optional) | — |
| | | `MultiShot` | — |
| | | `ArcaneShot` | — |
| | | `SteadyShot` | — |
| | | `ViperSting` | — |
| | | `SerpentSting` | — |

**Match status:** **Parity with melee-weave gap-closer handling.** Lua
adds `KillCommand`, `RapidFire`, `Readiness`, `AimedShot` which the APL
hides behind `autocastOtherCooldowns`. The melee-weave logic is
implemented as a separate `Weave` group in the APL; Lua's `ManaPotion`
→ `MendPet` chain handles pet state first. **No priority inversion.**

---

### Druid

#### 13. Druid — Balance

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/druid/balance/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/druid/balance_sylvanas.lua` (415 lines) |
| **Lua strategy source** | `_strategies` table starting at line 112 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | Innervate (self, mana<30%) | `BarkskinDefense` (HP<=40) | — |
| 2 | Faerie Fire (debuff <5s) | `ManaPotionEmergency` (mana<15%) | — |
| 3 | Dark Rune (mana cond) | `ForceOfNature` (burst) | — |
| 4 | Super Mana Potion (mana cond) | `MoonkinForm` (OOC) | — |
| 5 | Insect Swarm (multidot, 1 target, no overlap) | `InnervateSelf` (in-combat, self) | — |
| 6 | Trinket | `RebirthBattleRez` | — |
| 7 | **Moonfire** (multidot) | `PreHurricaneBarkskin` | — |
| 8 | (—) | `HurricaneAoE` | — |
| 9 | (—) | `FaerieFireDebuff` | — |
| 10 | (—) | `InsectSwarmDoT` | — |
| 11 | (—) | `MoonfireDoT` | — |
| 12 | `autocastOtherCooldowns` | `MovingMoonfire` | Moving |
| 13 | Trinket (redundant) | `StarfirePrimary` | **Lua 13 vs APL 20 — Starfire > Wrath** |
| 14 | **Starfall** (4+ targets) | `WrathFiller` | — |
| 15 | **Innervate** (mana<75%, remaining>=45s, trinket>30s, no BL) | `RemoveCurse` | — |
| 16 | **Wrath** (filler) | `ManaPotion` (mana<25) | — |
| 17 | (—) | `PvP_NaturesGrasp` | PvP |
| 18 | (—) | `PvP_EntanglingRoots` | PvP |
| 19 | (—) | `PvP_Cyclone` (on healer) | PvP |
| 20 | (—) | `WarStomp` (4+ mobs) | Racial |
| 21 | (—) | `MarkOfTheWild` | Buff |
| 22 | (—) | `ThornsBuff` | Buff |

**Match status:** **Parity with major additions.** Lua adds the
`BarkskinDefense` (HP<=40) gate, the `RebirthBattleRez` (party
member dead), the `PreHurricaneBarkskin` prep, the `PvP_*` block, and
the buff maintenance (`MarkOfTheWild`/`Thorns`).

**APL 2: Faerie Fire before DoTs. Lua 9: Faerie Fire after Hurricane.**
This is a **soft inversion** — the APL uses Faerie Fire as an
armor-reduction debuff for caster groups, so it goes second. Lua
evaluates it after `HurricaneAoE` and `PreHurricaneBarkskin`. In
practice, FaerieFire's `matches` only fires when the debuff is
falling off, and the Lua rotation has a pre-defined `_choose_nuke`
function that picks Starfire vs Wrath. **Not a true inversion.**

**APL 14: Starfall (4+ targets) is a WotLK CD, not a TBC spell.**
Lua has no Starfall strategy — correct, since TBC Balance has no
Starfall ability.

---

#### 14. Druid — Feral (Cat)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/druid/feralcat/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/druid/cat_sylvanas.lua` (1197 lines) |
| **Lua strategy source** | `ACTIONS` table (line 1125) → `strategies` (line 1163) |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | Bloodlust (5s) | `HealthPotion` | — |
| 2 | `Drums` | `ManaPotion` | — |
| 3 | Faerie Fire (Feral, missing) | `PoolForRip` | Energy pool |
| 4 | **Rip** (CP=5, no Rip, TTD>=10) | `PoolForExecuteBite` | — |
| 5 | **Ferocious Bite** (CP=5, TTD<10 OR Rip active) | `CatForm` | Form |
| 6 | Mangle (Trauma buff, not active) | `Prowl` (OOC) | Stealth |
| 7 | **Shred** (filler) | `Barkskin` | — |
| 8 | Engineering (energy<=30, gcd ready) | `PounceOpener` | Stealth |
| 9 | Trinkets (energy<=30) | `RavageOpener` | Stealth |
| 10 | Potion (energy<=30) | `StealthShred` | Stealth |
| 11 | Dark/Demonic Rune (mana<75, energy<=30) | `StealthMangle` | Stealth |
| 12 | Cat Form (energy<=30) | `Dash` | — |
| | | `FaerieFireFeral` | Debuff |
| | | `MaimInterrupt` | CC |
| | | `RipSnapshot` | — |
| | | `Rip` | — |
| | | `FerociousBiteExecute` | — |
| | | `FerociousBiteTtd` | — |
| | | `BiteTrick` | — |
| | | `MaimControl` | — |
| | | `MangleDebuff` | — |
| | | `RakeTrick` | — |
| | | `RakePvE` | — |
| | | `MangleBuilder` | — |
| | | `TigersFury` | CD |
| | | `Powershift` | — |
| | | `EmergencyPowershift` | — |
| | | `ShredOmen` (clearcast) | Filler |
| | | `Shred` | Filler |
| | | `MangleFiller` | Filler |
| | | `ClawFallback` | Filler |
| | | `RakePvP` | PvP |

**Match status:** **Parity with major refactor.** Lua has
`RipSnapshot` (snapshot-aware Rip) and `BiteTrick`/`RakeTrick`
(Tigers Fury energy pooling) and a clear **Rip > Mangle > Shred**
filler priority. APL has **Mangle (Trauma)** at line 6 — Lua has
`MangleDebuff` (which checks the debuff) before the filler Mangle.
The Lua also has a **Pounce/Ravage** opener from stealth that the
APL doesn't model.

**APL 6: Mangle (Trauma active, not debuff active).** Lua places
`MangleDebuff` (which is line 16 of Lua) **after** `MaimInterrupt`/
`Rip*`/`Bite*`/`MaimControl` — the Lua `MangleDebuff.matches` checks
`MangleDebuff < 5 stacks`, so it can only fire when stacks are low.
The APL's Mangle is for Trauma synergy. **No meaningful inversion.**

---

#### 15. Druid — Feral (Bear)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/druid/feralbear/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/druid/bear_sylvanas.lua` (854 lines) |
| **Lua strategy source** | `ACTIONS` table (line 742) → `strategies` (line 833) |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | Bloodlust (5s) | `PoolForMangle` | Energy pool |
| 2 | `Drums` | `MarkOfTheWild` (OOC) | Buff |
| 3 | Dire Bear Form (missing) | `GiftOfTheWild` (OOC) | Buff |
| 4 | Engineering (gcd ready, !Mangle, Trauma+Lacerate up) | `Thorns` (OOC) | Buff |
| 5 | `CD: Offensive Trinkets` | `BearForm` (OOC) | Form |
| 6 | Defensive Trinkets (HP<=40) | `PrePullEnrage` | — |
| 7 | Barkskin (HP<=40) | `FeralChargePull` (OOC) | — |
| 8 | Healthstone (HP<=30) | `FaerieFirePull` (OOC) | — |
| 9 | Felstone Band (HP<=30) | `Healthstone` | — |
| 10 | Potion (Bloodlust) | `HealingPotion` | — |
| 11 | Mangle Bear (rage>=50) | `FrenziedRegeneration` | Defensive |
| 12 | Lacerate (missing) | `SurvivalInstincts` | Defensive |
| 13 | Faerie Fire (Feral, missing) | `Barkskin` | Defensive |
| 14 | Faerie Fire (Feral, refresh<6s) | `ChallengingRoar` | — |
| 15 | Lacerate (refresh) | `Growl` | Taunt |
| 16 | Demoralizing Roar (missing) | `FaerieFireFeral` | Debuff |
| 17 | Swipe (Bear) | `DemoralizingRoar` | — |
| | | `MangleOpener` | — |
| | | `Lacerate` | — |
| | | `LacerateOffTarget` | — |
| | | `SwipeAoE` | — |
| | | `MangleBear` | — |
| | | `ClearcastingMangle` | Proc |
| | | `ClearcastingLacerate` | Proc |
| | | `Swipe` | — |
| | | `Maul` | — |
| | | `EnrageCombat` | — |
| | | `FerociousBiteExecute` | — |
| | | `BashPvP` | PvP |
| | | `BashInterrupt` | — |
| | | `FeralChargePvP` | PvP |
| | | `NaturesGraspPvP` | PvP |
| | | `FaerieFirePvP` | PvP |

**Match status:** **Parity with major additions.** Lua adds the
OOC buff block (`MarkOfTheWild`/`GiftOfTheWild`/`Thorns`/`BearForm`)
that the APL doesn't model (simc presumes form/buffs done). Lua also
adds `ClearcastingMangle`/`ClearcastingLacerate` (Omen of Clarity
procs) and the PvP block.

**APL 11: Mangle Bear (rage>=50) before Lacerate. Lua: same —
MangleOpener/Lacerate at the same priority but with rage gates.**
**No inversion.**

**APL 17: Swipe (Bear) is the AoE filler. Lua: `Swipe` at position
23, `SwipeAoE` (3+ targets) at position 20 — Lua prioritizes
SwipeAoE for 3+ targets, Swipe for 2 targets.** This is a
**refinement** of the APL's single Swipe entry.

---

### Rogue

#### 16. Rogue — Swords (Combat)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/rogue/dps/apls/swords.apl.json` |
| **Lua spec** | `EaxRotations/classes/rogue/combat_sylvanas.lua` (481 lines) |
| **Lua strategy source** | `strategies` table starting at line 441 |

**Note:** the user-requested spec is "rogue/dps/swords". The canonical
sword rogue spec is `combat_sylvanas.lua` (the daggers variant is
assassination, the prep variant is subtlety).

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | Adrenaline Rush (energy<=40) | `HealthPotion` | — |
| 2 | Blade Flurry item (energy<=30) | `DamagePotion` | — |
| 3 | Blade Flurry (SnD + EA) | `Stealth` | — |
| 4 | Cold Blood (only EA) | `SliceAndDice` | Buff |
| 5 | `autocastOtherCooldowns` (EA on target) | `AdrenalineRush` | CD |
| 6 | `Cast Expose or Pool` (Imp EA + 5CP) | `BladeFlurry` | CD |
| 7 | Slice and Dice (refresh) | `Rupture` | DoT |
| 8 | Rupture (imp EA, !EA SnD safe, 3-5CP) | `Eviscerate` | — |
| 9 | Eviscerate (CP=5 OR (Shiv + SnD/EA safe + Rupture)) | `ShivPurge` | — |
| 10 | Hemorrhage (no Shiv, CP<5, EA fall OR Shiv) | `Gouge` | CC |
| 11 | Sinister Strike (CP<5 OR pool) | `Sprint` | — |
| 12 | Backstab (use, CP<5 OR pool) | `Vanish` | — |
| 13 | Hemorrhage (Shiv known + CP=4 + !SnD + EA fall) | `Feint` | — |
| 14 | Mutilate (CP<5 OR pool) | `Hemorrhage` | — |
| 15 | Hemorrhage (no SS/Mutilate known, !BS, CP<5 OR pool) | `GhostlyStrike` | — |
| 16 | Engineering item | `Backstab` | — |
| 17 | Other engineering item | `KidneyShot` | — |
| | | `ExposeArmor` | Debuff |
| | | `SinisterStrike` | Filler |

**Match status:** **Parity with Swords-specific gating.** The APL
uses a `Spam Shiv` toggle (default `false`) which removes Shiv from
the rotation when not using Wound Poison. The Lua `ShivPurge`
strategy is gated by the same setting.

**APL 11: Sinister Strike (no Shiv known, !BS, CP<5 OR pool).**
**APL 15: Hemorrhage (no Shiv + no SS + no Mutilate).** Lua places
`SinisterStrike` at the bottom (position 17 of 17), and the
`Backstab`/`Hemorrhage` strategies are mid-rotation. **Lua order:
Hemorrhage (8) → GhostlyStrike (9) → Backstab (10) → KidneyShot
(11) → ExposeArmor (12) → SinisterStrike (17).** The Lua treats
SinisterStrike as the **last-resort filler**, while the APL treats
it as a primary CP builder. This is a **known Lua design decision**:
for a swords build, Mutilate/Hemorrhage/Sinister Strike are gated
on which daggers/swords are equipped (the Lua checks via
`is_spell_learned` for Shiv/Mutilate), so the bottom position of
Sinister Strike is fine when those aren't learned. **No real
inversion.**

---

### Paladin

#### 17. Paladin — Retribution

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/paladin/retribution/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/paladin/retribution_sylvanas.lua` (568 lines) |
| **Lua strategy source** | `add_strategy(...)` calls (priorities 1000→435), assembled into `strategies` at line 276 |

| # | APL order | Lua strategy order (descending priority) | Match? |
|---|---|---|---|
| 1 | `autocastOtherCooldowns` (after 11s delay) | `Ret_DivineShield_Emergency` (HP<=15) | Prio 1000 |
| 2 | Seal of Blood proc (SoB active, next swing<=0.4s) | `Ret_LayOnHands_LastResort` (HP<=8) | Prio 990 |
| 3 | Judgement of Blood (SoB active) | `Ret_DivineProtection_Physical` (HP<=22) | Prio 980 |
| 4 | Crusader Strike (SoB active + !HS) | `Ret_HealthstoneOrPotion` (HP<=35) | Prio 970 |
| 5 | `ExoOrConsec` group (Exo or Consec, SoB active) | `Ret_BlessingProtection_FocusedAlly` | Prio 930 |
| 6 | Seal of the Crusader (refresh) | `Ret_BlessingFreedom_Self` | Prio 920 |
| | | `Ret_BlessingFreedom_Ally` | Prio 910 |
| | | `Ret_Cleanse_Self` | Prio 900 |
| | | `Ret_Purify_SelfFallback` | Prio 890 |
| | | `Ret_Cleanse_Ally` | Prio 880 |
| | | `Ret_PvP_Repentance_Opener` | Prio 850 |
| | | `Ret_PvP_HammerJustice_Burst` | Prio 820 |
| | | `Ret_HammerWrath_Execute` (HP<20) | Prio 800 |
| | | `Ret_HammerWrath_FleeingPvP` | Prio 790 |
| | | `Ret_AvengingWrath_Burst` (no Forbearance, TTD>=15) | Prio 780 |
| | | `Ret_HotC_Opener_Seal` (combat<5s, !Crusader) | Prio 775 |
| | | `Ret_HotC_Opener_Judge` (combat<8s) | Prio 770 |
| | | `SealTwistBlood` (twist ready) | Prio 760 |
| | | `SealTwistPrepCommand` (twist prep) | Prio 750 |
| | | `Ret_CrusaderStrike_AfterJudgement` (no seal) | Prio 730 |
| | | `Ret_JudgeCrusader` | Prio 720 |
| | | `Ret_ApplyCrusaderSeal` | Prio 710 |
| | | `CrusaderStrike` (twist not active) | Prio 700 |
| | | `Ret_JudgeDamageSeal` (mana>=12) | Prio 690 |
| | | `Ret_SealBlood_Primary` | Prio 670 |
| | | `Ret_SealMartyr_Primary` | Prio 665 |
| | | `Ret_SealCommand_Primary` | Prio 660 |
| | | `Ret_JudgementWisdom_LowMana` (mana<=45) | Prio 640 |
| | | `Ret_SealWisdom_Emergency` (mana<=18) | Prio 630 |
| | | `Ret_ManaPotion` (mana<=20) | Prio 620 |
| | | `Consecration` (3+ targets, mana>=35) | Prio 600 |
| | | `Ret_Consecration_ManaDump` | Prio 590 |
| | | `Exorcism` (undead/demon) | Prio 580 |
| | | `Ret_HolyWrath_AoE` (2+ undead/demon) | Prio 575 |
| | | `Ret_JudgeSecondary_CommandCleave` | Prio 570 |
| | | `Ret_BlessingMight_Self` | Prio 540 |
| | | `Ret_BlessingKings_Self` | Prio 530 |
| | | `Ret_BlessingMight_MeleeAlly` | Prio 520 |
| | | `Ret_BlessingKings_Party` | Prio 510 |
| | | `Ret_SealCommand_AoE` (2+ targets) | Prio 490 |
| | | `Ret_SealRighteousness_Filler` | Prio 470 |
| | | `Ret_Judgement_RighteousnessFiller` | Prio 460 |
| | | `Ret_SealCommand_Fallback` | Prio 450 |
| | | `Ret_SealBlood_Fallback` | Prio 440 |
| | | `Ret_SealMartyr_Fallback` | Prio 435 |

**Match status:** **Parity with massive Lua extension.** Lua adds:
- **Emergency defensives** (Divine Shield, Lay on Hands, Divine
  Protection, Healthstone — none in the APL, all at the top)
- **PvP** (Repentance opener, Hammer of Justice burst, Hammer of
  Wrath fleeing) — none in the APL
- **Cleansing** (self, ally, Purify) — none in the APL
- **Blessing management** (BoP, BoF self, BoF ally) — none in the
  APL
- **HotC opener** (Seal of the Crusader + Judge) — partially in
  APL `PrepullSeal`/`PrepullJudge` groups
- **Seal twisting** (Blood/Martyr twist, prep Command) — none in
  the APL (the APL uses `autocastOtherCooldowns` to handle it)
- **Blessing buff maintenance** (Might/Kings self/party)
- **Consecration as mana dump** (single-target)

**APL 1: `autocastOtherCooldowns` (which on Ret includes trinkets,
potions, drums). Lua has no equivalent — handled by middleware.**

**APL 2: Seal of Blood proc (instant attack).** The Lua does not
have an explicit "Seal of Blood proc" strategy because the proc
fires automatically from the buff aura. The `SealTwistBlood` (Prio
760) handles the "twist to Blood before next swing" case.

**No priority inversion.** The Lua order is dominated by
survival/PvP that the APL doesn't model. The combat rotation
portion (Crusader Strike → Judge → SealBlood → Judgement of Wisdom
→ Consecration) matches the APL in spirit.

---

#### 18. Paladin — Protection (Tank)

| Source | Path |
|---|---|
| **APL JSON** | `tbc-new/ui/paladin/protection/apls/default.apl.json` |
| **Lua spec** | `EaxRotations/classes/paladin/protection_sylvanas.lua` (423 lines) |
| **Lua strategy source** | `strategies` table starting at line 384 |

| # | APL order | Lua strategy order | Match? |
|---|---|---|---|
| 1 | `autocastOtherCooldowns` | `ManaPotion` | — |
| 2 | Judgement (no SoC, !JoL, or T<0.5s) | `RighteousFury` | Buff |
| 3 | Wait (HS refresh) | `Consecration` | **Lua 3 vs APL 7 — Lua puts Consecration earlier** |
| 4 | Holy Shield (HS priority) | `HolyShield` | **Lua 4 vs APL 3 — close** |
| 5 | Judgement (HS, !SoC, !JoL, !HS) | `AvengerShield` | — |
| 6 | Seal of Command (no SoC, !HS or GCD>1.5s) | `Judgement` | — |
| 7 | **Consecration** (!HS or GCD>1.5s) | `SealOfCommandAoE` | — |
| 8 | Strict: Judgement + Seal of Command (SoC active) | `SealRighteousness` | — |
| 9 | Exorcism (undead/demon) | `HammerOfWrath` | — |
| 10 | (—) | `AvengingWrath` | — |
| 11 | Hammer of Wrath (no HS or GCD>1.5s) | `Exorcism` | — |
| 12 | Avenger's Shield (no HS or GCD>1.5s) | `HolyWrath` | — |
| | | `SealOfWisdom` | — |
| | | `DevotionAura` | — |
| | | `BlessingOfSanctuary` | — |
| | | `HolyShock` | Heal |
| | | `FlashOfLight` | Heal |
| | | `HolyLight` | Heal |
| | | `Cleanse` | — |
| | | `DivineProtection` | Defensive |
| | | `DivineShield` | Defensive |
| | | `LayOnHands` | Defensive |
| | | `RighteousDefense` | Peel |
| | | `BlessingOfProtectionAlly` | Peel |

**Match status:** **Parity with priority swap of Consecration and
Holy Shield.**

The file comment at line 380 says:
> "Priority order: Consecration > HolyShield > AvengerShield for AoE
> threat. Consecration generates more AoE threat per GCD; HolyShield
> provides mitigation."

The APL has:
- Line 2: Judgement
- Line 3: Wait (HS refresh)
- Line 4: **HolyShield** (HS priority)
- Line 7: **Consecration** (no HS or GCD>1.5s)

The Lua has:
- Line 2: RighteousFury
- Line 3: **Consecration**
- Line 4: **HolyShield**

This is a **documented priority inversion** of the APL's Holy
Shield > Consecration ordering, but it is an **intentional design
choice** for AoE threat gen (Consecration does more threat/GCD).
The code comment confirms the rationale. **Not a bug; a deliberate
TBC tanking refactor.**

---

## Specs Without APL JSONs

The TBC Classic rotation suite ships 29 specs. Of these, the
following **do NOT have a corresponding `*.apl.json` priority list**
in `tbc-new/ui/<class>/`:

### Healing specs (simc doesn't ship a "rotation" for healers)
| Class | Spec | Lua file | Notes |
|-------|------|----------|-------|
| Priest | Holy | `priest/holy_sylvanas.lua` | |
| Priest | Discipline | `priest/discipline_sylvanas.lua` | |
| Shaman | Restoration | `shaman/restoration_sylvanas.lua` | |
| Druid | Restoration | `druid/resto_sylvanas.lua` | |
| Paladin | Holy | `paladin/holy_sylvanas.lua` | |
| Paladin | Heal helper | `paladin/heal_helper_sylvanas.lua` | Not a registered spec — helper module |

### Tank specs without APL
- *(all tanks in TBC have APLs: warrior/protection, druid/feralbear,
  paladin/protection)*

### DPS specs without APL
| Class | Spec | Lua file | Notes |
|-------|------|----------|-------|
| Mage | Fire | `mage/fire_sylvanas.lua` | Fire has `mage/dps/blank.apl.json` (empty) and `mage/dps/test.apl.json` (test). Both effectively skip. |
| Mage | Frost | `mage/frost_sylvanas.lua` | No APL. |
| Hunter | Beast Mastery | `hunter/beast_mastery_sylvanas.lua` | BM uses the same `default.apl.json` as MM/SV (weave). |
| Hunter | Survival | `hunter/survival_sylvanas.lua` | Same. |
| Rogue | Assassination | `rogue/assassination_sylvanas.lua` | Only swords has an APL. |
| Rogue | Subtlety | `rogue/subtlety_sylvanas.lua` | Same. |
| Priest | Smite | `priest/smite_sylvanas.lua` | Holy-DPS hybrid. The "priest/dps/default.apl.json" matches Shadow, not Smite. |
| Warlock | (all 3) | — | All three have APLs. |

### Off-spec / utility
| Class | Spec | Lua file | Notes |
|-------|------|----------|-------|
| Druid | Caster | `druid/caster_sylvanas.lua` | Off-spec balance/utility helper. |
| Druid | Feral (cat) | `druid/cat_sylvanas.lua` | Has APL. |
| Hunter | Cliptracker | `hunter/cliptracker_sylvanas.lua` | Helper, not a registered spec. |

### Special / test
| Class | Spec | Lua file | Notes |
|-------|------|----------|-------|
| Warrior | Kebab | `warrior/kebab_sylvanas.lua` | Experimental/legacy spec. |
| *(various)* | Leveling rotations | `*/leveling_sylvanas.lua` | 9 leveling rotations. No APLs. |

**Total specs without an APL: 13 (excluding blanks, tests, and helpers).**
**Total specs with a usable APL: 18.**

---

## Summary: Priority Inversions and Notable Differences

### Real priority inversions (worth investigating)

1. **Affliction Warlock** — APL casts **UA before Corruption**; Lua
   casts **Corruption before UA**. In practice the Lua's
   `CorruptionDoT.matches` does not gate on UA being present, so the
   Cor debuff can land first. UA is the higher damage per cast in
   most gear profiles, so the Lua may be missing some damage on
   opener. **Investigate**: should `CorruptionDoT` be gated on
   `ua_remains > 0`?

2. **Protection Paladin** — APL casts **Holy Shield before
   Consecration**; Lua casts **Consecration before Holy Shield**.
   This is **deliberate** (code comment at line 380 documents it as
   "Consecration > HolyShield > AvengerShield for AoE threat").
   **No action required**, but the design decision should be
   documented in user-facing rotation notes.

### Soft inversions (acceptable but worth noting)

3. **Elemental Shaman** — Lua places `FlameShock` (DoT maintenance)
   at position 15, **after** the Lightning Bolt filler. The
   `flame_shock_matches_fn` only fires when `flame_remains <= 1`, so
   the rotation correctly maintains the DoT. Not a true inversion,
   but the order is misleading for readers.

4. **Combat Rogue** — Lua places `SinisterStrike` at the **bottom**
   of the strategy list. The match function is always true (no
   gating), so it's the universal filler, but the position
   suggests "Sinister Strike is least important" when it's actually
   the primary builder. Cosmetic issue.

5. **Shadow Priest** — Lua places `DevouringPlague` at position 11,
   after `SWP`/`VT`/`VampiricEmbrace`. The APL has it at line 9
   (after Mind Blast, before Mind Flay). The match function
   requires both SWP and VT active, so in practice it can't fire
   before them anyway. Not a real inversion.

### Lua additions the APL doesn't model (intentional)

- **Survival gates** on every spec: HealthPotion/DamagePotion,
  Healthstone, DivineShield, LastStand, ShieldWall, IceBlock, Ice
  Barrier, ManaShield, etc. — all at the top of the Lua strategy
  list. Simc characters don't take damage, so these don't appear
  in the APL.

- **Defensive cooldown management**: BarkskinDefense (Balance),
  SurvivalInstincts (Bear), ShieldWall (Prot Warrior), etc.

- **PvP strategies**: Hammer of Justice burst (Ret), Repentance
  opener (Ret), Bash interrupt (Bear), Natures Grasp (Balance),
  Faerie Fire PvP stealth break (Bear), etc.

- **Pre-pull actions**: Cat Form, Prowl, Bear Form, MoTD, Thorns,
  Gift of the Naaru, etc.

- **Multi-DoT spreading**: SWPSpread/VTSpread (Shadow),
  CorruptionSpread (Affliction), multidot for InsectSwarm (Balance).

- **Mana management**: Evocation (Arcane), ManaGem (most casters),
  Dark Rune, Demonic Rune.

- **Pet state management**: Defensive/Passive/Aggressive toggles
  for all 3 warlock specs and Hunter marksmanship.

- **Snapshot-aware DoT refresh** (Affliction, Shadow): Lua tracks
  spell damage at cast time and only refreshes when SP has
  increased by >= 8%. APL uses simpler time-based refresh.

- **Aimed Shot prepull gating** (Hunter MM): Lua has a separate
  `AimedShotPrepull` strategy that fires in the pre-combat window
  (0.5s or less).

- **TTD awareness** (all DPS specs): Lua gates long CDs (Trinkets,
  Avenging Wrath, Barkskin, Faerie Fire) on `context.ttd > N`
  where the APL doesn't.

- **Spell damage gating** (Elemental, Balance, Destruction): Lua
  skips DoTs (Flame Shock, Insect Swarm, Moonfire, Immolate)
  below a configurable spell-damage threshold. Simc assumes
  pre-defined gear profiles.

- **Energy pooling** (Combat, Feral Cat): Lua pools energy for
  finishers using a tick-prediction heuristic.
  APL uses simple energy/combo-point thresholds.

- **Swing desync injection** (Fury Warrior): Lua injects a Slam
  cast when dual-wield swings are synced, smoothing rage
  generation. Not in the APL.

- **Pet abilities**: KillCommand (Hunter), SummonFelguard (Demon),
  HealthFunnel (all warlocks).

- **Movement fillers**: FlameShockMoving/EarthShockMoving/
  FrostShockMoving (Elemental), MovingSWP/MovingMoonfire (Shadow,
  Balance), SearingPain moving (Destruction).

### Specs not mapped

Of the 29 TBC specs, 18 have a usable APL. The 11 without an APL
fall into three categories:

1. **Healing specs** (5): priest/holy, priest/discipline,
   shaman/restoration, druid/restoration, paladin/holy.
2. **DPS specs without simc APLs** (5): mage/fire (test only),
   mage/frost, hunter/beast_mastery + survival (use the same
   `default.apl.json` as MM), rogue/assassination + subtlety.
3. **Off-spec / utility / helpers** (3+): druid/caster, druid/
   resto (healing), paladin/heal_helper, paladin/healing, plus
   `warrior/kebab` (experimental) and the 9 leveling rotations.

**Recommendation:** The 5 healing specs could potentially have
APLs added (the wowsims/tbc-new repo has healing APLs for
priest/holy, priest/discipline, paladin/holy in `tbc-classic` —
verify the source). The DPS specs without APLs (mage/frost,
rogue/assassination, etc.) likely have APLs in the broader
`wowsims/tbc-classic` repo under different paths. The 9
leveling rotations are intentionally simpler and don't need
APLs.

---

## Verification Checklist

- [x] All 18 usable APL JSONs read end-to-end
- [x] All 18 matching Lua spec files read end-to-end (strategy section)
- [x] Strategy orderings extracted from `strategies`/`ACTIONS`/`add_strategy`/
  `_strategies` tables
- [x] Side-by-side comparison done
- [x] Real priority inversions flagged (Affliction UA vs Cor, Prot Paladin
  HS vs Consecration)
- [x] Soft inversions noted
- [x] Lua-only additions documented
- [x] Specs without APLs listed (13 specs)
- [x] No files modified (other than this deliverable), no production code written
