-- docs/forever/kits/warrior.md -- WoW Forever Warrior kit research.
-- WHAT:  fourth kit transcription, from the Icy Veins Forever warrior class
--        overview (Abide, updated 2026-09-13) — page predates the series'
--        Sep-15 spell/talent pass, so expect a refresh.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Warrior rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: NO spell IDs in this file until the Forever DBC lands (2026-09-17);
--         see docs/forever/dbc_runbook.md for the verification gate.

# Warrior — WoW Forever kit (class overview 2026-09-13)

Sources: Icy Veins Forever Warrior Class Overview (Abide, 2026-09-13 —
PRE-SERIES-PASS: talent names are BlizzCon/calculator-derived, the dedicated
spell-talent detail section other classes got had not landed yet; re-check
the page for a Sep-15+ changelog entry). Community reproduction of Blizzard
data: plan lanes on it, but every claim is **unverified until the beta DBC
resolves it** (no IDs, no rank numbers below).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Victory Rush baseline** — damage + heal 10% max HP, only after killing a similar-level enemy | Leveling/solo sustain lane; combat-state gated (recently-killed flag) — not a raid rotation button |
| **Major CD split: Recklessness / Retaliation / Shield Wall no longer share a cooldown** | The Vanilla shared-CD interlock in every warrior rotation dies: each becomes an independent lane (dps burst vs panic defense decoupled) — big simplification |
| **Slam: baseline 15s cooldown** (was none) | Slam-weave lanes need CD awareness; interacts with Arms' Improved Slam below |
| **Bloodthirst: 35% AP damage** (was 45%) | Fury rotation unchanged in shape, throughput nerf — priority order survives but rage-to-damage math shifts |
| **Shield Block: blocks 2 attacks** (was 1) | Prot mitigation window doubles in value; block-based reactive lanes (Reckoning-style) gain weight |
| **Prot baseline CD reductions**: Last Stand + Shield Wall usable much more often | Defensive panic lanes fire far more; threshold settings need retuning for Forever |
| **Thunder Clap usable in Defensive Stance** | Prot AoE-tank loop opens up (was stance-locked); TC becomes a core prot AoE threat lane |
| **Shield Slam: harder scaling + more base threat** | Approaches its TBC power level — likely THE prot rage spender |
| **RAGE FORMULA CHANGE expected**: article expects the TBC-era rage-from-damage nerf (landing "around Cataclysm" tuning) | THE big unknown: rage starvation reshapes every rage-gated lane (Pattern-14 defaults). UNCONFIRMED — plan a rage-normalization probe for beta day 1 |
| **World buffs likely nerfed/removed in raids** | Meta note: Warrior is the most world-buff-dependent class; affects target perf expectations, not rotation code |

## Arms
- **Bloodthrill**: Rend procs can activate **Overpower without the target
  dodging** (TfB-style, WotLK-shaped) — Rend moves from near-dead dot to a
  proc-engine lane; Overpower becomes semi-rotational.
- **Improved Slam** (TBC import): reduces Slam GCD + cast time — Slam
  re-enters the PvE priority as a real button (pair with the new 15s CD).
- **Weaponmaster**: merges Axe/Sword weapon-specific talents into one
  (includes staves) — pick-best-weapon without respec; removes weapon-type
  gating from talent assumptions.
- **Spearing Strike** (NEW): 15 Rage, 40% weapon damage, **+80% vs
  Giant/Dragonkin/mounted**, force-dismount on mounted — encounter-gated
  nuke lane (fight-type context) + PvP dismount tool.
- **Mortal Strike** remains the PvP bread-and-butter (mortal-wound lane).

## Fury
- **Improved Cleave** (up to −3 rage) + **Raging Blows** (further −2 Cleave
  rage; **Whirlwind hits with both weapons**, was main-hand only) — the
  ~4-target cleave loop (WW + Cleave) gets materially cheaper and harder.
- **Dual Wield Specialization**: more off-hand rage generation + hit —
  rage economy improves from the OH side.
- **Precision** (TBC import): +3% hit with all abilities/attacks — stack
  with the OH-hit talent; hit-capping assumptions change.
- **Enrage procs from ANY damage taken** (was crits-against-you only),
  but only **+10% damage** (was 25%) — much higher uptime, much smaller
  per-proc; rotation-wise it becomes an ambient state, not a reactive lane.

## Protection
- **"While a shield is equipped" is on nearly every prot talent** —
  dual-wield Fury-prot tanking is over; shield is structural. Tank-mode
  detection = weapon-shield read, not spec read.
- **Improved Revenge**: now damage-up (stun chance removed) — Revenge stays
  a rage-efficient spender, threat output rises.
- **Improved Thunder Clap** (moved to prot): −2 rage/point — TC spam cheaper.
- **Focused Rage** (TBC import): −1 rage/point on offensive abilities —
  global rage-cost relief; rage-starvation planning shifts.
- **Vitality** (TBC import): +2%/pt Stamina + Strength.
- **Vanguard** (NEW): **Charge usable in Defensive Stance** (NOT in combat —
  unlike WotLK's Warbringer) — opener gap-close for prot; no mid-fight
  charge lane.
- **Shield Slam**: scaling + base threat up (see class-wide).

## Warrior-relevant racial detail (per-class page; numbers = press tier)
| Race | Detail relevant to warrior rotations |
|---|---|
| Night Elf | **Elune's Light** on-use +10% crit 15s (3-min CD — "additional trinket"); Quickness +1% dodge/+2% speed; Shadowmeld (out of combat) |
| Human | **Will to Survive** stun-break (3-min); Sword Spec +2% crit (melee-relevant) |
| Gnome | **Escape Artist** now grants root/snare IMMUNITY for its 8s; **Expansive Mind +5% Rage** (rage-pooling boost); **Eureka!** +10% on next 3 abilities (burst CD) |
| Dwarf | Stoneform physical-damage reduction (tank-flavored); Mace Spec +1% crit; Big Game Hunter +5% vs beasts |
| Orc | **Blood Fury +10% AP** (NERFED from 25%) 15s — third-trinket burst lane; Axe Spec +1% crit; Hardiness −20% stun duration; **Shatter Curse** curse/bane immunity +15% magic reduction |
| Tauren | Endurance +5% HP +1% hit (tank staple); **War Stomp** AoE stun; Cultivation (herb farming, non-rotation) |
| Undead | Weak pick for warriors (Berserker Rage already covers WotF's CC removal); Touch of the Grave drain passive |
| Skyborne (any faction — Warriors can be ANY race) | Walk on Air glide; Wind Blessed +1% melee haste; Elemental Insight +5% vs elementals; faction on-use (Ley Line regen / Skysight speed) — caster-leaning, weak for warriors |

## Flagged as unconfirmed
- **TBC rage-generation formula change** — expectation, not announcement.
  Highest-impact unknown for our rage-gated lanes; beta day-1 probe.
- World-buff removal/nerf in raids — expectation; meta only.
- The page itself is pre-Sep-15 series pass — talent list may be incomplete
  vs other classes' pages.

## Spec files to author (Phase 4, post-DBC)
- `classes/warrior/arms_forever.lua` — Rend-proc Overpower lane
  (Bloodthrill), Improved Slam weave with the new 15s CD, Spearing Strike
  encounter-gated nuke, Weaponmaster-aware weapon assumptions.
- `classes/warrior/fury_forever.lua` — WW-both-weapons + cheap-Cleave AoE
  loop, OH-rage/hit economy, ambient-Enrage (drop reactive Enrage lanes),
  Bloodthirst re-tuned priority.
- `classes/warrior/protection_forever.lua` — shield-gated structural check,
  Shield Slam primary spender, TC-in-defensive AoE threat loop, Revenge
  damage lane, CD-split defensives (independent thresholds), Vanguard opener.
- `classes/warrior/leveling_forever.lua` — Victory Rush kill-chain sustain
  lane, rage-formula watch (leveling is where starvation bites first).

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [ ] Resolve every named ability above BY NAME in the Forever bridge
      (zero-literal rule); record IDs into `WarriorSpells` only then.
- [ ] Confirm the CD split: Recklessness/Retaliation/Shield Wall cooldown
      groups fully independent (aura/CD shape in DBC).
- [ ] Confirm Slam baseline 15s CD + Improved Slam interaction.
- [ ] Confirm Bloodthirst AP coefficient (35%) and Victory Rush gating.
- [ ] Shield-gated prot talents: verify condition text (shield-required
      effect) for the tank-mode structural check.
- [ ] Vanguard: Charge-in-defensive WITHOUT in-combat use.
- [ ] RAGE FORMULA: compare rage-per-damage against the TBC formula on
      beta day 1 (highest-priority rotation-model probe).
- [ ] Re-read the page for the Sep-15+ spell/talent pass (changelog) and
      fold in anything new (Bloodthrill/Spearing Strike rank data etc.).

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
