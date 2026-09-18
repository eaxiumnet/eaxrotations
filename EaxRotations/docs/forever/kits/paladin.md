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
- **Light's Vigil**: party-heal / damage mark on a 6s category CD (beta DBC
  re-probe 2026-09-17: CategoryRecoveryTime 6000 on all ranks; 1340 mana,
  1.5s cast, 30s aura) — a rotational mark, not a burst CD: mark the target
  you are about to Holy Shock so the shock triggers no cooldown and pays the
  party heal (ally) or damage + 76% mana refund (enemy).

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
  **Not a holy spell (DBC 2026-09-17)**: the beta client carries NO
  SpellClassOptions row for 1310735 (class NULL) and its BaseLevel is 0, so
  the bridge generator excludes it as a non-player spell; the trainer table
  files it under the Retribution skill line. It is therefore a ret-only
  passive and is NOT wired into holy_forever.lua (a by-name lane could never
  resolve on the real bridge — battery-only sentinel firing would be a
  production-dead lane). Author it in `retribution_forever.lua` when that
  delta lands, or pin an explicit bridge override with in-game proof.
- **Seal/Judgement of the Crusader support** (class-wide: Judgment no longer
  consumes the seal): JoC raises the target's holy damage taken and no
  baseline holy lane provides it, so the holy delta carries a seal+judgement
  upkeep pair (setting `holy_forever_sotc_support`, default on).

## Spec files to author (Phase 4, post-DBC)
- `classes/paladin/retribution_forever.lua` — Holy Strike weave, non-consuming
  Judgment seal upkeep, Twist of Light echo lane.
  **Status (2026-09-18, day-1 completion): LANED (1 lane)** — the
  Holy Strike weave (max-rank mirror 10333@60, melee range, mana
  floor 25, setting `ret_forever_holy_strike`) spliced immediately
  above the baseline's Ret_SealRighteousness_Filler. The kit's OTHER
  ret items need no delta: "Judgement no longer consumes the seal"
  is already correct in the baseline (seal lanes re-apply only when
  the buff is missing — a non-consuming Judgement gains uptime for
  free); Vindication/Templar's Bulwark are passives. **Twist of
  Light is deliberately NOT laned**: the beta client carries no
  SpellClassOptions row for 1310735 (class NULL), the bridge
  excludes it, so a by-name lane could never fire live — a
  battery-only sentinel firing would be a production-dead lane
  (Pattern 17). Revisit only with an explicit bridge override
  backed by in-game proof. Unit pins: test_paladin_retribution_forever
  (mirror selection 19060/19160, splice position, gate discipline,
  dormant no-op path), load-bearing proven by file-revert. Battery
  scenario: forever_pal_ret_strike (weave fires; the SoR filler
  keeps firing — no shadowing).
- `classes/paladin/protection_forever.lua` — Seal of Fury taunt, Consecration
  threat, block-Reckoning, Templar's Bulwark with Forbearance tracking.
  **Status (2026-09-18, day-1 completion): LANED (2 lanes + wrap)** — the
  Seal of Fury pair: Judgement-of-Fury (the taunt — Judgement no longer
  consumes any seal on Forever and taunts while Fury is active; fires with
  Fury up on the kill target) and Fury upkeep (max-rank mirror 20423@58,
  buff anchor via the buff mirror, mana floor 30 to respect the baseline's
  Seal-of-Wisdom starvation band). The baseline's SealRighteousness lane is
  WRAPPED in place — with Fury up it stays blocked (its buff table predates
  the seal and would re-stomp Fury every tick; proven by the unit suite's
  baseline-vs-wrapped matcher pin), and Judgement of Wisdom stays reachable
  below. Consecration/block-Reckoning/Templar's Bulwark need no delta:
  Consecration is the baseline's own AoE lane (Forever makes it baseline at
  20, which the vanilla ladder already covers), and the Bulwark rows are
  passives. Unit pins: test_paladin_protection_forever (mirror selection
  19059/19159, splice geometry, wrap discipline, dormant no-op path),
  load-bearing proven by file-revert. Battery scenarios:
  forever_pal_prot_fury (upkeep fires) / forever_pal_prot_judgement_taunt
  (taunt fires, upkeep HOLDS, wrapped SoR stays blocked — the 338-scenario
  SoR record loses exactly this one scenario).
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
  **Status (2026-09-17, beta day): DAY-1 ROTATION** — 7 delta lanes over the
  32-lane baseline (39 total): IoL weave, Light's Vigil mark (DBC-corrected
  6s CD; ally/heavy-healing branch + enemy damage/refund branch, both gated
  on Holy Shock being ready), deficit-fit top-off (lowest group entry or
  friendly target inside the (65, 92] band; shared HealValue ladders through
  `NS.cast_best_heal_rank` with the Flash -> Holy Light escalation fallback;
  zero deficit never fires), Holy Shock core, Holy Strike weave, and the
  Seal/Judgement of the Crusader support pair. Battery-proven: all 7 lanes
  fire in the forever scenarios (`forever_iol_weave`, `forever_vigil_burst`,
  `forever_vigil_damage`, `forever_fit_topoff`, `forever_sotc_judge`,
  `forever_shock_cd`), never-inventory unchanged at 9.
- `classes/paladin/leveling_forever.lua` — Holy Strike from 6, Consecration
  from 20, first spec to feel the kit at low level.
  **Status (2026-09-17, beta day): DAY-1 BUILT (1 lane)** — the Holy Strike
  strike lane (ladder 679@6 / 678@12 / 1866@20 / 680@28 / 2495@36 /
  5569@44 / 10332@52 / 10333@60, trainer-taught under Retribution) woven
  into the leveling damage block between Exorcism and Consecration, with the
  baseline's guards (context guard, combat, movement, the seal-up
  damage-lane gate). RANK NOTE: the bridge mirrors carry one id per name, so
  the lane casts a {maxrank 10333, rank-1 678} ladder — NS.get_spell_id
  picks the highest LEARNED rung, covering levels 12-60; the @6 rank 679
  and the intermediate ranks are not name-reachable (a rank-ladder mirror
  is recorded as a close-out candidate). Consecration (26573@20 ... 20924@60)
  already has a baseline lane (2+ enemies) — no delta needed.

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
  casts the max-rank 1311595); buff row 1310909 (30s aura). Re-probed
  2026-09-17 (SpellCooldowns keyed by SpellID — the earlier pass read the
  RecoveryTime column only): CategoryRecoveryTime **6000** on every rank
  (1310911 / 1311590 / 1311595) and 1340 mana / 1.5s cast. The 180s
  estimate is RETRACTED: it is a 6s rotational mark. Mechanic text confirmed
  ("next Holy Shock triggers no cooldown", party-heal / damage + refund
  branches). [PROBE: the applied aura's live id (1310909 vs the 1311597
  duration row) and the in-game mark cap of 2 per paladin per party — the
  mark-detection guard reads the buff-mirror id 1310909.]
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

## Day-1 holy open probes (in-game, beta day)

- [ ] Holy Shock live-cast id: 20473 (class map) vs 1311606 (Forever row,
  160 vs 225 mana). The delta keeps the class-map action; if the Forever row
  is what the trainer grants, the class map needs the id added (era-shared
  file — one concern per commit).
- [ ] Infusion of Light live proc aura id: 53672 vs 426065.
- [ ] Light's Vigil applied-aura id on allies vs enemies (1310909 assumed
  for both) and whether the 2-per-party cap can be observed from the API.
- [ ] Seal of the Crusader judgement debuff id applied at rank 5 (the delta
  probes the bridge's rank-1 + max-rank ids: 20188 / 20303) and whether the
  target's holy-damage-taken increase is visible in tooltips at all.
- [ ] Flash/Holy Light rank ladders on the 1.60 client: the shared HealValue
  tables carry TBC ranks at the top (27136/27135/27137); pick_castable
  walks `NS.spell_ready`, which must report unlearned ranks false so the
  walk lands on 25292 / 19943. Battery mocks always-ready; verify in-game
  that a fitted cast never targets an unlearnable rank.
