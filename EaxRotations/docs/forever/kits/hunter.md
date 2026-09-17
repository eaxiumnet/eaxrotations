-- docs/forever/kits/hunter.md -- WoW Forever Hunter kit research.
-- WHAT:  first non-paladin kit transcription, from the Icy Veins Forever
--        hunter class overview (Impakt, updated 2026-09-15) — the series
--        derived from Blizzard's talent-calculator dump + BlizzCon reveals.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Hunter rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: NO spell IDs in this file until the Forever DBC lands (2026-09-17);
--         see docs/forever/dbc_runbook.md for the verification gate.

# Hunter — WoW Forever kit (class overview 2026-09-15)

Sources: Icy Veins Forever Hunter Class Overview (Impakt/BDGG, 2026-09-15),
built from the Forever talent calculator + BlizzCon coverage. Community
reproduction of Blizzard data: names/semantics are trustworthy enough to plan
lanes, but every claim here is **unverified until the beta DBC resolves it**
(no IDs, no rank numbers below).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Traps usable in combat** (was pre-combat only) | Trap lanes become mid-fight tools: freezing/freeze coverage in PvP loops, damage traps in AoE/PvE priority instead of setup-only |
| **Aimed Shot baseline for all Hunters, shares CD with Multi-Shot** | The TBC Aimed-vs-Multi priority fork becomes a shared-CD weave decision in EVERY hunter spec; Aimed no longer a talent-gated rank pick |
| **Abilities no longer clip Auto Shot** (Auto still needs standing still) | Kill the swing-timing weave logic: no cast-scheduling around auto shots — rotation order is pure priority, engine handles the rest |
| **Pets scale with hunter stats** (Agility etc.) | BM pet damage becomes gear-coupled — pet-heavy BM legs scale through endgame; pet-attack lanes gain weight |
| **Aspect of the Beast** — melee attack power aspect | New aspect lane, primarily Survival (melee SV synergy); aspect selection becomes a state-aware choice |
| **Lone Wolf** — early MM talent, +20% damage petless | Petless MM is now a real path: rotations branch on pet presence (context field needed — pet_up check) |

## Beast Mastery
- **Summon Hawk** (capstone-adjacent talent): shares CD with Arcane Shot;
  hawk attacks for up to 18s; **max 2 hawks** active alongside the pet.
  Rotation keeps 2 hawks up and weaves shots between — Arcane Shot becomes a
  hawk-refresh decision, not a filler.
- Everything else "mostly the same": pet as tank + main damage in world play.

## Marksmanship
- **Sniper Shot** (31-pt capstone): massive 4s-cast shot; strong burst, may
  be a PvE damage loss at that cast time — treat as PvP/execute-style burst
  lane, gate on context (not a rotation filler).
- **Lone Wolf**: petless +20% damage (see class-wide table) — MM's defining
  fork; needs a pet-present context field to branch.

## Survival — the reworked spec
Primarily **melee** now (dual-wield focused), traps woven throughout:
- **Savage Strikes** + **Predator's Edge**: dual-wield melee damage boosters.
- **Strider Kick**: NEW rotational melee ability.
- **Expose Prey** + **Lacerating Strikes**: make Mongoose Bite stronger and
  more frequent — Mongoose moves from situational proc-lane to core.
- **Resourcefulness**: enables near-continuous trap + melee spam (trap CDs /
  costs reduced — trap lanes become spammable, not opportunistic).
- Keeps "excellent ranged capabilities" — the forever spec is a hybrid weave
  (ranged fillers + melee windows), closest classic analog is TBC SV but far
  more melee-committed.

## Hunter-relevant racial detail (press-sourced, per-class pages)
| Race | Detail relevant to hunter rotations |
|---|---|
| Night Elf | **Elune's Light** on-use: +10% crit for 15s (burst-lane CD); **Shadowmeld usable in combat** (defensive/vanish-style save) |
| Human (NEW combo) | **Will to Survive** on-use stun break (no PvP-trinket CD share — double defensive) |
| Tauren | **War Stomp** AoE stun; Endurance +5% HP and +1% hit |
| Orc | **Blood Fury** AP on-use (2-min CD); **Shatter Curse** curse immunity + magic damage reduction |
| Troll | **Berserking** attack speed on-use (3-min CD); **Rapid Regeneration** 50% max HP over time |
| Dwarf | Stoneform bleed/poison/disease immunity + physical damage reduction |

Skyborne (both factions can be Hunters): on-use **Walk on Air** (glide),
Alliance **Read Ley Line** (health/mana regen burst) vs Horde **Skysight**
(+10% move speed), passive **Wind Blessed** +1% haste, **Elemental Insight**
+5% damage vs elementals.

## Flagged as unconfirmed
- World buffs reportedly no longer working inside raids (rumor tier — meta
  note only; no rotation impact unless confirmed).

## Spec files to author (Phase 4, post-DBC)
- `classes/hunter/beast_mastery_forever.lua` — 2-hawk maintenance lane
  (CD-shared with Arcane Shot), pet-stat-scaling weight, shot priority weave.
- `classes/hunter/marksmanship_forever.lua` — Lone Wolf petless branch,
  Sniper Shot burst lane (context-gated), shared Aimed/Multi CD weave.
- `classes/hunter/survival_forever.lua` — near-total rewrite: melee weave
  (Mongoose core via Expose Prey/Lacerating Strikes, Strider Kick, dual-wield),
  spam-capable trap lanes, ranged filler windows.
  **Status (2026-09-17, beta day): DAY-1 BUILT (additive + one reorder)** —
  Mongoose Bite (class map; 5s category CD; the react window is engine state
  — the activation auras 5302/1310726 are classless rows the bridge cannot
  carry, so readiness is the honest gate) and the NEW Strider Kick (1317257,
  RecoveryTime 8000, "deals $s2% melee weapon damage") spliced above the
  baseline's Raptor Strike, both melee-range (6yd) + combat gated; the
  baseline's MultiShot lane is re-emitted immediately above AimedShot so the
  DBC-confirmed SHARED 6s cooldown (both in SpellCategory 2,
  CategoryRecoveryTime 6000) picks the right shot for the target count —
  previously Aimed always won and the shared CD starved Multi on every
  multi-pull. NOT landed (documented): Aspect of the Beast — its rows
  (13161/1299445/1299446/1299447) are BaseLevel 0, so the bridge builder's
  level guard excludes the whole aspect and the class map has no entry; a
  by-name lane would be permanently dormant. Fix path: allow BaseLevel-0 rows
  with a real SpellLevel in the builder (touches every mirror — its own
  commit) or add a class-map entry with DBC evidence. Traps-in-combat needs
  no lane change (the baseline trap lanes simply stop being pre-combat-only).
  Resourcefulness is a COST reduction + mana-regen proc, not a cooldown cut
  (kit said "CDs/costs").
- `classes/hunter/leveling_forever.lua` — Aimed Shot baseline reshapes early
  rotations; trap-in-combat opens leveling tools.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Resolve the wave-2 names (2026-09-17): Mongoose Bite 1495/14271,
      Raptor Strike 2973/14266, Wing Clip 2974/14268, **Strider Kick 1317257**,
      Survival talents (Savage Strikes 19159, Predator's Edge 1310627,
      Expose Prey 1310532, Lacerating Strikes 1310533/1310536,
      Resourcefulness 440529), Aspects (Monkey 13163, Hawk 13165/25296),
      Traps (Immolation 13795/14305, Explosive 13813/14317, Freezing
      1499/14311, Frost 13809), shots (Aimed 19434/20904, Multi 2643,
      Arcane 3044/14287), Counterattack 19306/20910.
- [x] Aimed/Multi shared CD CONFIRMED (2026-09-17): both carry
      CategoryRecoveryTime 6000 in **SpellCategory 2** ("Direct Damage -
      Spell") — the same lockout, which makes the shot choice exclusive (the
      survival delta reorders Multi above Aimed so the 2+-target gate decides
      instead of Aimed always winning).
- [x] Strider Kick (2026-09-17): 1317257@30, RecoveryTime 8000, effect 121
      (weapon damage) + effect 31 (threat). No stance/form gate in the text.
- [x] Mongoose Bite (2026-09-17): 1495@16 … 14271@58 with
      CategoryRecoveryTime 5000, class 9; the classic "after you dodge"
      react window plus the Expose Prey proc (1310532: "attacks against
      targets with Hunter's Mark have a $s1% chance to activate your Mongoose
      Bite for $5302d", trigger 1310726 = a classless self-dummy aura). The
      delta gates on engine readiness instead of guessing an aura id.
- [x] Resourcefulness (2026-09-17): text = trap/melee mana COST reduction +
      a mana-regen-on-crit proc; no trap cooldown reduction (kit wording
      corrected). Trap families: Immolation/Explosive share SpellCategory
      411 (30s lockout), Freezing/Frost share 2183 — fire and frost traps are
      independent.
- [x] Aspect of the Beast (2026-09-17): exists with a 4-rank ladder
      (13161@30 / 1299445@40 / 1299446@50 / 1299447@60, melee-AP aspect
      text) but every row is **BaseLevel 0**, so the bridge builder's level
      guard excludes it and the class map has no entry — see the survival
      status note for the fix path.
- [ ] Traps-in-combat: in-game probe (a mechanic flag, not DBC-readable).
- [ ] Confirm hawk summon mechanics (duration, cap, shared CD) — pet-like
      entities may need pet-handler awareness (apidocs: pet-handler.md).
      [BM delta, #9]
- [ ] Survival melee abilities: verify melee-range lanes against unit_distance
      gating (Pattern: squared distance). DONE for Mongoose/Strider (6yd,
      mirroring the baseline's Raptor/WingClip gate).

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
