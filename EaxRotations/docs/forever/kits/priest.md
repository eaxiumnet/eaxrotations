-- docs/forever/kits/priest.md -- WoW Forever Priest kit research.
-- WHAT:  sixth kit transcription — NOTE: the Icy Veins class-overview
--        series has NO priest page yet (404; only the JS-gated talent
--        calculator). Source below is Zockify's demo-derived summary
--        (2026-09-14); source tier is LOWER than the other kit docs.
-- WHEN:  refresh when the Icy Veins priest overview lands or the beta DBC
--        verifies/corrects each claim (dbc_runbook.md).
-- WHY:   day-1 Priest rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: NO spell IDs in this file until the Forever DBC lands (2026-09-17);
--         see docs/forever/dbc_runbook.md for the verification gate.

# Priest — WoW Forever kit (demo-derived summary 2026-09-14)

Sources: Zockify Forever Priest page (2026-09-14, talent descriptions from
the playable BlizzCon demo build; work-in-progress) + the era-wide talent
framework (racials-and-talents.md). Community reproduction, demo tier:
plan lanes on it, but every claim is **unverified until the beta DBC
resolves it** (no IDs, no rank numbers below). WATCH: an Icy Veins priest
class-overview may still appear — refresh this doc when it does.

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Penance** (Discipline) — holy-light volley: damage vs enemies OR heal vs allies, instant + ticks | First WotLK-shaped Priest import: a dual-mode channeled button — mode-switch lane by role context |
| **Prayer of Mending** (Holy, via talent) — heal-on-damage buff that jumps up to 5× | The TBC staple arrives: pre-cast reactive heal lane (place on the tank before pulls; jump tracking) |
| **Devouring Plague for ALL races** (was Undead racial) | Shadow's flagship dot becomes universally available — Shadow rotation delta for every race |
| **Fear Ward baseline for all Priests** (was Dwarf racial) | Racial-spell system dissolved; the Vanilla race-choice matrix for priests collapses |
| **Improved Shadowform** — reduces Shadow spell mana cost + increases Shadow crit damage | Shadow mana model + crit scaling reshape |
| **Gnome Priests** (new combo); Divine Spirit baseline era-wide (talent removed) | Combo validation; one less Spirit talent tax |

## Discipline
- **Penance** (above) — the spec's new core button (offensive mode feeds
  the Smite build below).
- **Power in Light**: Smite + Penance deal up to +10% vs **Holy-Fire-kept
  targets** — the repo's dedicated SMITE spec file gains real kit support:
  Holy Fire becomes a maintenance debuff (hard lane gate, FS-style).
- **Divine Aegis**: critical heals shield the target for 5–15% of the heal
  — crit-heal absorbs stack on top of PW:S absorbs (Pattern 12 interplay:
  absorb accounting must track BOTH shields).
- **Soul Warding**: PW:S cooldown −4s + mana cost −15% — the shield loop
  spins faster; refresh thresholds re-derive.
- **Renewed Hope**: heals on Weakened-Soul targets gain crit chance AND
  shave the Weakened Soul duration — direct synergy with the PW:S loop.
- **Twin Disciplines**: instant-cast spells deal/heal up to +5%.
- **Holy Precision** (in Disc tree): Holy spell hit up to +18% — hit-capped
  offensive-disc/smite viability.

## Holy
- **Prayer of Mending** (above) — new scheduled pre-pull/re-trigger lane.
- **Binding Heal** (NEW to Holy) — heals target + caster (low threat):
  the self-preservation lane for the healer (tank+healer simultaneous
  damage coverage).
- **Litany of Light**: casting a DIFFERENT spell than the previous heal
  refunds 5–10% of its base cost as mana — rotation-shaping mana engine
  that PUNISHES spell repetition (cast-variability lane).
- **Twilight Focus**: 20–70% pushback protection while casting — channel/
  cast-finish reliability under damage.

## Shadow
- **Improved Mind Flay**: +10–20% damage, **+5–10y range**, and a 35% slow
  — the channel window extends (range = more uptime between movements),
  adding a utility slow to the core filler.
- **Devouring Contagion**: DP mana cost −25/50%; targets dying with DP
  **spread it to a nearby enemy** for the remaining duration — AoE dot
  chaining lane on trash pulls.
- **Early Demise**: SW:D crit chance +15/30% vs ≤20% health targets —
  sharper execute lane.
- **Improved Shadowform** (above) — mana + crit-damage scaling.

## Removed talents (rotation-relevant)
Lightwell, Divine Spirit, Force of Will, Healing Focus, Improved PW:Fort,
Improved Prayer of Healing, Improved Vampiric Embrace, Unbreakable Will —
era-wide Divine Spirit baseline accounts for the biggest one; the rest
trim dead lanes (none of these drive current vanilla-file lanes).

## Priest-relevant racial detail (per-class pages)
Gnome joins Human/Dwarf/NE (Alliance) and Undead/Troll (Horde) — the
Dwarf Fear Ward exclusivity that structured Vanilla priest race choice is
gone (baseline). Racial acts (Elune's Light crit burst, Berserking haste,
Eureka!) carry from racials-and-talents.md.

## Flagged as unconfirmed (demo tier)
- Exact Penance damage/heal split and channel behavior (ticks/1s x2?).
- PoM jump semantics (damage-triggered vs any non-periodic heal) — wording
  differs from the TBC version.
- Whether Divine Aegis absorbs stack with PW:S or replace one another.
- Litany of Light's "different spell" tracking window.
- The Icy Veins priest overview does not exist yet — this doc is the
  lowest-source-tier kit doc; refresh is mandatory before launch.

## Spec files to author (Phase 4, post-DBC)
- `classes/priest/discipline_forever.lua` — Penance dual-mode, Aegis
  absorb accounting (with PW:S, Pattern 12), Soul Warding loop, Weakened
  Soul shaving, Power in Light Holy Fire maintenance.
  **Status (2026-09-17, beta day): DAY-1 BUILT (3 lanes, additive)** — (1)
  the Soul Warding shield: with the talent learned, shields the tank/lowest
  at <= 75% HP when no Weakened Soul is up and the COMBINED PW:S + Divine
  Aegis absorb (431624 via buff_points) sits at or below 300; (2) Penance
  heal: the moderate-damage core button on the lowest ally at <= 65% (12s
  category cooldown declared); (3) Penance damage: the same cast row on the
  enemy inside the Power in Light window (Holy Fire debuff up), in the idle
  block with the group-stable >= 92% mirror of the baseline's local helper.
  The kit's "+10% Power in Light" is corrected to 15%; Renewed Hope's
  Weakened Soul shave is 5s (passive).
- `classes/priest/holy_forever.lua` — PoM placement/jump lane, Binding
  Heal pair-heal, Litany of Light cast-variability engine.
  **Status (2026-09-17, beta day): DAY-1 BUILT (3 lanes, additive)** — (1)
  Prayer of Mending: the maxrank cast (1240827@60, CategoryRecoveryTime
  10000) on the tank whenever NO party member carries the aura — the jump
  tracking reads the pinned @60 aura row (1240849, builder BUFF_OVERRIDES)
  plus the maxrank cast id, and scans the frame-cached healing entries.
  (2) Binding Heal (1240774@56, "Heals a friendly target and the caster",
  effect rows = two heal effects): the pair-heal fires only when BOTH the
  lowest ally and the priest sit at or below 65%. (3) Litany of Light
  (1317006, a passive proc): the cast-variability lane alternates Greater
  Heal and Flash Heal on its own last cast (the engine exposes no
  last-spell read — core's _last_spell_cast is file-local), so every cast
  it makes is a "different spell" for the refund. Twilight Focus (14913,
  pushback protection) is a pure passive — recorded as a probe.
- `classes/priest/shadow_forever.lua` — universal DP dot, extended Mind
  Flay (range + slow), DP-spread on-kill chaining, SW:D execute sharpening.
  **Status (2026-09-17, beta day): DAY-1 BUILT (2 lanes, additive)** — (1)
  Shadow Word: Death as the Early Demise execute (the baseline had NO SW:D
  lane): the maxrank row 1309636 at targets <= 20% HP, 15s
  CategoryRecoveryTime declared, below the mana-emergency floor and never
  clipping a live Mind Flay channel. Early Demise 1310076 is BaseLevel 0 (the
  builder's level guard excludes it — recorded as a probe), so the lane does
  not gate on the talent: its 20%-HP window IS the talent's condition. (2)
  The Devouring Contagion chaining lane: talent-gated, cleave/aoe mode,
  DP refreshed inside a wider 6s window so trash deaths always spread it
  (1309950: -50% mana, 10y jump). Devouring Plague is rune-granted
  ("Gain the Devouring Plague ability" rows reference the vanilla 19280
  ladder) — the baseline's spell_exists lane is the universal path, no delta.
  Improved Mind Flay 1225139 (+damage, +range, slow) is a pure passive on the
  baseline's range-gateless MindFlay lane — no new lane; the in-game numbers
  are recorded as a probe.
- `classes/priest/smite_forever.lua` — Power in Light makes the smite
  build real: Holy Fire upkeep + Penance/Smite core.
- `classes/priest/leveling_forever.lua` — Fear Ward/DP universal access
  reshape early leveling for all races.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Resolve every named ability above BY NAME in the Forever bridge
      (2026-09-17, disc day-1): Penance 402174@30 / 1240720@40 / 1240721@50 /
      1316995@60, Soul Warding 402000, Divine Aegis 431622/431624, Renewed
      Hope 425280, Twin Disciplines 1225132, Power in Light 1309969,
      Weakened Soul 6788, PW:S 10901 — all resolve.
- [x] Penance: dual-mode effect shape (2026-09-17, disc day-1) — the cast row
      1316995 is one spell ("causing $1316993s1 Holy damage to an enemy, or
      $1316991s1 healing to an ally, instantly and every $402261t2 sec for
      $402261d"), CategoryRecoveryTime 12000, trainer-taught under
      Discipline. The internal channel rows 1316991/1316993 win the raw @60
      maxrank tie, so the cast is pinned in the builder's MAXRANK_OVERRIDES;
      the #19 lanes carry both modes (heal on allies, damage on enemies in
      the Power in Light window). [PROBE: the exact tick count/interval and
      whether ticks can crit.]
- [x] Divine Aegis: absorb buff via buff points (2026-09-17, disc day-1) —
      the applied shield is 431624 (effect 6 aura 69 school-absorb, base 2,
      "$431624d") while the rank-1 baseline 431622 is the talent text, now
      pinned in the builder's BUFF_OVERRIDES. The #19 shield lane counts
      PW:S + Aegis absorbs together (Pattern 12) before re-shielding.
      [PROBE: whether Aegis stacks with PW:S or replaces — the lane assumes
      additive; the DBC has no stacking rule.]
- [x] Soul Warding: PW:S cooldown/cost deltas (2026-09-17, disc day-1) —
      effect rows confirm exactly −4000 ms and −15% mana; PW:S itself carries
      CategoryRecoveryTime 4000, so with the talent the loop becomes
      Weakened-Soul-limited. The #19 shield lane is gated on the talent.
- [x] Power in Light (2026-09-17, disc day-1): 1309969 reads "+15% damage to
      targets afflicted with your Holy Fire" — the kit's "up to +10%" is
      CORRECTED to 15%; the #19 offensive Penance lane gates on the Holy
      Fire debuff. Renewed Hope shaves 5s of Weakened Soul (the kit's
      "shave" is now quantified) and Twin Disciplines gives +5% instant
      casts — both passive on existing lanes, no new lane.
- [x] PoM: trigger-on-damage buff + jump chain (2026-09-17, holy day-1) —
      the cast ladder 401859@40 / 1240826@50 / 1240827@60 (10s
      CategoryRecoveryTime) applies the @60 aura 1240849 ("Heals upon taking
      damage or receiving healing"), pinned in the builder's BUFF_OVERRIDES;
      the #24 lane places it on the tank and holds while ANY party member
      carries it (jump tracking). [PROBE: the in-game jump count (kit: 5)
      and the jump radius.]
- [x] Binding Heal (2026-09-17, holy day-1): 1240774@56 heals the target
      AND the caster (effect rows confirm two heals); the #24 pair-heal
      gates on both parties being hurt. [PROBE: the threat reduction in-game
      ("Low threat") — no threat API.]
- [x] Litany of Light (2026-09-17, holy day-1): 1317006 is a passive proc
      (aura 42) refunding mana when the previous heal was a different spell;
      the #24 variety lane alternates Greater Heal / Flash Heal. [PROBE: the
      refund % (kit: 5-10%) in-game.]
- [ ] Twilight Focus (14913: pushback protection %) — pure passive,
      recorded; confirm the in-game value.
- [ ] DP + Fear Ward: baseline (non-racial) availability.
- [x] Mind Flay range extension + slow effect (2026-09-17, shadow day-1):
      1225139 reads "+damage, +range, slow"; the baseline's MindFlay lane
      carries no range gate, so the extension applies to every existing cast
      (no new lane). [PROBE: the exact +yards / slow % / damage % in-game.]
- [x] Devouring Contagion spread-on-death effect (2026-09-17, shadow
      day-1): 1309950 = -50% DP mana (aura 108) + a 10y jump on death (aura
      4, base 10); the #21 lane keeps DP rolling in cleave/aoe so the spread
      chains. [PROBE: the spread target selection (nearest enemy?) and
      whether the jump carries the remaining duration.]
- [x] Shadow Word: Death + Early Demise (2026-09-17, shadow day-1): SW:D
      ladder 1309595@32 / 1309633@40 / 1309635@48 / 1309636@56 with
      CategoryRecoveryTime 15000; Early Demise 1310076 (+30% crit at <= 20%
      HP, effect rows) is BaseLevel 0 — the builder's level guard excludes it
      (probe). The #21 execute lane's window matches the talent's condition.
- [ ] Cross-check against the Icy Veins priest overview if it appears.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
