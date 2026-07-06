# EaxRotations v2.4.0 — Release Notes

**Release Date:** 2026-07-05
**Theme:** Wowsims APL Alignment — every DPS spec grounded in authoritative theorycraft

---

## 🎯 Headline: Wowsims APL Alignment

**Every DPS spec has been audited against the authoritative wowsims TBC APLs
(`wowsims/tbc-new` and `wowsims/classic` GitHub repositories) and either improved
to match or verified as already correct.**

This is the most significant fidelity pass in the project's history. 15 specs
reviewed, 10 improved, 5 verified. All changes backed by the same simulation
data that tops the TBC theorycraft leaderboards.

---

## ✨ New Shared Module: Cooldown Planner

**`shared/cooldown_planner_sylvanas.lua`** — detects Bloodlust/Heroism, TBC
Drums, and major offensive cooldowns, then exposes `should_fire_offensive()`
so every spec can align personal cooldowns with power windows.

- Detects: Arcane Power, Icy Veins, Avenging Wrath, Bestial Wrath,
  Shamanistic Rage, Elemental Mastery, Power Infusion, Death Wish, Recklessness.
- Timeout fallback (45s) and TTD fallback (≤15s) prevent CDs from rotting.
- `trinket_align_with_cds = false` setting restores legacy "fire on cooldown".

---

## 🔥 Spec Improvements (wowsims-aligned)

### Mage Arcane — Burn/Conserve Rotation
- **Conserve phase**: AB3→Frostbolt to maintain the Arcane Blast buff cheaply
  (matches wowsims `ConserveRotation` group).
- **Mana Gem**: fires when `maxMana > currentMana + gemRestore + regen`
  (3100 with Serpent-Coil Braid, 2500 without).
- **Evocation**: fires only when Arcane Power AND Icy Veins are inactive and
  mana < 20%.
- **Presence of Mind**: fires at end of AP window (AP remaining ≤ AB cast time)
  for one more instant Arcane Blast.
- **Fire Blast execute**: fires when target TTD < AB cast time (instant > cast).
- Arcane Missiles: Clearcasting consumer ONLY (removed obsolete filler role).

### Warlock Affliction — Execute + Priority Fixes
- **Drain Soul**: fires at target HP ≤ 5% (wowsims execute) alongside the
  existing shard-capture path.
- **Shadowburn**: new execute strategy at target HP ≤ 5%, above Shadow Bolt.
- **Immolate**: moved from priority #13 → #8 (right after Siphon Life),
  matching wowsims APL: Corruption > UA > Siphon Life > Immolate.

### Hunter (all 3 specs) — Viper/Hawk + Aimed Shot Opener
- **Aspect of the Viper**: enters at **5% mana** (was 20%).
- **Aspect of the Hawk**: recovers at **25% mana** (was 30%).
- **Marksmanship Aimed Shot**: fires at ≤ 0.5s into combat when Serpent Sting
  is not active (wowsims opener). Replaces the old hard-disable.

### Priest Shadow — Shadowfiend + Starshards
- **Shadowfiend timing**: short fight (<120s) fires early at ≤45% mana; long
  fight fires only when VT is active and ≥1.5s remaining.
- **Starshards moved above Mind Flay** — was dead code (Mind Flay always
  matched first, so Starshards never fired for Night Elf priests). **Critical
  bug fix.**

### Warrior Fury — Overpower Weaving (opt-in)
- Added `Overpower` strategy back to Fury with wowsims "Overpower Weaving"
  conditions: swap to Battle Stance when Overpower procs and BT+WW are both
  ≥1.5s from ready, cast Overpower, swap back.
- Gated behind `fury_use_overpower` setting (default off).
- Death Wish and Recklessness now align with Bloodlust/Drums/major CDs.

### Druid Balance — Starfire Primary + Mana Gem
- **Starfire is now the primary nuke** (was Wrath — backwards vs wowsims).
  Wrath is mana-conservation only (fires when mana < 40%).
- **Mana Gem** strategy added (wowsims-aligned restore calculation).

### Druid Feral Cat — Powershift Threshold
- Powershift energy threshold raised from 20 → 25 (wowsims uses 30).

### Rogue Combat — Blade Flurry + Adrenaline Rush
- **Blade Flurry** now requires Slice and Dice active (don't waste BF time
  without the attack-speed buff).
- **Adrenaline Rush** now fires at ≤40 energy (when energy is needed, not cap).

### Major-CD Alignment Rollout
- **Fury Warrior**: Death Wish, Recklessness align with Bloodlust/Drums.
- **Enhancement Shaman**: Shamanistic Rage fires during power windows.
- **Fire Mage**: Combustion waits for power window + 5-stack Scorch.
- **Beast Mastery Hunter**: Bestial Wrath aligns with power windows.
- **Shadow Priest / Affliction Warlock**: racials align with power windows.

---

## ✅ Verified Specs (already correct)

| Spec | Key Mechanic | Status |
|------|-------------|--------|
| Fire Mage | Combustion after 5-stack Scorch | ✅ Correct |
| Ret Paladin | Seal twisting (SoC→SoB) | ✅ Correct |
| Arms Warrior | Slam weaving after auto-swing | ✅ Correct |
| Enhancement Shaman | Stormstrike top priority | ✅ Correct |
| Assassination Rogue | Mutilate/Envenom/Rupture cycle | ✅ Correct |
| Subtlety Rogue | Hemo/Shadowstep openers | ✅ Correct |

---

## 🐛 Bug Fixes

- **Hunter Marksmanship**: Bestial Wrath now gated on `is_spell_learned` — a MM
  build can no longer attempt the BM 31-point talent.
- **Shadow Priest Starshards**: was dead code below Mind Flay filler — moved
  above so it actually fires for Night Elves.
- **Warlock Healthstone**: spec-level healthstone now respects master
  `use_auto_consumables` and `use_healthstones` toggles.
- **Rotation Toggle**: turning the rotation OFF now stays OFF after UI reload.

---

## 📊 Quality Gates

| Gate | Result |
|------|--------|
| Rotation test suites | **220/220 pass** (+1 new: cooldown planner) |
| Leveling test suites | **13/13 pass** |
| Lua syntax (`luac -p`) | **443/443 clean** |
| Vanilla spell ID audit | **31/31 clean** (no TBC contamination) |
| Sylvanas spell ID audit | **61/61 clean** (all exist in DBC 2.5.5.68101) |

---

## 🔄 Upgrade Notes

- **No settings reset required** — all changes are backward compatible.
- New opt-in settings (all default to safe values):
  - `fury_use_overpower` (default off) — enable Fury Overpower weaving.
  - `trinket_align_with_cds` (default true) — set false for legacy trinket behavior.
- Behavior changes that upgrade automatically:
  - Hunter Viper/Hawk thresholds (5%/25%).
  - Balance Druid defaults to Starfire.
  - All major CDs now align with Bloodlust/Drums windows.

---

## 📦 Installation

1. Download `EaxRotations-v2.4.0.zip`
2. Delete your current `EaxRotations` folder
3. Extract the new one in its place
4. Your settings carry over automatically — no reset needed

---

## 🔗 Sources

All rotation changes grounded in:
- **wowsims/tbc-new** — `ui/<class>/dps/apls/*.apl.json`
- **wowsims/classic** — `ui/<class>/apls/*.apl.json`
- **DBC** — `wowheadScrape/dbc_extract/wowsims.db` (client 2.5.5.68101)

---

*Questions? Report issues at: https://github.com/eaxiumnet/eaxrotations/issues*
