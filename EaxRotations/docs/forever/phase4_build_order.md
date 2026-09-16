-- docs/forever/phase4_build_order.md -- Phase-4 spec-authoring plan.
-- WHAT:  ranked build order for the Forever `_forever` spec deltas, so the
--        first beta days start authoring immediately instead of planning.
-- WHEN:  re-ranked when a new kit is transcribed, when the beta DBC lands
--        (2026-09-17), or when a beta patch changes a kit claim.
-- WHY:   the loader's `_forever -> _vanilla` fallback means untouched specs
--        keep working with ZERO files — every delta authored must earn its
--        place by changing rotation shape. Rank = kit delta x repo impact.
-- SAFETY: no spell IDs here; every delta follows the proven zero-literal
--         template (see "Per-delta standard work").

# Phase 4 build order — Forever spec deltas

## The template is proven (Wave 0 — DONE)

`classes/paladin/holy_forever.lua` (commit 3323725e5) established the full
pattern: baseline captured via a register interceptor (zero edits to the
`_vanilla` file), zero numeric literals (era-shared from the class spell
map, Forever-new resolved BY NAME via the pcall-required bridge module,
dormant until beta), battery scenarios proving every new lane fires,
never-inventory unchanged. Every delta below reuses this shape — the
battery's `load_spec` forever fallback and bridge stub seeding already
exist, so new deltas are scenario-adds, not framework work.

## Ranking rule

**Rank = kit delta (how much the rotation shape changes) × repo impact
(which existing code it touches) — modulated by risk.** A kit that only
renames/retunes keeps the `_vanilla` fallback working and gets NO delta
file until the DBC proves otherwise.

## Wave 1 — beta days 1–3 (class-defining mechanics, heaviest impact)

| # | Delta | Why first |
|---|---|---|
| 1 | `shaman/enhancement_forever.lua` | Maelstrom Weapon stack weave + 8s Stormstrike with dodge/parry resets + Fire Nova de-toteming — sits on the repo's most maintenance-heavy code (totem twist). The Fire Nova change ripples into every shaman file's totem scheduler. |
| 2 | `shaman/elemental_forever.lua` | Lava Burst + hard Flame Shock dependency (the flagship new loop), Fire Nova spell lane (shares the de-toteming work), shorter LB/CL cadence. |
| 3 | `mage/fire_forever.lua` | Hot Streak 3-stack Pyro finisher — a brand-new stacking mechanic (Pattern 11 reads) on the historically highest-population class. Wake of Fire kill-chain lane. |
| 4 | `mage/arcane_forever.lua` | Arcane Blast 4-stack loop with expiry-on-other-spell — a genuinely new rotation shape for a spec that previously had no delta value. Missile Barrage proc lane. |

Wave-1 prereq on beta day: name-resolve the wave-1 kit abilities
(Maelstrom Weapon, Lava Burst, Stormstrike, Fire Nova, Hot Streak, Pyroblast,
Arcane Blast, Missile Barrage…) in the fresh bridge BEFORE authoring — a
miss downgrades the lane to dormant, never a guessed ID.

## Wave 2 — beta days 3–7

| # | Delta | Why / dependency |
|---|---|---|
| 5 | `warrior/fury_forever.lua` | GATED on the day-1 rage-formula probe (kit doc): if rage-from-damage really shifts, every rage lane re-derives; CD split + ambient Enrage + both-weapon Whirlwind land regardless. |
| 6 | `hunter/survival_forever.lua` | Near-total spec reshaper (melee weave, Mongoose core, trap spam) — biggest single-spec rewrite in the queue; needs the pet-present context field. |
| 7 | `hunter/beast_mastery_forever.lua` | 2-hawk maintenance loop (Summon Hawk CD-shared with Arcane Shot); shares the pet context field from #6. |
| 8 | `hunter/marksmanship_forever.lua` | Lone Wolf petless branch (same context field); Sniper Shot context-gated burst. |
| 9 | `warrior/protection_forever.lua` | Shield-gated structural check, TC-in-defensive AoE loop, independent defensive thresholds. |
| 10 | `warrior/arms_forever.lua` | Rend-proc Overpower, Improved Slam weave, Spearing Strike encounter gate. |
| 11 | `mage/frost_forever.lua` | FoF→Ice Lance burst lane, cheaper Shatter, Blizzard retiming — smallest of the wave-1-class deltas. |

## Wave 3 — after the remaining kits are transcribed

Priest, warlock, druid, rogue deltas are UNRANKED until their kit docs land
(TRANSCRIPTION_QUEUE.md: priest, warlock, druid, rogue QUEUE) — a delta
cannot be justified without knowing what changed. Pre-staged expectations
from era-wide notes:

- `priest/*` — Spirit/FSR rules + PW:S absorb semantics (Patterns 12/13).
- `warlock/*` — dot-table rewrites; WotLK-rank audit gates apply.
- `druid/*` — form-switch gating; largest file count (cat/bear/balance/
  caster/resto) — expect the most deltas if forms change.
- `rogue/*` — combo-point builder/finisher retunes.
- `*/leveling_forever.lua` for every class — low-risk fillers between waves;
  only where the kit changes early-level rotation (Holy Strike-style
  level-gated buttons).

## Re-rank triggers

1. Kit transcription completes for a queued class → rank its deltas.
2. Beta DBC lands → bridge name-resolve pass over all wave lists; a kit
   claim that fails downgrades its delta's rank.
3. Rage-formula probe verdict → fury/arms ranks move.
4. Beta patch notes touch a transcribed kit → re-verify affected lanes.

## Per-delta standard work (unchanged from the proven template)

1. Worktree on `feat/forever-era-2026-09-15`; one delta per commit.
2. Capture the `_vanilla` baseline via register interceptor (no baseline
   edits); splice delta lanes at the documented priority points.
3. Zero numeric literals; era-shared from the class spell map, Forever-new
   by name via the bridge module (dormant on miss).
4. Battery: add scenarios for every new lane; strict never-inventory
   preserved; every lane proven firing.
5. Unit suite pins the splice/dormancy/zero-literal contracts.
6. Full gate (19 checks) + verify_all green before commit.
