-- docs/forever/kits/warlock.md -- WoW Forever Warlock kit research.
-- WHAT:  seventh kit transcription, from the Icy Veins Forever warlock
--        class overview (Crix, 2026-09-15) — the RICHEST source so far:
--        ~12 hours of hands-on BlizzCon demo playtesting (level-38 build,
--        trainer inspected to 60), not just calculator-derived.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Warlock rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: NO spell IDs in this file until the Forever DBC lands (2026-09-17);
--         see docs/forever/dbc_runbook.md for the verification gate.

# Warlock — WoW Forever kit (hands-on overview 2026-09-15)

Sources: Icy Veins Forever Warlock Class Overview (Crix, 2026-09-15; ~12h
BlizzCon demo playtest, level-38 build + level-60 trainer inspection).
Demo-build data, hands-on tier: the strongest source tier short of the DBC
itself — but every claim is **unverified until the beta DBC resolves it**
(no IDs, no rank numbers below; the author explicitly expects numbers,
ranks, "even entire mechanics" to change).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Banes are no longer Curses** (Bane of Agony/Doom) | Curse-slot collision gone: maintain Bane of Agony AND Curse of the Elements/Recklessness simultaneously — dot-count and debuff-tracking lanes change shape |
| **DoTs can critically strike** | THE mechanical shift: every dot table gains crit awareness; interacts with the new Affliction crit talents (Pandemic) |
| **DoTs/drains/channels NOT affected by Haste** (current build) | Haste value collapses for Affliction (only affects hard casts); stat-weight lanes must not assume haste-scaled dots — flagged beta-verify |
| **Spellstone/Firestone rework** — weapon OILS (no longer wand-slot): Spellstone +1% haste/SP, Firestone +1% crit/crit-dmg | Imbue-slot economy: new oil lane (which oil per spec — haste vs crit) |
| **Demons scale with warlock stats**; Succubus observed best DPS, Voidwalker out-threatening tanks at 38 | Pet-power lanes gain weight; pet-choice becomes a rotation-relevant decision (Demonic Sacrifice interplay below) |
| **Pet "Move To" command** (100y) | Pet micro/QoL — no rotation-lane impact, note for pet-handler surfaces |
| **No more endless Shadow Bolt spam** — every spec got a new filler/core | The classic SB-fill rotation shape is gone in all three trees |
| Talent-rank spells persist (Siphon Life, Shadowburn, Conflagrate, Incinerate ranks seen at the 60 trainer) | Rank-ladder resolution must handle talent-granted ranks — audit-relevant |

## Affliction — the DoT+Drain identity shift
- **Drain Hope** (NEW capstone): 6s channel DoT that **+10%s the warlock's
  other Shadow DoTs on the target for 6s** — the new FILLER with an
  amplify-window: rotation now sequences drains around dot windows.
- **Improved Drains**: Drain Life/Soul +2% per active Affliction effect on
  the target (cap 6%) — **Drain Soul bonus TRIPLED below 20% health** — a
  real execute lane (count active aff-effects as a state field).
- **Soul Siphon**: drain speed +17/34/51% at the cost of Drain Life healing.
- **Pandemic**: crit-damage bonus of Corruption/BoA/BoD/DS/DL/SL/Drain Hope
  up to +100% — with critting DoTs, this is the crit-scaling payoff.
- **Malediction**: all periodic damage +5%.
- **Soul Harvesting**: 50% casting regen + regen +50% — mana model.
- **Suppression**: hit +1%/pt AND threat −4%/pt (all spells).
- **Improved Corruption**: instant + 10% damage.
- **Malevolence**: shadow spell crit chance +5%.

## Demonology — the demon-partner rework
- **Demonic Pact** (NEW capstone): **Demonic Sacrifice's buff PERSISTS when
  a different demon is summoned** (re-summoning the sacrificed one cancels)
  — a buff-juggling rotation: sacrifice Imp (+15% Shadow) or Succubus
  (+15% Fire), then summon the OTHER demon to fight alongside.
- **Demonic Sacrifice rework**: Imp → +15% Shadow dmg; Succubus → +15%
  Fire dmg — school-choice is now a spec decision (pairs with school-
  weighted rotations).
- **Demonic Energies**: pet heals from your spell damage (8/16%); Life
  Tap mana transfers up to 100% to the demon.
- **Demonic Brand**: Searing Pain threat −17/34/51%; pet's next 2 attacks
  generate high threat + bonus Fire/Shadow damage — Voidwalker tanking
  lane for world/solo play.
- **Fel Vitality**: pet HP/Mana +15% (and warlock max mana).
- **Demonic Knowledge**: SP while a demon is active.
- **Decimation**: Soul Fire CD −45/90%; vs ≤35% HP targets +6% damage,
  SF cast −40%, **no Soul Shard cost** — execute lane.

## Destruction — Fire/Shadow cross-school weaving
- **Incinerate** (NEW capstone): main Fire nuke, **+25% vs Immolate-kept
  targets** — the Immolate dependency lane (FS-style hard gate).
- **Shadow and Flame**: **Conflagrate boosts Shadow damage; Shadowburn
  boosts Fire damage** — cross-school amplification windows; at max rank
  **Conflagrate no longer consumes Immolate** and Shadowburn auto-refunds
  its shard.
- **Bane of Havoc** (NEW): 15% of damage to OTHER targets mirrors onto the
  Baned target — the two-target cleave lane (place-and-focus).
- **Fire and Brimstone**: Conflagrate crit +24%.
- **Aftermath**: Immolate initial damage up; Conflagrate dazes.
- **Ruin / Agonizing Flames / Molten Skin**: crit-damage, Searing Pain
  crit, flat −10% damage taken.

## Warlock-relevant racial detail (per-class page, hands-on)
| Race | Detail relevant to warlock rotations |
|---|---|
| Orc | **Blood Fury +10% Spell Power 15s** (on-use burst lane); Shatter Curse (defensive); Hardiness −20% stun duration; Axe Spec irrelevant (no axes) |
| Troll (NEW combo) | Berserking +10% cast speed 10s (strong for Destruction, weak for Affliction — drains/dots unhasted); Rapid Regeneration channeled 50% HP over 6s (cancels on damage/action); Beast Slaying |
| Undead | **Touch of the Grave: 5% chance on spells to drain up to 5% max HP** — IF it procs per DoT tick with no ICD it is a major Affliction throughput question (flagged; needs beta testing) |
| Human | Sword Spec **+2% spell crit while a sword is equipped** — weapon-choice-relevant for casters for the first time |
| Gnome | Eureka! (next 3 abilities −50% mana +10% dmg, 2-min CD); Expansive Mind +5% max Mana; Escape Artist +3s immunity |

## Flagged as unconfirmed (demo build)
- Haste NOT affecting dots/drains — current-build behavior; if beta changes
  it, Affliction stat lanes change.
- Touch of the Grave per-tick proc semantics (potentially huge, untested).
- Pet threat scaling (Voidwalker out-threatening tanks) — likely demo-tuned.
- Bane of Doom Doomguard spawn on expiry — flavor/summon semantics.
- All numbers/ranks from a level-38 demo build + trainer inspection.

## Spec files to author (Phase 4, post-DBC)
- `classes/warlock/affliction_forever.lua` — dot-maintenance + Drain Hope
  amplify-window sequencing, active-affliction-count state for Improved
  Drains, execute tripled Drain Soul, critting-dot table (era-shared IDs
  from `WarlockSpells`).
  **Status (2026-09-17, beta day): DAY-1 BUILT (additive + one slot drop)** —
  **"Drain Hope" does NOT exist in the beta client (any class)**: the kit's
  capstone is **WRACK 1316697** ("Tears the target apart from within, dealing
  $s1 Shadow damage every $t sec and increasing the damage they take from
  your other Shadow damage over time effects by $s2%. Lasts $d" — 6s,
  instant, no CD, 200 mana), and Improved Drains 403511 names it explicitly
  ("your Drain Life, Drain Soul, and Wrack spells"). The delta maintains
  Wrack at the head of the dot block. **Haunt** (403501@40 … 1293694@60, 15s
  CD, 12s amplify) and **Unstable Affliction** (427717@40 … 1242971@60, 18s)
  are ENGRAVING-granted ("Engrave Gloves - Haunt" / "Engrave Bracers -
  Unstable Affliction"), so those lanes gate on NS.is_spell_learned (either
  mirror id) and stay dormant un-engraved; when UA is learned the baseline's
  ImmolateDoT lane is DROPPED (the UA text: "Only one Unstable Affliction or
  Immolate per Warlock can be active on any one target").
- `classes/warlock/demonology_forever.lua` — Demonic Pact sacrifice-and-
  resummon buff juggling (school-choice lane), pet-scaling weight, Decimation
  execute, Demonic Brand pet-tank lane.
- `classes/warlock/destruction_forever.lua` — Immolate→Incinerate hard
  dependency, Shadow and Flame cross-school windows + non-consuming
  Conflagrate, Bane of Havoc cleave placement, shard-free execute.
- `classes/warlock/leveling_forever.lua` — Banes-not-curses slot math from
  early levels; pet Move To for leveling control.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Affliction names resolved (2026-09-17): Corruption 172, Bane of Agony
      980/11713, Bane of Doom 603, Drain Life 689/11700, Drain Soul
      1120/11675, Siphon Life 18265/18881, Death Coil 6789, Curse of the
      Elements 440892/1311680, Curse of Recklessness 704/11717, talents
      (Pandemic 427712, Malediction 1225177, Improved Drains 403511, Soul
      Siphon 17804, Everlasting Affliction 412689). **"Drain Hope" absent
      from the whole client** (name scan) — Wrack 1316697 is the kit's
      capstone (renamed); Curse of Agony is likewise renamed to Bane of
      Agony (same classic ids, so the class map still resolves).
- [x] Haunt / Unstable Affliction (2026-09-17): both exist as the kit
      describes but are ENGRAVING-granted (trainer `Engraving` rows), not
      trainer/talent rows — the delta gates them on is_spell_learned.
- [x] Improved Drains text CORRECTED: "Increases health drained or damage
      done by your **Drain Life, Drain Soul, and Wrack** spells by $m1%" —
      no Drain-Soul-tripled-below-20% clause (the kit's execute claim is not
      in the client text; the baseline's DrainSoulExecute lane stands on its
      own).
- [x] Banes-not-curses confirmed in shape: "Bane of Agony/Doom" and "Curse
      of the Elements/Recklessness" are separate names with separate rows
      (the slot mechanics themselves are in-game).
- [ ] Confirm DoT crit capability + Pandemic crit-damage effect shape.
- [ ] Confirm haste non-application to periodic effects (beta re-check —
      highest flip-risk claim; not DBC-readable).
- [ ] Demonic Pact: sacrifice-buff persistence across re-summon (aura
      source semantics) — this gates the whole demo rotation.
- [ ] Incinerate +25% vs Immolate; Shadow and Flame windows + non-consuming
      Conflagrate.
- [ ] Spellstone/Firestone as weapon oils (item-effect shape, not wand).
- [ ] Talent-granted ranks (Siphon Life etc.) resolve in the rank ladders.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
