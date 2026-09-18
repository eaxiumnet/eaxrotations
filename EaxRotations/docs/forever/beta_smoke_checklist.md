-- docs/forever/beta_smoke_checklist.md -- live-beta smoke-test checklist.
-- WHAT: every OPEN probe in beta_day1_probes.md re-cut into an execution-
--       ordered in-game checklist: what to do on the beta client, what to
--       read, and what each verdict flips. The probes doc stays the verdict
--       ledger (P0-P5); this file is the play-session runbook.
-- WHEN: first login of each beta session. Block 0 + 1 are the day-one
--       session (~60-90 min); blocks 2-4 follow in later sessions; P5
--       items ride along whenever they are visible.
-- WHY:  probes doc entries record WHAT to verify and the verdict; neither
--       is a step-by-step in-game routine. Execution order is by
--       decision-impact: engine truth first, then wave-2/3 gates, then
--       per-class lane shapes, then meta confirmations.
-- SAFETY: every verdict lands back in beta_day1_probes.md (the ledger) and
--       the owning kit doc's checklist. A flipped claim downgrades or
--       re-shapes a lane via the build-order decision table -- never a
--       silent drop. Nothing here guesses IDs: everything resolves by name
--       through the bridge mirrors.

# Live-beta smoke-test checklist (executes beta_day1_probes.md)

Rules of engagement for every block:

1. **Login order** — Block 0 first (engine truth); then work top-down.
   If time is short, run Block 0 + the three P2 gates; everything else
   can slip a session without blocking wave re-ranks.
2. **Record-as-you-go** — each item below ends with `LEDGER:` naming the
   beta_day1_probes.md entry to update (checkbox + date + one-line
   verdict), and the kit doc to touch.
3. **Never guess** — a probe that cannot complete in-game gets "BLOCKED:
   <reason>" in the ledger, not a guessed verdict.
4. **Character budget** — one class per block where possible; blocks are
   ordered so shared-client measurements (dummy, combat-log readings)
   happen once and get reused.

## Block 0 — engine truth (first login, any character, ~20 min)

Nothing class-specific gates wave re-ranks more than these four.

- [ ] **0.1 Version string.** Log in once, run the engine's version
      read (`get_game_version()` surface from core_sylvanas
      `_resolve_expansion_key()`), capture output.
      EXPECT: a Forever key resolving to the `_classic_beta_` client
      (1.60.1.69893 build reported by .build.info).
      LEDGER: P0 "Version string" item → runbook step 5 closes.
- [ ] **0.2 Race detection surface.** Create one alt of a DIFFERENT race
      than the main. On each: read `me` race/id the way racial lanes
      would (`core.object_manager` local player fields). This decides
      whether the race-gated lane backlog (Eureka!, Elune's Light, the
      four priest race spells) can ever ship.
      EXPECT: distinct, stable race identifiers per character.
      LEDGER: "Racial-rework sweep" → race-gated actives note.
- [ ] **0.3 Buff-points read (Pattern 11).** Cast any absorb (PW:S via a
      priest or the Fury absorb below) and read the buff's points array.
      This unblocks the Seal of Fury absorb-shield lane candidate.
      EXPECT: points[1] = remaining absorb, decreasing on damage.
      LEDGER: "Seal of Fury taunt pair" → absorb buff-points note.
- [ ] **0.4 Built-in damage meter + cooldown manager surfaces.** Open
      both, note what data they expose to external readers (what the
      P5 item needs to validate CD-tracking lane shapes).
      LEDGER: P5 "Built-in damage meter" item.
- [ ] **0.5 Addon-policy watch.** Confirm no integrity/error surface
      reaction while the engine runs (MMORPG.com interview posture:
      memory reads, no addon API).
      LEDGER: P0 "Addon-policy recon" item → close if silent.

## Block 1 — the three P2 gate probes (day-one session, ~40 min)

These three flip wave re-ranks; run them in this order.

- [ ] **1.1 Furor X/Y/Z (P2 #1).** Druid, level 20+, cat form, training
      dummy. Method: (a) drain energy below 20, wait for full refill,
      shift out and back in with a stopwatch — read the energy bar at
      the instant of return; (b) repeat with 5s and 10s out-of-form
      waits; (c) compare the restored amount against the tooltip's X/Y/Z
      tokens (tooltip says the capped restore formula; the client text
      has unresolved $ tokens). Verdict options: capped restore (Furor
      as shipped) vs any case where a shift NETS energy (powershift
      alive → cat keeps vanilla powershift lanes, cat_forever flips to
      additive, re-rank).
      LEDGER: P2 #1 → kit druid.md.
- [ ] **1.2 Rage-from-damage curve (P2 #2).** Warrior, training dummy,
      white hits only at a KNOWN attack power (strip all gear except a
      fixed AP source; record AP first). Hit for 30s, note rage per
      swing; repeat with one special (Heroic Strike) queued. Compare
      the observed curve against the vanilla and TBC formulas
      (the Gt* tables are absent from the build — only in-game can
      answer). Verdict decides whether fury/arms keep vanilla rage
      lanes or re-shape.
      LEDGER: P2 #2 → kits warrior.md, fury/arms/prot deltas.
- [ ] **1.3 Haste vs DoT tick rate (P2 #4).** Warlock, training dummy.
      Cast Corruption/Immolate, count ticks over 15s with a combat-log
      timestamp. Cast a haste buff (Blood Fury is Orc's own; or group
      with a shaman for Bloodlust), re-cast, recount.
      EXPECT (current demo build): identical tick count — haste does
      NOT affect dots. Any increase flips the affliction stat lanes.
      LEDGER: P2 #4 → kits warlock.md.

## Block 2 — per-class lane shapes (second session, ~60 min)

Class kits whose lane geometry depends on an open probe. Order within
the block = build-order wave order.

- [ ] **2.1 Elemental Mastery live-cast (P1 follow-up).** Shaman, 31
      points Elemental. Confirm the talent grants the ability and the
      baseline class-map lane fires (16166, 180s CD — the client has no
      SpellName row; only in-game confirms the grant).
      LEDGER: P1 "Elemental Mastery" PROBE note → kit shaman.md.
- [ ] **2.2 Wrath/Starfire Eclipse loop live (authoring premise).** Balance
      druid, engrave Belt - Eclipse, cast Wrath x3 → confirm the
      Starfire charge buff appears (408255) and Starfire consumes it
      instant-cast. This is the day-1 balance delta's spine — if the
      loop behaves differently in-game, the delta re-derives.
      LEDGER: P1 (implicit) → kit druid.md balance section.
- [ ] **2.3 Holy Shock live-cast id + Light's Vigil live behavior.**
      Paladin, holy. Cast Holy Shock — confirm the live-cast id (the
      10s CD is DBC-confirmed on 20473 AND 1311606; the live-cast id
      stays OPEN); cast Light's Vigil — confirm the 6s rotational
      category CD (the 180s estimate was RETRACTED).
      Also: proc Infusion of Light (cast a Holy Light crit or trigger
      its talent condition) and read the applied buff id — the talent/
      learn row 426065 is confirmed but the live proc-id confirmation
      stays OPEN until then.
      LEDGER: P1 paladin items → kit paladin.md.
- [ ] **2.4 Seal of Fury absorb + Judgement taunt trigger.** Paladin,
      prot, training dummy. Cast Seal of Fury, take a hit, re-read the
      absorb (ties to 0.3 buff-points read); judge — confirm the taunt
      actually requires Fury (DBC trigger linkage suggests yes).
      LEDGER: "Seal of Fury taunt pair" → REDUCED PROBE note closes.
- [ ] **2.5 Penance tick count + Soul Warding 4s-CD confirmation.**
      Priest, disc. Cast Penance (offensive on the dummy): confirm
      tick count/interval and crit behavior; cast PW:S twice back to
      back — confirm the 4s CD is truly gone (a category CD might not
      accept the full −4000 ms reduction).
      LEDGER: P3 "Penance dual-mode" + "Soul Warding deltas" PROBEs
      → kit priest.md.
- [ ] **2.6 Mutilate front-facing cast.** Rogue, assassination, dummy.
      Cast Mutilate facing the dummy (no stealth, no behind position).
      EXPECT (Forever text has no behind clause): it lands. If the
      client enforces behind, the TBC positional gate goes back on the
      assassination lanes.
      LEDGER: P3 "Venom + Mutilate" PROBE → kit rogue.md.
- [ ] **2.7 Thousand Cuts stack cap + Cutthroat proc chance.** Rogue,
      subtlety, dummy. Spam Hemorrhage/Backstab with TC up — confirm
      the stack cap (kit: 5); open from stealth repeatedly — confirm
      the Cutthroat proc chance (m1%) and whether the proc's Ambush
      still needs behind/dagger.
      LEDGER: P3 "Thousand Cuts + Cutthroat" PROBE → kit rogue.md.
- [ ] **2.8 Devouring Contagion on-death jump.** Priest, shadow, two
      dummies near each other. Kill one with DP up — confirm the jump
      target selection (nearest?) and whether the remaining duration
      carries to the new target.
      LEDGER: P3 "Devouring Contagion" PROBE → kit priest.md.
- [ ] **2.9 PoM jump count/radius + Litany refund %.** Priest, holy,
      party of 3+. Cast PoM — count jumps and note radius; heal with
      different spells back to back — confirm the Litany refund %.
      LEDGER: P3 "PoM + Binding Heal + Litany" PROBE → kit priest.md.
- [ ] **2.10 Wake of Fire trigger wiring.** Mage, fire. Trigger the
      Wake of Fire window (per its mechanic text) — confirm what
      actually procs the buff (11078) and window (1312934).
      LEDGER: P1 "Pyroblast/Fire Blast" note → kit mage.md.

- [ ] **2.11 Frostfire Bolt school behavior.** Mage: cast FFB at a
      dummy with different resists (or a PvP target) — the DBC's
      dual-school effect row needs in-game proof of which school the
      damage/ resist checks actually use (fire vs frost lower-resist
      swap gates the fire/frost school-choice lanes).
      LEDGER: P3 "Frostfire Bolt lower-resist school swap" → kit
      mage.md.
- [ ] **2.12 Power in Light smite ticks.** Priest, smite: cast
      Penance on a dummy — confirm the +15% applies per Penance tick
      (or per cast), and time the Holy Fire debuff refresh window
      against its DoT duration (the debuff-driven HF upkeep lane's
      premise).
      LEDGER: P3 "Power in Light smite core" PROBE → kit priest.md.

## Block 3 — warlock deep-dive (third session, ~45 min)

Warlock carries the most open P3 probes (demo + affliction family
shape). One warlock session clears six items.

- [ ] **3.1 Demonic Pact third-demon rule.** Sacrifice a demon, then
      summon a DIFFERENT one (Voidwalker/Felhunter). Confirm the
      school aura survives; re-summon the sacrificed one — confirm the
      aura cancels.
      LEDGER: P3 "Demonic Pact persistence" → kit warlock.md.
- [ ] **3.2 Demonic Sacrifice source.** Check trainer list, engraving
      vendor, and talent tree for Demonic Sacrifice (18788 has no
      SpellClassOptions — the bridge cannot carry it; the #17 sacrifice
      cast stays manual until the source is known). Also read the
      Decimation $m1/$m3/$m4 tokens in the tooltip.
      LEDGER: P3 "Demonic Sacrifice" → kit warlock.md.
- [ ] **3.3 Bane of Havoc slot rules + mirror attribution.** On two
      dummies: bane the off-target — confirm one-Bane-per-warlock, and
      whether the Bane shares the Curse slot on the same target; watch
      the combat log for the mirror-damage attribution.
      LEDGER: P3 "Bane of Havoc rules" → kit warlock.md.
- [ ] **3.4 Bane of Agony/Doom vs Curse slot.** Apply Bane of Agony and
      Curse of the Elements on one target — confirm the two coexist
      (separate aura family). If the slot is shared, the warlock
      leveling #26 amp lane CHURNS and must be removed.
      LEDGER: P3 "Bane decoupled" → kit warlock.md (+ leveling delta
      consequence).
- [ ] **3.5 Touch of the Grave proc semantics.** Undead warlock (or
      borrow any Undead caster): apply a DoT, watch the proc — per-DoT-
      tick or per-application? Any ICD? The warlock page calls it
      potentially "incredibly strong" if per-tick.
      LEDGER: P3 "Touch of the Grave" → kit warlock.md (+ rogue/mage
      racial-lane candidates).
- [ ] **3.6 DoT crits.** Cast Corruption on the dummy until a crit
      appears in the log (or gear for crit). Era-wide: gates the
      Pandemic / Predatory Instincts payoff lanes.
      LEDGER: P3 "DoTs can critically strike" → kits warlock.md,
      druid.md.

- [ ] **3.7 Demonic Brand pet-tank window.** Solo: apply Searing
      Pain with the brand up, let the pet hold the dummy — observe
      the threat behavior ("pet's next 2 attacks generate high
      threat") and the Searing Pain threat reduction. No threat API
      surface exists, so this stays a world/solo manual lane.
      LEDGER: P3 "Demonic Brand pet-tank window" → kit warlock.md.

## Block 4 — remaining per-class probes (fourth session, ~45 min)

- [ ] **4.1 Swiftmend HoT survival.** Druid, resto. Rejuv a target,
      Swiftmend it, immediately re-read the Rejuv aura — confirm the
      HoT SURVIVES the cast (kill the timer mid-cast and re-read per
      the ledger's method).
      LEDGER: P3 "Swiftmend" → kit druid.md.
- [ ] **4.2 Tree of Life 439745 form semantics.** Resto druid: take the
      form — shapeshift? duration? aura row? Read the +11% healing-
      received radius (the $a1 token). Form-lane candidate only; NOT
      laned in #16.
      LEDGER: P3 "Tree of Life" → kit druid.md.
- [ ] **4.3 Rejuv/Swiftmend same-second GCD.** GotE's 1s GCD vs the
      1.5s floor: cast Rejuv → Swiftmend within the same second —
      confirm whether the 1s GCD applies.
      LEDGER: P3 "Rejuv/Swiftmend same-second GCD" → kit druid.md.
- [ ] **4.4 Berserk (druid) form branches.** Bear: confirm no-Mangle-CD
      + 3 targets; Cat: confirm +100% CP-gen crit; both: fear
      immunity. Gates the cat/bear burst windows.
      LEDGER: P3 "Berserk form-branched" → kit druid.md.
- [ ] **4.5 Aimed/Multi-Shot shared CD + traps in combat.** Hunter:
      cast Aimed then Multi-Shot immediately — confirm any shared CD;
      drop a trap mid-combat — confirm usability.
      LEDGER: P3 "Aimed/Multi + traps" → kit hunter.md.
- [ ] **4.6 Blood Fury numbers.** Orc any class: pop Blood Fury, read
      the buff tooltip in-game (the DBC resolved AP+SP from 20572's
      text; the in-game tooltip is the final word on the % and
      duration).
      LEDGER: P3 "Blood Fury numbers" → kits warrior/rogue/mage/
      warlock.md.
- [ ] **4.7 Berserking observed duration.** Troll any class: pop
      Berserking (20554), time the buff (DBC says 10s; the in-game
      observation closes the reduced probe).
      LEDGER: P3 "Berserking form" → kit racial notes.
- [ ] **4.8 Holy Strike low-rank CD + Improved Mind Flay numbers.**
      Paladin leveling: read the 12s CD at rank @6; priest shadow:
      read the +yards and slow % on Mind Flay with the talent.
      LEDGER: P3 "Paladin Holy Strike ladder" + "Improved Mind Flay"
      PROBEs → kits paladin.md, priest.md.
- [ ] **4.9 Restless Blades per-CP value + Rupture interaction.** Rogue,
      combat: spend 2 CP via Rupture, read the RB CD discount — 2s/CP?
      Does Rupture shave? Compare against finishing a 5-CP Eviscerate.
      LEDGER: P3 "Restless Blades CD-discount shape" → kit rogue.md.
- [ ] **4.10 Early Demise + Fingers of Frost bridge gaps.** Shadow
      priest / frost mage: confirm the talents exist in-game (both are
      BaseLevel-0 bridge gaps) and the lane windows match the talent
      conditions.
      LEDGER: P3 "Improved Mind Flay" note + kit priest.md/mage.md.

- [ ] **4.11 Victory Rush rune source + heal %.** Warrior leveling:
      kill an enemy granting XP, confirm the rune's in-game source
      (Engrave Gloves - Victory Rush per the ledger) and read the
      heal percentage off the buff. The rage-formula watch (1.2)
      stays the standing P2 probe.
      LEDGER: P3 "Warrior Victory Rush" PROBE → kit warrior.md.

## Block 5 — P5 era-wide confirmations (background, any session)

Ride-along items; tick as they become visible.

- [ ] **5.1** Baseline raid buffs (Kings/Divine Spirit/Improved MotW) —
      if talent inference drops them, `talent_inference_sylvanas`
      probes go away.
- [ ] **5.2** Buff cap removed — cast 33+ buffs, confirm no cap.
      Totem/buff accounting simplification.
- [ ] **5.3** Merged spell/melee hit-crit — open the character pane,
      confirm the merged stat reads.
- [ ] **5.4** ⅓ healing→spell-damage conversion — healer solo: confirm
      the conversion on a damaging spell.
- [ ] **5.5** World buffs in raids — meta watch only (expected
      nerf/removal); no lane impact day 1.
- [ ] **5.6** Talent DB2 shape — the 16-point gold-medal mapping
      (racials-and-talents.md follow-up).
- [ ] **5.7** Skyborne druid form list — form-lane watch item.

## After each session

1. Move every verdict into `beta_day1_probes.md` (the ledger) — checkbox
   + date + one-line verdict; BLOCKED entries get a reason.
2. Update the owning kit doc's verification checklist the same way.
3. Apply the build-order decision table (phase4_build_order.md): only a
   P2 gate flip or a P3 flip that changes a wave's relative ranking
   re-ranks the build order — a lookup, not a research pass.
4. Re-run `lua EaxRotations/tests/run_forever_audit_tests.lua` after any
   lane change the verdict forces; the audit must stay 38 files / 0
   invalid.
