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
- `classes/hunter/leveling_forever.lua` — Aimed Shot baseline reshapes early
  rotations; trap-in-combat opens leveling tools.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [ ] Resolve every named ability above BY NAME in the Forever bridge
      (zero-literal rule); record IDs into the class spell map only then.
- [ ] Confirm Aimed/Multi shared CD + trap-in-combat semantics from the DBC
      effects (cast-time/aura shape), not the article.
- [ ] Confirm hawk summon mechanics (duration, cap, shared CD) — pet-like
      entities may need pet-handler awareness (apidocs: pet-handler.md).
- [ ] Survival melee abilities: verify melee-range lanes against unit_distance
      gating (Pattern: squared distance).

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
