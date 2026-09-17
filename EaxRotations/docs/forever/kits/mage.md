-- docs/forever/kits/mage.md -- WoW Forever Mage kit research.
-- WHAT:  fifth kit transcription, from the Icy Veins Forever mage class
--        overview (Wrdlbrmpft, updated 2026-09-13) — talent-detail pages
--        for all three specs; page predates the series' Sep-15 spell pass.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Mage rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: spell IDs below are DBC-verified (beta 1.60.1.69893, 2026-09-17)
--         unless marked [PROBE]; see docs/forever/dbc_runbook.md.

# Mage — WoW Forever kit (class overview 2026-09-13)

Sources: Icy Veins Forever Mage Class Overview (Wrdlbrmpft/Arcanaenus,
2026-09-13 — talent sections are unusually detailed for this vintage; still
re-check for a Sep-15+ changelog entry). Community reproduction of Blizzard
data: plan lanes on it, but every claim is **unverified until the beta DBC
resolves it** (no IDs, no rank numbers below).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Frostfire Bolt** — new spell: Frost + Fire bolt, damage over 9s + slow; deals the school the target has LOWER resistance to | The Fire-vs-Frost school choice becomes dynamic per target (resist-aware spell lane — new context field). Potential to re-open the hybrid Frostfire build as a full spec |
| **Ice Lance** — instant, low damage, **300% vs frozen targets** | Frozen-burst lane (pairs with FoF); known TBC-Anniversary backport precedent — verify the Forever version independently |
| **Hot Streak** — non-periodic Fire crits (Fireball/Frostfire/Fire Blast/Scorch) stack up to 3×, 15s; each stack cuts Pyroblast cast −25% (4.5/3/1.5s); consumed on cast | Brand-new stacking mechanic: crit-driven Pyro lanes with stack counting (Pattern 11 buff-points read). Changes Fire's crit value and rotation shape wholesale |
| **Missile Barrage** — Arcane Blast 40% / Fireball/Frostbolt/Frostfire 20% chance: next Arcane Missiles costs 0 mana and fires every 0.5s | Proc-lane for AM bursts; cross-spec triggers mean fire/frost casts feed arcane procs in a hybrid build |
| New mage races: Skyborne (Alliance), Orc (Horde) | Orc mage = new combo; race-choice math below |

## Arcane — finally a spec
Historically unplayable in Vanilla; the article expects it competitive:
- **Arcane Blast** — THE arcane damage spell: stacks to 4, each stack
  **+10% damage of all other spells + 175% AB damage**; stack expires at 8s
  or on casting any other spell. Rotation-shaping: a stack-management loop
  (nuke windows vs filler weaving; any non-AB cast drops the stacks).
- **Missile Barrage** (above) — free fast AM as the proc payoff.
- **Arcane Meditation**: 50% regen while casting (was 15%) — mana model.
- **Arcane Mind**: +10% Intellect AND +100% arcane crit damage bonus.
- **Arcane Impact**: +6% crit to ALL arcane spells (was Arcane Explosion only).
- **Arcane Focus**: 5% arcane hit (was 10%) — hit-cap math changes.
- **Improved Channeling**: 100% pushback protection AM / 70% AB (replaces
  Improved Arcane Missiles).
- **Arcane Subtlety**: −16 target resist (all spells) + −30% arcane threat
  (was −40%) — resist-shave and threat-lane rebalance.
- **Arcane Shielding**: Mana Shield −34% mana lost per damage taken; Mage
  Armor +50% resist — defensive-armor lane rebalance.
- **Arcane Geometry**: +6y range on arcane spells.
- **Arcane Resilience**: now 2 talent points.

## Fire
- **Hot Streak** (above) — the defining mechanic; Pyro becomes a
  crit-chained finisher rather than an opener nuke.
- **Wake of Fire** (NEW, replaces Improved Fire Blast + Incinerate):
  Fire Blast −2s CD; killing a non-trivial target grants the next Fire
  Blast within 20s +50% crit — which can itself proc Hot Streak. Mobility
  (cheap FBlast weaving) + kill-chain lane.
- **Incineration**: +6% crit to Fire Blast, Ice Lance, Arcane Blast, Scorch.
- **Improved Fireball**: now also affects Frostfire Bolt.
- **Pyroblast**: damage increased slightly.
- **Blast Wave**: damage increased slightly.

## Frost
- **Fingers of Frost**: chill effects 30% chance to grant FoF (15s) — next
  spell treats the target as frozen. Ice Lance's 300% payoff lane.
- **Shatter**: 50% crit vs frozen in 3 points (was 5) and no longer depends
  on Improved Frost Nova — cheaper, freer.
- **Winter's Chill**: now benefits ONLY Frostbolt + Ice Lance (was all
  crit-capable frost spells) — snapshot logic narrows.
- **Improved Blizzard**: chill now 45% for 1.5s (was 65% for 2s) — AoE
  crowd-control window shrinks; kite-loop timing changes.
- **Elemental Precision**: 5% hit Frost+Fire (was 6%) — hit-cap math.

## Mage-relevant racial detail (per-class page; numbers = press tier)
| Race | Detail relevant to mage rotations |
|---|---|
| Human | Sword Spec +2% crit WITH SWORD (melee-caster hybrid oddity — best Patchwerk-ish damage claim); Will to Survive (PvP); Human Spirit +5% |
| Gnome | **Eureka!** — cost cut + 10% dmg/heal on next 3 abilities (burst CD lane); Expansive Mind +5% Mana; Escape Artist root/snare immunity |
| Troll | Berserking +10% haste 10s (on-use burst lane); Beast Slaying +5% vs beasts (raids have beasts); Rapid Regeneration |
| Orc (NEW combo) | Blood Fury +10% AP AND Spell Power 15s (on-use burst); Shatter Curse (defensive); Axe Spec irrelevant for mages |
| Undead | Will of the Forsaken (no immunity); Touch of the Grave 5% chance to restore 5% max HP (page's math: minor — do not encode as a lane) |
| Skyborne Alliance | Read Ley Line +100% health/mana regen near ley lines (positioning-dependent); Wind Blessed +1% all haste incl. spell haste |

Cross-page contradiction: Blood Fury's numbers differ per class page
(AP-only vs AP+SP, durations vary) — flagged; resolve from the DBC.

## Flagged as unconfirmed
- Frostfire Bolt's school-swap behavior described as "was designed to" —
  WotLK description, not confirmed for Forever; the lower-resist mechanic
  needs DBC proof before any school-choice lane encodes it.
- QoL wishlist (multi-charge Mana Gems, water/food tables, raid-wide AI)
  is speculation — not a kit claim.
- Page predates the Sep-15 series spell pass — re-check for updates.

## Spec files to author (Phase 4, post-DBC)
- `classes/mage/arcane_forever.lua` — Arcane Blast 4-stack management loop
  (stack reads via Pattern 11), Missile Barrage free-AM proc lane,
  Arcane Meditation mana model.
- `classes/mage/fire_forever.lua` — Hot Streak 3-stack Pyro finisher lanes,
  Wake of Fire kill-chain Fire Blast, Frostfire school-swap option.
- `classes/mage/frost_forever.lua` — FoF→Ice Lance 300% burst lane,
  cheaper Shatter, narrowed Winter's Chill snapshot, Blizzard chill-window
  retiming.
- `classes/mage/leveling_forever.lua` — school-swap Frostfire for
  resist-varying leveling targets; Hot Streak availability timing.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Resolve every named ability above BY NAME in the Forever bridge
      (2026-09-17: Hot Streak 48108/400625, Arcane Blast 400573/400574+,
      Missile Barrage 400588/400589, Wake of Fire 11078/1312934, Frostfire
      Bolt 401502 — all resolve; role splits documented below).
- [x] Arcane Blast (partial 2026-09-17): +175%/+10% effect split CONFIRMED
      in the 400573 aura rows (EffectBasePointsF 175.0 / 10.0); nuke text
      references the 400573 stack rows by id; expiry-on-other-spell text
      CONFIRMED ("or until a[nother spell is cast]"). OPEN: stack cap (kit:
      4) + duration live in 400573's aura points — in-game buff-points read.
- [x] Hot Streak (partial 2026-09-17): buff row identified as 400625 (the
      Forever stacking proc: "grant Hot Streak ... stacking up to $s2
      times", granted by talent 400624; lane gates on the buff mirror).
      CONTRADICTION RECORDED: the kit's "3-stack" number is unconfirmed
      ($s2 lives in aura points), and the legacy 48108 row says "2 spell
      criticals in a row" — do NOT overwrite the kit number from the legacy
      row. OPEN: stack cap + 15s duration + per-stack Pyro reduction +
      consumption-on-cast, all in-game.
- [x] Frostfire Bolt: dual-school CONFIRMED in DBC (SchoolMask 20 =
      frost+fire on 401502; castable Effect-2 row present). School-choice
      lanes stay un-authored pending the lower-resist mechanic proof
      (in-gameresist behavior, not DBC-shape).
- [ ] Ice Lance: confirm 300% frozen multiplier + FoF interaction.
- [x] Missile Barrage: trigger-set STRUCTURE confirmed in 400588's text
      (Arcane Blast $m1% chance, Fireball/Frostbolt/Frostfire Bolt halved
      via ${$m1/2} — matches the kit's AB 40% / others 20% shape); exact
      $m1 lives in aura points. Proc buff is 400589 (triggered BY 400588);
      lane gates on the buff mirror.
- [x] Wake of Fire (partial 2026-09-17): buff 11078 + window 1312934
      ("Fire Blast critical strike chance increased") both resolve; full
      mechanic text confirmed (FB CDR + kill-triggered FB crit window with
      duration ref $1312934d). Lane stays ABSENT per the file's discipline
      (trigger wiring unconfirmed) — add it once in-game observation shows
      what applies the window on kill.
- [ ] Re-read the page for the Sep-15+ spell/talent pass and fold in
      anything new.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
