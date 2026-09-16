# Heal-Rank Fit — Live-Client Validation Checklist

How to confirm on a real client that each era's deficit-fit rank picks match
the values pinned in `shared/heal_value_sylvanas.lua` (v2.28.0). Every number
below is derived from the module tables plus the two live modifiers the fit
actually applies: the downrank penalty `classic(level) × min(1,(level+11)/player_level)`
from `PreemptiveHeal.downrank_penalty` (player_level 60 on SoD/vanilla lanes,
70 default on TBC) and the `pick_castable` walk (newest rank first, first rank
whose expected heal ≤ deficit × 1.3, biggest castable rank as the designed
overshoot fallback). The pinned suites (`test_sod_healer_rank_fit.lua`)
prove the math in-harness — this doc proves the wiring end-to-end on the
live client.

## Common setup (all eras)

1. **`heal_bonus_healing` = 0** (the default). Any bonus shifts every bound
   below by `+0.857 × bonus` for GH/HW rows and `+0.429 × bonus` for
   FH/LHW/FoL rows, and crits multiply by 1.5. Zero keeps the observed ranges
   exactly the (penalized) base tables.
2. **`healer_rank_fit_enabled` on** (default). The kill switch restores the
   legacy first-ready walk — useful as a differential (see each era).
3. Open both surfaces:
   - The plugin console: each cast prints the concrete spell id, e.g.
     `[SpellQueue] [Dispatcher] Spell Casted (25314) Greater Heal | Target …`,
     with the rank label on the lane's line (`Emergency FH R5`,
     `[SOD HEALING] FlashHeal R7`, `Friendly GH R5`, …).
   - The in-game combat log filtered to your own heals: `Your Greater Heal
     heals <target> for N`. Non-crit N lands inside the row's
     `[base_min, base_max]` when bonus is 0 and the row is unpenalized.
4. **Deficit control:** duel an ungear'd alt (max HP visible in its frame),
   damage it to a chosen %, and treat `deficit ≈ max_hp × (100 − hp%)`.
   Castability = `NS.spell_ready` (known, in range, mana, not on cooldown).
   Ranks above the client's learn level are never cast — on vanilla they are
   dropped at build time (`max_level` 60), on SoD they are skipped live by
   readiness.
5. **Pick zones are ranges, not points:** the walk checks newest rank first,
   so rank R wins where `expected(R)/1.3 ≤ deficit` and every larger rank
   overshoots. Probe mid-zone, not at boundaries.

---

## Vanilla priest (level 60, holy)

Ladders are built era-aliased (`vanilla` → classic dataset) and learn-capped
at 60 by `class_sylvanas.lua:495-503`, so the vanilla GH ladder is **exactly
R5** and the FH ladder is **exactly R7→R1** (R8/R9 dropped at build time).
Penalty at 60: GH R5 (learn 60) and FH R6/R7 (learn 51/56) are unpenalized;
FH R5 and below take `(level+11)/60` (plus the ≤-20 classic factor for
R1–R2). FH expected values at bonus 0: **R7 902, R6 723, R5 525, R4 347,
R3 236, R2 143, R1 13**; GH R5 **2080** (classic 1966–2194).

| Check | Expected observation | Failure signature |
|---|---|---|
| GH ladder contents | Every Greater Heal logs id **25314**, label **R5** — at every deficit (nothing else is learnable) | id 25210/25213 or label R6/R7 ⇒ learn-cap broken |
| GH heal range (non-crit, bonus 0) | **1966–2194** | see "spotting 25314" below |
| FH ladder contents | exactly R7→R1: 10917, 10916, 10915, 9474, 9473, 9472, 2061 | 25235 (R8) or 25233 (R9) cast or labelled ⇒ learn-cap broken |
| FH R7 row | id 10917 heals **828–975** | 833–979 ⇒ the vanilla→sod era alias is not applying |
| FH fit zones | deficit ≈ 300 → **R4** (347 ≤ 390, R5's 525 overshoots); ≈ 500 → **R5** (525 ≤ 650); ≈ 700 → **R7** (902 ≤ 910) | monotonic but offset ⇒ a row's value mismatches the table; always R7 ⇒ fit dead |
| Deep-deficit tail | deficits 10–181 fall to **R2/R1** (expected 143/13; R3 covers 182–267); below ~10 nothing fits and the fallback casts **R7** | no cast at all ⇒ `pick_castable` returned nil and the legacy walk also failed |
| Kill-switch differential | `healer_rank_fit_enabled=false` ⇒ GH always **R5** (same as fit-on — single-rank ladder), FH always **R7**; FH labels R1–R6 disappear | FH rank picks unchanged ⇒ setting not consulted |

### Spotting the GH 25314 correction in combat logs

The correction swapped the TBC row (2006–2235) for the classic row
(1966–2194) on vanilla. The ranges overlap (2006–2194), so a single cast can
be ambiguous — discriminate by the **extremes over a batch**:

1. Set `heal_bonus_healing = 0`, rank fit on.
2. Drop the alt to ~40% and cast Greater Heal ≥ 20 times (re-damaging as
   needed). Ignore crits (1.5×) and partial-resist messages.
3. Read the batch minimum and maximum:
   - min trends to **1966** and max never exceeds **2194** ⇒ corrected row is
     live ✔
   - any cast **> 2194**, or a min trending to **2006** ⇒ stale TBC values ⇒
     the era alias did not take on this client (report it; the vanilla
     wiring at `class_sylvanas.lua:495-503` is not live)
4. Fast per-cast triage zones: a roll of **1966–2005** is only possible with
   the corrected row; **2195–2235** only with the stale row.
5. Cross-era guard: a **TBC** priest casting the same id 25314 must heal
   **2006–2235** (TBC rows stay authoritative). Seeing 1966–2194 on TBC means
   the sod override leaked into era-less ladders.

---

## SoD priest (level 60, healing spec)

FH is built with `era = "sod"` and no `max_level` (`healing_sod.lua:29`), so
the ladder array carries R1–R9 — but R9 (learn 67) and R8 (learn 61) are
unlearnable at 60 and are skipped live by readiness; the effective live
ceiling is **R7**, whose row is the corrected 10917. Lanes thread
`player_level = 60` (`healing_sod.lua:80`), so the penalty matches vanilla's:
FH expected values at bonus 0: **R7 902, R6 723, R5 525, R4 347, R3 236,
R2 143, R1 13** (R8 1005 / R9 1206 exist only in the harness, where
`is_ready` is stubbed true).

| Check | Expected observation | Failure signature |
|---|---|---|
| FH R7 row | id 10917 heals **828–975** | 833–979 ⇒ era override missing (twin tell: the fit's stored row is 902 stale vs 906 — visible only in-harness; the live range check is the reliable one) |
| R9/R8 never cast | no `Spell Casted (25235)` / `(25233)` lines from the SoD lane | either id cast ⇒ readiness is not consulting learn level |
| FH fit zones (live ceiling R7) | deficit ≈ 250 → **R3** (236 ≤ 325); ≈ 500 → **R5** (525 ≤ 650); ≈ 800 → **R7** (902 ≤ 1040); ≥ ~694 stays R7 | monotonic but offset ⇒ row value mismatch; always R7 on small deficits ⇒ fit dead |
| Emergency lane | `Emergency FH` labels with the same R-labels (same ladder, speed-prioritized gate) | emergency always R7 ⇒ lane bypasses the hook |
| Kill-switch differential | fit off ⇒ always **R7** (the legacy walk's R9/R8 entries are unlearnable and skip) | unchanged ⇒ knob dead |

SoD shaman and druid anchors (same mechanics, unpenalized at learn ≤ 60):
Healing Wave 25357 heals **1620–1850** (stale TBC row: 1647–1878); Healing
Touch 25297 heals **2267–2677** (stale: 2303–2714). Batch min/max as above.

---

## TBC priest / paladin / druid (level 70)

TBC ladders are built era-less and unlimited — byte-identical to their
pre-fit shape. Every priest GH row's learn level (60/63/68) makes
`(level+11)/70 ≥ 1`, so no downrank penalty applies on TBC GH; ranges are
the raw tables.

| Check | Expected observation | Failure signature |
|---|---|---|
| Priest GH ladder contents | ids 25213 (R7), 25210 (R6), 25314 (R5) all appear as deficits grow | vanilla values (1966–2194) on TBC ⇒ override leak |
| Priest GH fit zones | deficit ≈ 1600 → **R7** (nothing fits: R5's 2121 > 2080 — the designed overshoot fallback); ≈ 1700 → **R5** (2121 ≤ 2210, R6's 2276 > 2210 — a genuine mid-rank pick); ≈ 1800–2000 → **R6** (2276); ≥ ~2010 → **R7** (2609) | always R7 ⇒ fit dead; R6 never appearing ⇒ mid-rank zone broken |
| Paladin Holy Light top ranks | R11 (27136) 2196–2446, R10 (27135) 1773–1971, R9 (25292) 1619–1799; big-deficit picks stay in these three (R11 from deficit ≈ 2000) | mid-rank picks at huge deficits ⇒ ceiling/mana-tier interaction changed |
| Druid Healing Touch tail | R13 (26979) 2715–3206 (the Wowhead-corrected tail), R11 (25297) 2303–2714 TBC row | classic values (2267–2677) on TBC ⇒ override leak |
| Kill-switch differential | fit off ⇒ every heal is the ladder head (GH R7 / HL R11) | unchanged ⇒ knob dead |

Lower-rank TBC picks (penalized rows, learn < 59) are covered by the
in-harness suites; live-verifying them requires knowing your exact bonus
healing, which is why this checklist pins the unpenalized rows.

---

## WotLK status (go/no-go check, 2026-09-16): NO-GO — the +11 divisor is TBC-only → landed as PR #54

The pinned downrank formula (`PreemptiveHeal.downrank_penalty`, cited to
LibHealComm-4.0) is **not valid on WotLK**, by the cited library's own code:
LHC-4.0's `calculateGeneralAmount` gates per era — `elseif isTBC then penalty
= penalty * min(1, (level + 11) / playerLevel)` is the **TBC branch only**;
on WotLK (`isWrath`) it **replaces** the penalty (sub-20 factor included)
with `min(1, max(0, (22 + (level+5) − playerLevel) / 20))` (its cited
wowwiki Downranking page; Ghostcrawler's statement puts the spell's "max cast
level" around learn + 4, so the +4/+5 offset carries a ±1 ambiguity).
Concrete divergence, priest GH 25314 (learn 60) at player level 80: the TBC
formula gives min(1, 71/80) = 0.888; the WotLK formula gives (22 + 65 − 80)/20
= 0.35. A WotLK row is therefore **mandatory, not optional** — a replacement
branch, not a multiplier — and needs one live calibration cast to pin the
+4/+5 offset. Separately, patch 3.0.2 made WotLK spell costs a percentage of
base mana (rank-invariant or decreasing with rank), so downranking saves
~no mana there — the fit's efficiency benefit is structurally absent and only
overheal avoidance survives. Any future WotLK priest PR must first: (1) add
the wotlk branch to `downrank_penalty`, (2) live-calibrate the offset with
the batch-extremes method above, (3) re-run the scoping verdict with the
added cost.

Side finding from the same check (2026-09-16), flagged for its own verified
pass rather than silently changed: the module's `expected_heal` applies the
penalty to `(base + bonus·coeff)`, but both authorities it cites apply it to
**bonus healing only** — LHC-4.0 multiplies `spellPower` before the
`amount + spellPower·spModifier` sum, the wowwiki TBC section says the
multiplier is "multiplied with your spell coefficient and your bonus
healing/damage", and TrinityCore 3.3.5's WotLK implementation
(`CalculateSpellpowerCoefficientLevelPenalty`) scales the coefficient factor,
never the base. With the default `heal_bonus_healing = 0` the two semantics
still differ (penalized vs unpenalized base), so the shipped expected values
and pick zones are conservative (they under-state downranked rows, biasing
picks toward smaller ranks). Any correction would move pinned values across
all eras and needs its own wave with the same pin discipline.

### Harvest record (PR #54, 2026-09-16): the WotLK FH/GH rows

The go/no-go pre-conditions above are now implemented on PR #54
(feat/wotlk-priest-fit-2026-09-16): (1) the wrath branch is in
`downrank_penalty` (player_level > 70), classic/TBC paths byte-unchanged;
(2) the +4/+5 offset live calibration is **scoped down** — it only matters
when `heal_bonus_healing` > 0, because the wrath factor scales the
bonus-healing term only (see the side finding below; at the default bonus 0
every WotLK expected value is the raw base average and the fit is
offset-insensitive); (3) the scoping verdict (priest-only first) was
shipped. Status: the NO-GO gate is resolved; the checklist rows below are
live in the module and pinned by the rank-fit suite.

**Provenance.** Every row verified 2026-09-16 against the wotlk-client
tooltips (nether.wowhead.com/wotlk/tooltip/spell/<id>: heal range +
Requires level + DBC SpellLevel); the two heads exact-match
wowsims/wotlk@563e4a08 (sim/priest/flash_heal.go `Roll(1896,2203)`,
greater_heal.go `Roll(3980,4621)` — the 1.88 wrath healing multiplier on
the 1.5/3.5 ratios gives coeff 0.8057 / 1.6114). Learn levels: the WotLK
bridge (wowhead_data_bridge_spell_index_wotlk) where present, the tooltip
Requires-level otherwise (the two heads); the sources agree wherever both
exist. WotLK costs are %-of-base-mana at every rank (18% FH / 32% GH), so
`cost` stays nil and HPM is correctly no-signal — downranking saves no
mana; the fit is pure overheal avoidance. DBC SpellLevel is 80 for every
rank, so no rank is coefficient-penalized at any caster ≤ 82.

**Two era divergences found** (kept era-distinct in the `Wotlk*` families;
`find_rank_by_id` resolves era-suffixed families after the canonical
TBC/classic ones, so shared ids keep the TBC-table answer):

- FH 25235 (R9): wotlk 1121–1300 vs TBC 1116–1295.
- GH 25213 (R7): wotlk 2433–2822 vs TBC 2414–2803.

**Flash Heal (coeff 0.8057, 1.5s)** — expected @80, bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R10 | 48071 | 79 | 1896–2203 | 2049.5 |
| R9 | 25235 † | 67 | 1121–1300 | 1210.5 |
| R8 | 25233 | 61 | 931–1078 | 1004.5 |
| R7 | 10917 | 56 | 833–979 | 906 |
| R6 | 10916 | 50 | 662–783 | 722.5 |
| R5 | 10915 | 44 | 534–633 | 583.5 |
| R4 | 9474 | 38 | 414–492 | 453 |
| R3 | 9473 | 32 | 339–406 | 372.5 |
| R2 | 9472 | 26 | 269–325 | 297 |
| R1 | 2061 | 20 | 202–247 | 224.5 |

**Greater Heal (coeff 1.6114, 3.0s)** — expected @80, bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R8 | 48063 | 78 | 3980–4621 | 4300.5 |
| R7 | 25213 † | 68 | 2433–2822 | 2627.5 |
| R6 | 25210 | 63 | 2107–2444 | 2275.5 |
| R5 | 25314 | 60 | 2006–2235 | 2120.5 |
| R4 | 10965 | 58 | 1835–2044 | 1939.5 |
| R3 | 10964 | 52 | 1470–1642 | 1556 |
| R2 | 10963 | 46 | 1178–1318 | 1248 |
| R1 | 2060 | 40 | 924–1039 | 981.5 |

† era-divergent row (wotlk values shown; the TBC table keeps its own).

The four classic GH ranks (2060/10963/10964/10965) are members again — the
TBC ladder had replaced them with the 61+ ranks only; a WotLK client learns
both bands.

**Pick zones at 80, bonus 0** (same rule as every era: newest-first walk,
first rank with expected ≤ deficit × 1.3; when nothing fits, the head is
the correct overshoot): FH — 440→R4, 600→R6, 900→R8, 1500→R9, deficit
≥ 1577→R10, below ~173→overshoot R10. GH — 900→R1, 1000→R2, 1700→R5,
2000→R6, 2350→R7, deficit ≥ 3309→R8, below ~755→overshoot R8. With
`heal_bonus_healing` > 0 the zones shift (the wrath factor scales each
row's bonus term by (22 + learn + 5 − 80)/20 clamped to [0,1] — low-learn
rows gain little bonus), which is the case the live calibration cast
settles.

### Harvest record (WotLK paladin, 2026-09-16): the WotLK HL/FoL rows

Same wave, same method (nether.wowhead.com/wotlk/tooltip/spell/\<id\>:
heal range + Requires level, all 20 rows read). WotLK retuned every shared
row upward, so the families are era-distinct like the priest pair; the TBC
table keeps its own values and `find_rank_by_id` keeps the TBC answer for
shared ids.

**Provenance notes.** 48783 resolves to Trample (unrelated), so 48782 is
the true HL max. HL R5 1042 exists in the WotLK client (Holy Light, req
30) but is absent from the spec ACTION ladder — it is included in the
family so the fit ladder is complete (R1–R12). Learn levels: the WotLK
bridge where present (19750→20, 27136→70, 27137→66 — all agree with the
tooltips), the tooltip Requires-level otherwise. WotLK costs are
%-of-base-mana at every rank (HL 29% / FoL 7%), so `cost` stays nil.
Coefficients: paladin heals have no dedicated sim file at
wowsims/wotlk@563e4a08 (the sim/paladin listing carries no
holy_light/flash_of_light — heals resolve through generic APL handling),
so no sim exact-match is claimed; the coeff reuses the priest-proven 1.88
wrath multiplier on the TBC ratios (0.714 → 1.3423, 0.429 → 0.8065). At
the default bonus 0 the fit runs on raw base averages and is
coeff-insensitive.

**Holy Light (coeff 1.3423, 2.5s, ×1.12 Healing Light)** — expected @80,
bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R12 | 48782 | 80 | 4888–5444 | 5786 |
| R11 | 27136 | 70 | 2846–3166 | 3367 |
| R10 | 27135 | 62 | 2264–2518 | 2678 |
| R9 | 25292 | 60 | 2063–2295 | 2440 |
| R8 | 10329 | 54 | 1621–1803 | 1917 |
| R7 | 10328 | 46 | 1232–1372 | 1458 |
| R6 | 3472 | 38 | 913–1017 | 1081 |
| R5 | 1042 | 30 | 643–724 | 766 |
| R4 | 1026 | 22 | 409–467 | 491 |
| R3 | 647 | 14 | 211–248 | 257 |
| R2 | 639 | 6 | 101–122 | 125 |
| R1 | 635 | 1 | 53–64 | 66 |

**Flash of Light (coeff 0.8065, 1.5s, ×1.12)** — expected @80, bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R8 | 48785 | 79 | 788–883 | 936 |
| R7 | 27137 | 66 | 600–670 | 711 |
| R6 | 19943 | 58 | 458–512 | 543 |
| R5 | 19942 | 50 | 357–401 | 424 |
| R4 | 19941 | 42 | 265–298 | 315 |
| R3 | 19940 | 34 | 197–219 | 233 |
| R2 | 19939 | 26 | 130–151 | 157 |
| R1 | 19750 | 20 | 86–98 | 103 |

**Pick zones at 80, bonus 0:** HL — 4500→R12, 3000→R11, 2000→R9,
1500→R8, 1000→R6, 500→R4, 300→R3, 150→R2, 60→R1; below ~51→overshoot
R12. FoL — 800→R8, 700→R7, 400→R5, 200→R3, 100→R1; below ~80→overshoot
R8.

### Harvest record (WotLK druid, 2026-09-16): the WotLK HT rows

Same wave, same method (nether.wowhead.com/wotlk/tooltip/spell/\<id\>:
heal range + Requires level, all 14 rows read). WotLK retuned every shared
row except R1–R4 (which agree exactly: R4 376–459, R3 204–253, R2 94–119,
R1 40–55) and adds one head (R14 48378, req 79). Learn levels: the WotLK
bridge where present (5185/9889/25297/26978/26979 — all agree with the
tooltips), the tooltip Requires-level otherwise. Costs are %-of-base-mana
(33% down to 17% by rank), so `cost` stays nil. Coefficient: no dedicated
druid heal file at wowsims/wotlk@563e4a08 either (sim/druid carries no
healing_touch; restoration/ holds only the spec scaffold), so the coeff
reuses the same derived 1.88 wrath multiplier (1.0 → 1.88); bonus-0
coeff-insensitive as throughout.

**Healing Touch (coeff 1.88, 3.0s)** — expected @80, bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R14 | 48378 | 79 | 3761–4440 | 4100.5 |
| R13 | 26979 | 69 | 2349–2767 | 2558 |
| R12 | 26978 | 62 | 2057–2424 | 2240.5 |
| R11 | 25297 | 60 | 1975–2325 | 2150 |
| R10 | 9889 | 56 | 1648–1941 | 1794.5 |
| R9 | 9888 | 50 | 1324–1565 | 1444.5 |
| R8 | 9758 | 44 | 1221–1450 | 1335.5 |
| R7 | 8903 | 38 | 821–980 | 900.5 |
| R6 | 6778 | 32 | 653–783 | 718 |
| R5 | 5189 | 26 | 505–609 | 557 |
| R4 | 5188 | 20 | 376–459 | 417.5 |
| R3 | 5187 | 14 | 204–253 | 228.5 |
| R2 | 5186 | 8 | 94–119 | 106.5 |
| R1 | 5185 | 1 | 40–55 | 47.5 |

**Pick zones at 80, bonus 0:** 3500→R14, 2000→R13, 1700→R11,
1300→R9, 1000→R7, 600→R6, 400→R4, 150→R2, 40→R1; below ~37→overshoot
R14.

**Lane note.** The WotLK spec previously had no non-emergency direct HT
lane to fit (Nourish is single-rank, Regrowth is refresh-gated, NS+HT is
the instant emergency — all excluded by the wave contract), so this wave
adds `FallbackHealingTouch` mirroring the TBC gate (lowest ≤ 80, mana ≥
25, standing still, HT ready, no predicted overheal) in fallback position
after Nourish. The fit is built into the new lane; fail-closed to the
legacy 48378 max-rank cast.

### Harvest record (WotLK shaman, 2026-09-16): the WotLK HW/LHW rows

Final spec of the wave; same method (nether.wowhead.com/wotlk/tooltip/
spell/\<id\>: heal range + Requires level, all 23 rows read). WotLK adds
two ranks per ladder and retunes two shared rows; every other shared row
agrees exactly.

**Rank-number provenance.** 49273 = HW Rank 14 (req 80) and 49272 = HW
Rank 13 (req 75); 49276 = LHW Rank 9 (req 77) and 49275 = LHW Rank 8 (req
72) — confirmed 2026-09-16 via the wowclassicdb / wowhead indexed pages
(49273 "Healing Wave Rank 14", 49276 "Lesser Healing Wave Rank 9").
Learn levels: the WotLK bridge where present (all 12 HW + 7 LHW
classic/TBC ids agree with the tooltips), the tooltip Requires-level
otherwise (the four new heads). Costs are %-of-base-mana, so `cost` stays
nil. Coefficients: no dedicated shaman heal file at
wowsims/wotlk@563e4a08, so the coeff reuses the priest-proven 1.88 wrath
multiplier on the TBC ratios (3.0/3.5 → 1.6114, 1.5/3.5 → 0.8057);
bonus-0 coeff-insensitive as throughout.

**Healing Wave (coeff 1.6114, 3.0s)** — expected @80, bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R14 | 49273 | 80 | 3034–3466 | 3250 |
| R13 | 49272 | 75 | 2656–3028 | 2842 |
| R12 | 25396 † | 70 | 2162–2465 | 2314 |
| R11 | 25391 | 63 | 1756–2001 | 1879 |
| R10 | 25357 | 60 | 1647–1878 | 1763 |
| R9 | 10396 | 56 | 1394–1589 | 1492 |
| R8 | 10395 | 48 | 1040–1191 | 1116 |
| R7 | 8005 | 40 | 759–874 | 817 |
| R6 | 959 | 32 | 552–639 | 596 |
| R5 | 939 | 24 | 389–454 | 422 |
| R4 | 913 | 18 | 279–328 | 304 |
| R3 | 547 | 12 | 136–163 | 150 |
| R2 | 332 | 6 | 69–83 | 76 |
| R1 | 331 | 1 | 36–47 | 42 |

**Lesser Healing Wave (coeff 0.8057, 1.5s)** — expected @80, bonus 0:

| Rank | Id | Learn | Base range | Expected |
|---|---|---|---|---|
| R9 | 49276 | 77 | 1624–1852 | 1738 |
| R8 | 49275 | 72 | 1402–1598 | 1500 |
| R7 | 25420 † | 66 | 1055–1202 | 1129 |
| R6 | 10468 | 60 | 853–949 | 901 |
| R5 | 10467 | 52 | 649–723 | 686 |
| R4 | 10466 | 44 | 473–529 | 501 |
| R3 | 8010 | 36 | 349–394 | 372 |
| R2 | 8008 | 28 | 257–292 | 275 |
| R1 | 8004 | 20 | 170–195 | 183 |

† era-divergent row (wotlk values shown; the TBC table keeps its own).

**Pick zones at 80, bonus 0:** HW — 3000→R14, 2200→R13, 2000→R12,
1500→R11, 1200→R9, 800→R7, 350→R5, 120→R3, below ~32→overshoot R14.
LHW — 1500→R9, 1200→R8, 700→R6, 400→R4, 200→R1, below ~141→overshoot R9.

**Lane note.** Three lanes draw the fit: `HealingWave` (49273 fallback),
`TidalWavesHealingWave` (casts the same HW ladder; the TW mechanic changes
cast speed, not rank identity — 49273 fallback), and `LesserHealingWave`
(49276 fallback). The NS+HealingWave lane stays max-rank (instant-cast
emergency identity), Chain Heal stays a group-aggregate lane, and Riptide
stays refresh-gated — all per the wave contract.

---

## Reporting a failure

Note the era, player level, both settings' values, the observed id/label and
heal amounts (batch min/max over ≥ 20 casts), and compare against the module
rows cited above. Value mismatches that reproduce across batches indicate the
era override or learn-cap wiring is not live on that client build — check
that the installed zip matches the release tag
(`release_zip_audit.py --release=X.Y.Z`) before filing.
