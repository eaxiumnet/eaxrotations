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
- `classes/rogue/combat_forever.lua` — Restless Blades CD-recycling lane
  (spenders recharge cooldowns), Puncturing Wounds weapon flexibility,
  Hack-and-Slash per-weapon behavior.
- `classes/rogue/subtlety_forever.lua` — Hemorrhage→Rupture amplifier loop,
  Thousand Cuts stack engine, Cutthroat free-Ambush bursts, Quietus
  execute-ish lane.
- `classes/rogue/leveling_forever.lua` — constant-regen energy reshapes
  early leveling pace; Mutilate from early levels (Assassination leveling).

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [ ] Resolve every named ability above BY NAME in the Forever bridge
      (zero-literal rule); record IDs into `RogueSpells` only then.
- [ ] ENERGY MODEL: confirm constant regen vs tick (highest priority —
      re-derives every threshold lane).
- [ ] Restless Blades: CD-reduction effect shape + CD list.
- [ ] Venom: CP-scaled duration + poison-damage/application buffs.
- [ ] Thousand Cuts: stack cap 5 + which generators it discounts.
- [ ] Hemorrhage's Rupture-vulnerability debuff (aura family).
- [ ] Cutthroat stealth-free Ambush proc.
- [ ] Improved Expose Armor CP-refund condition.
- [ ] 1h axe equip-ability for rogues.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
