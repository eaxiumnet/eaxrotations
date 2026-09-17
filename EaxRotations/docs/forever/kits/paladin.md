-- docs/forever/kits/paladin.md -- WoW Forever Paladin kit research.
-- WHAT:  the only fully-revealed Forever class kit, transcribed from the
--        2026-09-13 Deep Dive panel; the build brief for the first _forever
--        spec deltas (post-beta-DBC).
-- WHEN:  updated as Blizzard's class-identity article/video series adds detail.
-- WHY:   day-1 Paladin rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: spell IDs below are DBC-verified (beta 1.60.1.69893, 2026-09-17)
--         unless marked [PROBE]; see docs/forever/dbc_runbook.md.

# Paladin — WoW Forever kit (Deep Dive 2026-09-13)

Sources: Blizzard Deep Dive recap (24303313), Massively OP report, Wowhead
Forever liveblog. Full class walkthrough; other classes follow in Blizzard's
"future videos and articles".

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Holy Strike** — level 6, instant weapon strike, Holy damage, 12s CD | New core builder/weave lane in EVERY paladin rotation incl. leveling; use early + on CD in melee range |
| **Judgment no longer consumes the seal** | Seal maintenance becomes cast-once/upkeep semantics (like an aura refresh), not re-seal-per-judgment; big rework of ret seal-twist + prot taunt loop |
| **Seal of Fury** — tank seal; favors fast weapons, grants small absorb shields, Judgment taunts while active | New prot seal + THE prot taunt lane; absorbs suggest reading via buff points (Pattern 11) once IDs exist |
| **Consecration baseline at level 20** | AoE/threat lane from 20 without talent investment; high damage+threat on first 4 targets, reduced beyond — mirror the TBC downrank/priority split |

## Holy
- **Improved Holy Strike**: reduces Holy Strike CD (fills the melee-weave lane).
- **Voice of Truth**: temporary immunity to Silence/Interrupt (anti-kick lane).
- **Reverence**: mana regen from Spirit while casting (sustains the FSR cycle;
  interacts with the repo's fsr_manager assumptions).
- **Infusion of Light**: Holy Shock / Flash of Light crits reduce Holy Light
  cast time → crit-chase + weave-Holy-Light healing priority.
- **Holy Shock on a 10s CD**: significantly more uptime than TBC's 30s —
  becomes a core rotational nuke/heal, not a niche proc.
- **Consecrated Ground**: +Holy damage taken inside Consecration (AoE amplification).
- **Light's Vigil**: high-cost CD; resets Holy Shock and triggers extra damage
  or party-wide healing through an ally (burst-window candidate; wire through
  burst_logic use_cooldowns gating).

## Protection
- **Improved Seal of Fury**: mana when Seal of Fury absorbs (sustain lane).
- **Shield Specialization**: mana on block (sustain lane).
- **Swift Judgment**: 1/min Judgment reset so a missed taunt isn't fatal
  (recovery lane; gate on last-taunt-failed signals if the engine exposes them).
- **Templar's Bulwark**: max-health-based absorb, interacts with Forbearance
  (defensive CD lane; track Forbearance to avoid waste).
- **Reckoning redesigned**: also triggers from blocks → viable for tanks
  (defense procs offense; factor into threat rotation).
- **Iron Creed**: timed Holy Strikes reduce incoming damage (active-mitigation
  weave — Holy Strike priority rises in prot).

## Retribution
- **Vindication**: reduces enemy AP while increasing the paladin's own.
- **Sacred Arbiter**: empowers Holy Strike + refreshes Judgments on target.
- **Champion of the Light**: spell damage from Intellect.
- **Instrument of the Law**: threat reduction + instant Holy Wrath.
  (Name verified against the official Deep Dive article — Wowhead's BlizzCon
  coverage misprinted this as "Hammer of Wrath"; cross-check community
  reproductions against the official text where they disagree.)
- **Twist of Light**: a new Seal echoes into the next melee swing — seal
  twisting WITHOUT a swing-timer addon (the repo's seal-twist lane can use
  engine swing timing rather than manual windows).

## Spec files to author (Phase 4, post-DBC)
- `classes/paladin/retribution_forever.lua` — Holy Strike weave, non-consuming
  Judgment seal upkeep, Twist of Light echo lane.
- `classes/paladin/protection_forever.lua` — Seal of Fury taunt, Consecration
  threat, block-Reckoning, Templar's Bulwark with Forbearance tracking.
- `classes/paladin/holy_forever.lua` — 10s Holy Shock core, Infusion of Light
  weaving, Light's Vigil burst, Spirit/FSR interplay.
  **Status (2026-09-15, pre-beta): AUTHORED** — zero-literal delta over
  holy_vanilla.lua (baseline captured via a register interceptor, zero edits
  to the baseline); Holy Shock is era-shared (`NS.PaladinSpells`), the three
  Forever-new spells resolve BY NAME through the pcall-required DBC-derived
  bridge module and stay dormant until the beta DBC lands (dbc_runbook.md
  step 3b). Battery-proven:
  all four delta lanes fire in the forever scenarios (`forever_iol_weave`,
  `forever_vigil_burst`, `forever_shock_cd`), never-inventory unchanged at 9.
- `classes/paladin/leveling_forever.lua` — Holy Strike from 6, Consecration
  from 20, first spec to feel the kit at low level.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.

## Beta DBC evidence (2026-09-17, client 1.60.1.69893)

All rows below read off the extracted DBC (`wowsims_forever.db`), not
Wowhead. Rank ladders verified complete against the kit's learn levels.

- **Holy Strike**: castable rows 678@12 / 679@6 / 680@28 / 1866@20 / 2495@36
  / 5569@44 / 10332@52 / 10333@60, every rank CategoryRecoveryTime 12000
  (kit's 12s CD confirmed). Kit "level 6" ↔ 679@6; the bridge baseline keeps
  the lowest id (678@12) per the rank-1 rule — the weave lane casts the
  max-rank mirror (10333@60).
- **Light's Vigil**: cast rows 1310911@40 / 1311590@50 / 1311595@60 (lane
  casts the max-rank 1311595); buff row 1310909. NO DBC cooldown row on any
  rank — the 180s estimate stands, tune in-game. Mechanic text confirmed
  ("next Holy Shock triggers no cooldown", party-heal / damage + refund
  branches).
- **Infusion of Light**: buff 53672 (proc-shaped aura rows; lane gates on
  it) vs talent/learn row 426065 (granted by 426179). [PROBE: confirm the
  live proc aura id in-game — 53672 vs 426065.]
- **Holy Shock**: legacy rows 20473@40 / 20929@48 / 20930@56 AND the Forever
  row 1311606@30 (new damage/heal sub-spells 1311604/1311605) — BOTH shapes
  carry CategoryRecoveryTime 10000 (kit's 10s CD confirmed on both). The
  delta lane keeps the class-map id; [PROBE: confirm the live-cast id
  in-game, 20473 vs 1311606.]
- **Seal of Fury** (prot wave): ladder 1311649@10 / 1311656@18 / 20163@25 /
  20419@34 / 20421@42 / 20422@50 / 20423@58, triggers point at the Judgement
  ids (20231 etc.); absorb text confirmed ("grants an absorb shield equal
  to $m2%"). Bridge maxrank → 20423.
- **Consecration**: true rank 1 is 26573@20 (kit's "baseline at 20"
  confirmed); the bridge baseline reports 20116@30 (lowest-id rule quirk —
  same class as the Holy Strike 678/679 case, documented not fixed).
- **Judgment** 20271: "Does not consume the Seal" text confirmed
  (RecoveryTime 10000 — note: 10s Judgement CD in the DBC).
- Also present with kit-matching rows: Voice of Truth 1310897, Reverence
  1310899, Templar's Bulwark 1311015, Iron Creed 1311033/34, Sacred Arbiter
  1311087, Vindication 440667/68.
