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
| 5 | `druid/cat_forever.lua` | PROMOTED (re-rank 2026-09-16): destructive delta — Powershifting dies (Furor rework) so existing cat lanes are REMOVED, plus Berserk-cat burst + Tiger's Fury opener + critting bleeds. Furor verdict is a day-1 DBC probe, same gate class as fury but with the bigger delta. |
| 6 | `druid/bear_forever.lua` | PROMOTED (re-rank 2026-09-16): whole new rotation (Mangle / Lacerate stacks / Maul demoted to dump) replacing Maul-spam; shares Berserk + Furor resolution with #5. |
| 7 | `warrior/fury_forever.lua` | GATED on the day-1 rage-formula probe (kit doc): if rage-from-damage really shifts, every rage lane re-derives; CD split + ambient Enrage + both-weapon Whirlwind land regardless. Demoted one slot by cat's destructive delta. |
| 8 | `hunter/survival_forever.lua` | Near-total spec reshaper (melee weave, Mongoose core, trap spam); needs the pet-present context field. |
| 9 | `hunter/beast_mastery_forever.lua` | 2-hawk maintenance loop (Summon Hawk CD-shared with Arcane Shot); shares the pet context field from #8. |
| 10 | `warlock/affliction_forever.lua` | PROMOTED (re-rank 2026-09-16): dot-maintenance + Drain Hope amplify windows + critting-dot tables — the repo's dot tables are audit-gated (WotLK-rank IDs), highest repo impact of the wave-3 kits. |
| 11 | `warrior/protection_forever.lua` | Shield-gated structural check, TC-in-defensive AoE loop, independent defensive thresholds. |
| 12 | `hunter/marksmanship_forever.lua` | Lone Wolf petless branch (same context field); Sniper Shot context-gated burst. |
| 13 | `warrior/arms_forever.lua` | Rend-proc Overpower, Improved Slam weave, Spearing Strike encounter gate. |
| 14 | `mage/frost_forever.lua` | FoF→Ice Lance burst lane, cheaper Shatter, Blizzard retiming — smallest DPS delta in the build order. |

**Wave-1 status (2026-09-17)**: all four BUILT and beta-day verified (commits
4e67da40f, 6a1821070, 69985c42a, 433dc6d61, b401aff58) — shaman enh/ele,
mage fire/arcane.
**Wave-2 status (2026-09-17)**: #5 `druid/cat_forever.lua` BUILT (destructive:
Powershift dropped per the Furor rework, Tiger's Fury replaced, Berserk burst
added — probe P2 #1 resolved "rework shipped" from the client text). #6
`druid/bear_forever.lua` BUILT (additive: Mangle/Lacerate core above the
Swipe/Maul block, Berserk-bear window). #7 `warrior/fury_forever.lua` BUILT
(verdict-independent subset: the CD split's Recklessness burst lane; the P2
rage-formula probe is not client-resolvable, so no rage re-tuning and no
demotion — the question stays open in the kit). #8
`hunter/survival_forever.lua` BUILT (additive + shot reorder: Mongoose
Bite/Strider Kick melee core above Raptor Strike, MultiShot above AimedShot
for the DBC-confirmed shared cooldown; Aspect of the Beast documented as
blocked by the builder's BaseLevel-0 guard). #9
`hunter/beast_mastery_forever.lua` BUILT (Summon Hawk above the Arcane Shot
filler it shares a 6s category CD with; the client's 3-hawk cap and 18s
lifespan recorded, kit's "2 hawks" corrected). #12
`hunter/marksmanship_forever.lua` BUILT (Sniper Shot execute/PvP window, the
shared-CD shot reorder, and the Lone Wolf pet-fork via NS.is_spell_learned).
#10 `warlock/affliction_forever.lua` BUILT (the kit's "Drain Hope" is
WRACK 1316697 in the beta client — a name that does not exist anywhere;
Haunt/Unstable Affliction are engraving-granted and gated on
is_spell_learned, with the UA/Immolate slot drop). #11
`warrior/protection_forever.lua` BUILT (the TC lane replaced with a
stance-agnostic version — the baseline's Battle-only gate blocked the
class-wide Defensive unlock; the Vanguard OOC Defensive charge opener added
via is_spell_learned). #13
`warrior/arms_forever.lua` BUILT (Spearing Strike encounter nuke above
Mortal Strike; the Slam lane replaced under Improved Slam — the swing-window
gate would suppress most 15s-cooldown casts; Bloodthrill/Sudden Death
recorded as engine-readiness probes, not guessed gates). #14
`mage/frost_forever.lua` BUILT (engraving-gated Ice Lance burst in the Frost
Nova window, Icy Veins — absent from the kit but trainer-taught on the
client, with the class map pointing at Cold Snap — and the Winter's Chill
replacement reading the applied debuff 12579 via a new BUFF_OVERRIDES pin;
Fingers of Frost recorded as a BaseLevel-0 bridge gap).
**Wave 2 COMPLETE (2026-09-17).** Wave 3 (#15–#26) in progress: #15
`druid/balance_forever.lua` BUILT (the Eclipse pair — Wrath-procs-3-fast-
Starfires per the client text, NOT the kit's 4-stack alternation; Balance of
Nature has no client row; Nature's Grace/Dreamstate/Moonkin are passives).
#16 `druid/resto_forever.lua` BUILT (3 lanes: Wild Growth 6s party HoT when
>= 2 members hurt, non-consuming Swiftmend spot-heal under the emergency
lane, GotE-gated Rejuvenation blanket). Tree of Life 439745 recorded as the
resto open probe (form semantics unresolved, not laned).
#17 `warlock/demonology_forever.lua` BUILT (2 lanes: the Demonic Pact partner
maintenance — summon the other demon while a sacrifice aura is up, per the
425464 persistence text — and the Decimation Soul Fire window, with the
applied proc 440873 pinned in the builder's BUFF_OVERRIDES; Demonic
Sacrifice's class-less 18788 row keeps the sacrifice cast manual).
#18 `warlock/destruction_forever.lua` BUILT (3 lanes: the Immolate-kept
Incinerate nuke, the Shadow and Flame window lane choosing Incinerate or
Shadow Bolt by the fire/shadow window aura — both window rows class-less and
now pinned in the builder's CLASS_LESS_BUFF_NAMES — and the off-target Bane
of Havoc cleave, respecting the one-Bane limit; the kit's max-rank
no-consume claim corrected to Backdraft/S&F).
#19 `priest/discipline_forever.lua` BUILT (3 lanes: the Soul Warding shield
loop with combined PW:S + Divine Aegis absorb accounting, the Penance heal
on the moderate-damage tier, and the offensive Penance inside the Power in
Light Holy Fire window; the dual-mode cast row 1316995 pinned in the
builder's MAXRANK_OVERRIDES and the applied Aegis shield 431624 in
BUFF_OVERRIDES).
#20 `rogue/assassination_forever.lua` BUILT (3 lanes: the Mutilate 2-CP
builder with the both-hand dagger gate and the poison tag, the Venom
poison-window finisher at 5 CP, and the Improved Expose Armor 5-CP refund
upgrade of the assigned armor lane; the energy-model probe stays
unconfirmed, so the vanilla energy shape is kept).
#21 `priest/shadow_forever.lua` BUILT (2 lanes: the Shadow Word: Death
Early Demise execute the baseline never had, and the Devouring Contagion
cleave maintenance lane keeping DP rolling so deaths spread it; Improved
Mind Flay is a pure passive on the range-gateless baseline lane, Early
Demise recorded as a BaseLevel-0 bridge gap).
#22 `rogue/subtlety_forever.lua` BUILT (2 lanes: the Thousand Cuts stack
engine firing the discounted Hemorrhage under the baseline's pooling floor,
and the Cutthroat stealth-free Ambush proc; the applied TC stack row
1310723 and the Cutthroat proc 462707 are pinned in BUFF_OVERRIDES).
#23 `rogue/combat_forever.lua` BUILT (2 lanes: the Restless Blades
spender-timing lane that spends at 3-4 CP when a tracked CD sits inside the
2s x combo shave window, and the Puncturing Wounds dagger generator
promoted above the Hemorrhage filler; Hack and Slash recorded as a
class-less bridge gap + Blade Dance as a rune-granted backlog candidate).
#24 `priest/holy_forever.lua` BUILT (3 lanes: the Prayer of Mending
placement with party-wide jump tracking, the Binding Heal pair-heal gated
on both parties hurt, and the Litany of Light cast-variability alternation;
the @60 PoM aura 1240849 pinned in BUFF_OVERRIDES).
#25 `priest/smite_forever.lua` BUILT (2 lanes + 1 replacement: the Penance
nuke inside the Power in Light Holy Fire window and the debuff-driven Holy
Fire upkeep replacing the baseline's cast-on-cooldown lane; both
talent-gated, fail-closed to the baseline).
#26 `*/leveling_forever.lua` fillers IN PROGRESS: paladin BUILT (the Holy
Strike strike lane from the re-added Retribution ladder, woven between
Exorcism and Consecration; the rank-ladder mirror recorded as a close-out
candidate); druid BUILT (the Omen of Clarity clearcast weave waiving the
flat energy floors inside the free-cast window; the form-energy half needs
no lane — Furor is a capped restore and the leveling file has no
powershift lane); warrior BUILT (the Victory Rush kill-window sustain lane
above Execute, rune-learn-gated); hunter BUILT (the shared Aimed/Multi
cooldown reorder — the pair re-emitted Multi-first, no new lanes); warlock
BUILT (the Banes-not-curses pair — Curse of the Elements alongside the
baseline's Bane of Agony, Bane-present precondition + mana floor; the
pet-Move-To half is no rotation-lane impact); rogue BUILT (the Mutilate
2-CP builder above Sinister Strike, both-hand dagger gate + learn gate; the
energy half stays probe-gated); shaman BUILT (the Improved Ghost Wolf
in-combat escape lane; the 8s Stormstrike and early imbues already ride the
baseline); mage BUILT (the Hot Streak spend in the leveling fire branch;
the Frostfire school-swap stays deliberately absent per the kit's
unconfirmed note); priest BUILT (the universal-access pair — Devouring
Plague in the dot block and Fear Ward in the self-buff block). **#26
COMPLETE: all nine leveling classes shipped (paladin, druid, warrior,
hunter, warlock, rogue, shaman, mage, priest).**

## Wave 3 — beta week 2+ (all kits transcribed, fully ranked)

Ranked from the completed kits; priest deltas carry a one-notch risk
downgrade (lowest source tier — demo-derived Zockify page, no Icy Veins
priest overview exists). All rogue deltas are gated on the day-1
constant-regen-energy probe (kit doc), all warlock deltas on the
haste-not-affecting-dots re-check.

| # | Delta | Why here |
|---|---|---|
| 15 | `druid/balance_forever.lua` | Eclipse alternation loop (stacks to 4) — a new stack mechanic on an existing file; Nature's Grace GCD-reduction lane; moonkin/LotP buff accounting. |
| 16 | `druid/resto_forever.lua` | Wild Growth CD lane + non-consuming Swiftmend spot-heal + GotE 1s-GCD blanket priority — additive healer reshaper. |
| 17 | `warlock/demonology_forever.lua` | Demonic Pact sacrifice-and-resummon buff juggling (school-choice lane); pet-handler dependency makes it framework-heavier than its population justifies on day 1. |
| 18 | `warlock/destruction_forever.lua` | Incinerate's Immolate dependency + Shadow and Flame cross-school windows + Bane of Havoc cleave. |
| 19 | `priest/discipline_forever.lua` | Penance dual-mode + Divine Aegis on top of PW:S absorb accounting (Pattern 12 interplay) + Soul Warding loop. Source-tier downgrade. |
| 20 | `rogue/assassination_forever.lua` | Mutilate fast-CP + Venom spendable burst window (CP-scaled duration) + Expose Armor cheap maintenance. Gated on the energy-model probe. |
| 21 | `priest/shadow_forever.lua` | Universal Devouring Plague, extended Mind Flay (range+slow), Contagion spread-on-death chaining. Source-tier downgrade. |
| 22 | `rogue/subtlety_forever.lua` | Hemorrhage→Rupture amplifier loop + Thousand Cuts stack engine + Cutthroat free-Ambush bursts. Energy-probe gated. |
| 23 | `rogue/combat_forever.lua` | Restless Blades couples CD lanes to CP spending (infra change in CD handling); Puncturing Wounds weapon flexibility. Energy-probe gated. |
| 24 | `priest/holy_forever.lua` | PoM placement/jump lane + Binding Heal pair-heal + Litany of Light cast-variability engine. Source-tier downgrade. |
| 25 | `priest/smite_forever.lua` | Power in Light makes the dedicated smite file real: Holy Fire upkeep + Penance/Smite core. Source-tier downgrade. |
| 26 | `*/leveling_forever.lua` fillers | Per class where the kit changes early rotation (druid form-energy model, rogue energy pace, warlock Bane-slot math, paladin Holy Strike from 6). |

## Re-rank triggers

1. Kit transcription completes for a queued class → rank its deltas
   (DONE 2026-09-16 — all 9 kits transcribed; waves re-ranked below).2. Beta DBC lands → bridge name-resolve pass over all wave lists; a kit
   claim that fails downgrades its delta's rank.
3. Rage-formula probe verdict → fury/arms ranks move.
4. Beta patch notes touch a transcribed kit → re-verify affected lanes.
5. A probe verdict lands (P1–P3, see beta_day1_probes.md) → apply the
   decision table below; no research pass needed.

## Probe verdict → re-rank decision table (mechanical)

Each beta-day probe verdict maps to exactly one row here. Apply the move,
renumber within waves, record the verdict in the owning kit doc — one
commit through the full gate. Priest deltas keep their source-tier
downgrade regardless of outcome (that risk is independent of the probes);
the gates below override rank, not tier.

| Probe | Verdict | Priest / warlock / druid / rogue deltas | Waves 1-2 re-check |
|---|---|---|---|
| P2 Furor energy rework | CONFIRMED (shift never nets a gain) | NO CHANGE — #5 cat / #6 bear already rank as destructive; proceed day 1 | none |
| P2 Furor | NOT changed (TBC Furor ships as-is) | #5 cat demotes to wave-2 tail (loses its destructive core; Berserk-cat + critting bleeds remain); #6 bear demotes to wave-3 top | freed wave-2 slot promotes #15 balance (Eclipse) |
| P2 Warrior rage formula | CHANGED (rage-from-damage) | none directly | #7 fury returns ABOVE #5/#6 — rage re-derivation is the bigger blast radius; cat/bear demote one slot each |
| P2 Warrior rage | Unchanged | none | #7 fury demotes to wave-2 tail (CD split + ambient Enrage only) |
| P2 Rogue constant-regen energy | CONFIRMED | #20/#22/#23 promote as a BLOCK to the wave-2 tail, ordered assassination > subtlety > combat (Venom burst, Thousand Cuts engine, Restless Blades CD infra) | combat outranks #13 arms (both CD-lane work); block rides behind the existing wave-2 rows |
| P2 Rogue energy | NOT confirmed (tick-pulse survives) | rogue deltas stay wave 3 but drop BELOW priest rows — without regen, rogue lanes stay Vanilla-shaped; Venom/Thousand Cuts are additive only | none |
| P2 Haste does not affect DoTs | CONFIRMED (build behavior) | #10 affliction and #18 destruction hold rank | none |
| P2 Haste | FLIP: haste DOES scale dots | #10 affliction promotes INTO WAVE 1 (slot 5) — every dot lane re-derives haste-stacked; #18 destruction promotes to wave-2 top | only verdict that EXPANDS wave 1 |
| P3 Demonic Pact persistence | Persists through resummon | #17 demonology promotes to wave-3 top — buff juggling is rotation-core | none |
| P3 Demonic Pact | Buff re-applies on resummon only | #17 demonology drops to last of wave 3 (summon-time buff, not rotation) | none |
| P1 name resolution | Wave-1 ability missing from bridge | affected wave-1 delta → wave-2 tail (dormant, never a guessed ID) | next-ranked promotes into the freed wave-1 slot |
| Any probe | Verdict contradicts its kit doc | fix the kit doc FIRST (verdict + source line), then apply the matching row | — |

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
