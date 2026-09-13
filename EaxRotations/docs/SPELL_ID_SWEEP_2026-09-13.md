# Spell-id sweep - 2026-09-13

Every spell id pinned anywhere in `EaxRotations` (spec `define` ladders, `ids = {...}`
ladders, shared id tables) was re-derived against the local authoritative sources and
the wowsims fixtures, then the suspicious set was verified on Wowhead.

**Tool:** `EaxRotations/tools/spell_id_sweep.py` (read-only, re-runnable, ~0.7 s).
`python EaxRotations/tools/spell_id_sweep.py --json ... --md ...`, `--file P` for one
file, `--strict` to exit 1 on a HARD finding. Non-vacuity: injecting a dead id, a
lower-rank head and a cross-era id into synthetic ladders makes it fire (2 hard,
4 review, exit 1).

**Coverage:** 1879 ladders / 7347 id pins / 1965 unique ids.

**Sources of truth (all local):**

| Source | What it proves |
|---|---|
| `shared/_dbc_spell_ids.lua` (28650 ids) | the id exists in the TBC client DBC - exhaustive for TBC/vanilla |
| `shared/wowhead_data_bridge_spell_index_tbc_sylvanas.lua` (28613, == the vanilla bridge) | name / class / learn level / cooldown per id |
| `shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua` (1045) | the curated WotLK player-spell subset |
| `tools/evidence/apl/*.apl.json` (27 fixtures, 214 ids) | the ids the pinned wowsims APLs actually cast |
| `tests/run_wotlk_audit_tests.lua` pin tables | WOTLK_REFERENCE_ALIASES / SHARED_IDS / REJECTED_IDS (360 ids) |
| `tests/run_vanilla_audit_tests.lua` TBC_IDS (196) | the repo's curated late-vanilla boundary ids |

## Definitional results: zero

* **DEAD (id no source knows): 0.**
* **ERA-TBC-IN-VANILLA (post-60 id in a vanilla file): 0** - exhaustive by learn level,
  not the curated 196-id list the vanilla audit uses.
* **ERA-WOTLK-IN-TBC (WotLK-only id in a TBC class file): 0.**
* **REJECTED-ID-IN-USE (a WOTLK_REJECTED_IDS pin still in a ladder): 0.**

So the 48927 shape (a fabricated id) and cross-era leaks are *currently* absent. Note
they were never catchable offline before: the WotLK audit accepts a bridge-gap id once
it is pinned, which is why 48927 shipped - the pin was self-certifying.

## Verified wrong-family ids in live lanes

Each row was confirmed against Wowhead in the era named; the id is the first id a real
player knows, so `NS.get_spell_id` resolves to the **wrong spell** and casts it.

**All rows below are now FIXED (2026-09-13).** The ladders were rebuilt from the local
TBC bridge + Wowhead, the mislabelled audit pins were corrected, and the whole gate
re-ran green (battery never-fires unchanged: TBC 11 / vanilla 9 / SoD 0 / WotLK 0;
563/563 suites; WotLK runner 82/82; all audits 0 invalid; `verify_all` exit 0). The
original findings are kept verbatim as the evidence trail.

| Site | Pinned as | Actually | Evidence | Effect |
|---|---|---|---|---|
| `mage/class_sylvanas.lua:252` IceBlock | 11958 | Cold Snap (8 min CD) | Wowhead TBC 11958 = Cold Snap; 27619 = Ice Block | a mage who has Cold Snap never reaches Ice Block - the defensive lane casts Cold Snap instead (the file comment asserting "11958 = Ice Block ... 12472 = Cold Snap" is inverted) |
| `druid/tank_sod.lua:28` SodDemoralizingRoar | 16857 (head) | Faerie Fire (Feral) | bridge + Wowhead TBC 16857 | bear casts FF, never the -AP Demoralizing Roar |
| `hunter/dps_hunter_sod.lua:29` SodAspectHawk | 13159 (head) | Aspect of the Pack | Wowhead TBC 13159 | SoD hunter runs Pack (30% speed, daze) instead of Hawk |
| `hunter/dps_hunter_sod.lua:27` SodHuntersMark | 30706 (head) | Totem of Wrath (Shaman) | bridge + Wowhead TBC 30706 | head is never known, so it silently falls through to 14323 |
| `hunter/dps_hunter_sod.lua:29` SodVolley | 27019 (head) | Arcane Shot r9 | bridge + Wowhead TBC 27019 | Volley lane casts Arcane Shot |
| `hunter/class_sylvanas.lua:328` + `hunter/survival_sylvanas.lua` ImmolationTrap | 29906 (head) | Ravage (pet ability) | Wowhead TBC 29906 = Ravage; 27023 = Immolation Trap | TBC trap lane headed by a spell hunters do not know |
| `priest/leveling_wotlk.lua:26` PowerWordShield | 548 | Lightning Bolt r3 | Wowhead TBC 548 | wrong-family tail in the PW:S ladder |
| `priest/shadow_wotlk.lua:56` ShadowWordDeath | 2944 | Devouring Plague | Wowhead TBC 2944 | wrong-family tail; the same id is correctly Devouring Plague in the sibling ladder |
| `deathknight/frost_wotlk.lua:40` FrostStrike | 51414 / 51420 / 51421 | Venomous Breath Aura / Digging for Treasure Ping / Fire Cannon | Wowhead WotLK 51414 | wrong-family tails (head 55268 is correct) |
| `paladin/protection_wotlk.lua:42` + `leveling_wotlk.lua:53` HolyWrath pins | 37897 | Parachute | Wowhead WotLK 37897 | a pin-table entry, not the ladder head (48817 is correct) |

## Fixes applied (2026-09-13)

| Site | Was | Now | Verified how |
|---|---|---|---|
| `mage/class_sylvanas.lua` IceBlock | `{11958, 27619}` | `{45438, 27619}` | bridge + wowhead.com/tbc/spell=45438 (Hypothermia) and /classic/spell=27619 |
| `druid/tank_sod.lua` SodDemoralizingRoar | `{16857, 9898}` | `{9898, 9747, 9490, 1735, 99}` | bridge (full Demoralizing Roar ladder) |
| `hunter/dps_hunter_sod.lua` SodAspectHawk | `{13159, 13158, 8352}` | `{14322, 14321, 14320, 14319, 14318, 13165}` | bridge (full Aspect of the Hawk ladder) |
| `hunter/dps_hunter_sod.lua` SodVolley | `{27019, 1510}` | `{14295, 14294, 1510}` | bridge (full Volley ladder) |
| `hunter/dps_hunter_sod.lua` SodHuntersMark | `{30706, 14323, 14324, 14325}` | `{14325, 14324, 14323, 1130}` | bridge (full Hunter's Mark ladder) |
| `hunter/class_sylvanas.lua` + `survival_sylvanas.lua` ImmolationTrap | `{29906, 27023, 14299, 14298, 13795}` | `{27023, 14305, 14304, 14303, 14302, 13795}` | bridge (trap *cast* ranks only; 14299/14298 are the DoT effect) |
| `priest/leveling_wotlk.lua` PowerWordShield | tail `548` | removed | bridge: 548 is Lightning Bolt |
| `priest/shadow_wotlk.lua` ShadowWordDeath | tail `2944` | removed | bridge: 2944 is Devouring Plague (still pinned, relabelled) |
| `deathknight/frost_wotlk.lua` FrostStrike | `{55268, 49143, 51414..51421}` | `{55268, 51419, 51418, 51417, 51416, 49143}` | WotLK bridge (51414/51415/51420/51421 are not Frost Strike) |
| `paladin/protection_wotlk.lua` + `leveling_wotlk.lua` HolyWrath | `{48817, 37897, 31898}` | `{48817, 27139, 10318, 2812}` | wowhead 37897=Parachute, 31898=Judgement of Blood, 48817=Holy Wrath, bridge Holy Wrath ranks |
| `shaman/{elemental,enhancement,warden}_sod.lua` LightningBolt | `930` (Chain Lightning r1) | `915` (Lightning Bolt r6) | bridge |
| `tests/run_wotlk_audit_tests.lua` pins | 37897/31898 as "Holy Wrath", 2944 as "SW:Death" | real Holy Wrath ranks pinned; 2944 relabelled Devouring Plague | measured pin count 256 -> 257 |

Also cleaned: test-side stubs that repeated the wrong ids (`test_frost_deathknight_wotlk_strategies`,
`test_deathknight_wotlk_live_fixes`, `test_hunter_live_fixes`) and the SoD buff mock in
`test_sod_druid_hunter`; the vanilla IceBlock assertion in `test_mage_vanilla_live_fixes`
pinned the bug and was corrected.

## The systematic pattern

The SoD files (and a few 2026-09-09/12 guide-pass additions) were pinned with the rule
"an id that exists in the TBC bridge is safe". Presence is not identity: several SoD
ladders are headed by another class's spell or by the wrong rank of the same school, and
because SoD headers are added without Wowhead name checks, nothing caught it. Measured:

* `REDIRECTED` (bridge name disagrees with the pinned label): **123 review** (was 134
  before the 2026-09-13 fixes) - 32 of them are ladder *heads* (the id the resolver
  actually picks).
* `DUPLICATE-CONFLICT` (one id pinned under two different names): **41 review**. The
  cross-family ones this pass fixed: 548 as both LightningBolt and PowerWordShield,
  930 as both ChainLightning and LightningBolt (all three SoD Lightning Bolt ladders
  now carry 915), 27019 as both ArcaneShot and SodVolley, 30706 as both Totem of Wrath
  (`shaman/class_sylvanas.lua:391`) and SodHuntersMark, 16857 as both FaerieFireFeral and
  SodDemoralizingRoar, 11958 as both ColdSnap and IceBlock. Remaining duplicate rows are
  same-id/different-label aliases (e.g. 930 ChainLightning, 16857 FaerieFireFeral) or the
  10060 PowerInfusion row, whose "bloodlustheroism" name is a sweep naming artifact - every
  10060 site in the tree is Power Infusion.
* `RANK-ORDER` (a higher rank listed after a lower one): **45 review** - adjudicated
  2026-09-13, and every standing row is benign. 42 are order-INSENSITIVE rank lists
  (`shared/talent_inference_sylvanas.lua` `TALENT_SIGNATURES`, `shared/dispel_manager_sylvanas.lua`
  pet-rank tables): they answer "does the unit know any of these" and never resolve to
  a cast, so order carries no meaning. The other 3 are the deliberate vanilla Lightning
  Bolt downrank lane in `shaman/elemental_vanilla.lua` (`{10392, 10391, 15207}`), which
  prefers a *lower* rank on purpose. The class-file rows this bucket used to carry
  (BattleShout 2048, TrueshotAura 20906, Envenom, Volley) were real head-order defects
  and are fixed; a NEW row now means a real cast ladder is mis-ordered.
* `WRONG-RANK` (a higher rank exists outside the ladder): **103 review** (was 124; 21
  cleared by the 2026-09-13 head fixes below) - kept as a
  lead, not a finding: the classic bridge names a spell's cast and effect twins
  alike (Bestial Wrath 19574 vs its pet aura 38371, Freezing Trap 14311 vs 31933,
  Rapid Fire 3045 vs 36828), so most rows are cast/effect collisions. The genuinely
  actionable ones are the ids the vanilla audit has *not* already classified as
  TBC-era (e.g. 27024) plus any id whose ladder head sits below the era max.
* `PIN-FAMILY-MISMATCH` (audit pin family vs bridge name): **5 review**, all one defect:
  `run_wotlk_audit_tests.lua` labels 2944 "Shadow Word: Death" while the client calls it
  Devouring Plague, which is what let the stray 2944 tail into `ShadowWordDeath`.
* `UNSOURCED` (no local source knows the id): **85 review** - SoD rune ids (417157
  Starsurge, 414684 Sunfire, ...) and WotLK death-knight ids. Not defects: the local
  bridges cover neither the SoD client nor most of WotLK DK. They are the coverage gap
  that makes a *dead* verdict impossible for those two families.

## RANK-ORDER + WRONG-RANK adjudication (2026-09-13)

The sweep's remaining RANK-ORDER and WRONG-RANK leads were worked separately, because
they are different kinds of claim: RANK-ORDER is about *ladder order* (the resolver takes
the first id the player knows, so a lower rank ahead of a higher one silently down-ranks
every cast) while WRONG-RANK is about *ladder completeness* (a higher rank of the same
spell exists outside the ladder).

**RANK-ORDER: no genuine defect remains.** All 45 rows are order-insensitive lookup
tables or one deliberate downrank lane - see the bucket bullet above. Nothing was changed
for them, and the bucket stays pinned at 45.

**WRONG-RANK: 11 ladder heads across 19 files were genuine cast-rank gaps and are fixed.**
The discriminator was the bridge name *plus* a Wowhead tooltip check - cost, cooldown,
GCD and "Requires <class>" - because the classic bridge names a spell's cast spell, its
applied effect and its NPC version alike, and all three share a level. A real higher rank
of a cooldown spell carries the same cooldown and a real cost; a twin carries `nil`
cooldown, no cost, no GCD, or an NPC-only (`Uncategorized Spells`) category.

| File(s) | Ladder | Was head | Now head | Head level (bridge) |
|---|---|---|---|---|
| `mage/{class,arcane,fire}_sylvanas.lua` | Fireball | 27070 | **38692** | 66 -> 70 |
| `mage/{class,arcane,frost}_sylvanas.lua` | Frostbolt | 27072 | **38697** | 69 -> 70 |
| `paladin/{class,holy}_sylvanas.lua` | BlessingOfLight | 27144 | **32770** | 69 -> 70 |
| `warlock/{class,demonology,destruction}_sylvanas.lua` | DeathCoil | 27223 | **30500** | 68 -> 70 |
| `priest/class_sylvanas.lua` | Resurrection | 20770 | **25435** | 58 -> 68 |
| `hunter/class_sylvanas.lua`, `hunter/survival_sylvanas.lua` | MongooseBite | 14271 | **36916** | 58 -> 70 |
| `hunter/marksmanship_sylvanas.lua` | TrueshotAura | 20906 | **27066** | 60 -> 70 |
| `warrior/class_sylvanas.lua` | MockingBlow | 20560 | **25266** | 56 -> 65 |
| `rogue/{class,combat,subtlety}_sylvanas.lua` | Gouge | 11286 / 1776 | **38764** | 60 -> 67 |
| `shaman/{class,restoration}_sylvanas.lua` | PoisonCleansingTotem | 8166 | **38306** | 22 -> 70 |

**Rejected as twins (no change made):** 17144 Wrath (5yd instant, no cost), 31933
Freezing Trap (no cooldown, weaker 5s freeze), 38371 Bestial Wrath (the pet aura, range
"Anywhere - Unlimited"), 24394 Intimidation (pet threat), 36828 Rapid Fire, 29390 Shield
Wall, 29564 Greater Heal, 29961 Counterspell, 29717 Cone of Cold, 36984 Serpent Sting,
29883 Blink, 29563 Holy Fire and 36831 Curse of the Elements (all `NPC Abilities`),
39666 Cloak of Shadows (the applied buff), 41390 Ambush (flat 4500 damage),
37276 Mind Flay (60 mana / 2000 dps), 27167 Seal of Wisdom (Cost None, no GCD: the proc),
40135 Shackle Undead (Cost None, no GCD), 30412 Drain Life (30s channel at 20yd; the
player spell is 5s at 30yd).

**Pinned structure:** the 19 fixed ladders and the rejected twins are both pinned, so
neither can drift back. `tests/test_spell_id_table_regressions.lua` asserts the exact id
list of every fixed ladder, and the baseline freeze makes the cleared WRONG-RANK rows
re-appear as drift if a head is ever demoted again. Each pin was proven load-bearing by
demoting the head in place (throwaway, restored byte-identical).

## Gate: the sweep is a `verify_all` component (2026-09-13)

The sweep is no longer a report someone has to remember to run. `verify_all` -- the
matrix CI runs -- now runs it through `tests/run_spell_id_sweep_check.lua`, which spawns
`tools/spell_id_sweep.py --check` and compares the live result to the committed,
classified-once baseline `tools/spell_id_sweep_baseline.json` (LF-pinned).

Buckets are classified once, in the sweep's `CHECK_DISPOSITION`:

| disposition | buckets | rule |
|---|---|---|
| `gate` | DEAD, REJECTED-ID-IN-USE, ERA-TBC-IN-VANILLA, ERA-WOTLK-IN-TBC | proofs of wrongness - must stay empty; `--write-baseline` refuses to pin one, so a dead id can never be laundered into "acceptable" |
| `pinned` | REDIRECTED, WRONG-RANK, RANK-ORDER, PIN-FAMILY-MISMATCH, DUPLICATE-CONFLICT, UNSOURCED | the adjudicated triage leads, frozen entry by entry |

The pinned set is **392 findings / 385 unique keys**, identified as `check|id|file` so
line and label drift is not id drift. A finding outside the baseline is **NEW** and
fails the build - that is the wrong-family gate. A finding that disappears is
**CLEARED** and also fails, until the pin is moved on purpose: the never-fires
discipline (`never-firing 11` fails in either direction too). The classifications are
byte-compared as well, so editing `CHECK_DISPOSITION` without re-baselining fails.

`--self-test` proves the gate is not vacuous end to end: it injects a mislabelled pin
(2048 Battle Shout under a Frostbolt label - the `SodCleave` = 25286 shape), an
unknown id and a correctly labelled control into synthetic ladders, then asserts the
real extractor + classifier fire on the first two, stay silent on the control, and
classify both as NEW against the committed baseline.

Live-tree proof: re-pinning 25286 (Heroic Strike) as the `SodCleave` head makes the
component fail with `NEW: 2` (the redirected id plus the cross-file duplicate
conflict); an unknown id fails on the `DEAD` gate bucket with `HARD: 1`, and
`--write-baseline` refuses to freeze it.

## Honest limits

* The sweep can only speak for ids the local sources describe. WotLK proof is narrow
  (1045-id bridge + 360 pins + 27 fixtures); a fabricated WotLK pin that no fixture
  casts is still invisible offline - closing that needs a full WotLK spell dump, the
  same shape as `_dbc_spell_ids.lua` for TBC.
* `WRONG-RANK` and `REDIRECTED` are heuristics on top of a dump whose `level` field is
  the spell's learn level only approximately, and whose names include both the cast and
  the effect spell. Every row above was Wowhead-verified; the buckets as a whole are not.
* Ladders are resolved at runtime by "first id the player knows", so a wrong-family id
  that the player does not know is harmless (30706) while one they do know is a live bug
  (11958, 13159, 16857, 27019). Severity therefore depends on the player, not just the pin.
* No live client was exercised; everything here is static plus Wowhead.

## Recommended next pass

The live-path rows and tails named above are fixed (see *Fixes applied*). To make the
defect class unrepeatable, add a name-agreement assertion to the WotLK and SoD audits -
`bridge_name` must match the pinned label - so "bridge-valid" can never again stand in
for "same spell", then wire this sweep into `verify_all` with the buckets classified
once and pinned, the way the never-fire baseline is.

**Status 2026-09-13: the assertion is DONE** (see triage addendum (k)). Both the WotLK
audit (41 files + the pin tables, 1,758 bridge-compared ids) and the SoD tier of the
sylvanas audit (20 loaders, 308 ids) now fail on a label/bridge-name disagreement, via
the shared helper `tests/spell_name_agreement.lua`. The check immediately found one live
defect this sweep had missed - `holy_wotlk.lua` HolyShock carried 33071/33070, the
dummy auras "Shadow Prison" / "Cloud of Corruption" - and both were removed. The TBC
class tier is deliberately not wired yet; a dry run there surfaced two further
live-path leads (`Repentance` carrying 5164 Knockdown, `HolyLight` carrying 10324
Redemption) recorded in addendum (k). **Wiring this sweep itself into `verify_all` is DONE** (see *Gate* above):
`tools/spell_id_sweep.py --check` now runs as a `verify_all` component against the
committed classified-once baseline, so a new wrong-family id fails the build instead
of waiting for someone to run the report. Adding it to the local `tools/pre-commit`
list (a separately numbered 19-check subset) is not part of this change.
