-- docs/forever/kits/rogue.md -- WoW Forever Rogue kit research.
-- WHAT:  ninth (final) kit transcription, from the Icy Veins Forever rogue
--        class overview (Sellin, updated 2026-09-15 with BlizzCon
--        playtest detail) — headline: energy is now constant-regen.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Rogue rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: NO spell IDs in this file until the Forever DBC lands (2026-09-17);
--         see docs/forever/dbc_runbook.md for the verification gate.

# Rogue — WoW Forever kit (class overview 2026-09-15)

Sources: Icy Veins Forever Rogue Class Overview (Sellin, 2026-09-15
playtest-detail update), from the talent calculator + BlizzCon coverage.
Community reproduction of Blizzard data: plan lanes on it, but every claim
is **unverified until the beta DBC resolves it** (no IDs, no rank numbers
below).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Energy: constant regeneration** (was tick-pulse) | THE structural change: the tick-clock sync logic in every rogue file dies; rotation pace rises (author predicts high-APM); energy-threshold lanes re-derive on a smooth curve |
| **1-handed Axes usable by Rogues** (Orc Axe Spec applies) | Weapon-choice lane widens |
| Tauren remains the only non-rogue Classic race | Combo validation note |

## Combat
- **Puncturing Wounds** (NEW, tier 2): benefits dagger/fist CP generation —
  weapon-agnostic Combat builds become viable (breaks the slow-sword
  assumption baked into combat lanes).
- **Restless Blades**: each combo point SPENT reduces the CD of Adrenaline
  Rush, Blade Flurry, Evasion, Sprint, Vanish by 2s — CD lanes become
  rotation-coupled (spenders now actively recharge cooldowns; defensive
  CDs can be used pre-emptively).
- **Hack and Slash**: per-weapon-type bonuses — swords/axes: extra-swing
  proc; daggers/fists: crit chance; maces: armor penetration — weapon
  choice changes rotation behavior, not just stats.

## Assassination — the poison-burst spec
- **Mutilate** (NEW): 2-combo-point generator, bonus damage vs poisoned
  targets — faster CP pace; poisoned-target check becomes a lane gate.
- **Venom** (NEW capstone): spend combo points → **+30% poison damage +
  10% poison-application chance**, duration scales with CP spent — a
  spendable burst WINDOW (energy + CP pooling around it, like the old
  Snapshot-mindset but interactive).
- **Improved Expose Armor**: cheaper AND refunds a CP at 5 CP — armor
  debuff maintenance stops being a DPS sacrifice.
- **Cold Blood** moved earlier in the tree — guaranteed-crit builds open up.
- **Improved Kidney Shot**: personal damage up vs the target (scale with
  points) — a control button becomes a damage lane.

## Subtlety — the Rupture engine
- **Hemorrhage reworked**: damage (more with dagger) + debuff making the
  target take **+15% damage from Rupture** — Hemorrhage becomes the
  Rupture-amplifier setup lane.
- **Thousand Cuts**: Rupture ticks reduce the energy cost of Hemorrhage or
  Backstab by 3, **stacking to 5** — keep-Rupture-up is now the energy
  engine (stack read, Pattern 11).
- **Cutthroat**: Backstab procs a stealth-free Ambush (chance scales) —
  burst-window lane; Backstab becomes the default Subtlety generator.
- **Quietus**: +damage vs ≤35% health targets — soft execute lane (not a
  true execute; compare warriors).

## Rogue-relevant racial detail (per-class page)
Orc (**Blood Fury +10% AP** — pairs with Adrenaline Rush; Axe Spec now
rogue-relevant via 1h axes; Shatter Curse; Hardiness), Troll (Berserking
static +10% attack speed 10s — pairs with Venom windows; Rapid
Regeneration), Human (Will to Survive; Sword Spec +2% crit), Dwarf (Mace
Spec; Big Game Hunter; Stoneform physical reduction), Gnome (Eureka!
burst window; Escape Artist), Night Elf (Elune's Light +10% crit — pairs
with Adrenaline Rush), Skyborne (Wind Blessed +1% haste — poison-proc
frequency), Undead (Touch of the Grave self-sustain; WotF rework).
Numbers = press tier; cross-page Blood Fury contradiction still stands
(resolve from DBC).

## Flagged as unconfirmed
- **Constant-regen energy** — described in the article's outlook section,
  not the spell-changes list; the single highest-impact claim for rogue
  code. Beta day-1 probe.
- Restless Blades exact per-CP discount (2s) and eligible-CD list.
- Venom CP-duration scaling table.
- Cutthroat proc chance + whether the free Ambush keeps stealth modifiers.

## Spec files to author (Phase 4, post-DBC)
- `classes/rogue/assassination_forever.lua` — Mutilate fast-CP generation,
  Venom pooling/spend window (CP-duration scaling), Expose Armor cheap
  maintenance, poison-target gating.
  **Status (2026-09-17, beta day): DAY-1 BUILT (3 lanes, additive; energy
  probe still unconfirmed so the vanilla energy shape is kept)** — (1)
  Mutilate: the maxrank bridge row (ladder 1310707@30 / 399956@40 /
  1241582@50 / 1241584@60) above the baseline builder, gated on both-hand
  daggers (shared/dagger_set, TBC-sibling precedent), energy >= 60 and
  combo < 5; the poison state is reported in the tag, NOT gated — the DBC
  text makes the +20% bonus damage, not a usability requirement, and 2 CP
  beats Sinister Strike's 1 even unbuffed. **The client text carries NO
  "must be behind" clause** (unlike the TBC 34413 row) — recorded as an
  in-game probe. (2) Venom: the poison window (+30% poison damage / +10%
  application chance confirmed by the effect rows) fired at 5 CP when the
  buff is down or within 4s of expiry, leading the finisher block. (3)
  Improved Expose Armor: with the talent (effect rows: -10 energy, 2-CP
  refund at 5 CP) the baseline's assigned armor-debuff lane is upgraded to
  the 5-CP refund cast with a refresh window.
- `classes/rogue/combat_forever.lua` — Restless Blades CD-recycling lane
  (spenders recharge cooldowns), Puncturing Wounds weapon flexibility,
  Hack-and-Slash per-weapon behavior.
- `classes/rogue/subtlety_forever.lua` — Hemorrhage→Rupture amplifier loop,
  Thousand Cuts stack engine, Cutthroat free-Ambush bursts, Quietus
  execute-ish lane.
  **Status (2026-09-17, beta day): DAY-1 BUILT (2 lanes, additive)** — (1)
  the Thousand Cuts energy engine: with Rupture-tick stacks on (the applied
  row 1310723, pinned in the builder's BUFF_OVERRIDES — the baseline 1310721
  is the talent text), the lane fires the discounted Hemorrhage when energy
  + 3/stack covers both the 35 cost and the baseline's 40-energy pooling
  floor (e.g. 25 energy at 5 stacks). (2) the Cutthroat stealth-free Ambush:
  the proc (462707, pinned; the baseline 424980 is the grant row) + behind +
  main-hand dagger + 60 energy, above the baseline's stealth Ambush opener.
  Hemorrhage's +Rupture-damage amplifier (16511) is already maintained by the
  baseline's HemorrhageDebuff lane; Quietus 1310728 is a passive on the
  generators the rotation already casts — no lane, recorded as a probe.
- `classes/rogue/leveling_forever.lua` — constant-regen energy reshapes
  early leveling pace; Mutilate from early levels (Assassination leveling).

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Resolve every named ability above BY NAME in the Forever bridge
      (2026-09-17, assassin day-1): Mutilate ladder 1310707@30 / 399956@40 /
      1241582@50 / 1241584@60, Venom 1310703@40, Improved Expose Armor 14168,
      Improved Kidney Shot 14174, Cold Blood 14177, Thousand Cuts 1310721 +
      aura 1310723, Hemorrhage 16511, Cut to the Chase 432271, Vigor 14983,
      the poison debuff rows (Deadly 2818 / Crippling 3408 / Wound 13218) —
      all resolve.
- [ ] ENERGY MODEL: confirm constant regen vs tick (highest priority —
      re-derives every threshold lane). Still unconfirmed (P2 #3): the #20
      delta keeps the vanilla energy shape (real-cost builder gate, pooling
      flag on the finishers).
- [x] Venom: CP-scaled duration + poison-damage/application buffs
      (2026-09-17, assassin day-1) — 1310703's effect rows confirm +30%
      poison damage (aura 108 x2) and +10% application chance (aura 107);
      the duration text carries the 9/12/15/18/21s CP ladder. The #20 lane
      spends at 5 CP and refreshes inside 4s.
- [x] Improved Expose Armor CP-refund condition (2026-09-17, assassin
      day-1) — 14168's effect rows confirm -10 energy and the 2-CP refund at
      5 CP; the #20 lane gates on the talent + the 5-CP condition + the
      baseline's assignment setting.
- [x] Mutilate (2026-09-17, assassin day-1): effect rows = 2 combo points +
      two weapon-strike triggers + a 20% dummy vs poisoned; the client text
      has NO "must be behind" clause (the TBC 34413 row does) — the #20 lane
      is positional-free. [PROBE: confirm in-game that a front-facing
      Mutilate lands; if the client enforces behind, add the TBC positional
      gate.]
- [ ] Restless Blades: CD-reduction effect shape + CD list. [combat delta]
- [x] Thousand Cuts: stack cap 5 + which generators it discounts (2026-09-17,
      subtlety day-1) — 1310721's text names Hemorrhage AND Backstab, -3
      energy per stack ("$1310723s1"), cap "$1310723u" (kit: 5); the applied
      stack row 1310723 is pinned in BUFF_OVERRIDES. [PROBE: confirm the
      in-game cap and that the discount applies to Backstab's own gate.]
- [x] Hemorrhage's Rupture-vulnerability debuff (2026-09-17, subtlety
      day-1): 16511 carries the "+$m3% Rupture damage" amplifier text; the
      baseline's HemorrhageDebuff lane already maintains it — no delta lane.
- [x] Cutthroat stealth-free Ambush proc (2026-09-17, subtlety day-1):
      462708 ("Your Backstab has a $m1% chance to cause your next Ambush
      within $462707d to not require Stealth") applies the proc 462707 —
      pinned in BUFF_OVERRIDES; the #22 lane consumes it. [PROBE: the m1%
      chance and whether the proc's Ambush respects the behind/dagger
      requirements (the lane assumes yes).]
- [ ] Quietus values (1310728: "$m1% more damage below $m2% health") — the
      passive is recorded; confirm the in-game numbers.
- [ ] 1h axe equip-ability for rogues.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
