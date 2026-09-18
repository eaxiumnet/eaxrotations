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
  **Status (2026-09-17, beta day): DAY-1 BUILT (one nuke + one replacement)**
  — Spearing Strike (trainer-taught under Arms) is wired as the
  encounter-gated nuke: the DBC text is "41% weapon damage ... an additional
  ${41*3}% weapon damage against Giants, Dragonkin, and mounted targets"
  (the kit's "40%/+80%" corrected), so the lane fires only when the target's
  creature type is Giant (5) or Dragonkin (2) — the mounted case has no API
  signal and is skipped. Improved Slam ("reduces the GCD and cast time ...
  Slam no longer interrupts your melee swing time") makes the baseline's
  swing-window gate obsolete, so the baseline Slam lane is REPLACED with an
  ungated version when the talent is learned (same rage/movement/Overpower
  guards). **Bloodthrill (1289682: "melee attacks against targets afflicted
  by your Rend have a 16% chance to activate your Overpower") needs no lane**
  — the baseline's Overpower lane already keys off the engine readiness
  state; whether that state includes the proc is an in-game probe (the
  talent/aura rows are BaseLevel-0 and bridge-invisible). Sudden Death
  (440113: "one use of Execute regardless of the target's health state")
  likewise stays un-laned: an ungated Execute lane would shadow the whole
  rotation if the engine's readiness did NOT include the proc — probe first.
  Weaponmaster is a talent merge (no lane).
- `classes/warrior/fury_forever.lua` — WW-both-weapons + cheap-Cleave AoE
  loop, OH-rage/hit economy, ambient-Enrage (drop reactive Enrage lanes),
  Bloodthirst re-tuned priority.
  **Status (2026-09-17, beta day): DAY-1 BUILT (verdict-independent subset)**
  — the **CD split is DBC-confirmed** (Recklessness 1719 RecoveryTime
  1800000, Retaliation 20230 / Shield Wall 871 900000, none sharing a
  SpellCategories row), so a Recklessness burst lane is added above the
  baseline's DeathWish (the baseline never pressed it). The kit's other fury
  items are passives/value changes and need no lane: ambient Enrage (no
  baseline lane reads Enrage), cheaper Cleave / both-weapon Whirlwind
  (talent passives; the client's WW row carries a single weapon-damage
  effect, so both-weapon behavior is an in-game probe), Bloodthirst's 35% AP
  (confirmed in the DBC). The P2 rage-formula probe is NOT client-resolvable
  — every baseline rage reserve stays conservative until the in-game verdict.
  OPEN (in-game): rage formula, WW both-weapons, whether Recklessness needs
  a Berserker Stance gate (the client description omits it, as it does for
  the known stance-locked Whirlwind).
- `classes/warrior/protection_forever.lua` — shield-gated structural check,
  Shield Slam primary spender, TC-in-defensive AoE threat loop, Revenge
  damage lane, CD-split defensives (independent thresholds), Vanguard opener.
  **Status (2026-09-17, beta day): DAY-1 BUILT (one replacement + one
  addition)** — the baseline's Thunder Clap lane hard-gated on Battle Stance
  ("Vanilla TC requires Battle Stance"), so the class-wide unlock could never
  fire in the tanking stance: the lane is REPLACED with a stance-agnostic
  version (Defensive or Battle, same debuff/rage/AoE gates) in the same
  position. The new passive Vanguard 1310317 ("Your Charge ability is now
  usable while in Defensive Stance", aura-332 overrides of the Charge ids) is
  gated on is_spell_learned and adds an OUT-OF-COMBAT Defensive-stance Charge
  opener (8-25yd); in combat the baseline's Intercept stays the gap-closer.
  CD reductions confirmed in the DBC (Shield Wall 871 = 900000, Last Stand
  12975 = 180000 — 15/3 min, down from vanilla's 30/10) and need no lane
  (the baseline's separate defensive lanes read spell_ready). "Shield is
  structural" is a talent-condition note: the engine validates the shield on
  cast and no shield-type API read exists in this tree — documented.
  Shield Slam 23925 / Revenge 25288 value changes need no lane.
- `classes/warrior/leveling_forever.lua` — Victory Rush kill-chain sustain
  lane, rage-formula watch (leveling is where starvation bites first).
  **Status (2026-09-17, beta day): DAY-1 BUILT (1 lane)** — Victory Rush
  402927 (Warrior, level 20, 30s RecoveryTime, rune-granted via "Engrave
  Gloves - Victory Rush": "Instantly attack the target ... healing you for
  $s2% of your maximum health. Only useable within $402975d after you kill
  a non-trivial enemy") fired inside the VICTORIOUS kill window (402975,
  "Follows killing an enemy") above the baseline's Execute lane, with the
  melee/combat/target gates the baseline's damage lanes carry and a learn
  gate for the rune (fail-closed un-engraved). The rage-formula watch is
  the standing P2 probe (not client-resolvable) — recorded, no lane.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Resolve the wave-2 names BY NAME / class map (2026-09-17): Retaliation
      20230, Shield Wall 871, Whirlwind 1680, Death Wish 12328, Bloodthirst
      23881/23894, Cleave 845/20569, Execute 5308/20662, Slam 1464/11605,
      Overpower 7384/11585, Victory Rush 402927, Raging Blows 1310315,
      Improved Cleave 12329, DWS 13715, Precision 456382. **Recklessness 1719
      is NOT in the bridge** — the builder's 20-minute RecoveryTime cap
      filters its 30-minute row — but the class map carries it (id 1719), so
      fearless lanes use the class map. "Enrage" resolves the *druid* 5229
      (cross-class lowest id; the warrior rows are classless 12880 / a
      BaseLevel-0 427066) — a future Enrage lane needs a
      MIRROR_NAME_OVERRIDE, same hazard class as Berserk.
- [x] CD split CONFIRMED (2026-09-17): Recklessness 1719 RecoveryTime
      1800000, Retaliation 20230 and Shield Wall 871 RecoveryTime 900000 —
      each with **no SpellCategories row** (cat 0), so the vanilla shared-CD
      interlock is gone. The fury delta presses Recklessness independently.
- [x] Slam baseline 15s CD CONFIRMED (2026-09-17): CategoryRecoveryTime
      15000 on 1464 and 11605. The baseline lanes already gate through
      spell_ready, so the CD is honored without a delta.
- [x] Bloodthirst coefficient CONFIRMED (2026-09-17): the rank rows
      23881@40 / 23894@60 carry a dummy effect at base **35** (the "35% of
      AP" kit claim) and CategoryRecoveryTime 6000; priority shape unchanged.
- [x] Victory Rush (2026-09-17): 402927@20, text "healing you for **11%** of
      your maximum health" (the kit said 10% — corrected), usable within
      $402975d after a kill. No "recently killed" signal is exposed to the
      API, so this stays a leveling/solo candidate, not a day-1 lane.
- [ ] Shield-gated prot talents: verify condition text (shield-required
      effect) for the tank-mode structural check.
- [x] Prot wave (2026-09-17): Vanguard 1310317 confirmed ("Charge usable in
      Defensive Stance", aura-332 override rows at the Charge ids
      11578/6178/100); Shield Wall 871 RecoveryTime 900000 and Last Stand
      12975 RecoveryTime 180000 confirm the CD reductions; Shield Slam
      23925@60 ("656 damage, increased by your Block Value ... very high
      threat"), Revenge 25288@60 ("must follow a block, dodge or parry"),
      Shield Block 2565 ("Increases chance to block by 76% for 7, but will
      only block $n attacks" — the $n is the Forever 2), Devastate 20243,
      Sunder Armor 7386/11597, Concussion Blow 12809, Improved Revenge
      12797, Improved Thunder Clap 12287, Focused Rage 29787 all resolve.
      The baseline's TC Battle-stance gate was the one live defect (fixed).
- [x] Arms wave (2026-09-17): Spearing Strike 1310222@1 = "41% weapon damage
      ... additional ${41*3}% against Giants, Dragonkin, and mounted"
      (trainer-taught under Arms; 15 rage per spell_meta power 1); Improved
      Slam 12862 = "reduces the global cooldown and cast time of your Slam
      ability ... Slam no longer interrupts your melee swing time"; Mortal
      Strike 12294/21553, Overpower 7384/11585, Rend 772/11574 resolve.
      Bloodthrill 1289681/1289682 and Sudden Death 440113 exist (Sudden Death
      is bridge-resolvable; Bloodthrill's rows are BaseLevel-0) — see the
      arms status note for why neither adds a lane yet.
      [PROBE: does the engine's Overpower readiness include the Bloodthrill
      proc, and does Execute readiness include the Sudden Death window?]
- [ ] Vanguard: Charge-in-defensive WITHOUT in-combat use. DONE (the lane
      gates OOC + defensive + 8-25yd).
- [ ] RAGE FORMULA: **not resolvable from the client data** (no rage table
      is extracted; the Gt* tables are absent from this build). In-game
      probe stands: compare rage-per-damage against the TBC formula. Until
      it lands, the fury/arms/prot deltas ship only verdict-independent
      lanes and every baseline rage reserve stays conservative.
- [ ] Re-read the page for the Sep-15+ spell/talent pass (changelog) and
      fold in anything new (Bloodthrill/Spearing Strike rank data etc.).

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
