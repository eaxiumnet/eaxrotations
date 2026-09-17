-- docs/forever/kits/shaman.md -- WoW Forever Shaman kit research.
-- WHAT:  second kit transcription, from the Icy Veins Forever shaman class
--        overview (Seksixeny, spell/talent pass added 2026-09-15) — the kit
--        that touches the repo's most maintenance-heavy code: totem twist,
--        fire-nova-totem, and shield/weapon imbue lanes.
-- WHEN:  updated as the beta DBC verifies (or corrects) each claim below.
-- WHY:   day-1 Shaman rotations must encode the confirmed deltas, not TBC
--        assumptions; every strategy change traces to a source line here.
-- SAFETY: spell IDs below are DBC-verified (beta 1.60.1.69893, 2026-09-17)
--         unless marked [PROBE]; see docs/forever/dbc_runbook.md.

# Shaman — WoW Forever kit (class overview 2026-09-15)

Sources: Icy Veins Forever Shaman Class Overview (Seksixeny; changelog
"all spell and talent details" 2026-09-15), built from the Forever talent
calculator + BlizzCon coverage. Community reproduction of Blizzard data:
plan lanes on it, but every claim is **unverified until the beta DBC
resolves it** (no IDs, no rank numbers below).

## Class-wide changes (all three specs)

| Change | Rotation impact |
|---|---|
| **Lightning Bolt max rank: 2.5s cast** (was 3.0s baseline) | Elemental filler cadence tightens; cast-time math in the FS/LB cycle changes everywhere |
| **Chain Lightning: 0.5s faster baseline** | Off-target/burst lane is snappier without deep Elemental investment |
| **Fire Nova is NO LONGER A TOTEM** — a cast that detonates your Fire Totem (30y, +15y via Elemental Reach) | Kills the fire-nova-totem twist lane outright; becomes a normal AoE spell lane gated on a live Fire Totem |
| **Totemic Projection / Totemic Recall** — move totems up to 30y / recall to save mana | Totem economy rework the stub predicted: mobility + mana-recovery lanes replace rigid drop-and-forget; totem-twist maintenance code can lean on these |
| **Call of the Elements** — drop a full totem set, 3s cast | Set-drop lane for opener/AoE; changes how the totem scheduler batches |
| **Ghost Wolf: 2.0s baseline; Improved makes it instant + usable everywhere** | Mobility lane (kiting, gap-close in Enh); instant everywhere also affects disengage/reposition logic |
| **Merged spell hit/crit (Ele) + merged melee hit/crit (Enh)** (Deep Dive, era-wide) | Simplifies the hit-table assumptions in both DPS specs; one stat read per school |
| **Every spec has a new 31-pt capstone** (Lava Burst / Rage of the Farseer / Riptide) | Capstone presence is itself a lane: each spec's core loop changes shape |

## Elemental
- **Lava Burst** (31-pt capstone): long-cast nuke, **20% stronger on a
  Flame-Shocked target** — introduces the classic keep-Flame-Shock-up loop;
  the FS dependency becomes a hard lane gate (debuff_remains check).
- **Lightning Overload**: Nature spells occasionally duplicate with **no
  extra threat** — proc, no rotation cost; threat logic must not double-count.
- **Elemental Alacrity**: reduces Lava Burst + Nature cast times.
- **Call of Flame**: now boosts all Fire **spells** (incl. the new Fire Nova),
  not just Fire Totems — fire damage weighting shifts.
- **Elemental Fury** 5-pointer, earlier in tree; **Call of Thunder** 1-pointer.
- **Improved Fire Nova**: strong AoE talent for the new spell.
- **Elemental Reach**: extends "more spells" + **Flame Shock by 15y** — FS
  castable at normal spell range (dotting from range without closing).
- **Earthbound**: Earthbind Totem **roots nearby targets 5s on cast** —
  encounter/PvP CC lane ( PvE add-slow).

## Enhancement — the battlemage rework
- **Maelstrom Weapon**: melee attacks stack a buff that progressively cuts
  **Lightning Bolt mana cost + cast time** — weave LBs at high stacks. THE
  new core mechanic; stack count reads via buff points (Pattern 11) once
  the DBC lands.
- **Stormstrike: 8s CD baseline** (was 20s in Vanilla!) + **Improved
  Stormstrike**: up to 100% chance to enable in-combat mana regen on use,
  and up to 100% chance to **reset its own CD on Dodge/Parry** — SS becomes
  a near-every-GCD button with proc-driven resets (reactive priority).
- **Rage of the Farseer** (31-pt capstone): 3-min CD attack-speed burst →
  accelerates MW stacking — pairs the two new mechanics into a burst window.
- **Mental Dexterity**: AP from up to 100% of Intellect; **Mental Quickness**:
  spell damage from up to 30% of Intellect — caster gear viable on a melee.
- **Spirit Weapons**: Parry + **-30% threat… unless Rockbiter is imbued,
  then +30%** — Rockbiter becomes the tank-imbue; Enh can off-tank/dungeon-
  tank in a pinch (tank-mode branch gated on imbue choice).
- **Thundering Strikes**: crit with all spells AND abilities (cross-spec).
- **Ancestral Knowledge**: 2%/pt Intellect (was 1%).
- **Anticipation**: Dodge investment that synergizes with Stormstrike resets.
- **Shamanistic Focus**: massive mana relief for Shield recasting (leveling).
- **Elemental Weapons**: pickable much earlier (early imbue access).
- **Elemental Devastation** (Ele-tree, for Enh): melee crit after spell crits.

## Restoration
- **Riptide** (31-pt capstone): direct heal + HoT + **Chain Heal +25% on its
  target** — the pre-Cata "keep Riptide up for Chain Heal" loop arrives in
  Forever; Riptide becomes the most-loaded heal lane.
- **Healing Way reworked**: flat **+25% Healing Wave, just works** (old: stack
  a buff by repeatedly healing the same target) — deletes the HW-stacking
  upkeep logic our healing lanes carry; big simplification.
- **New Water Shield**: 2% mana per orb spent; healing crits can trigger —
  default resto shield in endgame (shield-choice lane: Water for mana vs
  Lightning for throughput).
- **Restorative Totems**: Mana Spring **+25%**, Healing Stream **+50%** —
  both totems become actually worth scheduling (totem-lane weights rise).
- **Tidal Mastery**: healing crits ONLY now (no more Lightning crit) — no
  DPS takeaway; pure resto.
- **Tidal Focus**: global **Hit chance** + slight heal-cost cut — cross-spec
  talent (hit-capping healers interrupting with Earth Shock).
- Era-wide: **buff cap removed** — totem/buff slot accounting simplifies.

## Shaman-relevant racial detail (per-class page; numbers = press tier)
| Race | Detail relevant to shaman rotations |
|---|---|
| Tauren | **War Stomp** AoE stun; Endurance +5% HP / +1% hit; Plainsrunning ramping move speed |
| Orc | **Blood Fury** on-use throughput burst; **Shatter Curse** curse immunity + magic-damage reduction (8s); Axe Spec +1% crit; Hardiness -20% stun duration |
| Troll | **Berserking** on-use haste (10s per this page; hunter page says 3-min CD attack-speed — resolve from DBC); **Rapid Regeneration** 50% max HP over time; Beast Slaying +5% |
| Dwarf (NEW combo) | Stoneform (bleed/poison/disease immunity + physical reduction); Mace Spec +1% crit; Big Game Hunter +5% vs beasts |
| Skyborne Horde (Windshaper) | **Walk on Air** on-use glide; **Skysight** +10% move speed; Wind Blessed +1% haste; Elemental Insight +5% vs elementals |

Flagged: the Orc Blood Fury numbers differ between the hunter page (AP on a
2-min CD) and this page (10% throughput for 15s) — verify from the DBC, do
not encode either.

## EAX impact notes (the maintenance-heavy lanes)
- **Fire Nova no longer a totem** removes a whole twist family — the
  fire-nova-totem lanes in `enhancement_sylvanas.lua`/
  `elemental_sylvanas.lua` collapse into a plain spell gate (live Fire
  Totem check + CD).
- **Totem economy** (Projection/Recall/Call of the Elements) is the
  modernization the stub predicted for the totem-twist scheduler: expect
  set-drop openers + reposition/recall lanes instead of per-totem timers.
- **Maelstrom Weapon** is a Pattern-11 read (`buff_points`) for stack count;
  the LB weave lane gates on it.
- **Healing Way** simplification deletes the HW-stack upkeep from resto
  healing lanes; **Riptide** adds the FS-style dependency loop to heals.

## Spec files to author (Phase 4, post-DBC)
- `classes/shaman/elemental_forever.lua` — FS→Lava Burst dependency gate,
  Fire Nova spell lane (Fire Totem live check), Overload threat-neutral
  awareness, shorter LB/CL cadence.
  **Status (2026-09-17, beta day): DAY-1 VERIFIED** — Lava Burst casts the
  max-rank row 1238300@60 with the Flame Shock remains gate and the 10s
  category CD declared to the readiness check; Fire Nova casts the corrected
  totem-detonating row and holds without a live fire totem; Elemental Mastery
  needs no delta (talent row 16166 still in the client's Elemental tree —
  tier 6, prereq Elemental Fury 5 — and the baseline lane casts it from the
  class map; the client's SpellName table has no name row for it, so it is
  bridge-invisible, see the probe list). OPEN (wave 2): Lightning Overload
  threat-neutrality, Elemental Alacrity cast-time math.
- `classes/shaman/enhancement_forever.lua` — MW-stack LB weave (Pattern 11),
  8s Stormstrike + dodge/parry reset reactivity, Rage of the Farseer burst
  window pairing, Rockbiter tank-mode branch.
  **Status (2026-09-17, beta day): DAY-1 VERIFIED** — the weave lane spends
  Lightning Bolt at the DBC-confirmed 5-stack cap (fails open on an unusable
  stack read), the Stormstrike core rides the 8s RecoveryTime, and the Fire
  Nova lane casts the corrected totem-detonating cast row and holds without a
  live fire totem. Shocks and imbues re-verified (above) — no lane changes
  needed. OPEN (wave 2, talent-side): Improved Stormstrike dodge/parry reset,
  Rage of the Farseer pairing, Rockbiter tank-mode branch.
- `classes/shaman/restoration_forever.lua` — Riptide→Chain Heal loop,
  flat Healing Way, Water Shield default, Restorative Totem weights.
- `classes/shaman/leveling_forever.lua` — early Stormstrike (8s CD) leveling
  loop per the page's build sketch, instant Ghost Wolf mobility, early imbues.

## Verification checklist (beta DBC, dbc_runbook.md step 5-6)
- [x] Resolve every named ability above BY NAME in the Forever bridge
      (2026-09-17: all P1 shaman names resolve — Maelstrom Weapon 408498/
      408505, Stormstrike 17364, Fire Nova 8349/11307, Totemic Projection
      437009, Totemic Recall 36936, Call of the Elements 66842, Lava Burst
      408490/1238300, Flame Shock 8050).
- [x] Fire Nova **re-verified 2026-09-17 (role fix)**: the classic rows
      8349@12 … 11307@52 are totem-INTERNAL damage rows (no mana, no cast
      time, no GCD, no cooldown, not trainer-taught); the player casts are
      408341@12 … 408345@52 ("Instantly inflicts $11307s1 fire damage to
      enemies within $11307a1 yd of your active Fire totem"), trainer-taught
      under Elemental Combat, 520 mana at rank 5, 1.5s GCD, and
      **CategoryRecoveryTime 6000** (the earlier "no DBC cooldown row" came
      from the RecoveryTime column only). The max-rank mirror picked 11307 on
      the raw @52 tie (lowest id wins), so the bridge builder now pins
      Fire Nova to 408345 via MAXRANK_OVERRIDES. Lanes hold when no fire
      totem is up (the detonation is a no-op without one) — see
      `forever_fire_nova_totem`.
- [x] Lava Burst: Flame Shock dependency confirmed in description text
      ("If your Flame Shock is on the target") + the bonus effect (+20
      EffectBasePoints; the rendered tooltip reads 21% with talents); max
      rank 1238300@60 (10s category CD on both 408490 and 1238300); lane
      casts the max-rank mirror.
- [x] Maelstrom Weapon (complete 2026-09-17): buff row 408505 ("Reduces the
      cast time and Mana cost of your next Lightning Bolt spell" — baseline
      408498 is the talent text); **SpellAuraOptions CumulativeAura = 5
      confirms the 5-stack cap** (talent row 408498's third effect
      base_points 5, aura 108 at -20%/stack), proc mask 81920 = melee hit,
      ProcChance 100. The weave lane spends at 5 stacks and fails open when
      the stack read is unusable.
- [x] Stormstrike CD 8s confirmed (RecoveryTime 8000 on 17364; bridge
      cooldown field reads 8.0). OPEN: Improved Stormstrike reset/
      dodge-parry semantics (talent-side, wave 2).
- [x] Shocks re-verified 2026-09-17: the casts are the class-map classic rows
      (Earth Shock 10414@60, Flame Shock 29228@60, Frost Shock 10473@58,
      Lightning Bolt 15208@56 with cast_ms 2500 — the kit's 2.5s cadence is
      the live row, Chain Lightning 10605@56 with cast_ms 2000). The
      408xxx/1220xxx name-mates are internal or variant rows (408690 is the
      "S03 - Earth Shock - Way of Earth" taunt variant); no lane change.
- [x] Weapon imbues re-verified 2026-09-17: the trainer-taught tops are the
      class-map ids (Rockbiter 16316@54, Flametongue 16342@56, Windfury
      16362@60, Frostbrand 16356@58); the same-name 461xxx rows exist but are
      not in the trainer list, and Flametongue/Rockbiter/Frostbrand carry no
      SpellClassOptions row (only Windfury does), so they are absent from the
      bridge mirrors — the class map covers the lanes, no change needed.
- [ ] Rockbiter threat modifier (+30% with Spirit Weapons) — threat-logic
      branch flag.
- [x] Totemic Projection/Recall/Call of the Elements spell shapes
      (2026-09-17): 437009 (60s CD, effect-28 target [87,0]), 36936
      (effect-110 self), 66842 (effect-97 self). Cast-time index → seconds
      mapping needs the SpellCastTimes table (not extracted) — ranges/mana
      per tooltip when read live.
- [ ] Blood Fury numbers (pages disagree) + Berserking duration/CD.

Battery rule (Pattern 17): every new lane must fire in a battery scenario on
day 1 — strict never=0, no SoD-style retrofit.
