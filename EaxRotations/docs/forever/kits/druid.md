-- docs/forever/kits/druid.md -- WoW Forever Druid kit research.
-- WHAT:  eighth kit transcription, from the Icy Veins Forever druid class
--        overview (Meyra & Voulk, 2026-09-15) — the kit that invalidates
--        the repo's powershifting cat lanes and gives bear a real rotation.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Druid rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: NO spell IDs in this file until the Forever DBC lands (2026-09-17);
--         see docs/forever/dbc_runbook.md for the verification gate.

# Druid — WoW Forever kit (class overview 2026-09-15)

Sources: Icy Veins Forever Druid Class Overview (Meyra & Voulk
[QuestionablyEpic], 2026-09-15), from the talent calculator + BlizzCon
coverage. Community reproduction of Blizzard data: plan lanes on it, but
every claim is **unverified until the beta DBC resolves it** (no IDs, no
rank numbers below).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **DoTs can critically strike** (era-wide; shared with warlock) | Rake/Rip/Rejuv/Regrowth crit value up; crit-gear weighting shifts (Predatory Instincts synergy) |
| **Omen of Clarity baseline** — procs on offensive spells AND heals AND melee | Every spec gains a clearcast lane: free-cast detection via buff read (Pattern 11); resto/Balance weave clearcasts into priority |
| **Revive** — new out-of-combat res alongside Rebirth | Utility lane only; battle-res (Rebirth) remains the in-combat tool |
| Skyborne can be Druids (both factions, new custom forms) | Combo validation; form list unpublished — watch list |

## Balance — the Eclipse spec arrives
- **Eclipse** (NEW): rewards alternating Wrath ↔ Starfire; **stacks up to
  4**, more flexible and more powerful than Balance of Nature — the
  alternating-cast loop is the rotation's spine (track Eclipse stacks,
  Pattern 11).
- **Balance of Nature** (NEW): same alternation theme, stricter — talent
  interplay flagged for beta tuning.
- **Nature's Grace**: 10% cast speed AND GCD reduction for 3s on a
  non-periodic crit — crit-proc haste lane (GCD reduction is new for
  Vanilla-shaped casters).
- **Reflection/Subtlety buffs**: mana + threat largely solved — the spec's
  two historical raid blockers; threat-aware lane logic can relax.
- **Moonkin Form**: party crit to ALL spell/ability types (was spell-crit
  only); **exclusive with Leader of the Pack** — buff-role accounting.

## Feral — the form rework
- **Berserk** (NEW): 3-min CD, 15s, form-dependent — **Bear: removes Mangle
  CD + hits 3 targets; Cat: +100% crit chance on combo-point generators**;
  fear immunity during. A single spell with two rotation personalities.
- **Tiger's Fury reworked**: +15% physical damage 6s on 30s CD, **no energy
  cost**; with King of the Jungle it **generates 60 energy** — burst-window
  opener (damage buff + energy infusion).
- **Mangle** (talent) + **Lacerate** (trainer): bear finally has a rotation —
  Mangle (6s CD nuke), Lacerate (threat + bleed, stacks to 5), both cost
  rage; **Maul demoted to rage dump**. The vanilla bear "Maul-spam" loop is
  replaced by a three-button priority.
- **Furor reworked — POWERSHIFTING DIES**: entering Cat grants energy based
  on how much you had on exit and elapsed time; shifting no longer nets
  extra energy. The repo's powershifting cat lanes (a defining Vanilla-cat
  mechanic) are DEAD in Forever — cat rotation becomes pure in-form
  priority. Furor itself becomes skippable for long-in-form content.
- **Genesis / Rend and Tear**: bleed emphasis (Rake/Rip) — bleed-lane
  weights rise.

## Restoration — the HoT spec
- **Wild Growth** (NEW): party-wide HoT on a short CD — expected core raid/
  dungeon heal (cooldown-tracked lane).
- **Swiftmend no longer consumes the HoT** (still requires one active) —
  becomes a spam-able spot heal; the Vanilla "don't waste the Rejuv"
  interplay is gone.
- **Gift of the Earthmother**: Rejuv/Swiftmend/Wild Growth GCD −0.5s (1s
  GCD) — blanket-the-group speed lane.
- **HoTs can crit** + better in-combat regen (Reflection) — mana model
  loosens; HoT-centric builds displace direct Healing Touch.

## Druid-relevant racial detail (per-class page)
Night Elf (Elune's Light crit burst; Shadowmeld), Tauren (War Stomp,
Endurance), Skyborne both factions (Wind Blessed haste, Elemental Insight;
faction on-use). Standard set — see racials-and-talents.md.

## Flagged as unconfirmed
- Eclipse stack semantics (4-cap interaction with Starfire/Wrath damage
  bonuses) — talent-page derived.
- Berserk's exact Bear/Cat split (one spell, two effect sets) — verify the
  aura shape in the DBC.
- Skyborne druid form list (unpublished).
- King of the Jungle's energy-generation value (60) — demo tier.

## Spec files to author (Phase 4, post-DBC)
- `classes/druid/cat_forever.lua` — POWERSHIFT LANES REMOVED (the big one):
  pure in-form energy priority, critting Rake/Rip weights, Berserk-cat
  burst (CP-generator crit window), Tiger's Fury damage+energy opener.
- `classes/druid/bear_forever.lua` — Mangle/Lacerate/Maul priority with
  Lacerate stack tracking (Pattern 11), Berserk-bear AoE window
  (no-Mangle-CD + 3-target), threat re-derivation.
- `classes/druid/balance_forever.lua` — Eclipse alternation loop (stack
  reads), Nature's Grace crit-proc lane, relaxed threat logic, moonkin
  buff-role accounting (LotP exclusivity).
- `classes/druid/resto_forever.lua` — Wild Growth CD lane, non-consuming
  Swiftmend spot-heal spam, GotE 1s-GCD blanket priority, critting HoTs,
  Omen clearcast weaving.
- `classes/druid/leveling_forever.lua` — form-change energy model changes
  early cat leveling; Omen baseline helps all specs.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [ ] Resolve every named ability above BY NAME in the Forever bridge
      (zero-literal rule); record IDs into `DruidSpells` only then.
- [ ] Furor: confirm the new energy-on-shift formula from DBC effects —
      the powershifting-verdict probe (drives cat_forever's shape).
- [ ] Berserk: confirm one spell with form-branched effects.
- [ ] Lacerate stack cap + threat effect; Mangle 6s CD.
- [ ] Eclipse: stack cap 4 + Wrath/Starfire trigger shape.
- [ ] Swiftmend: confirm non-consumption (effect no longer removes the HoT).
- [ ] Wild Growth: party HoT effect shape + CD.
- [ ] Moonkin/LotP buff exclusivity (aura family check).
- [ ] Omen of Clarity: proc conditions across spells/heals/melee.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
