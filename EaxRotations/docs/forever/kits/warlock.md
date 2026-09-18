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
  **Status (2026-09-17, beta day): DAY-1 BUILT (2 lanes)** — (1) the Demonic
  Pact PARTNER lane: while a Demonic Sacrifice school aura is up (Burning
  Shadow 18789 = sacrificed Imp / Touch of Fire 18791 = sacrificed Succubus)
  and no living demon is out, it summons the OTHER demon through the bridge's
  maxrank mirror (the sacrificed pet itself is the one summon that would
  cancel the aura — the client text's own rule). Dormant unless Demonic Pact
  425464 is learned. (2) The DECIMATION lane: while the proc buff (440873,
  pinned in the builder's BUFF_OVERRIDES — the 440870 row is the talent text)
  is up, Soul Fire is cast on the target above the baseline's Shadow Bolt
  filler (the Shadow Bolt / Searing Pain trigger rides the existing filler).
  **Demonic Sacrifice itself (18788) has no SpellClassOptions row on this
  client**, so the bridge's player-spell index cannot carry it — the
  sacrifice cast stays the pre-pull MANUAL choice the vanilla baseline already
  documents (DS/Ruin); the delta automates the half the new mechanic created.
  OPEN (in-game): whether DS is trainer/engraving-granted at 60; Demonic Brand
  pet-tank lane (Searing Pain threat −% + pet consumes the brand — no threat
  API data, world/solo concern).
- `classes/warlock/destruction_forever.lua` — Immolate→Incinerate hard
  dependency, Shadow and Flame cross-school windows + non-consuming
  Conflagrate, Bane of Havoc cleave placement, shard-free execute.
  **Status (2026-09-17, beta day): DAY-1 BUILT (3 lanes, additive)** — (1)
  Incinerate (412758@40 / 1293812@50 / 1293813@60, the +25% dummy confirmed)
  with the hard Immolate-kept gate, above the baseline Shadow Bolt filler;
  (2) the Shadow and Flame window lane: the fire window (426311 "Flame")
  picks Incinerate, the shadow window (1293816 "Shadow") picks Shadow Bolt —
  both window rows are CLASS-LESS auras and now ride the builder's new
  CLASS_LESS_BUFF_NAMES pin; (3) Bane of Havoc (1225228, the 15%-mirror aura)
  placed on an OFF-target while >= 2 enemies live, respecting the one-Bane
  limit. **KIT CORRECTIONS**: the max-rank Conflagrate (18932) STILL reads
  "consuming your Immolate effect" — the no-consume effects are **Backdraft
  427713** ("no longer consumes Immolate", + the 427714 haste buff) and
  Shadow and Flame's 20% chance; the Shadowburn shard refund is likewise an
  S&F *chance*, not a max-rank guarantee. Neither needs a lane (the
  baseline's Conflagrate/Shadowburn lanes already cast on their own gates).
  OPEN (in-game): the Bane of Havoc 1-target enforcement + whether a Bane
  competes with the Curse slot on the same target.
- `classes/warlock/leveling_forever.lua` — Banes-not-curses slot math from
  early levels; pet Move To for leveling control.
  **Status (2026-09-17, beta day): DAY-1 BUILT (1 lane)** — the
  Banes-not-curses pair: with Banes and Curses in separate families (the
  family texts name Banes, not Curses), the baseline's Bane of Agony dot
  lane stays and the delta applies CURSE OF THE ELEMENTS alongside it
  (bridge 440892/1311680) directly below the Bane lane — the amp requires
  the Bane to be rolling first, respects a 25% mana floor and a 2s refresh
  window, and mirrors the baseline's leveling context guard. The Bane read
  uses the class-map CurseOfAgony ladder (every leveling rank). The kit's
  pet-Move-To half is explicitly "no rotation-lane impact" (the API exposes
  no move command) — recorded, no lane. [PROBE (P3): the in-game slot
  mechanics — if a Bane and a Curse share one slot after all, the amp lane
  would churn against the baseline's Bane lane and must be removed.]

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
- [x] Confirm DoT crit capability + Pandemic crit-damage effect shape.
- [ ] Confirm haste non-application to periodic effects (beta re-check —
      highest flip-risk claim; not DBC-readable).
- [x] Demonic Pact: sacrifice-buff persistence across re-summon (2026-09-17,
      demo day-1) — RESOLVED by the client text: 425464 reads "Your Demonic
      Sacrifice effect is no longer cancelled by summoning a different Demon
      pet. Resummoning the sacrificed pet will still cancel the effect." The
      #17 partner lane encodes exactly that rule (summon the OTHER demon of
      the sacrifice aura). The sacrifice auras are separately named rows —
      Burning Shadow 18789 (Imp) and Touch of Fire 18791 (Succubus) — so the
      lane reads the aura's own name. [PROBE: confirm in-game that a third
      demon (Voidwalker) may be summoned without cancelling either aura.]
- [x] Decimation (2026-09-17, demo day-1): 440870's text confirms the
      sub-35% trigger ("When you cast Shadow Bolt or Searing Pain on an enemy
      below $m3% health, they deal $m4% increased damage, and for the next
      $440873d your Soul Fire spell has its cast time reduced by $m1% and
      costs no Soul Shards"); the applied proc 440873 is now pinned in the
      builder's BUFF_OVERRIDES. Soul Fire itself carries no RecoveryTime row
      (1.5s StartRecovery only), so the lane gates on the proc + spell_ready.
      [PROBE: the exact $m3/$m4/$m1 values and whether the proc survives
      leaving execute range.]
- [x] Demonic Sacrifice (2026-09-17): the cast row 18788 exists but has **no
      SpellClassOptions row**, so the bridge's class-filtered index cannot
      carry it (mirrors the 2.5.5 note for class-less racial actives). The
      sacrifice cast stays manual; recorded again under the demo probes.
- [ ] Demonic Brand pet-tank window (Searing Pain threat −17/34/51%, pet's
      next 2 attacks "generate high threat") — no threat API; world/solo lane,
      not automated on day 1.
- [x] Incinerate +25% vs Immolate; Shadow and Flame windows + non-consuming
      Conflagrate (2026-09-17, destro day-1): Incinerate's effect dump shows
      the +25% dummy (effect 3, base 25) and the ladder 412758/1293812/
      1293813 — the #18 lane gates on Immolate. S&F 426316 applies the two
      windows **1293816 ("Shadow")** / **426311 ("Flame")**, both aura 79
      +10% and both CLASS-LESS (they now ride the builder's
      CLASS_LESS_BUFF_NAMES). The no-consume claim is CORRECTED: the
      max-rank Conflagrate still consumes; Backdraft 427713 is the
      unconditional no-consume (+haste 427714), S&F is a 20% chance.
- [x] Bane of Havoc (2026-09-17, destro day-1): 1225228 is the cast/aura row
      (effect 6 dummy aura base 15 = the 15% mirror), text "Bane of Havoc is
      limited to 1 target, and only one Bane per Warlock can be active on any
      one target". The #18 lane banes a NON-focus enemy and aborts the scan
      when the one Bane is already placed. [PROBE: in-game confirm a Bane
      does not collide with the Curse slot, and that the mirror damage
      attributes correctly.]
- [ ] Spellstone/Firestone as weapon oils (item-effect shape, not wand).
- [ ] Talent-granted ranks (Siphon Life etc.) resolve in the rank ladders.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
